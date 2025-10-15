import SwiftUI

struct HomeView: View {
    let onEnvironmentSelected: (TOMEEnvironment, CGPoint) -> Void
    @ObservedObject var currentState: TOMEState
    
    @State private var selectedEnvironment: TOMEEnvironment = .planning
    @State private var rotationAngle: Double = 0
    @State private var isHovering = false
    @State private var showShockwave = false
    @State private var shockwaveCenter: CGPoint = .zero
    @State private var shockwaveColor: Color = .white
    @State private var iconScale: CGFloat = 1.0
    @State private var doorwayExpansion: CGFloat = 1.0

    private let environments: [TOMEEnvironment] = [.planning, .writerDesk, .workshop, .coffeeshop, .garden]
    
    var body: some View {
        ZStack {
            // Pure black background with subtle breathing effect
            Color.black
                .ignoresSafeArea(.all)

            VStack(spacing: 0) {
                Spacer()

                // Central door - the focus of the entire interface
                centralDoor

                Spacer()

                // Minimal recent tasks at bottom
                recentTasksRow
                    .padding(.bottom, 60)
            }

            // Shockwave animation overlay
            if showShockwave {
                ZStack {
                    GlassmorphicShockwave(center: shockwaveCenter, isActive: showShockwave, color: shockwaveColor)
                        .opacity(0.5) // Half opacity for home screen

                    // Expanding doorway rectangle animation
                    RoundedRectangle(cornerRadius: 16 * doorwayExpansion)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(max(0, 1.0 - (doorwayExpansion - 1.0) / 12.0) * 0.9),
                                    selectedEnvironment.primaryColor.opacity(max(0, 1.0 - (doorwayExpansion - 1.0) / 12.0) * 0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 200 * doorwayExpansion, height: 300 * doorwayExpansion)
                        .position(shockwaveCenter)
                        .shadow(color: selectedEnvironment.primaryColor.opacity(max(0, 1.0 - (doorwayExpansion - 1.0) / 12.0) * 0.9), radius: 20)
                        .blur(radius: 0.5)
                        .opacity(max(0, 1.0 - (doorwayExpansion - 1.0) / 12.0))
                }
                .ignoresSafeArea(.all)
            }
        }
    }
    
    // Simplified central door - clean, Nothing-inspired aesthetic
    private var centralDoor: some View {
        VStack(spacing: 0) {
            // Rotate to select environment - minimal dial
            dialSelection
                .padding(.bottom, 20)
            
            // The door itself - simple, elegant
            doorPortal
        }
    }
    
