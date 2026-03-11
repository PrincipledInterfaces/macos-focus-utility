import SwiftUI
import AppKit

/// Calibration interface for HUD projector setup - ALL controls on main display
struct HUDCalibrationView: View {
    @ObservedObject var settings: HUDProjectorSettings
    @Environment(\.dismiss) var dismiss

    @State private var calibrationStep: CalibrationStep = .displaySelection
    @State private var selectedDisplay: CGDirectDisplayID? = nil
    @State private var availableDisplays: [(id: CGDirectDisplayID, name: String, bounds: CGRect)] = []

    // Front edge calibration - values in display coordinates
    @State private var frontLeftCorner: CGPoint = .zero
    @State private var frontRightCorner: CGPoint = .zero

    // Crop calibration
    @State private var cropRect: CGRect = .zero

    // Projection window reference
    @State private var projectionWindow: NSWindow? = nil

    // Track if this is a recalibration
    private var isRecalibration: Bool {
        settings.isCalibrated
    }

    enum CalibrationStep: Int {
        case displaySelection = 0
        case frontEdgeAlignment = 1
        case confirmation = 2
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea(.all)

            VStack(spacing: 0) {
                // Header
                calibrationHeader
                    .frame(height: 140)  // Fixed height for header

                // Step content (takes remaining space)
                calibrationContent
                    .frame(maxHeight: .infinity)

                // Navigation buttons (always visible at bottom)
                navigationButtons
                    .padding(.bottom, 20)
                    .padding(.top, 16)
            }
        }
        .frame(width: 800, height: 600)
        .onAppear {
            // Reset to beginning if this is a recalibration
            if isRecalibration {
                calibrationStep = .displaySelection
                // Pre-select the current display
                selectedDisplay = settings.selectedDisplayID
            }
            loadAvailableDisplays()
        }
        .onDisappear {
            // Actually close the window when calibration view is dismissed
            if let window = projectionWindow {
                window.orderOut(nil)
                // Delay close to let animations finish
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    window.close()
                }
            }
            projectionWindow = nil
        }
    }

    private var calibrationHeader: some View {
        VStack(spacing: 8) {
            Text("HUD Projector Calibration")
                .font(.tomeHeading())
                .foregroundColor(.white)

            Text(stepDescription)
                .font(.tomeBody())
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            // Progress indicator
            HStack(spacing: 12) {
                ForEach(0..<3) { step in
                    Circle()
                        .fill(step <= calibrationStep.rawValue ? Color.blue : Color.white.opacity(0.3))
                        .frame(width: 10, height: 10)
                }
            }
            .padding(.top, 8)
        }
        .padding(.top, 40)
        .padding(.horizontal, 40)
    }

    private var stepDescription: String {
        switch calibrationStep {
        case .displaySelection:
            return "Select the display you want to use as the overhead projector"
        case .frontEdgeAlignment:
            return "Adjust sliders to align corners with TOME front edge on projection"
        case .confirmation:
            return "Review your calibration settings"
        }
    }

    @ViewBuilder
    private var calibrationContent: some View {
        switch calibrationStep {
        case .displaySelection:
            displaySelectionView
        case .frontEdgeAlignment:
            frontEdgeAlignmentControlsView
        case .confirmation:
            confirmationView
        }
    }

    // MARK: - Display Selection

    private var displaySelectionView: some View {
        VStack(spacing: 24) {
            Text("Available Displays")
                .font(.tomeSubheading())
                .foregroundColor(.white)

            if availableDisplays.isEmpty {
                Text("No external displays detected")
                    .font(.tomeBody())
                    .foregroundColor(.white.opacity(0.5))
            } else {
                VStack(spacing: 16) {
                    ForEach(availableDisplays, id: \.id) { display in
                        displayCard(for: display)
                    }
                }
            }

            Button(action: loadAvailableDisplays) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh Displays")
                }
                .font(.tomeBody())
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(40)
    }

    private func displayCard(for display: (id: CGDirectDisplayID, name: String, bounds: CGRect)) -> some View {
        Button(action: {
            selectedDisplay = display.id
            settings.selectDisplay(display.id)
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(display.name)
                        .font(.tomeSubheading())
                        .foregroundColor(.white)

                    Text("\(Int(display.bounds.width)) × \(Int(display.bounds.height))")
                        .font(.tomeBody())
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                if selectedDisplay == display.id {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.tomeSubheading())
                        .foregroundColor(.blue)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedDisplay == display.id ? Color.blue.opacity(0.2) : Color.white.opacity(0.05))
                    .stroke(selectedDisplay == display.id ? Color.blue.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func loadAvailableDisplays() {
        availableDisplays = settings.getAvailableDisplays()
    }

    // MARK: - Front Edge Alignment (Visual Click & Drag Interface)

    private var frontEdgeAlignmentControlsView: some View {
        VStack(spacing: 24) {
            Text("Align Front Edge")
                .font(.tomeSubheading())
                .foregroundColor(.white)

            Text("Drag the blue and green corners to align with your TOME's front edge. Look at the projector to see the result.")
                .font(.tomeBody())
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Visual representation of projection screen
            GeometryReader { geometry in
                let previewWidth: CGFloat = 500
                let previewHeight: CGFloat = 280
                let scaleX = previewWidth / settings.displayWidth
                let scaleY = previewHeight / settings.displayHeight

                ZStack {
                    // Background representing projection screen
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: previewWidth, height: previewHeight)
                        .overlay(
                            Rectangle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        )

                    // Left corner (draggable)
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: 28, height: 28)
                        )
                        .position(x: frontLeftCorner.x * scaleX, y: frontLeftCorner.y * scaleY)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    frontLeftCorner = CGPoint(
                                        x: max(0, min(settings.displayWidth, value.location.x / scaleX)),
                                        y: max(0, min(settings.displayHeight, value.location.y / scaleY))
                                    )
                                }
                        )

                    // Right corner (draggable)
                    Circle()
                        .fill(Color.green)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: 28, height: 28)
                        )
                        .position(x: frontRightCorner.x * scaleX, y: frontRightCorner.y * scaleY)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    frontRightCorner = CGPoint(
                                        x: max(0, min(settings.displayWidth, value.location.x / scaleX)),
                                        y: max(0, min(settings.displayHeight, value.location.y / scaleY))
                                    )
                                }
                        )

                    // Line connecting corners
                    Path { path in
                        path.move(to: CGPoint(x: frontLeftCorner.x * scaleX, y: frontLeftCorner.y * scaleY))
                        path.addLine(to: CGPoint(x: frontRightCorner.x * scaleX, y: frontRightCorner.y * scaleY))
                    }
                    .stroke(Color.white, lineWidth: 3)

                    // Arrow showing content direction (perpendicular, pointing AWAY from TOME)
                    let center = CGPoint(
                        x: ((frontLeftCorner.x + frontRightCorner.x) / 2) * scaleX,
                        y: ((frontLeftCorner.y + frontRightCorner.y) / 2) * scaleY
                    )
                    let angle = atan2(
                        (frontRightCorner.y - frontLeftCorner.y),
                        (frontRightCorner.x - frontLeftCorner.x)
                    )
                    // Arrow points perpendicular AWAY from TOME (90 degrees counterclockwise from edge)
                    let perpAngle = angle - .pi / 2

                    Path { path in
                        let arrowLength: CGFloat = 60
                        let arrowTip = CGPoint(
                            x: center.x + cos(perpAngle) * arrowLength,
                            y: center.y + sin(perpAngle) * arrowLength
                        )
                        path.move(to: center)
                        path.addLine(to: arrowTip)

                        // Arrowhead
                        let headSize: CGFloat = 12
                        let headAngle: CGFloat = .pi / 6

                        path.move(to: arrowTip)
                        path.addLine(to: CGPoint(
                            x: arrowTip.x - cos(perpAngle - headAngle) * headSize,
                            y: arrowTip.y - sin(perpAngle - headAngle) * headSize
                        ))

                        path.move(to: arrowTip)
                        path.addLine(to: CGPoint(
                            x: arrowTip.x - cos(perpAngle + headAngle) * headSize,
                            y: arrowTip.y - sin(perpAngle + headAngle) * headSize
                        ))
                    }
                    .stroke(Color.yellow, lineWidth: 3)

                    // Labels
                    Text("Blue: Left Corner")
                        .font(.tomeSmall())
                        .foregroundColor(.blue)
                        .position(x: 80, y: 20)

                    Text("Green: Right Corner")
                        .font(.tomeSmall())
                        .foregroundColor(.green)
                        .position(x: previewWidth - 80, y: 20)

                    Text("Content emerges →")
                        .font(.tomeSmall())
                        .foregroundColor(.yellow)
                        .position(x: center.x + cos(perpAngle) * 95, y: center.y + sin(perpAngle) * 95)
                }
                .frame(width: previewWidth, height: previewHeight)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
            .frame(height: 300)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
        .foregroundColor(.white)
        .onAppear {
            startFrontEdgeCalibration()
        }
    }

    // MARK: - Crop Adjustment (Visual Click & Drag Interface)

    private var cropAdjustmentControlsView: some View {
        VStack(spacing: 24) {
            Text("Adjust Crop Boundaries")
                .font(.tomeSubheading())
                .foregroundColor(.white)

            Text("Drag the corners to define your desk area. Content will be limited to this region.")
                .font(.tomeBody())
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Visual representation of projection screen
            GeometryReader { geometry in
                let previewWidth: CGFloat = 500
                let previewHeight: CGFloat = 280
                let scaleX = previewWidth / max(1, settings.displayWidth)
                let scaleY = previewHeight / max(1, settings.displayHeight)

                ZStack {
                    // Background representing projection screen
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: previewWidth, height: previewHeight)
                        .overlay(
                            Rectangle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        )

                    // TOME front edge (reference)
                    Path { path in
                        path.move(to: CGPoint(x: frontLeftCorner.x * scaleX, y: frontLeftCorner.y * scaleY))
                        path.addLine(to: CGPoint(x: frontRightCorner.x * scaleX, y: frontRightCorner.y * scaleY))
                    }
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)

                    // Crop rectangle (draggable) - only show if valid
                    if cropRect.width > 0 && cropRect.height > 0 {
                        Rectangle()
                            .stroke(Color.cyan, lineWidth: 3)
                            .frame(width: cropRect.width * scaleX, height: cropRect.height * scaleY)
                            .position(x: cropRect.midX * scaleX, y: cropRect.midY * scaleY)
                    }

                    // Corner handles for resizing - only show if valid
                    if cropRect.width > 0 && cropRect.height > 0 {
                        Group {
                        // Top-left
                        cropHandle(
                            x: cropRect.minX * scaleX,
                            y: cropRect.minY * scaleY,
                            color: .cyan,
                            onDrag: { value in
                                let newX = value.location.x / scaleX
                                let newY = value.location.y / scaleY
                                let maxX = cropRect.maxX - 50
                                let maxY = cropRect.maxY - 50
                                cropRect.origin.x = min(maxX, max(0, newX))
                                cropRect.origin.y = min(maxY, max(0, newY))
                                cropRect.size.width = cropRect.maxX - cropRect.minX
                                cropRect.size.height = cropRect.maxY - cropRect.minY
                            }
                        )

                        // Top-right
                        cropHandle(
                            x: cropRect.maxX * scaleX,
                            y: cropRect.minY * scaleY,
                            color: .cyan,
                            onDrag: { value in
                                let newX = value.location.x / scaleX
                                let newY = value.location.y / scaleY
                                let minWidth: CGFloat = 50
                                cropRect.size.width = max(minWidth, newX - cropRect.minX)
                                cropRect.origin.y = min(cropRect.maxY - minWidth, max(0, newY))
                                cropRect.size.height = cropRect.maxY - cropRect.minY
                            }
                        )

                        // Bottom-left
                        cropHandle(
                            x: cropRect.minX * scaleX,
                            y: cropRect.maxY * scaleY,
                            color: .cyan,
                            onDrag: { value in
                                let newX = value.location.x / scaleX
                                let newY = value.location.y / scaleY
                                let minWidth: CGFloat = 50
                                cropRect.origin.x = min(cropRect.maxX - minWidth, max(0, newX))
                                cropRect.size.width = cropRect.maxX - cropRect.minX
                                cropRect.size.height = max(minWidth, newY - cropRect.minY)
                            }
                        )

                        // Bottom-right
                        cropHandle(
                            x: cropRect.maxX * scaleX,
                            y: cropRect.maxY * scaleY,
                            color: .cyan,
                            onDrag: { value in
                                let newX = value.location.x / scaleX
                                let newY = value.location.y / scaleY
                                let minWidth: CGFloat = 50
                                cropRect.size.width = max(minWidth, min(settings.displayWidth - cropRect.minX, newX - cropRect.minX))
                                cropRect.size.height = max(minWidth, min(settings.displayHeight - cropRect.minY, newY - cropRect.minY))
                            }
                        )
                        }
                    }

                    // Label
                    Text("Cyan: Crop Area")
                        .font(.tomeSmall())
                        .foregroundColor(.cyan)
                        .position(x: previewWidth / 2, y: 20)
                }
                .frame(width: previewWidth, height: previewHeight)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
            .frame(height: 300)

            Button(action: {
                // Skip crop and use full display
                cropRect = CGRect(x: 0, y: 0, width: settings.displayWidth, height: settings.displayHeight)
                calibrationStep = .confirmation
                closeProjectionWindow()
            }) {
                Text("Skip (Use Full Display)")
                    .font(.tomeBody())
                    .foregroundColor(.white.opacity(0.7))
                    .underline()
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
        .foregroundColor(.white)
        .onAppear {
            startCropCalibration()
        }
    }

    // Helper for crop corner handles
    private func cropHandle(x: CGFloat, y: CGFloat, color: Color, onDrag: @escaping (DragGesture.Value) -> Void) -> some View {
        Circle()
            .fill(color)
            .frame(width: 16, height: 16)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: 20, height: 20)
            )
            .position(x: x, y: y)
            .gesture(
                DragGesture()
                    .onChanged(onDrag)
            )
    }

    // MARK: - Confirmation

    private var confirmationView: some View {
        VStack(spacing: 24) {
            Text("Calibration Complete!")
                .font(.tomeHeading())
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 16) {
                confirmationRow(icon: "display", title: "Display", value: settings.selectedDisplayName ?? "Unknown")
                confirmationRow(icon: "rectangle.and.hand.point.up.left", title: "Front Edge", value: "Configured")
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .stroke(Color.blue.opacity(0.3), lineWidth: 2)
            )
        }
        .padding(40)
    }

    private func confirmationRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.tomeSubheading())
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.tomeBody())
                    .foregroundColor(.white.opacity(0.6))

                Text(value)
                    .font(.tomeSubheading())
                    .foregroundColor(.white)
            }

            Spacer()
        }
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        HStack(spacing: 24) {
            if calibrationStep.rawValue > 0 {
                Button(action: goBack) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.tomeBody())
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.1))
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }

            Spacer()

            if calibrationStep == .confirmation {
                Button(action: saveAndFinish) {
                    HStack {
                        Text("Save & Finish")
                        Image(systemName: "checkmark")
                    }
                    .font(.tomeBody())
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green.opacity(0.3))
                            .stroke(Color.green, lineWidth: 2)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Button(action: goNext) {
                    HStack {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .font(.tomeBody())
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(canProceed ? Color.blue.opacity(0.3) : Color.white.opacity(0.05))
                            .stroke(canProceed ? Color.blue : Color.white.opacity(0.2), lineWidth: 2)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!canProceed)
            }
        }
        .padding(.horizontal, 40)
    }

    private var canProceed: Bool {
        switch calibrationStep {
        case .displaySelection:
            return selectedDisplay != nil
        case .frontEdgeAlignment:
            // Always allow proceeding - corners are initialized with defaults
            return true
        case .confirmation:
            return true
        }
    }

    private func goNext() {
        guard canProceed else { return }

        switch calibrationStep {
        case .displaySelection:
            calibrationStep = .frontEdgeAlignment
            // Initialize default corner positions
            let centerY = settings.displayHeight / 2
            let spacing: CGFloat = 200
            frontLeftCorner = CGPoint(x: settings.displayWidth / 2 - spacing, y: centerY)
            frontRightCorner = CGPoint(x: settings.displayWidth / 2 + spacing, y: centerY)

        case .frontEdgeAlignment:
            // Close projection window and wait before transitioning
            closeProjectionWindow()

            // Set cropRect to full display (no cropping)
            cropRect = CGRect(x: 0, y: 0, width: settings.displayWidth, height: settings.displayHeight)

            // Small delay to ensure window is fully deallocated before next step
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                calibrationStep = .confirmation
            }

        case .confirmation:
            break
        }
    }

    private func goBack() {
        closeProjectionWindow()
        if calibrationStep.rawValue > 0 {
            calibrationStep = CalibrationStep(rawValue: calibrationStep.rawValue - 1) ?? .displaySelection
        }
    }

    private func saveAndFinish() {
        settings.saveCalibration(
            frontLeft: frontLeftCorner,
            frontRight: frontRightCorner,
            crop: cropRect
        )
        settings.isEnabled = true
        settings.saveToUserDefaults()
        closeProjectionWindow()

        // Re-initialize HUD projector with new settings after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            HUDProjectorService.shared.initialize()
            print("📺 HUD projector re-initialized after calibration")
        }

        dismiss()
    }

    // MARK: - Projection Window Management

    private func startFrontEdgeCalibration() {
        guard let displayID = selectedDisplay else {
            print("❌ No display selected for calibration")
            return
        }
        let displayBounds = CGDisplayBounds(displayID)

        print("🎬 Starting front edge calibration")
        print("   Display ID: \(displayID)")
        print("   Display bounds: \(displayBounds)")

        let window = NSWindow(
            contentRect: displayBounds,
            styleMask: [.borderless, .titled],  // .titled needed for proper rendering
            backing: .buffered,
            defer: false
        )

        window.backgroundColor = .black
        window.isOpaque = true
        window.level = .screenSaver  // Higher level to ensure visibility
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.ignoresMouseEvents = true
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false  // CRITICAL: Prevent dealloc crash with active animations

        let view = FrontEdgeProjectionView(
            frontLeftCorner: $frontLeftCorner,
            frontRightCorner: $frontRightCorner,
            displaySize: displayBounds.size
        )

        let hosting = NSHostingController(rootView: view)

        // Set hosting view frame to match display size (origin at zero)
        hosting.view.frame = CGRect(origin: .zero, size: displayBounds.size)
        hosting.view.setFrameSize(displayBounds.size)

        window.contentView = hosting.view

        // Critical: Force layout update before showing (macOS Sequoia+ fix)
        hosting.view.needsLayout = true
        hosting.view.layoutSubtreeIfNeeded()
        hosting.view.needsDisplay = true

        window.setFrame(displayBounds, display: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()  // Force to front

        // Force a redraw
        window.display()

        print("✅ Projection window created and ordered front")
        print("   Window frame: \(window.frame)")
        print("   Window is visible: \(window.isVisible)")
        print("   Window level: \(window.level.rawValue)")
        print("   Content view frame: \(hosting.view.frame)")

        projectionWindow = window
    }

    private func startCropCalibration() {
        guard let displayID = selectedDisplay else {
            print("❌ No display selected for calibration")
            return
        }
        let displayBounds = CGDisplayBounds(displayID)

        print("🎬 Starting crop calibration")
        print("   Display ID: \(displayID)")
        print("   Display bounds: \(displayBounds)")

        let window = NSWindow(
            contentRect: displayBounds,
            styleMask: [.borderless, .titled],  // .titled needed for proper rendering
            backing: .buffered,
            defer: false
        )

        window.backgroundColor = .black
        window.isOpaque = true
        window.level = .screenSaver  // Higher level to ensure visibility
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.ignoresMouseEvents = true
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false  // CRITICAL: Prevent dealloc crash with active animations

        // Create a static view with current values - NO BINDINGS
        let view = CropProjectionView(
            cropRect: .constant(cropRect),
            frontLeftCorner: frontLeftCorner,
            frontRightCorner: frontRightCorner,
            displaySize: displayBounds.size
        )

        let hosting = NSHostingController(rootView: view)

        // Set hosting view frame to match display size (origin at zero)
        hosting.view.frame = CGRect(origin: .zero, size: displayBounds.size)
        hosting.view.setFrameSize(displayBounds.size)

        window.contentView = hosting.view

        // Critical: Force layout update before showing (macOS Sequoia+ fix)
        hosting.view.needsLayout = true
        hosting.view.layoutSubtreeIfNeeded()
        hosting.view.needsDisplay = true

        window.setFrame(displayBounds, display: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()  // Force to front

        // Force a redraw
        window.display()

        print("✅ Crop window created and ordered front")
        print("   Window frame: \(window.frame)")
        print("   Window is visible: \(window.isVisible)")
        print("   Window level: \(window.level.rawValue)")
        print("   Content view frame: \(hosting.view.frame)")

        projectionWindow = window
    }

    private func updateProjection() {
        // Projection updates automatically through bindings
    }

    private func updateCropProjection() {
        // Projection updates automatically through bindings
    }

    private func closeProjectionWindow() {
        guard let window = projectionWindow else { return }

        // Immediately hide to stop rendering
        window.orderOut(nil)

        // Close and deallocate the window immediately
        window.close()

        // Clear reference
        projectionWindow = nil

        print("🗑️ Projection window closed and deallocated")
    }
}

// MARK: - Projection Views (Read-only, no user interaction)

struct FrontEdgeProjectionView: View {
    @Binding var frontLeftCorner: CGPoint
    @Binding var frontRightCorner: CGPoint
    let displaySize: CGSize

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Instructions at top
            VStack {
                Text("Drag corners on main display to align with your TOME's front edge")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .padding(40)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.7))
                    )
                    .padding(.top, 60)

                Spacer()
            }

            // Left corner marker (BLUE)
            Circle()
                .fill(Color.blue)
                .frame(width: 50, height: 50)
                .shadow(color: .blue, radius: 30)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 70, height: 70)
                )
                .position(frontLeftCorner)

            // Right corner marker (GREEN)
            Circle()
                .fill(Color.green)
                .frame(width: 50, height: 50)
                .shadow(color: .green, radius: 30)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 70, height: 70)
                )
                .position(frontRightCorner)

            // Line connecting corners (TOME front edge)
            Path { path in
                path.move(to: frontLeftCorner)
                path.addLine(to: frontRightCorner)
            }
            .stroke(Color.white, lineWidth: 6)
            .shadow(color: .white.opacity(0.8), radius: 20)

            // Arrow showing where content emerges (perpendicular, away from TOME, towards user)
            let center = CGPoint(
                x: (frontLeftCorner.x + frontRightCorner.x) / 2,
                y: (frontLeftCorner.y + frontRightCorner.y) / 2
            )
            let angle = atan2(frontRightCorner.y - frontLeftCorner.y, frontRightCorner.x - frontLeftCorner.x)
            let arrowDistance: CGFloat = 150

            // Arrow pointing perpendicular AWAY from TOME (90 degrees counterclockwise from edge)
            let perpAngle = angle - .pi / 2

            Path { path in
                let arrowTip = CGPoint(
                    x: center.x + cos(perpAngle) * arrowDistance,
                    y: center.y + sin(perpAngle) * arrowDistance
                )
                path.move(to: center)
                path.addLine(to: arrowTip)

                // Arrowhead
                let headSize: CGFloat = 30
                let headAngle: CGFloat = .pi / 6

                path.move(to: arrowTip)
                path.addLine(to: CGPoint(
                    x: arrowTip.x - cos(perpAngle - headAngle) * headSize,
                    y: arrowTip.y - sin(perpAngle - headAngle) * headSize
                ))

                path.move(to: arrowTip)
                path.addLine(to: CGPoint(
                    x: arrowTip.x - cos(perpAngle + headAngle) * headSize,
                    y: arrowTip.y - sin(perpAngle + headAngle) * headSize
                ))
            }
            .stroke(Color.yellow, lineWidth: 8)
            .shadow(color: .yellow, radius: 25)

            // Label for arrow
            Text("Content emerges here →")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.yellow)
                .shadow(color: .yellow, radius: 15)
                .position(CGPoint(
                    x: center.x + cos(perpAngle) * (arrowDistance + 80),
                    y: center.y + sin(perpAngle) * (arrowDistance + 80)
                ))
        }
    }
}

struct CropProjectionView: View {
    @Binding var cropRect: CGRect
    let frontLeftCorner: CGPoint
    let frontRightCorner: CGPoint
    let displaySize: CGSize

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Show TOME edge for reference (dimmed)
            Path { path in
                path.move(to: frontLeftCorner)
                path.addLine(to: frontRightCorner)
            }
            .stroke(Color.white.opacity(0.3), lineWidth: 4)

            // Crop rectangle - only show if valid
            if cropRect.width > 0 && cropRect.height > 0 {
                Rectangle()
                    .stroke(Color.cyan, lineWidth: 6)
                    .frame(width: cropRect.width, height: cropRect.height)
                    .position(x: cropRect.midX, y: cropRect.midY)
                    .shadow(color: .cyan, radius: 20)
            }

            // Instructions
            VStack {
                Text("Adjust crop sliders on main display to define desk boundaries")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .padding(40)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.7))
                    )
                    .padding(.top, 60)

                Spacer()
            }
        }
    }
}
