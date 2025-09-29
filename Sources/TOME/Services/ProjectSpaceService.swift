import SwiftUI
import AppKit
import Foundation

/// ProjectSpaceService handles the project-space mapping system with state preservation
/// This service manages the mapping between projects, environments, and their associated states
/// including open applications, window positions, files, and workspace configurations
class ProjectSpaceService: ObservableObject {
    @Published var currentProject: Project?
    @Published var availableProjects: [Project] = []
    
    private var projectStateCache: [UUID: DetailedProjectState] = [:]
    private let applicationService: ApplicationService
    private let fileManager = FileManager.default
    private let userDefaults = UserDefaults.standard
    
    init(applicationService: ApplicationService) {
        self.applicationService = applicationService
        loadProjects()
        setupAutoSave()
    }
    
    // MARK: - Project Management
    
    /// Creates a new project with the given name and environment
    func createProject(name: String, environment: TOMEEnvironment) -> Project {
        let project = Project(
            id: UUID(),
            name: name,
            environment: environment,
            state: ProjectState()
        )
        
        let detailedState = DetailedProjectState(
            projectId: project.id,
            environment: environment,
            openApplications: [],
            windowStates: [:],
            openFiles: [],
            workingDirectory: getDefaultWorkingDirectory(for: environment),
            customSettings: [:],
            lastUsed: Date()
        )
        
        projectStateCache[project.id] = detailedState
        availableProjects.append(project)
        saveProjects()
        
        return project
    }
    
    /// Switches to a different project, preserving current state and restoring target state
    func switchToProject(_ project: Project) {
        // Save current project state if one is active
        if currentProject != nil {
            saveCurrentProjectState()
        }
        
        // Switch to new project
        currentProject = project
        restoreProjectState(project)
        
        // Update project's last used timestamp
        if var cachedState = projectStateCache[project.id] {
            cachedState.lastUsed = Date()
            projectStateCache[project.id] = cachedState
        }
        
        print("Switched to project: \(project.name) in \(project.environment.displayName)")
    }
    
    /// Archives a project and cleans up its associated state
    func archiveProject(_ project: Project) {
        // Remove from active projects
        availableProjects.removeAll { $0.id == project.id }
        
        // Archive the state data
        if let state = projectStateCache[project.id] {
            archiveProjectState(project, state: state)
        }
        
        // Clean up cache
        projectStateCache.removeValue(forKey: project.id)
        
        // If this was the current project, clear it
        if currentProject?.id == project.id {
            currentProject = nil
        }
        
        saveProjects()
    }
    
    // MARK: - State Preservation
    
    /// Saves the current state of the active project
    private func saveCurrentProjectState() {
        guard let project = currentProject else { return }
        
        let openApps = applicationService.runningApplications.map { app in
            ApplicationState(
                name: app.name,
                bundleIdentifier: app.bundleIdentifier,
                isActive: app.isActive,
                windowCount: getWindowCount(for: app)
            )
        }
        
        let windowStates = captureWindowStates()
        let openFiles = captureOpenFiles()
        let workingDir = captureWorkingDirectory()
        
        let detailedState = DetailedProjectState(
            projectId: project.id,
            environment: project.environment,
            openApplications: openApps,
            windowStates: windowStates,
            openFiles: openFiles,
            workingDirectory: workingDir,
            customSettings: captureCustomSettings(for: project.environment).mapValues { AnyCodable($0) },
            lastUsed: Date()
        )
        
        projectStateCache[project.id] = detailedState
        
        print("Saved state for project: \(project.name)")
        print("- Open applications: \(openApps.count)")
        print("- Window states: \(windowStates.count)")
        print("- Open files: \(openFiles.count)")
    }
    
    /// Restores the state for a given project
    private func restoreProjectState(_ project: Project) {
        guard let state = projectStateCache[project.id] else {
            print("No saved state found for project: \(project.name)")
            return
        }
        
        print("Restoring state for project: \(project.name)")
        
        // Switch to the project's environment first
        if project.environment != state.environment {
            print("Environment mismatch - updating project environment")
        }
        
        // Restore working directory
        if !state.workingDirectory.isEmpty {
            setWorkingDirectory(state.workingDirectory)
        }
        
        // Restore applications
        restoreApplications(state.openApplications)
        
        // Restore windows and files immediately in background
        DispatchQueue.global(qos: .userInitiated).async {
            // Small delay for apps to fully launch
            usleep(500_000) // 0.5 seconds
            DispatchQueue.main.async {
                self.restoreWindowStates(state.windowStates)
            }
            
            // Restore files
            usleep(500_000) // Additional 0.5 seconds  
            DispatchQueue.main.async {
                self.restoreOpenFiles(state.openFiles)
            }
        }
        
        // Apply custom settings
        applyCustomSettings(state.customSettings, for: project.environment)
        
        print("State restoration initiated for project: \(project.name)")
    }
    
    // MARK: - Application Management
    
