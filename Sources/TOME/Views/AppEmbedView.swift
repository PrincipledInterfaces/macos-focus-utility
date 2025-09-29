import SwiftUI
import AppKit

struct AppEmbedView: NSViewRepresentable {
    let appName: String
    let bundleId: String
    
    func makeNSView(context: Context) -> NSView {
        let containerView = AppEmbedContainerView(appName: appName, bundleId: bundleId)
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.black.cgColor
        
        // Launch and embed the app
        containerView.embedApplication()
        
        return containerView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Update if needed
    }
}

class AppEmbedContainerView: NSView {
    let appName: String
    let bundleId: String
    private var embeddedWindow: NSWindow?
    
    init(appName: String, bundleId: String) {
        self.appName = appName
        self.bundleId = bundleId
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func embedApplication() {
        // Don't auto-launch apps - instead first try to capture if already running
        // Capture immediately for responsiveness
        captureAndEmbedApp()
    }
    
    private func captureAndEmbedApp() {
        DispatchQueue.main.async {
            // Try to capture running app first
            if let windowImage = self.captureApplicationScreen() {
                print("✅ Captured running app: \(self.appName)")
                self.displayCapturedImage(windowImage)
            } else {
                print("📱 App not running, showing launcher for: \(self.appName)")
                // Show app launcher interface - don't auto-launch
                self.showAppLauncher()
            }
        }
    }
    
    private func captureApplicationScreen() -> NSImage? {
        // Use modern ScreenCaptureKit if available
        if #available(macOS 12.3, *) {
            return captureApplicationScreenModern()
        } else {
            // Fallback to legacy method for older macOS versions
            return captureApplicationScreenLegacy()
        }
    }
    
    @available(macOS 12.3, *)
    private func captureApplicationScreenModern() -> NSImage? {
        // For now, return nil to avoid blocking the UI
        // The actual implementation would be async and integrate with ScreenCaptureService
        // This is a placeholder for future async implementation
        return nil
    }
    
    private func captureApplicationScreenLegacy() -> NSImage? {
        let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as! [[String: Any]]
        
        // Find windows belonging to our app
        for windowInfo in windowList {
            if let windowOwner = windowInfo[kCGWindowOwnerName as String] as? String,
               windowOwner.lowercased().contains(appName.lowercased()),
               let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID {
                
                // Capture this window using deprecated API
                if let windowImage = CGWindowListCreateImage(
                    CGRect.null,
                    .optionIncludingWindow,
                    windowID,
                    []
                ) {
                    return NSImage(cgImage: windowImage, size: NSSize(width: CGFloat(windowImage.width), height: CGFloat(windowImage.height)))
                }
            }
        }
        return nil
    }
    
