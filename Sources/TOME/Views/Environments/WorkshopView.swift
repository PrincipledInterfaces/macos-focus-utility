import SwiftUI
import WebKit
import UniformTypeIdentifiers

struct WorkshopView: View {
    @ObservedObject var currentState: TOMEState
    @State private var selectedTool: WorkshopTool? = nil
    @State private var showWaveAnimation = false
    @State private var waveCenter: CGPoint = .zero
    @State private var terminalRef: TerminalEmulator?
    
    let onNavigateHome: () -> Void
    
    init(currentState: TOMEState, onNavigateHome: @escaping () -> Void = {}) {
        self.currentState = currentState
        self.onNavigateHome = onNavigateHome
    }
    
    var body: some View {
        ZStack {
            // Pure black background
            Color.black.ignoresSafeArea(.all)
            
            if selectedTool == nil {
                // Workshop selection page
                workshopSelectionView
            } else {
                // Selected tool interface
                selectedToolView
            }
            
            // Wave animation overlay
            if showWaveAnimation {
                waveAnimationOverlay
                    .ignoresSafeArea(.all)
            }
            
            // Navigation overlay
            TOMENavigationOverlay(
                onNavigateHome: {
                    if selectedTool != nil {
                        // Go back to workshop selection
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedTool = nil
                        }
                    } else {
                        // Go home
                        onNavigateHome()
                    }
                },
                environmentName: selectedTool?.name ?? "Workshop",
                environmentColor: .purple,
                tomeState: currentState
            )
        }
    }
    
    private var workshopSelectionView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            HStack(spacing: 120) {
                // VSCode Icon
                workshopToolIcon(
                    tool: .vscode,
                    systemName: "curlybraces.square.fill",
                    color: Color.blue
                )
                
                // Terminal Icon
                workshopToolIcon(
                    tool: .terminal,
                    systemName: "terminal.fill",
                    color: Color.green
                )
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func workshopToolIcon(tool: WorkshopTool, systemName: String, color: Color) -> some View {
        GeometryReader { geometry in
            Button(action: {
                // Capture the center point for wave animation
                let frame = geometry.frame(in: .global)
                waveCenter = CGPoint(x: frame.midX, y: frame.midY)
                
                print("🎯 Icon clicked at: \(waveCenter)")
                print("🎯 Frame: \(frame)")
                
                // Start wave animation immediately
                showWaveAnimation = true
                
                // Transition to tool after wave expands
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTool = tool
                        showWaveAnimation = false
                        
                        // Notify AI agent of tool selection
                        updateAIAgentContext()
                    }
                }
            }) {
                Image(systemName: systemName)
                    .font(.system(size: 80, weight: .medium))
                    .foregroundColor(color.opacity(0.8))
                    .frame(width: 120, height: 120)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(color.opacity(0.1))
                            .stroke(color.opacity(0.3), lineWidth: 2)
                    )
                    .scaleEffect(1.0)
                    .animation(.easeInOut(duration: 0.2), value: false)
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { isHovered in
                // Subtle hover effect
            }
        }
        .frame(width: 120, height: 120)
    }
    
    private var selectedToolView: some View {
        Group {
            switch selectedTool {
            case .vscode:
                CustomIDEView()
                    .environmentObject(currentState)
            case .terminal:
                EmbeddedTerminalView(terminalRef: $terminalRef)
            case .none:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var waveAnimationOverlay: some View {
        ImpactfulWaveAnimationView(center: waveCenter, isActive: $showWaveAnimation)
    }
    
    private func updateAIAgentContext() {
        currentState.globalAIAgent?.setCurrentWorkshopTool(selectedTool, terminal: terminalRef)
    }
    
    private func updateAIAgentWithIDE(_ ideManager: IDEManager, selectedFile: IDEFile?) {
        currentState.globalAIAgent?.setCurrentWorkshopTool(selectedTool, terminal: terminalRef, ideManager: ideManager, selectedFile: selectedFile)
    }
}

// MARK: - Workshop Tool Enum

enum WorkshopTool: CaseIterable {
    case vscode
    case terminal
    
    var name: String {
        switch self {
        case .vscode: return "VS Code"
        case .terminal: return "Terminal"
        }
    }
}


// MARK: - Custom IDE Interface

struct CustomIDEView: View {
    @StateObject private var ideManager = IDEManager()
    @StateObject private var ideTerminal = TerminalEmulator()
    @State private var selectedFile: IDEFile?
    @State private var showAIPanel = false
    @State private var showTerminalPanel = true
    @State private var terminalHeight: CGFloat = 200
    @State private var currentProjectPath: String? = nil
    @State private var showProjectSelector = true
    
    // AI Integration
    @EnvironmentObject var tomeState: TOMEState
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea(.all)
            
            if showProjectSelector {
                ProjectSelectorView(
                    onProjectSelected: { projectPath in
                        currentProjectPath = projectPath
                        showProjectSelector = false
                        ideManager.loadProject(at: projectPath)
                        tomeState.globalAIAgent?.currentProjectPath = projectPath
                    }
                )
            } else {
                ideMainInterface
            }
        }
        .onAppear {
            setupAIIntegration()
        }
        .onChange(of: selectedFile) { _, newFile in
            // Update AI agent when file selection changes
            tomeState.globalAIAgent?.updateSelectedFile(newFile)
        }
    }
    
    private var ideMainInterface: some View {
        // Embedded container with proper spacing
        VStack(spacing: 0) {
            Spacer().frame(height: 60)
                
                HStack(spacing: 0) {
                    Spacer().frame(width: 40)
                    
                    // Main IDE interface
                    HStack(spacing: 0) {
                        // File explorer sidebar
                        FileExplorerSidebar(
                            ideManager: ideManager,
                            selectedFile: $selectedFile
                        )
                        .frame(width: 250)
                        
                        // Main editor and terminal area
                        VStack(spacing: 0) {
                            // Top toolbar
                            IDEToolbar(
                                showTerminal: $showTerminalPanel,
                                showAI: $showAIPanel,
                                ideManager: ideManager,
                                selectedFile: selectedFile,
                                terminal: ideTerminal
                            )
                            
                            // Editor and terminal split view
                            VSplitView {
                                // Main editor area
                                VStack(spacing: 0) {
                                    // Editor tabs
                                    EditorTabBar(
                                        openFiles: ideManager.openFiles,
                                        selectedFile: $selectedFile,
                                        onCloseFile: { file in
                                            ideManager.closeFile(file)
                                            if selectedFile == file {
                                                selectedFile = ideManager.openFiles.first
                                            }
                                        }
                                    )
                                    
                                    // Code editor
                                    CodeEditor(
                                        file: selectedFile,
                                        ideManager: ideManager
                                    )
                                }
                                .frame(minHeight: 300)
                                
                                // Terminal panel (collapsible)
                                if showTerminalPanel {
                                    IDETerminalPanel(terminal: ideTerminal)
                                        .frame(height: terminalHeight)
                                }
                            }
                        }
                        
                        // AI assistant panel (collapsible)
                        if showAIPanel {
                            AIAssistantPanel(
                                ideManager: ideManager,
                                selectedFile: selectedFile
                            )
                            .frame(width: 300)
                        }
                    }
                    .background(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.9),
                                Color(red: 0.05, green: 0.05, blue: 0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    
                    Spacer().frame(width: 40)
                }
                
                Spacer().frame(height: 60)
            }
        }
    
    private func setupAIIntegration() {
        // Connect AI agent to IDE and terminal
        tomeState.globalAIAgent?.setCurrentWorkshopTool(.vscode, terminal: ideTerminal, ideManager: ideManager, selectedFile: selectedFile)
        tomeState.globalAIAgent?.currentEnvironment = .workshop
    }
}

// MARK: - Project Selector

struct ProjectSelectorView: View {
    let onProjectSelected: (String) -> Void
    @State private var recentProjects: [RecentProject] = []
    @State private var showFolderPicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 80)
            
            // Header
            VStack(spacing: 16) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 48))
                    .foregroundColor(.purple.opacity(0.8))
                
                Text("Welcome to TOME Workshop")
                    .font(.tomeHeading())
                    .foregroundColor(.white)
                
                Text("Select a project folder to start coding")
                    .font(.tomeBody())
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.bottom, 40)
            
            // Action buttons
            VStack(spacing: 16) {
                // Open folder button
                Button(action: { showFolderPicker = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 18))
                        Text("Open Folder")
                            .font(.tomeBodyMedium())
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.purple.opacity(0.6),
                                Color.purple.opacity(0.4)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.purple.opacity(0.5), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Create new project button  
                Button(action: { createNewProject() }) {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 18))
                        Text("Create New Project")
                            .font(.tomeBodyMedium())
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.15, green: 0.15, blue: 0.18))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.bottom, 40)
            
            // Recent projects
            if !recentProjects.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Recent Projects")
                        .font(.tomeBodyMedium())
                        .foregroundColor(.white.opacity(0.9))
                    
                    LazyVStack(spacing: 8) {
                        ForEach(recentProjects) { project in
                            RecentProjectRow(project: project) {
                                onProjectSelected(project.path)
                            }
                        }
                    }
                }
                .padding(.horizontal, 40)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black,
                    Color(red: 0.05, green: 0.05, blue: 0.08)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onAppear {
            loadRecentProjects()
        }
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    let path = url.path
                    saveRecentProject(path: path)
                    onProjectSelected(path)
                }
            case .failure(let error):
                print("Folder selection failed: \(error)")
            }
        }
    }
    
    private func loadRecentProjects() {
        // Load from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "recentProjects"),
           let projects = try? JSONDecoder().decode([RecentProject].self, from: data) {
            recentProjects = projects
        }
    }
    
    private func saveRecentProject(path: String) {
        let projectName = (path as NSString).lastPathComponent
        let newProject = RecentProject(name: projectName, path: path, lastOpened: Date())
        
        // Remove if already exists
        recentProjects.removeAll { $0.path == path }
        
        // Add to beginning
        recentProjects.insert(newProject, at: 0)
        
        // Keep only last 10
        recentProjects = Array(recentProjects.prefix(10))
        
        // Save to UserDefaults
        if let data = try? JSONEncoder().encode(recentProjects) {
            UserDefaults.standard.set(data, forKey: "recentProjects")
        }
    }
    
    private func createNewProject() {
        // Create a new project in Documents/TOME Projects
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let tomeProjectsPath = (documentsPath as NSString).appendingPathComponent("TOME Projects")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(atPath: tomeProjectsPath, withIntermediateDirectories: true)
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let newProjectPath = (tomeProjectsPath as NSString).appendingPathComponent("Project-\(timestamp)")
        
        do {
            try FileManager.default.createDirectory(atPath: newProjectPath, withIntermediateDirectories: true)
            
            // Create a sample file
            let readmePath = (newProjectPath as NSString).appendingPathComponent("README.md")
            let readmeContent = """
            # New TOME Project
            
            Welcome to your new project! Start coding here.
            
            ## Getting Started
            
            1. Create your files using the file explorer
            2. Use the AI assistant to help with code generation
            3. Run your code using the terminal
            
            Happy coding! 🚀
            """
            try readmeContent.write(toFile: readmePath, atomically: true, encoding: .utf8)
            
            saveRecentProject(path: newProjectPath)
            onProjectSelected(newProjectPath)
        } catch {
            print("Failed to create new project: \(error)")
        }
    }
}

