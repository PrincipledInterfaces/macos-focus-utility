import SwiftUI

struct FocusControlPanel: View {
    @ObservedObject var focusService: FocusEnforcementService
    @ObservedObject var tomeState: TOMEState
    @State private var showOverrideRequest = false
    @State private var overrideAppName = ""
    @State private var overrideDuration = 5.0 // minutes
    
    var body: some View {
        VStack(spacing: 20) {
            headerSection
            
            if focusService.isEnforcementActive {
                activeFocusSection
            } else {
                inactiveFocusSection
            }
            
            Divider()
                .background(.white.opacity(0.1))
            
            statisticsSection
            
            if focusService.isEnforcementActive {
                Divider()
                    .background(.white.opacity(0.1))
                
                overrideSection
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.black.opacity(0.8))
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
        .sheet(isPresented: $showOverrideRequest) {
            overrideRequestSheet
        }
    }
    
    private var headerSection: some View {
        HStack {
            Image(systemName: focusService.isEnforcementActive ? "target" : "target.slash")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(focusService.isEnforcementActive ? .green : .gray)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Focus Control")
                    .font(.tomeHeading())
                    .foregroundColor(.white)
                
                Text(focusService.isEnforcementActive ? "Active" : "Inactive")
                    .font(.tomeCaption())
                    .foregroundColor(focusService.isEnforcementActive ? .green : .gray)
            }
            
            Spacer()
            
            Button(action: toggleFocusMode) {
                Image(systemName: focusService.isEnforcementActive ? "stop.fill" : "play.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(focusService.isEnforcementActive ? .red.opacity(0.2) : .green.opacity(0.2))
                            .stroke(focusService.isEnforcementActive ? .red.opacity(0.4) : .green.opacity(0.4), lineWidth: 1)
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var activeFocusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Current Mode")
                    .font(.tomeBodyMedium())
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                Text(focusService.currentFocusMode.displayName)
                    .font(.tomeSmallMedium())
                    .foregroundColor(focusService.currentFocusMode.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(focusService.currentFocusMode.color.opacity(0.1))
                            .stroke(focusService.currentFocusMode.color.opacity(0.3), lineWidth: 1)
                    )
            }
            
            Text(focusService.currentFocusMode.description)
                .font(.tomeSmall())
                .foregroundColor(.white.opacity(0.6))
            
            // Focus mode selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Adjust Focus Level")
                    .font(.tomeCaptionMedium())
                    .foregroundColor(.white.opacity(0.7))
                
                HStack(spacing: 12) {
                    ForEach(FocusMode.allCases.filter { $0 != .disabled }, id: \.self) { mode in
                        focusModeButton(mode)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.03))
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private var inactiveFocusSection: some View {
        VStack(spacing: 12) {
            Text("Focus mode is disabled")
                .font(.tomeBody())
                .foregroundColor(.white.opacity(0.6))
            
            Text("Activate focus mode to block distracting applications and maintain concentration in your current environment.")
                .font(.tomeSmall())
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
            
            Button("Activate Focus Mode") {
                activateFocusForCurrentEnvironment()
            }
            .font(.tomeBodyMedium())
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.green.opacity(0.2))
                    .stroke(.green.opacity(0.4), lineWidth: 1)
            )
            .buttonStyle(PlainButtonStyle())
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.03))
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Focus")
                .font(.tomeBodyMedium())
                .foregroundColor(.white.opacity(0.8))
            
            HStack {
                statisticItem("Apps Blocked", value: "\(focusService.blockedAppsToday.count)")
                statisticItem("Violations", value: "\(focusService.focusViolations)")
                statisticItem("Environment", value: tomeState.currentEnvironment.displayName)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.03))
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private var overrideSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Emergency Override")
                    .font(.tomeBodyMedium())
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.orange)
            }
            
            Text("Temporarily allow a blocked application for a specific duration.")
                .font(.tomeSmall())
                .foregroundColor(.white.opacity(0.6))
            
            Button("Request Override") {
                showOverrideRequest = true
            }
            .font(.tomeSmallMedium())
            .foregroundColor(.orange)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(.orange.opacity(0.1))
                    .stroke(.orange.opacity(0.3), lineWidth: 1)
            )
            .buttonStyle(PlainButtonStyle())
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.03))
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private var overrideRequestSheet: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Request Focus Override")
                    .font(.tomeHeading())
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("Cancel") {
                    showOverrideRequest = false
                }
                .font(.tomeSmall())
                .foregroundColor(.white.opacity(0.6))
                .buttonStyle(PlainButtonStyle())
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Application Name")
                    .font(.tomeBodyMedium())
                    .foregroundColor(.white.opacity(0.8))
                
                TextField("Enter app name", text: $overrideAppName)
                    .font(.tomeBody())
                    .foregroundColor(.white)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.white.opacity(0.05))
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Duration: \(Int(overrideDuration)) minutes")
                    .font(.tomeBodyMedium())
                    .foregroundColor(.white.opacity(0.8))
                
                HStack {
                    Text("5 min")
                        .font(.tomeSmall())
                        .foregroundColor(.white.opacity(0.5))
                    
                    Slider(value: $overrideDuration, in: 5...60, step: 5)
                        .accentColor(.orange)
                    
                    Text("60 min")
                        .font(.tomeSmall())
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    showOverrideRequest = false
                }
                .font(.tomeBody())
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.05))
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
                .buttonStyle(PlainButtonStyle())
                
                Button("Grant Override") {
                    grantOverride()
                }
                .font(.tomeBodyMedium())
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.orange.opacity(0.2))
                        .stroke(.orange.opacity(0.4), lineWidth: 1)
                )
                .buttonStyle(PlainButtonStyle())
                .disabled(overrideAppName.isEmpty)
            }
            
            Spacer()
        }
        .padding(20)
        .frame(width: 400, height: 300)
        .background(.black)
    }
    
    private func focusModeButton(_ mode: FocusMode) -> some View {
        Button(action: { changeFocusMode(to: mode) }) {
            VStack(spacing: 4) {
                Image(systemName: mode.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(mode == focusService.currentFocusMode ? .white : mode.color)
                
                Text(mode.displayName)
                    .font(.tomeTiny())
                    .foregroundColor(mode == focusService.currentFocusMode ? .white : .white.opacity(0.6))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(mode == focusService.currentFocusMode ? mode.color.opacity(0.2) : .clear)
                    .stroke(mode == focusService.currentFocusMode ? mode.color.opacity(0.4) : .white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func statisticItem(_ title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.tomeBodyMedium())
                .foregroundColor(.white)
            
            Text(title)
                .font(.tomeTiny())
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
    
    private func toggleFocusMode() {
        if focusService.isEnforcementActive {
            tomeState.deactivateFocusEnforcement()
        } else {
            activateFocusForCurrentEnvironment()
        }
    }
    
    private func activateFocusForCurrentEnvironment() {
        tomeState.activateFocusEnforcement(for: tomeState.currentEnvironment)
    }
    
    private func changeFocusMode(to mode: FocusMode) {
        focusService.activateFocusMode(mode, environment: tomeState.currentEnvironment)
    }
    
    private func grantOverride() {
        let durationSeconds = overrideDuration * 60
        tomeState.requestFocusOverride(for: overrideAppName, duration: durationSeconds)
        
        overrideAppName = ""
        overrideDuration = 5.0
        showOverrideRequest = false
    }
}

// MARK: - Focus Mode Extensions

extension FocusMode {
    var color: Color {
        switch self {
        case .disabled: return .gray
        case .lenient: return .green
        case .balanced: return .orange
        case .strict: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .disabled: return "target.slash"
        case .lenient: return "leaf"
        case .balanced: return "target"
        case .strict: return "lock"
        }
    }
}