import SwiftUI
import AppKit

/// Service for managing the HUD projector window and content
class HUDProjectorService: ObservableObject {
    static let shared = HUDProjectorService()

    @Published var isActive: Bool = false
    @Published var currentContent: HUDContent? = nil

    private var hudWindow: NSWindow?
    private var hostingController: NSHostingController<HUDProjectorView>?
    private let settings = HUDProjectorSettings.shared

    private init() {}

    // MARK: - Window Management

    func initialize() {
        guard settings.isEnabled && settings.isCalibrated else {
            print("⚠️ HUD projector not enabled or not calibrated")
            return
        }

        guard let displayID = settings.selectedDisplayID else {
            print("❌ No display selected for HUD projector")
            return
        }

        // Don't create the window immediately - wait for content to be requested
        // This avoids crashes with @State initialization during app startup
        print("✅ HUD projector ready (window will be created when content is displayed)")
        isActive = true
    }

    func shutdown() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if let window = self.hudWindow {
                window.orderOut(nil)  // Hide first
                window.close()
                self.hudWindow = nil
                self.hostingController = nil
            }
            self.currentContent = nil
            self.isActive = false
            print("📺 HUD projector shutdown")
        }
    }

    private func createHUDWindow(on displayID: CGDirectDisplayID) {
        let displayBounds = CGDisplayBounds(displayID)

        // Create a borderless, black window that covers the entire display
        let window = NSWindow(
            contentRect: displayBounds,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.title = "TOME HUD Projector"
        window.backgroundColor = .black
        window.isOpaque = true
        window.hasShadow = false
        window.ignoresMouseEvents = true // No mouse interaction needed on projector
        window.level = .statusBar // High level to stay on top
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true

        // Create the SwiftUI view
        let hudView = HUDProjectorView(service: self, settings: settings)
        let hosting = NSHostingController(rootView: hudView)

        // Set hosting view frame to match display size (origin at zero) - SAME AS CALIBRATION
        hosting.view.frame = CGRect(origin: .zero, size: displayBounds.size)
        hosting.view.setFrameSize(displayBounds.size)

        window.contentView = hosting.view
        window.setFrame(displayBounds, display: true)
        window.makeKeyAndOrderFront(nil)

        self.hudWindow = window
        self.hostingController = hosting
        self.isActive = true

        print("✅ HUD projector window created on display \(displayID)")
        print("   Bounds: \(displayBounds)")
    }

    // MARK: - Content Management

    func showContent(_ content: HUDContent) {
        guard isActive else {
            print("⚠️ HUD projector not active, cannot show content")
            return
        }

        // Create window if it doesn't exist yet
        if hudWindow == nil, let displayID = settings.selectedDisplayID {
            createHUDWindow(on: displayID)
        }

        DispatchQueue.main.async {
            self.currentContent = content
        }
    }

    func hideContent() {
        DispatchQueue.main.async {
            self.currentContent = nil
        }
    }

    func updateContent(_ update: (inout HUDContent) -> Void) {
        guard var content = currentContent else { return }
        update(&content)
        self.currentContent = content
    }

    // MARK: - Animation Triggers

    func triggerShockwave(color: Color, center: CGPoint? = nil) {
        let shockwaveCenter = center ?? settings.frontEdgeCenter
        let content = HUDContent(
            type: .shockwave(color: color, center: shockwaveCenter),
            position: .zero,
            size: CGSize(width: settings.displayWidth, height: settings.displayHeight)
        )
        showContent(content)

        // Auto-hide after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            self.hideContent()
        }
    }

    // MARK: - Calibration Mode

    func enterCalibrationMode() {
        guard let displayID = settings.selectedDisplayID else {
            print("❌ No display selected for calibration")
            return
        }

        // Close existing window if any
        shutdown()

        // Create calibration window
        createHUDWindow(on: displayID)

        print("🎯 Entered HUD calibration mode")
    }

    func exitCalibrationMode() {
        shutdown()
        print("🎯 Exited HUD calibration mode")
    }
}

// MARK: - HUD Content Model

struct HUDContent: Equatable {
    let id = UUID()
    var type: HUDContentType
    var position: CGPoint
    var size: CGSize
    var rotation: CGFloat = 0
    var opacity: Double = 1.0

    static func == (lhs: HUDContent, rhs: HUDContent) -> Bool {
        return lhs.id == rhs.id
    }
}

enum HUDContentType {
    case aiChat(messages: [ChatMessage])
    case shockwave(color: Color, center: CGPoint)
    case environmentInfo(environment: TOMEEnvironment, details: String)
    case notification(title: String, message: String)
    case homeScreen(selectedEnvironment: TOMEEnvironment, dialRotation: Double)
    case custom(view: AnyView)
}

// MARK: - HUD Projector View

struct HUDProjectorView: View {
    @ObservedObject var service: HUDProjectorService
    @ObservedObject var settings: HUDProjectorSettings

    @State private var shockwaveActive = false