struct RecentProject: Codable, Identifiable {
    let id: UUID
    let name: String
    let path: String
    let lastOpened: Date
    
    init(name: String, path: String, lastOpened: Date) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.lastOpened = lastOpened
    }
}

struct RecentProjectRow: View {
    let project: RecentProject
    let onSelect: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: "folder")
                    .font(.system(size: 16))
                    .foregroundColor(.purple.opacity(0.8))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.tomeBodyMedium())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(project.path)
                        .font(.tomeCaption())
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
                
                Text(timeAgoString(from: project.lastOpened))
                    .font(.tomeCaption())
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isHovered ? Color.purple.opacity(0.2) : Color(red: 0.1, green: 0.1, blue: 0.12))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let timeInterval = Date().timeIntervalSince(date)
        
        if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(timeInterval / 86400)
            return "\(days)d ago"
        }
    }
}

// MARK: - VSCode Web Interface

struct VSCodeWebView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea(.all)
            
            // Embedded container with proper spacing
            VStack(spacing: 0) {
                Spacer().frame(height: 60) // Top spacing for embedded feel
                
                HStack(spacing: 0) {
                    Spacer().frame(width: 40) // Left spacing
                    
                    // VSCode web interface - embedded style
                    VSCodeWebInterface()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    Spacer().frame(width: 40) // Right spacing
                }
                
                Spacer().frame(height: 60) // Bottom spacing
            }
        }
    }
}

struct VSCodeWebInterface: NSViewRepresentable {
    typealias NSViewType = VSCodeWebKitView
    
    func makeNSView(context: Context) -> VSCodeWebKitView {
        let webView = VSCodeWebKitView()
        webView.loadVSCode()
        return webView
    }
    
    func updateNSView(_ nsView: VSCodeWebKitView, context: Context) {
        // No updates needed for now
    }
}

class VSCodeWebKitView: WKWebView, WKNavigationDelegate {
    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        let config = WKWebViewConfiguration()
        
        // Enable developer tools and console
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        
        // Create user content controller for custom CSS injection
        let userContentController = WKUserContentController()
        config.userContentController = userContentController
        
        super.init(frame: frame, configuration: config)
        
        self.navigationDelegate = self
        
        // Remove default styling
        self.setValue(false, forKey: "drawsBackground")
        
        // Inject custom CSS to match TOME theme
        injectTOMETheme()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func loadVSCode() {
        // Load VSCode for the web
        if let url = URL(string: "https://vscode.dev/") {
            let request = URLRequest(url: url)
            self.load(request)
        }
    }
    
    private func injectTOMETheme() {
        let tomeThemeCSS = """
        /* TOME Dark Theme for VSCode Web */
        :root {
            --tome-bg: #1e1e1e;
            --tome-surface: #2d2d2d;
            --tome-accent: #007acc;
            --tome-text: #cccccc;
            --tome-border: rgba(255, 255, 255, 0.1);
        }
        
        /* Hide VS Code branding and unnecessary elements */
        .monaco-workbench .part.titlebar {
            display: none !important;
        }
        
        /* Main editor styling */
        .monaco-editor {
            background-color: var(--tome-bg) !important;
        }
        
        .monaco-editor .margin {
            background-color: var(--tome-bg) !important;
        }
        
        /* Activity bar styling */
        .monaco-workbench .activitybar {
            background-color: var(--tome-surface) !important;
            border-right: 1px solid var(--tome-border) !important;
        }
        
        /* Side bar styling */
        .monaco-workbench .sidebar {
            background-color: var(--tome-surface) !important;
            border-right: 1px solid var(--tome-border) !important;
        }
        
        /* Editor group styling */
        .monaco-workbench .editor-group-container {
            background-color: var(--tome-bg) !important;
        }
        
        /* Tab styling */
        .monaco-workbench .tabs-container {
            background-color: var(--tome-surface) !important;
            border-bottom: 1px solid var(--tome-border) !important;
        }
        
        .monaco-workbench .tab {
            background-color: var(--tome-surface) !important;
            border-right: 1px solid var(--tome-border) !important;
            color: var(--tome-text) !important;
        }
        
        .monaco-workbench .tab.active {
            background-color: var(--tome-bg) !important;
            color: white !important;
        }
        
        /* Status bar styling */
        .monaco-workbench .statusbar {
            background-color: var(--tome-accent) !important;
            color: white !important;
        }
        
        /* Panel styling */
        .monaco-workbench .panel {
            background-color: var(--tome-surface) !important;
            border-top: 1px solid var(--tome-border) !important;
        }
        
        /* Menu bar - hide or style */
        .monaco-workbench .menubar {
            background-color: var(--tome-surface) !important;
            color: var(--tome-text) !important;
        }
        
        /* Quick open and command palette */
        .monaco-inputbox {
            background-color: var(--tome-surface) !important;
            border: 1px solid var(--tome-border) !important;
            color: var(--tome-text) !important;
        }
        
        .monaco-list {
            background-color: var(--tome-surface) !important;
        }
        
        .monaco-list .monaco-list-row {
            color: var(--tome-text) !important;
        }
        
        .monaco-list .monaco-list-row.selected {
            background-color: var(--tome-accent) !important;
            color: white !important;
        }
        
        /* Remove rounded corners to match TOME aesthetic */
        .monaco-workbench,
        .monaco-workbench .part {
            border-radius: 0 !important;
        }
        
        /* Custom scrollbar */
        ::-webkit-scrollbar {
            width: 8px;
            height: 8px;
        }
        
        ::-webkit-scrollbar-track {
            background: var(--tome-bg);
        }
        
        ::-webkit-scrollbar-thumb {
            background: var(--tome-border);
            border-radius: 4px;
        }
        
        ::-webkit-scrollbar-thumb:hover {
            background: rgba(255, 255, 255, 0.2);
        }
        
        /* Welcome page styling */
        .monaco-workbench .welcome-page {
            background-color: var(--tome-bg) !important;
            color: var(--tome-text) !important;
        }
        
        /* Settings page styling */
        .monaco-workbench .settings-editor {
            background-color: var(--tome-bg) !important;
            color: var(--tome-text) !important;
        }
        """
        
        let userScript = WKUserScript(
            source: """
            (function() {
                const style = document.createElement('style');
                style.textContent = `\(tomeThemeCSS)`;
                document.head.appendChild(style);
                
                // Also try to set dark theme preference
                setTimeout(() => {
                    if (typeof window !== 'undefined' && window.localStorage) {
                        window.localStorage.setItem('workbench.colorTheme', 'Default Dark+');
                        window.localStorage.setItem('workbench.preferredDarkColorTheme', 'Default Dark+');
                    }
                }, 2000);
            })();
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        
        configuration.userContentController.addUserScript(userScript)
        
        // Add a second injection after page loads completely
        let delayedScript = WKUserScript(
            source: """
            setTimeout(() => {
                const style = document.createElement('style');
                style.textContent = `\(tomeThemeCSS)`;
                document.head.appendChild(style);
                
                // Hide welcome screen after a moment
                setTimeout(() => {
                    const welcomeElement = document.querySelector('.welcome-view');
                    if (welcomeElement) {
                        const closeButton = document.querySelector('.welcome-view .codicon-close');
                        if (closeButton) closeButton.click();
                    }
                }, 3000);
            }, 5000);
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        
        configuration.userContentController.addUserScript(delayedScript)
    }
    
    // MARK: - WKNavigationDelegate
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Apply theme again after page loads
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.applyThemePostLoad()
        }
    }
    
    private func applyThemePostLoad() {
        let themeScript = """
        // Set VS Code theme to dark
        if (typeof window !== 'undefined' && window.localStorage) {
            window.localStorage.setItem('workbench.colorTheme', 'Default Dark+');
            window.localStorage.setItem('workbench.preferredDarkColorTheme', 'Default Dark+');
        }
        
        // Create and inject TOME theme styles
        const tomeStyle = document.getElementById('tome-theme') || document.createElement('style');
        tomeStyle.id = 'tome-theme';
        tomeStyle.innerHTML = `
            .monaco-workbench { background: #1e1e1e !important; }
            .monaco-workbench .part.titlebar { display: none !important; }
            .monaco-workbench .statusbar { background: #007acc !important; }
            .monaco-workbench .activitybar { background: #2d2d2d !important; }
        `;
        document.head.appendChild(tomeStyle);
        """
        
        evaluateJavaScript(themeScript, completionHandler: nil)
    }
}


