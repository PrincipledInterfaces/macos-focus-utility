import SwiftUI

struct WorkshopView: View {
    @ObservedObject var currentState: TOMEState
    @StateObject private var windowManager = WindowManagementService()
    @State private var showOverlay = false
    @State private var selectedApp: DetectedApp? = nil
    @State private var availableApps: [DetectedApp] = []
    @State private var progressValue: Double = 0.0
    @State private var currentTask = "Creative Session"
    @State private var quickNotes = ""
    @State private var capturedIdeas: [String] = []
    @State private var sessionTimer: TimeInterval = 0
    @State private var isTimerRunning = false
    
    let onNavigateHome: () -> Void
    
    init(currentState: TOMEState, onNavigateHome: @escaping () -> Void = {}) {
        self.currentState = currentState
        self.onNavigateHome = onNavigateHome
    }
    
    var body: some View {
        ZStack {
            // Pure black background
            Color.black.ignoresSafeArea(.all)
            
            // Fullscreen real tool interface
            fullscreenToolInterface
            
            // Minimal overlay (only shows when needed)
            if showOverlay {
                workshopOverlay
                    .transition(.opacity)
            }
            
            // Navigation overlay
            TOMENavigationOverlay(
                onNavigateHome: onNavigateHome,
                environmentName: "Workshop",
                environmentColor: .purple,
                tomeState: currentState
            )
        }
        .onKeyPress(.space) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showOverlay.toggle()
            }
            return .handled
        }
        .onAppear {
            scanForCreativeApps()
        }
    }
    
    private var workshopBackground: some View {
        LinearGradient(
            colors: [
                Color.purple.opacity(0.05),
                Color.black,
                Color.blue.opacity(0.03)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea(.all)
    }
    
    private var fullscreenToolInterface: some View {
        Group {
            if let selectedApp = selectedApp {
                if selectedApp.bundleId == "com.tome.browser" {
                    // Show embedded TOME Browser
                    TOMEBrowserView()
                } else {
                    // Show app embed view for other apps
                    SimpleAppEmbedView(appName: selectedApp.name, bundleId: selectedApp.bundleId)
                }
            } else if !availableApps.isEmpty {
                // Show app selection interface
                appSelectionInterface
            } else {
                // Show scanning or no apps found
                placeholderInterface
            }
        }
        .ignoresSafeArea(.all)
    }
    
    private func scanForCreativeApps() {
        let creativeApps = [
            // Development
            DetectedApp(name: "Visual Studio Code", bundleId: "com.microsoft.VSCode", category: .development, icon: "curlybraces.square"),
            DetectedApp(name: "Xcode", bundleId: "com.apple.dt.Xcode", category: .development, icon: "hammer"),
            DetectedApp(name: "Sublime Text", bundleId: "com.sublimetext.4", category: .development, icon: "doc.text"),
            DetectedApp(name: "Atom", bundleId: "com.github.atom", category: .development, icon: "atom"),
            DetectedApp(name: "TextMate", bundleId: "com.macromates.TextMate", category: .development, icon: "doc.plaintext"),
            DetectedApp(name: "Nova", bundleId: "com.panic.Nova", category: .development, icon: "curlybraces"),
            DetectedApp(name: "Terminal", bundleId: "com.apple.Terminal", category: .development, icon: "terminal"),
            DetectedApp(name: "iTerm2", bundleId: "com.googlecode.iterm2", category: .development, icon: "terminal.fill"),
            DetectedApp(name: "Docker Desktop", bundleId: "com.docker.docker", category: .development, icon: "shippingbox"),
            DetectedApp(name: "Postman", bundleId: "com.postmanlabs.mac", category: .development, icon: "network"),
            DetectedApp(name: "GitHub Desktop", bundleId: "com.github.GitHubDesktop", category: .development, icon: "externaldrive.connected.to.line.below"),
            
            // Design
            DetectedApp(name: "Figma", bundleId: "com.figma.Desktop", category: .design, icon: "paintbrush.pointed"),
            DetectedApp(name: "Sketch", bundleId: "com.bohemiancoding.sketch3", category: .design, icon: "scribble.variable"),
            DetectedApp(name: "Adobe Photoshop", bundleId: "com.adobe.Photoshop", category: .design, icon: "photo"),
            DetectedApp(name: "Adobe Illustrator", bundleId: "com.adobe.Illustrator", category: .design, icon: "paintpalette"),
            DetectedApp(name: "Adobe InDesign", bundleId: "com.adobe.InDesign", category: .design, icon: "doc.richtext"),
            DetectedApp(name: "Canva", bundleId: "com.canva.CanvaDesktop", category: .design, icon: "rectangle.on.rectangle.angled"),
            DetectedApp(name: "Affinity Designer", bundleId: "com.seriflabs.affinitydesigner2", category: .design, icon: "pencil.and.outline"),
            
            // Presentation
            DetectedApp(name: "Microsoft PowerPoint", bundleId: "com.microsoft.Powerpoint", category: .presentation, icon: "play.rectangle"),
            DetectedApp(name: "Keynote", bundleId: "com.apple.iWork.Keynote", category: .presentation, icon: "play.rectangle.fill"),
            DetectedApp(name: "Google Slides", bundleId: "com.google.Chrome", category: .presentation, icon: "slider.horizontal.3"),
            DetectedApp(name: "Prezi", bundleId: "com.prezi.desktop", category: .presentation, icon: "rectangle.stack"),
            
            // Music & Audio
            DetectedApp(name: "Logic Pro", bundleId: "com.apple.logic10", category: .music, icon: "music.note"),
            DetectedApp(name: "GarageBand", bundleId: "com.apple.GarageBand10", category: .music, icon: "guitars"),
            DetectedApp(name: "Pro Tools", bundleId: "com.avid.ProTools", category: .music, icon: "waveform"),
            DetectedApp(name: "Ableton Live", bundleId: "com.ableton.live", category: .music, icon: "slider.horizontal.below.rectangle"),
            DetectedApp(name: "FL Studio", bundleId: "com.image-line.flstudio", category: .music, icon: "music.quarternote.3"),
            DetectedApp(name: "Audacity", bundleId: "org.audacityteam.audacity", category: .music, icon: "waveform.path"),
            DetectedApp(name: "Spotify", bundleId: "com.spotify.client", category: .music, icon: "music.note.list"),
            
            // Writing & Content
            DetectedApp(name: "Microsoft Word", bundleId: "com.microsoft.Word", category: .writing, icon: "doc.text"),
            DetectedApp(name: "Pages", bundleId: "com.apple.iWork.Pages", category: .writing, icon: "doc.richtext"),
            DetectedApp(name: "Notion", bundleId: "notion.id", category: .writing, icon: "note.text"),
            DetectedApp(name: "Bear", bundleId: "net.shinyfrog.bear", category: .writing, icon: "text.alignleft"),
            DetectedApp(name: "Ulysses", bundleId: "com.ulyssesapp.mac", category: .writing, icon: "text.book.closed"),
            DetectedApp(name: "Obsidian", bundleId: "md.obsidian", category: .writing, icon: "link"),
            DetectedApp(name: "Scrivener", bundleId: "com.literatureandlatte.scrivener3", category: .writing, icon: "books.vertical"),
            
            // Video & Media
            DetectedApp(name: "Final Cut Pro", bundleId: "com.apple.FinalCut", category: .video, icon: "film"),
            DetectedApp(name: "Adobe Premiere Pro", bundleId: "com.adobe.PremierePro", category: .video, icon: "play.rectangle.on.rectangle"),
            DetectedApp(name: "DaVinci Resolve", bundleId: "com.blackmagic-design.DaVinciResolve", category: .video, icon: "video"),
            DetectedApp(name: "Adobe After Effects", bundleId: "com.adobe.AfterEffects", category: .video, icon: "video"),
            DetectedApp(name: "Blender", bundleId: "org.blenderfoundation.blender", category: .video, icon: "cube"),
            DetectedApp(name: "iMovie", bundleId: "com.apple.iMovieApp", category: .video, icon: "video.fill"),
            
            // Built-in Browser
            DetectedApp(name: "TOME Browser", bundleId: "com.tome.browser", category: .browser, icon: "safari"),
        ]
        
        // Check which apps are actually installed using NSWorkspace
        let workspace = NSWorkspace.shared
        let installedApps = creativeApps.filter { app in
            // Always include TOME Browser (built-in)
            if app.bundleId == "com.tome.browser" {
                return true
            }
            return workspace.urlForApplication(withBundleIdentifier: app.bundleId) != nil
        }
        
        DispatchQueue.main.async {
            self.availableApps = installedApps
            // Don't auto-select - let user choose from the selection interface
            // selectedApp remains nil so appSelectionInterface is shown
        }
    }
    
    
    private func selectApp(_ app: DetectedApp) {
        selectedApp = app
        
        // Handle TOME Browser differently (don't launch externally)
        if app.bundleId == "com.tome.browser" {
            // TOME Browser is handled internally - no external launch needed
            return
        }
        
        // Launch app and arrange workspace intelligently
        launchAndArrangeApp(app)
    }
    
    private func launchAndArrangeApp(_ app: DetectedApp) {
        // Get all apps in the same category for intelligent workspace arrangement
        let categoryApps = availableApps.filter { $0.category == app.category }
        
        // Launch the selected app first
        let workspace = NSWorkspace.shared
        if let appURL = workspace.urlForApplication(withBundleIdentifier: app.bundleId) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true // Explicitly bring to front for workshop apps
            workspace.openApplication(at: appURL, configuration: config) { launchedApp, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Failed to launch \(app.name): \(error)")
                    } else if launchedApp != nil {
                        print("✅ Successfully launched: \(app.name)")
                        
                        // Arrange workspace after short delay to allow app to initialize
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.arrangeIntelligentWorkspace(for: app, with: categoryApps)
                        }
                    }
                }
            }
        }
    }
    
    private func arrangeIntelligentWorkspace(for primaryApp: DetectedApp, with categoryApps: [DetectedApp]) {
        // Determine which additional apps should be launched for optimal workflow
        let appsToLaunch = selectComplementaryApps(for: primaryApp.category, primaryApp: primaryApp, availableApps: categoryApps)
        
        // Launch complementary apps
        for app in appsToLaunch {
            if app.bundleId != primaryApp.bundleId { // Don't launch the primary app again
                launchAppInBackground(app)
            }
        }
        
        // Arrange the workspace layout
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.windowManager.arrangeWorkspace(
                for: primaryApp.category,
                apps: [primaryApp] + appsToLaunch,
                screenFrame: NSScreen.main?.frame
            )
            
            // Update current task based on category
            self.updateCurrentTaskForCategory(primaryApp.category)
        }
    }
    
    private func selectComplementaryApps(for category: AppCategory, primaryApp: DetectedApp, availableApps: [DetectedApp]) -> [DetectedApp] {
        switch category {
        case .development:
            // For development, add Terminal and version control if available
            var complementary: [DetectedApp] = []
            if let terminal = availableApps.first(where: { ["Terminal", "iTerm2"].contains($0.name) && $0.bundleId != primaryApp.bundleId }) {
                complementary.append(terminal)
            }
            if let git = availableApps.first(where: { $0.name == "GitHub Desktop" && $0.bundleId != primaryApp.bundleId }) {
                complementary.append(git)
            }
            return complementary
            
        case .design:
            // For design, keep it simple - design apps work best alone
            return []
            
        case .presentation:
            // Presentation apps work best alone
            return []
            
        case .music:
            // For music, might want reference music app
            var complementary: [DetectedApp] = []
            if let musicPlayer = availableApps.first(where: { ["Spotify", "Music"].contains($0.name) && $0.bundleId != primaryApp.bundleId }) {
                complementary.append(musicPlayer)
            }
            return complementary
            
        case .writing:
            // For writing, add research/notes app if available
            var complementary: [DetectedApp] = []
            if let noteApp = availableApps.first(where: { ["Notion", "Obsidian"].contains($0.name) && $0.bundleId != primaryApp.bundleId }) {
                complementary.append(noteApp)
            }
            return complementary
            
        case .video:
            // Video editing apps work best alone due to resource intensity
            return []
            
        case .browser:
            // Browser is handled internally
            return []
        }
    }
    
    private func launchAppInBackground(_ app: DetectedApp) {
        let workspace = NSWorkspace.shared
        if let appURL = workspace.urlForApplication(withBundleIdentifier: app.bundleId) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = false // Launch in background
            workspace.openApplication(at: appURL, configuration: config) { launchedApp, error in
                if let error = error {
                    print("❌ Failed to launch background app \(app.name): \(error)")
                } else {
                    print("✅ Successfully launched background app: \(app.name)")
                }
            }
        }
    }
    
    private func updateCurrentTaskForCategory(_ category: AppCategory) {
        switch category {
        case .development:
            currentTask = "Development Session"
        case .design:
            currentTask = "Design Session"
        case .presentation:
            currentTask = "Presentation Creation"
        case .music:
            currentTask = "Music Production"
        case .writing:
            currentTask = "Writing Session"
        case .video:
            currentTask = "Video Production"
        case .browser:
            currentTask = "Research Session"
        }
    }
    
    private func startSessionTimer() {
        guard !isTimerRunning else { return }
        isTimerRunning = true
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if isTimerRunning {
                sessionTimer += 1
            } else {
                timer.invalidate()
            }
        }
    }
    
    private func stopSessionTimer() {
        isTimerRunning = false
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
    
    private func addIdea(_ idea: String) {
        guard !idea.isEmpty else { return }
        capturedIdeas.append(idea)
    }
    
    private func captureIdea() {
        // Create a quick idea capture - this would typically show a text input
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
        addIdea("💡 Idea captured at \(timestamp)")
        
        // Add to todos for follow-up
        currentState.addTodo("Follow up on idea from Workshop session")
    }
    
    private func captureBug() {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
        addIdea("🐛 Bug noted at \(timestamp)")
        
        // Add to todos for bug fixing
        currentState.addTodo("Investigate and fix bug noted during Workshop")
    }
    
    private func captureNote() {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
        addIdea("📝 Note taken at \(timestamp)")
    }
    
    private func toggleTimer() {
        if isTimerRunning {
            stopSessionTimer()
        } else {
            startSessionTimer()
        }
    }
    
    private var overlayToggleButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showOverlay.toggle()
            }
        }) {
            Image(systemName: showOverlay ? "xmark" : "info.circle")
                .font(.tomeBodyMedium())
                .foregroundColor(.white.opacity(0.8))
                .padding(12)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.3))
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
    }
    
    private var workshopOverlay: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
                .ignoresSafeArea(.all)
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showOverlay = false
                    }
                }
            
            // Overlay content
            VStack(spacing: 24) {
                // Current task progress
                progressSection
                
                // Tool switcher
                toolSwitcher
                
                // Quick actions
                quickActions
                
                // Environment switch
                environmentSwitch
                
                // Break reminder
                breakReminder
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.9))
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    .background(.ultraThinMaterial)
            )
            .frame(maxWidth: 400)
        }
    }
    
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Session Progress")
                    .font(.tomeBodyMedium())
                    .foregroundColor(.white)
                
                Spacer()
                
                HStack(spacing: 8) {
                    // Window management indicator
                    if windowManager.isManagingWindows {
                        HStack(spacing: 4) {
                            Image(systemName: "rectangle.3.group")
                                .font(.tomeSmallLabelMedium())
                                .foregroundColor(.blue)
                            
                            Text("Managed")
                                .font(.tomeTinyMedium())
                                .foregroundColor(.blue.opacity(0.8))
                        }
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: isTimerRunning ? "play.fill" : "pause.fill")
                            .font(.tomeSmallLabelMedium())
                            .foregroundColor(isTimerRunning ? .green : .orange)
                        
                        Text(formatTime(sessionTimer))
                            .font(.tomeSmallMedium())
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(currentTask)
                        .font(.tomeSmall())
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                    
                    Text("\(Int(progressValue * 100))%")
                        .font(.tomeCaptionMedium())
                        .foregroundColor(.white.opacity(0.6))
                }
                
                ProgressView(value: progressValue)
                    .progressViewStyle(LinearProgressViewStyle(tint: selectedApp?.category.color ?? .purple))
                    .scaleEffect(y: 2)
                
                HStack(spacing: 16) {
                    Button("25%") { 
                        withAnimation(.easeInOut(duration: 0.3)) {
                            progressValue = 0.25
                        }
                    }
                    Button("50%") { 
                        withAnimation(.easeInOut(duration: 0.3)) {
                            progressValue = 0.5
                        }
                    }
                    Button("75%") { 
                        withAnimation(.easeInOut(duration: 0.3)) {
                            progressValue = 0.75
                        }
                    }
                    Button("Done") { 
                        withAnimation(.easeInOut(duration: 0.3)) {
                            progressValue = 1.0
                            // Mark current task as completed
                            currentState.addTodo("✅ Completed: \(currentTask)")
                        }
                    }
                }
                .font(.tomeSmallLabelMedium())
                .foregroundColor(.white.opacity(0.6))
                .buttonStyle(PlainButtonStyle())
                
                // Show captured items count
                if !capturedIdeas.isEmpty {
                    HStack {
                        Image(systemName: "lightbulb")
                            .font(.tomeSmallLabelMedium())
                            .foregroundColor(.yellow.opacity(0.7))
                        
                        Text("\(capturedIdeas.count) items captured")
                            .font(.tomeSmallLabel())
                            .foregroundColor(.white.opacity(0.5))
                        
                        Spacer()
                    }
                }
            }
        }
    }
    
    private var toolSwitcher: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available Apps")
                .font(.tomeBodyMedium())
                .foregroundColor(.white)
            
            if availableApps.isEmpty {
                Text("No development apps found")
                    .font(.tomeCaption())
                    .foregroundColor(.white.opacity(0.5))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(availableApps.prefix(6)) { app in
                            appSwitchButton(app)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }
    
    private func appSwitchButton(_ app: DetectedApp) -> some View {
        Button(action: { selectApp(app) }) {
            VStack(spacing: 4) {
                Image(systemName: app.icon)
                    .font(.tomeSmallMedium())
                    .foregroundColor(selectedApp?.bundleId == app.bundleId ? app.category.color : .white.opacity(0.6))
                
                Text(app.shortName)
                    .font(.tomeTinyMedium())
                    .foregroundColor(selectedApp?.bundleId == app.bundleId ? .white : .white.opacity(0.6))
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selectedApp?.bundleId == app.bundleId ? app.category.color.opacity(0.2) : Color.white.opacity(0.05))
                    .stroke(selectedApp?.bundleId == app.bundleId ? app.category.color.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Capture")
                .font(.tomeBodyMedium())
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                actionButton("💡", "Idea") { captureIdea() }
                actionButton("🐛", "Bug") { captureBug() }
                actionButton("📝", "Note") { captureNote() }
                actionButton("⏰", "Timer") { toggleTimer() }
            }
        }
    }
    
    private func actionButton(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(icon)
                    .font(.tomeBody())
                
                Text(label)
                    .font(.tomeSmallLabelMedium())
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.05))
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    private var environmentSwitch: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Switch Environment")
                .font(.tomeSmallMedium())
                .foregroundColor(.white.opacity(0.8))
            
            HStack(spacing: 8) {
                environmentButton(.planning, "Planning")
                environmentButton(.writerDesk, "Writer")
                environmentButton(.coffeeshop, "Research")
            }
        }
    }
    
    private func environmentButton(_ env: TOMEEnvironment, _ label: String) -> some View {
        Button(action: { /* Switch environment */ }) {
            Text(label)
                .font(.tomeCaptionMedium())
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(env.primaryColor.opacity(0.1))
                        .stroke(env.primaryColor.opacity(0.3), lineWidth: 1)
                )
        }
    }
    
    private var breakReminder: some View {
        HStack {
            Image(systemName: "clock")
                .font(.tomeCaptionMedium())
                .foregroundColor(.orange)
            
            Text("Break reminder in 15 minutes")
                .font(.tomeCaption())
                .foregroundColor(.white.opacity(0.6))
            
            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.orange.opacity(0.1))
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - App Selection Interface
    
    private var appSelectionInterface: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                Image(systemName: "hammer.fill")
                    .font(.tomeTitle())
                    .foregroundColor(.purple)
                
                Text("Workshop")
                    .font(.tomeTitle())
                    .foregroundColor(.white)
                
                Text("Choose your creative tool")
                    .font(.tomeBody())
                    .foregroundColor(.white.opacity(0.7))
            }
            
            ScrollView {
                LazyVStack(spacing: 32) {
                    // Featured TOME Browser at top with distinct styling
                    featuredBrowserSection
                    
                    // Subtle divider
                    if !creativeCategories.filter({ $0 != AppCategory.browser }).isEmpty {
                        Rectangle()
                            .fill(.white.opacity(0.05))
                            .frame(height: 1)
                            .padding(.horizontal, 24)
                    }
                    
                    // Regular app categories below with better spacing
                    ForEach(creativeCategories.filter { $0 != AppCategory.browser }, id: \.self) { category in
                        categorySection(for: category)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.1), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
    
    private var featuredBrowserSection: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: "globe.americas.fill")
                        .font(.tomeHeading())
                        .foregroundColor(.indigo)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TOME Browser")
                            .font(.tomeHeading())
                            .foregroundColor(.white)
                        
                        Text("Built-in AI-powered research browser")
                            .font(.tomeCaption())
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.tomeCaptionMedium())
                    .foregroundColor(.white.opacity(0.4))
            }
            
            if let tomeBrowser = availableApps.first(where: { $0.bundleId == "com.tome.browser" }) {
                Button(action: { selectApp(tomeBrowser) }) {
                    HStack {
                        HStack(spacing: 16) {
                            Image(systemName: "safari")
                                .font(.tomeTitle())
                                .foregroundColor(.indigo)
                                .frame(width: 48, height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.indigo.opacity(0.1))
                                        .stroke(.indigo.opacity(0.3), lineWidth: 1)
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Launch TOME Browser")
                                    .font(.tomeBodyMedium())
                                    .foregroundColor(.white)
                                
                                Text("AI sidebar • Focus tracking • Smart recommendations")
                                    .font(.tomeLabel())
                                    .foregroundColor(.white.opacity(0.6))
                                
                                HStack(spacing: 8) {
                                    featureBadge("🧠", "AI Assistant")
                                    featureBadge("📊", "Focus Analytics")
                                    featureBadge("🔍", "Smart Search")
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.tomeSubheading())
                                .foregroundColor(.indigo)
                        }
                        .padding(20)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [.indigo.opacity(0.1), .blue.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .stroke(
                                LinearGradient(
                                    colors: [.indigo.opacity(0.4), .blue.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .scaleEffect(selectedApp?.bundleId == tomeBrowser.bundleId ? 1.02 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedApp?.bundleId)
            }
        }
        .padding(.horizontal, 4)
    }
    
    private func featureBadge(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 4) {
            Text(icon)
                .font(.tomeTiny())
            
            Text(text)
                .font(.tomeTinyMedium())
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(.white.opacity(0.05))
                .stroke(.white.opacity(0.1), lineWidth: 0.5)
        )
    }
    
    private var creativeCategories: [AppCategory] {
        let categoriesWithApps = Set(availableApps.map { $0.category })
        return [.development, .design, .presentation, .music, .writing, .video, .browser].filter { categoriesWithApps.contains($0) }
    }
    
    private func categorySection(for category: AppCategory) -> some View {
        let categoryApps = availableApps.filter { $0.category == category }
        
        guard !categoryApps.isEmpty else {
            return AnyView(EmptyView())
        }
        
        return AnyView(
            VStack(alignment: .leading, spacing: 20) {
                // Minimalist category header
                HStack(spacing: 12) {
                    Image(systemName: category.icon)
                        .font(.tomeBodyMedium())
                        .foregroundColor(category.color)
                        .frame(width: 20)
                    
                    Text(category.displayName)
                        .font(.tomeBodyMedium())
                        .foregroundColor(.white.opacity(0.9))
                    
                    Spacer()
                    
                    Text("\(categoryApps.count)")
                        .font(.tomeLabel())
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(.white.opacity(0.05))
                        )
                }
                .padding(.bottom, 4)
                
                // Ultra-minimalist app list
                VStack(spacing: 8) {
                    ForEach(categoryApps) { app in
                        ultraMinimalistAppButton(app)
                    }
                }
            }
            .padding(.vertical, 8)
        )
    }
    
    private func minimalistAppButton(_ app: DetectedApp) -> some View {
        Button(action: { selectApp(app) }) {
            VStack(spacing: 10) {
                // Clean app icon
                Image(systemName: app.icon)
                    .font(.tomeSubheading())
                    .foregroundColor(selectedApp?.bundleId == app.bundleId ? .white : app.category.color)
                    .frame(width: 32, height: 32)
                
                // Clean app name
                Text(app.name)
                    .font(.tomeTinyMedium())
                    .foregroundColor(selectedApp?.bundleId == app.bundleId ? .white : .white.opacity(0.8))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 72, height: 72)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selectedApp?.bundleId == app.bundleId ? app.category.color.opacity(0.15) : Color.white.opacity(0.02))
                    .stroke(
                        selectedApp?.bundleId == app.bundleId ? app.category.color.opacity(0.4) : Color.white.opacity(0.08),
                        lineWidth: selectedApp?.bundleId == app.bundleId ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(selectedApp?.bundleId == app.bundleId ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedApp?.bundleId)
    }
    
    private func ultraMinimalistAppButton(_ app: DetectedApp) -> some View {
        Button(action: { selectApp(app) }) {
            HStack(spacing: 12) {
                // Simple icon
                Image(systemName: app.icon)
                    .font(.tomeSmallMedium())
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 16)
                
                // App name
                Text(app.name)
                    .font(.tomeBody())
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                // Subtle chevron
                Image(systemName: "chevron.right")
                    .font(.tomeSmallLabelMedium())
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(.white.opacity(0.02))
                    .stroke(.white.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func appSelectionButton(_ app: DetectedApp) -> some View {
        Button(action: { selectApp(app) }) {
            VStack(spacing: 8) {
                Image(systemName: app.icon)
                    .font(.tomeHeading())
                    .foregroundColor(app.category.color)
                    .frame(height: 32)
                
                Text(app.name)
                    .font(.tomeSmallLabelMedium())
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 80, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .stroke(app.category.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(selectedApp?.bundleId == app.bundleId ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedApp?.bundleId)
    }
    
    private var placeholderInterface: some View {
        VStack(spacing: 24) {
            Image(systemName: "magnifyingglass")
                .font(.tomeTitle())
                .foregroundColor(.white.opacity(0.5))
            
            Text("Scanning for creative apps...")
                .font(.tomeSubheading())
                .foregroundColor(.white.opacity(0.7))
            
            Text("Install VS Code, Logic Pro, Figma, Final Cut Pro, or other creative apps to get started")
                .font(.tomeSmall())
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 64)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
    
}

struct DetectedApp: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let bundleId: String
    let category: AppCategory
    let icon: String
    
    var shortName: String {
        // Create short names from app names
        let words = name.components(separatedBy: " ")
        if words.count > 1 {
            return words.prefix(2).map { String($0.prefix(4)) }.joined(separator: " ")
        } else {
            return String(name.prefix(8))
        }
    }
    
    static func == (lhs: DetectedApp, rhs: DetectedApp) -> Bool {
        lhs.bundleId == rhs.bundleId
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleId)
    }
}

enum AppCategory: Codable {
    case development
    case design  
    case presentation
    case music
    case writing
    case video
    case browser
    
    var displayName: String {
        switch self {
        case .development: return "Development"
        case .design: return "Design"
        case .presentation: return "Presentation"
        case .music: return "Music & Audio"
        case .writing: return "Writing & Content"
        case .video: return "Video & Media"
        case .browser: return "Browser"
        }
    }
    
    var color: Color {
        switch self {
        case .development: return .blue
        case .design: return .purple
        case .presentation: return .green
        case .music: return .pink
        case .writing: return .orange
        case .video: return .red
        case .browser: return .indigo
        }
    }
    
    var icon: String {
        switch self {
        case .development: return "curlybraces"
        case .design: return "paintbrush.pointed"
        case .presentation: return "play.rectangle"
        case .music: return "music.note"
        case .writing: return "doc.text"
        case .video: return "film"
        case .browser: return "safari"
        }
    }
}