    private func displayCapturedImage(_ image: NSImage) {
        // Clear any existing subviews
        self.subviews.forEach { $0.removeFromSuperview() }
        
        let imageView = NSImageView(image: image)
        imageView.imageScaling = .scaleAxesIndependently  // Changed to fill the entire allocated space
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 8
        imageView.layer?.masksToBounds = true
        
        self.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: self.topAnchor, constant: 4),
            imageView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 4),
            imageView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -4),
            imageView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -4)
        ])
        
        // Set up periodic refresh with better performance
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
            DispatchQueue.global(qos: .utility).async {
                if let updatedImage = self.captureApplicationScreen() {
                    DispatchQueue.main.async {
                        // Only update if the view still exists
                        guard imageView.superview != nil else {
                            timer.invalidate()
                            return
                        }
                        imageView.image = updatedImage
                    }
                }
            }
        }
    }
    
    private func showAppLauncher() {
        let launcherView = NSView()
        launcherView.wantsLayer = true
        launcherView.layer?.backgroundColor = NSColor.darkGray.withAlphaComponent(0.3).cgColor
        launcherView.layer?.cornerRadius = 8
        
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .centerX
        stackView.spacing = 12
        
        // App icon (system icon as placeholder)
        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: "app.badge", accessibilityDescription: nil)
        iconView.contentTintColor = .white
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 32).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 32).isActive = true
        
        // App name label
        let nameLabel = NSTextField(labelWithString: appName)
        nameLabel.textColor = .white
        nameLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        nameLabel.alignment = .center
        
        // Launch button - only launch when explicitly requested
        let launchButton = NSButton(title: "Launch \(appName)", target: self, action: #selector(launchAndCaptureApp))
        launchButton.bezelStyle = .rounded
        launchButton.controlSize = .small
        
        stackView.addArrangedSubview(iconView)
        stackView.addArrangedSubview(nameLabel)
        stackView.addArrangedSubview(launchButton)
        
        launcherView.addSubview(stackView)
        self.addSubview(launcherView)
        
        // Set up constraints
        launcherView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            launcherView.topAnchor.constraint(equalTo: self.topAnchor, constant: 8),
            launcherView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 8),
            launcherView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -8),
            launcherView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -8),
            
            stackView.centerXAnchor.constraint(equalTo: launcherView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: launcherView.centerYAnchor)
        ])
    }
    
    @objc private func launchAndCaptureApp() {
        let appService = ApplicationService()
        
        print("🚀 User requested launch of \(appName)")
        appService.launchApplication(bundleId: bundleId) { success in
            if success {
                print("✅ App launched successfully: \(self.appName)")
                // Wait briefly for app to initialize then capture
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.captureAndEmbedApp()
                }
            } else {
                print("❌ Failed to launch app: \(self.appName)")
            }
        }
    }
    
    @objc private func launchExternalApp() {
        let appService = ApplicationService()
        _ = appService.showApplication(appName)
    }
    
    private func findApplicationWindow() -> NSWindow? {
        let workspace = NSWorkspace.shared
        
        // Find the running application
        guard let runningApp = workspace.runningApplications.first(where: { 
            $0.bundleIdentifier == bundleId || $0.localizedName == appName 
        }) else {
            print("Could not find running app: \(appName)")
            return nil
        }
        
        // Get all windows for this application
        let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as! [[String: Any]]
        
        for windowInfo in windowList {
            if let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? Int,
               ownerPID == runningApp.processIdentifier,
               let windowNumber = windowInfo[kCGWindowNumber as String] as? Int {
                
                // Convert CGWindowID to NSWindow (this is a simplified approach)
                // In a real implementation, you might need more sophisticated window management
                return NSApp.windows.first { $0.windowNumber == windowNumber }
            }
        }
        
        return nil
    }
    
    private func createAppHostView(for window: NSWindow) -> NSView {
        let hostView = NSView()
        hostView.wantsLayer = true
        hostView.layer?.backgroundColor = NSColor.clear.cgColor
        
        // Create a preview of the app window
        if let windowImage = captureWindowImage(window) {
            let imageView = NSImageView(image: windowImage)
            imageView.imageScaling = .scaleProportionallyUpOrDown
            hostView.addSubview(imageView)
            
            imageView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: hostView.topAnchor),
                imageView.leadingAnchor.constraint(equalTo: hostView.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: hostView.trailingAnchor),
                imageView.bottomAnchor.constraint(equalTo: hostView.bottomAnchor)
            ])
            
            // Set up periodic refresh to update the embedded view (less frequent)
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
                DispatchQueue.global(qos: .utility).async {
                    if let updatedImage = self.captureWindowImage(window) {
                        DispatchQueue.main.async {
                            imageView.image = updatedImage
                        }
                    }
                }
            }
        }
        
        return hostView
    }
    
    private func captureWindowImage(_ window: NSWindow) -> NSImage? {
        guard let view = window.contentView else { return nil }
        
        let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)
        guard let bitmapRep = rep else { return nil }
        
        view.cacheDisplay(in: view.bounds, to: bitmapRep)
        
        let image = NSImage(size: view.bounds.size)
        image.addRepresentation(bitmapRep)
        
        return image
    }
    
    private func showPlaceholder() {
        let placeholderView = NSView()
        placeholderView.wantsLayer = true
        placeholderView.layer?.backgroundColor = NSColor.darkGray.cgColor
        
        let label = NSTextField(labelWithString: "Loading \(appName)...")
        label.textColor = .white
        label.font = NSFont.systemFont(ofSize: 16, weight: .light)
        label.alignment = .center
        
        placeholderView.addSubview(label)
        self.addSubview(placeholderView)
        
        // Set up constraints
        placeholderView.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            placeholderView.topAnchor.constraint(equalTo: self.topAnchor),
            placeholderView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            placeholderView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            placeholderView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            
            label.centerXAnchor.constraint(equalTo: placeholderView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: placeholderView.centerYAnchor)
        ])
    }
}

