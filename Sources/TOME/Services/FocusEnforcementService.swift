import Foundation
import AppKit
import Combine
import UserNotifications

class FocusEnforcementService: ObservableObject {
    @Published var isEnforcementActive = false
    @Published var currentFocusMode: FocusMode = .balanced
    @Published var enforcementStrength: EnforcementStrength = .medium
    @Published var blockedAppsToday: [String] = []
    @Published var focusViolations: Int = 0
    
    private var cancellables = Set<AnyCancellable>()
    private var enforcementTimer: Timer?
    private var applicationService: ApplicationService
    private let workspace = NSWorkspace.shared
    
    // Focus rules for different environments
    private let environmentFocusRules: [TOMEEnvironment: FocusRules] = [
        .workshop: FocusRules(
            allowedCategories: [.development, .design, .browser],
            blockedKeywords: ["social", "entertainment", "games", "video", "streaming"],
            maxNonFocusTime: 300, // 5 minutes
            breakReminder: 3600 // 1 hour
        ),
        .writerDesk: FocusRules(
            allowedCategories: [.writing, .communication, .research],
            blockedKeywords: ["games", "entertainment", "video", "streaming", "social"],
            maxNonFocusTime: 180, // 3 minutes
            breakReminder: 2700 // 45 minutes
        ),
        .coffeeshop: FocusRules(
            allowedCategories: [.browser, .research, .notes, .reading],
            blockedKeywords: ["games", "entertainment", "development", "work"],
            maxNonFocusTime: 600, // 10 minutes
            breakReminder: 5400 // 90 minutes
        ),
        .planning: FocusRules(
            allowedCategories: [.planning, .notes, .calendar, .tasks],
            blockedKeywords: ["games", "entertainment", "social", "video"],
            maxNonFocusTime: 120, // 2 minutes
            breakReminder: 1800 // 30 minutes
        ),
        .garden: FocusRules(
            allowedCategories: [.meditation, .music, .reading, .relaxation],
            blockedKeywords: ["work", "development", "email", "slack"],
            maxNonFocusTime: 900, // 15 minutes
            breakReminder: 7200 // 2 hours
        )
    ]
    
    private var nonFocusStartTime: Date?
    private var lastBreakReminder: Date?
    
    init(applicationService: ApplicationService) {
        self.applicationService = applicationService
        setupEnforcement()
        loadEnforcementSettings()
    }
    
    // MARK: - Public Interface
    
    func activateFocusMode(_ mode: FocusMode, environment: TOMEEnvironment) {
        currentFocusMode = mode
        isEnforcementActive = true
        
        print("🎯 Activating focus mode: \(mode) for environment: \(environment)")
        
        // Configure enforcement based on mode
        switch mode {
        case .strict:
            enforcementStrength = .strict
        case .balanced:
            enforcementStrength = .medium
        case .lenient:
            enforcementStrength = .lenient
        case .disabled:
            isEnforcementActive = false
            return
        }
        
        // Apply environment-specific rules
        if let rules = environmentFocusRules[environment] {
            applyFocusRules(rules, for: environment)
        }
        
        startEnforcementTimer()
        showFocusModeNotification(mode, environment: environment)
    }
    
    func deactivateFocusMode() {
        isEnforcementActive = false
        currentFocusMode = .disabled
        stopEnforcementTimer()
        
        print("🔓 Focus mode deactivated")
        showFocusModeDeactivatedNotification()
    }
    
    func requestFocusOverride(for appName: String, duration: TimeInterval = 300) {
        // Allow temporary override for specific app
        let override = FocusOverride(
            appName: appName,
            granted: Date(),
            duration: duration
        )
        
        addTemporaryOverride(override)
        showOverrideGrantedNotification(appName, duration: duration)
    }
    
    func reportFocusViolation(_ appName: String) {
        focusViolations += 1
        blockedAppsToday.append(appName)
        
        // Track non-focus behavior
        if nonFocusStartTime == nil {
            nonFocusStartTime = Date()
        }
        
        print("⚠️ Focus violation: \(appName) (Total today: \(focusViolations))")
        
        // Escalate enforcement if too many violations
        if focusViolations >= 5 {
            escalateEnforcement()
        }
    }
    
    // MARK: - Focus Rules Application
    
