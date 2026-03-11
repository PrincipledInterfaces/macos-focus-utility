import SwiftUI

struct GlobalAIAssistant: View {
    @ObservedObject var aiAgent: GlobalAIAgent
    @State private var showChatWindow = false
    @State private var userMessage = ""
    @State private var isProcessing = false
    @State private var notificationObserver: NSObjectProtocol?
    @ObservedObject private var hudSettings = HUDProjectorSettings.shared
    @ObservedObject private var hudService = HUDProjectorService.shared

    var body: some View {
        VStack {
            HStack {
                Spacer()

                // AI Assistant Button
                Button(action: {
                    showChatWindow.toggle()
                    updateHUDChat()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: showChatWindow ? "brain.head.profile.fill" : "brain.head.profile")
                            .font(.system(size: 14, weight: .medium))
                        
                        if !showChatWindow && !aiAgent.suggestions.isEmpty {
                            Text("\(aiAgent.suggestions.count)")
                                .font(.tomeTinyMedium())
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(
                                    Circle()
                                        .fill(.red.opacity(0.8))
                                )
                        }
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .keyboardShortcut("a", modifiers: [.command])
            }
            
            // Only show in-app chat window if HUD is NOT enabled
            if showChatWindow && !shouldUseHUD {
                aiChatWindow
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
            
            Spacer()
        }
        .padding(.trailing, 20)
        .animation(.easeInOut(duration: 0.3), value: showChatWindow)
        .onAppear {
            // Only setup observer if not already set up
            if notificationObserver == nil {
                print("🔧 GlobalAIAssistant: Setting up notification observer")
                notificationObserver = NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("ToggleAIChat"),
                    object: nil,
                    queue: .main
                ) { _ in
                    print("🤖 Toggle AI notification received")
                    showChatWindow.toggle()
                    updateHUDChat()
                    print("🤖 AI window now: \(showChatWindow)")
                }
            } else {
                print("🔧 GlobalAIAssistant: Observer already exists, skipping setup")
            }
        }
        .onDisappear {
            print("🧹 GlobalAIAssistant: onDisappear called - removing notification observer")
            if let observer = notificationObserver {
                NotificationCenter.default.removeObserver(observer)
                notificationObserver = nil
            }
        }
    }
    
    private var aiChatWindow: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Assistant")
                        .font(.tomeBodyMedium())
                        .foregroundColor(.white)
                    
                    Text("⌘A to toggle • Ask anything")
                        .font(.tomeTiny())
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                Button(action: { showChatWindow = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(12)
            .background(.ultraThinMaterial)
            
            Divider()
                .background(.white.opacity(0.1))
            
            // Suggestions Section
            if !aiAgent.suggestions.isEmpty {
                suggestionsList
            }
            
            // Chat History
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(aiAgent.conversationHistory.enumerated()), id: \.offset) { index, message in
                            chatMessageView(message)
                                .id(index)
                        }

                        // Thinking animation when processing
                        if isProcessing {
                            thinkingIndicator
                                .id("thinking")
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .frame(height: 200)
                .onChange(of: aiAgent.conversationHistory.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo(aiAgent.conversationHistory.count - 1)
                    }
                }
                .onChange(of: isProcessing) { _, newValue in
                    if newValue {
                        withAnimation {
                            proxy.scrollTo("thinking")
                        }
                    }
                }
            }
            
            Divider()
                .background(.white.opacity(0.1))
            
            // Input Area
            HStack(spacing: 8) {
                TextField("Ask anything...", text: $userMessage)
                    .font(.tomeCaption())
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit {
                        sendMessage()
                    }
                
                Button(action: sendMessage) {
                    Image(systemName: isProcessing ? "hourglass" : "paperplane.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(isProcessing ? 0.5 : 0.8))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isProcessing || userMessage.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.black.opacity(0.3))
        }
        .frame(width: 320)
        .background(.black.opacity(0.8))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.5), radius: 20)
    }
    
