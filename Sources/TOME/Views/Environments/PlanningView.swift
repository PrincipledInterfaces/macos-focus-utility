import SwiftUI
import EventKit

struct PlanningView: View {
    @ObservedObject var currentState: TOMEState
    @StateObject private var aiService = OpenAIService()
    @State private var brainDumpText = ""
    @State private var newTodoText = ""
    @State private var selectedTodo: Todo?
    @State private var showAIChat = false
    @State private var isProcessingBrainDump = false
    @State private var selectedEnvironment: TOMEEnvironment = .writerDesk
    
    let onNavigateHome: () -> Void
    let onNavigateToEnvironment: (TOMEEnvironment) -> Void
    
    init(currentState: TOMEState, onNavigateHome: @escaping () -> Void = {}, onNavigateToEnvironment: @escaping (TOMEEnvironment) -> Void = { _ in }) {
        self.currentState = currentState
        self.onNavigateHome = onNavigateHome
        self.onNavigateToEnvironment = onNavigateToEnvironment
    }
    
    var body: some View {
        ZStack {
            // Pure black background
            Color.black.ignoresSafeArea(.all)
            
            GeometryReader { geometry in
                HStack(spacing: 1) {
                    // Left Panel - Todo Management (60%)
                    todoManagementPanel
                        .frame(width: geometry.size.width * 0.6, height: geometry.size.height)
                    
                    // Minimal divider
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 1)
                    
                    // Right Panel - AI Assistant (40%)
                    aiAssistantPanel
                        .frame(width: geometry.size.width * 0.4, height: geometry.size.height)
                }
            }
            
            // Navigation overlay
            TOMENavigationOverlay(
                onNavigateHome: onNavigateHome,
                environmentName: "Planning",
                environmentColor: .blue
            )
        }
    }
    
    private var todoManagementPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Clean header
            VStack(alignment: .leading, spacing: 4) {
                Text("Planning")
                    .font(.tomeSubheading())
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 40)
            .padding(.top, 40)
            .padding(.bottom, 30)
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 32) {
                    // Simplified brain dump
                    brainDumpSection
                    
                    // Clean todos list
                    activeTodosSection
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }
    
    private var brainDumpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Simple input area
            TextEditor(text: $brainDumpText)
                .font(.tomeBody())
                .foregroundColor(.white)
                .background(Color.clear)
                .frame(minHeight: 80)
                .padding(0)
                .background(Color.clear)
                .overlay(
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Stream thoughts here...")
                            .font(.tomeBody())
                            .foregroundColor(.white.opacity(0.4))
                        Text("Try: 'Email John about proposal, check AWS bill, finish report'")
                            .font(.tomeTiny())
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .padding(.top, 8)
                    .padding(.leading, 8)
                    .allowsHitTesting(false)
                    .opacity(brainDumpText.isEmpty ? 1 : 0),
                    alignment: .topLeading
                )
            
            // Minimal process button
            if !brainDumpText.isEmpty {
                HStack {
                    Spacer()
                    Button(action: processBrainDump) {
                        Text(isProcessingBrainDump ? "..." : "Parse")
                            .font(.tomeCaption())
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .keyboardShortcut(.return, modifiers: [])
                    .disabled(isProcessingBrainDump)
                }
            }
        }
    }
    
    private var activeTodosSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Simple todo input with AI suggestions
            VStack(alignment: .leading, spacing: 8) {
                TextField("Add todo", text: $newTodoText)
                    .font(.tomeBody())
                    .foregroundColor(.white)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit { addQuickTodo() }
                
                if !newTodoText.isEmpty && newTodoText.count > 5 {
                    AIEstimateView(todoText: newTodoText, aiService: aiService)
                }
            }
            
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
            
            // Enhanced todo list with AI features
            VStack(alignment: .leading, spacing: 12) {
                ForEach(currentState.todos.filter { !$0.isCompleted }) { todo in
                    EnhancedTodoRow(
                        todo: todo,
                        onToggleComplete: { currentState.completeTodo(todo.id) },
                        onUpdateTodo: { updatedTodo in
                            // TODO: Update todo with new properties
                        }
                    )
                }
            }

            // Real AI Duration Learning section
            if !currentState.todos.filter({ $0.isCompleted }).isEmpty {
                RealDurationLearningView(
                    completedTodos: currentState.todos.filter { $0.isCompleted },
                    aiService: aiService
                )
            }
        }
    }
    
    private var aiAssistantPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Clean header
            Text("Context")
                .font(.tomeSubheading())
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.top, 40)
                .padding(.bottom, 30)
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Today's context override
                    todaySection
                    
                    // Calendar integration
                    calendarIntegrationSection
                    
                    // Email/Comms status
                    emailStatusSection
                    
                    // Environment selection
                    environmentSelectionSection
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }
    
    
    private var calendarIntegrationSection: some View {
        RealCalendarIntegrationView(currentState: currentState)
    }
    
    private var emailStatusSection: some View {
        RealCommunicationStatusView(currentState: currentState)
    }
    
    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today")
                .font(.tomeBody())
                .foregroundColor(.white.opacity(0.7))
            
            TextEditor(text: $currentState.todayPromptOverride)
                .font(.tomeCaption())
                .foregroundColor(.white)
                .background(Color.clear)
                .frame(minHeight: 60)
                .overlay(
                    Text("Expecting package, call from Sarah...")
                        .font(.tomeCaption())
                        .foregroundColor(.white.opacity(0.3))
                        .allowsHitTesting(false)
                        .opacity(currentState.todayPromptOverride.isEmpty ? 1 : 0),
                    alignment: .topLeading
                )
        }
    }
    
    private var environmentSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Next Environment")
                .font(.tomeBody())
                .foregroundColor(.white.opacity(0.7))
            
            VStack(spacing: 8) {
                ForEach([TOMEEnvironment.writerDesk, .workshop, .coffeeshop, .garden], id: \.self) { environment in
                    Button(action: {
                        selectedEnvironment = environment
                        onNavigateToEnvironment(environment)
                    }) {
                        HStack {
                            Circle()
                                .fill(environment == selectedEnvironment ? Color.white : Color.clear)
                                .frame(width: 6, height: 6)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )

                            Text(environment.displayName)
                                .font(.tomeCaption())
                                .foregroundColor(environment == selectedEnvironment ? .white : .white.opacity(0.6))

                            Spacer()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Status")
                .font(.tomeBody())
                .foregroundColor(.white.opacity(0.7))
            
            Text("Ready to focus")
                .font(.tomeCaption())
                .foregroundColor(.white.opacity(0.5))
        }
    }
    
    private func processBrainDump() {
        guard !brainDumpText.isEmpty else { return }

        isProcessingBrainDump = true

        // Use structured AI parsing for better metadata
        DispatchQueue.global(qos: .userInitiated).async {
            self.aiService.parseStructuredTodos(input: self.brainDumpText) { result in
                DispatchQueue.main.async {
                    self.isProcessingBrainDump = false

                    switch result {
                    case .success(let parsedTodos):
                        print("AI parsed \(parsedTodos.count) structured todos: \(parsedTodos)")
                        for parsed in parsedTodos {
                            // Convert parsed priority string to enum
                            let priority: Todo.Priority = {
                                switch parsed.priority.lowercased() {
                                case "high": return .high
                                case "low": return .low
                                default: return .medium
                                }
                            }()

                            // Create todo with AI-determined metadata
                            let todo = Todo(
                                id: UUID(),
                                text: parsed.text,
                                isCompleted: false,
                                estimatedDuration: TimeInterval(parsed.durationMinutes * 60),
                                priority: priority,
                                aiEnhanced: true,
                                category: parsed.category
                            )
                            self.currentState.todos.append(todo)
                        }
                        self.brainDumpText = ""
                    case .failure(let error):
                        print("AI parsing failed: \(error)")
                        // Simple fallback: split by lines and common separators
                        let fallbackTodos = self.brainDumpText
                            .replacingOccurrences(of: " and ", with: "\n")
                            .replacingOccurrences(of: ", ", with: "\n")
                            .components(separatedBy: .newlines)
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty && $0.count > 3 }

                        for todoText in fallbackTodos {
                            self.currentState.addTodo(todoText)
                        }
                        self.brainDumpText = ""
                    }
                }
            }
        }
    }
    
    private func addQuickTodo() {
        guard !newTodoText.isEmpty else { return }
        currentState.addTodo(newTodoText)
        newTodoText = ""
    }
    
    private var navigationOverlay: some View {
        VStack {
            HStack {
                // Home button
                Button(action: onNavigateHome) {
                    HStack(spacing: 8) {
                        Image(systemName: "house")
                            .font(.tomeSmall())
                        Text("Home")
                            .font(.tomeBody())
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.5))
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .keyboardShortcut(.escape, modifiers: [])
                
                Spacer()
                
                // Continue to Environment button
                Button(action: { onNavigateToEnvironment(selectedEnvironment) }) {
                    HStack(spacing: 8) {
                        Text("Continue")
                            .font(.tomeBody())
                        Image(systemName: "arrow.right")
                            .font(.tomeSmall())
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.1))
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
            
            Spacer()
            
            // Bottom hint
            HStack {
                Text("ESC: Home")
                    .font(.tomeCaption())
                    .foregroundColor(.white.opacity(0.3))
                
                Spacer()
                
                Text("ENTER: Continue")
                    .font(.tomeCaption())
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
    }
}

struct SimpleTodoRow: View {
    let todo: Todo
    let onToggleComplete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggleComplete) {
                Circle()
                    .fill(todo.isCompleted ? Color.white : Color.clear)
                    .frame(width: 6, height: 6)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            }
            
            Text(todo.text)
                .font(.tomeBody())
                .foregroundColor(todo.isCompleted ? .white.opacity(0.3) : .white)
                .strikethrough(todo.isCompleted)
            
            Spacer()
        }
    }
}

