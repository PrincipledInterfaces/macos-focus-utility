import SwiftUI

struct ContentView: View {
    @StateObject private var tomeState = TOMEState()
    @State private var currentEnvironment: TOMEEnvironment = .home
    @State private var selectedLeftApp: String? = nil
    @State private var selectedRightApp: String? = nil
    @State private var isTransitioning = false
    @State private var animationPhase: Double = 0
    @State private var animationScale: Double = 1.0
    @State private var animationOpacity: Double = 1.0
    @State private var showWaveAnimation = false
    @State private var waveCenter: CGPoint = .zero
    
    var body: some View {
        GeometryReader { geometry in
            mainContentView
        }
        .scaleEffect(animationScale)
        .opacity(animationOpacity)
        .background(Color.black)
        .ignoresSafeArea(.all)
        .overlay(waveAnimationOverlay)
        .overlay(globalAIOverlay)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animationScale)
        .animation(.easeInOut(duration: 0.4), value: animationOpacity)
    }
    
    @ViewBuilder
    private var mainContentView: some View {
        if currentEnvironment == .home {
            HomeView(
                onEnvironmentSelected: { environment, center in
                    selectEnvironmentWithWave(environment, waveCenter: center)
                },
                currentState: tomeState
            )
        } else {
            environmentSpecificView
        }
    }
    
    @ViewBuilder
    private var environmentSpecificView: some View {
        switch currentEnvironment {
        case .planning:
            PlanningView(
                currentState: tomeState,
                onNavigateHome: { selectEnvironment(.home) },
                onNavigateToEnvironment: { environment in selectEnvironment(environment) }
            )
        case .writerDesk:
            WriterDeskView(
                currentState: tomeState,
                onNavigateHome: { selectEnvironment(.home) }
            )
        case .workshop:
            WorkshopView(
                currentState: tomeState,
                onNavigateHome: { selectEnvironment(.home) }
            )
        case .coffeeshop:
            CoffeeshopView(
                currentState: tomeState,
                onNavigateHome: { selectEnvironment(.home) }
            )
        case .garden:
            GardenView(
                currentState: tomeState,
                onNavigateHome: { selectEnvironment(.home) }
            )
        case .home:
            HomeView(
                onEnvironmentSelected: { environment, center in
                    selectEnvironmentWithWave(environment, waveCenter: center)
                },
                currentState: tomeState
            )
        }
    }
    
    @ViewBuilder
    private var waveAnimationOverlay: some View {
        Group {
            if showWaveAnimation {
                ImpactfulWaveAnimationView(center: waveCenter, isActive: $showWaveAnimation)
                    .ignoresSafeArea(.all)
            }
        }
    }
    
    @ViewBuilder
    private var globalAIOverlay: some View {
        Group {
            if let globalAIAgent = tomeState.globalAIAgent {
                GlobalAIAssistant(aiAgent: globalAIAgent)
            }
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea(.all)
    }
    
    private var backgroundColors: [Color] {
        switch currentEnvironment {
        case .home:
            return [Color.black, Color.gray.opacity(0.1)]
        case .planning:
            return [Color.blue.opacity(0.1), Color.black]
        case .writerDesk:
            return [Color.green.opacity(0.1), Color.black]
        case .workshop:
            return [Color.purple.opacity(0.1), Color.black]
        case .coffeeshop:
            return [Color.orange.opacity(0.1), Color.black]
        case .garden:
            return [Color.green.opacity(0.2), Color.black]
        }
    }
    
    private func selectEnvironment(_ environment: TOMEEnvironment) {
        let screenFrame = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 800, height: 600)
        selectEnvironmentWithWave(environment, waveCenter: CGPoint(x: screenFrame.midX, y: screenFrame.midY))
    }
    
    private func selectEnvironmentWithWave(_ environment: TOMEEnvironment, waveCenter center: CGPoint) {
        guard environment != currentEnvironment else { return }
        
        print("Switching to environment: \(environment.displayName)")
        
        // Set wave center and start wave animation
        waveCenter = center
        
        // Start transition
        isTransitioning = true
        
        if environment == .home {
            // Zoom out animation (environment to home)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                animationScale = 0.8
                animationOpacity = 0.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                // Switch to home
                currentEnvironment = environment
                tomeState.switchToEnvironment(environment)
                
                // Zoom back to normal scale
                withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                    animationScale = 1.0
                    animationOpacity = 1.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    isTransitioning = false
                }
            }
        } else {
            // Start wave animation first
            withAnimation(.easeOut(duration: 0.8)) {
                showWaveAnimation = true
            }
            
            // Then zoom in animation (home to environment)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    animationScale = 1.2
                    animationOpacity = 0.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    // Switch to new environment
                    currentEnvironment = environment
                    tomeState.switchToEnvironment(environment)
                    showWaveAnimation = false
                    
                    // Scale back to normal
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                        animationScale = 1.0
                        animationOpacity = 1.0
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isTransitioning = false
                    }
                }
            }
        }
        
        print("Environment switch initiated for: \(environment.displayName)")
    }
    
}

