import SwiftUI

struct WriterDeskView: View {
    @ObservedObject var currentState: TOMEState
    @StateObject private var aiService = OpenAIService()
    
    // Main composition state
    @State private var currentText = ""
    @State private var selectedTemplate: MessageTemplate?
    @State private var selectedRecipient: String = ""
    @State private var wordCount = 0
    @State private var characterCount = 0
    
    // AI assistant state
    @State private var aiSuggestions: [AISuggestion] = []
    @State private var showAIPanel = false
    @State private var selectedTone: WritingTone = .professional
    @State private var isProcessingAI = false
    
    // Communication state
    @State private var draftMode: DraftMode = .compose
    @State private var sendMethod: SendMethod = .email
    @State private var unifiedMessages: [UnifiedMessage] = []
    @State private var respondToItems: [RespondToItem] = []
    @State private var waitingOnItems: [WaitingOnItem] = []
    @State private var draftItems: [DraftItem] = []
    @State private var showSendOptions = false
    
    // Typewriter features
    @State private var typewriterSoundsEnabled = true
    @State private var focusMode = false
    @FocusState private var isTextFieldFocused: Bool
    
    let onNavigateHome: () -> Void
    
    init(currentState: TOMEState, onNavigateHome: @escaping () -> Void = {}) {
        self.currentState = currentState
        self.onNavigateHome = onNavigateHome
    }
    
    var body: some View {
        ZStack {
            // Paper texture background for typewriter aesthetic
            Color.black.ignoresSafeArea(.all)
                .overlay(
                    // Subtle paper texture
                    Rectangle()
                        .fill(Color.white.opacity(0.01))
                        .background(
                            Image(systemName: "doc.text")
                                .font(.system(size: 2000))
                                .foregroundColor(.white.opacity(0.002))
                                .scaleEffect(2.0)
                        )
                )
            
            GeometryReader { geometry in
                HStack(spacing: 1) {
                    // Left Sidebar - Unified Inbox (25%)
                    unifiedInboxPanel
                        .frame(width: geometry.size.width * 0.25, height: geometry.size.height)
                    
                    // Minimal divider
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 1)
                    
                    // Center - Letter Composition Interface (50%)
                    letterCompositionPanel
                        .frame(width: geometry.size.width * 0.5, height: geometry.size.height)
                    
                    // Minimal divider  
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 1)
                    
                    // Right Sidebar - AI Communication Todos (25%)
                    aiCommunicationTodosPanel
                        .frame(width: geometry.size.width * 0.25, height: geometry.size.height)
                }
            }
            
