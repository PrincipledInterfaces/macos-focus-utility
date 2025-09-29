import Foundation
import AppKit
import Combine

class WindowManagementService: ObservableObject {
    @Published var isManagingWindows = false
    @Published var currentLayout: WorkspaceLayout?
    
    private var managedApps: Set<String> = []
    private let workspace = NSWorkspace.shared
    
    init() {
        // Setup window management monitoring
        setupWindowObservers()
    }
    
    // MARK: - Window Layout Management
    
    func arrangeWorkspace(for category: AppCategory, apps: [DetectedApp], screenFrame: NSRect? = nil) {
        let screen = screenFrame ?? NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        
        switch category {
        case .development:
            arrangeDevelopmentWorkspace(apps: apps, screen: screen)
        case .design:
            arrangeDesignWorkspace(apps: apps, screen: screen)
        case .presentation:
            arrangePresentationWorkspace(apps: apps, screen: screen)
        case .music:
            arrangeMusicWorkspace(apps: apps, screen: screen)
        case .writing:
            arrangeWritingWorkspace(apps: apps, screen: screen)
        case .video:
            arrangeVideoWorkspace(apps: apps, screen: screen)
        case .browser:
            // Browser is handled internally by TOME
            break
        }
        
        // Update managed apps
        managedApps = Set(apps.map { $0.name })
        isManagingWindows = true
        
        // Create and store layout
        currentLayout = WorkspaceLayout(
            category: category,
            apps: apps,
            screenFrame: screen,
            timestamp: Date()
        )
    }
    
    // MARK: - Category-Specific Layouts
    
    private func arrangeDevelopmentWorkspace(apps: [DetectedApp], screen: NSRect) {
        let codeEditors = apps.filter { ["Visual Studio Code", "Xcode", "Sublime Text", "Atom", "TextMate", "Nova"].contains($0.name) }
        let terminals = apps.filter { ["Terminal", "iTerm2"].contains($0.name) }
        let devTools = apps.filter { ["Docker Desktop", "Postman", "GitHub Desktop"].contains($0.name) }
        
        // Main editor takes left 70%
        if let mainEditor = codeEditors.first {
            let editorFrame = NSRect(
                x: screen.origin.x,
                y: screen.origin.y,
                width: screen.width * 0.7,
                height: screen.height
            )
            moveAndResizeWindow(mainEditor.name, to: editorFrame)
        }
        
        // Terminal takes right 30%, top half
        if let terminal = terminals.first {
            let terminalFrame = NSRect(
                x: screen.origin.x + screen.width * 0.7,
                y: screen.origin.y + screen.height * 0.5,
                width: screen.width * 0.3,
                height: screen.height * 0.5
            )
            moveAndResizeWindow(terminal.name, to: terminalFrame)
        }
        
        // Dev tools take right 30%, bottom half
        if let devTool = devTools.first {
            let toolFrame = NSRect(
                x: screen.origin.x + screen.width * 0.7,
                y: screen.origin.y,
                width: screen.width * 0.3,
                height: screen.height * 0.5
            )
            moveAndResizeWindow(devTool.name, to: toolFrame)
        }
    }
    
    private func arrangeDesignWorkspace(apps: [DetectedApp], screen: NSRect) {
        let mainDesignApps = apps.filter { ["Figma", "Sketch", "Adobe Photoshop", "Adobe Illustrator", "Adobe InDesign"].contains($0.name) }
        
        // Design apps typically work best in full screen or maximized
        if let mainApp = mainDesignApps.first {
            let fullFrame = NSRect(
                x: screen.origin.x,
                y: screen.origin.y,
                width: screen.width,
                height: screen.height
            )
            moveAndResizeWindow(mainApp.name, to: fullFrame)
        }
        
        // Secondary design apps can be stacked behind
        if mainDesignApps.count > 1 {
            for i in 1..<mainDesignApps.count {
                let offset = CGFloat(i * 30)
                let appFrame = NSRect(
                    x: screen.origin.x + offset,
                    y: screen.origin.y + offset,
                    width: screen.width - offset * 2,
                    height: screen.height - offset * 2
                )
                moveAndResizeWindow(mainDesignApps[i].name, to: appFrame)
            }
        }
    }
    
    private func arrangePresentationWorkspace(apps: [DetectedApp], screen: NSRect) {
        let presentationApps = apps.filter { ["Microsoft PowerPoint", "Keynote", "Google Slides", "Prezi"].contains($0.name) }
        
        // Presentation apps work best in full screen
        if let mainApp = presentationApps.first {
            let fullFrame = NSRect(
                x: screen.origin.x,
                y: screen.origin.y,
                width: screen.width,
                height: screen.height
            )
            moveAndResizeWindow(mainApp.name, to: fullFrame)
        }
    }
    
    private func arrangeMusicWorkspace(apps: [DetectedApp], screen: NSRect) {
        let daws = apps.filter { ["Logic Pro", "GarageBand", "Pro Tools", "Ableton Live", "FL Studio"].contains($0.name) }
        let audioTools = apps.filter { ["Audacity"].contains($0.name) }
        let musicApps = apps.filter { ["Spotify", "Music"].contains($0.name) }
        
        // Main DAW takes most of the screen
        if let mainDAW = daws.first {
            let dawFrame = NSRect(
                x: screen.origin.x,
                y: screen.origin.y + screen.height * 0.15,
                width: screen.width,
                height: screen.height * 0.85
            )
            moveAndResizeWindow(mainDAW.name, to: dawFrame)
        }
        
        // Music player takes top strip if present
        if let musicPlayer = musicApps.first {
            let playerFrame = NSRect(
                x: screen.origin.x,
                y: screen.origin.y + screen.height * 0.85,
                width: screen.width,
                height: screen.height * 0.15
            )
            moveAndResizeWindow(musicPlayer.name, to: playerFrame)
        }
    }
    