    private func restoreApplications(_ applications: [ApplicationState]) {
        for appState in applications {
            // Only launch if not already running
            let isRunning = applicationService.runningApplications.contains { 
                $0.bundleIdentifier == appState.bundleIdentifier 
            }
            
            if !isRunning {
                if applicationService.launchApplication(appState.name) {
                    print("Launched application: \(appState.name)")
                } else {
                    print("Failed to launch application: \(appState.name)")
                }
            }
        }
    }
    
    private func getWindowCount(for app: TOMEApplication) -> Int {
        // This would require more advanced window management APIs
        // For now, return a simple estimation
        return app.isActive ? 1 : 0
    }
    
    // MARK: - Window State Management
    
    private func captureWindowStates() -> [String: WindowState] {
        var windowStates: [String: WindowState] = [:]
        
        // Get all visible windows using CGWindowListCopyWindowInfo
        if let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] {
            for windowInfo in windowList {
                if let ownerName = windowInfo[kCGWindowOwnerName as String] as? String,
                   let windowNumber = windowInfo[kCGWindowNumber as String] as? Int,
                   let bounds = windowInfo[kCGWindowBounds as String] as? [String: Any] {
                    
                    let windowId = "\(ownerName)_\(windowNumber)"
                    let windowState = WindowState(
                        applicationName: ownerName,
                        windowId: windowId,
                        frame: CGRect(
                            x: bounds["X"] as? Double ?? 0,
                            y: bounds["Y"] as? Double ?? 0,
                            width: bounds["Width"] as? Double ?? 800,
                            height: bounds["Height"] as? Double ?? 600
                        ),
                        isMinimized: false,
                        isFullscreen: false,
                        workspace: getCurrentWorkspace()
                    )
                    
                    windowStates[windowId] = windowState
                }
            }
        }
        