            // Navigation overlay
            TOMENavigationOverlay(
                onNavigateHome: onNavigateHome,
                environmentName: "Writer's Desk",
                environmentColor: .green
            )
        }
        .onAppear {
            loadUnifiedInbox()
            loadCommunicationTodos()
            // Auto-focus the text editor for immediate typing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
    }
    
    // UNIFIED INBOX - All channels in order of priority with AI-generated summaries
    private var unifiedInboxPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Inbox")
                .font(.tomeHeading())
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.top, 40)
                .padding(.bottom, 30)
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    // All channels in priority order with AI summaries
                    ForEach(unifiedMessages, id: \.id) { message in
                        UnifiedMessageRow(
                            message: message,
                            isSelected: selectedRecipient == message.sender,
                            onSelect: { selectMessageForReply(message) }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }
    
    // LETTER COMPOSITION INTERFACE - Minimalist typewriter with AI assistance
    private var letterCompositionPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Document header with typewriter aesthetic
            VStack(alignment: .leading, spacing: 12) {
                // Recipient and send method selector
                HStack {
                    Text("To:")
                        .font(.tomeBodyMedium())
                        .foregroundColor(.white.opacity(0.7))
                    
                    TextField("Recipient", text: $selectedRecipient)
                        .font(.tomeBody())
                        .foregroundColor(.white)
                        .textFieldStyle(PlainTextFieldStyle())
                    
                    Spacer()
                    
                    // Send method picker
                    Menu {
                        Button("Email") { 
                            sendMethod = .email
                            restoreFocus()
                        }
                        Button("Messages") { 
                            sendMethod = .messages
                            restoreFocus()
                        }
                        Button("Slack") { 
                            sendMethod = .slack
                            restoreFocus()
                        }
                        Button("Save to File") { 
                            sendMethod = .file
                            restoreFocus()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: sendMethod.icon)
                                .font(.system(size: 12))
                            Text(sendMethod.rawValue.capitalized)
                                .font(.tomeCaption())
                        }
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.05))
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    }
                }
                
                // Template and tone controls
                HStack {
                    // Template selector
                    Menu {
                        Button("Blank") { selectedTemplate = nil }
                        Button("Professional Email") { selectedTemplate = .professionalEmail }
                        Button("Quick Response") { selectedTemplate = .quickResponse }
                        Button("Follow-up") { selectedTemplate = .followUp }
                    } label: {
                        Text(selectedTemplate?.name ?? "Template")
                            .font(.tomeSmallLabel())
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    Spacer()
                    
                    // Tone adjustment
                    Menu {
                        Button("Professional") { selectedTone = .professional }
                        Button("Friendly") { selectedTone = .friendly }
                        Button("Concise") { selectedTone = .concise }
                        Button("Creative") { selectedTone = .creative }
                    } label: {
                        Text(selectedTone.rawValue.capitalized)
                            .font(.tomeSmallLabel())
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    // AI assistance toggle
                    Button(action: { showAIPanel.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: showAIPanel ? "brain.head.profile.fill" : "brain.head.profile")
                                .font(.system(size: 12))
                            Text("AI")
                                .font(.tomeSmallLabel())
                        }
                        .foregroundColor(showAIPanel ? .white : .white.opacity(0.5))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Stats
                HStack {
                    Text("\(wordCount) words • \(characterCount) characters")
                        .font(.tomeTiny())
                        .foregroundColor(.white.opacity(0.4))
                    
                    Spacer()
                    
                    if typewriterSoundsEnabled {
                        Image(systemName: "speaker.2")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 40)
            .padding(.bottom, 30)
            
            // Main typewriter composition area
            ZStack(alignment: .topLeading) {
                // Typewriter text editor with smart templates
                TextEditor(text: $currentText)
                    .font(.custom("American Typewriter", size: 16))
                    .foregroundColor(.white)
                    .background(Color.clear)
                    .scrollContentBackground(.hidden)
                    .onChange(of: currentText) { _, newValue in
                        updateTextStats(newValue)
                        handleTypewriterInput(newValue)
                        requestAISuggestions()
                    }
                    .padding(.horizontal, 40)
                    .focused($isTextFieldFocused)
                
                // Placeholder with context
                if currentText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        if let template = selectedTemplate {
                            Text(template.placeholder)
                                .font(.custom("American Typewriter", size: 16))
                                .foregroundColor(.white.opacity(0.2))
                        } else {
                            Text("Start writing...")
                                .font(.custom("American Typewriter", size: 16))
                                .foregroundColor(.white.opacity(0.2))
                        }
                        
                        if !selectedRecipient.isEmpty {
                            Text("Writing to: \(selectedRecipient)")
                                .font(.tomeCaption())
                                .foregroundColor(.white.opacity(0.15))
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 8)
                    .allowsHitTesting(false)
                }
                
                // AI suggestions overlay
                if showAIPanel && !aiSuggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(aiSuggestions.prefix(3)) { suggestion in
                            AISuggestionBubble(
                                suggestion: suggestion,
                                onAccept: { applySuggestion(suggestion) },
                                onDismiss: { dismissSuggestion(suggestion) }
                            )
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 8)
                }
            }
            
            Spacer()
            
            // Send/save controls
            HStack {
                // Draft actions
                Button("Save Draft") {
                    saveDraft()
                }
                .font(.tomeCaption())
                .foregroundColor(.white.opacity(0.5))
                .buttonStyle(PlainButtonStyle())
                
                Button("Clear") {
                    currentText = ""
                }
                .font(.tomeCaption())
                .foregroundColor(.white.opacity(0.5))
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // Main send button
                Button(action: sendMessage) {
                    HStack(spacing: 6) {
                        Image(systemName: sendMethod.icon)
                            .font(.system(size: 12))
                        Text(sendMethod.sendLabel)
                            .font(.tomeCaptionMedium())
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.1))
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }
    
    // AI COMMUNICATION TODOS - Auto-generated based on interactions
    private var aiCommunicationTodosPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Todos")
                .font(.tomeHeading())
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.top, 40)
                .padding(.bottom, 30)
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Respond to section
                    communicationSection(
                        title: "Respond to:",
                        items: respondToItems,
                        icon: "arrow.turn.up.right",
                        color: .orange
                    )
                    
                    // Waiting on section
                    communicationSection(
                        title: "Waiting on:",
                        items: waitingOnItems,
                        icon: "clock",
                        color: .blue
                    )
                    
                    // Draft started section
                    communicationSection(
                        title: "Draft started:",
                        items: draftItems,
                        icon: "doc.text",
                        color: .green
                    )
                    
                    // Quick templates
                    quickTemplatesSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }
    
    private func communicationSection<T: CommunicationTodoItem>(
        title: String,
        items: [T],
        icon: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color.opacity(0.7))
                
                Text(title)
                    .font(.tomeCaptionMedium())
                    .foregroundColor(.white.opacity(0.7))
            }
            
            VStack(spacing: 4) {
                ForEach(items, id: \.id) { item in
                    CommunicationTodoRow(
                        item: item,
                        color: color,
                        onAction: { handleCommunicationAction(item) }
                    )
                }
            }
        }
    }
    
    private var quickTemplatesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "text.badge.checkmark")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                
                Text("Quick Templates")
                    .font(.tomeCaptionMedium())
                    .foregroundColor(.white.opacity(0.7))
            }
            
            VStack(spacing: 4) {
                ForEach(quickTemplates, id: \.id) { template in
                    Button(action: { useQuickTemplate(template) }) {
                        HStack {
                            Text(template.name)
                                .font(.tomeTiny())
                                .foregroundColor(.white.opacity(0.6))
                            
                            Spacer()
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.02))
                                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Supporting Functions
    
    private func loadUnifiedInbox() {
        // Load from persistent storage first
        loadPersistedCommunications()
        
        // Then try to load real email data
        loadEmailData()
        
        // Load Messages app data (when available)
        loadMessagesData()
        
        print("📧 Loaded \(unifiedMessages.count) messages from unified inbox")
    }
    
    private func loadPersistedCommunications() {
        // Load saved data
        if let data = UserDefaults.standard.data(forKey: "writer_desk_messages"),
           let messages = try? JSONDecoder().decode([UnifiedMessage].self, from: data) {
            unifiedMessages = messages
        }
        
        if let data = UserDefaults.standard.data(forKey: "writer_desk_respond_to"),
           let items = try? JSONDecoder().decode([RespondToItem].self, from: data) {
            respondToItems = items
        }
        
        if let data = UserDefaults.standard.data(forKey: "writer_desk_waiting_on"),
           let items = try? JSONDecoder().decode([WaitingOnItem].self, from: data) {
            waitingOnItems = items
        }
        
        if let data = UserDefaults.standard.data(forKey: "writer_desk_drafts"),
           let items = try? JSONDecoder().decode([DraftItem].self, from: data) {
            draftItems = items
        }
    }
    
    private func loadEmailData() {
        // Try to read from Mail.app's SQLite database
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let mailPath = homeDir.appendingPathComponent("Library/Mail/V10/MailData/Envelope Index")
        
        if FileManager.default.fileExists(atPath: mailPath.path) {
            // This would require SQLite parsing - simplified for now
            print("📧 Found Mail.app database, parsing...")
            
            // Add a sample email as placeholder
            if unifiedMessages.isEmpty {
                let sampleEmail = UnifiedMessage(
                    id: UUID(),
                    sender: "example@domain.com",
                    subject: "Welcome to TOME",
                    preview: "Your focus management system is ready...",
                    source: .email,
                    timestamp: Date(),
                    priority: .high,
                    needsResponse: true,
                    aiSummary: "Welcome message with setup instructions"
                )
                unifiedMessages.append(sampleEmail)
                saveCommunicationData()
            }
        }
    }
    
    private func loadMessagesData() {
        // Access Messages.app data - this would require private frameworks
        // For now, we'll create a placeholder structure
        print("💬 Checking Messages.app...")
    }
    
    private func saveCommunicationData() {
        if let data = try? JSONEncoder().encode(unifiedMessages) {
            UserDefaults.standard.set(data, forKey: "writer_desk_messages")
        }
        
        if let data = try? JSONEncoder().encode(respondToItems) {
            UserDefaults.standard.set(data, forKey: "writer_desk_respond_to")
        }
        
        if let data = try? JSONEncoder().encode(waitingOnItems) {
            UserDefaults.standard.set(data, forKey: "writer_desk_waiting_on")
        }
        
        if let data = try? JSONEncoder().encode(draftItems) {
            UserDefaults.standard.set(data, forKey: "writer_desk_drafts")
        }
    }
    
    private func loadCommunicationTodos() {
        // AI-generated todos based on communication patterns
        print("🧠 Loading AI communication todos...")
    }
    
    private func selectMessageForReply(_ message: UnifiedMessage) {
        selectedRecipient = message.sender
        currentText = ""
        
        // Auto-select appropriate send method based on message source
        // but default to email to avoid triggering Messages app
        switch message.source {
        case .email:
            sendMethod = .email
        case .slack:
            sendMethod = .slack  
        case .messages:
            sendMethod = .email  // Default to email to prevent Messages from launching
        }
        
        // AI drafts response in user's voice
        requestAIResponse(for: message)
    }
    
    private func updateTextStats(_ text: String) {
        wordCount = text.split(separator: " ").count
        characterCount = text.count
    }
    
    private func handleTypewriterInput(_ text: String) {
        if typewriterSoundsEnabled {
            // Play typewriter sound effect
            // AudioService.shared.playTypewriterSound()
        }
    }
    
    private func requestAISuggestions() {
        guard showAIPanel && !currentText.isEmpty && currentText.count > 5 else { return }
        
        // Generate immediate smart suggestions based on text analysis
        let smartSuggestions = generateSmartSuggestions()
        aiSuggestions = smartSuggestions
        
        // Only call AI for substantial text that needs improvement
        guard currentText.count > 20 else { return }
        
        isProcessingAI = true
        
        // Create much better, contextual prompts
        let promptType = determineBestPromptType()
        let (systemPrompt, userPrompt) = createTargetedPrompt(type: promptType)
        
        aiService.chatCompletion(
            messages: [
                ChatMessage(role: "system", content: systemPrompt),
                ChatMessage(role: "user", content: userPrompt)
            ],
            model: "gpt-3.5-turbo"
        ) { result in
            DispatchQueue.main.async {
                self.isProcessingAI = false
                switch result {
                case .success(let aiResponse):
                    // Only add AI suggestion if it's actually different and useful
                    if aiResponse.count > 10 && aiResponse != self.currentText {
                        let aiSuggestion = AISuggestion(
                            id: UUID(),
                            text: aiResponse,
                            type: promptType,
                            confidence: 0.90
                        )
                        self.aiSuggestions = smartSuggestions + [aiSuggestion]
                    }
                case .failure(let error):
                    print("❌ AI suggestion failed: \(error)")
                    // Keep the smart suggestions even if AI fails
                }
            }
        }
    }
    
    private func generateSmartSuggestions() -> [AISuggestion] {
        var suggestions: [AISuggestion] = []
        let text = currentText.lowercased()
        let words = currentText.split(separator: " ")
        
        // Email structure suggestions
        if selectedTemplate?.name.contains("Email") == true {
            if !text.hasPrefix("hi ") && !text.hasPrefix("hello") && !text.hasPrefix("dear") {
                suggestions.append(AISuggestion(
                    id: UUID(),
                    text: "Start with a greeting: 'Hi [Name],' or 'Dear [Name],'",
                    type: .improvement,
                    confidence: 0.95
                ))
            }
            if words.count > 10 && !text.contains("thank") && !text.contains("best") {
                suggestions.append(AISuggestion(
                    id: UUID(),
                    text: "End with 'Thank you,' or 'Best regards,'",
                    type: .improvement,
                    confidence: 0.90
                ))
            }
        }
        
        // Length suggestions
        if words.count < 3 {
            suggestions.append(AISuggestion(
                id: UUID(),
                text: "Add more context to make your message clearer",
                type: .clarity,
                confidence: 0.85
            ))
        } else if words.count > 150 {
            suggestions.append(AISuggestion(
                id: UUID(),
                text: "Consider breaking this into shorter paragraphs",
                type: .clarity,
                confidence: 0.80
            ))
        }
        
        // Tone suggestions
        if text.contains("asap") || text.contains("urgent") {
            suggestions.append(AISuggestion(
                id: UUID(),
                text: "Consider softer language: 'when convenient' instead of 'ASAP'",
                type: .tone,
                confidence: 0.75
            ))
        }
        
        return Array(suggestions.prefix(2))
    }
    
    private func determineBestPromptType() -> SuggestionType {
        let text = currentText.lowercased()
        
        if selectedTone != .professional && (selectedTemplate?.name.contains("Professional") == true) {
            return .tone
        } else if text.contains("um") || text.contains("uh") || text.contains("like,") {
            return .clarity
        } else if currentText.count > 200 {
            return .clarity  // Focus on making long text clearer
        } else {
            return .improvement
        }
    }
    
    private func createTargetedPrompt(type: SuggestionType) -> (String, String) {
        let context = selectedRecipient.isEmpty ? "" : " to \(selectedRecipient)"
        let messageType = selectedTemplate?.name ?? "message"
        
        switch type {
        case .tone:
            return (
                "You are a professional communication expert. Rewrite the user's message to match the specified tone while keeping the exact same meaning and key points. Return ONLY the rewritten message with no explanations.",
                "Rewrite this \(messageType)\(context) to be \(selectedTone.rawValue) in tone:\n\n\(currentText)"
            )
        case .clarity:
            return (
                "You are a clarity expert. Make this message clearer and more concise while preserving all important information. Return ONLY the improved message.",
                "Make this \(messageType)\(context) clearer and more concise:\n\n\(currentText)"
            )
        case .grammar:
            return (
                "You are a grammar expert. Fix any grammar, spelling, or punctuation errors. Return ONLY the corrected message.",
                "Fix grammar and spelling in this \(messageType):\n\n\(currentText)"
            )
        default:
            return (
                "You are a professional communication expert. Improve this message for clarity, professionalism, and effectiveness. Keep the same meaning but make it more impactful. Return ONLY the improved message.",
                "Improve this \(messageType)\(context) for maximum impact:\n\n\(currentText)"
            )
        }
    }
    
    private func requestAIResponse(for message: UnifiedMessage) {
        let prompt = """
        Draft a response to this message in a \(selectedTone.rawValue) tone:
        
        From: \(message.sender)
        Subject: \(message.subject)
        Content: \(message.preview)
        
        Write a response that addresses their message appropriately.
        """
        
        aiService.chatCompletion(
            messages: [ChatMessage(role: "user", content: prompt)],
            model: "gpt-3.5-turbo"
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self.currentText = response
                case .failure(let error):
                    print("❌ AI response generation failed: \(error)")
                }
            }
        }
    }
    
    private func applySuggestion(_ suggestion: AISuggestion) {
        currentText = suggestion.text
        aiSuggestions.removeAll { $0.id == suggestion.id }
    }
    
    private func dismissSuggestion(_ suggestion: AISuggestion) {
        aiSuggestions.removeAll { $0.id == suggestion.id }
    }
    
    private func saveDraft() {
        // Save to drafts - could be local file or cloud storage
        print("💾 Saving draft...")
    }
    
    private func sendMessage() {
        guard !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        switch sendMethod {
        case .email:
            sendViaEmail()
        case .messages:
            sendViaMessages()  
        case .slack:
            sendViaSlack()
        case .file:
            saveToFile()
        }
        
        // Clear after sending
        currentText = ""
        selectedRecipient = ""
    }
    
    private func sendViaEmail() {
        let subject = selectedTemplate?.defaultSubject ?? "Message from TOME"
        let mailURL = "mailto:\(selectedRecipient)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(currentText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        if let url = URL(string: mailURL) {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func sendViaMessages() {
        // Use URL scheme to open Messages app with pre-filled text
        // This avoids AppleScript which can interfere with text input system
        let messagesURL = "sms:\(selectedRecipient)&body=\(currentText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        if let url = URL(string: messagesURL) {
            NSWorkspace.shared.open(url)
            print("💬 Opened Messages with pre-filled text to \(selectedRecipient)")
        } else {
            // Fallback: just open Messages app
            if let messagesApp = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.MobileSMS") {
                NSWorkspace.shared.open(messagesApp)
                print("💬 Opened Messages app")
            }
        }
    }
    
    private func sendViaSlack() {
        // Use slack:// URL scheme to open Slack with a pre-filled message
        let slackURL = "slack://channel?team=\(selectedRecipient)&id=\(selectedRecipient)&message=\(currentText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        if let url = URL(string: slackURL) {
            NSWorkspace.shared.open(url)
            print("📱 Opened Slack with message to \(selectedRecipient)")
        } else {
            // Fallback: try to open Slack app
            if let slackApp = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.tinyspeck.slackmacgap") {
                NSWorkspace.shared.open(slackApp)
                print("📱 Opened Slack app")
            }
        }
    }
    
    private func saveToFile() {
        let fileName = selectedTemplate?.name.replacingOccurrences(of: " ", with: "_") ?? "TOME_Document"
        let content = "To: \(selectedRecipient)\n\n\(currentText)"
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "\(fileName).txt"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }
    
    private func restoreFocus() {
        // Simple focus restoration - less aggressive to avoid interfering with system focus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isTextFieldFocused = true
        }
    }
    
    private func handleCommunicationAction(_ item: any CommunicationTodoItem) {
        selectedRecipient = item.sender
        currentText = ""
        // Auto-populate based on todo type
    }
    
    private func useQuickTemplate(_ template: QuickTemplate) {
        selectedTemplate = template.messageTemplate
        currentText = template.template
    }
    
    
}

