import SwiftUI

struct GlobalAIAssistant: View {
    @ObservedObject var aiAgent: GlobalAIAgent
    @State private var showChatWindow = false
    @State private var userMessage = ""
    @State private var isProcessing = false
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                // AI Assistant Button
                Button(action: { showChatWindow.toggle() }) {
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
            
            if showChatWindow {
                aiChatWindow
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
            
            Spacer()
        }
        .padding(.trailing, 20)
        .animation(.easeInOut(duration: 0.3), value: showChatWindow)
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
                    break
                case .failure(let error):
                    print("AI message error: \(error)")
                    // Could show error message in chat
                }
            }
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