    private func applyFocusRules(_ rules: FocusRules, for environment: TOMEEnvironment) {
        // Get all running applications
        let runningApps = workspace.runningApplications
        
        for app in runningApps {
            guard let appName = app.localizedName,
                  let bundleId = app.bundleIdentifier else { continue }
            
            if shouldBlockApplication(appName, bundleId: bundleId, rules: rules) {
                blockApplication(app, rules: rules)
            }
        }
    }
    
    private func shouldBlockApplication(_ appName: String, bundleId: String, rules: FocusRules) -> Bool {
        // Don't block system applications
        if isSystemApplication(appName) || appName == "TOME" {
            return false
        }
        
        // Check if app matches blocked keywords
        let appNameLower = appName.lowercased()
        let bundleIdLower = bundleId.lowercased()
        
        for keyword in rules.blockedKeywords {
            if appNameLower.contains(keyword.lowercased()) || bundleIdLower.contains(keyword.lowercased()) {
                return true
            }
        }
        
        // Check against known distracting applications
        return isDistractingApplication(appName, bundleId: bundleId)
    }
    
    private func isDistractingApplication(_ appName: String, bundleId: String) -> Bool {
        let distractingApps = [
            "Netflix", "YouTube", "Twitch", "TikTok", "Instagram",
            "Facebook", "Twitter", "Discord", "Steam", "Epic Games",
            "Spotify", "Apple Music", "VLC", "QuickTime Player",
            "Games", "Chess", "Solitaire", "Angry Birds"
        ]
        
        let distractingBundleIds = [
            "com.netflix.Netflix",
            // Removed Chrome - TOME now uses Chrome for development and shouldn't kill it
            "com.valvesoftware.steam",
            "com.epicgames.launcher",
            "com.twitterrific.mac",
            "com.facebook.archon",
            "com.spotify.client"
        ]
        
        return distractingApps.contains { $0.lowercased() == appName.lowercased() } ||
               distractingBundleIds.contains { $0.lowercased() == bundleId.lowercased() }
    }
    
    private func isSystemApplication(_ appName: String) -> Bool {
        let systemApps = [
            "Finder", "System Preferences", "Activity Monitor", "Console",
            "Terminal", "System Information", "Keychain Access",
            "Migration Assistant", "Boot Camp Assistant", "Disk Utility",
            "Network Utility", "Directory Utility", "System Events",
            "loginwindow", "WindowServer", "Dock", "Control Center"
        ]
        
        return systemApps.contains(appName)
    }
    
    // MARK: - Enforcement Actions
    
    private func blockApplication(_ app: NSRunningApplication, rules: FocusRules) {
        guard let appName = app.localizedName else { return }
        
        print("🚫 Blocking application: \(appName)")
        
        // Record the violation
        reportFocusViolation(appName)
        
        // Apply enforcement action based on strength
        switch enforcementStrength {
        case .lenient:
            // Just hide the app
            hideApplication(app)
            showLenientBlockNotification(appName)
            
        case .medium:
            // Gracefully quit the app
            if !app.terminate() {
                hideApplication(app)
            }
            showMediumBlockNotification(appName)
            
        case .strict:
            // Force quit the app
            app.forceTerminate()
            showStrictBlockNotification(appName)
        }
    }
    
    private func hideApplication(_ app: NSRunningApplication) {
        app.hide()
    }
    
    // MARK: - Timer and Monitoring
    