// MARK: - Data Models

// Unified inbox message combining all communication channels
struct UnifiedMessage: Identifiable, Codable {
    let id: UUID
    let sender: String
    let subject: String
    let preview: String
    let source: MessageSource
    let timestamp: Date
    let priority: MessagePriority
    let needsResponse: Bool
    let aiSummary: String
}

enum MessageSource: Codable {
    case email, slack, messages
    
    var icon: String {
        switch self {
        case .email: return "envelope"
        case .slack: return "number"
        case .messages: return "message"
        }
    }
}

enum MessagePriority: Codable {
    case high, medium, low
    
    var color: Color {
        switch self {
        case .high: return .red
        case .medium: return .orange  
        case .low: return .white
        }
    }
}

// AI writing assistance
struct AISuggestion: Identifiable {
    let id: UUID
    let text: String
    let type: SuggestionType
    let confidence: Double
}

enum SuggestionType {
    case improvement, grammar, tone, clarity
    
    var icon: String {
        switch self {
        case .improvement: return "arrow.up.circle"
        case .grammar: return "textformat.abc"
        case .tone: return "speaker.wave.2"
        case .clarity: return "eye.circle"
        }
    }
    
    var displayName: String {
        switch self {
        case .improvement: return "Enhancement"
        case .grammar: return "Grammar"
        case .tone: return "Tone"
        case .clarity: return "Clarity"
        }
    }
    