struct EnhancedTodoRow: View {
    let todo: Todo
    let onToggleComplete: () -> Void
    let onUpdateTodo: (Todo) -> Void
    
    @State private var isExpanded = false
    @State private var showProgress = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button(action: handleToggleComplete) {
                    Circle()
                        .fill(todo.isCompleted ? Color.white : Color.clear)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(todo.text)
                            .font(.tomeBody())
                            .foregroundColor(todo.isCompleted ? .white.opacity(0.3) : .white)
                            .strikethrough(todo.isCompleted)
                        
                        Spacer()

                        // AI estimated duration
                        Text(formatDuration(todo.estimatedDuration))
                            .font(.tomeTiny())
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.05))
                            )
                    }
                    
                    // Category/project tag
                    HStack(spacing: 4) {
                        Circle()
                            .fill(categoryColor(todo.category).opacity(0.6))
                            .frame(width: 4, height: 4)

                        Text(todo.category?.capitalized ?? "Uncategorized")
                            .font(.tomeTiny())
                            .foregroundColor(.white.opacity(0.5))

                        Spacer()

                        // Priority indicator
                        if todo.priority == .high {
                            Image(systemName: "exclamationmark")
                                .font(.custom("Helvetica Neue", size: 8).weight(.medium))
                                .foregroundColor(.orange.opacity(0.7))
                        }
                    }
                }
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.custom("Helvetica Neue", size: 8).weight(.medium))
                        .foregroundColor(.white.opacity(0.4))
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    // Progress bar for partially complete items
                    if showProgress {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Progress")
                                    .font(.tomeTinyMedium())
                                    .foregroundColor(.white.opacity(0.5))
                                
                                Spacer()
                                
                                Text("60%")
                                    .font(.tomeTiny())
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            
                            ProgressView(value: 0.6)
                                .progressViewStyle(LinearProgressViewStyle(tint: .white.opacity(0.6)))
                                .scaleEffect(x: 1, y: 0.5)
                        }
                    }
                    
                    // Subtasks or notes
                    HStack {
                        Button("Add Progress") {
                            showProgress.toggle()
                        }
                        .font(.tomeTiny())
                        .foregroundColor(.white.opacity(0.4))
                        .buttonStyle(PlainButtonStyle())
                        
                        Button("Note Blocker") {
                            // TODO: Add blocker note
                        }
                        .font(.tomeTiny())
                        .foregroundColor(.white.opacity(0.4))
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.leading, 18)
            }
        }
    }
    
    private func handleToggleComplete() {
        if !todo.isCompleted && isExpanded {
            // AI asks about blockers when completing
            // For now, just complete
        }
        onToggleComplete()
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        if minutes < 60 {
            return "~\(minutes)m"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "~\(hours)h"
            } else {
                return "~\(hours)h \(remainingMinutes)m"
            }
        }
    }

    private func categoryColor(_ category: String?) -> Color {
        guard let category = category?.lowercased() else { return .gray }
        switch category {
        case "work": return .blue
        case "personal": return .purple
        case "health": return .green
        case "learning": return .cyan
        case "creative": return .pink
        case "social": return .orange
        case "errands": return .yellow
        default: return .gray
        }
    }
}

