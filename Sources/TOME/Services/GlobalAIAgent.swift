import Foundation
import Combine

/// Global AI Agent that provides intelligent assistance across all TOME environments
/// Integrates with todos, environments, and provides contextual help
class GlobalAIAgent: ObservableObject {
    @Published var isActive = false
    @Published var conversationHistory: [AIMessage] = []
    @Published var suggestions: [AIAgentSuggestion] = []
    @Published var contextualTips: [String] = []
    
    private let openAIService: OpenAIService
    private weak var tomeState: TOMEState?
    private var cancellables = Set<AnyCancellable>()
    
    // Context awareness
    private var currentEnvironment: TOMEEnvironment = .home
    private var currentTodos: [Todo] = []
    private var userActivity: [String] = []
    
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
        
        let contextualPrompt = buildContextualPrompt(userMessage: message)
        let chatMessages = [ChatMessage(role: "user", content: contextualPrompt)]
        
        openAIService.chatCompletion(messages: chatMessages, model: "gpt-3.5-turbo") { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    let aiMessage = AIMessage(role: .assistant, content: response, timestamp: Date())
                    self?.conversationHistory.append(aiMessage)
                    completion(.success(response))
                    
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Execute an AI agent action (like creating todos, switching environments)
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
            }
        }
    }
    
    /// Get contextual suggestions based on current state
    func getContextualSuggestions() -> [AIAgentSuggestion] {
        return suggestions
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
        
        Keep responses conversational and actionable. If you can help with specific actions, mention them clearly.
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
            return "Development and creation"
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
        switch environment {
        case .planning:
            addSuggestion(AIAgentSuggestion(
                type: .productivity,
                title: "Planning Session",
                description: "Great time to review and organize your tasks. Consider doing a brain dump of everything on your mind.",
                action: nil
            ))
            
        case .workshop:
            addSuggestion(AIAgentSuggestion(
                type: .focus,
                title: "Deep Work Mode",
                description: "Perfect for focused development work. I'll minimize distractions and track your progress.",
                action: nil
            ))
            
        case .garden:
            addSuggestion(AIAgentSuggestion(
                type: .wellbeing,
                title: "Mindful Moment",
                description: "Take this time to reflect and recharge. The AI dialogue can help with introspective questions.",
                action: nil
            ))
            
        case .coffeeshop:
            addSuggestion(AIAgentSuggestion(
                type: .learning,
                title: "Research Session",
                description: "Perfect for exploration and learning. I can help find connections between your research and current projects.",
                action: nil
            ))
            
        case .writerDesk:
            addSuggestion(AIAgentSuggestion(
                type: .communication,
                title: "Communication Hub",
                description: "Great for handling messages and writing. I can help draft responses or organize your communications.",
                action: nil
            ))
            
        case .home:
            addSuggestion(AIAgentSuggestion(
                type: .navigation,
                title: "Choose Your Environment",
                description: "Which environment matches your current energy and goals? I can help you decide.",
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

struct AIAgentAction {
    let type: ActionType
    let parameters: [String: Any]
    
    enum ActionType {
        case createTodo, switchEnvironment, suggestBreak, analyzeTodos, provideInsight
    }
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