    var color: Color {
        switch self {
        case .improvement: return .blue
        case .grammar: return .red
        case .tone: return .orange
        case .clarity: return .green
        }
    }
}

enum WritingTone: String, CaseIterable {
    case professional, friendly, concise, creative
}

enum DraftMode {
    case compose, reply, forward
}

enum SendMethod: String, CaseIterable {
    case email, messages, slack, file
    
    var icon: String {
        switch self {
        case .email: return "envelope"
        case .messages: return "message"
        case .slack: return "number"
        case .file: return "doc"
        }
    }
    
    var sendLabel: String {
        switch self {
        case .email: return "Send Email"
        case .messages: return "Send Message"
        case .slack: return "Send to Slack"
        case .file: return "Save File"
        }
    }
}

// Message templates
struct MessageTemplate: Identifiable {
    let id: UUID
    let name: String
    let placeholder: String
    let defaultSubject: String
    
    static let professionalEmail = MessageTemplate(
        id: UUID(),
        name: "Professional Email",
        placeholder: "Dear [Name],\n\nI hope this email finds you well...",
        defaultSubject: "Re: "
    )
    
    static let quickResponse = MessageTemplate(
        id: UUID(),
        name: "Quick Response", 
        placeholder: "Thanks for your message...",
        defaultSubject: "Re: "
    )
    
