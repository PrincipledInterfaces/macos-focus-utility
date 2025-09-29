import SwiftUI
import UserNotifications

struct AIChatWindow: View {
    @ObservedObject var aiService: OpenAIService
    @ObservedObject var currentState: TOMEState
    let onDismiss: () -> Void
    
    @State private var messages: [ChatMessage] = []
    @State private var currentInput = ""
    @State private var isProcessing = false
    @State private var scrollProxy: ScrollViewProxy?
    @State private var activeReminders: [TOMEReminder] = []
    
    var body: some View {
        ZStack {
            // Background with subtle pattern
            LinearGradient(
                colors: [
                    Color.black,
                    Color.blue.opacity(0.1),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(.all)
            
            VStack(spacing: 0) {
                // Header
                chatHeader
                
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(messages.indices, id: \.self) { index in
                                MessageBubble(
                                    message: messages[index],
                                    isUser: messages[index].role == "user"
                                )
                                .id(index)
                            }
                            
                            if isProcessing {
                                typingIndicator
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                    }
                    .onAppear {
                        scrollProxy = proxy
                        initializeChat()
                    }
                    .onChange(of: messages.count) { _ in
                        scrollToBottom()
                    }
                }
                
                // Input area
                chatInputArea
            }
        }
        .frame(width: 800, height: 600)
    }
    
    private var chatHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("TOME AI Assistant")
                    .font(.tomeSubheading())
                    .foregroundColor(.white)
                
                Text("System Integration & Focus Management")
                    .font(.tomeCaption())
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            Button(action: { onDismiss() }) {
                Image(systemName: "xmark")
                    .font(.tomeSmallMedium())
                    .foregroundColor(.white.opacity(0.8))
                    .padding(8)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.3))
                .ignoresSafeArea(.all, edges: .top)
        )
    }
    
    private var chatInputArea: some View {
        VStack(spacing: 12) {
            // System commands info
            if messages.isEmpty || messages.count < 3 {
                systemCommandsInfo
            }
            
            // Input field
            HStack(spacing: 12) {
                TextField("Type your message or command...", text: $currentInput, axis: .vertical)
                    .font(.tomeBody())
                    .foregroundColor(.white)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.05))
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .onSubmit {
                        sendMessage()
                    }
                
                Button(action: sendMessage) {
                    Image(systemName: isProcessing ? "stop.circle" : "arrow.up.circle.fill")
                        .font(.tomeSubheading())
                        .foregroundColor(currentInput.isEmpty ? .white.opacity(0.3) : .blue)
                }
                .disabled(currentInput.isEmpty && !isProcessing)
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 24)
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.3))
                .ignoresSafeArea(.all, edges: .bottom)
        )
    }
    
    private var systemCommandsInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Available Commands:")
                .font(.tomeCaptionMedium())
                .foregroundColor(.white.opacity(0.7))
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    commandHint("add_todo:<task>", "Add new task")
                    commandHint("complete_todo:<task>", "Mark task complete")
                    commandHint("open_app:<app>", "Launch application")
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    commandHint("todo_list", "View current tasks")
                    commandHint("session_info", "Check session status")
                    commandHint("set_reminder:<min>:<msg>", "Set reminder")
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.05))
                .stroke(Color.blue.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
    
    private func commandHint(_ command: String, _ description: String) -> some View {
        HStack(spacing: 8) {
            Text(command)
                .font(.tomeTinyMedium())
                .foregroundColor(.blue.opacity(0.8))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue.opacity(0.1))
                )
            
            Text(description)
                .font(.tomeTiny())
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    private var typingIndicator: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.blue.opacity(0.8))
                        .frame(width: 8, height: 8)
                        .scaleEffect(isProcessing ? 1.2 : 0.8)
                        .opacity(isProcessing ? 1.0 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                            value: isProcessing
                        )
                }
                
                Text("AI is thinking...")
                    .font(.tomeSmallLabel())
                    .foregroundColor(.white.opacity(0.6))
                    .opacity(isProcessing ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.3), value: isProcessing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.blue.opacity(0.1))
                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
            )
            
            Spacer()
        }
    }
    
    private func initializeChat() {
        messages = [
            ChatMessage(
                role: "assistant",
                content: "Hello! I'm your TOME AI assistant. I can help you manage todos, control applications, set reminders, and optimize your focus session. What would you like to do?"
            )
        ]
    }
    
    private func sendMessage() {
        guard !currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = ChatMessage(role: "user", content: currentInput)
        messages.append(userMessage)
        
        let messageToProcess = currentInput
        currentInput = ""
        isProcessing = true
        
        // Check for system commands first
        if let response = processSystemCommand(messageToProcess) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                messages.append(ChatMessage(role: "assistant", content: response))
                isProcessing = false
            }
            return
        }
        
        // Send to OpenAI for general conversation
        let systemPrompt = """
        You are a TOME AI assistant integrated into a focus management system. You can help with:
        
        1. Todo management (adding, completing, organizing tasks)
        2. Session information (current focus mode, time remaining)
        3. Application control (opening/closing apps)
        4. Productivity guidance and motivation
        5. Break reminders and wellness
        
        Current session info:
        - Active todos: \(currentState.todos.filter { !$0.isCompleted }.count)
        - Environment: \(currentState.currentSession?.environment.displayName ?? "None")
        
        Be helpful, concise, and focused on productivity. Use system commands when appropriate.
        """
        
        let conversationMessages = [
            ChatMessage(role: "system", content: systemPrompt)
        ] + messages.suffix(10) // Last 10 messages for context
        
        aiService.chatCompletion(messages: conversationMessages) { result in
            DispatchQueue.main.async {
                isProcessing = false
                
                switch result {
                case .success(let response):
                    messages.append(ChatMessage(role: "assistant", content: response))
                case .failure(let error):
                    messages.append(ChatMessage(
                        role: "assistant",
                        content: "I'm having trouble connecting to the AI service. Error: \(error.localizedDescription)"
                    ))
                }
            }
        }
    }
    
    private func processSystemCommand(_ input: String) -> String? {
        let command = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Add todo command
        if command.hasPrefix("add_todo:") {
            let task = String(command.dropFirst(9)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !task.isEmpty {
                currentState.addTodo(task)
                return "✅ Added todo: \(task)"
            }
        }
        
        // Complete todo command
        if command.hasPrefix("complete_todo:") {
            let taskName = String(command.dropFirst(14)).trimmingCharacters(in: .whitespacesAndNewlines)
            if let todo = currentState.todos.first(where: { $0.text.lowercased().contains(taskName) && !$0.isCompleted }) {
                currentState.completeTodo(todo.id)
                return "✅ Completed: \(todo.text)"
            } else {
                return "❌ Could not find incomplete todo matching: \(taskName)"
            }
        }
        
        // Todo list command
        if command == "todo_list" {
            let activeTodos = currentState.todos.filter { !$0.isCompleted }
            if activeTodos.isEmpty {
                return "📝 No active todos. Great job!"
            } else {
                let todoList = activeTodos.map { "• \($0.text)" }.joined(separator: "\n")
                return "📝 Active todos:\n\(todoList)"
            }
        }
        
        // Session info command
        if command == "session_info" {
            if let session = currentState.currentSession {
                let elapsed = Date().timeIntervalSince(session.startTime)
                let remaining = session.plannedDuration - elapsed
                return "Current session: \(session.environment.displayName)\nTime remaining: \(Int(remaining/60)) minutes"
            } else {
                return "No active session"
            }
        }
        
        // Open app command
        if command.hasPrefix("open_app:") {
            let appName = String(command.dropFirst(9)).trimmingCharacters(in: .whitespacesAndNewlines)
            return openApplication(appName)
        }
        
        // Set reminder command
        if command.hasPrefix("set_reminder:") {
            let parts = String(command.dropFirst(13)).components(separatedBy: ":")
            if parts.count >= 2,
               let minutes = Int(parts[0].trimmingCharacters(in: .whitespacesAndNewlines)) {
                let message = parts[1...].joined(separator: ":").trimmingCharacters(in: .whitespacesAndNewlines)
                return setReminder(minutes: minutes, message: message)
            } else {
                return "❌ Invalid reminder format. Use: set_reminder:<minutes>:<message>"
            }
        }
        
        return nil
    }
    
    private func openApplication(_ appName: String) -> String {
        // Use the current state's application service if available
        if let success = currentState.applicationService?.launchApplication(appName), success {
            return "Successfully opened \(appName)"
        } else {
            return "Could not find or open '\(appName)'. Try using the exact application name."
        }
    }
    
    private func setReminder(minutes: Int, message: String) -> String {
        let reminder = TOMEReminder(
            id: UUID(),
            message: message,
            triggerTime: Date().addingTimeInterval(TimeInterval(minutes * 60))
        )
        
        activeReminders.append(reminder)
        
        // Schedule the reminder notification
        Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes * 60), repeats: false) { _ in
            self.triggerReminder(reminder)
        }
        
        return "⏰ Reminder set for \(minutes) minute\(minutes == 1 ? "" : "s"): \(message)"
    }
    
    private func triggerReminder(_ reminder: TOMEReminder) {
        DispatchQueue.main.async {
            // Add reminder message to chat
            let reminderMessage = ChatMessage(
                role: "assistant", 
                content: "⏰ REMINDER: \(reminder.message)"
            )
            self.messages.append(reminderMessage)
            
            // Remove from active reminders
            self.activeReminders.removeAll { $0.id == reminder.id }
            
            // Send system notification
            self.sendSystemNotification(for: reminder)
        }
    }
    
    private func sendSystemNotification(for reminder: TOMEReminder) {
        let content = UNMutableNotificationContent()
        content.title = "TOME Reminder"
        content.body = reminder.message
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: reminder.id.uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error)")
            }
        }
    }
    
    private func scrollToBottom() {
        if let proxy = scrollProxy, !messages.isEmpty {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo(messages.count - 1, anchor: .bottom)
            }
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    let isUser: Bool
    
    var body: some View {
        HStack {
            if isUser {
                Spacer()
                messageContent
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.blue.opacity(0.2))
                    )
            } else {
                messageContent
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.05))
                    )
                Spacer()
            }
        }
    }
    
    private var messageContent: some View {
        Text(message.content)
            .font(.tomeBody())
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct TOMEReminder: Identifiable {
    let id: UUID
    let message: String
    let triggerTime: Date
}

