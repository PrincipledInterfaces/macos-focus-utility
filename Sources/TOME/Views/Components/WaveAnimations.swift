import SwiftUI

// MARK: - Organic Shockwave Animation

struct ImpactfulWaveAnimationView: View {
    let center: CGPoint
    @Binding var isActive: Bool
    @State private var animationRadius: CGFloat = 50
    @State private var animationOpacity: Double = 0.0
    
    var body: some View {
        ZStack {
            if isActive {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(
                            Color.white.opacity(animationOpacity * (1.0 - Double(index) * 0.3)),
                            lineWidth: max(1, 15 - animationRadius / 60)
                        )
                        .frame(width: animationRadius, height: animationRadius)
                        .position(center)
                        .scaleEffect(1.0 + Double(index) * 0.2)
                        .animation(
                            .easeOut(duration: 2.0)
                            .delay(Double(index) * 0.2), 
                            value: animationRadius
                        )
                        .animation(
                            .easeOut(duration: 1.5)
                            .delay(0.5 + Double(index) * 0.2), 
                            value: animationOpacity
                        )
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: isActive) { _, active in
            if active {
                startRipple()
            } else {
                resetRipple()
            }
        }
    }
    
    private func startRipple() {
        print("🌊 Starting ripple animation at center: \(center)")
        // Start from small size and full opacity
        animationRadius = 50
        animationOpacity = 1.0
        
        // Animate to large size and fade out
        withAnimation(.easeOut(duration: 2.0)) {
            animationRadius = 800
        }
        
        withAnimation(.easeOut(duration: 1.8).delay(0.2)) {
            animationOpacity = 0.0
        }
    }
    
    private func resetRipple() {
        print("🌊 Resetting ripple animation")
        animationRadius = 50
        animationOpacity = 0.0
    }
}

// MARK: - Wave Ring Component

struct WaveRing: View {
    let center: CGPoint
    let radius: CGFloat
    let opacity: Double
    let lineWidth: CGFloat
    let scale: Double
    let index: Int
    
    var body: some View {
        Circle()
            .stroke(
                RadialGradient(
                    colors: [
                        Color.white.opacity(opacity * 0.9),
                        Color.cyan.opacity(opacity * 0.6),
                        Color.purple.opacity(opacity * 0.4),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 50
                ),
                lineWidth: lineWidth
            )
            .frame(width: radius, height: radius)
            .position(center)
            .opacity(opacity)
            .scaleEffect(scale)
    }
}

// MARK: - Organic Wave Shape

struct OrganicWaveShape: Shape {
    let radius: CGFloat
    let distortion: CGFloat
    let animationPhase: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        
        // Create organic wave with noise-based distortion
        let numPoints = 64
        let angleStep = 2 * .pi / Double(numPoints)
        
        var points: [CGPoint] = []
        
        for i in 0..<numPoints {
            let angle = Double(i) * angleStep
            
            // Create organic distortion using multiple sine waves
            let noise1 = sin(angle * 3.0 + Double(animationPhase)) * 0.3
            let noise2 = sin(angle * 7.0 - Double(animationPhase) * 0.7) * 0.2
            let noise3 = cos(angle * 5.0 + Double(animationPhase) * 1.3) * 0.15
            
            let organicDistortion = distortion * (noise1 + noise2 + noise3)
            let distortedRadius = radius + organicDistortion
            
            let x = center.x + cos(angle) * distortedRadius
            let y = center.y + sin(angle) * distortedRadius
            
            points.append(CGPoint(x: x, y: y))
        }
        
        // Create smooth path through all points
        if !points.isEmpty {
            path.move(to: points[0])
            
            for i in 1..<points.count {
                let current = points[i]
                let previous = points[i - 1]
                let next = points[(i + 1) % points.count]
                
                // Create smooth curves using control points
                let controlPoint1 = CGPoint(
                    x: previous.x + (current.x - previous.x) * 0.3,
                    y: previous.y + (current.y - previous.y) * 0.3
                )
                let controlPoint2 = CGPoint(
                    x: current.x - (next.x - current.x) * 0.3,
                    y: current.y - (next.y - current.y) * 0.3
                )
                
                path.addCurve(to: current, control1: controlPoint1, control2: controlPoint2)
            }
            
            // Close the path smoothly
            let first = points[0]
            let last = points[points.count - 1]
            let _ = points[points.count - 2]
            let second = points[1]
            
            let controlPoint1 = CGPoint(
                x: last.x + (first.x - last.x) * 0.3,
                y: last.y + (first.y - last.y) * 0.3
            )
            let controlPoint2 = CGPoint(
                x: first.x - (second.x - first.x) * 0.3,
                y: first.y - (second.y - first.y) * 0.3
            )
            
            path.addCurve(to: first, control1: controlPoint1, control2: controlPoint2)
        }
        
        return path
    }
}