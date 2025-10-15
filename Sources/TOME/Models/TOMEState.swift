import SwiftUI
import Combine

class TOMEState: ObservableObject {
    @Published var currentSession: FocusSession?
    @Published var todos: [Todo] = []
    @Published var notifications: [TOMENotification] = []
    @Published var projects: [Project] = []
    @Published var isPhoneConnected = false
    @Published var hardwareConnected = false
    @Published var currentEnvironment: TOMEEnvironment = .home
    
    // AI and notification filtering
    @Published var notificationMetaprompt = ""
    @Published var todayPromptOverride = ""
    
    // Environment-specific context
    @Published var currentCoffeeshopArticle: CoffeeshopArticle?
    
    // Services
    @Published var notificationService: NotificationService?
    @Published var applicationService: ApplicationService?
    @Published var openAIService: OpenAIService?
    @Published var projectSpaceService: ProjectSpaceService?
    @Published var globalAIAgent: GlobalAIAgent?
    @Published var focusEnforcementService: FocusEnforcementService?
    @Published var screenCaptureService: ScreenCaptureService?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupDefaultState()
        startHardwareMonitoring()
        initializeServices()
    }
    
    private func setupDefaultState() {
        // Load saved state or initialize defaults
        loadProjects()
        loadNotificationSettings()
        setupProjectServiceBinding()
    }
    
    private func initializeServices() {
        // Initialize OpenAI service first
        openAIService = OpenAIService()
        
        // Initialize notification service with OpenAI dependency
        if let aiService = openAIService {
            notificationService = NotificationService(openAIService: aiService, tomeState: self)
        }
        
        // Initialize application service
        applicationService = ApplicationService()
        
        // Initialize focus enforcement service with application service dependency
        if let appService = applicationService {
            focusEnforcementService = FocusEnforcementService(applicationService: appService)
        }
        
        // Initialize project space service with application service dependency
        if let appService = applicationService {
            projectSpaceService = ProjectSpaceService(applicationService: appService)
        }
        
        // Initialize global AI agent with OpenAI service dependency
        if let aiService = openAIService {
            globalAIAgent = GlobalAIAgent(openAIService: aiService, tomeState: self)
        }
        
        // Initialize screen capture service for creative work monitoring
        if #available(macOS 12.3, *) {
            screenCaptureService = ScreenCaptureService()
        }
    }
    
    private func setupProjectServiceBinding() {
        // Set up binding to keep projects in sync after service initialization
        if let projectService = projectSpaceService {
            projects = projectService.availableProjects
            
            // Set up binding to keep projects in sync
            projectService.$availableProjects
                .receive(on: DispatchQueue.main)
                .assign(to: &$projects)
        }
    }
    
    private func loadProjects() {
        // Projects are now managed by ProjectSpaceService
        // The actual loading happens in setupProjectServiceBinding() after services are initialized
    }
    
    private func loadNotificationSettings() {
        notificationMetaprompt = """
        Allow interruptions for:
        - Direct messages from manager or leadership
        - Emails marked "URGENT" from known contacts
        - Calendar reminders 10 minutes before meetings
        - Security alerts or system failures
        
        Defer everything else to next Writer's Desk session.
        """
    }
    
    private func startHardwareMonitoring() {
        // TODO: Hardware monitoring will be implemented later when hardware is available
        // For now, this is a placeholder for future hardware integration
    }
    
    private func checkHardwareConnection() {
        // TODO: Hardware detection will be implemented later
        // This is a placeholder for future hardware integration
    }
    
    func addTodo(_ text: String) {
        let todo = Todo(
            id: UUID(),
            text: text,
            isCompleted: false,
            estimatedDuration: estimateDuration(for: text),
            priority: determinePriority(for: text)
        )
        todos.append(todo)
        
        // Use AI to enhance the todo if possible
        enhanceTodoWithAI(todo)
    }
    
    func addTodosFromNaturalLanguage(_ input: String, completion: @escaping ([Todo]) -> Void) {
        openAIService?.parseNaturalLanguageTodos(input: input) { [weak self] result in
            switch result {
            case .success(let todoTexts):
                let newTodos = todoTexts.map { text in
                    Todo(
                        id: UUID(),
                        text: text,
                        isCompleted: false,
                        estimatedDuration: self?.estimateDuration(for: text) ?? 900, // 15 min default
                        priority: self?.determinePriority(for: text) ?? .medium
                    )
                }
                
                DispatchQueue.main.async {
                    self?.todos.append(contentsOf: newTodos)
                    completion(newTodos)
                }
                
            case .failure(let error):
                print("Failed to parse todos: \(error)")
                // Fallback to manual parsing
                let lines = input.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                
                let fallbackTodos = lines.map { text in
                    Todo(
                        id: UUID(),
                        text: text,
                        isCompleted: false,
                        estimatedDuration: self?.estimateDuration(for: text) ?? 900,
                        priority: self?.determinePriority(for: text) ?? .medium
                    )
                }
                
                DispatchQueue.main.async {
                    self?.todos.append(contentsOf: fallbackTodos)
                    completion(fallbackTodos)
                }
            }
        }
    }
    
    private func enhanceTodoWithAI(_ todo: Todo) {
        // Get AI-powered duration estimate
        openAIService?.estimateTaskDuration(task: todo.text) { [weak self] result in
            switch result {
            case .success(let aiDuration):
                DispatchQueue.main.async {
                    if let index = self?.todos.firstIndex(where: { $0.id == todo.id }) {
                        self?.todos[index].estimatedDuration = aiDuration
                        self?.todos[index].aiEnhanced = true
                    }
                }
            case .failure(let error):
                print("AI duration estimation failed: \(error)")
            }
        }
    }
    
    private func determinePriority(for text: String) -> Todo.Priority {
        let lowercased = text.lowercased()
        
        // High priority keywords
        let highPriorityKeywords = ["urgent", "asap", "critical", "emergency", "deadline", "important", "due today"]
        if highPriorityKeywords.contains(where: { lowercased.contains($0) }) {
            return .high
        }
        
        // Low priority keywords
        let lowPriorityKeywords = ["someday", "maybe", "when free", "low priority", "nice to have"]
        if lowPriorityKeywords.contains(where: { lowercased.contains($0) }) {
            return .low
        }
        
        return .medium
    }
    
    func completeTodo(_ id: UUID) {
        if let index = todos.firstIndex(where: { $0.id == id }) {
            todos[index].isCompleted.toggle()
            todos[index].completedAt = todos[index].isCompleted ? Date() : nil
        }
    }
    
    func startSession(environment: TOMEEnvironment, duration: TimeInterval) {
        currentSession = FocusSession(
            id: UUID(),
            environment: environment,
            startTime: Date(),
            plannedDuration: duration,
            todos: todos.filter { !$0.isCompleted }
        )
        
        // Switch to the new environment
        switchToEnvironment(environment)
    }
    
    func switchToEnvironment(_ environment: TOMEEnvironment) {
        currentEnvironment = environment
        
        // Update notification filtering immediately
        updateNotificationFiltering(for: environment)
        
        // Activate focus enforcement for this environment
        activateFocusEnforcement(for: environment)
        
        print("Switched to environment: \(environment.displayName)")
        
        // Configure applications and windows in background to avoid UI delays
        DispatchQueue.global(qos: .userInitiated).async {
            self.applicationService?.setEnvironment(environment)
            self.applicationService?.arrangeWindows(for: environment)
        }
    }
    
    // MARK: - Focus Enforcement
    
    func activateFocusEnforcement(for environment: TOMEEnvironment) {
        // Determine appropriate focus mode based on environment
        let focusMode: FocusMode = determineFocusMode(for: environment)
        
        // Activate focus enforcement
        focusEnforcementService?.activateFocusMode(focusMode, environment: environment)
        
        print("🎯 Activated \(focusMode.displayName) focus mode for \(environment.displayName)")
    }
    
    func deactivateFocusEnforcement() {
        focusEnforcementService?.deactivateFocusMode()
    }
    
    func requestFocusOverride(for appName: String, duration: TimeInterval = 300) {
        focusEnforcementService?.requestFocusOverride(for: appName, duration: duration)
    }
    
    private func determineFocusMode(for environment: TOMEEnvironment) -> FocusMode {
        // Determine focus mode based on environment characteristics
        switch environment {
        case .workshop:
            return .balanced // Allow some flexibility for creative work
        case .writerDesk:
            return .strict // Writing requires deep focus
        case .planning:
            return .balanced // Planning needs moderate focus
        case .coffeeshop:
            return .lenient // Research environment is more relaxed
        case .garden:
            return .lenient // Relaxation mode
        case .home:
            return .disabled // No enforcement on home screen
        }
    }
    
    // MARK: - Project Management
    
    func createProject(name: String, environment: TOMEEnvironment) -> Project? {
        return projectSpaceService?.createProject(name: name, environment: environment)
    }
    
    func switchToProject(_ project: Project) {
        projectSpaceService?.switchToProject(project)
        // The environment will be updated through the project's environment
        switchToEnvironment(project.environment)
    }
    
    func archiveProject(_ project: Project) {
        projectSpaceService?.archiveProject(project)
    }
    
    func getCurrentProject() -> Project? {
        return projectSpaceService?.currentProject
    }
    
    private func updateNotificationFiltering(for environment: TOMEEnvironment) {
        // Adjust notification metaprompt based on environment
        let environmentPrompts: [TOMEEnvironment: String] = [
            .workshop: """
            FOCUS MODE: Deep work session active.
            Only allow:
            - Build/deployment failures or critical errors
            - Direct messages from team leads about current project
            - Calendar reminders for stand-ups or project meetings
            - Security alerts
            
            Defer everything else until break or session end.
            """,
            
            .writerDesk: """
            COMMUNICATION MODE: Writing and messaging active.
            Allow:
            - All direct messages and emails
            - Urgent communication from clients or team
            - Meeting invitations and calendar updates
            - Document collaboration requests
            
            Defer:
            - Social media notifications
            - Non-urgent system updates
            """,
            
            .coffeeshop: """
            RESEARCH MODE: Learning and exploration active.
            Allow:
            - Research-related notifications
            - Educational content alerts
            - Calendar reminders for learning sessions
            - Important emails from research sources
            
            Defer:
            - Work-related notifications (unless urgent)
            - Social distractions
            """,
            
            .garden: """
            MINDFULNESS MODE: Rest and reflection active.
            Only allow:
            - Emergency calls or messages
            - Health-related alerts
            - Family emergency notifications
            
            Defer everything else to maintain peace and focus.
            """,
            
            .planning: """
            PLANNING MODE: Organization and preparation active.
            Allow:
            - Calendar notifications
            - Task and project management updates
            - Meeting requests and scheduling
            - Goal-related reminders
            
            Moderate all other notifications.
            """
        ]
        
        if let environmentPrompt = environmentPrompts[environment] {
            notificationMetaprompt = environmentPrompt
        }
    }
    
    func endSession() {
        guard var session = currentSession else { return }
        session.endTime = Date()
        currentSession = nil
        
        // Archive completed session
        archiveSession(session)
    }
    
    private func estimateDuration(for text: String) -> TimeInterval {
        // Simple heuristic for duration estimation
        let wordCount = text.split(separator: " ").count
        let baseMinutes = max(15, wordCount * 2)
        return TimeInterval(baseMinutes * 60)
    }
    
    private func archiveSession(_ session: FocusSession) {
        // Create session archive record
        let archive = SessionArchive(
            session: session,
            completedTodos: session.todos.filter { $0.isCompleted }.count,
            totalTodos: session.todos.count,
            productivity: calculateProductivityScore(session),
            archivedAt: Date()
        )
        
        // Store in UserDefaults for now (could be CoreData or CloudKit later)
        saveSessionArchive(archive)
        
        // Generate session summary
        generateSessionSummary(archive)
    }
    
    private func calculateProductivityScore(_ session: FocusSession) -> Double {
        guard let actualDuration = session.actualDuration else { return 0.0 }
        
        let completedTodos = session.todos.filter { $0.isCompleted }.count
        let totalTodos = session.todos.count
        
        let completionRate = totalTodos > 0 ? Double(completedTodos) / Double(totalTodos) : 0.0
        let timeEfficiency = min(1.0, session.plannedDuration / actualDuration)
        
        // Weighted score: 70% completion rate, 30% time efficiency
        return (completionRate * 0.7) + (timeEfficiency * 0.3)
    }
    
    private func saveSessionArchive(_ archive: SessionArchive) {
        let userDefaults = UserDefaults.standard
        var existingArchives = loadSessionArchives()
        existingArchives.append(archive)
        
        // Keep only last 100 sessions
        if existingArchives.count > 100 {
            existingArchives = Array(existingArchives.suffix(100))
        }
        
        if let encoded = try? JSONEncoder().encode(existingArchives) {
            userDefaults.set(encoded, forKey: "session_archives")
        }
    }
    
    private func loadSessionArchives() -> [SessionArchive] {
        let userDefaults = UserDefaults.standard
        guard let data = userDefaults.data(forKey: "session_archives"),
              let archives = try? JSONDecoder().decode([SessionArchive].self, from: data) else {
            return []
        }
        return archives
    }
    
    private func generateSessionSummary(_ archive: SessionArchive) {
        let summary = """
        Session Complete!
        
        Environment: \(archive.session.environment.displayName)
        Duration: \(formatDuration(archive.session.actualDuration ?? 0))
        Completed: \(archive.completedTodos)/\(archive.totalTodos) todos
        Productivity Score: \(Int(archive.productivity * 100))%
        """
        
        // This could trigger a notification or update UI
        print(summary)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    // MARK: - Communication Status
    
    func getCommunicationStatus() -> String {
        return notificationService?.getCommunicationStatus() ?? "Communication monitoring not available"
    }
    
    func getActiveApplications() -> [String] {
        return applicationService?.runningApplications.map { $0.name } ?? []
    }
    
    func launchApplication(_ appName: String) -> Bool {
        return applicationService?.launchApplication(appName) ?? false
    }
    
    func quitApplication(_ appName: String) -> Bool {
        return applicationService?.quitApplication(appName) ?? false
    }
    
    // MARK: - Intelligent Todo Suggestions
    
    func suggestNextTodo() -> Todo? {
        let incompleteTodos = todos.filter { !$0.isCompleted }
        
        // Prioritize by: high priority first, then by estimated duration (shorter first)
        let sortedTodos = incompleteTodos.sorted { first, second in
            if first.priority != second.priority {
                return first.priority.rawValue > second.priority.rawValue
            }
            return first.estimatedDuration < second.estimatedDuration
        }
        
        return sortedTodos.first
    }
    
    func getProductivityInsights() -> ProductivityInsights {
        let archives = loadSessionArchives()
        let recentSessions = archives.suffix(10) // Last 10 sessions
        
        let avgProductivity = recentSessions.isEmpty ? 0.0 : 
            recentSessions.map { $0.productivity }.reduce(0, +) / Double(recentSessions.count)
        
        let totalFocusTime = recentSessions.compactMap { $0.session.actualDuration }.reduce(0, +)
        
        let completedTodosToday = todos.filter { todo in
            guard let completedAt = todo.completedAt else { return false }
            return Calendar.current.isDateInToday(completedAt)
        }.count
        
        return ProductivityInsights(
            averageProductivity: avgProductivity,
            totalFocusTime: totalFocusTime,
            completedTodosToday: completedTodosToday,
            currentStreak: calculateCurrentStreak(from: archives),
            topEnvironment: getMostProductiveEnvironment(from: Array(recentSessions))
        )
    }
    
    private func calculateCurrentStreak(from archives: [SessionArchive]) -> Int {
        let calendar = Calendar.current
        var streak = 0
        let currentDate = Date()
        
        for i in stride(from: 0, to: 30, by: 1) { // Check last 30 days
            let date = calendar.date(byAdding: .day, value: -i, to: currentDate) ?? currentDate
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            
            let sessionsOnDay = archives.filter { archive in
                archive.session.startTime >= dayStart && archive.session.startTime < dayEnd
            }
            
            if sessionsOnDay.isEmpty {
                break
            } else {
                streak += 1
            }
        }
        
        return streak
    }
    
    private func getMostProductiveEnvironment(from sessions: [SessionArchive]) -> TOMEEnvironment {
        let environmentProductivity = Dictionary(grouping: sessions) { $0.session.environment }
            .mapValues { sessions in
                sessions.map { $0.productivity }.reduce(0, +) / Double(sessions.count)
            }
        
        return environmentProductivity.max(by: { $0.value < $1.value })?.key ?? .workshop
    }
}