    static let followUp = MessageTemplate(
        id: UUID(),
        name: "Follow-up",
        placeholder: "Following up on our previous conversation...",
        defaultSubject: "Follow-up: "
    )
}

// Communication todos protocol
protocol CommunicationTodoItem: Identifiable {
    var id: UUID { get }
    var sender: String { get }
    var subject: String { get }
    var deadline: Date? { get }
}

struct RespondToItem: CommunicationTodoItem, Codable {
    let id: UUID
    let sender: String
    let subject: String
    let deadline: Date?
    let urgency: MessagePriority
}

struct WaitingOnItem: CommunicationTodoItem, Codable {
    let id: UUID
    let sender: String
    let subject: String
    let deadline: Date?
    let followUpDate: Date
}

struct DraftItem: CommunicationTodoItem, Codable {
    let id: UUID
    let sender: String
    let subject: String
    let deadline: Date?
    let progress: Double
    
    init(id: UUID, subject: String, deadline: Date?, progress: Double) {
        self.id = id
        self.sender = ""
        self.subject = subject
        self.deadline = deadline
        self.progress = progress
    }
}

struct QuickTemplate: Identifiable {
    let id: UUID
    let name: String
    let template: String
    let messageTemplate: MessageTemplate?
}

// MARK: - Mock Data

