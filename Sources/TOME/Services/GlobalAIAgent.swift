import Foundation
import Combine
import SwiftUI

/// Global AI Agent that provides intelligent assistance across all TOME environments
/// Integrates with todos, environments, and provides contextual help
class GlobalAIAgent: ObservableObject {
    @Published var isActive = false
    @Published var conversationHistory: [AIMessage] = []
    @Published var suggestions: [AIAgentSuggestion] = []
    @Published var contextualTips: [String] = []
    @Published var isAnimatingTyping = false
    @Published var memories: [AIMemory] = []

    private let openAIService: OpenAIService
    private weak var tomeState: TOMEState?
    private var cancellables = Set<AnyCancellable>()

    // Persistence keys
    private let conversationHistoryKey = "AIConversationHistory"
    private let memoriesKey = "AIMemories"
    private let sessionStartKey = "AISessionStart"

    // Context awareness
    var currentEnvironment: TOMEEnvironment = .home
    private var currentTodos: [Todo] = []
    private var userActivity: [String] = []

    // Workshop Integration
    weak var currentTerminal: TerminalEmulator?
    weak var currentIDEManager: IDEManager?
    private var currentWorkshopTool: WorkshopTool?
    private var currentSelectedFile: IDEFile?
    var currentProjectPath: String?

    init(openAIService: OpenAIService, tomeState: TOMEState) {
        self.openAIService = openAIService
        self.tomeState = tomeState

        // Load persistent memories (survive app restarts)
        loadMemories()

        // Check if this is a new session and clear conversation history if so
        checkAndClearConversationHistory()

        setupContextMonitoring()
        generateInitialSuggestions()
    }
    
    // MARK: - Public Interface
    
    // MARK: - Helper Methods

    /// Check if the request requires complex code generation or is a simple query
    private func isComplexCodeGenerationRequest(_ message: String) -> Bool {
        let lowerMessage = message.lowercased()

        // Keywords indicating complex code generation
        let codeKeywords = ["create", "write", "generate", "build", "make", "implement"]
        let artifactKeywords = ["app", "program", "project", "function", "class", "component", "file", "script", "website", "game"]

        // Check if message contains code generation intent
        let hasCodeKeyword = codeKeywords.contains { lowerMessage.contains($0) }
        let hasArtifactKeyword = artifactKeywords.contains { lowerMessage.contains($0) }

        // If both are present and message is substantial, it's likely complex code generation
        if hasCodeKeyword && hasArtifactKeyword && message.count > 20 {
            return true
        }

        // Check for explicit multi-file or large project indicators
        let complexIndicators = ["multiple files", "full", "complete", "entire", "whole app", "with tests"]
        if complexIndicators.contains(where: { lowerMessage.contains($0) }) {
            return true
        }

        // Otherwise, it's a simple query
        return false
    }