struct FocusSession: Identifiable, Codable {
    let id: UUID
    let environment: TOMEEnvironment
    let startTime: Date
    let plannedDuration: TimeInterval
    var endTime: Date?
    var todos: [Todo]
    
    var actualDuration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }
    
    var isActive: Bool {
        endTime == nil
    }
}

struct Todo: Identifiable, Codable {
    let id: UUID
    var text: String
    var isCompleted: Bool
    var estimatedDuration: TimeInterval
    var actualDuration: TimeInterval?
    var completedAt: Date?
    var priority: Priority
    var aiEnhanced: Bool = false
    var category: String?
    var dependencies: [UUID] = []
    
    enum Priority: String, CaseIterable, Codable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        
        var color: Color {
            switch self {
            case .low: return .gray
            case .medium: return .blue
            case .high: return .red
            }
        }
    }
}

struct Project: Identifiable, Codable {
    let id: UUID
    var name: String
    var environment: TOMEEnvironment
    var state: ProjectState
}

struct ProjectState: Codable {
    var openFiles: [String] = []
    var windowPositions: [String: CGRect] = [:]
    var lastAccessed: Date = Date()
}

// Enhanced notification structure for the service
struct TOMENotification: Identifiable, Codable {
    let id: UUID
    let title: String
    let content: String
    let source: String
    let timestamp: Date
    var isAllowed: Bool = false
    var isDeferred: Bool = false
}

struct SessionArchive: Identifiable, Codable {
    let id = UUID()
    let session: FocusSession
    let completedTodos: Int
    let totalTodos: Int
    let productivity: Double
    let archivedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case session, completedTodos, totalTodos, productivity, archivedAt
    }
}

struct ProductivityInsights: Codable {
    let averageProductivity: Double
    let totalFocusTime: TimeInterval
    let completedTodosToday: Int
    let currentStreak: Int
    let topEnvironment: TOMEEnvironment
    
    var formattedFocusTime: String {
        let hours = Int(totalFocusTime) / 3600
        let minutes = (Int(totalFocusTime) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var productivityPercentage: String {
        return "\(Int(averageProductivity * 100))%"
    }
}

// MARK: - Environment Context

struct CoffeeshopArticle {
    let title: String
    let author: String?
    let content: String
    let summary: String
    let url: String
    let source: String
}