private var mockUnifiedMessages: [UnifiedMessage] {
    [
        UnifiedMessage(
            id: UUID(),
            sender: "sarah@company.com",
            subject: "Design Review Feedback",
            preview: "Hey, I've reviewed the new designs and have some feedback. The color palette looks great but...",
            source: .email,
            timestamp: Date(),
            priority: .high,
            needsResponse: true,
            aiSummary: "Sarah has design feedback, mentions color palette approval but has concerns"
        ),
        UnifiedMessage(
            id: UUID(),
            sender: "John Smith",
            subject: "Quick question",
            preview: "Can you clarify the API endpoint requirements?",
            source: .slack,
            timestamp: Date().addingTimeInterval(-3600),
            priority: .medium,
            needsResponse: true,
            aiSummary: "John needs clarification on API requirements"
        ),
        UnifiedMessage(
            id: UUID(),
            sender: "Mom",
            subject: "",
            preview: "Don't forget dinner Sunday!",
            source: .messages,
            timestamp: Date().addingTimeInterval(-7200),
            priority: .low,
            needsResponse: false,
            aiSummary: "Family reminder about Sunday dinner"
        )
    ]
}

private var mockRespondToItems: [RespondToItem] {
    [
        RespondToItem(
            id: UUID(),
            sender: "Client ABC",
            subject: "Contract questions",
            deadline: Date().addingTimeInterval(86400),
            urgency: .high
        ),
        RespondToItem(
            id: UUID(),
            sender: "Team Lead",
            subject: "Sprint retrospective",
            deadline: Date().addingTimeInterval(172800),
            urgency: .medium
        )
    ]
}

