import Foundation
import ScreenCaptureKit
import Combine
import AppKit

@available(macOS 12.3, *)
class ScreenCaptureService: ObservableObject {
    @Published var isCapturing = false
    @Published var captureError: Error?
    @Published var availableDisplays: [SCDisplay] = []
    @Published var availableApplications: [SCRunningApplication] = []
    @Published var hasScreenRecordingPermission = false
    
    private var captureEngine: SCStreamConfiguration?
    private let permissionCacheKey = "ScreenCapturePermissionGranted"
    private var contentFilter: SCContentFilter?
    private var stream: SCStream?
    private var cancellables = Set<AnyCancellable>()
    
    // Creative work monitoring
    @Published var activeCreativeApps: [CreativeAppSession] = []
    @Published var screenActivityLevel: ActivityLevel = .idle
    @Published var focusMetrics: FocusMetrics = FocusMetrics()
    
    private var monitoringTimer: Timer?
    private let creativeAppBundleIds = [
        "com.microsoft.VSCode",
        "com.apple.dt.Xcode", 
        "com.figma.Desktop",
        "com.bohemiancoding.sketch3",
        "com.adobe.Photoshop",
        "com.adobe.Illustrator",
        "com.adobe.PremierePro",
        "com.adobe.AfterEffects",
        "com.apple.FinalCut",
        "com.apple.logic10",
        "com.apple.GarageBand10"
    ]
    
    init() {
        // Check cached permission state first
        checkCachedPermission()
        
        // Only setup screen capture if we already have permission or haven't checked yet
        if hasScreenRecordingPermission {
            setupScreenCapture()
            startCreativeWorkMonitoring()
        }
    }
    
    deinit {
        stream?.stopCapture()
        stopCreativeWorkMonitoring()
    }
    
    // MARK: - Screen Capture Setup
    
    private func setupScreenCapture() {
        Task {
            do {
                // Request permission for screen capture
                let canRecord = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                
                await MainActor.run {
                    self.cachePermissionState(true)
                    self.availableDisplays = canRecord.displays
                    self.availableApplications = canRecord.applications
                    print("✅ ScreenCaptureKit initialized with \(canRecord.displays.count) displays and \(canRecord.applications.count) apps")
                }
                
            } catch {
                await MainActor.run {
                    self.cachePermissionState(false)
                    self.captureError = error
                    print("❌ Failed to setup ScreenCaptureKit: \(error)")
                }
            }
        }
    }
    
    func requestScreenRecordingPermission() async -> Bool {
        do {
            let _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            await MainActor.run {
                self.cachePermissionState(true)
            }
            return true
        } catch {
            print("❌ Screen recording permission denied: \(error)")
            await MainActor.run {
                self.cachePermissionState(false)
                self.captureError = error
            }
            return false
        }
    }
    
    // MARK: - Creative Work Monitoring
    
