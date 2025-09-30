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
    
    private let openAIService: OpenAIService
    private weak var tomeState: TOMEState?
    private var cancellables = Set<AnyCancellable>()
    
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
        
        setupContextMonitoring()
        generateInitialSuggestions()
    }
    
    // MARK: - Public Interface
    
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
        
        let contextualPrompt = buildContextualPromptWithFunctions(userMessage: message)
        let chatMessages = [ChatMessage(role: "user", content: contextualPrompt)]
        
        openAIService.chatCompletion(messages: chatMessages, model: "gpt-3.5-turbo") { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    // Parse and execute any function calls in the response
                    self?.parseFunctionCallsAndExecute(response: response) { executedActions in
                        var finalResponse = response
                        
                        if let actionResult = executedActions, !actionResult.isEmpty {
                            finalResponse = "\(response)\n\n✅ \(actionResult)"
                        }
                        
                        let aiMessage = AIMessage(role: .assistant, content: finalResponse, timestamp: Date())
                        self?.conversationHistory.append(aiMessage)
                        completion(.success(finalResponse))
                    }
                    
                case .failure(let error):
                    completion(.failure(error))
                }
            }
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
                createFileWithAnimation(fileName: fileName, content: content)
            }
            
        case .writeCode:
            if let code = action.parameters["code"] as? String,
               let fileName = action.parameters["fileName"] as? String {
                writeCodeWithAnimation(code: code, fileName: fileName)
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
    private func createFileWithAnimation(fileName: String, content: String) {
        guard let ideManager = currentIDEManager else { return }
        
        DispatchQueue.main.async {
            // Create the file in the IDE manager
            let newFile = IDEFile(name: fileName, path: "", isDirectory: false, content: content)
            ideManager.createFile(newFile)
            
            // Open the file for editing
            self.openFileInIDE(fileName: fileName)
            
            // Animate typing the content
            self.animateTypingCode(content: content)
        }
    }
    
    /// Write code to existing file with animation
    private func writeCodeWithAnimation(code: String, fileName: String) {
        guard let ideManager = currentIDEManager else { return }
        
        DispatchQueue.main.async {
            // Find and open the file
            if let file = ideManager.openFiles.first(where: { $0.name == fileName }) {
                // Update file content
                var updatedFile = file
                updatedFile.content = code
                ideManager.updateFile(updatedFile)
                
                // Animate typing the new code
                self.animateTypingCode(content: code)
            } else {
                // File doesn't exist, create it
                self.createFileWithAnimation(fileName: fileName, content: code)
            }
        }
    }
    
    /// Execute terminal command with fast typing animation
    private func executeTerminalCommandWithAnimation(command: String) {
        guard let terminal = currentTerminal else { return }
        
        DispatchQueue.main.async {
            // Animate typing the command
            self.animateTypingTerminalCommand(command: command) {
                // Execute the command after typing animation
                terminal.executeCommand(command)
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
    private func animateTypingCode(content: String) {
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
        
        return """
        You are TOME's global AI assistant, helping users with productivity and focus across different work environments.
        
        Current Context:
        - Environment: \(currentEnvironment.displayName) - \(environmentContext)
        - Active Todos: \(currentTodos.filter { !$0.isCompleted }.count)
        - Recent Activity: \(activityContext)
        \(articleContext)
        
        Todo Context: \(todoContext)
        
        User Message: "\(userMessage)"
        
        Respond as a helpful, concise assistant that can:
        1. Help manage tasks and todos
        2. Suggest environment switches for optimal work
        3. Provide productivity insights
        4. Execute actions like creating todos or switching environments
        5. Summarize or analyze articles currently being read
        \(getEnvironmentSpecificCapabilities())
        
        Keep responses conversational and actionable. If you can help with specific actions, mention them clearly.
        \(getEnvironmentSpecificInstructions())
        """
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
        case .workshop:
            if let tool = currentWorkshopTool {
                switch tool {
                case .terminal:
                    return """
                    
                    Workshop Terminal Instructions:
                    - Automatically execute safe terminal commands when the user asks for navigation or file operations
                    - When suggesting commands, prioritize actually executing them in the embedded terminal
                    - For navigation requests like "go to desktop" or "show me files", execute the commands directly
                    - Provide command explanations after execution to help the user learn
                    - Focus on filesystem navigation, git operations, and development tool commands
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
        case .writerDesk:
            return """
            
            Writer's Desk Instructions:
            - Provide specific writing examples and templates
            - Focus on clarity, tone, and audience appropriateness
            - Suggest structural improvements for better flow
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
        
        IMPORTANT: When you want to perform actions, use the function call format:
        [FUNCTION_CALL:function_name(param1=value1,param2=value2)]
        """
    }
    
    /// Get available function definitions for AI
    private func getFunctionDefinitions() -> String {
        if currentEnvironment == .workshop {
            if currentWorkshopTool == .terminal {
                return """
                Available Functions:
                - execute_terminal(command=string): Execute a terminal command
                
                Example: [FUNCTION_CALL:execute_terminal(command=ls -la)]
                """
            } else if currentWorkshopTool == .vscode {
                return """
                Available Functions:
                - create_file(fileName=string,content=string): Create a new file
                - write_code(fileName=string,code=string): Write code to existing file
                - read_file(fileName=string): Read file contents
                - open_file(fileName=string): Open file in IDE
                
                Examples:
                [FUNCTION_CALL:create_file(fileName=main.py,content=print("Hello World"))]
                [FUNCTION_CALL:write_code(fileName=main.py,code=def hello(): print("Hi"))]
                """
            }
        }
        return ""
    }
    
    private func parseFunctionCallsAndExecute(response: String, completion: @escaping (String?) -> Void) {
        // Parse function calls from response and execute them
        let functionPattern = "\\[FUNCTION_CALL:([^\\]]+)\\]"
        
        do {
            let regex = try NSRegularExpression(pattern: functionPattern, options: [])
            let matches = regex.matches(in: response, options: [], range: NSRange(location: 0, length: response.count))
            
            for match in matches {
                if let range = Range(match.range(at: 1), in: response) {
                    let functionCall = String(response[range])
                    parseSingleFunctionCall(functionCall) { _ in
                        // Function executed
                    }
                }
            }
            
            // Return the original response instead of just "Functions executed"
            let responseWithoutFunctionCalls = response.replacingOccurrences(
                of: "\\[FUNCTION_CALL:[^\\]]+\\]", 
                with: "", 
                options: .regularExpression
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            
            completion(responseWithoutFunctionCalls.isEmpty ? "Actions completed successfully." : responseWithoutFunctionCalls)
        } catch {
            completion(nil)
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
        // Simple parameter parsing - could be enhanced
        let paramPairs = paramString.split(separator: ",")
        for pair in paramPairs {
            let keyValue = pair.split(separator: "=", maxSplits: 1)
            if keyValue.count == 2 {
                let key = String(keyValue[0]).trimmingCharacters(in: .whitespaces)
                let value = String(keyValue[1]).trimmingCharacters(in: .whitespaces)
                parameters[key] = value
            }
        }
        
        executeFunctionCall(functionName: functionName, parameters: parameters, completion: completion)
    }
    
    /// Execute a specific function call
    private func executeFunctionCall(functionName: String, parameters: [String: String], completion: @escaping (String?) -> Void) {
        switch functionName {
        case "execute_terminal":
            if let command = parameters["command"] {
                executeTerminalCommandWithAnimation(command: command)
                completion("Executed terminal command: \(command)")
            } else {
                completion(nil)
            }
            
        case "create_file":
            if let fileName = parameters["fileName"], let content = parameters["content"] {
                createFileWithAnimation(fileName: fileName, content: content)
                completion("Created file: \(fileName)")
            } else {
                completion(nil)
            }
            
        case "write_code":
            if let fileName = parameters["fileName"], let code = parameters["code"] {
                writeCodeWithAnimation(code: code, fileName: fileName)
                completion("Wrote code to: \(fileName)")
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
                createFileWithAnimation(fileName: fileName, content: content)
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