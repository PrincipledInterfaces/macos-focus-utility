import SwiftUI

/// Settings view for TOME configuration
struct TOMESettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var hudSettings = HUDProjectorSettings.shared
    @ObservedObject var hudService = HUDProjectorService.shared

    @State private var showCalibration = false

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea(.all)

            VStack(spacing: 0) {
                // Header
                settingsHeader

                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // HUD Projector Section
                        hudProjectorSection

                        Spacer(minLength: 40)
                    }
                    .padding(40)
                }

                // Close button
                closeButton
                    .padding(.bottom, 40)
            }
        }
        .frame(width: 700, height: 600)
        .sheet(isPresented: $showCalibration) {
            HUDCalibrationView(settings: hudSettings)
        }
    }

    private var settingsHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("TOME Settings")
                    .font(.tomeHeading())
                    .foregroundColor(.white)

                Text("Configure your TOME experience")
                    .font(.tomeBody())
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.tomeSubheading())
                    .foregroundColor(.white.opacity(0.8))
                    .padding(8)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 40)
        .padding(.top, 40)
        .padding(.bottom, 20)
    }

    private var hudProjectorSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section header
            HStack {
                Image(systemName: "videoprojector")
                    .font(.tomeSubheading())
                    .foregroundColor(.blue)

                Text("HUD Projector")
                    .font(.tomeSubheading())
                    .foregroundColor(.white)
            }

            Divider()
                .background(Color.white.opacity(0.2))

            // Description
            Text("Enable overhead projection for an immersive heads-up display experience. When enabled, AI chat windows and environment content will appear on your desk via an external projector.")
                .font(.tomeBody())
                .foregroundColor(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)

            // Enable/Disable Toggle
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable HUD Projector")
                        .font(.tomeBody())
                        .foregroundColor(.white)

                    Text(hudSettings.isEnabled ? "HUD projector is active" : "HUD projector is disabled")
                        .font(.tomeSmall())
                        .foregroundColor(hudSettings.isEnabled ? .green.opacity(0.8) : .white.opacity(0.5))
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { hudSettings.isEnabled },
                    set: { newValue in
                        if newValue && !hudSettings.isCalibrated {
                            // Show calibration first
                            showCalibration = true
                        } else {
                            hudSettings.isEnabled = newValue
                            hudSettings.saveToUserDefaults()

                            if newValue {
                                hudService.initialize()
                            } else {
                                hudService.shutdown()
                            }
                        }
                    }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .blue))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )

            // Calibration Status
            if hudSettings.isEnabled {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Calibration Status")
                        .font(.tomeBody())
                        .foregroundColor(.white.opacity(0.8))

                    HStack {
                        Image(systemName: hudSettings.isCalibrated ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(hudSettings.isCalibrated ? .green : .orange)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(hudSettings.isCalibrated ? "Calibrated" : "Not Calibrated")
                                .font(.tomeBody())
                                .foregroundColor(.white)

                            if let displayName = hudSettings.selectedDisplayName {
                                Text("Display: \(displayName)")
                                    .font(.tomeSmall())
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }

                        Spacer()

                        Button(action: { showCalibration = true }) {
                            Text(hudSettings.isCalibrated ? "Recalibrate" : "Calibrate")
                                .font(.tomeBody())
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.blue.opacity(0.3))
                                        .stroke(Color.blue, lineWidth: 1)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.05))
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )

                // Test HUD Button
                if hudSettings.isCalibrated {
                    Button(action: testHUD) {
                        HStack {
                            Image(systemName: "play.circle")
                            Text("Test HUD Projection")
                        }
                        .font(.tomeBody())
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.green.opacity(0.2))
                                .stroke(Color.green.opacity(0.5), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            // Info callout
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "info.circle")
                    .font(.tomeBody())
                    .foregroundColor(.blue.opacity(0.8))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Setup Requirements")
                        .font(.tomeSmallMedium())
                        .foregroundColor(.white)

                    Text("You'll need an external display or projector mounted above your desk. The calibration process will help you align the projection with your physical TOME controller.")
                        .font(.tomeSmall())
                        .foregroundColor(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.05))
                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
            )
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.03))
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var closeButton: some View {
        Button(action: { dismiss() }) {
            Text("Close")
                .font(.tomeBody())
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func testHUD() {
        guard hudService.isActive || hudSettings.isEnabled else {
            // Initialize if not active
            hudService.initialize()
            return
        }

        // Show a test shockwave animation
        hudService.triggerShockwave(color: .blue)

        // Show test content after shockwave
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let testMessages = [
                ChatMessage(role: "assistant", content: "HUD Projection Test"),
                ChatMessage(role: "assistant", content: "If you can see this on your projector, the HUD is working correctly!"),
                ChatMessage(role: "user", content: "This content emerges from the TOME controller")
            ]

            // Calculate position perpendicular to front edge
            let frontEdgeCenter = hudSettings.frontEdgeCenter
            let angle = hudSettings.frontEdgeAngle

            // Move content away from TOME (perpendicular to edge, 90 degrees counterclockwise)
            let distance: CGFloat = 200
            let perpAngle = angle - .pi / 2
            let offsetX = cos(perpAngle) * distance
            let offsetY = sin(perpAngle) * distance

            let testContent = HUDContent(
                type: .aiChat(messages: testMessages),
                position: CGPoint(x: frontEdgeCenter.x + offsetX, y: frontEdgeCenter.y + offsetY),
                size: CGSize(width: 600, height: 400),
                rotation: angle  // Align content with front edge
            )

            hudService.showContent(testContent)

            // Hide after 5 seconds - IMPORTANT: Actually hide it!
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                hudService.hideContent()
            }
        }
    }
}