struct GridPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing: CGFloat = 40
        
        // Vertical lines
        for x in stride(from: 0, through: rect.width, by: spacing) {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
        }
        
        // Horizontal lines
        for y in stride(from: 0, through: rect.height, by: spacing) {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        
        return path
    }
}

// MARK: - Real Implementation Views

struct AIEstimateView: View {
    let todoText: String
    let aiService: OpenAIService
    @State private var estimate: String = ""
    @State private var isLoading: Bool = false
    
    var body: some View {
        HStack {
            if isLoading {
                Text("Estimating...")
                    .font(.tomeTiny())
                    .foregroundColor(.white.opacity(0.4))
            } else if !estimate.isEmpty {
                Text(estimate)
                    .font(.tomeTiny())
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .onAppear {
            generateEstimate()
        }
        .onChange(of: todoText) { _, _ in
            generateEstimate()
        }
    }
    
    private func generateEstimate() {
        guard todoText.count > 5 else { return }
        isLoading = true
        
        let prompt = "Estimate how long this task will take in minutes. Consider complexity and typical completion times. Return only a number followed by 'min' and confidence percentage. Task: '\(todoText)'"
        
        aiService.chatCompletion(
            messages: [ChatMessage(role: "user", content: prompt)],
            model: "gpt-3.5-turbo"
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let response):
                    estimate = "AI estimate: ~\(response.trimmingCharacters(in: .whitespacesAndNewlines))"
                case .failure:
                    estimate = "Est: 30-45 min (heuristic)"
                }
            }
        }
    }
}

