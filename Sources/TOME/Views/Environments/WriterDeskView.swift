import SwiftUI

struct WriterDeskView: View {
    @ObservedObject var currentState: TOMEState
    @StateObject private var documentService = DocumentService()
    @StateObject private var aiService = OpenAIService()
    @State private var selectedDocument: Document?
    @State private var showEditor = false

    let onNavigateHome: () -> Void

    init(currentState: TOMEState, onNavigateHome: @escaping () -> Void = {}) {
        self.currentState = currentState
        self.onNavigateHome = onNavigateHome
    }

    var body: some View {
        ZStack {
            if !showEditor {
                // Document selection screen
                DocumentSelectionView(
                    documentService: documentService,
                    onSelectDocument: { document in
                        selectedDocument = document
                        showEditor = true
                    },
                    onNavigateHome: onNavigateHome
                )
            } else if let document = selectedDocument {
                // Text editor screen
                TextEditorView(
                    documentService: documentService,
                    document: Binding(
                        get: { document },
                        set: { newValue in
                            selectedDocument = newValue
                            documentService.updateDocument(newValue)
                        }
                    ),
                    aiService: aiService,
                    onBack: {
                        showEditor = false
                        selectedDocument = nil
                    },
                    onNavigateHome: onNavigateHome
                )
            }
        }
        .environmentObject(documentService)
        .onAppear {
            // Register notification observer for AI agent integration
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("AIInsertTextToWriter"),
                object: nil,
                queue: .main
            ) { notification in
                if let text = notification.object as? String {
                    insertAIGeneratedText(text)
                }
            }
        }
    }

    // MARK: - AI Integration

    private func insertAIGeneratedText(_ text: String) {
        if var document = selectedDocument {
            // Insert AI-generated text into current document
            if document.content.isEmpty {
                document.content = text
            } else {
                document.content += "\n\n" + text
            }
            selectedDocument = document
            documentService.updateDocument(document)
        } else {
            // Create new document with AI-generated content
            let newDoc = documentService.createDocument(title: "AI Generated Document", category: .general)
            var updatedDoc = newDoc
            updatedDoc.content = text
            documentService.updateDocument(updatedDoc)
            selectedDocument = updatedDoc
            showEditor = true
        }
    }
}
