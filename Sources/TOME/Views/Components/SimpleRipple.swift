import SwiftUI

struct SimpleRipple: View {
    let center: CGPoint
    let isActive: Bool
    
    @State private var animationScale: CGFloat = 1
    @State private var animationOpacity: Double = 0.8
    
    var body: some View {
        ZStack {
            // Primary ripple wave
            Circle()
                .stroke(Color.cyan, lineWidth: 4)
                .frame(width: 100 * animationScale, height: 100 * animationScale)
                .opacity(animationOpacity)
                .position(center)
            
            // Secondary ripple wave
            Circle()
                .stroke(Color.cyan.opacity(0.6), lineWidth: 3)
                .frame(width: 80 * animationScale, height: 80 * animationScale)
                .opacity(animationOpacity * 0.7)
                .position(center)
            
            // Tertiary ripple wave
            Circle()
                .stroke(Color.cyan.opacity(0.3), lineWidth: 2)
                .frame(width: 60 * animationScale, height: 60 * animationScale)
                .opacity(animationOpacity * 0.5)
                .position(center)
        }
        .allowsHitTesting(false)
        .onChange(of: isActive) { _, newValue in
            if newValue {
                animationScale = 1
                animationOpacity = 0.8
                
                withAnimation(.easeOut(duration: 1.5)) {
                    animationScale = 8
                    animationOpacity = 0
                }
            }
        }
    }
}