    var body: some View {
        ZStack {
            // Pure black background (invisible to eye, acts as projection mask)
            Color.black
                .ignoresSafeArea(.all)

            // Render content if any
            if let content = service.currentContent {
                contentView(for: content)
            }
        }
        .frame(width: settings.displayWidth, height: settings.displayHeight)
        .onChange(of: service.currentContent) { _, newContent in
            if case .shockwave = newContent?.type {
                shockwaveActive = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    shockwaveActive = false
                }
            }
        }
    }

    @ViewBuilder
    private func contentView(for content: HUDContent) -> some View {
        Group {
            switch content.type {
            case .aiChat(let messages):
                HUDAIChatView(messages: messages, settings: settings)
                    .position(content.position)
                    .frame(width: content.size.width, height: content.size.height)
                    .rotationEffect(.radians(Double(content.rotation)))
                    .opacity(content.opacity)

            case .shockwave(let color, let center):
                SimpleGlowShockwave(center: center, isActive: shockwaveActive, color: color)
                    .ignoresSafeArea(.all)

            case .environmentInfo(let environment, let details):
                HUDEnvironmentInfoView(environment: environment, details: details, settings: settings)
                    .position(content.position)
                    .frame(width: content.size.width, height: content.size.height)
                    .rotationEffect(.radians(Double(content.rotation)))
                    .opacity(content.opacity)

            case .notification(let title, let message):
                HUDNotificationView(title: title, message: message, settings: settings)
                    .position(content.position)
                    .frame(width: content.size.width, height: content.size.height)
                    .rotationEffect(.radians(Double(content.rotation)))
                    .opacity(content.opacity)

            case .homeScreen(let selectedEnvironment, let dialRotation):
                HUDHomeScreenView(
                    selectedEnvironment: selectedEnvironment,
                    dialRotation: dialRotation,
                    settings: settings
                )
                .ignoresSafeArea(.all)

            case .custom(let view):
                view
                    .position(content.position)
                    .frame(width: content.size.width, height: content.size.height)
                    .rotationEffect(.radians(Double(content.rotation)))
                    .opacity(content.opacity)
            }
        }
        .clipped() // Clip to crop boundaries
    }
}

// MARK: - HUD AI Chat View

struct HUDAIChatView: View {
    let messages: [ChatMessage]
    let settings: HUDProjectorSettings

    @State private var appear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(messages.prefix(5).indices, id: \.self) { index in
                let message = messages[messages.count - min(5, messages.count) + index]
                HStack {
                    if message.role == "user" {
                        Spacer()
                    }

                    Text(message.content)
                        .font(.tomeBody())
                        .foregroundColor(.white)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(message.role == "user" ? Color.blue.opacity(0.3) : Color.white.opacity(0.1))
                                .shadow(color: Color.white.opacity(0.2), radius: 10)
                        )
                        .frame(maxWidth: 600)

                    if message.role == "assistant" {
                        Spacer()
                    }
                }
                .opacity(appear ? 1.0 : 0.0)
                .offset(y: appear ? 0 : 20)
                .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.1), value: appear)
            }
        }
        .padding(24)
        .onAppear {
            appear = true
        }
    }
}

// MARK: - HUD Environment Info View

struct HUDEnvironmentInfoView: View {
    let environment: TOMEEnvironment
    let details: String
    let settings: HUDProjectorSettings

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: environment.icon)
                    .font(.tomeSubheading())
                    .foregroundColor(environment.primaryColor)

                Text(environment.displayName)
                    .font(.tomeSubheading())
                    .foregroundColor(.white)
            }

            Text(details)
                .font(.tomeBody())
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.3))
                .stroke(environment.primaryColor.opacity(0.5), lineWidth: 2)
                .shadow(color: environment.primaryColor.opacity(0.5), radius: 20)
        )
    }
}

// MARK: - HUD Notification View