    private func setupEnforcement() {
        // Monitor app launches
        workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                self?.handleApplicationLaunched(app)
            }
        }
        
        // Monitor app activations
        workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                self?.handleApplicationActivated(app)
            }
        }
    }
    
    private func startEnforcementTimer() {
        stopEnforcementTimer()
        
        enforcementTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.performEnforcementCheck()
        }
    }
    
    private func stopEnforcementTimer() {
        enforcementTimer?.invalidate()
        enforcementTimer = nil
    }
    
    private func performEnforcementCheck() {
        guard isEnforcementActive else { return }
        
        // Check for break reminders
        checkBreakReminder()
        
        // Check for excessive non-focus time
        checkNonFocusTime()
        
        // Perform active enforcement scan
        scanAndEnforceApplications()
    }
    
    private func handleApplicationLaunched(_ app: NSRunningApplication) {
        guard isEnforcementActive,
              let appName = app.localizedName,
              let bundleId = app.bundleIdentifier else { return }
        
        // Get current environment rules (you'd need to track current environment)
        // For now, use a default ruleset
        let rules = FocusRules(
            allowedCategories: [.development, .writing],
            blockedKeywords: ["social", "games", "entertainment"],
            maxNonFocusTime: 300,
            breakReminder: 3600
        )
        
        if shouldBlockApplication(appName, bundleId: bundleId, rules: rules) {
            // Small delay to allow app to fully launch
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.blockApplication(app, rules: rules)
            }
        }
    }
    
    private func handleApplicationActivated(_ app: NSRunningApplication) {
        guard isEnforcementActive,
              let appName = app.localizedName else { return }
        
        print("👀 Application activated: \(appName)")
        
        // Reset non-focus timer if switching to focused app
        if isFocusedApplication(appName) {
            nonFocusStartTime = nil
        }
    }
    
    private func isFocusedApplication(_ appName: String) -> Bool {
        // Define focused applications based on current environment
        let focusedApps = [
            "Visual Studio Code", "Xcode", "Terminal", "TOME",
            "Safari", "Google Chrome", "Pages", "Microsoft Word", "Notion"
        ]
        
        return focusedApps.contains(appName)
    }
    
    // MARK: - Break and Time Management
    
    private func checkBreakReminder() {
        // Implementation would depend on current environment rules
        let now = Date()
        
        if let lastBreak = lastBreakReminder {
            let timeSinceBreak = now.timeIntervalSince(lastBreak)
            if timeSinceBreak >= 3600 { // 1 hour
                showBreakReminderNotification()
                lastBreakReminder = now
            }
        } else {
            lastBreakReminder = now
        }
    }
    
    private func checkNonFocusTime() {
        guard let startTime = nonFocusStartTime else { return }
        
        let nonFocusTime = Date().timeIntervalSince(startTime)
        if nonFocusTime >= 300 { // 5 minutes
            showExcessiveNonFocusWarning(duration: nonFocusTime)
        }
    }
    
    private func scanAndEnforceApplications() {
        // Scan all running apps and enforce rules
        let runningApps = workspace.runningApplications
        
        let rules = FocusRules(
            allowedCategories: [.development, .writing],
            blockedKeywords: ["social", "games", "entertainment"],
            maxNonFocusTime: 300,
            breakReminder: 3600
        )
        
        for app in runningApps {
            guard let appName = app.localizedName,
                  let bundleId = app.bundleIdentifier else { continue }
            
            if shouldBlockApplication(appName, bundleId: bundleId, rules: rules) {
                blockApplication(app, rules: rules)
            }
        }
    }
    
    // MARK: - Override Management
    
    private var temporaryOverrides: [FocusOverride] = []
    
    private func addTemporaryOverride(_ override: FocusOverride) {
        temporaryOverrides.append(override)
        
        // Clean up expired overrides
        cleanupExpiredOverrides()
    }
    
    private func cleanupExpiredOverrides() {
        let now = Date()
        temporaryOverrides = temporaryOverrides.filter { override in
            now.timeIntervalSince(override.granted) < override.duration
        }
    }
    
    private func hasActiveOverride(for appName: String) -> Bool {
        cleanupExpiredOverrides()
        return temporaryOverrides.contains { $0.appName == appName }
    }
    
    // MARK: - Enforcement Escalation
    
    private func escalateEnforcement() {
        switch enforcementStrength {
        case .lenient:
            enforcementStrength = .medium
            showEnforcementEscalatedNotification("Medium")
        case .medium:
            enforcementStrength = .strict
            showEnforcementEscalatedNotification("Strict")
        case .strict:
            // Already at maximum - maybe implement additional measures
            break
        }
    }
    
    // MARK: - Notifications
    
    private func showFocusModeNotification(_ mode: FocusMode, environment: TOMEEnvironment) {
        let notification = UNMutableNotificationContent()
        notification.title = "🎯 Focus Mode Activated"
        notification.body = "\(mode.displayName) mode active for \(environment.displayName)"
        notification.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "focus_mode_activated",
            content: notification,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func showFocusModeDeactivatedNotification() {
        let notification = UNMutableNotificationContent()
        notification.title = "🔓 Focus Mode Deactivated"
        notification.body = "You can now access all applications"
        notification.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "focus_mode_deactivated",
            content: notification,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func showLenientBlockNotification(_ appName: String) {
        let notification = UNMutableNotificationContent()
        notification.title = "⚠️ Focus Reminder"
        notification.body = "\(appName) was minimized to help you stay focused"
        notification.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "lenient_block_\(appName)",
            content: notification,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func showMediumBlockNotification(_ appName: String) {
        let notification = UNMutableNotificationContent()
        notification.title = "🚫 Application Blocked"
        notification.body = "\(appName) was closed to maintain focus"
        notification.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "medium_block_\(appName)",
            content: notification,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func showStrictBlockNotification(_ appName: String) {
        let notification = UNMutableNotificationContent()
        notification.title = "🔒 Strict Focus Enforcement"
        notification.body = "\(appName) was force-closed. Focus mode is active."
        notification.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "strict_block_\(appName)",
            content: notification,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func showBreakReminderNotification() {
        let notification = UNMutableNotificationContent()
        notification.title = "⏰ Break Time"
        notification.body = "You've been focused for an hour. Consider taking a break."
        notification.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "break_reminder",
            content: notification,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func showExcessiveNonFocusWarning(duration: TimeInterval) {
        let minutes = Int(duration / 60)
        let notification = UNMutableNotificationContent()
        notification.title = "📱 Focus Alert"
        notification.body = "You've been away from focused work for \(minutes) minutes"
        notification.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "non_focus_warning",
            content: notification,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func showOverrideGrantedNotification(_ appName: String, duration: TimeInterval) {
        let minutes = Int(duration / 60)
        let notification = UNMutableNotificationContent()
        notification.title = "✅ Focus Override Granted"
        notification.body = "\(appName) is allowed for \(minutes) minutes"
        notification.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "override_granted",
            content: notification,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func showEnforcementEscalatedNotification(_ level: String) {
        let notification = UNMutableNotificationContent()
        notification.title = "🔥 Focus Enforcement Escalated"
        notification.body = "Switched to \(level) enforcement due to multiple violations"
        notification.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "enforcement_escalated",
            content: notification,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Settings Persistence
    
    private func loadEnforcementSettings() {
        let defaults = UserDefaults.standard
        
        if let modeRaw = defaults.object(forKey: "focus_mode") as? String,
           let mode = FocusMode(rawValue: modeRaw) {
            currentFocusMode = mode
        }
        
        if let strengthRaw = defaults.object(forKey: "enforcement_strength") as? String,
           let strength = EnforcementStrength(rawValue: strengthRaw) {
            enforcementStrength = strength
        }
        
        isEnforcementActive = defaults.bool(forKey: "enforcement_active")
        focusViolations = defaults.integer(forKey: "focus_violations_today")
        
        if let blockedApps = defaults.array(forKey: "blocked_apps_today") as? [String] {
            blockedAppsToday = blockedApps
        }
    }
    
    func saveEnforcementSettings() {
        let defaults = UserDefaults.standard
        
        defaults.set(currentFocusMode.rawValue, forKey: "focus_mode")
        defaults.set(enforcementStrength.rawValue, forKey: "enforcement_strength")
        defaults.set(isEnforcementActive, forKey: "enforcement_active")
        defaults.set(focusViolations, forKey: "focus_violations_today")
        defaults.set(blockedAppsToday, forKey: "blocked_apps_today")
    }
}

// MARK: - Supporting Types

enum FocusMode: String, CaseIterable {
    case disabled = "disabled"
    case lenient = "lenient" 
    case balanced = "balanced"
    case strict = "strict"
    
    var displayName: String {
        switch self {
        case .disabled: return "Disabled"
        case .lenient: return "Lenient"
        case .balanced: return "Balanced"
        case .strict: return "Strict"
        }
    }
    
    var description: String {
        switch self {
        case .disabled: return "No focus enforcement"
        case .lenient: return "Gentle reminders only"
        case .balanced: return "Moderate enforcement"
        case .strict: return "Strong enforcement"
        }
    }
}

enum EnforcementStrength: String {
    case lenient = "lenient"
    case medium = "medium" 
    case strict = "strict"
}

enum FocusAppCategory {
    case development, design, writing, communication, research, notes
    case calendar, tasks, planning, meditation, music, reading, relaxation
    case browser, games, entertainment, social
}

struct FocusRules {
    let allowedCategories: [FocusAppCategory]
    let blockedKeywords: [String]
    let maxNonFocusTime: TimeInterval
    let breakReminder: TimeInterval
}

struct FocusOverride {
    let appName: String
    let granted: Date
    let duration: TimeInterval
}