import Foundation
import UserNotifications
import EventKit
import Contacts
import Combine
import AppKit

class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published var pendingNotifications: [TOMENotification] = []
    @Published var allowedNotifications: [TOMENotification] = []
    @Published var deferredNotifications: [TOMENotification] = []
    @Published var notificationCount: Int = 0
    
    private let openAIService: OpenAIService
    private let tomeState: TOMEState
    private var cancellables = Set<AnyCancellable>()
    private var notificationMonitor: Any?
    private let eventStore = EKEventStore()
    
    init(openAIService: OpenAIService, tomeState: TOMEState) {
        self.openAIService = openAIService
        self.tomeState = tomeState
        super.init()
        
        setupNotificationMonitoring()
        requestNotificationPermissions()
        setupCalendarAccess()
    }
    
    // MARK: - Notification Permissions
    
    private func requestNotificationPermissions() {
        print("Using alternative notification monitoring (no UNUserNotificationCenter required)")
        DispatchQueue.main.async {
            self.startMonitoring()
        }
    }
    
    private func setupCalendarAccess() {
        eventStore.requestAccess(to: .event) { granted, error in
            if granted {
                print("Calendar access granted")
            } else {
                print("Calendar access denied: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    // MARK: - Notification Monitoring
    
    private func setupNotificationMonitoring() {
        print("Setting up notification monitoring with workspace and polling approach")
        
        // Monitor workspace notifications for app changes
        let workspace = NSWorkspace.shared
        workspace.notificationCenter.addObserver(
            self,
            selector: #selector(handleAppActivation(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        
        // Monitor for new notifications via multiple methods (run on background queue)
        Timer.publish(every: 30.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                DispatchQueue.global(qos: .background).async {
                    self?.checkForNewNotifications()
                    self?.checkSlackNotifications()
                    self?.checkSystemNotifications()
                }
            }
            .store(in: &cancellables)
    }
    
    private func startMonitoring() {
        // Start periodic email checking (less frequent, background queue)
        Timer.publish(every: 120.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                DispatchQueue.global(qos: .utility).async {
                    self?.checkEmailInbox()
                    self?.checkUpcomingMeetings()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Notification Handlers
    
    @objc private func handleAppActivation(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let appName = app.localizedName else { return }
        
        // Create notification for app switching
        let appNotification = TOMENotification(
            id: UUID(),
            title: "App Activated",
            content: "\(appName) became active",
            source: appName,
            timestamp: Date()
        )
        
        processNotification(appNotification)
    }
    
    private func checkForNewNotifications() {
        // Monitor notification-related system activity through logs
        checkRecentSystemLogs()
    }
    
    private func checkSlackNotifications() {
        // Check if Slack is running and has unread messages
        let script = """
        try
            tell application "System Events"
                if (name of processes) contains "Slack" then
                    tell application "Slack"
                        try
                            set appName to name
                            return "Slack is running"
                        on error
                            return "Slack running but no access"
                        end try
                    end tell
                else
                    return "Slack not running"
                end if
            end tell
        on error
            return "Error checking Slack"
        end try
        """
        
        executeAppleScript(script) { [weak self] result in
            if let result = result, result.contains("running") {
                let notification = TOMENotification(
                    id: UUID(),
                    title: "Slack Status",
                    content: result,
                    source: "Slack",
                    timestamp: Date()
                )
                DispatchQueue.main.async {
                    self?.processNotification(notification)
                }
            }
        }
    }
    
    private func checkSystemNotifications() {
        // Check for system-level notifications through Activity Monitor or similar
        let script = """
        try
            do shell script "ps aux | grep -i 'notification\\|mail\\|message' | grep -v grep | head -5"
        on error
            return "No notification processes found"
        end try
        """
        
        executeAppleScript(script) { [weak self] result in
            if let result = result, !result.isEmpty && !result.contains("No notification") {
                let notification = TOMENotification(
                    id: UUID(),
                    title: "System Activity",
                    content: "Notification-related processes detected",
                    source: "System",
                    timestamp: Date()
                )
                DispatchQueue.main.async {
                    self?.processNotification(notification)
                }
            }
        }
    }
    
    private func checkRecentSystemLogs() {
        // Check system logs for recent notification activity
        let script = """
        try
            do shell script "log show --predicate 'category == \"notification\" OR subsystem == \"com.apple.usernotifications\"' --last 1m --style compact | tail -5"
        on error
            return ""
        end try
        """
        
        executeAppleScript(script) { [weak self] result in
            if let result = result, !result.isEmpty {
                let lines = result.components(separatedBy: .newlines).filter { !$0.isEmpty }
                for line in lines.prefix(3) {
                    let notification = TOMENotification(
                        id: UUID(),
                        title: "System Log",
                        content: String(line.prefix(100)), // Truncate long lines
                        source: "SystemLog",
                        timestamp: Date()
                    )
                    DispatchQueue.main.async {
                        self?.processNotification(notification)
                    }
                }
            }
        }
    }
    
    // MARK: - Email Inbox Monitoring
    
    private func checkEmailInbox() {
        // Simple AppleScript to check if Mail is running and has unread messages
        let script = """
        try
            tell application "System Events"
                if (name of processes) contains "Mail" then
                    tell application "Mail"
                        set unreadCount to unread count of inbox
                        return unreadCount as string
                    end tell
                else
                    return "0"
                end if
            end tell
        on error
            return "0"
        end try
        """
        
        executeAppleScript(script) { [weak self] result in
            if let result = result, let count = Int(result), count > 0 {
                let emailNotification = TOMENotification(
                    id: UUID(),
                    title: "Unread Emails",
                    content: "You have \(count) unread email\(count == 1 ? "" : "s")",
                    source: "Mail",
                    timestamp: Date()
                )
                
                DispatchQueue.main.async {
                    self?.processNotification(emailNotification)
                }
            }
        }
    }
    
    private func checkUpcomingMeetings() {
        let calendar = Calendar.current
        let now = Date()
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        
        let predicate = eventStore.predicateForEvents(withStart: now, end: endOfDay, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        for event in events {
            let timeUntilEvent = event.startDate.timeIntervalSince(now)
            
            // Notify 10 minutes before meetings
            if timeUntilEvent > 0 && timeUntilEvent <= 600 { // 10 minutes
                let meetingNotification = TOMENotification(
                    id: UUID(),
                    title: "Upcoming Meeting",
                    content: "\(event.title ?? "Meeting") starts in \(Int(timeUntilEvent/60)) minutes",
                    source: "Calendar",
                    timestamp: Date(),
                    type: .calendar,
                    priority: .high,
                    sender: nil
                )
                
                processNotification(meetingNotification)
            }
        }
    }
    
    // MARK: - AI-Powered Notification Processing
    
    private func processNotification(_ notification: TOMENotification) {
        DispatchQueue.main.async {
            self.pendingNotifications.append(notification)
            self.notificationCount = self.pendingNotifications.count
        }
        
        // Analyze with AI based on metaprompt
        analyzeNotificationUrgency(notification) { [weak self] shouldAllow in
            DispatchQueue.main.async {
                if shouldAllow {
                    self?.allowNotification(notification)
                } else {
                    self?.deferNotification(notification)
                }
            }
        }
    }
    
    private func analyzeNotificationUrgency(_ notification: TOMENotification, completion: @escaping (Bool) -> Void) {
        // Enhanced analysis with today's prompt override
        let combinedPrompt = """
        \(tomeState.notificationMetaprompt)
        
        TODAY'S SPECIAL RULES:
        \(tomeState.todayPromptOverride)
        
        Additional context:
        - Current time: \(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short))
        - Session environment: \(tomeState.currentSession?.environment.displayName ?? "None")
        - Active todos: \(tomeState.todos.filter { !$0.isCompleted }.count)
        """
        
        openAIService.analyzeNotificationUrgency(
            notification: notification,
            metaprompt: combinedPrompt
        ) { result in
            switch result {
            case .success(let shouldAllow):
                completion(shouldAllow)
            case .failure(let error):
                print("AI analysis failed: \(error)")
                // Fallback to rule-based filtering
                completion(self.ruleBasedFilter(notification))
            }
        }
    }
    
    private func ruleBasedFilter(_ notification: TOMENotification) -> Bool {
        // Fallback rule-based filtering
        switch notification.type {
        case .calendar:
            return true // Always allow calendar notifications
        case .email:
            return notification.content.lowercased().contains("urgent") ||
                   notification.content.lowercased().contains("important")
        case .message:
            return true // Allow direct messages
        case .slack:
            return notification.priority == .high
        case .other:
            return false // Defer unknown notifications
        }
    }
    
    private func allowNotification(_ notification: TOMENotification) {
        allowedNotifications.append(notification)
        pendingNotifications.removeAll { $0.id == notification.id }
        notificationCount = pendingNotifications.count
        
        // Show notification to user
        presentNotificationToUser(notification)
        
        // Log decision for learning
        logNotificationDecision(notification, action: "ALLOW")
    }
    
    private func deferNotification(_ notification: TOMENotification) {
        deferredNotifications.append(notification)
        pendingNotifications.removeAll { $0.id == notification.id }
        notificationCount = pendingNotifications.count
        
        // Log decision for learning
        logNotificationDecision(notification, action: "DEFER")
    }
    
    private func presentNotificationToUser(_ notification: TOMENotification) {
        let content = UNMutableNotificationContent()
        content.title = "TOME: \(notification.source)"
        content.body = "\(notification.title)\n\(notification.content)"
        content.sound = .default
        content.badge = NSNumber(value: notificationCount)
        
        let request = UNNotificationRequest(
            identifier: notification.id.uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to present notification: \(error)")
            }
        }
    }
    
    // MARK: - Learning System
    
    private func logNotificationDecision(_ notification: TOMENotification, action: String) {
        let decision = NotificationDecision(
            notification: notification,
            correctAction: action,
            timestamp: Date()
        )
        
        // Store in UserDefaults for learning
        var decisions = loadNotificationDecisions()
        decisions.append(decision)
        
        // Keep only last 50 decisions
        if decisions.count > 50 {
            decisions = Array(decisions.suffix(50))
        }
        
        saveNotificationDecisions(decisions)
    }
    
    func markNotificationDecisionIncorrect(_ notificationId: UUID, correctAction: String) {
        // User feedback for improving AI
        if let notification = (allowedNotifications + deferredNotifications).first(where: { $0.id == notificationId }) {
            logNotificationDecision(notification, action: correctAction)
            
            // Trigger metaprompt improvement
            improveMetaprompt()
        }
    }
    
    private func improveMetaprompt() {
        let recentDecisions = loadNotificationDecisions().suffix(10)
        
        openAIService.generateMetapromptSuggestion(
            currentMetaprompt: tomeState.notificationMetaprompt,
            recentDecisions: Array(recentDecisions)
        ) { [weak self] result in
            switch result {
            case .success(let improvedPrompt):
                DispatchQueue.main.async {
                    self?.tomeState.notificationMetaprompt = improvedPrompt
                }
            case .failure(let error):
                print("Failed to improve metaprompt: \(error)")
            }
        }
    }
    
    // MARK: - Persistence
    
    private func saveNotificationDecisions(_ decisions: [NotificationDecision]) {
        if let encoded = try? JSONEncoder().encode(decisions) {
            UserDefaults.standard.set(encoded, forKey: "notification_decisions")
        }
    }
    
    private func loadNotificationDecisions() -> [NotificationDecision] {
        guard let data = UserDefaults.standard.data(forKey: "notification_decisions"),
              let decisions = try? JSONDecoder().decode([NotificationDecision].self, from: data) else {
            return []
        }
        return decisions
    }
    
    // MARK: - Utility Methods
    
    private func determinePriority(from userInfo: [AnyHashable: Any]) -> NotificationPriority {
        let content = (userInfo["body"] as? String ?? "").lowercased()
        let title = (userInfo["title"] as? String ?? "").lowercased()
        
        if content.contains("urgent") || content.contains("emergency") || title.contains("urgent") {
            return .high
        } else if content.contains("important") || title.contains("important") {
            return .medium
        } else {
            return .low
        }
    }
    
    private func executeAppleScript(_ script: String, completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            let appleScript = NSAppleScript(source: script)
            var errorDict: NSDictionary?
            let result = appleScript?.executeAndReturnError(&errorDict)
            
            DispatchQueue.main.async {
                if let error = errorDict {
                    print("AppleScript error: \(error)")
                    completion(nil)
                } else {
                    completion(result?.stringValue)
                }
            }
        }
    }
    
    private func parseEmailResults(_ result: String?) {
        // Parse AppleScript results and create notifications
        guard let result = result, !result.isEmpty else { return }
        
        // Simple parsing - in production you'd use more robust parsing
        let lines = result.components(separatedBy: "\n")
        for line in lines {
            if !line.isEmpty {
                let emailNotification = TOMENotification(
                    id: UUID(),
                    title: "New Email",
                    content: line,
                    source: "Mail",
                    timestamp: Date(),
                    type: .email,
                    priority: .medium,
                    sender: nil
                )
                
                processNotification(emailNotification)
            }
        }
    }
    
    // MARK: - Communication Status
    
    func getCommunicationStatus() -> String {
        let urgentCount = deferredNotifications.filter { $0.priority == .high }.count
        
        if urgentCount == 0 {
            return "None of your emails appear to be urgent. Time to focus!"
        } else {
            let urgentList = deferredNotifications
                .filter { $0.priority == .high }
                .prefix(3)
                .map { "• \($0.sender ?? $0.source): \($0.title)" }
                .joined(separator: "\n")
            
            return """
            You have the following possibly urgent communications:
            \(urgentList)
            """
        }
    }
}

// MARK: - Supporting Types

extension TOMENotification {
    init(id: UUID, title: String, content: String, source: String, timestamp: Date, type: NotificationType, priority: NotificationPriority, sender: String?) {
        self.init(
            id: id,
            title: title,
            content: content,
            source: source,
            timestamp: timestamp
        )
        self.type = type
        self.priority = priority
        self.sender = sender
    }
}

enum NotificationType: String, Codable {
    case email = "email"
    case message = "message"
    case slack = "slack"
    case calendar = "calendar"
    case other = "other"
}

enum NotificationPriority: String, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
}

extension TOMENotification {
    var type: NotificationType {
        get { NotificationType(rawValue: source.lowercased()) ?? .other }
        set { /* Read-only computed property */ }
    }
    
    var priority: NotificationPriority {
        get {
            if content.lowercased().contains("urgent") || content.lowercased().contains("emergency") {
                return .high
            } else if content.lowercased().contains("important") {
                return .medium
            } else {
                return .low
            }
        }
        set { /* Read-only computed property */ }
    }
    
    var sender: String? {
        get { nil } // Would be set during initialization
        set { /* Read-only computed property */ }
    }
}

struct NotificationDecision: Codable {
    let notification: TOMENotification
    let correctAction: String
    let timestamp: Date
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Intercept notifications before they're shown
        let tomeNotification = TOMENotification(
            id: UUID(),
            title: notification.request.content.title,
            content: notification.request.content.body,
            source: notification.request.identifier,
            timestamp: Date()
        )
        
        // Process through our filtering system
        analyzeNotificationUrgency(tomeNotification) { shouldAllow in
            if shouldAllow {
                // Allow the notification to show
                completionHandler([.banner, .sound])
            } else {
                // Block the notification
                completionHandler([])
            }
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification responses
        completionHandler()
    }
}