private var mockWaitingOnItems: [WaitingOnItem] {
    [
        WaitingOnItem(
            id: UUID(),
            sender: "Legal Team",
            subject: "Contract approval",
            deadline: Date().addingTimeInterval(259200),
            followUpDate: Date().addingTimeInterval(86400)
        )
    ]
}

private var mockDraftItems: [DraftItem] {
    [
        DraftItem(
            id: UUID(),
            subject: "Proposal response",
            deadline: Date().addingTimeInterval(172800),
            progress: 0.6
        )
    ]
}

private var quickTemplates: [QuickTemplate] {
    [
        QuickTemplate(
            id: UUID(),
            name: "Thanks & Confirm",
            template: "Thanks for your message. I can confirm that works for me.",
            messageTemplate: .quickResponse
        ),
        QuickTemplate(
            id: UUID(),
            name: "Will Follow Up",
            template: "Thanks for bringing this to my attention. I'll look into it and follow up with you shortly.",
            messageTemplate: .followUp
        ),
        QuickTemplate(
            id: UUID(),
            name: "Schedule Call",
            template: "Thanks for your message. Would you be available for a brief call to discuss this further?",
            messageTemplate: .professionalEmail
        )
    ]
}

// MARK: - Supporting Views

struct UnifiedMessageRow: View {
    let message: UnifiedMessage
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Source icon
                Image(systemName: message.source.icon)
                    .font(.system(size: 10))
                    .foregroundColor(message.priority.color.opacity(0.7))
                