    /// Make the actual API request (extracted from sendMessage for reuse)
    private func makeActualRequest(message: String, maxTokens: Int, completion: @escaping (Result<String, Error>) -> Void) {
        let contextualPrompt = self.buildContextualPromptWithFunctions(userMessage: message)
        let chatMessages = [ChatMessage(role: "user", content: contextualPrompt)]

        self.openAIService.chatCompletion(messages: chatMessages, model: "gpt-4o", maxTokens: maxTokens) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    // Parse and execute any function calls in the response
                    self.parseFunctionCallsAndExecute(response: response) { cleanedResponse, actionIndicators in
                        // cleanedResponse has function calls removed
                        // actionIndicators are the actions that were executed

                        let aiMessage = AIMessage(
                            role: .assistant,
                            content: cleanedResponse,
                            timestamp: Date(),
                            actionIndicators: actionIndicators
                        )
                        self.conversationHistory.append(aiMessage)
                        completion(.success(cleanedResponse))
                    }

                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    /// Send a message to the AI agent and get a response
    func sendMessage(_ message: String, completion: @escaping (Result<String, Error>) -> Void) {
        let userMessage = AIMessage(role: .user, content: message, timestamp: Date())
        conversationHistory.append(userMessage)
        
        // Check if we should execute commands directly based on context
        if currentEnvironment == .workshop {
            // Terminal command execution
            if currentWorkshopTool == .terminal, let terminalCommand = extractTerminalCommand(from: message) {
                executeTerminalCommand(terminalCommand) { [weak self] result in
                    DispatchQueue.main.async {
                        let aiMessage = AIMessage(role: .assistant, content: "Executed: \(terminalCommand)\n\nResult:\n\(result)", timestamp: Date())
                        self?.conversationHistory.append(aiMessage)
                        completion(.success("Executed: \(terminalCommand)\n\nResult:\n\(result)"))
                    }
                }
                return
            }
            
            // IDE file operations
            if currentWorkshopTool == .vscode {
                if let codeAction = extractCodeAction(from: message) {
                    executeCodeAction(codeAction) { [weak self] result in
                        DispatchQueue.main.async {
                            let aiMessage = AIMessage(role: .assistant, content: result, timestamp: Date())
                            self?.conversationHistory.append(aiMessage)
                            completion(.success(result))
                        }
                    }
                    return
                }
            }
        }
        
        // Determine if this is a simple query or complex code generation
        let needsTokenEstimation = self.isComplexCodeGenerationRequest(message)

        if needsTokenEstimation {
            // For complex requests, estimate tokens needed
            let estimationPrompt = """
            Analyze this request and estimate the TOTAL number of tokens needed for a complete response (including all code, explanations, and function calls).

            Request: "\(message)"

            Consider:
            - Number of files to create
            - Lines of code per file
            - Complexity of implementation
            - Any explanatory text

            Respond with ONLY a number (e.g., "2500" or "8000"). Add 20% headroom. Maximum is 16000.
            """

            let estimationMessages = [ChatMessage(role: "user", content: estimationPrompt)]

            // Get token estimate from AI
            openAIService.chatCompletion(messages: estimationMessages, model: "gpt-4o", maxTokens: 100) { [weak self] estimateResult in
                guard let self = self else { return }

                let estimatedTokens: Int
                switch estimateResult {
                case .success(let estimate):
                    // Parse the number from AI response
                    let cleanedEstimate = estimate.trimmingCharacters(in: .whitespacesAndNewlines)
                    estimatedTokens = Int(cleanedEstimate) ?? 4000
                    print("🤖 AI estimated tokens needed: \(estimatedTokens)")
                case .failure:
                    // Fallback to default
                    estimatedTokens = 4000
                    print("⚠️ Failed to get AI estimate, using default: \(estimatedTokens)")
                }

                // Now make the actual request with AI-determined token limit
                self.makeActualRequest(message: message, maxTokens: estimatedTokens, completion: completion)
            }
        } else {
            // For simple queries, skip token estimation and use a reasonable default
            print("💬 Simple query detected - skipping token estimation")
            self.makeActualRequest(message: message, maxTokens: 1000, completion: completion)
        }
    }
    
    /// Execute an AI agent action with real IDE/terminal manipulation
    func executeAction(_ action: AIAgentAction) {
        switch action.type {
        case .createTodo:
            if let todoText = action.parameters["text"] as? String {
                tomeState?.addTodo(todoText)
                logActivity("Created todo: \(todoText)")
            }
            
        case .switchEnvironment:
            if let envString = action.parameters["environment"] as? String,
               let environment = TOMEEnvironment.fromString(envString) {
                tomeState?.switchToEnvironment(environment)
                logActivity("Switched to environment: \(environment.displayName)")
            }
            
        case .suggestBreak:
            generateBreakSuggestion()
            
        case .analyzeTodos:
            analyzeTodosWithAI()
            
        case .provideInsight:
            if let insight = action.parameters["insight"] as? String {
                addContextualTip(insight)
            } else if let message = action.parameters["message"] as? String {
                sendMessage(message) { result in
                    switch result {
                    case .success(let response):
                        print("AI action executed successfully: \(response)")
                    case .failure(let error):
                        print("AI action failed: \(error)")
                    }
                }
            }
            
        case .createFile:
            if let fileName = action.parameters["fileName"] as? String,
               let content = action.parameters["content"] as? String {
                createFileWithAnimation(fileName: fileName, content: content) {
                    // Animation completed
                }
            }

        case .writeCode:
            if let code = action.parameters["code"] as? String,
               let fileName = action.parameters["fileName"] as? String {
                writeCodeWithAnimation(code: code, fileName: fileName) {
                    // Animation completed
                }
            }
            
        case .executeTerminal:
            if let command = action.parameters["command"] as? String {
                executeTerminalCommandWithAnimation(command: command)
            }
            
        case .readFile:
            if let fileName = action.parameters["fileName"] as? String {
                let content = readFileContent(fileName: fileName)
                print("Read file \(fileName): \(content.count) characters")
            }
            
        case .openFile:
            if let fileName = action.parameters["fileName"] as? String {
                openFileInIDE(fileName: fileName)
            }
        }
    }
    
    // MARK: - AI Action Implementation Functions
    
    /// Create a new file with animated typing effect
    private func createFileWithAnimation(fileName: String, content: String, completion: @escaping () -> Void) {
        guard let ideManager = currentIDEManager else {
            completion()
            return
        }

        DispatchQueue.main.async {
            // Build proper file path
            let projectPath = self.currentProjectPath ?? ideManager.currentDirectory
            let fullPath = (projectPath as NSString).appendingPathComponent(fileName)

            print("📝 Creating file: \(fileName) at \(fullPath)")

            // Create the file in the IDE manager with EMPTY content initially
            let newFile = IDEFile(name: fileName, path: fullPath, isDirectory: false, content: "")
            ideManager.createFile(newFile)

            // Select and open the file
            ideManager.selectedFile = newFile
            if !ideManager.openFiles.contains(where: { $0.path == newFile.path }) {
                ideManager.openFile(newFile)
            }

            print("✅ File created and opened: \(fileName)")

            // Animate typing the content - this will populate the file
            self.animateTypingCode(content: content, fileName: fileName, completion: completion)
        }
    }
    
    /// Write code to existing file with animation
    private func writeCodeWithAnimation(code: String, fileName: String, completion: @escaping () -> Void) {
        guard let ideManager = currentIDEManager else {
            completion()
            return
        }

        DispatchQueue.main.async {
            // Find the file in the files list
            if let file = ideManager.files.first(where: { $0.name == fileName }) {
                print("📝 Updating file: \(fileName)")

                // Clear file content first
                var updatedFile = file
                updatedFile.content = ""
                ideManager.updateFile(updatedFile)

                // Select and open the file
                ideManager.selectedFile = updatedFile
                if !ideManager.openFiles.contains(where: { $0.name == fileName }) {
                    ideManager.openFile(updatedFile)
                }

                print("✅ File cleared, starting animation: \(fileName)")

                // Animate typing the new code - this will populate the file
                self.animateTypingCode(content: code, fileName: fileName, completion: completion)
            } else {
                // File doesn't exist, create it
                print("⚠️ File not found, creating: \(fileName)")
                self.createFileWithAnimation(fileName: fileName, content: code, completion: completion)
            }
        }
    }
    
    /// Execute terminal command with fast typing animation
    private func executeTerminalCommandWithAnimation(command: String) {
        guard let terminal = currentTerminal else {
            print("❌ Cannot execute terminal command: terminal is nil")
            print("🔧 Current workshop tool: \(currentWorkshopTool?.name ?? "nil")")
            print("🔧 Current environment: \(currentEnvironment)")
            return
        }

        print("✅ Executing terminal command: \(command)")

        DispatchQueue.main.async {
            // Animate typing the command
            self.animateTypingTerminalCommand(command: command) {
                // Execute the command after typing animation
                terminal.executeCommand(command)
                print("✅ Command executed in terminal: \(command)")
            }
        }
    }
    
    /// Read file content and store for AI context
    private func readFileContent(fileName: String) -> String {
        guard let ideManager = currentIDEManager else { return "" }
        
        if let file = ideManager.openFiles.first(where: { $0.name == fileName }) {
            return file.content
        }
        
        // Try to read from filesystem if not in open files
        let filePath = (currentProjectPath ?? "") + "/" + fileName
        do {
            return try String(contentsOfFile: filePath)
        } catch {
            print("Could not read file: \(fileName)")
            return ""
        }
    }
    
    /// Open file in IDE for editing
    private func openFileInIDE(fileName: String) {
        guard let ideManager = currentIDEManager else { return }
        
        DispatchQueue.main.async {
            if let file = ideManager.openFiles.first(where: { $0.name == fileName }) {
                // File already open, just select it
                ideManager.selectedFile = file
            } else {
                // Try to load and open the file
                let filePath = (self.currentProjectPath ?? "") + "/" + fileName
                if let content = try? String(contentsOfFile: filePath) {
                    let file = IDEFile(name: fileName, path: filePath, isDirectory: false, content: content)
                    ideManager.openFile(file)
                }
            }
        }
    }
    
    // MARK: - Animation Functions
    
    /// Animate typing code with realistic speed
    private func animateTypingCode(content: String, fileName: String, completion: @escaping () -> Void) {
        guard let ideManager = currentIDEManager else {
            completion()
            return
        }

        // This will be implemented to simulate fast typing in the IDE
        // Characters will appear rapidly as if someone is typing very fast
        let typingSpeed = 0.003 // 3ms per character - very fast but visible

        isAnimatingTyping = true

        for (index, character) in content.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * typingSpeed) {
                // Add character to the currently selected file
                // This will need to interface with the code editor
                NotificationCenter.default.post(
                    name: NSNotification.Name("AITypingCharacter"),
                    object: String(character)
                )

                // Mark animation as complete after last character
                if index == content.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.isAnimatingTyping = false
                        print("🎬 Animation completed for \(content.count) characters")

                        // Save the final content to the file
                        if let file = ideManager.files.first(where: { $0.name == fileName }) {
                            var updatedFile = file
                            updatedFile.content = content
                            ideManager.updateFile(updatedFile)
                            print("💾 Saved final content to \(fileName)")
                        }

                        completion()
                    }
                }
            }
        }
    }
    
    /// Animate typing terminal command
    private func animateTypingTerminalCommand(command: String, completion: @escaping () -> Void) {
        let typingSpeed = 0.05 // Slightly slower for terminal commands
        
        isAnimatingTyping = true
        
        for (index, character) in command.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * typingSpeed) {
                // Add character to terminal input
                NotificationCenter.default.post(
                    name: NSNotification.Name("AITypingTerminalCharacter"), 
                    object: String(character)
                )
            }
        }
        
        // Execute command after typing animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(command.count) * typingSpeed + 0.2) {
            self.isAnimatingTyping = false
            completion()
        }
    }
    
    /// Get contextual suggestions based on current state
    func getContextualSuggestions() -> [AIAgentSuggestion] {
        return suggestions
    }
    
    /// Set the current workshop tool for context-aware assistance
    func setCurrentWorkshopTool(_ tool: WorkshopTool?, terminal: TerminalEmulator? = nil, ideManager: IDEManager? = nil, selectedFile: IDEFile? = nil) {
        print("🔧 AI Agent setCurrentWorkshopTool called")
        print("🔧 Tool: \(tool?.name ?? "nil")")
        print("🔧 Terminal provided: \(terminal != nil)")
        print("🔧 IDE Manager provided: \(ideManager != nil)")
        
        currentWorkshopTool = tool
        if let terminal = terminal {
            currentTerminal = terminal
            print("🔧 Terminal connected successfully")
        }
        if let ideManager = ideManager {
            currentIDEManager = ideManager
            print("🔧 IDE Manager connected successfully")
        }
        currentSelectedFile = selectedFile
        generateWorkshopToolSpecificSuggestions()
    }
    
    /// Update the currently selected file context
    func updateSelectedFile(_ file: IDEFile?) {
        currentSelectedFile = file
        generateWorkshopToolSpecificSuggestions()
    }
    
    // MARK: - Context Monitoring

    private func setupContextMonitoring() {
        // Monitor environment changes
        tomeState?.$currentEnvironment
            .receive(on: DispatchQueue.main)
            .sink { [weak self] environment in
                self?.currentEnvironment = environment
                self?.onEnvironmentChanged(environment)
            }
            .store(in: &cancellables)
        
        // Monitor todo changes
        tomeState?.$todos
            .receive(on: DispatchQueue.main)
            .sink { [weak self] todos in
                self?.currentTodos = todos
                self?.onTodosChanged(todos)
            }
            .store(in: &cancellables)
    }
    
    private func onEnvironmentChanged(_ environment: TOMEEnvironment) {
        logActivity("Environment changed to \(environment.displayName)")
        generateEnvironmentSpecificSuggestions(for: environment)
    }
    
    private func onTodosChanged(_ todos: [Todo]) {
        let incompleteTodos = todos.filter { !$0.isCompleted }
        if incompleteTodos.count > 10 {
            addSuggestion(AIAgentSuggestion(
                type: .productivity,
                title: "Too Many Open Tasks",
                description: "You have \(incompleteTodos.count) open tasks. Consider prioritizing or breaking them into smaller chunks.",
                action: AIAgentAction(type: .analyzeTodos, parameters: [:])
            ))
        }
        
        // Check for completed todos to celebrate
        let recentlyCompleted = todos.filter { 
            $0.isCompleted && 
            $0.completedAt?.timeIntervalSinceNow ?? -Double.infinity > -3600 // Last hour
        }
        
        if recentlyCompleted.count >= 3 {
            addSuggestion(AIAgentSuggestion(
                type: .celebration,
                title: "Great Progress!",
                description: "You've completed \(recentlyCompleted.count) tasks recently. Consider taking a break in the Garden.",
                action: AIAgentAction(type: .switchEnvironment, parameters: ["environment": "garden"])
            ))
        }
    }
    
    // MARK: - AI Processing
    
    private func buildContextualPrompt(userMessage: String) -> String {
        let environmentContext = getEnvironmentContext()
        let todoContext = getTodoContext()
        let activityContext = getActivityContext()
        let articleContext = getArticleContext()
        let conversationContext = getConversationContext()
        let memoriesContext = getMemoriesAsContext()

        return """
        You are TOME's global AI assistant, helping users with productivity and focus across different work environments.

        Current Context:
        - Environment: \(currentEnvironment.displayName) - \(environmentContext)
        - Active Todos: \(currentTodos.filter { !$0.isCompleted }.count)
        - Recent Activity: \(activityContext)
        \(articleContext)

        Todo Context: \(todoContext)
        \(conversationContext)
        \(memoriesContext)

        User Message: "\(userMessage)"

        Respond as a helpful, concise assistant that can:
        1. Help manage tasks and todos
        2. Suggest environment switches for optimal work
        3. Provide productivity insights
        4. Execute actions like creating todos or switching environments
        5. Summarize or analyze articles currently being read
        6. Reference previous conversation history to maintain context
        7. Save important information to persistent memory when requested
        \(getEnvironmentSpecificCapabilities())

        Keep responses conversational and actionable. If you can help with specific actions, mention them clearly.
        \(getEnvironmentSpecificInstructions())
        """
    }

    private func getConversationContext() -> String {
        guard conversationHistory.count > 1 else { return "" }

        // Get last 5 messages (or fewer) for context
        let recentMessages = conversationHistory.suffix(5)
        var context = "\n\nRecent Conversation:\n"

        for message in recentMessages {
            let roleLabel = message.role == .user ? "User" : "Assistant"
            let preview = message.content.prefix(100)
            context += "- \(roleLabel): \(preview)\(message.content.count > 100 ? "..." : "")\n"
        }

        return context
    }
    
    private func getEnvironmentContext() -> String {
        switch currentEnvironment {
        case .home:
            return "Central hub for navigation"
        case .planning:
            return "Task management and goal setting"
        case .writerDesk:
            return "Communication and writing"
        case .workshop:
            if let tool = currentWorkshopTool {
                switch tool {
                case .terminal:
                    return "Development and creation - Terminal active"
                case .vscode:
                    return "Development and creation - IDE active"
                }
            } else {
                return "Development and creation - Tool selection"
            }
        case .coffeeshop:
            return "Research and learning"
        case .garden:
            return "Reflection and mindfulness"
        }
    }
    
    private func getTodoContext() -> String {
        let total = currentTodos.count
        let completed = currentTodos.filter { $0.isCompleted }.count
        let highPriority = currentTodos.filter { $0.priority == .high && !$0.isCompleted }.count
        
        return "\(completed)/\(total) todos completed, \(highPriority) high-priority remaining"
    }
    
    private func getActivityContext() -> String {
        return userActivity.suffix(3).joined(separator: ", ")
    }
    
    private func getArticleContext() -> String {
        guard let article = tomeState?.currentCoffeeshopArticle else {
            return ""
        }
        
        return """
        - Currently Reading: "\(article.title)" from \(article.source)
        - Article Summary: \(article.summary)
        - Article Content: \(String(article.content.prefix(500)))\(article.content.count > 500 ? "..." : "")
        """
    }
    
    private func logActivity(_ activity: String) {
        userActivity.append(activity)
        if userActivity.count > 50 {
            userActivity.removeFirst(userActivity.count - 50)
        }
    }
    
    // MARK: - Suggestions and Insights
    
    private func generateInitialSuggestions() {
        addSuggestion(AIAgentSuggestion(
            type: .welcome,
            title: "Welcome to TOME",
            description: "I'm your AI assistant. I can help manage tasks, suggest optimal environments, and provide productivity insights.",
            action: nil
        ))
    }
    
    private func generateEnvironmentSpecificSuggestions(for environment: TOMEEnvironment) {
        // Clear previous environment-specific suggestions
        suggestions.removeAll { suggestion in
            switch suggestion.type {
            case .productivity, .focus, .wellbeing, .learning, .communication, .navigation:
                return true
            default:
                return false
            }
        }
        
        switch environment {
        case .planning:
            addSuggestion(AIAgentSuggestion(
                type: .productivity,
                title: "Create a new project plan",
                description: "Help me break down a large project into manageable tasks",
                action: nil
            ))
            addSuggestion(AIAgentSuggestion(
                type: .productivity,
                title: "Review my current goals",
                description: "Analyze my todo list and suggest priorities",
                action: AIAgentAction(type: .analyzeTodos, parameters: [:])
            ))
            addSuggestion(AIAgentSuggestion(
                type: .productivity,
                title: "Time block my schedule",
                description: "Help me organize my day with focused work blocks",
                action: nil
            ))
            
        case .workshop:
            addSuggestion(AIAgentSuggestion(
                type: .focus,
                title: "Initialize a git repository",
                description: "Set up version control for my current project",
                action: nil
            ))
            addSuggestion(AIAgentSuggestion(
                type: .focus,
                title: "Generate boilerplate code",
                description: "Create starter templates for React, Python, or Swift projects",
                action: nil
            ))
            addSuggestion(AIAgentSuggestion(
                type: .focus,
                title: "Debug this error message",
                description: "Help me understand and fix compilation or runtime errors",
                action: nil
            ))
            addSuggestion(AIAgentSuggestion(
                type: .focus,
                title: "Optimize my development setup",
                description: "Suggest terminal shortcuts and development workflow improvements",
                action: nil
            ))
            
        case .garden:
            addSuggestion(AIAgentSuggestion(
                type: .wellbeing,
                title: "Reflect on my progress",
                description: "Help me review what I've accomplished and celebrate wins",
                action: nil
            ))
            addSuggestion(AIAgentSuggestion(
                type: .wellbeing,
                title: "Set intentions for tomorrow",
                description: "Guide me through planning meaningful work for the next day",
                action: nil
            ))
            addSuggestion(AIAgentSuggestion(
                type: .wellbeing,
                title: "Practice mindful breathing",
                description: "Lead me through a short mindfulness exercise",
                action: nil
            ))
            
        case .coffeeshop:
            addSuggestion(AIAgentSuggestion(
                type: .learning,
                title: "Summarize this article",
                description: "Create key takeaways from what I'm currently reading",
                action: nil
            ))
            addSuggestion(AIAgentSuggestion(
                type: .learning,
                title: "Research new technologies",
                description: "Help me explore emerging tools and trends in my field",
                action: nil
            ))
            addSuggestion(AIAgentSuggestion(
                type: .learning,
                title: "Connect ideas across topics",
                description: "Find patterns and connections between different concepts I'm learning",
                action: nil
            ))
            
        case .writerDesk:
            addSuggestion(AIAgentSuggestion(
                type: .communication,
                title: "Draft a professional email",
                description: "Help me write clear and effective business communications",
                action: nil
            ))
            addSuggestion(AIAgentSuggestion(
                type: .communication,
                title: "Improve my writing clarity",
                description: "Review and refine my prose for better impact",
                action: nil
            ))
            addSuggestion(AIAgentSuggestion(
                type: .communication,
                title: "Create presentation slides",
                description: "Structure and outline content for an upcoming presentation",
                action: nil
            ))
            
        case .home:
            addSuggestion(AIAgentSuggestion(
                type: .navigation,
                title: "Choose my optimal environment",
                description: "Based on my energy and current tasks, suggest the best workspace",
                action: nil
            ))
            addSuggestion(AIAgentSuggestion(
                type: .navigation,
                title: "Review my productivity patterns",
                description: "Analyze when and where I'm most effective",
                action: nil
            ))
        }
    }
    
    private func generateBreakSuggestion() {
        addSuggestion(AIAgentSuggestion(
            type: .wellbeing,
            title: "Break Time",
            description: "You've been working hard. Consider taking a mindful break in the Garden or stepping away from your screen.",
            action: AIAgentAction(type: .switchEnvironment, parameters: ["environment": "garden"])
        ))
    }
    
    private func analyzeTodosWithAI() {
        let todoTexts = currentTodos.filter { !$0.isCompleted }.map { $0.text }.joined(separator: "\n")
        
        let analysisPrompt = """
        Analyze these todos for patterns, priorities, and suggestions for better organization:
        
        \(todoTexts)
        
        Provide 2-3 specific, actionable insights in a concise format.
        """
        
        let messages = [ChatMessage(role: "user", content: analysisPrompt)]
        
        openAIService.chatCompletion(messages: messages, model: "gpt-3.5-turbo") { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.addContextualTip(response)
                case .failure(let error):
                    print("Todo analysis failed: \(error)")
                }
            }
        }
    }
    
    private func addSuggestion(_ suggestion: AIAgentSuggestion) {
        suggestions.insert(suggestion, at: 0)
        if suggestions.count > 5 {
            suggestions = Array(suggestions.prefix(5))
        }
    }
    
    private func addContextualTip(_ tip: String) {
        contextualTips.insert(tip, at: 0)
        if contextualTips.count > 10 {
            contextualTips = Array(contextualTips.prefix(10))
        }
    }
    
    private func getEnvironmentSpecificCapabilities() -> String {
        switch currentEnvironment {
        case .workshop:
            if let tool = currentWorkshopTool {
                switch tool {
                case .terminal:
                    return """
                    6. Execute terminal commands directly in the embedded terminal
                    7. Navigate the filesystem and manage directories
                    8. Perform git operations and version control
                    9. Run development commands (npm, pip, cargo, etc.)
                    10. Debug and troubleshoot system-level issues
                    """
                case .vscode:
                    return """
                    6. Generate code templates and boilerplate
                    7. Create complete functions and classes
                    8. Explain and optimize existing code
                    9. Suggest architectural improvements
                    10. Generate documentation and comments
                    """
                }
            } else {
                return """
                6. Help you choose between terminal or IDE for your current task
                7. Set up development environments
                8. Suggest optimal tool workflows
                """
            }
        case .planning:
            return """
            6. Break down large projects into tasks
            7. Suggest time-blocking strategies
            8. Prioritize tasks based on urgency and impact
            9. Create project timelines and milestones
            """
        case .writerDesk:
            return """
            6. Draft emails and professional communications
            7. Improve writing clarity and tone
            8. Structure presentations and documents
            9. Generate creative content and copy
            """
        case .garden:
            return """
            6. Guide reflection and mindfulness exercises
            7. Help set intentions and goals
            8. Celebrate accomplishments and progress
            9. Suggest wellness and self-care practices
            """
        case .coffeeshop:
            return """
            6. Summarize articles and research content
            7. Connect ideas across different topics
            8. Suggest related learning resources
            9. Extract key insights from complex information
            """
        case .home:
            return """
            6. Analyze productivity patterns and habits
            7. Recommend optimal environments for different tasks
            8. Review overall work-life balance
            """
        }
    }
    
    private func getEnvironmentSpecificInstructions() -> String {
        switch currentEnvironment {
        case .writerDesk:
            return """

            Writer's Desk Instructions:
            - When generating writing content (templates, essays, documents), use the insert_text_to_writer function
            - Focus on clarity, tone, and audience appropriateness
            - For templates like MLA format, generate the COMPLETE formatted template
            - Do NOT just explain how to format - GENERATE the actual formatted content
            - Suggest structural improvements for better flow
            """
        case .workshop:
            if let tool = currentWorkshopTool {
                switch tool {
                case .terminal:
                    return """

                    Workshop Terminal Instructions:
                    - YOU HAVE FULL TERMINAL ACCESS - Execute ALL commands the user needs
                    - AUTOMATICALLY install packages/dependencies - DO NOT ask the user to do it
                    - Run commands for navigation, git, package management, running scripts, etc.
                    - DO NOT just provide instructions - EXECUTE the actual commands using function calls
                    - Use [FUNCTION_CALL:execute_terminal(command=...)::END_CALL::] for EVERY command
                    - You can run multiple commands sequentially for complex tasks

                    Examples of what you MUST DO:
                    - User: "install pyqt5" → [FUNCTION_CALL:execute_terminal(command=pip install pyqt5)::END_CALL::]
                    - User: "go to desktop" → [FUNCTION_CALL:execute_terminal(command=cd ~/Desktop && ls)::END_CALL::]
                    - User: "run the script" → [FUNCTION_CALL:execute_terminal(command=python script.py)::END_CALL::]

                    WRONG: "You can install pyqt5 with: pip install pyqt5"
                    RIGHT: [FUNCTION_CALL:execute_terminal(command=pip install pyqt5)::END_CALL::]
                    """
                case .vscode:
                    return """
                    
                    Workshop IDE Instructions:
                    - Generate complete, runnable code snippets
                    - Provide detailed explanations of code structure and patterns
                    - Focus on best practices for code organization and architecture
                    - Suggest refactoring and optimization strategies
                    - Help with debugging by analyzing code structure and logic
                    """
                }
            } else {
                return """
                
                Workshop Tool Selection Instructions:
                - Help the user choose the right tool based on their current task
                - Recommend terminal for system operations, git, and command-line tools
                - Recommend IDE for code writing, debugging, and file editing
                - Provide guidance on optimal development workflows
                """
            }
        case .planning:
            return """

            Planning Environment Instructions:
            - Help break down abstract goals into specific, actionable tasks
            - Suggest realistic timeframes and priorities
            - Encourage regular review and adjustment of plans
            """
        case .garden:
            return """
            
            Garden Environment Instructions:
            - Use calming, reflective language
            - Guide through specific mindfulness techniques
            - Encourage self-compassion and celebration of progress
            """
        case .coffeeshop:
            return """
            
            Coffeeshop Environment Instructions:
            - Focus on synthesis and connection-making
            - Provide structured summaries with key takeaways
            - Suggest follow-up questions and deeper exploration
            """
        case .home:
            return """
            
            Home Environment Instructions:
            - Take a holistic view of productivity and well-being
            - Consider the user's overall patterns and preferences
            - Suggest environment switches based on current energy and tasks
            """
        }
    }
    
    // MARK: - Terminal Command Integration
    
    private func extractTerminalCommand(from message: String) -> String? {
        let message = message.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Direct command patterns
        let commandPatterns = [
            "navigate to desktop",
            "go to desktop",
            "cd desktop",
            "list files",
            "show files",
            "ls",
            "pwd",
            "what directory am i in",
            "where am i",
            "go home",
            "cd ~",
            "git status",
            "check git status"
        ]
        
        for pattern in commandPatterns {
            if message.contains(pattern) {
                switch pattern {
                case "navigate to desktop", "go to desktop", "cd desktop":
                    return "cd ~/Desktop"
                case "list files", "show files", "ls":
                    return "ls -la"
                case "pwd", "what directory am i in", "where am i":
                    return "pwd"
                case "go home", "cd ~":
                    return "cd ~"
                case "git status", "check git status":
                    return "git status"
                default:
                    return nil
                }
            }
        }
        
        return nil
    }
    
    private func extractTerminalCommandFromResponse(_ response: String) -> String? {
        // Look for code blocks or command suggestions in AI response
        let patterns = [
            "```bash\\n(.+?)\\n```",
            "```\\n(.+?)\\n```",
            "`(.+?)`"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) {
                let range = NSRange(location: 0, length: response.utf16.count)
                if let match = regex.firstMatch(in: response, options: [], range: range) {
                    if let commandRange = Range(match.range(at: 1), in: response) {
                        let command = String(response[commandRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        // Only execute safe, common commands
                        if isCommandSafe(command) {
                            return command
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    private func isCommandSafe(_ command: String) -> Bool {
        let safeCommands = ["ls", "pwd", "cd", "git status", "git log", "cat", "head", "tail", "find", "grep"]
        let commandParts = command.split(separator: " ")
        guard let firstCommand = commandParts.first else { return false }
        
        return safeCommands.contains(String(firstCommand))
    }
    
    private func executeTerminalCommand(_ command: String, completion: @escaping (String) -> Void) {
        guard let terminal = currentTerminal else {
            completion("Terminal not available")
            return
        }
        
        DispatchQueue.main.async {
            terminal.executeCommand(command)
            completion("Command executed in terminal")
        }
    }
    
    // MARK: - IDE Code Actions
    
    private func extractCodeAction(from message: String) -> CodeAction? {
        let message = message.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Detect file creation requests
        if message.contains("create") && (message.contains("file") || message.contains("component") || message.contains("function")) {
            if let fileName = extractFileName(from: message) {
                return .createFile(name: fileName, content: generateCodeContent(for: fileName, request: message))
            }
        }
        
        // Detect code writing requests
        if message.contains("write") && (message.contains("function") || message.contains("class") || message.contains("component")) {
            return .writeCode(code: generateCodeFromRequest(message), location: .currentFile)
        }
        
        // Detect code insertion requests
        if message.contains("add") || message.contains("insert") {
            return .insertCode(code: generateCodeFromRequest(message), location: .currentFile)
        }
        
        // Detect file reading requests
        if message.contains("read") || message.contains("show") || message.contains("open") {
            if let fileName = extractFileName(from: message) {
                return .readFile(name: fileName)
            }
        }
        
        return nil
    }
    
    private func executeCodeAction(_ action: CodeAction, completion: @escaping (String) -> Void) {
        guard let ideManager = currentIDEManager else {
            completion("IDE not available")
            return
        }
        
        DispatchQueue.main.async {
            switch action {
            case .createFile(let name, let content):
                ideManager.createNewFile(name: name, content: content)
                completion("Created file: \(name)")
                
            case .writeCode(let code, _):
                if let currentFile = self.currentSelectedFile {
                    ideManager.saveFile(currentFile, content: code)
                    completion("Code written to \(currentFile.name)")
                } else {
                    completion("No file selected to write code to")
                }
                
            case .insertCode(let code, _):
                if let currentFile = self.currentSelectedFile {
                    let newContent = currentFile.content + "\n\n" + code
                    ideManager.saveFile(currentFile, content: newContent)
                    completion("Code inserted into \(currentFile.name)")
                } else {
                    completion("No file selected to insert code into")
                }
                
            case .readFile(let name):
                if let file = ideManager.files.first(where: { $0.name == name }) {
                    completion("File content of \(name):\n\n\(file.content)")
                } else {
                    completion("File not found: \(name)")
                }
                
            case .runCode(let fileName):
                completion("Running code in \(fileName) - feature not yet implemented")
                
            case .debugCode(let fileName):
                completion("Debugging code in \(fileName) - feature not yet implemented")
            }
        }
    }
    
    private func extractFileName(from message: String) -> String? {
        // Simple regex to extract file names
        let patterns = [
            "create\\s+(\\w+\\.\\w+)",
            "file\\s+called\\s+(\\w+\\.\\w+)",
            "new\\s+(\\w+\\.\\w+)",
            "\\\"([^\\\"]+\\.\\w+)\\\"",
            "\\'([^\\']+\\.\\w+)\\'"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: message.utf16.count)
                if let match = regex.firstMatch(in: message, options: [], range: range) {
                    if let matchRange = Range(match.range(at: 1), in: message) {
                        return String(message[matchRange])
                    }
                }
            }
        }
        
        return nil
    }
    
    private func generateCodeContent(for fileName: String, request: String) -> String {
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        let baseName = (fileName as NSString).deletingPathExtension
        
        switch fileExtension {
        case "swift":
            return generateSwiftTemplate(for: baseName, request: request)
        case "py":
            return generatePythonTemplate(for: baseName, request: request)
        case "js", "jsx":
            return generateJavaScriptTemplate(for: baseName, request: request)
        case "ts", "tsx":
            return generateTypeScriptTemplate(for: baseName, request: request)
        default:
            return "// Generated content for \(fileName)\n// \(request)\n"
        }
    }
    
    private func generateCodeFromRequest(_ request: String) -> String {
        // This would integrate with OpenAI to generate actual code
        // For now, return a placeholder
        return "// Generated code based on: \(request)\n// TODO: Implement actual code generation\n"
    }
    
    private func generateSwiftTemplate(for name: String, request: String) -> String {
        if request.contains("view") || request.contains("component") {
            return """
            import SwiftUI
            
            struct \(name): View {
                var body: some View {
                    VStack {
                        Text("Hello, \(name)!")
                            .font(.title)
                    }
                    .padding()
                }
            }
            
            #Preview {
                \(name)()
            }
            """
        } else if request.contains("class") {
            return """
            import Foundation
            
            class \(name) {
                init() {
                    // TODO: Implement initialization
                }
            }
            """
        } else {
            return """
            import Foundation
            
            // \(name)
            // Generated based on: \(request)
            """
        }
    }
    
    private func generatePythonTemplate(for name: String, request: String) -> String {
        if request.contains("class") {
            return """
            class \(name.capitalized):
                def __init__(self):
                    # TODO: Implement initialization
                    pass
            """
        } else {
            return """
            # \(name)
            # Generated based on: \(request)
            
            def main():
                # TODO: Implement main functionality
                pass
            
            if __name__ == "__main__":
                main()
            """
        }
    }
    
    private func generateJavaScriptTemplate(for name: String, request: String) -> String {
        if request.contains("component") || request.contains("react") {
            return """
            import React from 'react';
            
            const \(name.capitalized) = () => {
                return (
                    <div>
                        <h1>Hello, \(name.capitalized)!</h1>
                    </div>
                );
            };
            
            export default \(name.capitalized);
            """
        } else {
            return """
            // \(name)
            // Generated based on: \(request)
            
            function main() {
                // TODO: Implement main functionality
            }
            
            main();
            """
        }
    }
    
    private func generateTypeScriptTemplate(for name: String, request: String) -> String {
        if request.contains("component") || request.contains("react") {
            return """
            import React from 'react';
            
            interface \(name.capitalized)Props {
                // TODO: Define props
            }
            
            const \(name.capitalized): React.FC<\(name.capitalized)Props> = () => {
                return (
                    <div>
                        <h1>Hello, \(name.capitalized)!</h1>
                    </div>
                );
            };
            
            export default \(name.capitalized);
            """
        } else {
            return """
            // \(name)
            // Generated based on: \(request)
            
            function main(): void {
                // TODO: Implement main functionality
            }
            
            main();
            """
        }
    }
    
    // MARK: - Workshop Tool Specific Suggestions
    
    private func generateWorkshopToolSpecificSuggestions() {
        // Clear previous workshop suggestions
        suggestions.removeAll { $0.type == .focus }
        
        guard currentEnvironment == .workshop else { return }
        
        switch currentWorkshopTool {
        case .terminal:
            addSuggestion(AIAgentSuggestion(
                type: .focus,
                title: "Navigate to Desktop",
                description: "Take me to the Desktop directory",
                action: nil
            ))
            addSuggestion(AIAgentSuggestion(
                type: .focus,
                title: "Check current directory",
                description: "Show me where I am in the filesystem",
                action: nil
            ))
            addSuggestion(AIAgentSuggestion(
                type: .focus,
                title: "List all files",
                description: "Show me all files and folders here",
                action: nil
            ))
            addSuggestion(AIAgentSuggestion(
                type: .focus,
                title: "Check git status",
                description: "Show me the current git repository status",
                action: nil
            ))
            addSuggestion(AIAgentSuggestion(
                type: .focus,
                title: "Go to home directory",
                description: "Navigate back to my home folder",
                action: nil
            ))
            
        case .vscode:
            addSuggestion(AIAgentSuggestion(
                type: .focus,
                title: "Create a new React component",
                description: "Generate a functional React component with props",
                action: AIAgentAction(type: .provideInsight, parameters: ["message": "Create a new React component called MyComponent.jsx"])
            ))
            addSuggestion(AIAgentSuggestion(
                type: .focus,
                title: "Write a Python function",
                description: "Create a Python function with documentation",
                action: AIAgentAction(type: .provideInsight, parameters: ["message": "Create a new Python file called main.py with a hello world function"])
            ))
            addSuggestion(AIAgentSuggestion(
                type: .focus,
                title: "Generate Swift view",
                description: "Create a SwiftUI view with proper structure",
                action: AIAgentAction(type: .provideInsight, parameters: ["message": "Create a new Swift file called ContentView.swift with a SwiftUI view"])
            ))
            addSuggestion(AIAgentSuggestion(
                type: .focus,
                title: "Explain this code",
                description: "Help me understand what this code does",
                action: AIAgentAction(type: .provideInsight, parameters: ["message": "Explain the code in the current file"])
            ))
            addSuggestion(AIAgentSuggestion(
                type: .focus,
                title: "Optimize this function",
                description: "Suggest improvements for better performance",
                action: AIAgentAction(type: .provideInsight, parameters: ["message": "Optimize the code in the current file for better performance"])
            ))
            
        case .none:
            // General workshop suggestions when no specific tool is selected
            addSuggestion(AIAgentSuggestion(
                type: .focus,
                title: "Start a new project",
                description: "Help me set up a development environment",
                action: nil
            ))
            addSuggestion(AIAgentSuggestion(
                type: .focus,
                title: "Choose the right tool",
                description: "Recommend terminal or IDE based on my current task",
                action: nil
            ))
        }
    }
    
    // MARK: - Function Call Methods
    
    /// Build contextual prompt with function definitions
    private func buildContextualPromptWithFunctions(userMessage: String) -> String {
        let basePrompt = buildContextualPrompt(userMessage: userMessage)
        let functionDefinitions = getFunctionDefinitions()
        
        return """
        \(basePrompt)

        \(functionDefinitions)

        CRITICAL RULES:
        1. ALWAYS use function calls for code and commands - NEVER include code in your text response
        2. Write COMPLETE, PRODUCTION-READY code - not stubs or TODOs
        3. Format: [FUNCTION_CALL:function_name(param1=value1,param2=value2)::END_CALL::]
        4. Use \\n for newlines and \\t for tabs in code content
        5. MUST end every function call with ::END_CALL:: delimiter
        6. Your text response should only describe what you're doing, not contain code

        Example response:
        "I'll create a Python script with a main function and a helper module."
        [FUNCTION_CALL:create_file(fileName=main.py,content=import utils\\n\\ndef main():\\n\\tprint(utils.helper())\\n\\nif __name__ == "__main__":\\n\\tmain())::END_CALL::]
        [FUNCTION_CALL:create_file(fileName=utils.py,content=def helper():\\n\\treturn "Hello World")::END_CALL::]
        """
    }
    
    /// Get available function definitions for AI
    private func getFunctionDefinitions() -> String {
        if currentEnvironment == .writerDesk {
            return """
            Available Functions:
            - insert_text_to_writer(content=string): Insert text/template into the currently open document in Writer's Desk

            CRITICAL WRITER'S DESK RULES:
            1. When user asks for templates (MLA, APA, etc.), generate the FULL template using this function
            2. When user asks for content generation, create the content using this function
            3. Use \\n for newlines in the content
            4. Always include ::END_CALL:: at the end of every function call
            5. Generate COMPLETE, properly formatted content - not explanations

            Examples:
            [FUNCTION_CALL:insert_text_to_writer(content=[Your Name]\\n[Instructor Name]\\n[Course]\\n[Date]\\n\\n[Essay Title]\\n\\n[Introduction paragraph...]\\n\\nWorks Cited)::END_CALL::]

            When user says "give me an MLA template", you MUST execute:
            [FUNCTION_CALL:insert_text_to_writer(content=<full MLA formatted template>)::END_CALL::]
            """
        } else if currentEnvironment == .workshop {
            if currentWorkshopTool == .terminal {
                return """
                Available Functions:
                - execute_terminal(command=string): Execute a terminal command with typing animation

                CRITICAL TERMINAL RULES:
                1. AUTOMATICALLY execute commands - DO NOT give instructions to the user
                2. If user asks to install something, USE THIS FUNCTION to install it
                3. If user needs a package, USE THIS FUNCTION to install it first
                4. Always include ::END_CALL:: at the end of every function call
                5. You can chain commands with && for sequential operations
                6. IMPORTANT: Use python3 and pip3 for Python (NOT python or pip)

                Examples:
                [FUNCTION_CALL:execute_terminal(command=pip3 install requests)::END_CALL::]
                [FUNCTION_CALL:execute_terminal(command=python3 main.py)::END_CALL::]
                [FUNCTION_CALL:execute_terminal(command=npm install && npm start)::END_CALL::]

                When user says "install pyqt5", your response MUST include:
                [FUNCTION_CALL:execute_terminal(command=pip3 install pyqt5)::END_CALL::]
                """
            } else if currentWorkshopTool == .vscode {
                return """
                Available Functions (YOU MUST USE THESE - DO NOT INCLUDE CODE IN YOUR RESPONSE):

                FILE OPERATIONS:
                - create_file(fileName=string,content=string): Create a new file with code
                - write_code(fileName=string,code=string): Write code to existing file
                - read_file(fileName=string): Read file contents
                - open_file(fileName=string): Open file in IDE

                TERMINAL OPERATIONS (IDE has embedded terminal):
                - execute_terminal(command=string): Execute commands in the embedded terminal

                CRITICAL INSTRUCTIONS:
                1. Put ALL code inside function calls, NOT in your text response
                2. In the content parameter, use ONLY the string \\n for newlines
                3. For indentation, use actual spaces (NOT \\t, NOT the word tab, just regular spaces)
                4. Write complete, production-ready code with proper structure
                5. Each file should be fully implemented, not just stubs
                6. MUST end every function call with ::END_CALL:: delimiter
                7. AUTOMATICALLY install dependencies with execute_terminal - DO NOT give instructions
                8. IMPORTANT: Use python3 and pip3 for Python (NOT python or pip)

                Example (this will create a properly formatted Python file):
                [FUNCTION_CALL:create_file(fileName=main.py,content=def main():\\n    print("Hello World")\\n\\nif __name__ == "__main__":\\n    main())::END_CALL::]

                The above creates a file that looks like:
                def main():
                    print("Hello World")

                if __name__ == "__main__":
                    main()

                Note: The 4 spaces before "print" and "main()" are literal spaces in the content parameter.

                More examples:
                [FUNCTION_CALL:execute_terminal(command=pip3 install requests)::END_CALL::]
                [FUNCTION_CALL:execute_terminal(command=python3 main.py)::END_CALL::]

                When user says "install pyqt5", you MUST execute:
                [FUNCTION_CALL:execute_terminal(command=pip3 install pyqt5)::END_CALL::]
                """
            }
        }
        return ""
    }
    
    private func parseFunctionCallsAndExecute(response: String, completion: @escaping (String, [String]?) -> Void) {
        // Parse function calls using explicit ::END_CALL:: delimiter - no ambiguity!
        var functionCalls: [String] = []
        var cleanedResponse = response
        var actionIndicators: [String] = []

        // Find all [FUNCTION_CALL:...::END_CALL::] patterns
        var searchIndex = response.startIndex
        while searchIndex < response.endIndex {
            if let startRange = response[searchIndex...].range(of: "[FUNCTION_CALL:") {
                // Look for the explicit end delimiter
                if let endRange = response[startRange.upperBound...].range(of: "::END_CALL::]") {
                    // Extract the function call content between delimiters
                    let functionCallStart = startRange.upperBound
                    let functionCallEnd = endRange.lowerBound
                    let functionCall = String(response[functionCallStart..<functionCallEnd])
                    functionCalls.append(functionCall)

                    print("✅ Parsed function call: \(functionCall.prefix(100))...")

                    // Extract function name for action indicator
                    if let parenIndex = functionCall.firstIndex(of: "(") {
                        let functionName = String(functionCall[..<parenIndex])
                        actionIndicators.append(functionName)
                    }

                    // Remove entire function call from cleaned response
                    let fullCallRange = startRange.lowerBound..<endRange.upperBound
                    cleanedResponse = cleanedResponse.replacingOccurrences(of: response[fullCallRange], with: "")

                    searchIndex = endRange.upperBound
                } else {
                    print("⚠️ Found [FUNCTION_CALL: without ::END_CALL::] - skipping")
                    searchIndex = response.index(after: startRange.lowerBound)
                }
            } else {
                break
            }
        }

        print("📋 Found \(functionCalls.count) function calls to execute")

        // Execute function calls sequentially
        executeSequentially(functionCalls: functionCalls, index: 0) {
            let finalCleanedResponse = cleanedResponse.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalResponse = finalCleanedResponse.isEmpty ? "Actions completed." : finalCleanedResponse
            completion(finalResponse, actionIndicators.isEmpty ? nil : actionIndicators)
        }
    }

    private func executeSequentially(functionCalls: [String], index: Int, completion: @escaping () -> Void) {
        guard index < functionCalls.count else {
            completion()
            return
        }

        let functionCall = functionCalls[index]
        print("🔄 Executing function \(index + 1)/\(functionCalls.count): \(functionCall)")

        // Execute this function call - completion is called when animation finishes
        parseSingleFunctionCall(functionCall) { result in
            print("✅ Function completed: \(result ?? "no result")")

            // Move to next function immediately after this one completes
            self.executeSequentially(functionCalls: functionCalls, index: index + 1, completion: completion)
        }
    }
    
    private func parseSingleFunctionCall(_ functionCall: String, completion: @escaping (String?) -> Void) {
        // Parse individual function call like "execute_terminal(command=ls -la)"
        let components = functionCall.split(separator: "(", maxSplits: 1)
        guard components.count == 2 else {
            completion(nil)
            return
        }

        let functionName = String(components[0])
        let paramString = String(components[1]).dropLast() // Remove closing )

        var parameters: [String: String] = [:]

        // Better parameter parsing that handles commas in values
        // Look for parameter pattern: key=value where the next param starts with ,key=
        var currentKey = ""
        var currentValue = ""
        var i = paramString.startIndex

        while i < paramString.endIndex {
            // Look for key=
            if let equalIndex = paramString[i...].firstIndex(of: "=") {
                // Extract key
                currentKey = String(paramString[i..<equalIndex]).trimmingCharacters(in: .whitespaces)
                i = paramString.index(after: equalIndex)

                // Now find the end of the value (either end of string or next ,key=)
                var valueEnd = paramString.endIndex
                var searchIndex = i

                while searchIndex < paramString.endIndex {
                    if paramString[searchIndex] == "," {
                        // Check if this comma is followed by a parameter name (letters followed by =)
                        let afterComma = paramString.index(after: searchIndex)
                        if afterComma < paramString.endIndex {
                            let remaining = paramString[afterComma...]
                            // Look for pattern: word characters followed by =
                            if remaining.range(of: "^\\s*\\w+=", options: .regularExpression) != nil {
                                valueEnd = searchIndex
                                break
                            }
                        }
                    }
                    searchIndex = paramString.index(after: searchIndex)
                }

                currentValue = String(paramString[i..<valueEnd]).trimmingCharacters(in: .whitespaces)
                parameters[currentKey] = currentValue

                // Move to next parameter
                i = valueEnd < paramString.endIndex ? paramString.index(after: valueEnd) : paramString.endIndex
            } else {
                break
            }
        }

        print("📝 Parsed parameters: \(parameters.keys.joined(separator: ", "))")
        for (key, value) in parameters {
            print("   \(key): \(value.count) characters")
            if key == "content" || key == "code" {
                print("   First 100 chars: \(value.prefix(100))")
                print("   Last 100 chars: \(value.suffix(100))")
            }
        }

        executeFunctionCall(functionName: functionName, parameters: parameters, completion: completion)
    }
    
    /// Execute a specific function call
    private func executeFunctionCall(functionName: String, parameters: [String: String], completion: @escaping (String?) -> Void) {
        switch functionName {
        case "insert_text_to_writer":
            if let content = parameters["content"] {
                // Unescape newlines for proper formatting
                let formattedContent = content.replacingOccurrences(of: "\\n", with: "\n")

                // Send notification to WriterDeskView to insert text
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("AIInsertTextToWriter"),
                        object: formattedContent
                    )
                }
                completion("Inserted content into document")
            } else {
                completion(nil)
            }

        case "execute_terminal":
            if let command = parameters["command"] {
                executeTerminalCommandWithAnimation(command: command)
                completion("Executed terminal command: \(command)")
            } else {
                completion(nil)
            }
            
        case "create_file":
            if let fileName = parameters["fileName"], let content = parameters["content"] {
                // Unescape newlines and tabs for proper formatting
                let formattedContent = content
                    .replacingOccurrences(of: "\\n", with: "\n")
                    .replacingOccurrences(of: "\\t", with: "\t")

                createFileWithAnimation(fileName: fileName, content: formattedContent) {
                    completion("Created file: \(fileName)")
                }
            } else {
                completion(nil)
            }

        case "write_code":
            if let fileName = parameters["fileName"], let code = parameters["code"] {
                // Unescape newlines and tabs for proper formatting
                let formattedCode = code
                    .replacingOccurrences(of: "\\n", with: "\n")
                    .replacingOccurrences(of: "\\t", with: "\t")

                writeCodeWithAnimation(code: formattedCode, fileName: fileName) {
                    completion("Wrote code to: \(fileName)")
                }
            } else {
                completion(nil)
            }
            
        case "read_file":
            if let fileName = parameters["fileName"] {
                let content = readFileContent(fileName: fileName)
                completion("Read file: \(fileName) (\(content.count) characters)")
            } else {
                completion(nil)
            }
            
        case "open_file":
            if let fileName = parameters["fileName"] {
                openFileInIDE(fileName: fileName)
                completion("Opened file: \(fileName)")
            } else {
                completion(nil)
            }
            
        default:
            completion(nil)
        }
    }
    
    /// Generate autocomplete response without adding to chat history
    func generateAutocompleteResponse(prompt: String, completion: @escaping (String?) -> Void) {
        let message = ChatMessage(role: "user", content: prompt)
        openAIService.chatCompletion(messages: [message]) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    completion(response)
                case .failure(_):
                    completion(nil)
                }
            }
        }
    }
    
    /// Execute a direct command immediately without AI processing
    func executeDirectCommand(_ command: String, parameters: [String: String]) {
        print("🔧 AI Agent executeDirectCommand called: \(command)")
        print("🔧 Current terminal: \(currentTerminal != nil ? "connected" : "nil")")
        print("🔧 Current IDE manager: \(currentIDEManager != nil ? "connected" : "nil")")

        switch command {
        case "create_file":
            if let fileName = parameters["fileName"], let content = parameters["content"] {
                print("🔧 Creating file: \(fileName)")
                createFileWithAnimation(fileName: fileName, content: content) {
                    // Animation completed
                }
            }
        case "execute_terminal":
            if let command = parameters["command"] {
                print("🔧 Executing terminal command: \(command)")
                executeTerminalCommandWithAnimation(command: command)
            }
        default:
            print("Unknown direct command: \(command)")
        }
    }

    // MARK: - Memory & Persistence

    /// Save a persistent memory that survives app restarts
    func saveMemory(content: String, category: AIMemory.Category) {
        let memory = AIMemory(content: content, category: category, timestamp: Date())
        memories.append(memory)
        persistMemories()
        print("💾 Saved memory: \(content)")
    }

    /// Get memories for a specific category
    func getMemories(for category: AIMemory.Category) -> [AIMemory] {
        return memories.filter { $0.category == category }
    }

    /// Delete a memory
    func deleteMemory(_ memory: AIMemory) {
        memories.removeAll { $0.id == memory.id }
        persistMemories()
    }

    /// Clear all memories
    func clearAllMemories() {
        memories.removeAll()
        persistMemories()
    }

    private func checkAndClearConversationHistory() {
        let sessionStart = UserDefaults.standard.object(forKey: sessionStartKey) as? Date

        // If no session start or it's a new launch, clear history
        if sessionStart == nil || !Calendar.current.isDateInToday(sessionStart!) {
            print("🆕 New session detected - clearing conversation history")
            conversationHistory.removeAll()
            UserDefaults.standard.set(Date(), forKey: sessionStartKey)
        } else {
            print("♻️ Continuing existing session - keeping conversation history")
            // Optionally load saved conversation history here if you want to persist it within a session
        }
    }

    private func loadMemories() {
        if let data = UserDefaults.standard.data(forKey: memoriesKey),
           let decoded = try? JSONDecoder().decode([AIMemory].self, from: data) {
            memories = decoded
            print("💾 Loaded \(memories.count) memories")
        }
    }

    private func persistMemories() {
        if let encoded = try? JSONEncoder().encode(memories) {
            UserDefaults.standard.set(encoded, forKey: memoriesKey)
        }
    }

    /// Get memories as context for AI prompts
    func getMemoriesAsContext() -> String {
        guard !memories.isEmpty else { return "" }

        let memoriesByCategory = Dictionary(grouping: memories) { $0.category }
        var context = "\n\nPersistent Memories (important information to remember):\n"

        for (category, mems) in memoriesByCategory {
            context += "\n\(category.rawValue):\n"
            for memory in mems.prefix(5) { // Limit to 5 per category
                context += "- \(memory.content)\n"
            }
        }

        return context
    }

}