    private func arrangeWritingWorkspace(apps: [DetectedApp], screen: NSRect) {
        let writingApps = apps.filter { ["Microsoft Word", "Pages", "Bear", "Ulysses", "Scrivener"].contains($0.name) }
        let noteApps = apps.filter { ["Notion", "Obsidian"].contains($0.name) }
        
        // Main writing app takes left 65%
        if let mainWriter = writingApps.first {
            let writerFrame = NSRect(
                x: screen.origin.x,
                y: screen.origin.y,
                width: screen.width * 0.65,
                height: screen.height
            )
            moveAndResizeWindow(mainWriter.name, to: writerFrame)
        }
        
        // Notes/research app takes right 35%
        if let noteApp = noteApps.first {
            let noteFrame = NSRect(
                x: screen.origin.x + screen.width * 0.65,
                y: screen.origin.y,
                width: screen.width * 0.35,
                height: screen.height
            )
            moveAndResizeWindow(noteApp.name, to: noteFrame)
        }
    }
    
    private func arrangeVideoWorkspace(apps: [DetectedApp], screen: NSRect) {
        let videoEditors = apps.filter { ["Final Cut Pro", "Adobe Premiere Pro", "DaVinci Resolve", "Adobe After Effects"].contains($0.name) }
        let mediaApps = apps.filter { ["iMovie", "Blender"].contains($0.name) }
        
        // Video editors typically work best maximized
        if let mainEditor = videoEditors.first {
            let fullFrame = NSRect(
                x: screen.origin.x,
                y: screen.origin.y,
                width: screen.width,
                height: screen.height
            )
            moveAndResizeWindow(mainEditor.name, to: fullFrame)
        }
    }
    
    // MARK: - Window Control
    
    private func moveAndResizeWindow(_ appName: String, to frame: NSRect) {
        // Convert NSRect to screen coordinates (flip Y axis for AppleScript)
        let screenHeight = NSScreen.main?.frame.height ?? 1080
        let flippedY = screenHeight - frame.origin.y - frame.size.height
        
        let script = """
        tell application "System Events"
            try
                tell process "\(appName)"
                    if exists window 1 then
                        set position of window 1 to {\(Int(frame.origin.x)), \(Int(flippedY))}
                        set size of window 1 to {\(Int(frame.width)), \(Int(frame.height))}
                    end if
                end tell
            on error
                -- App might not be running or accessible
            end try
        end tell
        """
        
        executeAppleScript(script)
    }
    
    private func executeAppleScript(_ script: String) {
        DispatchQueue.global(qos: .utility).async {
            let appleScript = NSAppleScript(source: script)
            var errorDict: NSDictionary?
            appleScript?.executeAndReturnError(&errorDict)
            
            if let error = errorDict {
                print("❌ AppleScript error for window management: \(error)")
            }
        }
    }
    
    // MARK: - Window Observers
    
    private func setupWindowObservers() {
        // Listen for app launches to manage their windows
        workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
               let appName = app.localizedName {
                self?.handleAppLaunched(appName)
            }
        }
    }
    
    private func handleAppLaunched(_ appName: String) {
        guard managedApps.contains(appName),
              let layout = currentLayout else { return }
        
        // Convert LayoutApp back to DetectedApp for arrangement
        let detectedApps = layout.apps.map { layoutApp in
            DetectedApp(name: layoutApp.name, bundleId: layoutApp.bundleId, category: layoutApp.category, icon: layoutApp.category.icon)
        }
        
        // Delay to allow app to fully launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.arrangeWorkspace(for: layout.category, apps: detectedApps, screenFrame: layout.screenFrame)
        }
    }
    
    // MARK: - Layout Persistence
    
    func saveLayout(_ layout: WorkspaceLayout) {
        // Save layout to UserDefaults or file system for restoration
        if let data = try? JSONEncoder().encode(layout) {
            UserDefaults.standard.set(data, forKey: "workspace_layout_\(layout.category.displayName)")
        }
    }
    
    func loadLayout(for category: AppCategory) -> WorkspaceLayout? {
        guard let data = UserDefaults.standard.data(forKey: "workspace_layout_\(category.displayName)"),
              let layout = try? JSONDecoder().decode(WorkspaceLayout.self, from: data) else {
            return nil
        }
        return layout
    }
    
    // MARK: - Window Restoration
    
    func restoreWorkspace(for layout: WorkspaceLayout) {
        // Convert LayoutApp back to DetectedApp for arrangement
        let detectedApps = layout.apps.map { layoutApp in
            DetectedApp(name: layoutApp.name, bundleId: layoutApp.bundleId, category: layoutApp.category, icon: layoutApp.category.icon)
        }
        
        arrangeWorkspace(for: layout.category, apps: detectedApps, screenFrame: layout.screenFrame)
        currentLayout = layout
    }
    
    func stopManaging() {
        isManagingWindows = false
        managedApps.removeAll()
        currentLayout = nil
    }
}

// MARK: - Supporting Types

struct WorkspaceLayout: Codable {
    let category: AppCategory
    let apps: [LayoutApp] // Simplified version of DetectedApp for encoding
    let screenFrame: CGRect
    let timestamp: Date
    
    init(category: AppCategory, apps: [DetectedApp], screenFrame: NSRect, timestamp: Date) {
        self.category = category
        self.apps = apps.map { LayoutApp(name: $0.name, bundleId: $0.bundleId, category: $0.category) }
        self.screenFrame = screenFrame
        self.timestamp = timestamp
    }
}

struct LayoutApp: Codable {
    let name: String
    let bundleId: String
    let category: AppCategory
}