    func startCreativeWorkMonitoring() {
        print("🎨 Starting creative work monitoring with ScreenCaptureKit")
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task {
                await self?.analyzeCreativeActivity()
            }
        }
    }
    
    func stopCreativeWorkMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    private func analyzeCreativeActivity() async {
        do {
            let shareableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            
            // Analyze running creative applications
            let creativeApps = shareableContent.applications.filter { app in
                creativeAppBundleIds.contains(app.bundleIdentifier)
            }
            
            await MainActor.run {
                updateCreativeAppSessions(creativeApps)
                analyzeScreenActivity(shareableContent)
                updateFocusMetrics()
            }
            
        } catch {
            print("❌ Failed to analyze creative activity: \(error)")
        }
    }
    
    private func updateCreativeAppSessions(_ apps: [SCRunningApplication]) {
        let currentTime = Date()
        
        // Update existing sessions
        for i in activeCreativeApps.indices {
            if apps.first(where: { $0.bundleIdentifier == activeCreativeApps[i].bundleId }) != nil {
                // App is still active, update session
                activeCreativeApps[i].lastActivity = currentTime
                activeCreativeApps[i].totalDuration = currentTime.timeIntervalSince(activeCreativeApps[i].startTime)
                activeCreativeApps[i].isActive = true
            } else {
                // App is no longer active
                activeCreativeApps[i].isActive = false
            }
        }
        
        // Add new sessions for newly detected apps
        for app in apps {
            if !activeCreativeApps.contains(where: { $0.bundleId == app.bundleIdentifier }) {
                let session = CreativeAppSession(
                    appName: app.applicationName,
                    bundleId: app.bundleIdentifier,
                    startTime: currentTime,
                    lastActivity: currentTime,
                    totalDuration: 0,
                    activityLevel: .active,
                    isActive: true
                )
                activeCreativeApps.append(session)
                print("🎨 Started tracking creative app: \(app.applicationName)")
            }
        }
        
        // Remove sessions that have been inactive for more than 5 minutes
        activeCreativeApps.removeAll { session in
            !session.isActive && currentTime.timeIntervalSince(session.lastActivity) > 300
        }
    }
    
    private func analyzeScreenActivity(_ content: SCShareableContent) {
        // Analyze screen activity based on visible windows and applications
        let visibleWindows = content.windows.filter { $0.isOnScreen }
        let activeApps = content.applications.filter { app in
            visibleWindows.contains { $0.owningApplication == app }
        }
        
        // Determine activity level based on number of active creative apps
        let activeCreativeCount = activeApps.filter { app in
            creativeAppBundleIds.contains(app.bundleIdentifier)
        }.count
        
        switch activeCreativeCount {
        case 0:
            screenActivityLevel = .idle
        case 1:
            screenActivityLevel = .focused
        case 2...3:
            screenActivityLevel = .active
        default:
            screenActivityLevel = .busy
        }
    }
    
    private func updateFocusMetrics() {
        let currentTime = Date()
        let sessionDuration = currentTime.timeIntervalSince(focusMetrics.sessionStart)
        
        // Calculate focus score based on creative app usage
        let activeCreativeTime = activeCreativeApps.reduce(0) { total, session in
            total + (session.isActive ? session.totalDuration : 0)
        }
        
        let focusRatio = sessionDuration > 0 ? activeCreativeTime / sessionDuration : 0
        focusMetrics.focusScore = min(100, focusRatio * 100)
        
        // Update activity breakdown
        focusMetrics.creativeTime = activeCreativeTime
        focusMetrics.totalTime = sessionDuration
        focusMetrics.distractionEvents = max(0, activeCreativeApps.count - 2) // More than 2 apps = distraction
        
        // Calculate productivity trend
        updateProductivityTrend()
    }
    
    private func updateProductivityTrend() {
        let currentHour = Calendar.current.component(.hour, from: Date())
        
        // Simple productivity scoring based on time of day and activity
        var productivityScore = focusMetrics.focusScore
        
        // Boost score during typical work hours
        if currentHour >= 9 && currentHour <= 17 {
            productivityScore *= 1.1
        }
        
        // Reduce score for evening/night work
        if currentHour >= 22 || currentHour <= 6 {
            productivityScore *= 0.8
        }
        
        focusMetrics.productivityTrend = min(100, productivityScore)
    }
    
    // MARK: - Window Capture for Specific Apps
    
    func captureWindow(for application: SCRunningApplication) async throws -> NSImage? {
        guard let display = availableDisplays.first else {
            throw ScreenCaptureError.noDisplayAvailable
        }
        
        // Create filter for specific application
        let filter = SCContentFilter(display: display, including: [application], exceptingWindows: [])
        
        // Configure capture settings
        let configuration = SCStreamConfiguration()
        configuration.width = 1920
        configuration.height = 1080
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.showsCursor = false
        configuration.scalesToFit = true
        configuration.colorSpaceName = CGColorSpace.displayP3
        
        // Perform single frame capture
        let cgImage = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
        
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
    
    func captureApplicationScreenshot(bundleId: String) async -> NSImage? {
        guard let app = availableApplications.first(where: { $0.bundleIdentifier == bundleId }) else {
            print("❌ Application with bundle ID \(bundleId) not found")
            return nil
        }
        
        do {
            let screenshot = try await captureWindow(for: app)
            print("✅ Captured screenshot for \(app.applicationName)")
            return screenshot
        } catch {
            print("❌ Failed to capture screenshot for \(app.applicationName): \(error)")
            return nil
        }
    }
    
    // MARK: - Creative Flow Analysis
    
    func getCreativeFlowInsights() -> CreativeFlowInsights {
        let insights = CreativeFlowInsights()
        
        // Analyze flow states based on app switching patterns
        insights.flowStateDetected = analyzeFlowState()
        insights.contextSwitches = countContextSwitches()
        insights.deepWorkPeriods = identifyDeepWorkPeriods()
        insights.distractionPatterns = analyzeDistractionPatterns()
        
        return insights
    }
    
    private func analyzeFlowState() -> Bool {
        // Flow state indicators:
        // - Single creative app active for extended period
        // - Minimal context switching
        // - High activity level
        
        guard let currentSession = activeCreativeApps.first(where: { $0.isActive }) else {
            return false
        }
        
        let sessionDuration = currentSession.totalDuration
        let isLongSession = sessionDuration > 1800 // 30 minutes
        let isFocused = activeCreativeApps.filter({ $0.isActive }).count == 1
        
        return isLongSession && isFocused && screenActivityLevel == .focused
    }
    
    private func countContextSwitches() -> Int {
        // Count app switches in the last hour
        let oneHourAgo = Date().addingTimeInterval(-3600)
        
        return activeCreativeApps.filter { session in
            session.startTime > oneHourAgo
        }.count
    }
    
    private func identifyDeepWorkPeriods() -> [DeepWorkPeriod] {
        var deepWorkPeriods: [DeepWorkPeriod] = []
        
        for session in activeCreativeApps {
            if session.totalDuration > 1800 && session.activityLevel == .active { // 30 min+
                deepWorkPeriods.append(DeepWorkPeriod(
                    appName: session.appName,
                    startTime: session.startTime,
                    duration: session.totalDuration,
                    focusScore: focusMetrics.focusScore
                ))
            }
        }
        
        return deepWorkPeriods
    }
    
    private func analyzeDistractionPatterns() -> [DistractionPattern] {
        // This would analyze patterns of app switching, interruptions, etc.
        // For now, return empty array as a placeholder
        return []
    }
    
    // MARK: - Privacy and Permissions
    
    private func checkCachedPermission() {
        // Use synchronous permission check that doesn't trigger system dialogs
        hasScreenRecordingPermission = UserDefaults.standard.bool(forKey: permissionCacheKey) && CGPreflightScreenCaptureAccess()
        print("📱 Cached screen recording permission: \(hasScreenRecordingPermission)")
    }
    
    private func cachePermissionState(_ granted: Bool) {
        UserDefaults.standard.set(granted, forKey: permissionCacheKey)
        hasScreenRecordingPermission = granted
        print("💾 Cached screen recording permission: \(granted)")
    }
    
    func checkScreenRecordingPermission() -> Bool {
        return hasScreenRecordingPermission
    }
    
    func promptForScreenRecordingPermission() {
        CGRequestScreenCaptureAccess()
    }
    
    func enableScreenCapture() {
        // Called after user grants permission to set up screen capture
        if !hasScreenRecordingPermission {
            setupScreenCapture()
            startCreativeWorkMonitoring()
        }
    }
}

