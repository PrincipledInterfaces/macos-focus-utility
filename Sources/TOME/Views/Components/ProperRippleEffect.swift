import SwiftUI

/// A proper ripple effect using Core Animation layers for maximum performance
struct ProperRippleEffect: View {
    let center: CGPoint
    let isActive: Bool
    let maxRadius: CGFloat
    let duration: Double
    let color: Color
    
    @State private var animationRadius: CGFloat = 0
    @State private var animationOpacity: Double = 1
    
    init(
        center: CGPoint,
        isActive: Bool,
        maxRadius: CGFloat = 800,
        duration: Double = 2.0,
        color: Color = .white
    ) {
        self.center = center
        self.isActive = isActive
        self.maxRadius = maxRadius
        self.duration = duration
        self.color = color
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Multiple ripple rings for better effect
                ForEach(0..<3, id: \.self) { ringIndex in
                    Circle()
                        .stroke(
                            color.opacity(animationOpacity * (1.0 - Double(ringIndex) * 0.3)),
                            lineWidth: 4 - CGFloat(ringIndex)
                        )
                        .frame(
                            width: animationRadius * (1.0 - CGFloat(ringIndex) * 0.2),
                            height: animationRadius * (1.0 - CGFloat(ringIndex) * 0.2)
                        )
                        .position(center)
                        .animation(
                            .easeOut(duration: duration + Double(ringIndex) * 0.2),
                            value: animationRadius
                        )
                        .animation(
                            .easeInOut(duration: duration * 0.8),
                            value: animationOpacity
                        )
                }
                
                // Central expanding circle with fill
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                color.opacity(animationOpacity * 0.6),
                                color.opacity(animationOpacity * 0.3),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: animationRadius * 0.5
                        )
                    )
                    .frame(width: animationRadius, height: animationRadius)
                    .position(center)
                    .animation(.easeOut(duration: duration), value: animationRadius)
                    .animation(.easeInOut(duration: duration * 0.6), value: animationOpacity)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: isActive) { _, newValue in
            if newValue {
                startRipple()
            } else {
                resetRipple()
            }
        }
    }
    
    private func startRipple() {
        // Reset first
        animationRadius = 0
        animationOpacity = 1
        
        // Animate expansion
        withAnimation(.easeOut(duration: duration)) {
            animationRadius = maxRadius
        }
        
        // Fade out during expansion
        withAnimation(.easeInOut(duration: duration * 0.8)) {
            animationOpacity = 0
        }
    }
    
    private func resetRipple() {
        animationRadius = 0
        animationOpacity = 1
    }
}

/// Modern shockwave effect with particle-like elements
struct ModernShockwave: View {
    let center: CGPoint
    let isActive: Bool
    let color: Color
    
    @State private var waveRadius: CGFloat = 0
    @State private var waveOpacity: Double = 1
    @State private var particleScale: CGFloat = 0
    @State private var particleRotation: Double = 0
    
    init(center: CGPoint, isActive: Bool, color: Color = .cyan) {
        self.center = center
        self.isActive = isActive
        self.color = color
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main shockwave ring
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                color.opacity(waveOpacity),
                                color.opacity(waveOpacity * 0.5),
                                Color.clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 6
                    )
                    .frame(width: waveRadius * 2, height: waveRadius * 2)
                    .position(center)
                
                // Secondary wave
                Circle()
                    .stroke(
                        color.opacity(waveOpacity * 0.4),
                        lineWidth: 2
                    )
                    .frame(width: waveRadius * 1.5, height: waveRadius * 1.5)
                    .position(center)
                
                // Particle effect around the center
                ForEach(0..<12, id: \.self) { index in
                    Circle()
                        .fill(color.opacity(waveOpacity * 0.8))
                        .frame(width: 4, height: 4)
                        .position(
                            x: center.x + cos(Double(index) * .pi / 6 + particleRotation) * Double(particleScale) * 40,
                            y: center.y + sin(Double(index) * .pi / 6 + particleRotation) * Double(particleScale) * 40
                        )
                        .scaleEffect(particleScale)
                }
                
