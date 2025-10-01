import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        // Ensure window comes to front when app becomes active
        if let window = NSApp.windows.first {
            window.orderFrontRegardless()
            window.makeKey()
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set as regular app immediately so it can come to front
        NSApp.setActivationPolicy(.regular)
        
        // Activate immediately
        NSApp.activate(ignoringOtherApps: true)
        
        // Setup window after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.setupFullscreenMode()
            self.enterTOMEMode()
        }
    }
    
    private func setupFullscreenMode() {
        guard let window = NSApp.windows.first else {
            print("Warning: No window found for fullscreen setup")
            return
        }
        
        // Configure window for fullscreen takeover
        // TEMPORARILY USING NORMAL LEVEL TO ALLOW KEYBOARD INPUT
        window.level = .normal  // Was: CGShieldingWindowLevel() + 1 (blocked keyboard)
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle,
            .canJoinAllApplications,
            .auxiliary
        ]
        window.styleMask = [.borderless, .fullSizeContentView]
        window.backgroundColor = .black
        window.isOpaque = true
        window.hasShadow = false
        
        // Prevent window from being hidden or moved
        window.canHide = false
        window.hidesOnDeactivate = false
        window.isMovable = false
        window.isRestorable = false
    }
    
    func enterTOMEMode() {        
        guard let window = NSApp.windows.first else {
            print("Warning: No window found for TOME mode")
            return
        }
        
        print("Entering TOME mode - setting up fullscreen")
        
        // Get ALL screens and use the main one
        let screen = NSScreen.main ?? NSScreen.screens.first!
        print("Screen frame: \(screen.frame)")
        
        // First bring to front BEFORE setting fullscreen
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        
        // Then set up fullscreen
        window.setFrame(screen.frame, display: true, animate: false)
        window.level = .normal // Use normal level to allow keyboard input
        window.styleMask = [.borderless, .fullSizeContentView]
        window.backgroundColor = .black
        window.isOpaque = true
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.isMovable = false
        window.canHide = false
        window.hidesOnDeactivate = false

        // Ensure window can receive keyboard events
        window.acceptsMouseMovedEvents = true
        window.makeFirstResponder(nil) // Clear any existing responder

        // Force window to accept keyboard input
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            window.makeKey()
            NSApp.activate(ignoringOtherApps: true)
        }
        
        // Hide system UI but allow app switching (less aggressive)
        NSApp.presentationOptions = [
            .hideDock, 
            .hideMenuBar
        ]
        
        // Continuous activation to stay in front (less frequent, background queue)
        let timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            DispatchQueue.main.async {
                if NSApp.isActive {
                    window.orderFrontRegardless()
                }
            }
        }
        
        // Stop the timer after 30 seconds (longer initial activation period)
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
            timer.invalidate()
        }
        
        // Final activation
        NSApp.activate(ignoringOtherApps: true)
        window.makeKey()
        window.makeMain()
        window.orderFrontRegardless()
        
        print("TOME mode entered - window frame: \(window.frame)")
        print("Window level: \(window.level.rawValue)")
    }
    
    func exitTOMEMode() {
        // Restore normal macOS UI
        NSApp.presentationOptions = []
        NSApp.setActivationPolicy(.accessory)
    }
}