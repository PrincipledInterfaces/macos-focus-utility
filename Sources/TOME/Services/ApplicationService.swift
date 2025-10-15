import Foundation
import AppKit
import Combine
import UserNotifications

class ApplicationService: ObservableObject {
    @Published var runningApplications: [TOMEApplication] = []
    @Published var allowedApplications: [String] = []
    @Published var blockedApplications: [String] = []
    @Published var currentEnvironmentApps: [String] = []
    
    private var cancellables = Set<AnyCancellable>()
    private var appMonitorTimer: Timer?
    
    // Environment-specific app configurations
    private let environmentApps: [TOMEEnvironment: [String]] = [
        .workshop: [
            "Xcode",
            "Visual Studio Code",
            "Terminal",
            "Simulator",
            "GitHub Desktop",
            "Figma",
            "Sketch",
            "Tower",
            "Charles",
            "Paw",
            "Instruments"
        ],
        .writerDesk: [
            "Mail",
            "Messages",
            "Slack",
            "Discord",
            "Zoom",
            "Microsoft Teams",
            "Google Docs",
            "Notion",
            "Bear",
            "Ulysses",
            "Grammarly Editor",
            "Telegram"
        ],
        .coffeeshop: [
            "Safari",
            "Google Chrome",
            "Firefox",
            "Obsidian",
            "DevonThink",
            "Papers",
            "MindNode",
            "SimpleMind",
            "Spotify",
            "Music",
            "Books",
            "Research Assistant"
        ],
        .garden: [
            "Headspace",
            "Calm",
            "Ten Percent Happier",
            "Day One",
            "Journey",
            "Photos",
            "Music",
            "Spotify"
        ],
        .planning: [
            "Calendar",
            "Fantastical",
            "Things",
            "OmniFocus",
            "Todoist",
            "Notion",
            "Obsidian",
            "MindNode"
        ]
    ]
    
    init() {
        startApplicationMonitoring()
        loadApplicationPreferences()
    }
    
    // MARK: - Application Monitoring
    
    private func startApplicationMonitoring() {
        // Monitor running applications on background queue
        appMonitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            DispatchQueue.global(qos: .background).async {
                self?.updateRunningApplications()
                self?.enforceApplicationPolicy()
            }
        }
        
