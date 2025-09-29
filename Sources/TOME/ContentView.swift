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
    
    var body: some View {
        GeometryReader { geometry in
            if currentEnvironment == .home {
                // Home view - environment selection
                HomeView(
                    onEnvironmentSelected: selectEnvironment,
                    currentState: tomeState
                )
            } else {
                // Environment-specific views
                switch currentEnvironment {
                case .planning:
                    PlanningView(
                        currentState: tomeState,
                        onNavigateHome: { selectEnvironment(.home) }
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
                    // This case shouldn't happen but included for completeness
                    HomeView(
                        onEnvironmentSelected: selectEnvironment,
                        currentState: tomeState
                    )
                }
            }
        }
        .scaleEffect(animationScale)
        .opacity(animationOpacity)
        .background(Color.black)
        .ignoresSafeArea(.all)
        .overlay(
            // Global AI Assistant - available in all environments
            Group {
                if let globalAIAgent = tomeState.globalAIAgent {
                    GlobalAIAssistant(aiAgent: globalAIAgent)
                }
            }
        )
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animationScale)
        .animation(.easeInOut(duration: 0.4), value: animationOpacity)
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
        guard environment != currentEnvironment else { return }
        
        print("Switching to environment: \(environment.displayName)")
        
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
            // Zoom in animation (home to environment)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                animationScale = 1.2
                animationOpacity = 0.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                // Switch to new environment
                currentEnvironment = environment
                tomeState.switchToEnvironment(environment)
                
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
        
        print("Environment switch initiated for: \(environment.displayName)")
    }
    
}

