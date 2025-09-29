import SwiftUI
import AppKit

@main
struct TOMEApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .ignoresSafeArea(.all)
                .onAppear {
                    configureFullScreen()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            // Remove default menu items
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .help) { }
            CommandGroup(replacing: .windowArrangement) { }
            CommandGroup(replacing: .windowSize) { }
            CommandGroup(replacing: .appInfo) { }
        }
    }
    
    private func configureFullScreen() {
        DispatchQueue.main.async {
            guard let window = NSApplication.shared.windows.first else { return }
            
            // Hide title bar and make borderless
            window.styleMask = [.borderless, .fullSizeContentView]
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            
            // Set to full screen size
            if let screen = NSScreen.main {
                window.setFrame(screen.frame, display: true)
            }
            
            // Configure window behavior
            window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.backgroundColor = NSColor.black
            
            // Make key and front
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}