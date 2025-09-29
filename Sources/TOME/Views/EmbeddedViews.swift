import SwiftUI

// Embedded versions of environment views without navigation overlays
// These are used in the 3-pane layout where navigation is handled by the layout itself

struct EmbeddedPlanningView: View {
    @ObservedObject var currentState: TOMEState
    @StateObject private var aiService = OpenAIService()
    @State private var brainDumpText = ""
    @State private var newTodoText = ""
    @State private var selectedTodo: Todo?
    @State private var isProcessingBrainDump = false
    
    var body: some View {
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
        .background(Color.black)
    }
    
    private var todoManagementPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Clean header
            VStack(alignment: .leading, spacing: 4) {
                Text("Planning")
                    .font(.tomeHeading())
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
                    .disabled(isProcessingBrainDump)
                }
            }
        }
    }
    
    private var activeTodosSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Simple todo input
            TextField("Add todo", text: $newTodoText)
                .font(.tomeBody())
                .foregroundColor(.white)
                .textFieldStyle(PlainTextFieldStyle())
                .onSubmit { addQuickTodo() }
            
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
            
            // Clean todo list
            VStack(alignment: .leading, spacing: 12) {
                ForEach(currentState.todos.filter { !$0.isCompleted }) { todo in
                    SimpleTodoRow(
                        todo: todo,
                        onToggleComplete: { currentState.completeTodo(todo.id) }
                    )
                }
            }
        }
    }
    
    private var aiAssistantPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Clean header
            Text("Assistant")
                .font(.tomeHeading())
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.top, 40)
                .padding(.bottom, 30)
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Simplified metaprompt
                    metapromptSection
                    
                    // Today's context
                    todaySection
                    
                    // Status
                    statusSection
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }
    
    private var metapromptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rules")
                .font(.tomeBody())
                .foregroundColor(.white.opacity(0.7))
            
            TextEditor(text: $currentState.notificationMetaprompt)
                .font(.tomeCaption())
                .foregroundColor(.white)
                .background(Color.clear)
                .frame(minHeight: 100)
        }
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
        
        // Use AI parsing directly - no manual fallback
        DispatchQueue.global(qos: .userInitiated).async {
            self.aiService.parseNaturalLanguageTodos(input: self.brainDumpText) { result in
                DispatchQueue.main.async {
                    self.isProcessingBrainDump = false
                    
                    switch result {
                    case .success(let aiTodos):
                        for todoText in aiTodos {
                            self.currentState.addTodo(todoText)
                        }
                        self.brainDumpText = ""
                    case .failure(let error):
                        print("AI parsing failed: \(error)")
                        // Simple fallback
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
}

// Simplified embedded views for other environments
struct EmbeddedWriterDeskView: View {
    @ObservedObject var currentState: TOMEState
    
    var body: some View {
        VStack {
            Text("Writer's Desk")
                .font(.tomeHeading())
                .foregroundColor(.white)
            
            Text("Communication & Writing")
                .font(.tomeBody())
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

struct EmbeddedWorkshopView: View {
    @ObservedObject var currentState: TOMEState
    
    var body: some View {
        VStack {
            Text("Workshop")
                .font(.tomeHeading())
                .foregroundColor(.white)
            
            Text("Build & Create")
                .font(.tomeBody())
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

struct EmbeddedCoffeeshopView: View {
    @ObservedObject var currentState: TOMEState
    
    var body: some View {
        VStack {
            Text("Coffeeshop")
                .font(.tomeHeading())
                .foregroundColor(.white)
            
            Text("Research & Exploration")
                .font(.tomeBody())
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

struct EmbeddedGardenView: View {
    @ObservedObject var currentState: TOMEState
    
    var body: some View {
        VStack {
            Text("Garden")
                .font(.tomeHeading())
                .foregroundColor(.white)
            
            Text("Rest & Reflection")
                .font(.tomeBody())
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}