// Real app embedding implementation
struct SimpleAppEmbedView: View {
    let appName: String
    let bundleId: String
    @State private var isLoading = true
    @State private var appLaunched = false
    @State private var windowCaptured = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
            
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    
                    Text("Launching \(appName)")
                        .font(.tomeBody())
                        .foregroundColor(.white.opacity(0.8))
                }
            } else if appLaunched {
                VStack(spacing: 0) {
                    // App control bar
                    HStack {
                        Image(systemName: "app.badge")
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text(appName)
                            .font(.tomeCaption())
                            .foregroundColor(.white.opacity(0.8))
                        
                        Spacer()
                        
                        Button("Refresh") {
                            refreshEmbeddedView()
                        }
                        .font(.tomeTiny())
                        .foregroundColor(.white.opacity(0.6))
                        .buttonStyle(PlainButtonStyle())
                        
                        Button("Focus") {
                            focusApp()
                        }
                        .font(.tomeTiny())
                        .foregroundColor(.white.opacity(0.6))
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.1))
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    
                    // Embedded app view
                    AppEmbedView(appName: appName, bundleId: bundleId)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(12)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "app.badge")
                        .font(.tomeTitle())
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text(appName)
                        .font(.tomeSubheading())
                        .foregroundColor(.white)
                    
                    Text("App is not running")
                        .font(.tomeCaption())
                        .foregroundColor(.white.opacity(0.6))
                    
                    Button("Launch \(appName)") {
                        actuallyLaunchApp()
                    }
                    .font(.tomeCaptionMedium())
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue.opacity(0.2))
                            .stroke(Color.blue.opacity(0.4), lineWidth: 1)
                    )
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .onAppear {
            launchApp()
        }
    }
    
    private func launchApp() {
        // Don't auto-launch - check if app is already running
        isLoading = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Check if the app is already running
            let workspace = NSWorkspace.shared
            let isRunning = workspace.runningApplications.contains { app in
                app.bundleIdentifier == self.bundleId || 
                app.localizedName?.lowercased().contains(self.appName.lowercased()) == true
            }
            
            self.isLoading = false
            self.appLaunched = isRunning
            
            print("📱 SimpleAppEmbedView ready for \(self.appName) - running: \(isRunning)")
        }
    }
    
    private func actuallyLaunchApp() {
        isLoading = true
        
        let workspace = NSWorkspace.shared
        if let appURL = workspace.urlForApplication(withBundleIdentifier: bundleId) {
            do {
                try workspace.launchApplication(at: appURL, options: [.async], configuration: [:])
                print("✅ Launched \(appName)")
                
                // Wait a moment for app to start, then check if it's running
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    let isNowRunning = workspace.runningApplications.contains { app in
                        app.bundleIdentifier == self.bundleId || 
                        app.localizedName?.lowercased().contains(self.appName.lowercased()) == true
                    }
                    
                    self.isLoading = false
                    self.appLaunched = isNowRunning
                }
            } catch {
                print("❌ Failed to launch \(appName): \(error)")
                isLoading = false
                appLaunched = false
            }
        } else {
            print("❌ Could not find app URL for \(appName)")
            isLoading = false
            appLaunched = false
        }
    }
    
    private func focusApp() {
        let appService = ApplicationService()
        _ = appService.showApplication(appName)
    }
    
    private func refreshEmbeddedView() {
        // Force refresh the embedded view
        windowCaptured.toggle()
    }
}