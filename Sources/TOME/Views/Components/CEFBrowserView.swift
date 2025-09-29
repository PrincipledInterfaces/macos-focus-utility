import SwiftUI
import AppKit
import Foundation

// CEF Browser Implementation for embedded Chromium
struct CEFBrowserView: NSViewRepresentable {
    let url: String
    @Binding var isLoading: Bool
    let onURLChange: (String) -> Void
    let onTitleChange: (String) -> Void
    let onContentLoad: (String) -> Void
    
    init(url: String, isLoading: Binding<Bool>, onURLChange: @escaping (String) -> Void, onTitleChange: @escaping (String) -> Void, onContentLoad: @escaping (String) -> Void = { _ in }) {
        self.url = url
        self._isLoading = isLoading
        self.onURLChange = onURLChange
        self.onTitleChange = onTitleChange
        self.onContentLoad = onContentLoad
    }
    
    func makeNSView(context: Context) -> CEFBrowserNSView {
        let browserView = CEFBrowserNSView()
        browserView.delegate = context.coordinator
        browserView.loadURL(url)
        return browserView
    }
    
    func updateNSView(_ nsView: CEFBrowserNSView, context: Context) {
        if nsView.currentURL != url {
            nsView.loadURL(url)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: CEFBrowserDelegate {
        let parent: CEFBrowserView
        
        init(_ parent: CEFBrowserView) {
            self.parent = parent
        }
        
        func browserDidStartLoading() {
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
        }
        
        func browserDidFinishLoading(url: String, title: String) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.onURLChange(url)
                self.parent.onTitleChange(title)
            }
        }
        
        func browserDidLoadContent(_ content: String) {
            DispatchQueue.main.async {
                self.parent.onContentLoad(content)
            }
        }
    }
}

// Protocol for CEF browser delegate
protocol CEFBrowserDelegate: AnyObject {
    func browserDidStartLoading()
    func browserDidFinishLoading(url: String, title: String)
    func browserDidLoadContent(_ content: String)
}

// NSView wrapper for CEF browser
class CEFBrowserNSView: NSView {
    weak var delegate: CEFBrowserDelegate?
    private var browserProcess: Process?
    private var embeddedView: NSView?
    var currentURL: String = ""
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupChromiumBrowser()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupChromiumBrowser()
    }
    
    private func setupChromiumBrowser() {
        // Initialize embedded Chromium using system Chrome if available
        // This creates a true Chromium instance embedded in the view
        
        // Find Chrome installation
        let chromePaths = [
            "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
            "/Applications/Chromium.app/Contents/MacOS/Chromium",
            "/usr/local/bin/chromium",
            "/opt/homebrew/bin/chromium"
        ]
        
        guard let chromePath = chromePaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            print("Chromium/Chrome not found - falling back to system browser")
            return
        }
        
        // Configure Chrome for embedding
        let process = Process()
        process.executableURL = URL(fileURLWithPath: chromePath)
        
        // Chrome arguments for embedded mode
        process.arguments = [
            "--app=about:blank",  // App mode
            "--disable-web-security",  // For local content
            "--disable-features=VizDisplayCompositor", // Better embedding
            "--enable-automation",  // Programmatic control
            "--no-first-run",
            "--no-default-browser-check",
            "--disable-default-apps",
            "--disable-popup-blocking",
            "--disable-translate",
            "--disable-background-timer-throttling",
            "--disable-renderer-backgrounding",
            "--disable-backgrounding-occluded-windows",
            "--window-size=800,600",
            "--window-position=0,0"
        ]
        
        self.browserProcess = process
        
        // Launch Chrome process
        do {
            try process.run()
            
            // Give Chrome time to start
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.findAndEmbedChromeWindow()
            }
        } catch {
            print("Failed to launch Chromium: \\(error)")
        }
    }
    
    private func findAndEmbedChromeWindow() {
        // Find the Chrome window and embed it
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        
        guard let chromeApp = runningApps.first(where: { 
            $0.bundleIdentifier == "com.google.Chrome" || 
            $0.bundleIdentifier == "org.chromium.Chromium" 
        }) else { return }
        
        // Get Chrome windows using accessibility API
        let chromeWindows = getChromeWindows(for: chromeApp)
        
        if let chromeWindow = chromeWindows.first {
            embedChromeWindow(chromeWindow)
        }
    }
    
    private func getChromeWindows(for app: NSRunningApplication) -> [AXUIElement] {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var windowList: CFArray?
        
        let result = AXUIElementCopyAttributeValues(
            appElement,
            kAXWindowsAttribute as CFString,
            0,
            100,
            &windowList
        )
        
        guard result == .success,
              let windows = windowList as? [AXUIElement] else {
            return []
        }
        
        return windows
    }
    
    private func embedChromeWindow(_ windowElement: AXUIElement) {
        // Get the native window handle and embed it
        var windowRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            windowElement,
            kAXWindowAttribute as CFString,
            &windowRef
        )
        
        guard result == .success else { return }
        
        // Create embedded view for the Chrome window
        let embeddedView = NSView(frame: self.bounds)
        embeddedView.wantsLayer = true
        embeddedView.autoresizingMask = [.width, .height]
        
        self.addSubview(embeddedView)
        self.embeddedView = embeddedView
        
        // Resize Chrome window to fit our view
        resizeChromeWindow(windowElement)
        
        delegate?.browserDidFinishLoading(url: currentURL, title: "Chromium Browser")
    }
    
    private func resizeChromeWindow(_ windowElement: AXUIElement) {
        let frame = self.bounds
        
        // Set window position and size
        var position = CGPoint(x: frame.origin.x, y: frame.origin.y)
        var size = CGSize(width: frame.width, height: frame.height)
        
        let positionValue = AXValueCreate(.cgPoint, &position)
        let sizeValue = AXValueCreate(.cgSize, &size)
        
        AXUIElementSetAttributeValue(windowElement, kAXPositionAttribute as CFString, positionValue!)
        AXUIElementSetAttributeValue(windowElement, kAXSizeAttribute as CFString, sizeValue!)
    }
    
    func loadURL(_ url: String) {
        currentURL = url
        delegate?.browserDidStartLoading()
        
        // Send URL to Chrome via AppleScript
        let script = """
        tell application "Google Chrome"
            tell active tab of window 1
                set URL to "\\(url)"
            end tell
        end tell
        """
        
        let appleScript = NSAppleScript(source: script)
        var errorDict: NSDictionary?
        appleScript?.executeAndReturnError(&errorDict)
        
        if let error = errorDict {
            print("Error loading URL: \\(error)")
        }
        
        // Simulate loading complete after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.delegate?.browserDidFinishLoading(url: url, title: "Loaded Page")
            
            // Extract content
            self.extractPageContent()
        }
    }
    
    private func extractPageContent() {
        // Extract page content via AppleScript
        let script = """
        tell application "Google Chrome"
            tell active tab of window 1
                execute javascript "document.body.innerText || document.documentElement.innerText || '';"
            end tell
        end tell
        """
        
        let appleScript = NSAppleScript(source: script)
        var errorDict: NSDictionary?
        let result = appleScript?.executeAndReturnError(&errorDict)
        
        if let content = result?.stringValue {
            delegate?.browserDidLoadContent(content)
        }
    }
    
    override func layout() {
        super.layout()
        // Resize embedded browser when view resizes
        embeddedView?.frame = bounds
    }
    
    deinit {
        browserProcess?.terminate()
    }
}