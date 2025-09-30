import SwiftUI

struct HomeView: View {
    let onEnvironmentSelected: (TOMEEnvironment, CGPoint) -> Void
    @ObservedObject var currentState: TOMEState
    
    @State private var selectedEnvironment: TOMEEnvironment = .planning
    @State private var rotationAngle: Double = 0
    @State private var isHovering = false
    
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
                // Simple door frame
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    .frame(width: 200, height: 300)
                
                // Inner glow when hovered
                RoundedRectangle(cornerRadius: 16)
                    .fill(selectedEnvironment.primaryColor.opacity(isHovering ? 0.05 : 0.02))
                    .frame(width: 200, height: 300)
                
                // Environment icon - centered and clean
                VStack(spacing: 16) {
                    Image(systemName: selectedEnvironment.icon)
                        .font(.tomeTitle().weight(.ultraLight))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("Enter")
                        .font(.tomeSmall())
                        .foregroundColor(.white.opacity(0.6))
                }
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
                onEnvironmentSelected(selectedEnvironment, center)
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
                    Button(action: {
                        selectedEnvironment = project.environment
                        // Use a default center position for recent tasks
                        onEnvironmentSelected(project.environment, CGPoint(x: 400, y: 300))
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: project.environment.icon)
                                .font(.tomeCaptionMedium())
                                .foregroundColor(project.environment.primaryColor)
                            
                            Text(project.environment.displayName)
                                .font(.tomeTiny())
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(project.environment.primaryColor.opacity(0.1))
                                .stroke(project.environment.primaryColor.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}