        return windowStates
    }
    
    private func restoreWindowStates(_ windowStates: [String: WindowState]) {
        for (_, windowState) in windowStates {
            // This is a complex operation that would require private APIs
            // For now, we'll log the intended restoration
            print("Would restore window: \(windowState.applicationName) to frame: \(windowState.frame)")
            
            // In a full implementation, this would use accessibility APIs or private APIs
            // to actually move and resize windows
        }
    }
    
    // MARK: - File Management
    
    private func captureOpenFiles() -> [String] {
        var openFiles: [String] = []
        
        // This would integrate with common editors and IDEs to capture open files
        // For now, we'll check for recent files in common applications
        
        // Check Xcode recent files
        if let xcodeRecents = getXcodeRecentFiles() {
            openFiles.append(contentsOf: xcodeRecents)
        }
        
        // Check VSCode recent files
        if let vscodeRecents = getVSCodeRecentFiles() {
            openFiles.append(contentsOf: vscodeRecents)
        }
        
        return openFiles
    }
    
    private func restoreOpenFiles(_ files: [String]) {
        for filePath in files {
            if fileManager.fileExists(atPath: filePath) {
                // Attempt to open the file with its default application
                let url = URL(fileURLWithPath: filePath)
                NSWorkspace.shared.open(url)
                print("Opened file: \(filePath)")
            }
        }
    }
    
    // MARK: - Environment-Specific Settings
    
    private func captureCustomSettings(for environment: TOMEEnvironment) -> [String: Any] {
        var settings: [String: Any] = [:]
        
        switch environment {
        case .workshop:
            // Capture IDE settings, terminal configurations, etc.
            settings["terminalTabs"] = captureTerminalTabs()
            settings["debuggerState"] = captureDebuggerState()
            
        case .writerDesk:
            // Capture writing app states, document positions
            settings["documentFontSize"] = captureDocumentFontSize()
            settings["writingMode"] = captureWritingMode()
            
        case .coffeeshop:
            // Capture browser tabs, research notes
            settings["browserTabs"] = captureBrowserTabs()
            settings["researchNotes"] = captureResearchNotes()
            
        case .planning:
            // Capture planning view states, calendar positions
            settings["calendarView"] = captureCalendarViewState()
            settings["todoFilters"] = captureTodoFilters()
            
        case .garden:
            // Capture meditation settings, ambient preferences
            settings["meditationDuration"] = captureMeditationSettings()
            settings["ambientSounds"] = captureAmbientSoundSettings()
            
        case .home:
            break
        }
        
        return settings
    }
    
    private func applyCustomSettings(_ settings: [String: Any], for environment: TOMEEnvironment) {
        switch environment {
        case .workshop:
            if let terminalTabs = settings["terminalTabs"] as? [String] {
                restoreTerminalTabs(terminalTabs)
            }
            
        case .writerDesk:
            if let fontSize = settings["documentFontSize"] as? Double {
                restoreDocumentFontSize(fontSize)
            }
            
        case .coffeeshop:
            if let browserTabs = settings["browserTabs"] as? [String] {
                restoreBrowserTabs(browserTabs)
            }
            
        default:
            break
        }
    }
    
    // MARK: - Persistence
    
    private func loadProjects() {
        // Load projects from UserDefaults
        if let data = userDefaults.data(forKey: "tome_projects"),
           let projects = try? JSONDecoder().decode([Project].self, from: data) {
            availableProjects = projects
        } else {
            // Create default projects
            createDefaultProjects()
        }
        
        // Load project state cache
        loadProjectStateCache()
    }
    
    private func saveProjects() {
        if let data = try? JSONEncoder().encode(availableProjects) {
            userDefaults.set(data, forKey: "tome_projects")
        }
        
        saveProjectStateCache()
    }
    
    private func loadProjectStateCache() {
        if let data = userDefaults.data(forKey: "tome_project_states"),
           let cache = try? JSONDecoder().decode([UUID: DetailedProjectState].self, from: data) {
            projectStateCache = cache
        }
    }
    
    private func saveProjectStateCache() {
        if let data = try? JSONEncoder().encode(projectStateCache) {
            userDefaults.set(data, forKey: "tome_project_states")
        }
    }
    
    private func archiveProjectState(_ project: Project, state: DetailedProjectState) {
        let archiveKey = "tome_archived_project_\(project.id.uuidString)"
        let archive = ArchivedProjectState(
            project: project,
            state: state,
            archivedAt: Date()
        )
        
        if let data = try? JSONEncoder().encode(archive) {
            userDefaults.set(data, forKey: archiveKey)
        }
    }
    
    private func setupAutoSave() {
        // Auto-save project state every 30 seconds
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            self.saveCurrentProjectState()
            self.saveProjectStateCache()
        }
    }
    
    // MARK: - Helper Methods
    
    private func createDefaultProjects() {
        let defaultProjects = [
            ("iOS App Development", TOMEEnvironment.workshop),
            ("Newsletter Writing", TOMEEnvironment.writerDesk),
            ("Market Research", TOMEEnvironment.coffeeshop),
            ("Weekly Planning", TOMEEnvironment.planning)
        ]
        
        for (name, environment) in defaultProjects {
            _ = createProject(name: name, environment: environment)
        }
    }
    
    private func getDefaultWorkingDirectory(for environment: TOMEEnvironment) -> String {
        switch environment {
        case .workshop:
            return NSHomeDirectory() + "/Developer"
        case .writerDesk:
            return NSHomeDirectory() + "/Documents/Writing"
        case .coffeeshop:
            return NSHomeDirectory() + "/Documents/Research"
        default:
            return NSHomeDirectory() + "/Documents"
        }
    }
    
    private func setWorkingDirectory(_ path: String) {
        // This would set the working directory for new processes
        print("Setting working directory to: \(path)")
    }
    
    private func captureWorkingDirectory() -> String {
        return fileManager.currentDirectoryPath
    }
    
    private func getCurrentWorkspace() -> Int {
        // This would require private APIs to get the current workspace number
        return 1
    }
    
    // MARK: - Application-Specific Helpers
    
    private func getXcodeRecentFiles() -> [String]? {
        // This would parse Xcode's recent files from its preferences
        return nil
    }
    
    private func getVSCodeRecentFiles() -> [String]? {
        // This would parse VSCode's recent files from its state
        return nil
    }
    
    private func captureTerminalTabs() -> [String] {
        return []
    }
    
    private func captureDebuggerState() -> [String: Any] {
        return [:]
    }
    
    private func captureDocumentFontSize() -> Double {
        return 14.0
    }
    
    private func captureWritingMode() -> String {
        return "focus"
    }
    
    private func captureBrowserTabs() -> [String] {
        return []
    }
    
    private func captureResearchNotes() -> String {
        return ""
    }
    
    private func captureCalendarViewState() -> String {
        return "week"
    }
    
    private func captureTodoFilters() -> [String] {
        return []
    }
    
    private func captureMeditationSettings() -> Int {
        return 300 // 5 minutes
    }
    
    private func captureAmbientSoundSettings() -> String {
        return "forest_rain"
    }
    
    private func restoreTerminalTabs(_ tabs: [String]) {
        // Implementation would restore terminal tabs
    }
    
    private func restoreDocumentFontSize(_ size: Double) {
        // Implementation would restore document font size
    }
    
    private func restoreBrowserTabs(_ tabs: [String]) {
        // Implementation would restore browser tabs
    }
}

// MARK: - Data Models

struct DetailedProjectState: Codable {
    let projectId: UUID
    let environment: TOMEEnvironment
    var openApplications: [ApplicationState]
    var windowStates: [String: WindowState]
    var openFiles: [String]
    var workingDirectory: String
    var customSettings: [String: AnyCodable]
    var lastUsed: Date
}

struct ApplicationState: Codable {
    let name: String
    let bundleIdentifier: String
    var isActive: Bool
    var windowCount: Int
}

struct WindowState: Codable {
    let applicationName: String
    let windowId: String
    var frame: CGRect
    var isMinimized: Bool
    var isFullscreen: Bool
    var workspace: Int
}

struct ArchivedProjectState: Codable {
    let project: Project
    let state: DetailedProjectState
    let archivedAt: Date
}

// Helper for encoding arbitrary values
struct AnyCodable: Codable {
    private let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type")
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unsupported type")
            )
        }
    }
}