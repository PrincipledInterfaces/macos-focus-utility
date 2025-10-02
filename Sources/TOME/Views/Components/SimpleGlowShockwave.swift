import SwiftUI

/// Simpler, smaller shockwave animation for workbench tools - just a growing glow without particles
struct SimpleGlowShockwave: View {
    let center: CGPoint
    let isActive: Bool
    let color: Color

    @State private var waveProgress: CGFloat = 0
    @State private var waveOpacity: Double = 1
    @State private var innerGlowScale: CGFloat = 1

    init(center: CGPoint, isActive: Bool, color: Color = .cyan) {
        self.center = center
        self.isActive = isActive
        self.color = color
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Central glow that pulses - brighter and bigger
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                color.opacity(1.0),
                                color.opacity(0.8),
                                color.opacity(0.4),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 150 * innerGlowScale
                        )
                    )
                    .frame(width: 300 * innerGlowScale, height: 300 * innerGlowScale)
                    .blur(radius: 30)
                    .position(center)

                // Expanding ring - more visible and bigger
                Circle()
                    .stroke(
                        RadialGradient(
                            colors: [
                                color.opacity(1.0),
                                color.opacity(0.8),
                                color.opacity(0.5),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 300 * waveProgress
                        ),
                        lineWidth: 6
                    )
                    .frame(width: 600 * waveProgress, height: 600 * waveProgress)
                    .blur(radius: 25)
                    .opacity(waveOpacity)
                    .position(center)

                // Outer glow ring - brighter and bigger
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                color.opacity(0.9),
                                color.opacity(0.6),
                                color.opacity(0.3),
                                .clear
                            ],
                            center: .center,
                            startRadius: 200 * waveProgress,
                            endRadius: 450 * waveProgress
                        )
                    )
                    .frame(width: 900 * waveProgress, height: 900 * waveProgress)
                    .blur(radius: 40)
                    .opacity(waveOpacity * 0.8)
                    .position(center)
            }
        }
        .drawingGroup() // GPU acceleration
        .onChange(of: isActive) { _, active in
            if active {
                startAnimation()
            } else {
                resetAnimation()
            }
        }
    }

    private func startAnimation() {
        waveProgress = 0
        waveOpacity = 1
        innerGlowScale = 1

        // Much slower expansion (1.8s total to match fade)
        withAnimation(.easeOut(duration: 1.8)) {
            waveProgress = 1.0
        }

        // Gradual fade away effect - starts halfway through
        withAnimation(.easeIn(duration: 1.0).delay(0.8)) {
            waveOpacity = 0
        }

        // Inner glow pulse - slower and bigger
        withAnimation(.easeInOut(duration: 1.4)) {
            innerGlowScale = 2.5
        }

        // Fade out inner glow at the end with smooth transition
        withAnimation(.easeInOut(duration: 0.6).delay(1.2)) {
            innerGlowScale = 0.3
        }
    }

    private func resetAnimation() {
        waveProgress = 0
        waveOpacity = 0
        innerGlowScale = 1
    }
}