    private var dialSelection: some View {
        HStack(spacing: 40) {
            ForEach(Array(environments.enumerated()), id: \.offset) { index, environment in
                VStack(spacing: 8) {
                    Circle()
                        .fill(environment == selectedEnvironment ? Color.white : Color.clear)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    
                    Text(environment.displayName)
                        .font(.tomeCaption())
                        .foregroundColor(environment == selectedEnvironment ? .white : .white.opacity(0.4))
                }
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedEnvironment = environment
                    }
                }
            }
        }
    }
    
    private var doorPortal: some View {
        GeometryReader { geometry in
            ZStack {
                // Glassmorphic rounded rectangle outline (unfilled)
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.6),
                                Color.white.opacity(0.3),
                                selectedEnvironment.primaryColor.opacity(0.4),
                                Color.white.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 200, height: 300)
                    // Glassmorphic effects on the outline
                    .shadow(color: .white.opacity(0.3), radius: 8, x: -4, y: -4) // Top-left highlight
                    .shadow(color: .black.opacity(0.4), radius: 8, x: 4, y: 4) // Bottom-right shadow
                    .shadow(color: selectedEnvironment.primaryColor.opacity(0.6), radius: 20, x: 0, y: 0) // Color glow
                
                // Inner glow when hovered (subtle)
                RoundedRectangle(cornerRadius: 16)
                    .fill(selectedEnvironment.primaryColor.opacity(isHovering ? 0.05 : 0.02))
                    .frame(width: 200, height: 300)
                
                // Environment icon in center with glassmorphic effects
                VStack(spacing: 16) {
                    ZStack {
                        // Base icon with enhanced glassmorphic effects
                        Image(systemName: selectedEnvironment.icon)
                            .font(.tomeTitle().weight(.ultraLight))
                            .foregroundColor(.white.opacity(0.8))
                            // Multiple layered shadows for depth
                            .shadow(color: selectedEnvironment.primaryColor.opacity(0.8), radius: 25, x: 0, y: 0) // Strong glow
                            .shadow(color: selectedEnvironment.primaryColor.opacity(0.4), radius: 40, x: 0, y: 0) // Outer glow
                            .shadow(color: .white.opacity(0.5), radius: 12, x: -6, y: -6) // Top-left highlight
                            .shadow(color: .white.opacity(0.2), radius: 20, x: -10, y: -10) // Extended highlight
                            .shadow(color: .black.opacity(0.6), radius: 12, x: 6, y: 6) // Bottom-right shadow
                            .shadow(color: .black.opacity(0.3), radius: 20, x: 10, y: 10) // Extended shadow
                        
                        // Primary glass reflection
                        Image(systemName: selectedEnvironment.icon)
                            .font(.tomeTitle().weight(.ultraLight))
                            .foregroundColor(.white.opacity(0.25))
                            .blur(radius: 1.5)
                            .offset(x: -3, y: -3)
                        
                        // Secondary glass reflection for more depth
                        Image(systemName: selectedEnvironment.icon)
                            .font(.tomeTitle().weight(.ultraLight))
                            .foregroundColor(.white.opacity(0.1))
                            .blur(radius: 3)
                            .offset(x: -6, y: -6)
                        
                        // Subtle color gradient overlay
                        Image(systemName: selectedEnvironment.icon)
                            .font(.tomeTitle().weight(.ultraLight))
                            .foregroundColor(selectedEnvironment.primaryColor.opacity(0.1))
                            .blur(radius: 4)
                            .offset(x: 2, y: 2)
                        
                        // Hover effect - additional glow
                        if isHovering {
                            Image(systemName: selectedEnvironment.icon)
                                .font(.tomeTitle().weight(.ultraLight))
                                .foregroundColor(selectedEnvironment.primaryColor.opacity(0.3))
                                .blur(radius: 8)
                                .scaleEffect(1.1)
                        }
                    }
                    
                    Text("Enter")
                        .font(.tomeSmall())
                        .foregroundColor(.white.opacity(0.6))
                }
                .scaleEffect(iconScale)
            }
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = hovering
                }
            }
            .onTapGesture {
                let frame = geometry.frame(in: .global)
                let center = CGPoint(x: frame.midX, y: frame.midY)

                // Set shockwave properties
                shockwaveCenter = center
                shockwaveColor = selectedEnvironment.primaryColor
                showShockwave = true
                doorwayExpansion = 1.0

                // Animate icon scale during shockwave
                withAnimation(.easeOut(duration: 2.5)) {
                    iconScale = 1.3
                }

                // Animate doorway expansion at the same time as shockwave - expand beyond screen
                withAnimation(.easeOut(duration: 2.5)) {
                    doorwayExpansion = 10.0  // Even larger to ensure it fills the screen
                }

                // Transition to environment after wave expands
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    onEnvironmentSelected(selectedEnvironment, center)
                    showShockwave = false

                    // Reset states
                    withAnimation(.easeOut(duration: 0.3)) {
                        iconScale = 1.0
                        doorwayExpansion = 1.0
                    }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedEnvironment)
        }
        .frame(width: 200, height: 300)
    }
    
    // Quick access to recent environments - clear and intuitive
    private var recentTasksRow: some View {
        VStack(spacing: 8) {
            Text("Recent")
                .font(.tomeSmallLabelMedium())
                .foregroundColor(.white.opacity(0.4))
            
            HStack(spacing: 16) {
                ForEach(currentState.projects.prefix(3)) { project in
                    GeometryReader { geometry in
                        Button(action: {
                            selectedEnvironment = project.environment

                            // Get button center for shockwave
                            let frame = geometry.frame(in: .global)
                            let center = CGPoint(x: frame.midX, y: frame.midY)

                            // Set shockwave properties
                            shockwaveCenter = center
                            shockwaveColor = project.environment.primaryColor
                            showShockwave = true
                            doorwayExpansion = 1.0

                            // Animate doorway expansion
                            withAnimation(.easeOut(duration: 2.5)) {
                                doorwayExpansion = 10.0  // Even larger to ensure it fills the screen
                            }

                            // Transition to environment after wave expands
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                onEnvironmentSelected(project.environment, center)
                                showShockwave = false

                                // Reset doorway
                                withAnimation(.easeOut(duration: 0.3)) {
                                    doorwayExpansion = 1.0
                                }
                            }
                        }) {
                        VStack(spacing: 4) {
                            ZStack {
                                // Base icon with glassmorphic effects
                                Image(systemName: project.environment.icon)
                                    .font(.tomeCaptionMedium())
                                    .foregroundColor(project.environment.primaryColor)
                                    // Glassmorphic effects scaled for smaller icon
                                    .shadow(color: project.environment.primaryColor.opacity(0.7), radius: 12, x: 0, y: 0) // Glow
                                    .shadow(color: .white.opacity(0.4), radius: 6, x: -2, y: -2) // Highlight
                                    .shadow(color: .black.opacity(0.5), radius: 6, x: 2, y: 2) // Shadow
                                
                                // Glass reflection
                                Image(systemName: project.environment.icon)
                                    .font(.tomeCaptionMedium())
                                    .foregroundColor(.white.opacity(0.2))
                                    .blur(radius: 1)
                                    .offset(x: -1, y: -1)
                            }
                            
                            Text(project.environment.displayName)
                                .font(.tomeTiny())
                                .foregroundColor(.white.opacity(0.5))
                                // Subtle glassmorphic effects for text
                                .shadow(color: .white.opacity(0.1), radius: 2, x: -1, y: -1)
                                .shadow(color: .black.opacity(0.2), radius: 2, x: 1, y: 1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .frame(width: 80, height: 60)
                }
            }
        }
    }
}

