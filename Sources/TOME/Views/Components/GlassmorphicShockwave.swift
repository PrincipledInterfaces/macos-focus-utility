import SwiftUI

/// Full-screen glassmorphic shockwave effect that expands organically
struct GlassmorphicShockwave: View {
    let center: CGPoint
    let isActive: Bool
    let color: Color

    @State private var waveProgress: CGFloat = 0
    @State private var waveOpacity: Double = 1
    @State private var innerGlowScale: CGFloat = 1
    @State private var particleRotation: Double = 0

    init(center: CGPoint, isActive: Bool, color: Color = .cyan) {
        self.center = center
        self.isActive = isActive
        self.color = color
    }

    var body: some View {
        GeometryReader { geometry in
            let screenSize = max(geometry.size.width, geometry.size.height)
            let maxRadius = screenSize * 1.5

            ZStack {
                // Main expanding waves
                expandingWaves(maxRadius: maxRadius)

                // Central glow and particles
                centralEffects(maxRadius: maxRadius)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            if isActive {
                // Small delay to ensure view is fully rendered
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    startShockwave()
                }
            }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                // Small delay to ensure smooth transition
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    startShockwave()
                }
            } else {
                resetShockwave()
            }
        }
    }

    private func expandingWaves(maxRadius: CGFloat) -> some View {
        ZStack {
            // Main expanding glassmorphic wave rings (reduced from 5 to 3 for performance)
            ForEach(0..<3, id: \.self) { ringIndex in
                waveRing(index: ringIndex, maxRadius: maxRadius)
            }

            // Organic radial gradient fill (reduced blur for performance)
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.white.opacity(waveOpacity * 0.4), location: 0.0),
                            .init(color: color.opacity(waveOpacity * 0.3), location: 0.3),
                            .init(color: color.opacity(waveOpacity * 0.15), location: 0.6),
                            .init(color: Color.clear, location: 1.0)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: maxRadius * waveProgress
                    )
                )
                .frame(width: maxRadius * 2 * waveProgress, height: maxRadius * 2 * waveProgress)
                .position(center)
                .blur(radius: 4)
        }
    }

    private func waveRing(index: Int, maxRadius: CGFloat) -> some View {
        let ringIndex = CGFloat(index)
        let ringOpacity = waveOpacity * (1.0 - ringIndex * 0.2)

        return Circle()
            .stroke(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(ringOpacity),
                        color.opacity(ringOpacity * 0.6),
                        color.opacity(ringOpacity * 0.3),
                        Color.clear
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                style: StrokeStyle(
                    lineWidth: 10 - ringIndex * 2,
                    lineCap: .round
                )
            )
            .frame(
                width: maxRadius * 2 * waveProgress * (1.0 - ringIndex * 0.15),
                height: maxRadius * 2 * waveProgress * (1.0 - ringIndex * 0.15)
            )
            .position(center)
            .blur(radius: 1.5)
            .drawingGroup() // GPU acceleration for smooth rendering
    }

    private func centralEffects(maxRadius: CGFloat) -> some View {
        ZStack {
            // Inner glow (reduced blur)
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(waveOpacity * 0.8),
                            color.opacity(waveOpacity * 0.5),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 100 * innerGlowScale
                    )
                )
                .frame(width: 200 * innerGlowScale, height: 200 * innerGlowScale)
                .position(center)
                .blur(radius: 12)
                .drawingGroup()

            // Reduced particles for performance (12 instead of 24)
            ForEach(0..<12, id: \.self) { index in
                particleView(index: index, distance: 100 + waveProgress * 200, size: 12, rotation: particleRotation)
            }

            // Reduced outer particles (8 instead of 16)
            ForEach(0..<8, id: \.self) { index in
                particleView(index: index, distance: 150 + waveProgress * 300, size: 6, rotation: -particleRotation * 0.5)
            }

            // Glassmorphic blur overlay (reduced blur radius)
            Circle()
                .fill(Color.white.opacity(0.02))
                .frame(width: maxRadius * 2 * waveProgress * 0.8, height: maxRadius * 2 * waveProgress * 0.8)
                .position(center)
                .blur(radius: 20)
                .opacity(waveOpacity)
                .drawingGroup()
        }
    }

    private func particleView(index: Int, distance: CGFloat, size: CGFloat, rotation: Double) -> some View {
        let angle = Double(index) * .pi / (size > 10 ? 6 : 4) + rotation

        return Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(waveOpacity * 0.8),
                        color.opacity(waveOpacity * 0.4),
                        Color.clear
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: size / 2
                )
            )
            .frame(width: size, height: size)
            .position(
                x: center.x + cos(angle) * distance,
                y: center.y + sin(angle) * distance
            )
            .blur(radius: 1.5)
            .opacity(waveOpacity * 0.6)
            .drawingGroup()
    }

    private func startShockwave() {
        print("🌊 Starting glassmorphic shockwave animation at center: \(center)")

        // Ensure we're on main thread
        DispatchQueue.main.async {
            // Reset all animation values immediately (no animation)
            self.waveProgress = 0
            self.waveOpacity = 1
            self.innerGlowScale = 1
            self.particleRotation = 0

            // Small delay before starting animations to ensure reset is complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                print("🌊 Animating wave expansion...")

                // Main wave expansion - smooth and organic
                withAnimation(.easeOut(duration: 2.0)) {
                    self.waveProgress = 1.0
                }

                // Fade out during expansion
                withAnimation(.easeIn(duration: 1.6).delay(0.2)) {
                    self.waveOpacity = 0
                }

                // Inner glow pulse
                withAnimation(.easeInOut(duration: 1.0)) {
                    self.innerGlowScale = 2.5
                }

                // Particle rotation for organic movement
                withAnimation(.linear(duration: 2.0)) {
                    self.particleRotation = .pi * 1.5
                }
            }
        }
    }

    private func resetShockwave() {
        waveProgress = 0
        waveOpacity = 1
        innerGlowScale = 1
        particleRotation = 0
    }
}