                // Central burst
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                color.opacity(waveOpacity),
                                color.opacity(waveOpacity * 0.5),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 30
                        )
                    )
                    .frame(width: 60, height: 60)
                    .position(center)
                    .scaleEffect(particleScale)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: isActive) { _, newValue in
            if newValue {
                startShockwave()
            } else {
                resetShockwave()
            }
        }
    }
    
    private func startShockwave() {
        // Reset all values
        waveRadius = 0
        waveOpacity = 1
        particleScale = 0
        particleRotation = 0
        
        // Animate the main wave expansion
        withAnimation(.easeOut(duration: 2.0)) {
            waveRadius = 400
        }
        
        // Fade out the wave
        withAnimation(.easeInOut(duration: 1.6)) {
            waveOpacity = 0
        }
        
        // Animate particles
        withAnimation(.easeOut(duration: 1.5)) {
            particleScale = 1.0
        }
        
        // Rotate particles
        withAnimation(.linear(duration: 2.0)) {
            particleRotation = .pi * 2
        }
    }
    
    private func resetShockwave() {
        waveRadius = 0
        waveOpacity = 1
        particleScale = 0
        particleRotation = 0
    }
}

/// Ultra-smooth ripple using path-based animation
struct UltraSmoothRipple: View {
    let center: CGPoint
    let isActive: Bool
    
    @State private var animationProgress: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Only draw if animation is active
                guard animationProgress > 0 else { return }
                
                let maxRadius: CGFloat = 600
                let currentRadius = maxRadius * animationProgress
                let opacity = 1.0 - animationProgress
                
                // Draw multiple concentric rings
                for ringIndex in 0..<4 {
                    let ringRadius = currentRadius * (1.0 - CGFloat(ringIndex) * 0.15)
                    let ringOpacity = opacity * (1.0 - CGFloat(ringIndex) * 0.2)
                    
                    if ringRadius > 0 {
                        context.stroke(
                            Path { path in
                                path.addEllipse(in: CGRect(
                                    x: center.x - ringRadius,
                                    y: center.y - ringRadius,
                                    width: ringRadius * 2,
                                    height: ringRadius * 2
                                ))
                            },
                            with: .color(.white.opacity(ringOpacity)),
                            lineWidth: 3
                        )
                    }
                }
                
                // Central glow
                let glowRadius = currentRadius * 0.3
                context.fill(
                    Path { path in
                        path.addEllipse(in: CGRect(
                            x: center.x - glowRadius,
                            y: center.y - glowRadius,
                            width: glowRadius * 2,
                            height: glowRadius * 2
                        ))
                    },
                    with: .radialGradient(
                        Gradient(colors: [
                            .white.opacity(opacity * 0.6),
                            .white.opacity(opacity * 0.3),
                            .clear
                        ]),
                        center: CGPoint(x: center.x, y: center.y),
                        startRadius: 0,
                        endRadius: glowRadius
                    )
                )
            }
        }
        .allowsHitTesting(false)
        .onChange(of: isActive) { _, newValue in
            if newValue {
                startUltraSmoothRipple()
            } else {
                resetRipple()
            }
        }
    }
    
    private func startUltraSmoothRipple() {
        animationProgress = 0
        
        withAnimation(.easeOut(duration: 2.0)) {
            animationProgress = 1.0
        }
    }
    
    private func resetRipple() {
        animationProgress = 0
    }
}

/// Combined effects view that layers multiple ripple types
struct CombinedRippleEffects: View {
    let center: CGPoint
    let isActive: Bool
    
    var body: some View {
        ZStack {
            // Ultra-smooth base ripple
            UltraSmoothRipple(center: center, isActive: isActive)
            
            // Modern shockwave overlay
            ModernShockwave(center: center, isActive: isActive, color: .cyan)
                .opacity(0.7)
            
            // Additional ripple rings
            ProperRippleEffect(
                center: center,
                isActive: isActive,
                maxRadius: 500,
                duration: 1.8,
                color: .white
            )
            .opacity(0.5)
        }
    }
}