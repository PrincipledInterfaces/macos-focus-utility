import SwiftUI
import UniformTypeIdentifiers

struct TextEditorView: View {
    @ObservedObject var documentService: DocumentService
    @Binding var document: Document
    @ObservedObject var aiService: OpenAIService
    @StateObject private var inboxService = UnifiedInboxService()

    @State private var fontSize: Double = 16
    @State private var showAIPanel: Bool = false
    @State private var aiInput: String = ""
    @State private var isProcessingAI: Bool = false
    @State private var selectedMessage: UnifiedMessage?
    @FocusState private var isTextFocused: Bool

    let onBack: () -> Void
    let onNavigateHome: () -> Void

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea(.all)

            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Left sidebar - Unified Inbox (25% width)
                    unifiedInboxPanel
                        .frame(width: geometry.size.width * 0.25)

                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 1)

                    // Main editor (50% width)
                    editorPanel
                        .frame(width: showAIPanel ? geometry.size.width * 0.45 : geometry.size.width * 0.75)

                    // AI Assistant Panel (25% width when shown)
                    if showAIPanel {
                        Rectangle()
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 1)

                        aiAssistantPanel
                            .frame(width: geometry.size.width * 0.3)
                    }
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
            // Auto-focus text editor
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isTextFocused = true
            }
        }
    }

    // MARK: - Editor Panel

    private var editorPanel: some View {
        VStack(spacing: 0) {
            // Header with document title and controls
            editorHeader

            // Main text editor with glassmorphic container
            ZStack {
                // Background
                Color.black

                ScrollView {
                    TextEditor(text: $document.content)
                        .font(.custom("American Typewriter", size: fontSize))
                        .foregroundColor(.white)
                        .scrollContentBackground(.hidden)
                        .focused($isTextFocused)
                        .onChange(of: document.content) { _, _ in
                            autoSaveDocument()
                        }
                        .padding(.horizontal, 40)
                        .padding(.vertical, 40)
                        .frame(minHeight: 600)
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 30)
            }
            .overlay(
                // Glassmorphic outline
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1),
                                Color.green.opacity(0.2),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    .shadow(color: .white.opacity(0.2), radius: 4, x: -2, y: -2)
                    .shadow(color: .black.opacity(0.4), radius: 6, x: 3, y: 3)
                    .shadow(color: .green.opacity(0.3), radius: 12, x: 0, y: 0)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 30)
            )

            // Footer with stats only
            editorFooter
        }
    }

    // MARK: - Editor Header

    private var editorHeader: some View {
        VStack(spacing: 0) {
            HStack {
                // Back button with glassmorphic style
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .light))
                        Text("Documents")
                            .font(.tomeBody())
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.03))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.2),
                                                Color.white.opacity(0.05)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: .white.opacity(0.1), radius: 2, x: -1, y: -1)
                            .shadow(color: .black.opacity(0.3), radius: 3, x: 2, y: 2)
                    )
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()

                // AI toggle with enhanced glassmorphic style
                Button(action: { showAIPanel.toggle() }) {
                    HStack(spacing: 8) {
                        Image(systemName: showAIPanel ? "brain.head.profile.fill" : "brain.head.profile")
                            .font(.system(size: 14, weight: .light))
                        Text("AI")
                            .font(.tomeBody())
                    }
                    .foregroundColor(showAIPanel ? .green.opacity(0.9) : .white.opacity(0.6))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(showAIPanel ? Color.green.opacity(0.08) : Color.white.opacity(0.03))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        LinearGradient(
                                            colors: showAIPanel ? [
                                                Color.green.opacity(0.4),
                                                Color.green.opacity(0.2)
                                            ] : [
                                                Color.white.opacity(0.2),
                                                Color.white.opacity(0.05)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: showAIPanel ? .green.opacity(0.3) : .white.opacity(0.1), radius: showAIPanel ? 8 : 2, x: -1, y: -1)
                            .shadow(color: .black.opacity(0.3), radius: 3, x: 2, y: 2)
                    )
                }
                .buttonStyle(PlainButtonStyle())

                // Export button with glassmorphic style
                Menu {
                    Button("Export as TXT") { exportDocument(as: .plainText) }
                    Button("Export as RTF") { exportDocument(as: .rtf) }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.03))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.2),
                                                    Color.white.opacity(0.05)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                                .shadow(color: .white.opacity(0.1), radius: 2, x: -1, y: -1)
                                .shadow(color: .black.opacity(0.3), radius: 3, x: 2, y: 2)
                        )
                }
            }
            .padding(.horizontal, 60)
            .padding(.top, 40)
            .padding(.bottom, 24)

            // Document title (editable)
            TextField("Document Title", text: $document.title)
                .font(.tomeTitle())
                .foregroundColor(.white)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.horizontal, 60)
                .padding(.bottom, 20)
                .onChange(of: document.title) { _, _ in
                    autoSaveDocument()
                }

            // Category selector and formatting controls
            HStack(spacing: 20) {
                // Category selector with enhanced glassmorphic pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(DocumentCategory.allCases, id: \.self) { category in
                            CategoryPill(
                                category: category,
                                isSelected: document.category == category
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    document.category = category
                                    autoSaveDocument()
                                }
                            }
                        }
                    }
                }

                // Separator
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 3, height: 3)

                // Formatting controls
                HStack(spacing: 12) {
                    // Font size controls
                    HStack(spacing: 6) {
                        Text("Size")
                            .font(.tomeSmallLabel())
                            .foregroundColor(.white.opacity(0.4))

                        EditorToolButton(icon: "minus", size: 11) {
                            adjustFontSize(-1)
                        }

                        Text("\(Int(fontSize))")
                            .font(.tomeCaption())
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 24)

                        EditorToolButton(icon: "plus", size: 11) {
                            adjustFontSize(1)
                        }
                    }

                    // Separator
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 2, height: 2)

                    // Basic formatting
                    EditorToolButton(icon: "bold", size: 13) {}
                    EditorToolButton(icon: "italic", size: 13) {}
                    EditorToolButton(icon: "underline", size: 13) {}

                    // Separator
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 2, height: 2)

                    // Indent controls
                    EditorToolButton(icon: "increase.indent", size: 13) {
                        insertIndent()
                    }
                    EditorToolButton(icon: "decrease.indent", size: 13) {
                        removeIndent()
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 24)
        }
    }


    // MARK: - Editor Footer

    private var editorFooter: some View {
        HStack(spacing: 12) {
            Text("\(document.wordCount) words")
                .font(.tomeCaption())
                .foregroundColor(.white.opacity(0.5))

            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 2, height: 2)

            Text("\(document.characterCount) chars")
                .font(.tomeCaption())
                .foregroundColor(.white.opacity(0.5))

            Spacer()

            Text(relativeTime(from: document.modifiedAt))
                .font(.tomeCaption())
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 12)
    }

    // MARK: - Unified Inbox Panel

    private var unifiedInboxPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Spacer for home button
            Spacer()
                .frame(height: 100)

            // Inbox Header
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 32, height: 32)
                            .shadow(color: .blue.opacity(0.3), radius: 8)

                        Image(systemName: "tray.fill")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(.blue)
                    }

                    Text("Inbox")
                        .font(.tomeHeading())
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: { inboxService.refreshAllMessages() }) {
                        Image(systemName: inboxService.isLoading ? "arrow.clockwise" : "arrow.clockwise")
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(.white.opacity(0.5))
                            .rotationEffect(.degrees(inboxService.isLoading ? 360 : 0))
                            .animation(inboxService.isLoading ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: inboxService.isLoading)
                            .padding(6)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.05))
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Text("\(inboxService.messages.filter { !$0.isRead }.count) unread")
                    .font(.tomeCaption())
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(20)

            // Glassmorphic divider
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.05),
                            Color.blue.opacity(0.1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)

            // Messages List
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(inboxService.messages) { message in
                        MessageRow(
                            message: message,
                            isSelected: selectedMessage?.id == message.id,
                            onTap: {
                                selectedMessage = message
                                inboxService.markAsRead(message)
                            },
                            onStar: {
                                inboxService.toggleStar(message)
                            }
                        )

                        Rectangle()
                            .fill(Color.white.opacity(0.05))
                            .frame(height: 1)
                            .padding(.leading, 20)
                    }
                }
            }

            if inboxService.messages.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 40, weight: .ultraLight))
                        .foregroundColor(.white.opacity(0.2))

                    Text("No messages")
                        .font(.tomeBody())
                        .foregroundColor(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.5),
                    Color.blue.opacity(0.03)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - AI Assistant Panel

    private var aiAssistantPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // AI Panel Header with glassmorphic styling
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.1))
                            .frame(width: 32, height: 32)
                            .shadow(color: .green.opacity(0.3), radius: 8)

                        Image(systemName: "brain.head.profile.fill")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(.green)
                    }

                    Text("AI Assistant")
                        .font(.tomeHeading())
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: { showAIPanel = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(6)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.05))
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Text("Enhance your writing with AI")
                    .font(.tomeCaption())
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(20)

            // Glassmorphic divider
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.05),
                            Color.green.opacity(0.1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Quick actions
                    quickActionsSection
                }
                .padding(20)
            }

            Spacer()

            // AI input area
            aiInputArea
        }
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.5),
                    Color.green.opacity(0.03)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - AI Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Quick Actions")
                .font(.tomeBodyMedium())
                .foregroundColor(.white.opacity(0.6))

            VStack(spacing: 10) {
                AIActionButton(
                    icon: "doc.text",
                    title: "MLA Template",
                    description: "Generate essay structure"
                ) {
                    requestAITemplate(type: "MLA")
                }

                AIActionButton(
                    icon: "pencil.line",
                    title: "Improve Writing",
                    description: "Enhance clarity and style"
                ) {
                    requestAIImprovement()
                }

                AIActionButton(
                    icon: "textformat.abc",
                    title: "Fix Grammar",
                    description: "Correct errors"
                ) {
                    requestAIGrammarFix()
                }

                AIActionButton(
                    icon: "arrow.up.arrow.down",
                    title: "Change Tone",
                    description: "More formal/casual"
                ) {
                    requestAIToneChange()
                }

                AIActionButton(
                    icon: "arrow.down.left.arrow.up.right",
                    title: "Expand Ideas",
                    description: "Add detail and depth"
                ) {
                    requestAIExpansion()
                }

                AIActionButton(
                    icon: "arrow.up.left.and.arrow.down.right",
                    title: "Condense",
                    description: "Make concise"
                ) {
                    requestAICondense()
                }
            }
        }
    }

    // MARK: - AI Input Area

    private var aiInputArea: some View {
        VStack(spacing: 0) {
            // Glassmorphic divider
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.green.opacity(0.2),
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)

            HStack(alignment: .bottom, spacing: 12) {
                TextField("Ask AI anything...", text: $aiInput, axis: .vertical)
                    .font(.tomeBody())
                    .foregroundColor(.white)
                    .textFieldStyle(PlainTextFieldStyle())
                    .lineLimit(1...3)
                    .disabled(isProcessingAI)

                Button(action: sendCustomAIRequest) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.green.opacity(aiInput.isEmpty ? 0.08 : 0.25),
                                        Color.green.opacity(aiInput.isEmpty ? 0.03 : 0.15)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(aiInput.isEmpty ? 0.1 : 0.2),
                                                Color.green.opacity(aiInput.isEmpty ? 0.1 : 0.3)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: aiInput.isEmpty ? .clear : .green.opacity(0.3), radius: 8)
                            .frame(width: 36, height: 36)

                        if isProcessingAI {
                            ProgressView()
                                .scaleEffect(0.6)
                                .tint(.green)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(aiInput.isEmpty ? .white.opacity(0.3) : .green.opacity(0.9))
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(aiInput.isEmpty || isProcessingAI)
            }
            .padding(18)
        }
    }

    // MARK: - AI Functions

    private func requestAITemplate(type: String) {
        isProcessingAI = true
        let prompt = """
        Generate a \(type) format essay template with proper formatting. Include:
        - All necessary headers and sections
        - Placeholder text in [brackets] where user should fill in
        - Proper formatting and structure
        - Professional and complete

        Return only the template, no explanations.
        """

        aiService.chatCompletion(
            messages: [ChatMessage(role: "user", content: prompt)],
            model: "gpt-3.5-turbo"
        ) { result in
            DispatchQueue.main.async {
                self.isProcessingAI = false
                switch result {
                case .success(let template):
                    // Insert template into current document instead of replacing
                    if self.document.content.isEmpty {
                        self.document.content = template
                    } else {
                        self.document.content += "\n\n" + template
                    }
                    self.autoSaveDocument()
                case .failure(let error):
                    print("❌ AI template generation failed: \(error)")
                }
            }
        }
    }

    private func requestAIImprovement() {
        guard !document.content.isEmpty else { return }
        processAIRequest(
            systemPrompt: "You are a professional writing editor. Improve the user's text for clarity, style, and impact. Return ONLY the improved text.",
            userPrompt: "Improve this text:\n\n\(document.content)"
        )
    }

    private func requestAIGrammarFix() {
        guard !document.content.isEmpty else { return }
        processAIRequest(
            systemPrompt: "You are a grammar expert. Fix all grammar, spelling, and punctuation errors. Return ONLY the corrected text.",
            userPrompt: "Fix grammar and spelling:\n\n\(document.content)"
        )
    }

    private func requestAIToneChange() {
        guard !document.content.isEmpty else { return }
        processAIRequest(
            systemPrompt: "You are a professional writer. Make this text more formal and professional while keeping the same meaning. Return ONLY the rewritten text.",
            userPrompt: "Make this more professional:\n\n\(document.content)"
        )
    }

    private func requestAIExpansion() {
        guard !document.content.isEmpty else { return }
        processAIRequest(
            systemPrompt: "You are a creative writer. Expand on these ideas with more detail, examples, and depth. Return ONLY the expanded text.",
            userPrompt: "Expand these ideas:\n\n\(document.content)"
        )
    }

    private func requestAICondense() {
        guard !document.content.isEmpty else { return }
        processAIRequest(
            systemPrompt: "You are an editor. Make this text more concise while keeping all key points. Return ONLY the condensed text.",
            userPrompt: "Condense this text:\n\n\(document.content)"
        )
    }

    private func sendCustomAIRequest() {
        guard !aiInput.isEmpty else { return }
        let request = aiInput
        aiInput = ""
        isProcessingAI = true

        let prompt = document.content.isEmpty
            ? "You are a helpful writing assistant. Follow the user's instructions exactly. Return ONLY the result, no explanations.\n\nUser request: \(request)"
            : "You are a helpful writing assistant. Follow the user's instructions exactly on the text provided. Return ONLY the modified/generated text, no explanations.\n\nUser request: \(request)\n\nText:\n\n\(document.content)"

        aiService.chatCompletion(
            messages: [ChatMessage(role: "user", content: prompt)],
            model: "gpt-3.5-turbo"
        ) { result in
            DispatchQueue.main.async {
                self.isProcessingAI = false
                switch result {
                case .success(let response):
                    // Insert AI response into current document
                    if self.document.content.isEmpty {
                        self.document.content = response
                    } else {
                        self.document.content = response
                    }
                    self.autoSaveDocument()
                case .failure(let error):
                    print("❌ AI request failed: \(error)")
                }
            }
        }
    }

    private func processAIRequest(systemPrompt: String, userPrompt: String) {
        isProcessingAI = true

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
                case .success(let response):
                    self.document.content = response
                    self.autoSaveDocument()
                case .failure(let error):
                    print("❌ AI request failed: \(error)")
                }
            }
        }
    }

    // MARK: - Helper Functions

    private func autoSaveDocument() {
        documentService.updateDocument(document)
    }

    private func adjustFontSize(_ delta: Double) {
        fontSize = max(12, min(32, fontSize + delta))
    }

    private func insertIndent() {
        document.content += "    "  // 4 spaces
        autoSaveDocument()
    }

    private func removeIndent() {
        if document.content.hasSuffix("    ") {
            document.content = String(document.content.dropLast(4))
            autoSaveDocument()
        }
    }

    private func exportDocument(as type: UTType) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [type]
        savePanel.nameFieldStringValue = "\(document.title).\(type == .plainText ? "txt" : "rtf")"

        if savePanel.runModal() == .OK, let url = savePanel.url {
            try? documentService.exportDocument(document, to: url)
        }
    }

    private func relativeTime(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let seconds = Int(interval)
        if seconds < 60 {
            return "Just now"
        }
        let minutes = Int(interval / 60)
        if minutes < 60 {
            return "\(minutes)m ago"
        }
        let hours = Int(interval / 3600)
        if hours < 24 {
            return "\(hours)h ago"
        }
        let days = Int(interval / 86400)
        return "\(days)d ago"
    }
}