// MARK: - Terminal Interface

struct EmbeddedTerminalView: View {
    @StateObject private var terminal = TerminalEmulator()
    @Binding var terminalRef: TerminalEmulator?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea(.all)
            
            // Embedded container with proper spacing
            VStack(spacing: 0) {
                Spacer().frame(height: 60) // Top spacing for embedded feel
                
                HStack(spacing: 0) {
                    Spacer().frame(width: 40) // Left spacing
                    
                    // Terminal interface - embedded style
                    TerminalInterface(terminal: terminal)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    Spacer().frame(width: 40) // Right spacing
                }
                
                Spacer().frame(height: 60) // Bottom spacing
            }
        }
        .onAppear {
            terminalRef = terminal
        }
    }
}

struct TerminalInterface: View {
    @ObservedObject var terminal: TerminalEmulator
    @State private var commandInput = ""
    
    var body: some View {
        VStack(spacing: 0) {
            terminalHeader
            terminalOutputArea
            commandInputArea
        }
        .background(LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.08, green: 0.08, blue: 0.12),
                Color(red: 0.05, green: 0.05, blue: 0.08)
            ]),
            startPoint: .top,
            endPoint: .bottom
        ))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var terminalHeader: some View {
        HStack {
            Image(systemName: "terminal.fill")
                .font(.tomeBody())
                .foregroundColor(.green.opacity(0.8))
            
            Text("Terminal")
                .font(.tomeBodyMedium())
                .foregroundColor(.white)
            
            Spacer()
            
            HStack(spacing: 12) {
                Circle()
                    .fill(.green.opacity(0.3))
                    .frame(width: 6, height: 6)
                
                Text("Active")
                    .font(.tomeCaption())
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [Color.gray.opacity(0.15), Color.gray.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var terminalOutputArea: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(terminal.outputLines.indices, id: \.self) { index in
                    Text(terminal.outputLines[index])
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(getLineColor(at: index))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var commandInputArea: some View {
        HStack(spacing: 8) {
            Text(terminal.promptText)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.green)
            
            TextField("Enter command...", text: $commandInput)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.white)
                .textFieldStyle(PlainTextFieldStyle())
                .onSubmit {
                    terminal.executeCommand(commandInput)
                    commandInput = ""
                }
        }
        .padding(16)
        .background(Color.gray.opacity(0.1))
    }
    
    private func getLineColor(at index: Int) -> Color {
        return terminal.lineColors.indices.contains(index) ? terminal.lineColors[index] : .white
    }
}



// MARK: - Terminal Emulator

class TerminalEmulator: ObservableObject {
    @Published var outputLines: [String] = []
    @Published var lineColors: [Color] = []
    @Published var currentDirectory: String = ""
    
    var promptText: String {
        let homeDir = NSHomeDirectory()
        let displayPath: String
        
        if currentDirectory == homeDir {
            displayPath = "~"
        } else if currentDirectory.hasPrefix(homeDir) {
            displayPath = "~" + String(currentDirectory.dropFirst(homeDir.count))
        } else {
            displayPath = currentDirectory
        }
        
        return "\(displayPath) $"
    }
    
    init() {
        // Start in user's home directory
        currentDirectory = NSHomeDirectory()
        
        outputLines = [
            "TOME Terminal v1.0.3",
            "Current directory: \(currentDirectory)",
            "Type 'help' for available commands",
            ""
        ]
        lineColors = [.white.opacity(0.8), .white.opacity(0.6), .white.opacity(0.6), .white]
    }
    
    func executeCommand(_ command: String) {
        // Add command to output with proper prompt
        outputLines.append("\(promptText) \(command)")
        lineColors.append(.green)
        
        // Simulate command execution
        let result = processCommand(command)
        outputLines.append(contentsOf: result.lines)
        lineColors.append(contentsOf: result.colors)
        
        // Scroll to bottom
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    private func processCommand(_ command: String) -> (lines: [String], colors: [Color]) {
        let cmd = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = cmd.split(separator: " ", maxSplits: 1).map(String.init)
        let baseCommand = parts.first?.lowercased() ?? ""
        let argument = parts.count > 1 ? parts[1] : ""
        
        switch baseCommand {
        case "help":
            return (
                lines: [
                    "Available commands:",
                    "  ls [-la] - List directory contents",
                    "  pwd - Show current directory",
                    "  cd <path> - Change directory",
                    "  cd ~ - Go to home directory",
                    "  git status - Show git status (if in git repo)",
                    "  clear - Clear terminal",
                    ""
                ],
                colors: Array(repeating: Color.white.opacity(0.8), count: 8)
            )
            
        case "ls":
            return listDirectory(showHidden: cmd.contains("-a") || cmd.contains("-la"))
            
        case "pwd":
            return (
                lines: [currentDirectory, ""],
                colors: [.white.opacity(0.8), .white]
            )
            
        case "cd":
            return changeDirectory(to: argument)
            
        case "git":
            if argument.lowercased() == "status" {
                return getGitStatus()
            } else {
                return (
                    lines: ["git: '\(argument)' is not a git command. Try 'git status'", ""],
                    colors: [.red, .white]
                )
            }
            
        case "clear":
            outputLines.removeAll()
            lineColors.removeAll()
            return (lines: [], colors: [])
            
        default:
            return (
                lines: ["Command not found: \(baseCommand)", "Type 'help' for available commands", ""],
                colors: [.red, .white.opacity(0.6), .white]
            )
        }
    }
    
    private func listDirectory(showHidden: Bool) -> (lines: [String], colors: [Color]) {
        do {
            let fileManager = FileManager.default
            var contents = try fileManager.contentsOfDirectory(atPath: currentDirectory)
            
            if !showHidden {
                contents = contents.filter { !$0.hasPrefix(".") }
            }
            
            var lines: [String] = []
            var colors: [Color] = []
            
            for item in contents.sorted() {
                let itemPath = (currentDirectory as NSString).appendingPathComponent(item)
                var isDirectory: ObjCBool = false
                fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory)
                
                if showHidden {
                    // Show detailed format like ls -la
                    let permissions = isDirectory.boolValue ? "drwxr-xr-x" : "-rw-r--r--"
                    let displayName = isDirectory.boolValue ? "\(item)/" : item
                    lines.append("\(permissions)  1 user user    \(displayName)")
                } else {
                    // Simple format
                    let displayName = isDirectory.boolValue ? "\(item)/" : item
                    lines.append(displayName)
                }
                
                colors.append(isDirectory.boolValue ? .blue.opacity(0.8) : .white.opacity(0.8))
            }
            
            if lines.isEmpty {
                lines.append("(empty directory)")
                colors.append(.white.opacity(0.6))
            }
            
            lines.append("")
            colors.append(.white)
            
            return (lines: lines, colors: colors)
            
        } catch {
            return (
                lines: ["ls: cannot access '\(currentDirectory)': \(error.localizedDescription)", ""],
                colors: [.red, .white]
            )
        }
    }
    
    private func changeDirectory(to path: String) -> (lines: [String], colors: [Color]) {
        var targetPath = path
        
        if path.isEmpty {
            // cd with no arguments goes to home directory
            targetPath = NSHomeDirectory()
        } else if path == "~" {
            targetPath = NSHomeDirectory()
        } else if path.hasPrefix("~/") {
            targetPath = NSHomeDirectory() + String(path.dropFirst(1))
        } else if !path.hasPrefix("/") {
            // Relative path
            targetPath = (currentDirectory as NSString).appendingPathComponent(path)
        }
        
        // Resolve path (handle .. and .)
        targetPath = (targetPath as NSString).standardizingPath
        
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        
        if fileManager.fileExists(atPath: targetPath, isDirectory: &isDirectory) && isDirectory.boolValue {
            currentDirectory = targetPath
            return (lines: [""], colors: [.white])
        } else {
            return (
                lines: ["cd: no such file or directory: \(path)", ""],
                colors: [.red, .white]
            )
        }
    }
    
    private func getGitStatus() -> (lines: [String], colors: [Color]) {
        // Check if we're in a git repository
        let gitDir = (currentDirectory as NSString).appendingPathComponent(".git")
        let fileManager = FileManager.default
        
        if fileManager.fileExists(atPath: gitDir) {
            return (
                lines: [
                    "On branch main",
                    "Your branch is up to date with 'origin/main'.",
                    "",
                    "nothing to commit, working tree clean",
                    ""
                ],
                colors: [.green, .white.opacity(0.8), .white, .white.opacity(0.8), .white]
            )
        } else {
            return (
                lines: [
                    "fatal: not a git repository (or any of the parent directories): .git",
                    ""
                ],
                colors: [.red, .white]
            )
        }
    }
}

// MARK: - Web View Container

struct WebViewContainer: View {
    let url: String
    
    var body: some View {
        VStack {
            Text("VSCode Web Interface")
                .font(.tomeSubheading())
                .foregroundColor(.white.opacity(0.8))
            
            Text("Connect to \(url)")
                .font(.tomeCaption())
                .foregroundColor(.white.opacity(0.6))
            
            // In a real implementation, this would be a WKWebView
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - IDE Components

class IDEManager: ObservableObject {
    @Published var currentDirectory: String = ""
    @Published var workspaceRoot: String = ""
    @Published var files: [IDEFile] = []
    @Published var openFiles: [IDEFile] = []
    @Published var selectedFile: IDEFile? = nil
    @Published var isLoading = false
    @Published var projectStructure: [ProjectNode] = []
    
    init() {
        currentDirectory = NSHomeDirectory()
        workspaceRoot = currentDirectory
    }
    
    func loadCurrentDirectory() {
        isLoading = true
        files = loadFilesFromDirectory(currentDirectory)
        loadProjectStructure()
        isLoading = false
    }
    
    func openWorkspace(_ path: String) {
        workspaceRoot = path
        currentDirectory = path
        loadCurrentDirectory()
    }
    
    func loadProjectStructure() {
        projectStructure = buildProjectTree(at: workspaceRoot)
    }
    
    func navigateToDirectory(_ path: String) {
        currentDirectory = path
        loadCurrentDirectory()
    }
    
    func openFile(_ file: IDEFile) {
        if !openFiles.contains(where: { $0.path == file.path }) {
            openFiles.append(file)
        }
    }
    
    func closeFile(_ file: IDEFile) {
        openFiles.removeAll { $0.path == file.path }
    }
    
    
    func saveFile(_ file: IDEFile, content: String) {
        do {
            try content.write(toFile: file.path, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to save file: \(error)")
        }
    }
    
    func createFile(_ file: IDEFile) {
        // Write file to disk
        do {
            try file.content.write(toFile: file.path, atomically: true, encoding: .utf8)
            
            // Add to files list and open it
            files.append(file)
            openFile(file)
        } catch {
            print("Failed to create file: \(error)")
        }
    }
    
    func createNewFile(name: String, content: String) {
        let filePath = (currentDirectory as NSString).appendingPathComponent(name)
        let newFile = IDEFile(name: name, path: filePath, isDirectory: false, content: content)
        createFile(newFile)
    }
    
    func updateFile(_ file: IDEFile) {
        // Update the file in the files array
        if let index = files.firstIndex(where: { $0.id == file.id }) {
            files[index] = file
        }
        
        // Update in open files if it's open
        if let index = openFiles.firstIndex(where: { $0.id == file.id }) {
            openFiles[index] = file
        }
        
        // Save to disk
        saveFile(file, content: file.content)
    }
    
    func loadProject(at path: String) {
        currentDirectory = path
        workspaceRoot = path
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let projectFiles = self.loadFilesFromDirectory(path)
            let projectTree = self.buildProjectTree(at: path)
            
            DispatchQueue.main.async {
                self.files = projectFiles
                self.projectStructure = projectTree
                self.isLoading = false
                
                // Open README.md if it exists
                if let readme = projectFiles.first(where: { $0.name.lowercased() == "readme.md" }) {
                    self.openFile(readme)
                }
            }
        }
    }
    
    private func loadFilesFromDirectory(_ path: String) -> [IDEFile] {
        do {
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(atPath: path)
            
            return contents.compactMap { item in
                let itemPath = (path as NSString).appendingPathComponent(item)
                var isDirectory: ObjCBool = false
                
                guard fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory) else {
                    return nil
                }
                
                return IDEFile(
                    name: item,
                    path: itemPath,
                    isDirectory: isDirectory.boolValue,
                    content: isDirectory.boolValue ? "" : (try? String(contentsOfFile: itemPath)) ?? ""
                )
            }.sorted { file1, file2 in
                if file1.isDirectory != file2.isDirectory {
                    return file1.isDirectory
                }
                return file1.name < file2.name
            }
        } catch {
            print("Failed to load directory: \(error)")
            return []
        }
    }
    
    private func buildProjectTree(at path: String, maxDepth: Int = 3, currentDepth: Int = 0) -> [ProjectNode] {
        guard currentDepth < maxDepth else { return [] }
        
        do {
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(atPath: path)
            
            return contents.compactMap { item in
                // Skip hidden files and common ignore patterns
                if item.hasPrefix(".") && ![".", ".."].contains(item) {
                    // Only show important dotfiles
                    let importantDotfiles = [".gitignore", ".env", ".env.local", ".npmrc", ".package.json"]
                    if !importantDotfiles.contains(item) {
                        return nil
                    }
                }
                
                // Skip common build/cache directories
                let ignoreDirs = ["node_modules", ".build", "build", "dist", ".git", "__pycache__", ".vscode"]
                if ignoreDirs.contains(item) {
                    return nil
                }
                
                let itemPath = (path as NSString).appendingPathComponent(item)
                var isDirectory: ObjCBool = false
                
                guard fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory) else {
                    return nil
                }
                
                if isDirectory.boolValue {
                    let children = buildProjectTree(at: itemPath, maxDepth: maxDepth, currentDepth: currentDepth + 1)
                    return ProjectNode(name: item, path: itemPath, isDirectory: true, children: children)
                } else {
                    return ProjectNode(name: item, path: itemPath, isDirectory: false, children: [])
                }
            }.sorted { node1, node2 in
                if node1.isDirectory != node2.isDirectory {
                    return node1.isDirectory
                }
                return node1.name < node2.name
            }
        } catch {
            print("Failed to build project tree: \(error)")
            return []
        }
    }
}

struct IDEFile: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    var content: String
    
    var fileExtension: String {
        (name as NSString).pathExtension.lowercased()
    }
    
    var language: String {
        switch fileExtension {
        case "swift": return "Swift"
        case "js", "jsx": return "JavaScript"
        case "ts", "tsx": return "TypeScript"
        case "py": return "Python"
        case "rs": return "Rust"
        case "go": return "Go"
        case "java": return "Java"
        case "cpp", "cc", "cxx": return "C++"
        case "c": return "C"
        case "php": return "PHP"
        case "rb": return "Ruby"
        case "md": return "Markdown"
        case "json": return "JSON"
        case "xml": return "XML"
        case "html": return "HTML"
        case "css": return "CSS"
        default: return "Text"
        }
    }
    
    static func == (lhs: IDEFile, rhs: IDEFile) -> Bool {
        return lhs.path == rhs.path
    }
}

struct ProjectNode: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    let children: [ProjectNode]
}

struct FileExplorerSidebar: View {
    @ObservedObject var ideManager: IDEManager
    @Binding var selectedFile: IDEFile?
    @State private var showCreateFileDialog = false
    @State private var newFileName = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "folder.fill")
                    .font(.tomeBody())
                    .foregroundColor(.blue.opacity(0.8))
                
                Text("Explorer")
                    .font(.tomeBodyMedium())
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: { showCreateFileDialog = true }) {
                    Image(systemName: "plus")
                        .font(.tomeCaption())
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.15))
            
            // Current directory
            HStack {
                Text(ideManager.currentDirectory.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .font(.tomeCaption())
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                Button(action: {
                    let parentPath = (ideManager.currentDirectory as NSString).deletingLastPathComponent
                    ideManager.navigateToDirectory(parentPath)
                }) {
                    Image(systemName: "arrow.up")
                        .font(.tomeCaption())
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Project tree
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(ideManager.projectStructure) { node in
                        ProjectNodeView(
                            node: node,
                            selectedFile: $selectedFile,
                            ideManager: ideManager,
                            level: 0
                        )
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.8),
                    Color(red: 0.08, green: 0.08, blue: 0.12)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(Color.purple.opacity(0.3))
                .blur(radius: 0.5),
            alignment: .trailing
        )
        .alert("Create New File", isPresented: $showCreateFileDialog) {
            TextField("File name", text: $newFileName)
            Button("Create") {
                if !newFileName.isEmpty {
                    ideManager.createNewFile(name: newFileName, content: "")
                    newFileName = ""
                }
            }
            Button("Cancel", role: .cancel) {
                newFileName = ""
            }
        }
    }
}