    private var suggestionsList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Suggestions")
                .font(.tomeSmallLabelMedium())
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.top, 8)
            
            ForEach(aiAgent.suggestions.prefix(3)) { suggestion in
                suggestionCard(suggestion)
            }
            
            Divider()
                .background(.white.opacity(0.1))
                .padding(.horizontal, 12)
        }
    }
    
    private func suggestionCard(_ suggestion: AIAgentSuggestion) -> some View {
        Button(action: {
            if let action = suggestion.action {
                aiAgent.executeAction(action)
            }
        }) {
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.title)
                    .font(.tomeSmallLabelMedium())
                    .foregroundColor(.white)
                
                Text(suggestion.description)
                    .font(.tomeTiny())
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(suggestionColor(suggestion.type).opacity(0.1))
                    .stroke(suggestionColor(suggestion.type).opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 12)
    }
    
    private var thinkingIndicator: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                SineWaveThinking(color: environmentColor())
                    .frame(width: 50, height: 20)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.white.opacity(0.05))
                    )
            }

            Spacer()
        }
    }

    private func environmentColor() -> Color {
        switch aiAgent.currentEnvironment {
        case .planning:
            return .blue
        case .writerDesk:
            return .green
        case .workshop:
            return .purple
        case .coffeeshop:
            return .orange
        case .garden:
            return .green
        case .home:
            return .white
        }
    }

    private func chatMessageView(_ message: AIMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .user {
                Spacer()
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.tomeSmallLabel())
                    .foregroundColor(.white)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(message.role == .user ? .blue.opacity(0.2) : .white.opacity(0.1))
                    )

                // Action indicators (small text below AI messages)
                if message.role == .assistant, let indicators = message.actionIndicators, !indicators.isEmpty {
                    Text(indicators.joined(separator: " • "))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.top, 2)
                }

                Text(formatTime(message.timestamp))
                    .font(.tomeTiny())
                    .foregroundColor(.white.opacity(0.5))
            }

            if message.role == .assistant {
                Spacer()
            }
        }
    }
    
    private func sendMessage() {
        guard !userMessage.isEmpty else { return }

        let message = userMessage
        userMessage = ""
        isProcessing = true

        aiAgent.sendMessage(message) { result in
            DispatchQueue.main.async {
                isProcessing = false
                switch result {
                case .success:
                    // Message added to conversation history by the agent
                    // Update HUD if active
                    self.updateHUDChat()
                    break
                case .failure(let error):
                    print("AI message error: \(error)")
                    // Could show error message in chat
                }
            }
        }
    }

    // MARK: - HUD Integration

    private var shouldUseHUD: Bool {
        return hudSettings.isEnabled && hudSettings.isCalibrated && hudService.isActive
    }

    private func updateHUDChat() {
        guard shouldUseHUD else { return }

        if showChatWindow {
            // Convert AI conversation to ChatMessage format
            let messages = aiAgent.conversationHistory.suffix(5).map { aiMessage in
                ChatMessage(
                    role: aiMessage.role == .user ? "user" : "assistant",
                    content: aiMessage.content
                )
            }

            let frontEdgeCenter = hudSettings.frontEdgeCenter
            let angle = hudSettings.frontEdgeAngle

            // Position chat perpendicular to front edge, away from TOME
            let distance: CGFloat = 200
            let perpAngle = angle - .pi / 2
            let offsetX = cos(perpAngle) * distance
            let offsetY = sin(perpAngle) * distance

            let content = HUDContent(
                type: .aiChat(messages: Array(messages)),
                position: CGPoint(x: frontEdgeCenter.x + offsetX, y: frontEdgeCenter.y + offsetY),
                size: CGSize(width: 700, height: 500),
                rotation: angle
            )

            hudService.showContent(content)
        } else {
            // Hide HUD chat when toggled off
            hudService.hideContent()
        }
    }
    
    private func suggestionColor(_ type: AIAgentSuggestion.SuggestionType) -> Color {
        switch type {
        case .welcome: return .blue
        case .productivity: return .green
        case .focus: return .purple  
        case .wellbeing: return .mint
        case .learning: return .orange
        case .communication: return .indigo
        case .navigation: return .gray
        case .celebration: return .yellow
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Quick Actions Extension
extension GlobalAIAssistant {
    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Quick Actions")
                .font(.tomeSmallLabelMedium())
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 12)
            
            HStack(spacing: 8) {
                quickActionButton("Add Task", icon: "plus.circle") {
                    userMessage = "Create a new todo: "
                }
                
                quickActionButton("Analyze", icon: "chart.line.uptrend.xyaxis") {
                    aiAgent.executeAction(AIAgentAction(type: .analyzeTodos, parameters: [:]))
                }
                
                quickActionButton("Break", icon: "leaf") {
                    aiAgent.executeAction(AIAgentAction(type: .suggestBreak, parameters: [:]))
                }
            }
            .padding(.horizontal, 12)
        }
    }
    
    private func quickActionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .medium))
                Text(title)
                    .font(.tomeTinyMedium())
            }
            .foregroundColor(.white.opacity(0.8))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(.white.opacity(0.1))
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Sine Wave Thinking Animation
struct SineWaveThinking: View {
    let color: Color
    @State private var phase: CGFloat = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let timeOffset = timeline.date.timeIntervalSinceReferenceDate
                let animatedPhase = CGFloat(timeOffset * 2.0).truncatingRemainder(dividingBy: 2 * .pi)

                var path = Path()
                let midHeight = size.height / 2
                let amplitude = size.height / 3

                path.move(to: CGPoint(x: 0, y: midHeight))

                // Create smooth sine wave
                for x in stride(from: 0, through: size.width, by: 0.5) {
                    let relativeX = x / size.width
                    let sine = sin((relativeX * 4 * .pi) - animatedPhase)
                    let y = midHeight + (sine * amplitude)
                    path.addLine(to: CGPoint(x: x, y: y))
                }

                // Draw the wave with glow effect
                context.stroke(
                    path,
                    with: .color(color.opacity(0.9)),
                    lineWidth: 2.5
                )

                // Add glow
                context.stroke(
                    path,
                    with: .color(color.opacity(0.3)),
                    lineWidth: 6
                )
            }
        }
    }
}