// MARK: - Supporting Views

struct EditorToolButton: View {
    let icon: String
    let size: CGFloat
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .light))
                .foregroundColor(isHovered ? .white.opacity(0.8) : .white.opacity(0.5))
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovered ? Color.white.opacity(0.08) : Color.white.opacity(0.03))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(isHovered ? 0.25 : 0.15),
                                            Color.white.opacity(isHovered ? 0.15 : 0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: .white.opacity(0.1), radius: 2, x: -1, y: -1)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 1, y: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct CategoryPill: View {
    let category: DocumentCategory
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 10, weight: .light))
                Text(category.rawValue)
                    .font(.tomeSmallLabel())
            }
            .foregroundColor(
                isSelected
                    ? category.color.opacity(0.9)
                    : (isHovered ? .white.opacity(0.6) : .white.opacity(0.4))
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? category.color.opacity(0.15) : Color.white.opacity(isHovered ? 0.05 : 0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                LinearGradient(
                                    colors: isSelected ? [
                                        category.color.opacity(0.5),
                                        category.color.opacity(0.2)
                                    ] : [
                                        Color.white.opacity(isHovered ? 0.2 : 0.1),
                                        Color.white.opacity(isHovered ? 0.1 : 0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: isSelected ? category.color.opacity(0.3) : .clear, radius: 6)
                    .shadow(color: .white.opacity(0.05), radius: 2, x: -1, y: -1)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 1, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct AIActionButton: View {
    let icon: String
    let title: String
    let description: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.green.opacity(isHovered ? 0.15 : 0.08),
                                    Color.green.opacity(isHovered ? 0.08 : 0.03)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.green.opacity(isHovered ? 0.4 : 0.2),
                                            Color.green.opacity(isHovered ? 0.2 : 0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: isHovered ? .green.opacity(0.3) : .clear, radius: 8)

                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(.green.opacity(isHovered ? 0.9 : 0.7))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.tomeBody())
                        .foregroundColor(isHovered ? .white.opacity(0.9) : .white.opacity(0.7))

                    Text(description)
                        .font(.tomeCaption())
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .light))
                    .foregroundColor(.white.opacity(isHovered ? 0.4 : 0.2))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered ? Color.white.opacity(0.05) : Color.white.opacity(0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(isHovered ? 0.2 : 0.1),
                                        Color.white.opacity(isHovered ? 0.1 : 0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .white.opacity(0.05), radius: 2, x: -1, y: -1)
                    .shadow(color: .black.opacity(0.2), radius: 3, x: 1, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct MessageRow: View {
    let message: UnifiedMessage
    let isSelected: Bool
    let onTap: () -> Void
    let onStar: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Source icon
                ZStack {
                    Circle()
                        .fill(sourceColor.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: message.source.icon)
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(sourceColor)
                }

                // Message content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(message.sender)
                            .font(.tomeBodyMedium())
                            .foregroundColor(.white.opacity(message.isRead ? 0.6 : 0.9))
                            .lineLimit(1)

                        Spacer()

                        Text(message.timeAgo)
                            .font(.tomeTiny())
                            .foregroundColor(.white.opacity(0.4))
                    }

                    if let subject = message.subject {
                        Text(subject)
                            .font(.tomeBody())
                            .foregroundColor(.white.opacity(message.isRead ? 0.5 : 0.8))
                            .lineLimit(1)
                    }

                    Text(message.preview)
                        .font(.tomeCaption())
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(2)
                }

                // Star button
                Button(action: onStar) {
                    Image(systemName: message.isStarred ? "star.fill" : "star")
                        .font(.system(size: 11, weight: .light))
                        .foregroundColor(message.isStarred ? .yellow.opacity(0.8) : .white.opacity(0.3))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Rectangle()
                    .fill(
                        isSelected
                            ? Color.white.opacity(0.08)
                            : (isHovered ? Color.white.opacity(0.04) : Color.clear)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private var sourceColor: Color {
        switch message.source {
        case .email: return .blue
        case .imessage: return .green
        case .slack: return .purple
        }
    }
}