struct FileRow: View {
    let file: IDEFile
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: file.isDirectory ? "folder.fill" : fileIcon(for: file.fileExtension))
                    .font(.system(size: 14))
                    .foregroundColor(file.isDirectory ? .blue.opacity(0.8) : fileColor(for: file.fileExtension))
                    .frame(width: 16)
                
                Text(file.name)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                
                Spacer()
                
                if !file.isDirectory {
                    Text(file.language)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue.opacity(0.3) : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func fileIcon(for fileExtension: String) -> String {
        switch fileExtension {
        case "swift": return "swift"
        case "js", "jsx": return "doc.text"
        case "ts", "tsx": return "doc.text"
        case "py": return "doc.text"
        case "rs": return "doc.text"
        case "go": return "doc.text"
        case "java": return "doc.text"
        case "cpp", "cc", "cxx", "c": return "doc.text"
        case "php": return "doc.text"
        case "rb": return "doc.text"
        case "md": return "doc.richtext"
        case "json": return "doc.plaintext"
        case "xml": return "doc.plaintext"
        case "html": return "globe"
        case "css": return "paintbrush"
        default: return "doc"
        }
    }
    
    private func fileColor(for fileExtension: String) -> Color {
        switch fileExtension {
        case "swift": return .orange
        case "js", "jsx": return .yellow
        case "ts", "tsx": return .blue
        case "py": return .green
        case "rs": return .red
        case "go": return .cyan
        case "java": return .orange
        case "cpp", "cc", "cxx", "c": return .blue
        case "php": return .purple
        case "rb": return .red
        case "md": return .white
        case "json": return .yellow.opacity(0.8)
        case "xml": return .orange.opacity(0.8)
        case "html": return .orange
        case "css": return .blue
        default: return .white.opacity(0.6)
        }
    }
}