struct HUDNotificationView: View {
    let title: String
    let message: String
    let settings: HUDProjectorSettings

    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.tomeSubheading())
                .foregroundColor(.white)

            Text(message)
                .font(.tomeBody())
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.2))
                .stroke(Color.blue.opacity(pulse ? 0.8 : 0.4), lineWidth: 2)
                .shadow(color: Color.blue.opacity(0.6), radius: 20)
        )
        .scaleEffect(pulse ? 1.05 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - HUD Home Screen View

struct HUDHomeScreenView: View {
    let selectedEnvironment: TOMEEnvironment
    let dialRotation: Double
    let settings: HUDProjectorSettings

    private let tickSpacing: CGFloat = 12

    @State private var smoothRotation: Double = 0.0

    var body: some View {
        ZStack {
            HUDContentPlane(
                leftCorner: settings.frontLeftCorner,
                rightCorner: settings.frontRightCorner,
                displaySize: CGSize(width: settings.displayWidth, height: settings.displayHeight),
                contentWidth: settings.frontEdgeWidth
            ) {
                // Centered container for all HUD elements
                VStack(spacing: 0) {
                    // Environment label at top, centered
                    environmentLabel
                        .padding(.top, 15)

                    // Center indicator triangle pointing down at ticks
                    Triangle()
                        .fill(selectedEnvironment.primaryColor.opacity(0.8))
                        .frame(width: 8, height: 6)
                        .shadow(color: selectedEnvironment.primaryColor, radius: 4)
                        .padding(.top, 8)

                    // Scrolling tick marks below
                    tickStrip
                        .padding(.top, 4)
                }
                .frame(width: settings.frontEdgeWidth, height: 120)
                .clipped()
            }
        }
        .frame(width: settings.displayWidth, height: settings.displayHeight)
        .onChange(of: dialRotation) { oldValue, newValue in
            withAnimation(.linear(duration: 0.15)) {
                smoothRotation = newValue
            }
        }
        .onAppear {
            smoothRotation = dialRotation
        }
    }

    private var tickStrip: some View {
        let period: CGFloat = tickSpacing * 5  // 60px = one large-tick repeat cycle

        // Render ticks symmetrically around center: tick at relIndex=0 (large) sits at frame center
        let halfCount = Int(ceil(settings.frontEdgeWidth / (2 * tickSpacing))) + Int(period / tickSpacing) + 2
        let totalCount = halfCount * 2 + 1

        // Wrap scroll within [0, period) for seamless infinite looping
        let rawScroll = smoothRotation / 360.0 * period * 6
        let wrapped = (rawScroll.truncatingRemainder(dividingBy: period) + period)
            .truncatingRemainder(dividingBy: period)

        return HStack(spacing: 0) {
            ForEach(0..<totalCount, id: \.self) { i in
                let rel = i - halfCount
                tickMark(isLarge: rel % 5 == 0)
                    .frame(width: tickSpacing)
            }
        }
        .frame(width: CGFloat(totalCount) * tickSpacing)
        .offset(x: -wrapped)
        .frame(width: settings.frontEdgeWidth, alignment: .center)
        .clipped()
    }

    private func tickMark(isLarge: Bool) -> some View {
        let tickLength: CGFloat = isLarge ? 14 : 7
        let tickWidth: CGFloat = isLarge ? 2 : 1
        let tickOpacity: Double = isLarge ? 0.7 : 0.4

        return Rectangle()
            .fill(Color.white.opacity(tickOpacity))
            .frame(width: tickWidth, height: tickLength)
    }

    private var environmentLabel: some View {
        HStack(spacing: 10) {
            Image(systemName: selectedEnvironment.icon)
                .font(.system(size: 16, weight: .light))
                .foregroundColor(selectedEnvironment.primaryColor.opacity(0.9))
                .shadow(color: selectedEnvironment.primaryColor.opacity(0.6), radius: 8)

            Text(selectedEnvironment.displayName.uppercased())
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .tracking(2)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.4))
                .overlay(
                    Capsule()
                        .stroke(selectedEnvironment.primaryColor.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: selectedEnvironment.primaryColor.opacity(0.3), radius: 10)
        )
    }
}

// Simple triangle shape for the indicator
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - HUD Content Plane Transform
// Maps local "plane" coordinates to display coordinates
// Green point (leftCorner) = top-left of content plane (0, 0 in SwiftUI coords)
// Blue point (rightCorner) = top-right of content plane (width, 0)
// Content extends downward (+Y) from the calibrated edge, into the projection space

struct HUDContentPlane<Content: View>: View {
    let leftCorner: CGPoint  // Green calibration point
    let rightCorner: CGPoint // Blue calibration point
    let displaySize: CGSize
    let contentWidth: CGFloat // The "design" width of the content (will be scaled to match edge)
    let content: Content

    init(leftCorner: CGPoint, rightCorner: CGPoint, displaySize: CGSize, contentWidth: CGFloat, @ViewBuilder content: () -> Content) {
        self.leftCorner = leftCorner
        self.rightCorner = rightCorner
        self.displaySize = displaySize
        self.contentWidth = contentWidth
        self.content = content()
    }

    var body: some View {
        // Calculate edge properties
        let edgeWidth = sqrt(pow(rightCorner.x - leftCorner.x, 2) + pow(rightCorner.y - leftCorner.y, 2))
        let edgeAngle = atan2(rightCorner.y - leftCorner.y, rightCorner.x - leftCorner.x)

        // Scale factor: map content's design width to actual calibrated edge width
        let scale = edgeWidth / contentWidth

        // Calculate perpendicular direction (away from TOME)
        // Using - π/2 to point toward the user
        let perpAngle = edgeAngle - .pi / 2

        // Transform content:
        // Rotate by edgeAngle + π to align with edge
        // Offset in perpendicular direction to place content on the "away from TOME" side
        let perpOffset: CGFloat = 150 // Offset to position content on "away from TOME" side
        let finalX = rightCorner.x + perpOffset * CGFloat(Darwin.cos(perpAngle))
        let finalY = rightCorner.y + perpOffset * CGFloat(Darwin.sin(perpAngle))

        return content
            .scaleEffect(scale, anchor: .topLeading)
            .rotationEffect(.radians(edgeAngle + .pi), anchor: .topLeading)
            .offset(x: finalX, y: finalY)
            .frame(width: displaySize.width, height: displaySize.height, alignment: .topLeading)
    }
}
