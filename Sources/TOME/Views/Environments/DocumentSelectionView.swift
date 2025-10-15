import SwiftUI

struct DocumentSelectionView: View {
    @ObservedObject var documentService: DocumentService
    let onSelectDocument: (Document) -> Void
    let onNavigateHome: () -> Void

    @State private var hoveredDocumentId: UUID?

    var body: some View {
        ZStack {
            // Background similar to home screen
            Color.black.ignoresSafeArea(.all)

            VStack(spacing: 0) {
                // Header
                header

                // Document grid
                ScrollView(showsIndicators: false) {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 280, maximum: 320), spacing: 24)
                        ],
                        spacing: 24
                    ) {
                        // Create new document card (always first)
                        createNewDocumentCard

                        // Recent documents
                        ForEach(documentService.documents) { document in
                            documentCard(document)
                        }
                    }
                    .padding(.horizontal, 60)
                    .padding(.top, 40)
                    .padding(.bottom, 80)
                }
            }

            // Navigation overlay
            TOMENavigationOverlay(
                onNavigateHome: onNavigateHome,
                environmentName: "Writer's Desk",
                environmentColor: .green
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.green.opacity(0.8))

                Text("Writer's Desk")
                    .font(.tomeTitle())
                    .foregroundColor(.white)

                Spacer()

                Text("\(documentService.documents.count) documents")
                    .font(.tomeBody())
                    .foregroundColor(.white.opacity(0.5))
            }

            Text("Select a document to continue writing, or create a new one")
                .font(.tomeBody())
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 60)
        .padding(.top, 60)
        .padding(.bottom, 20)
    }

    // MARK: - Create New Document Card

    private var createNewDocumentCard: some View {
        Button(action: {
            let newDoc = documentService.createDocument()
            onSelectDocument(newDoc)
        }) {
            VStack(spacing: 16) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.green.opacity(0.3),
                                    Color.green.opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)

                    Image(systemName: "plus")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(.green.opacity(0.9))
                }

                Text("Create New Document")
                    .font(.tomeBodyMedium())
                    .foregroundColor(.white.opacity(0.8))

                Spacer()
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.03),
                                Color.white.opacity(0.01)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.green.opacity(0.3),
                                        Color.green.opacity(0.1)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(hoveredDocumentId == UUID(uuidString: "new-doc") ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hoveredDocumentId)
        .onHover { isHovered in
            hoveredDocumentId = isHovered ? UUID(uuidString: "new-doc") : nil
        }
    }

    // MARK: - Document Card

    private func documentCard(_ document: Document) -> some View {
        Button(action: {
            onSelectDocument(document)
        }) {
            VStack(alignment: .leading, spacing: 0) {
                // Document preview area
                VStack(alignment: .leading, spacing: 8) {
                    // Category badge
                    HStack(spacing: 6) {
                        Image(systemName: document.category.icon)
                            .font(.system(size: 10))
                            .foregroundColor(document.category.color.opacity(0.8))

                        Text(document.category.rawValue)
                            .font(.tomeSmallLabel())
                            .foregroundColor(document.category.color.opacity(0.8))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(document.category.color.opacity(0.1))
                    )

                    Spacer().frame(height: 8)

                    // Preview text
                    Text(document.preview)
                        .font(.custom("American Typewriter", size: 12))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 80)
                }
                .padding(16)
                .frame(height: 140)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.04),
                            Color.white.opacity(0.02)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Document info
                VStack(alignment: .leading, spacing: 6) {
                    Text(document.title)
                        .font(.tomeBodyMedium())
                        .foregroundColor(.white)
                        .lineLimit(1)

                    HStack {
                        Text("\(document.wordCount) words")
                            .font(.tomeSmallLabel())
                            .foregroundColor(.white.opacity(0.5))

                        Text("•")
                            .font(.tomeSmallLabel())
                            .foregroundColor(.white.opacity(0.3))

                        Text(relativeTime(from: document.modifiedAt))
                            .font(.tomeSmallLabel())
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.05),
                                Color.white.opacity(0.02)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                hoveredDocumentId == document.id
                                    ? Color.green.opacity(0.4)
                                    : Color.white.opacity(0.1),
                                lineWidth: hoveredDocumentId == document.id ? 1.5 : 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(hoveredDocumentId == document.id ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hoveredDocumentId)
        .onHover { isHovered in
            hoveredDocumentId = isHovered ? document.id : nil
        }
        .contextMenu {
            Button("Duplicate") {
                duplicateDocument(document)
            }

            Button("Export...") {
                exportDocument(document)
            }

            Divider()

            Button("Delete", role: .destructive) {
                deleteDocument(document)
            }
        }
    }

    // MARK: - Helper Functions

    private func relativeTime(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)

        if minutes < 1 {
            return "Just now"
        } else if minutes < 60 {
            return "\(minutes)m ago"
        } else if hours < 24 {
            return "\(hours)h ago"
        } else if days < 7 {
            return "\(days)d ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }

    private func duplicateDocument(_ document: Document) {
        let duplicate = Document(
            title: "\(document.title) (Copy)",
            content: document.content,
            category: document.category
        )
        documentService.documents.insert(duplicate, at: 0)
        documentService.saveDocuments()
    }

    private func exportDocument(_ document: Document) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "\(document.title).txt"

        if savePanel.runModal() == .OK, let url = savePanel.url {
            try? documentService.exportDocument(document, to: url)
        }
    }

    private func deleteDocument(_ document: Document) {
        withAnimation {
            documentService.deleteDocument(document)
        }
    }
}
