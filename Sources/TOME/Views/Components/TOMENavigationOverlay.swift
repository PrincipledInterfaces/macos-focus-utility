import SwiftUI

struct TOMENavigationOverlay: View {
    let onNavigateHome: () -> Void
    let environmentName: String
    let environmentColor: Color
    let showBackButton: Bool
    let backAction: (() -> Void)?
    let tomeState: TOMEState?
    
    @State private var showFocusPanel = false
    
    init(
        onNavigateHome: @escaping () -> Void,
        environmentName: String,
        environmentColor: Color = .white,
        showBackButton: Bool = false,
        backAction: (() -> Void)? = nil,
        tomeState: TOMEState? = nil
    ) {
        self.onNavigateHome = onNavigateHome
        self.environmentName = environmentName
        self.environmentColor = environmentColor
        self.showBackButton = showBackButton
        self.backAction = backAction
        self.tomeState = tomeState
    }
    
    var body: some View {
        VStack {
            HStack {
                // Back button (if needed)
                if showBackButton, let backAction = backAction {
                    Button(action: backAction) {
                        Image(systemName: "chevron.left")
                            .font(.tomeBodyMedium())
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.trailing, 12)
                }
                
                // Home button with clean design
                Button(action: onNavigateHome) {
                    HStack(spacing: 6) {
                        Image(systemName: "house.fill")
                            .font(.tomeCaptionMedium())
                        Text("Home")
                            .font(.tomeCaptionMedium())
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .keyboardShortcut(.escape, modifiers: [])
                
                Spacer()
                
                // Focus control button
                if let tomeState = tomeState, let focusService = tomeState.focusEnforcementService {
                    Button(action: { showFocusPanel.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: focusService.isEnforcementActive ? "target" : "target.slash")
                                .font(.tomeSmallLabelMedium())
                                .foregroundColor(focusService.isEnforcementActive ? .green : .white.opacity(0.6))
                            
                            Text(focusService.isEnforcementActive ? "FOCUS" : "UNFOCUSED")
                                .font(.tomeTinyMedium())
                                .foregroundColor(focusService.isEnforcementActive ? .green : .white.opacity(0.6))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.4))
                                .stroke(focusService.isEnforcementActive ? .green.opacity(0.3) : .white.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Environment indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(environmentColor)
                        .frame(width: 6, height: 6)
                    
                    Text(environmentName.uppercased())
                        .font(.tomeSmallLabelMedium())
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.3))
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            Spacer()
            
            // Subtle bottom hint
            HStack {
                Text("ESC")
                    .font(.tomeTinyMedium())
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.1))
                    )
                
                Text("Home")
                    .font(.tomeTiny())
                    .foregroundColor(.white.opacity(0.3))
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .overlay(
            // Focus control panel overlay
            Group {
                if showFocusPanel, 
                   let tomeState = tomeState,
                   let focusService = tomeState.focusEnforcementService {
                    ZStack {
                        // Background dim
                        Color.black.opacity(0.4)
                            .ignoresSafeArea(.all)
                            .onTapGesture {
                                showFocusPanel = false
                            }
                        
                        // Focus control panel
                        VStack {
                            Spacer()
                            
                            HStack {
                                Spacer()
                                
                                FocusControlPanel(
                                    focusService: focusService,
                                    tomeState: tomeState
                                )
                                .frame(width: 350)
                                
                                Spacer()
                            }
                            
                            Spacer()
                        }
                    }
                    .transition(.opacity)
                }
            }
        )
    }
}

// Preview - removed #Preview macro for compatibility