struct ProjectNodeView: View {
    let node: ProjectNode
    @Binding var selectedFile: IDEFile?
    @ObservedObject var ideManager: IDEManager
    let level: Int
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            // Node content
            HStack(spacing: 4) {
                // Indentation
                if level > 0 {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: CGFloat(level * 16))
                }
                
                // Expand/collapse for directories
                if node.isDirectory {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 12)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 12)
                }
                
                // File/folder icon and name
                Button(action: {
                    if node.isDirectory {
                        // For directories, just expand/collapse
                        isExpanded.toggle()
                    } else {
                        // For files, open them
                        let file = IDEFile(
                            name: node.name,
                            path: node.path,
                            isDirectory: false,
                            content: (try? String(contentsOfFile: node.path)) ?? ""
                        )
                        ideManager.openFile(file)
                        selectedFile = file
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: node.isDirectory ? "folder.fill" : fileIcon(for: node.name))
                            .font(.system(size: 12))
                            .foregroundColor(node.isDirectory ? .blue.opacity(0.8) : fileColor(for: node.name))
                        
                        Text(node.name)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                selectedFile?.path == node.path ? Color.blue.opacity(0.3) : Color.clear
            )
            
            // Children (if directory is expanded)
            if node.isDirectory && isExpanded {
                ForEach(node.children) { child in
                    ProjectNodeView(
                        node: child,
                        selectedFile: $selectedFile,
                        ideManager: ideManager,
                        level: level + 1
                    )
                }
            }
        }
    }
    
    private func fileIcon(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "js", "jsx": return "doc.text"
        case "ts", "tsx": return "doc.text"
        case "py": return "doc.text"
        case "json": return "doc.plaintext"
        case "md": return "doc.richtext"
        case "html": return "globe"
        case "css": return "paintbrush"
        default: return "doc"
        }
    }
    
    private func fileColor(for fileName: String) -> Color {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return .orange
        case "js", "jsx": return .yellow
        case "ts", "tsx": return .blue
        case "py": return .green
        case "json": return .yellow.opacity(0.8)
        case "md": return .white
        case "html": return .orange
        case "css": return .blue
        default: return .white.opacity(0.6)
        }
    }
}

struct EditorTabBar: View {
    let openFiles: [IDEFile]
    @Binding var selectedFile: IDEFile?
    let onCloseFile: (IDEFile) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(openFiles) { file in
                    EditorTab(
                        file: file,
                        isSelected: selectedFile?.path == file.path,
                        onSelect: { selectedFile = file },
                        onClose: { onCloseFile(file) }
                    )
                }
                
                Spacer()
            }
        }
        .frame(height: 40)
        .background(Color(red: 0.18, green: 0.18, blue: 0.18))
    }
}

struct EditorTab: View {
    let file: IDEFile
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Button(action: onSelect) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(file.name)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color(red: 0.12, green: 0.12, blue: 0.12) : Color.clear)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(isSelected ? .blue : .clear),
            alignment: .bottom
        )
    }
}

struct CodeEditor: View {
    let file: IDEFile?
    @ObservedObject var ideManager: IDEManager
    @EnvironmentObject var tomeState: TOMEState
    @State private var editedContent: String = ""
    @State private var hasUnsavedChanges = false
    @State private var currentWord = ""
    @State private var isAITyping = false
    @State private var inlinePreview: String = ""
    @State private var currentSuggestion: CodeSuggestion? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            if let file = file {
                // Editor header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.name)
                            .font(.tomeBodyMedium())
                            .foregroundColor(.white)
                        
                        Text(file.language)
                            .font(.tomeCaption())
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    if hasUnsavedChanges {
                        Button("Save") {
                            ideManager.saveFile(file, content: editedContent)
                            hasUnsavedChanges = false
                        }
                        .font(.tomeCaption())
                        .foregroundColor(.blue)
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.1))
                
                // Code editor area with autocomplete
                ZStack(alignment: .topLeading) {
                    SimpleSyntaxHighlightedEditor(
                        text: $editedContent,
                        fileExtension: getFileExtension(file.name),
                        inlinePreview: inlinePreview,
                        onTabPress: {
                            if !inlinePreview.isEmpty {
                                acceptInlinePreview()
                            }
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onChange(of: editedContent) { _, newValue in
                        hasUnsavedChanges = (newValue != file.content)
                        updateAutocompleteSuggestions(for: newValue)
                    }
                    .onTapGesture {
                        inlinePreview = ""
                    }
                }
                .onAppear {
                    editedContent = file.content
                    hasUnsavedChanges = false
                }
                .onChange(of: file.path) { _, _ in
                    editedContent = file.content
                    hasUnsavedChanges = false
                }
            } else {
                // Welcome screen
                VStack(spacing: 20) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.3))
                    