        // Listen for app launch/quit notifications
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleApplicationLaunched(notification)
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleApplicationTerminated(notification)
        }
        
        // Initial update
        updateRunningApplications()
    }
    
    private func updateRunningApplications() {
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        
        let tomeApps = runningApps.compactMap { app -> TOMEApplication? in
            guard let bundleId = app.bundleIdentifier,
                  let localizedName = app.localizedName else { return nil }
            
            return TOMEApplication(
                bundleIdentifier: bundleId,
                name: localizedName,
                isActive: app.isActive,
                isHidden: app.isHidden,
                pid: app.processIdentifier,
                icon: app.icon,
                launchDate: app.launchDate
            )
        }
        
        DispatchQueue.main.async {
            self.runningApplications = tomeApps
        }
    }
    
    private func handleApplicationLaunched(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let appName = app.localizedName else { return }
        
        print("App launched: \(appName)")
        
        // Check if app should be blocked in current environment
        if shouldBlockApplication(appName) {
            blockApplication(app)
        }
        
        updateRunningApplications()
    }
    
    private func handleApplicationTerminated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let appName = app.localizedName else { return }
        
        print("App terminated: \(appName)")
        updateRunningApplications()
    }
    
    // MARK: - Application Control
    
    func launchApplication(_ appName: String) -> Bool {
        let workspace = NSWorkspace.shared
        
        // First try to find by bundle identifier
        let bundleIds = getBundleIdentifiers()
        if let bundleId = bundleIds[appName.lowercased()] {
            if let appURL = workspace.urlForApplication(withBundleIdentifier: bundleId) {
                do {
                    let config = NSWorkspace.OpenConfiguration()
                    config.activates = false // Don't activate - keep in background for embedding
                    try workspace.openApplication(at: appURL, configuration: config)
                    print("Launched application: \(appName)")
                    return true
                } catch {
                    print("Failed to launch \(appName): \(error)")
                }
            }
        }
        
        // Try to find by name in Applications folder
        return launchApplicationFromPath(appName)
    }
    
    func launchApplicationForWorkshop(_ appName: String) -> Bool {
        let workspace = NSWorkspace.shared
        
        // First try to find by bundle identifier
        let bundleIds = getBundleIdentifiers()
        if let bundleId = bundleIds[appName.lowercased()] {
            if let appURL = workspace.urlForApplication(withBundleIdentifier: bundleId) {
                do {
                    let config = NSWorkspace.OpenConfiguration()
                    config.activates = true // Activate and bring to front for workshop launches
                    try workspace.openApplication(at: appURL, configuration: config)
                    print("Launched application for workshop: \(appName)")
                    return true
                } catch {
                    print("Failed to launch \(appName): \(error)")
                }
            }
        }
        
        // Try to find by name in Applications folder with activation
        return launchApplicationFromPathWithActivation(appName)
    }
    
    func launchApplication(bundleId: String, completion: @escaping (Bool) -> Void) {
        let workspace = NSWorkspace.shared
        
        print("🚀 Attempting to launch app with bundle ID: \(bundleId)")
        
        if let appURL = workspace.urlForApplication(withBundleIdentifier: bundleId) {
            print("✅ Found app URL: \(appURL.path)")
            
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true // Let it activate so we can see it
            workspace.openApplication(at: appURL, configuration: config) { app, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Failed to launch \(bundleId): \(error)")
                        completion(false)
                    } else if let app = app {
                        print("✅ Successfully launched: \(app.localizedName ?? bundleId)")
                        completion(true)
                    } else {
                        print("❌ Unknown error launching \(bundleId)")
                        completion(false)
                    }
                }
            }
        } else {
            print("❌ Could not find app with bundle ID: \(bundleId)")
            completion(false)
        }
    }
    
    func launchApplicationByName(_ appName: String, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let success = self.launchApplicationFromPath(appName)
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
    
    private func launchApplicationFromPath(_ appName: String) -> Bool {
        let fileManager = FileManager.default
        let applicationDirs = [
            "/Applications",
            "/Applications/Utilities",
            "/System/Applications",
            "/System/Applications/Utilities",
            "~/Applications"
        ]
        
        for dir in applicationDirs {
            let expandedDir = NSString(string: dir).expandingTildeInPath
            let appPath = "\(expandedDir)/\(appName).app"
            
            if fileManager.fileExists(atPath: appPath) {
                let workspace = NSWorkspace.shared
                let appURL = URL(fileURLWithPath: appPath)
                
                do {
                    let config = NSWorkspace.OpenConfiguration()
                    try workspace.openApplication(at: appURL, configuration: config)
                    print("Launched application from path: \(appPath)")
                    return true
                } catch {
                    print("Failed to launch from path: \(error)")
                }
            }
        }
        
        return false
    }
    
    private func launchApplicationFromPathWithActivation(_ appName: String) -> Bool {
        let fileManager = FileManager.default
        let applicationDirs = [
            "/Applications",
            "/Applications/Utilities",
            "/System/Applications",
            "/System/Applications/Utilities",
            "~/Applications"
        ]
        
        for dir in applicationDirs {
            let expandedDir = NSString(string: dir).expandingTildeInPath
            let appPath = "\(expandedDir)/\(appName).app"
            
            if fileManager.fileExists(atPath: appPath) {
                let workspace = NSWorkspace.shared
                let appURL = URL(fileURLWithPath: appPath)
                
                do {
                    let config = NSWorkspace.OpenConfiguration()
                    config.activates = true // Bring to front
                    try workspace.openApplication(at: appURL, configuration: config)
                    print("Launched application from path with activation: \(appPath)")
                    return true
                } catch {
                    print("Failed to launch from path: \(error)")
                }
            }
        }
        
        return false
    }
    
    func quitApplication(_ appName: String) -> Bool {
        guard let app = runningApplications.first(where: { $0.name.lowercased() == appName.lowercased() }) else {
            return false
        }
        
        return quitApplicationByPID(app.pid)
    }
    
    func quitApplicationByPID(_ pid: pid_t) -> Bool {
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = [
            "-e",
            "tell application \"System Events\" to tell process id \(pid) to quit"
        ]
        
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            print("Failed to quit application: \(error)")
            return false
        }
    }
    
    func forceQuitApplication(_ appName: String) -> Bool {
        guard let app = runningApplications.first(where: { $0.name.lowercased() == appName.lowercased() }) else {
            return false
        }
        
        let task = Process()
        task.launchPath = "/bin/kill"
        task.arguments = ["-9", "\(app.pid)"]
        
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            print("Failed to force quit application: \(error)")
            return false
        }
    }
    
    func hideApplication(_ appName: String) -> Bool {
        guard let app = runningApplications.first(where: { $0.name.lowercased() == appName.lowercased() }) else {
            return false
        }
        
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = [
            "-e",
            "tell application \"System Events\" to set visible of process \"\(app.name)\" to false"
        ]
        
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            print("Failed to hide application: \(error)")
            return false
        }
    }
    
    func showApplication(_ appName: String) -> Bool {
        // First try to activate if already running
        if let app = runningApplications.first(where: { $0.name.lowercased() == appName.lowercased() }) {
            let runningApp = NSWorkspace.shared.runningApplications.first { $0.processIdentifier == app.pid }
            return runningApp?.activate(options: []) ?? false
        }
        
        // If not running, launch it
        return launchApplication(appName)
    }
    
    // MARK: - Environment-Based Application Management
    
    func setEnvironment(_ environment: TOMEEnvironment) {
        currentEnvironmentApps = environmentApps[environment] ?? []
        allowedApplications = currentEnvironmentApps
        
        // Block applications not in current environment
        enforceApplicationPolicy()
        
        // Launch environment-specific apps
        launchEnvironmentApplications(environment)
    }
    
    private func launchEnvironmentApplications(_ environment: TOMEEnvironment) {
        // Disabled: Don't auto-launch applications
        // Users should explicitly choose which apps to open
        return
    }
    
    private func enforceApplicationPolicy() {
        // App blocking has been completely disabled
        return
    }
    
    private func shouldBlockApplication(_ appName: String) -> Bool {
        // Don't block system applications
        if isSystemApplication(appName) {
            return false
        }
        
        // Don't block TOME itself
        if appName == "TOME" {
            return false
        }
        
        // Block if not in allowed list
        return !allowedApplications.contains(appName)
    }
    
    private func blockApplication(_ app: NSRunningApplication) {
        // First try graceful quit
        if !app.terminate() {
            // Force quit if graceful quit fails
            app.forceTerminate()
        }
        
        // Show notification
        let notification = UNMutableNotificationContent()
        notification.title = "TOME: Application Blocked"
        notification.body = "\(app.localizedName ?? "Application") was closed to maintain focus"
        notification.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: notification,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func isSystemApplication(_ appName: String) -> Bool {
        let systemApps = [
            "Finder",
            "System Preferences",
            "Activity Monitor",
            "Console",
            "Keychain Access",
            "Terminal",
            "System Information",
            "Disk Utility",
            "Migration Assistant",
            "Boot Camp Assistant",
            "Directory Utility",
            "Network Utility",
            "System Events",
            "loginwindow",
            "WindowServer"
        ]
        
        return systemApps.contains(appName)
    }
    
    // MARK: - Application Information
    
    func getApplicationInfo(_ appName: String) -> TOMEApplication? {
        return runningApplications.first { $0.name.lowercased() == appName.lowercased() }
    }
    
    func getInstalledApplications() -> [String] {
        let fileManager = FileManager.default
        let applicationDirs = [
            "/Applications",
            "/System/Applications",
            "~/Applications"
        ]
        
        var apps: [String] = []
        
        for dir in applicationDirs {
            let expandedDir = NSString(string: dir).expandingTildeInPath
            
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: expandedDir)
                let appNames = contents
                    .filter { $0.hasSuffix(".app") }
                    .map { String($0.dropLast(4)) } // Remove .app extension
                
                apps.append(contentsOf: appNames)
            } catch {
                print("Error reading directory \(expandedDir): \(error)")
            }
        }
        
        return Array(Set(apps)).sorted() // Remove duplicates and sort
    }
    
    func searchApplications(_ query: String) -> [String] {
        let allApps = getInstalledApplications()
        let runningAppNames = runningApplications.map { $0.name }
        let combinedApps = Array(Set(allApps + runningAppNames))
        
        return combinedApps.filter { app in
            app.lowercased().contains(query.lowercased())
        }.sorted()
    }
    
    // MARK: - Bundle Identifiers
    
    private func getBundleIdentifiers() -> [String: String] {
        return [
            "xcode": "com.apple.dt.Xcode",
            "visual studio code": "com.microsoft.VSCode",
            "vs code": "com.microsoft.VSCode",
            "vscode": "com.microsoft.VSCode",
            "safari": "com.apple.Safari",
            "chrome": "com.google.Chrome",
            "google chrome": "com.google.Chrome",
            "firefox": "org.mozilla.firefox",
            "mail": "com.apple.mail",
            "messages": "com.apple.MobileSMS",
            "slack": "com.tinyspeck.slackmacgap",
            "discord": "com.hnc.Discord",
            "zoom": "us.zoom.xos",
            "teams": "com.microsoft.teams",
            "microsoft teams": "com.microsoft.teams",
            "figma": "com.figma.Desktop",
            "sketch": "com.bohemiancoding.sketch3",
            "terminal": "com.apple.Terminal",
            "finder": "com.apple.finder",
            "spotify": "com.spotify.client",
            "music": "com.apple.Music",
            "calendar": "com.apple.iCal",
            "fantastical": "com.flexibits.fantastical2.mac",
            "things": "com.culturedcode.ThingsMac",
            "omnifocus": "com.omnigroup.OmniFocus3.MacAppStore",
            "todoist": "com.todoist.mac.Todoist",
            "notion": "notion.id",
            "obsidian": "md.obsidian",
            "bear": "net.shinyfrog.bear",
            "ulysses": "com.ulyssesapp.mac",
            "day one": "com.dayoneapp.dayone",
            "headspace": "com.headspace.macos",
            "calm": "com.calm.mac"
        ]
    }
    
    // MARK: - Persistence
    
    private func loadApplicationPreferences() {
        let userDefaults = UserDefaults.standard
        
        if let saved = userDefaults.array(forKey: "allowed_applications") as? [String] {
            allowedApplications = saved
        }
        
        if let blocked = userDefaults.array(forKey: "blocked_applications") as? [String] {
            blockedApplications = blocked
        }
    }
    
    func saveApplicationPreferences() {
        let userDefaults = UserDefaults.standard
        userDefaults.set(allowedApplications, forKey: "allowed_applications")
        userDefaults.set(blockedApplications, forKey: "blocked_applications")
    }
    
    // MARK: - Window Management
    
    func arrangeWindows(for environment: TOMEEnvironment) {
        // Disabled: Don't auto-arrange windows or launch apps
        // This was causing unwanted Safari and Calendar launches
        return
    }
    
    private func arrangeWorkshopWindows() {
        // Arrange windows for development work
        let screen = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        
        // IDE takes left 2/3
        moveAndResizeWindow("Xcode", to: NSRect(x: 0, y: 0, width: screen.width * 0.67, height: screen.height))
        moveAndResizeWindow("Visual Studio Code", to: NSRect(x: 0, y: 0, width: screen.width * 0.67, height: screen.height))
        
        // Terminal takes right 1/3
        moveAndResizeWindow("Terminal", to: NSRect(x: screen.width * 0.67, y: 0, width: screen.width * 0.33, height: screen.height * 0.5))
        
        // Simulator below terminal
        moveAndResizeWindow("Simulator", to: NSRect(x: screen.width * 0.67, y: screen.height * 0.5, width: screen.width * 0.33, height: screen.height * 0.5))
    }
    
    private func arrangeWriterDeskWindows() {
        // Arrange windows for communication
        let screen = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        
        // Mail takes left half
        moveAndResizeWindow("Mail", to: NSRect(x: 0, y: 0, width: screen.width * 0.5, height: screen.height))
        
        // Slack takes right half
        moveAndResizeWindow("Slack", to: NSRect(x: screen.width * 0.5, y: 0, width: screen.width * 0.5, height: screen.height))
    }
    
    private func arrangeCoffeeshopWindows() {
        // Browser-focused layout
        let screen = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        
        // Browser takes most of screen
        moveAndResizeWindow("Safari", to: NSRect(x: 0, y: 0, width: screen.width * 0.75, height: screen.height))
        moveAndResizeWindow("Google Chrome", to: NSRect(x: 0, y: 0, width: screen.width * 0.75, height: screen.height))
        
        // Notes app on the side
        moveAndResizeWindow("Obsidian", to: NSRect(x: screen.width * 0.75, y: 0, width: screen.width * 0.25, height: screen.height))
    }
    
    private func moveAndResizeWindow(_ appName: String, to frame: NSRect) {
        let script = """
        tell application "System Events"
            try
                tell process "\(appName)"
                    set position of window 1 to {\(Int(frame.origin.x)), \(Int(frame.origin.y))}
                    set size of window 1 to {\(Int(frame.width)), \(Int(frame.height))}
                end tell
            end try
        end tell
        """
        
        let appleScript = NSAppleScript(source: script)
        var errorDict: NSDictionary?
        appleScript?.executeAndReturnError(&errorDict)
        
        if let error = errorDict {
            print("Error arranging window for \(appName): \(error)")
        }
    }
}