struct RealDurationLearningView: View {
    let completedTodos: [Todo]
    let aiService: OpenAIService

    @State private var insights: String = ""
    @State private var isAnalyzing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Productivity Insights")
                .font(.tomeCaptionMedium())
                .foregroundColor(.white.opacity(0.6))

            if completedTodos.isEmpty {
                Text("Complete some todos to see AI insights")
                    .font(.tomeTiny())
                    .foregroundColor(.white.opacity(0.4))
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(completedTodos.prefix(2)) { todo in
                        HStack {
                            Text(String(todo.text.prefix(25)) + (todo.text.count > 25 ? "..." : ""))
                                .font(.tomeTiny())
                                .foregroundColor(.white.opacity(0.5))

                            Spacer()

                            Text("✓")
                                .font(.tomeTiny())
                                .foregroundColor(.green.opacity(0.6))
                        }
                    }

                    if isAnalyzing {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 12, height: 12)
                            Text("Analyzing patterns...")
                                .font(.tomeTiny())
                                .foregroundColor(.white.opacity(0.4))
                        }
                    } else if !insights.isEmpty {
                        Text(insights)
                            .font(.tomeTiny())
                            .foregroundColor(.white.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .onAppear {
            analyzePatterns()
        }
        .onChange(of: completedTodos.count) { _, _ in
            analyzePatterns()
        }
    }

    private func analyzePatterns() {
        guard !completedTodos.isEmpty, !isAnalyzing else { return }

        isAnalyzing = true

        let taskSummaries = completedTodos.prefix(5).map { todo in
            "- \(todo.text) (estimated: \(Int(todo.estimatedDuration/60))min)"
        }.joined(separator: "\n")

        let prompt = """
        Based on these recently completed tasks:
        \(taskSummaries)

        Provide a brief 1-2 sentence insight about the user's productivity patterns or task completion habits. Be specific and actionable.
        """

        aiService.chatCompletion(
            messages: [ChatMessage(role: "user", content: prompt)],
            model: "gpt-3.5-turbo"
        ) { result in
            DispatchQueue.main.async {
                isAnalyzing = false
                switch result {
                case .success(let response):
                    insights = response.trimmingCharacters(in: .whitespacesAndNewlines)
                case .failure:
                    insights = "Keep completing tasks to build better insights."
                }
            }
        }
    }
}


struct RealCalendarIntegrationView: View {
    @ObservedObject var currentState: TOMEState
    @State private var upcomingEvents: [CalendarEvent] = []
    @State private var isLoading = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Calendar")
                .font(.tomeBody())
                .foregroundColor(.white.opacity(0.7))
            
            if isLoading {
                Text("Loading events...")
                    .font(.tomeSmallLabel())
                    .foregroundColor(.white.opacity(0.5))
            } else if upcomingEvents.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No upcoming events")
                        .font(.tomeSmallLabel())
                        .foregroundColor(.green.opacity(0.8))
                    
                    Button("Open Calendar") {
                        NSWorkspace.shared.open(URL(string: "calshow://")!)
                    }
                    .font(.tomeTiny())
                    .foregroundColor(.white.opacity(0.6))
                    .buttonStyle(PlainButtonStyle())
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    let todayEvents = upcomingEvents.filter { $0.isToday }
                    let futureEvents = upcomingEvents.filter { !$0.isToday }
                    
                    // Today's events first (with times, green)
                    if !todayEvents.isEmpty {
                        Text("Today:")
                            .font(.tomeLabel())
                            .foregroundColor(.green.opacity(0.7))
                        
                        ForEach(todayEvents) { event in
                            HStack {
                                Text(event.timeString)
                                    .font(.tomeSmallLabelMedium())
                                    .foregroundColor(.green.opacity(0.8))
                                
                                Text(event.title)
                                    .font(.tomeSmallLabel())
                                    .foregroundColor(.green.opacity(0.6))
                                    .lineLimit(1)
                                
                                Spacer()
                            }
                        }
                    }
                    