                    Text("Welcome to TOME IDE")
                        .font(.tomeHeading())
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("Select a file from the explorer to start editing")
                        .font(.tomeBody())
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 0.12, green: 0.12, blue: 0.12))
            }
        }
        .onAppear {
            setupAITypingObservers()
        }
    }
    
    // MARK: - Autocomplete Methods
    
    private func updateAutocompleteSuggestions(for text: String) {
        guard let file = file else { return }
        
        // Get context around cursor
        let lines = text.components(separatedBy: .newlines)
        let currentLine = lines.last ?? ""
        
        // Only show suggestions if typing on a meaningful line
        if currentLine.trimmingCharacters(in: .whitespaces).count > 2 {
            currentWord = currentLine
            
            // First try basic keyword suggestions for immediate response
            let _ = getBasicSuggestions(for: currentLine, fileType: file.fileExtension)
            
            // Then get AI-powered suggestions
            getAIAutocompleteSuggestions(
                currentLine: currentLine,
                fullContext: text,
                fileType: file.fileExtension,
                fileName: file.name,
                tomeState: tomeState
            ) { aiSuggestions in
                DispatchQueue.main.async {
                    // Set inline preview to the first AI suggestion if available
                    if let firstSuggestion = aiSuggestions.first {
                        currentSuggestion = firstSuggestion
                        inlinePreview = firstSuggestion.completion
                    }
                }
            }
        } else {
            inlinePreview = ""
        }
    }
    
    private func insertSuggestion(_ suggestion: CodeSuggestion) {
        // Get current lines and find where to insert
        let lines = editedContent.components(separatedBy: .newlines)
        guard !lines.isEmpty else {
            editedContent = suggestion.completion
            hasUnsavedChanges = true
            return
        }
        
        var modifiedLines = lines
        let lastLineIndex = modifiedLines.count - 1
        let lastLine = modifiedLines[lastLineIndex]
        
        // Find the current word being typed (word at the end of the line)
        let words = lastLine.components(separatedBy: .whitespaces)
        if !words.isEmpty && words.last == currentWord.trimmingCharacters(in: .whitespaces) {
            // Replace the current word with the suggestion
            var modifiedWords = words
            modifiedWords[modifiedWords.count - 1] = suggestion.completion
            modifiedLines[lastLineIndex] = modifiedWords.joined(separator: " ")
        } else {
            // Append the suggestion to the current line
            if lastLine.hasSuffix(" ") || lastLine.isEmpty {
                modifiedLines[lastLineIndex] = lastLine + suggestion.completion
            } else {
                modifiedLines[lastLineIndex] = lastLine + " " + suggestion.completion
            }
        }
        
        editedContent = modifiedLines.joined(separator: "\n")
        hasUnsavedChanges = true
        
        // Save the changes to the file
        if let file = file {
            ideManager.saveFile(file, content: editedContent)
        }
    }
    
    private func acceptInlinePreview() {
        guard !inlinePreview.isEmpty else { return }
        
        let textToType = inlinePreview
        inlinePreview = ""
        currentSuggestion = nil
        
        // Animate typing the suggestion
        animateTyping(text: textToType)
    }
    
    private func animateTyping(text: String) {
        let characters = Array(text)
        var currentIndex = 0
        
        // Start typing animation
        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
            if currentIndex < characters.count {
                editedContent += String(characters[currentIndex])
                currentIndex += 1
                hasUnsavedChanges = true
            } else {
                timer.invalidate()
                
                // Save the changes to the file after typing is complete
                if let file = file {
                    ideManager.saveFile(file, content: editedContent)
                }
            }
        }
    }
    
    private func getFileExtension(_ fileName: String) -> String {
        return (fileName as NSString).pathExtension.lowercased()
    }
    
    private func getBasicSuggestions(for line: String, fileType: String) -> [CodeSuggestion] {
        let keywords = getKeywords(for: fileType)
        let lowercaseWord = line.lowercased()
        
        return keywords
            .filter { $0.keyword.lowercased().contains(lowercaseWord.trimmingCharacters(in: .whitespaces)) }
            .sorted { $0.keyword.count < $1.keyword.count }
            .prefix(3)
            .map { $0 }
    }
    
    private func getAIAutocompleteSuggestions(
        currentLine: String,
        fullContext: String,
        fileType: String,
        fileName: String,
        tomeState: TOMEState,
        completion: @escaping ([CodeSuggestion]) -> Void
    ) {
        // Get AI service from environment
        guard let aiAgent = tomeState.globalAIAgent else {
            completion([])
            return
        }
        
        // Don't show autocomplete during typing animations
        if aiAgent.isAnimatingTyping {
            completion([])
            return
        }
        
        let prompt = buildAutocompletePrompt(
            currentLine: currentLine,
            fullContext: fullContext,
            fileType: fileType,
            fileName: fileName
        )
        
        // Use a direct AI call that doesn't go through chat
        aiAgent.generateAutocompleteResponse(prompt: prompt) { response in
            if let response = response {
                let suggestions = self.parseAIAutocompletions(response)
                completion(suggestions)
            } else {
                completion([])
            }
        }
    }
    
    private func buildAutocompletePrompt(
        currentLine: String,
        fullContext: String,
        fileType: String,
        fileName: String
    ) -> String {
        let lines = fullContext.components(separatedBy: "\n")
        let currentLineIndex = lines.count - 1
        
        // Get indentation context from previous lines
        let indentationContext = getIndentationContext(lines: lines, currentIndex: currentLineIndex)
        
        // Get the part of current line before cursor
        let currentLineBeforeCursor = currentLine
        
        return """
        INTELLIGENT CODE COMPLETION - Generate precise contextual code completion.
        
        File: \(fileName) (\(fileType))
        Current line before cursor: "\(currentLineBeforeCursor)"
        Current indentation level: \(indentationContext.level) spaces
        Previous line indentation: \(indentationContext.previousLevel) spaces
        
        Full context (last 10 lines):
        \(lines.suffix(10).joined(separator: "\n"))
        
        Generate ONE precise code completion that continues from the cursor position.
        
        CRITICAL RULES:
        - PRESERVE the exact indentation level (\(indentationContext.level) spaces) for the current line
        - If this is a new line after an indent-increasing statement (function, if, for, class, etc.), increase indentation by 4 spaces
        - If completing a partial line, continue exactly from where the text ends
        - Match the existing code style and spacing patterns
        - For \(fileType): follow language-specific indentation and syntax rules
        - Return ONLY the completion text, no explanations
        - Ensure proper formatting and consistent spacing
        
        Example format:
        If current line is "    def calculate_" complete with "sum(a, b):\n        return a + b"
        If current line is "# merge sort" complete with full implementation maintaining indentation
        
        Return ONLY the code completion, no explanation needed.
        """
    }
    
    private func getIndentationContext(lines: [String], currentIndex: Int) -> (level: Int, previousLevel: Int) {
        let currentLine = currentIndex < lines.count ? lines[currentIndex] : ""
        let previousLine = currentIndex > 0 ? lines[currentIndex - 1] : ""
        
        let currentLevel = countLeadingSpaces(currentLine)
        let previousLevel = countLeadingSpaces(previousLine)
        
        return (level: currentLevel, previousLevel: previousLevel)
    }
    
    private func countLeadingSpaces(_ line: String) -> Int {
        var count = 0
        for char in line {
            if char == " " {
                count += 1
            } else if char == "\t" {
                count += 4  // Treat tab as 4 spaces
            } else {
                break
            }
        }
        return count
    }
    
    private func parseAIAutocompletions(_ response: String) -> [CodeSuggestion] {
        // Clean up the response and treat it as a single completion
        let cleanedResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !cleanedResponse.isEmpty {
            // Create a single suggestion from the entire response
            return [CodeSuggestion(
                keyword: "AI Completion",
                completion: cleanedResponse,
                description: "AI-generated code completion"
            )]
        }
        
        return []
    }
    
    private func getKeywords(for fileType: String) -> [CodeSuggestion] {
        switch fileType {
        case "swift":
            return [
                CodeSuggestion(keyword: "func", completion: "func ", description: "Function declaration"),
                CodeSuggestion(keyword: "class", completion: "class ", description: "Class declaration"),
                CodeSuggestion(keyword: "struct", completion: "struct ", description: "Struct declaration"),
                CodeSuggestion(keyword: "enum", completion: "enum ", description: "Enum declaration"),
                CodeSuggestion(keyword: "protocol", completion: "protocol ", description: "Protocol declaration"),
                CodeSuggestion(keyword: "extension", completion: "extension ", description: "Extension declaration"),
                CodeSuggestion(keyword: "import", completion: "import ", description: "Import statement"),
                CodeSuggestion(keyword: "var", completion: "var ", description: "Variable declaration"),
                CodeSuggestion(keyword: "let", completion: "let ", description: "Constant declaration"),
                CodeSuggestion(keyword: "if", completion: "if ", description: "Conditional statement"),
                CodeSuggestion(keyword: "else", completion: "else ", description: "Else clause"),
                CodeSuggestion(keyword: "for", completion: "for ", description: "For loop"),
                CodeSuggestion(keyword: "while", completion: "while ", description: "While loop"),
                CodeSuggestion(keyword: "return", completion: "return ", description: "Return statement"),
                CodeSuggestion(keyword: "guard", completion: "guard ", description: "Guard statement"),
                CodeSuggestion(keyword: "switch", completion: "switch ", description: "Switch statement"),
                CodeSuggestion(keyword: "case", completion: "case ", description: "Case statement"),
                CodeSuggestion(keyword: "private", completion: "private ", description: "Private access modifier"),
                CodeSuggestion(keyword: "public", completion: "public ", description: "Public access modifier"),
                CodeSuggestion(keyword: "override", completion: "override ", description: "Override modifier")
            ]
        case "py":
            return [
                CodeSuggestion(keyword: "def", completion: "def ", description: "Function definition"),
                CodeSuggestion(keyword: "class", completion: "class ", description: "Class definition"),
                CodeSuggestion(keyword: "import", completion: "import ", description: "Import statement"),
                CodeSuggestion(keyword: "from", completion: "from ", description: "From import"),
                CodeSuggestion(keyword: "if", completion: "if ", description: "Conditional statement"),
                CodeSuggestion(keyword: "elif", completion: "elif ", description: "Elif clause"),
                CodeSuggestion(keyword: "else", completion: "else:", description: "Else clause"),
                CodeSuggestion(keyword: "for", completion: "for ", description: "For loop"),
                CodeSuggestion(keyword: "while", completion: "while ", description: "While loop"),
                CodeSuggestion(keyword: "return", completion: "return ", description: "Return statement"),
                CodeSuggestion(keyword: "try", completion: "try:", description: "Try block"),
                CodeSuggestion(keyword: "except", completion: "except ", description: "Exception handler"),
                CodeSuggestion(keyword: "finally", completion: "finally:", description: "Finally block"),
                CodeSuggestion(keyword: "with", completion: "with ", description: "Context manager"),
                CodeSuggestion(keyword: "lambda", completion: "lambda ", description: "Lambda function"),
                CodeSuggestion(keyword: "print", completion: "print()", description: "Print function")
            ]
        case "js", "jsx":
            return [
                CodeSuggestion(keyword: "function", completion: "function ", description: "Function declaration"),
                CodeSuggestion(keyword: "const", completion: "const ", description: "Constant declaration"),
                CodeSuggestion(keyword: "let", completion: "let ", description: "Variable declaration"),
                CodeSuggestion(keyword: "var", completion: "var ", description: "Variable declaration"),
                CodeSuggestion(keyword: "if", completion: "if ", description: "Conditional statement"),
                CodeSuggestion(keyword: "else", completion: "else ", description: "Else clause"),
                CodeSuggestion(keyword: "for", completion: "for ", description: "For loop"),
                CodeSuggestion(keyword: "while", completion: "while ", description: "While loop"),
                CodeSuggestion(keyword: "return", completion: "return ", description: "Return statement"),
                CodeSuggestion(keyword: "import", completion: "import ", description: "Import statement"),
                CodeSuggestion(keyword: "export", completion: "export ", description: "Export statement"),
                CodeSuggestion(keyword: "class", completion: "class ", description: "Class declaration"),
                CodeSuggestion(keyword: "extends", completion: "extends ", description: "Class inheritance"),
                CodeSuggestion(keyword: "async", completion: "async ", description: "Async function"),
                CodeSuggestion(keyword: "await", completion: "await ", description: "Await expression"),
                CodeSuggestion(keyword: "console.log", completion: "console.log()", description: "Console log")
            ]
        default:
            return []
        }
    }
    
    private func setupAITypingObservers() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AITypingCharacter"),
            object: nil,
            queue: .main
        ) { notification in
            if let character = notification.object as? String {
                isAITyping = true
                editedContent += character
                hasUnsavedChanges = true
            }
        }
    }
}

struct AIAssistantPanel: View {
    @ObservedObject var ideManager: IDEManager
    let selectedFile: IDEFile?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.tomeBody())
                    .foregroundColor(.purple.opacity(0.8))
                
                Text("AI Assistant")
                    .font(.tomeBodyMedium())
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.15))
            
            // AI suggestions based on current file
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if let file = selectedFile {
                        AICodeSuggestion(
                            title: "Explain this code",
                            description: "Get a detailed explanation of the current file"
                        )
                        
                        AICodeSuggestion(
                            title: "Generate documentation",
                            description: "Create comments and documentation for this \(file.language) file"
                        )
                        
                        AICodeSuggestion(
                            title: "Optimize performance",
                            description: "Suggest improvements for better performance"
                        )
                        
                        AICodeSuggestion(
                            title: "Add error handling",
                            description: "Implement proper error handling patterns"
                        )
                        
                        AICodeSuggestion(
                            title: "Create unit tests",
                            description: "Generate unit tests for this code"
                        )
                    } else {
                        AICodeSuggestion(
                            title: "Create new project",
                            description: "Set up a new development project with boilerplate code"
                        )
                        
                        AICodeSuggestion(
                            title: "Generate component",
                            description: "Create a new code component or module"
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(Color(red: 0.15, green: 0.15, blue: 0.15))
    }
}

struct AICodeSuggestion: View {
    let title: String
    let description: String
    @EnvironmentObject var tomeState: TOMEState
    