// MARK: - Supporting Types

struct TOMEApplication: Identifiable, Codable {
    let id = UUID()
    let bundleIdentifier: String
    let name: String
    let isActive: Bool
    let isHidden: Bool
    let pid: pid_t
    let icon: NSImage?
    let launchDate: Date?
    
    enum CodingKeys: String, CodingKey {
        case bundleIdentifier, name, isActive, isHidden, pid, launchDate
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bundleIdentifier, forKey: .bundleIdentifier)
        try container.encode(name, forKey: .name)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(isHidden, forKey: .isHidden)
        try container.encode(pid, forKey: .pid)
        try container.encode(launchDate, forKey: .launchDate)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
        name = try container.decode(String.self, forKey: .name)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        isHidden = try container.decode(Bool.self, forKey: .isHidden)
        pid = try container.decode(pid_t.self, forKey: .pid)
        launchDate = try container.decodeIfPresent(Date.self, forKey: .launchDate)
        icon = nil // Can't encode NSImage
    }
    
    init(bundleIdentifier: String, name: String, isActive: Bool, isHidden: Bool, pid: pid_t, icon: NSImage?, launchDate: Date?) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.isActive = isActive
        self.isHidden = isHidden
        self.pid = pid
        self.icon = icon
        self.launchDate = launchDate
    }
}