// MARK: - Supporting Types

enum ActivityLevel {
    case idle, focused, active, busy
    
    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .focused: return "Focused"
        case .active: return "Active" 
        case .busy: return "Busy"
        }
    }
    
    var color: NSColor {
        switch self {
        case .idle: return .systemGray
        case .focused: return .systemGreen
        case .active: return .systemBlue
        case .busy: return .systemOrange
        }
    }
}

struct CreativeAppSession {
    let appName: String
    let bundleId: String
    let startTime: Date
    var lastActivity: Date
    var totalDuration: TimeInterval
    var activityLevel: ActivityLevel
    var isActive: Bool
}

struct FocusMetrics {
    var sessionStart = Date()
    var focusScore: Double = 0
    var creativeTime: TimeInterval = 0
    var totalTime: TimeInterval = 0
    var distractionEvents: Int = 0
    var productivityTrend: Double = 0
}

class CreativeFlowInsights: ObservableObject {
    @Published var flowStateDetected = false
    @Published var contextSwitches = 0
    @Published var deepWorkPeriods: [DeepWorkPeriod] = []
    @Published var distractionPatterns: [DistractionPattern] = []
}

struct DeepWorkPeriod {
    let appName: String
    let startTime: Date
    let duration: TimeInterval
    let focusScore: Double
}

struct DistractionPattern {
    let type: DistractionType
    let frequency: Int
    let averageDuration: TimeInterval
    let suggestions: [String]
}

enum DistractionType {
    case appSwitching
    case socialMedia
    case notifications
    case webBrowsing
}

enum ScreenCaptureError: Error, LocalizedError {
    case noDisplayAvailable
    case permissionDenied
    case captureFailure(String)
    
    var errorDescription: String? {
        switch self {
        case .noDisplayAvailable:
            return "No display available for capture"
        case .permissionDenied:
            return "Screen recording permission denied"
        case .captureFailure(let message):
            return "Screen capture failed: \(message)"
        }
    }
}

// MARK: - Compatibility Check

@available(macOS, obsoleted: 12.3, message: "Use ScreenCaptureService for macOS 12.3+")
class LegacyScreenCaptureService {
    // Fallback implementation for older macOS versions
    static func captureWindow(for app: NSRunningApplication) -> NSImage? {
        // Use deprecated CGWindowListCreateImage as fallback
        let windowList = CGWindowListCreateImage(
            CGRect.null,
            .optionIncludingWindow,
            CGWindowID(app.processIdentifier),
            .bestResolution
        )
        
        if let cgImage = windowList {
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        }
        
        return nil
    }
}