    var body: some View {
        Button(action: {
            executeAISuggestion()
        }) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.tomeCaption())
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.purple.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func executeAISuggestion() {
        guard let aiAgent = tomeState.globalAIAgent else { return }
        
        // Execute direct actions based on the suggestion title
        switch title {
        case "Create new project":
            aiAgent.executeDirectCommand("create_file", parameters: ["fileName": "main.py", "content": "def merge_sort(arr):\n    if len(arr) <= 1:\n        return arr\n    \n    mid = len(arr) // 2\n    left = merge_sort(arr[:mid])\n    right = merge_sort(arr[mid:])\n    \n    return merge(left, right)\n\ndef merge(left, right):\n    result = []\n    i = j = 0\n    \n    while i < len(left) and j < len(right):\n        if left[i] <= right[j]:\n            result.append(left[i])\n            i += 1\n        else:\n            result.append(right[j])\n            j += 1\n    \n    result.extend(left[i:])\n    result.extend(right[j:])\n    return result"])
            
            aiAgent.executeDirectCommand("create_file", parameters: ["fileName": "main_runner.py", "content": "from merge_sort import merge_sort\n\ndef main():\n    # Get user input\n    numbers_input = input(\"Enter numbers separated by spaces: \")\n    numbers = list(map(int, numbers_input.split()))\n    \n    print(f\"Original list: {numbers}\")\n    \n    # Sort using merge sort\n    sorted_numbers = merge_sort(numbers)\n    \n    print(f\"Sorted list: {sorted_numbers}\")\n\nif __name__ == \"__main__\":\n    main()"])
            
        case "Generate component":
            aiAgent.executeDirectCommand("create_file", parameters: ["fileName": "component.py", "content": "# Generated component\nclass Component:\n    def __init__(self):\n        self.initialized = True\n    \n    def render(self):\n        return \"Component rendered\""])
            
        default:
            // For other suggestions, send as message
            let message = "\(title): \(description)"
            aiAgent.sendMessage(message) { result in
                switch result {
                case .success(let response):
                    print("AI suggestion executed: \(response)")
                case .failure(let error):
                    print("AI suggestion failed: \(error)")
                }
            }
        }
    }
}

// MARK: - IDE Toolbar

struct IDEToolbar: View {
    @Binding var showTerminal: Bool
    @Binding var showAI: Bool
    @ObservedObject var ideManager: IDEManager
    let selectedFile: IDEFile?
    let terminal: TerminalEmulator
    
    var body: some View {
        HStack {
            // Run buttons
            HStack(spacing: 8) {
                Button(action: { runCurrentFile() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12))
                        Text("Run")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.8))
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { debugCurrentFile() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "ladybug.fill")
                            .font(.system(size: 12))
                        Text("Debug")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.8))
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Spacer()
            
            // Current directory
            Text(ideManager.currentDirectory.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            // Panel toggles
            HStack(spacing: 8) {
                Button(action: { showTerminal.toggle() }) {
                    Image(systemName: "terminal")
                        .font(.system(size: 14))
                        .foregroundColor(showTerminal ? .cyan : .white.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { showAI.toggle() }) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 14))
                        .foregroundColor(showAI ? .purple : .white.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(red: 0.18, green: 0.18, blue: 0.18))
    }
    
    private func runCurrentFile() {
        guard let file = selectedFile else {
            terminal.executeCommand("echo 'No file selected'")
            return
        }
        
        // Save the file first
        ideManager.saveFile(file, content: file.content)
        
        // Ensure terminal is visible
        showTerminal = true
        
        // Run based on file type
        let runCommand = getRunCommand(for: file)
        if !runCommand.isEmpty {
            terminal.executeCommand(runCommand)
        } else {
            terminal.executeCommand("echo 'Unsupported file type: \(file.fileExtension)'")
        }
    }
    
    private func debugCurrentFile() {
        guard let file = selectedFile else {
            terminal.executeCommand("echo 'No file selected'")
            return
        }
        
        // Save the file first
        ideManager.saveFile(file, content: file.content)
        
        // Ensure terminal is visible
        showTerminal = true
        
        // Debug based on file type
        let debugCommand = getDebugCommand(for: file)
        if !debugCommand.isEmpty {
            terminal.executeCommand(debugCommand)
        } else {
            terminal.executeCommand("echo 'Debugging not supported for: \(file.fileExtension)'")
        }
    }
    
    private func getRunCommand(for file: IDEFile) -> String {
        let fileName = file.name
        let filePath = file.path
        
        switch file.fileExtension {
        case "py":
            return "python3 \"\(filePath)\""
        case "js":
            return "node \"\(filePath)\""
        case "ts":
            return "npx ts-node \"\(filePath)\""
        case "swift":
            return "swift \"\(filePath)\""
        case "rs":
            // For Rust, we need to compile first
            let directory = (filePath as NSString).deletingLastPathComponent
            return "cd \"\(directory)\" && rustc \"\(fileName)\" && ./\((fileName as NSString).deletingPathExtension)\""
        case "go":
            return "go run \"\(filePath)\""
        case "java":
            let className = (fileName as NSString).deletingPathExtension
            let directory = (filePath as NSString).deletingLastPathComponent
            return "cd \"\(directory)\" && javac \"\(fileName)\" && java \"\(className)\""
        case "cpp", "cc", "cxx":
            let outputName = (fileName as NSString).deletingPathExtension
            let directory = (filePath as NSString).deletingLastPathComponent
            return "cd \"\(directory)\" && g++ \"\(fileName)\" -o \"\(outputName)\" && ./\"\(outputName)\""
        case "c":
            let outputName = (fileName as NSString).deletingPathExtension
            let directory = (filePath as NSString).deletingLastPathComponent
            return "cd \"\(directory)\" && gcc \"\(fileName)\" -o \"\(outputName)\" && ./\"\(outputName)\""
        case "rb":
            return "ruby \"\(filePath)\""
        case "php":
            return "php \"\(filePath)\""
        case "sh":
            return "bash \"\(filePath)\""
        default:
            return ""
        }
    }
    
    private func getDebugCommand(for file: IDEFile) -> String {
        let fileName = file.name
        let filePath = file.path
        
        switch file.fileExtension {
        case "py":
            return "python3 -m pdb \"\(filePath)\""
        case "js":
            return "node --inspect \"\(filePath)\""
        case "swift":
            return "lldb -- swift \"\(filePath)\""
        case "cpp", "cc", "cxx":
            let outputName = (fileName as NSString).deletingPathExtension
            let directory = (filePath as NSString).deletingLastPathComponent
            return "cd \"\(directory)\" && g++ -g \"\(fileName)\" -o \"\(outputName)\" && lldb ./\"\(outputName)\""
        case "c":
            let outputName = (fileName as NSString).deletingPathExtension
            let directory = (filePath as NSString).deletingLastPathComponent
            return "cd \"\(directory)\" && gcc -g \"\(fileName)\" -o \"\(outputName)\" && lldb ./\"\(outputName)\""
        case "go":
            return "dlv debug \"\(filePath)\""
        default:
            return ""
        }
    }
}

// MARK: - IDE Terminal Panel

struct IDETerminalPanel: View {
    @ObservedObject var terminal: TerminalEmulator
    @State private var commandInput = ""
    @State private var isAITyping = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Terminal header
            HStack {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.cyan)
                
                Text("Terminal")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: clearTerminal) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(red: 0.15, green: 0.15, blue: 0.15))
            
            // Terminal output
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(terminal.outputLines.indices, id: \.self) { index in
                            Text(terminal.outputLines[index])
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(getLineColor(at: index))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(index)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .background(Color(red: 0.08, green: 0.08, blue: 0.08))
                .onChange(of: terminal.outputLines.count) { _, _ in
                    if !terminal.outputLines.isEmpty {
                        withAnimation {
                            proxy.scrollTo(terminal.outputLines.count - 1, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Command input
            HStack(spacing: 8) {
                Text(terminal.promptText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.cyan)
                
                TextField("Enter command...", text: $commandInput)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit {
                        terminal.executeCommand(commandInput)
                        commandInput = ""
                    }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.12),
                    Color(red: 0.05, green: 0.05, blue: 0.08)
                ]),
                startPoint: .top,
                endPoint: .bottom
            ))
        }
        .background(LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.08, green: 0.08, blue: 0.12),
                Color(red: 0.05, green: 0.05, blue: 0.08)
            ]),
            startPoint: .top,
            endPoint: .bottom
        ))
        .overlay(
            Rectangle()
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            setupAITerminalTypingObservers()
        }
    }
    
    private func getLineColor(at index: Int) -> Color {
        return terminal.lineColors.indices.contains(index) ? terminal.lineColors[index] : .white
    }
    
    private func clearTerminal() {
        terminal.outputLines.removeAll()
        terminal.lineColors.removeAll()
    }
    
    private func setupAITerminalTypingObservers() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AITypingTerminalCharacter"),
            object: nil,
            queue: .main
        ) { notification in
            if let character = notification.object as? String {
                isAITyping = true
                commandInput += character
            }
        }
    }
}

// MARK: - Autocomplete Supporting Types

struct CodeSuggestion: Identifiable {
    let id = UUID()
    let keyword: String
    let completion: String
    let description: String
}

// MARK: - Syntax Highlighted Text Editor

struct SimpleSyntaxHighlightedEditor: View {
    @Binding var text: String
    let fileExtension: String
    let inlinePreview: String
    let onTabPress: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Line numbers
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { index, _ in
                    Text("\(index + 1)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(minWidth: 30, alignment: .trailing)
                        .frame(height: 18)
                }
            }
            .padding(.trailing, 8)
            .background(Color(red: 0.1, green: 0.1, blue: 0.1))
            