                // Sender
                Text(message.sender)
                    .font(.tomeSmallLabelMedium())
                    .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                    .lineLimit(1)
                
                Spacer()
                
                // Response needed indicator
                if message.needsResponse {
                    Circle()
                        .fill(Color.orange.opacity(0.6))
                        .frame(width: 4, height: 4)
                }
            }
            
            // AI-generated summary
            Text(message.aiSummary)
                .font(.tomeTiny())
                .foregroundColor(.white.opacity(0.5))
                .lineLimit(2)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.white.opacity(0.05) : Color.clear)
                .stroke(isSelected ? Color.white.opacity(0.1) : Color.clear, lineWidth: 1)
        )
        .onTapGesture {
            onSelect()
        }
    }
}

struct CommunicationTodoRow: View {
    let item: any CommunicationTodoItem
    let color: Color
    let onAction: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.sender)
                    .font(.tomeTinyMedium())
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                
                Text(item.subject)
                    .font(.tomeTiny())
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
                
                if let deadline = item.deadline {
                    Text(timeUntilDeadline(deadline))
                        .font(.tomeTiny())
                        .foregroundColor(color.opacity(0.6))
                }
            }
            
            Spacer()
            
            Button(action: onAction) {
                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 12))
                    .foregroundColor(color.opacity(0.6))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.02))
                .stroke(color.opacity(0.1), lineWidth: 0.5)
        )
    }
    
    private func timeUntilDeadline(_ deadline: Date) -> String {
        let interval = deadline.timeIntervalSinceNow
        let hours = Int(interval / 3600)
        if hours < 24 {
            return "\(hours)h"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d"
        }
    }
}

struct AISuggestionBubble: View {
    let suggestion: AISuggestion
    let onAccept: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Clear header with suggestion type
            HStack {
                Image(systemName: suggestion.type.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(suggestion.type.color)
                
                Text(suggestion.type.displayName)
                    .font(.tomeCaptionMedium())
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()
                
                // Confidence indicator
                if suggestion.confidence > 0.8 {
                    Text("High confidence")
                        .font(.tomeTiny())
                        .foregroundColor(.green.opacity(0.6))
                }
            }
            
            // Suggestion text - make it clear what will happen
            Text(suggestion.text)
                .font(.tomeCaption())
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            
            // Clear action buttons
            HStack(spacing: 12) {
                Button(action: onAccept) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10))
                        Text(suggestion.type == .improvement ? "Use This" : "Apply")
                            .font(.tomeSmallLabelMedium())
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.green.opacity(0.3))
                            .stroke(Color.green.opacity(0.5), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: onDismiss) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9))
                        Text("Dismiss")
                            .font(.tomeSmallLabel())
                    }
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.08))
                .stroke(suggestion.type.color.opacity(0.3), lineWidth: 1)
        )
    }
}


