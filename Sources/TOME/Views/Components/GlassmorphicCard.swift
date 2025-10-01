import SwiftUI

/// Enhanced glassmorphic design with prominent fade effects
struct GlassmorphicCard<Content: View>: View {
    let content: Content
    let blurRadius: CGFloat
    let cornerRadius: CGFloat
    let opacity: CGFloat
    let intensity: GlassIntensity
    
    enum GlassIntensity {
        case subtle, prominent, dramatic
        
        var backgroundOpacity: Double {
            switch self {
            case .subtle: return 0.15
            case .prominent: return 0.35
            case .dramatic: return 0.55
            }
        }
        
        var borderOpacity: Double {
            switch self {
            case .subtle: return 0.2
            case .prominent: return 0.4
            case .dramatic: return 0.6
            }
        }
        
        var shadowRadius: CGFloat {
            switch self {
            case .subtle: return 15
            case .prominent: return 30
            case .dramatic: return 50
            }
        }
    }
    
    init(
        blurRadius: CGFloat = 20,
        cornerRadius: CGFloat = 20,
        opacity: CGFloat = 0.3,
        intensity: GlassIntensity = .prominent,
        @ViewBuilder content: () -> Content
    ) {
        self.blurRadius = blurRadius
        self.cornerRadius = cornerRadius
        self.opacity = opacity
        self.intensity = intensity
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            // Prominent backdrop blur
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(intensity.backgroundOpacity),
                                    Color.white.opacity(intensity.backgroundOpacity * 0.7),
                                    Color.white.opacity(intensity.backgroundOpacity * 0.4),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blur(radius: blurRadius)
                )
            
            // Glass surface with enhanced gradients
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.white.opacity(intensity.backgroundOpacity), location: 0.0),
                            .init(color: Color.white.opacity(intensity.backgroundOpacity * 0.8), location: 0.3),
                            .init(color: Color.white.opacity(intensity.backgroundOpacity * 0.5), location: 0.7),
                            .init(color: Color.white.opacity(intensity.backgroundOpacity * 0.2), location: 1.0)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    // Shimmer effect
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(intensity.borderOpacity),
                                    Color.cyan.opacity(intensity.borderOpacity * 0.8),
                                    Color.white.opacity(intensity.borderOpacity * 0.6),
                                    Color.clear
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: Color.black.opacity(0.4),
                    radius: intensity.shadowRadius,
                    x: 0,
                    y: intensity.shadowRadius * 0.3
                )
                .shadow(
                    color: Color.cyan.opacity(0.2),
                    radius: intensity.shadowRadius * 0.5,
                    x: 0,
                    y: 0
                )
            
            // Content
            content
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

/// Glassmorphic button for interactive elements
struct GlassmorphicButton<Content: View>: View {
    let action: () -> Void
    let content: Content
    @State private var isPressed = false
    
    init(action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.action = action
        self.content = content()
    }
    
    var body: some View {
        Button(action: action) {
            GlassmorphicCard(
                blurRadius: 15,
                cornerRadius: 16,
                opacity: isPressed ? 0.5 : 0.3
            ) {
                content
                    .scaleEffect(isPressed ? 0.95 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isPressed)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }
}

/// Glassmorphic icon container for large icons
struct GlassmorphicIcon: View {
    let systemName: String
    let size: CGFloat
    let color: Color
    
    init(_ systemName: String, size: CGFloat = 40, color: Color = .white) {
        self.systemName = systemName
        self.size = size
        self.color = color
    }
    
    var body: some View {
        GlassmorphicCard(
            blurRadius: 12,
            cornerRadius: 12,
            opacity: 0.25
        ) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .medium))
                .foregroundColor(color)
                .padding(16)
        }
        .frame(width: size + 32, height: size + 32)
    }
}

/// Environment card with glassmorphic design
struct GlassmorphicEnvironmentCard: View {
    let title: String
    let description: String
    let systemName: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        GlassmorphicButton(action: action) {
            VStack(spacing: 16) {
                GlassmorphicIcon(systemName, size: 60, color: color)
                
                VStack(spacing: 8) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .padding(24)
        }
        .frame(width: 200, height: 240)
    }
}

/// Glassmorphic navigation bar
struct GlassmorphicNavigationBar<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        GlassmorphicCard(
            blurRadius: 25,
            cornerRadius: 16,
            opacity: 0.4
        ) {
            HStack {
                content
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(height: 60)
    }
}