            // Main text editor with proper alignment
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.clear)
                    .background(.clear)
                    .scrollContentBackground(.hidden)
                    .textFieldStyle(.plain)
                    .onKeyPress(.tab) {
                        if !inlinePreview.isEmpty {
                            onTabPress()
                            return .handled
                        }
                        return .ignored
                    }
                
                // Syntax highlighting overlay with exact same font metrics
                SyntaxHighlightedTextOverlay(text: text, fileExtension: fileExtension)
                    .font(.system(size: 13, design: .monospaced))
                    .allowsHitTesting(false)
                    
                    // Inline preview overlay - show all lines
                    if !inlinePreview.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            let textLines = text.components(separatedBy: "\n")
                            let previewLines = inlinePreview.components(separatedBy: "\n")
                            
                            ForEach(0..<textLines.count, id: \.self) { index in
                                HStack {
                                    Text(textLines[index])
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundColor(.clear)
                                    
                                    if index == textLines.count - 1 {
                                        // Show first line of preview inline
                                        Text(previewLines.first ?? "")
                                            .font(.system(size: 13, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.4))
                                            .italic()
                                    }
                                    
                                    Spacer()
                                }
                                .frame(height: 18)
                            }
                            
                            // Show remaining preview lines
                            if previewLines.count > 1 {
                                ForEach(1..<previewLines.count, id: \.self) { lineIndex in
                                    HStack {
                                        Text(previewLines[lineIndex])
                                            .font(.system(size: 13, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.4))
                                            .italic()
                                        Spacer()
                                    }
                                    .frame(height: 18)
                                }
                            }
                            
                            Spacer()
                        }
                        .allowsHitTesting(false)
                    }
                }
            }
            .background(Color(red: 0.12, green: 0.12, blue: 0.12))
    }
}

struct SyntaxHighlightedTextOverlay: View {
    let text: String
    let fileExtension: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { index, line in
                HStack(spacing: 0) {
                    SimpleSyntaxHighlightedLine(line: line, fileExtension: fileExtension)
                    Spacer()
                }
                .frame(height: 18, alignment: .leading)
            }
            Spacer()
        }
    }
}

struct SimpleSyntaxHighlightedLine: View {
    let line: String
    let fileExtension: String
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tokenizeLine(line).enumerated()), id: \.offset) { _, token in
                Text(token.text)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(colorForTokenType(token.type))
            }
        }
    }
    
    private func tokenizeLine(_ line: String) -> [SyntaxToken] {
        var tokens: [SyntaxToken] = []
        let words = line.components(separatedBy: .whitespacesAndNewlines)
        
        for word in words {
            if word.isEmpty { continue }
            
            let tokenType = getWordType(word)
            tokens.append(SyntaxToken(text: word, type: tokenType))
            
            // Add space after word if not last
            if word != words.last {
                tokens.append(SyntaxToken(text: " ", type: .normal))
            }
        }
        
        return tokens
    }
    
    private func getWordType(_ word: String) -> SyntaxTokenType {
        // Comments
        if word.hasPrefix("//") || word.hasPrefix("#") {
            return .comment
        }
        
        // Strings
        if (word.hasPrefix("\"") && word.hasSuffix("\"")) || (word.hasPrefix("'") && word.hasSuffix("'")) {
            return .string
        }
        
        // Keywords
        let keywords = ["func", "var", "let", "if", "else", "for", "while", "class", "struct", "enum", "import", "return", "true", "false", "nil", "self", "super", "switch", "case", "default", "break", "continue", "public", "private", "internal", "static", "override", "final", "def", "print"]
        if keywords.contains(word) {
            return .keyword
        }
        
        // Numbers
        if Double(word) != nil {
            return .number
        }
        
        return .normal
    }
    
    private func colorForTokenType(_ type: SyntaxTokenType) -> Color {
        switch type {
        case .keyword:
            return Color(red: 0.8, green: 0.4, blue: 1.0) // Purple
        case .string:
            return Color(red: 0.4, green: 0.8, blue: 0.4) // Green
        case .comment:
            return Color(red: 0.6, green: 0.6, blue: 0.6) // Gray
        case .number:
            return Color(red: 1.0, green: 0.6, blue: 0.4) // Orange
        case .function:
            return Color(red: 1.0, green: 1.0, blue: 0.4) // Yellow
        case .`operator`:
            return Color(red: 0.4, green: 0.8, blue: 1.0) // Cyan
        case .normal:
            return Color.white // Normal text should be white
        }
    }
}

struct SyntaxHighlightedOverlay: View {
    let text: String
    let fileExtension: String
    let inlinePreview: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Line numbers
            lineNumbersView
            // Syntax highlighted text
            syntaxHighlightedTextView
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    private var lineNumbersView: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { index, _ in
                Text("\(index + 1)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(minWidth: 30, alignment: .trailing)
                    .padding(.vertical, 1)
            }
        }
        .padding(.trailing, 10)
        .background(Color(red: 0.1, green: 0.1, blue: 0.1))
    }
    
    private var syntaxHighlightedTextView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { index, line in
                HStack(alignment: .top, spacing: 0) {
                    SyntaxHighlightedLine(line: line, fileExtension: fileExtension)
                    
                    // Show inline preview on the last line if available
                    if index == text.components(separatedBy: "\n").count - 1 && !inlinePreview.isEmpty {
                        Text(inlinePreview)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                            .italic()
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 18, alignment: .leading)
            }
        }
    }
}

struct SyntaxHighlightedLine: View {
    let line: String
    let fileExtension: String
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tokenizeLine(line).enumerated()), id: \.offset) { _, token in
                Text(token.text)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(colorForTokenType(token.type))
            }
        }
        .frame(minHeight: 18, alignment: .leading)
    }
    
    private func tokenizeLine(_ line: String) -> [SyntaxToken] {
        // Simple word-based tokenization
        let words = line.components(separatedBy: .whitespacesAndNewlines)
        var tokens: [SyntaxToken] = []
        var position = 0
        
        for word in words {
            if word.isEmpty { continue }
            
            // Find the actual position of this word in the line
            if let range = line.range(of: word, range: line.index(line.startIndex, offsetBy: position)..<line.endIndex) {
                // Add any whitespace before the word
                let beforeWord = String(line[line.index(line.startIndex, offsetBy: position)..<range.lowerBound])
                if !beforeWord.isEmpty {
                    tokens.append(SyntaxToken(text: beforeWord, type: .normal))
                }
                
                // Determine word type and add token
                let tokenType = getWordType(word)
                tokens.append(SyntaxToken(text: word, type: tokenType))
                
                position = line.distance(from: line.startIndex, to: range.upperBound)
            }
        }
        
        // Add any remaining text
        if position < line.count {
            let remaining = String(line[line.index(line.startIndex, offsetBy: position)...])
            if !remaining.isEmpty {
                tokens.append(SyntaxToken(text: remaining, type: .normal))
            }
        }
        
        return tokens
    }
    
    private func getWordType(_ word: String) -> SyntaxTokenType {
        // Comments
        if word.hasPrefix("//") || word.hasPrefix("#") {
            return .comment
        }
        
        // Strings
        if (word.hasPrefix("\"") && word.hasSuffix("\"")) || (word.hasPrefix("'") && word.hasSuffix("'")) {
            return .string
        }
        
        // Keywords
        let keywords = ["func", "var", "let", "if", "else", "for", "while", "class", "struct", "enum", "import", "return", "true", "false", "nil", "self", "super", "switch", "case", "default", "break", "continue", "public", "private", "internal", "static", "override", "final", "lazy", "weak", "strong", "unowned", "mutating", "nonmutating", "convenience", "required", "optional", "throws", "rethrows", "async", "await", "actor", "isolated", "nonisolated"]
        if keywords.contains(word) {
            return .keyword
        }
        
        // Numbers
        if Double(word) != nil {
            return .number
        }
        
        return .normal
    }
    
    private func colorForTokenType(_ type: SyntaxTokenType) -> Color {
        switch type {
        case .keyword:
            return Color(red: 0.8, green: 0.4, blue: 1.0) // Purple
        case .string:
            return Color(red: 0.4, green: 0.8, blue: 0.4) // Green
        case .comment:
            return Color(red: 0.6, green: 0.6, blue: 0.6) // Gray
        case .number:
            return Color(red: 1.0, green: 0.6, blue: 0.4) // Orange
        case .function:
            return Color(red: 1.0, green: 1.0, blue: 0.4) // Yellow
        case .`operator`:
            return Color(red: 0.4, green: 0.8, blue: 1.0) // Cyan
        case .normal:
            return Color.white
        }
    }
}

struct SyntaxToken {
    let text: String
    let type: SyntaxTokenType
}

enum SyntaxTokenType {
    case keyword
    case string
    case comment
    case number
    case function
    case `operator`
    case normal
}

struct AutocompleteSuggestionsView: View {
    let suggestions: [CodeSuggestion]
    let onSelect: (CodeSuggestion) -> Void
    @State private var hoveredSuggestion: UUID? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(suggestions) { suggestion in
                Button(action: { onSelect(suggestion) }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.keyword)
                                .font(.system(size: 12, design: .monospaced))
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            
                            Text(suggestion.description)
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.turn.down.left")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(hoveredSuggestion == suggestion.id ? 
                        Color.purple.opacity(0.3) : 
                        Color(red: 0.15, green: 0.15, blue: 0.15)
                    )
                    .overlay(
                        Rectangle()
                            .frame(height: 0.5)
                            .foregroundColor(.white.opacity(0.1)),
                        alignment: .bottom
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { isHovered in
                    hoveredSuggestion = isHovered ? suggestion.id : nil
                }
            }
        }
        .background(Color(red: 0.1, green: 0.1, blue: 0.1))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(radius: 8)
        .frame(width: 200)
    }
}