// MARK: - Supporting Types

struct AIMessage {
    enum Role {
        case user
        case assistant
    }

    let role: Role
    let content: String
    let timestamp: Date
    let actionIndicators: [String]?

    init(role: Role, content: String, timestamp: Date, actionIndicators: [String]? = nil) {
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.actionIndicators = actionIndicators
    }
}

struct AIMemory: Codable, Identifiable {
    let id: UUID
    let content: String
    let category: Category
    let timestamp: Date

    init(content: String, category: Category, timestamp: Date) {
        self.id = UUID()
        self.content = content
        self.category = category
        self.timestamp = timestamp
    }

    enum Category: String, Codable {
        case userPreferences = "User Preferences"
        case projectInfo = "Project Information"
        case importantFacts = "Important Facts"
        case workflows = "Workflows & Processes"
        case goals = "Goals & Objectives"
    }
}

struct AIAgentSuggestion: Identifiable {
    let id = UUID()
    let type: SuggestionType
    let title: String
    let description: String
    let action: AIAgentAction?
    
    enum SuggestionType {
        case welcome, productivity, focus, wellbeing, learning, communication, navigation, celebration
        
        var color: String {
            switch self {
            case .welcome: return "blue"
            case .productivity: return "green" 
            case .focus: return "purple"
            case .wellbeing: return "mint"
            case .learning: return "orange"
            case .communication: return "indigo"
            case .navigation: return "gray"
            case .celebration: return "yellow"
            }
        }
    }
}

// MARK: - Supporting Types

struct AIAgentAction {
    let type: ActionType
    let parameters: [String: Any]
    
    enum ActionType {
        case createTodo, switchEnvironment, suggestBreak, analyzeTodos, provideInsight
        case createFile, writeCode, executeTerminal, readFile, openFile
    }
}

enum CodeAction {
    case createFile(name: String, content: String)
    case writeCode(code: String, location: CodeLocation)
    case insertCode(code: String, location: CodeLocation)
    case readFile(name: String)
    case runCode(fileName: String)
    case debugCode(fileName: String)
}

enum CodeLocation {
    case currentFile
    case newFile(name: String)
    case specificFile(name: String)
}

extension TOMEEnvironment {
    static func fromString(_ string: String) -> TOMEEnvironment? {
        switch string.lowercased() {
        case "home": return .home
        case "planning": return .planning  
        case "writer", "writerdesk": return .writerDesk
        case "workshop": return .workshop
        case "coffeeshop", "coffee": return .coffeeshop
        case "garden": return .garden
        default: return nil
        }
    }
}