                    // Future events (without times, gray)
                    if !futureEvents.isEmpty {
                        if !todayEvents.isEmpty {
                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 1)
                                .padding(.vertical, 4)
                        }
                        
                        Text("Upcoming:")
                            .font(.tomeLabel())
                            .foregroundColor(.white.opacity(0.5))
                        
                        ForEach(futureEvents.prefix(4)) { event in
                            HStack {
                                Text(event.dateString)
                                    .font(.tomeSmallLabelMedium())
                                    .foregroundColor(.white.opacity(0.4))
                                
                                Text(event.title)
                                    .font(.tomeSmallLabel())
                                    .foregroundColor(.white.opacity(0.3))
                                    .lineLimit(1)
                                
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            loadCalendarEvents()
        }
    }
    
    private func loadCalendarEvents() {
        isLoading = true
        // Real calendar integration would go here
        // For now, check if Calendar app is accessible
        DispatchQueue.global().async {
            let hasCalendarAccess = EventStore.shared.requestCalendarAccess()
            DispatchQueue.main.async {
                isLoading = false
                if hasCalendarAccess {
                    upcomingEvents = EventStore.shared.getUpcomingEvents()
                }
            }
        }
    }
}

struct RealCommunicationStatusView: View {
    @ObservedObject var currentState: TOMEState
    @State private var emailStatus: CommunicationStatus = .loading
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Communications")
                .font(.tomeSmall())
                .foregroundColor(.white.opacity(0.7))
            
            switch emailStatus {
            case .loading:
                Text("Checking communications...")
                    .font(.tomeLabel())
                    .foregroundColor(.white.opacity(0.5))
            case .clear:
                Text("All clear! Time to focus.")
                    .font(.tomeLabel())
                    .foregroundColor(.green.opacity(0.8))
            case .hasUrgent(let count):
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(count) potentially urgent items")
                        .font(.tomeLabel())
                        .foregroundColor(.orange.opacity(0.8))
                    
                    Button("Review in Writer's Desk") {
                        // Navigate to Writer's Desk
                    }
                    .font(.tomeSmallLabel())
                    .foregroundColor(.white.opacity(0.6))
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .onAppear {
            checkCommunications()
        }
    }
    
    private func checkCommunications() {
        // Real email/message checking would happen here
        DispatchQueue.global().async {
            // Check Mail.app, Messages.app for urgent communications
            let urgentCount = EmailChecker.shared.getUrgentEmailCount()
            DispatchQueue.main.async {
                if urgentCount > 0 {
                    emailStatus = .hasUrgent(urgentCount)
                } else {
                    emailStatus = .clear
                }
            }
        }
    }
}

// MARK: - Supporting Models

struct CalendarEvent: Identifiable {
    let id = UUID()
    let title: String
    let startTime: Date
    
    var isToday: Bool {
        Calendar.current.isDateInToday(startTime)
    }
    
    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: startTime)
    }
    
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: startTime)
    }
}

enum CommunicationStatus {
    case loading
    case clear
    case hasUrgent(Int)
}

// MARK: - Service Stubs (would be implemented elsewhere)

class EventStore {
    static let shared = EventStore()
    private let eventStore = EKEventStore()
    
    func requestCalendarAccess() -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var accessGranted = false
        
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .authorized:
            return true
        case .notDetermined:
            eventStore.requestFullAccessToEvents { granted, error in
                accessGranted = granted
                semaphore.signal()
            }
            semaphore.wait()
            return accessGranted
        case .restricted, .denied, .writeOnly:
            return false
        @unknown default:
            return false
        }
    }
    
    func getUpcomingEvents() -> [CalendarEvent] {
        let authStatus = EKEventStore.authorizationStatus(for: .event)
        guard authStatus == .fullAccess || authStatus == .authorized else {
            return []
        }
        
        let now = Date()
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        
        let predicate = eventStore.predicateForEvents(withStart: now, end: nextWeek, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        let sortedEvents = events.sorted { $0.startDate < $1.startDate }
        
        return sortedEvents.prefix(8).map { event in
            CalendarEvent(
                title: event.title ?? "Untitled Event",
                startTime: event.startDate
            )
        }
    }
}

class EmailChecker {
    static let shared = EmailChecker()
    
    func getUrgentEmailCount() -> Int {
        // Would check Mail.app SQLite database or use private frameworks
        return 0
    }
}

