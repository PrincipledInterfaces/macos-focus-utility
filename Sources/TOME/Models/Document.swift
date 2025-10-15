import Foundation
import SwiftUI

// MARK: - Document Model

struct Document: Identifiable, Codable {
    let id: UUID
    var title: String
    var content: String  // Plain text content
    var attributedContent: AttributedContentData?  // Rich text formatting
    var createdAt: Date
    var modifiedAt: Date
    var tags: [String]
    var category: DocumentCategory

    init(
        id: UUID = UUID(),
        title: String = "Untitled Document",
        content: String = "",
        attributedContent: AttributedContentData? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        tags: [String] = [],
        category: DocumentCategory = .general
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.attributedContent = attributedContent
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.tags = tags
        self.category = category
    }

    var wordCount: Int {
        content.split(separator: " ").count
    }

    var characterCount: Int {
        content.count
    }

    var preview: String {
        let maxLength = 150
        if content.count <= maxLength {
            return content
        }
        let preview = String(content.prefix(maxLength))
        return preview + "..."
    }
}

enum DocumentCategory: String, Codable, CaseIterable {
    case general = "General"
    case essay = "Essay"
    case letter = "Letter"
    case notes = "Notes"
    case creative = "Creative Writing"
    case technical = "Technical"
    case business = "Business"

    var icon: String {
        switch self {
        case .general: return "doc.text"
        case .essay: return "book"
        case .letter: return "envelope"
        case .notes: return "note.text"
        case .creative: return "pencil.and.outline"
        case .technical: return "chevron.left.forwardslash.chevron.right"
        case .business: return "briefcase"
        }
    }

    var color: Color {
        switch self {
        case .general: return .white
        case .essay: return .blue
        case .letter: return .green
        case .notes: return .yellow
        case .creative: return .purple
        case .technical: return .cyan
        case .business: return .orange
        }
    }
}

// MARK: - Text Formatting

struct AttributedContentData: Codable {
    var formattingRanges: [FormatRange]
    var fontSize: Double
    var fontFamily: String

    init(
        formattingRanges: [FormatRange] = [],
        fontSize: Double = 16,
        fontFamily: String = "American Typewriter"
    ) {
        self.formattingRanges = formattingRanges
        self.fontSize = fontSize
        self.fontFamily = fontFamily
    }
}

struct FormatRange: Codable, Identifiable {
    let id: UUID
    let range: Range<Int>
    let format: TextFormat

    init(id: UUID = UUID(), range: Range<Int>, format: TextFormat) {
        self.id = id
        self.range = range
        self.format = format
    }

    enum CodingKeys: String, CodingKey {
        case id, rangeStart, rangeEnd, format
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        let start = try container.decode(Int.self, forKey: .rangeStart)
        let end = try container.decode(Int.self, forKey: .rangeEnd)
        range = start..<end
        format = try container.decode(TextFormat.self, forKey: .format)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(range.lowerBound, forKey: .rangeStart)
        try container.encode(range.upperBound, forKey: .rangeEnd)
        try container.encode(format, forKey: .format)
    }
}

enum TextFormat: String, Codable {
    case bold
    case italic
    case underline
    case heading1
    case heading2
    case heading3
}

// MARK: - Document Service

class DocumentService: ObservableObject {
    @Published var documents: [Document] = []
    @Published var currentDocument: Document?

    private let documentsKey = "tome_writer_documents"
    private let fileManager = FileManager.default

    init() {
        loadDocuments()
    }

    // MARK: - Document Management

    func createDocument(title: String = "Untitled Document", category: DocumentCategory = .general) -> Document {
        let document = Document(title: title, category: category)
        documents.insert(document, at: 0)
        saveDocuments()
        return document
    }

    func updateDocument(_ document: Document) {
        if let index = documents.firstIndex(where: { $0.id == document.id }) {
            var updatedDoc = document
            updatedDoc.modifiedAt = Date()
            documents[index] = updatedDoc

            if currentDocument?.id == document.id {
                currentDocument = updatedDoc
            }

            saveDocuments()
        }
    }

    func deleteDocument(_ document: Document) {
        documents.removeAll { $0.id == document.id }
        if currentDocument?.id == document.id {
            currentDocument = nil
        }
        saveDocuments()
    }

    func selectDocument(_ document: Document) {
        currentDocument = document
    }

    // MARK: - Persistence

    private func loadDocuments() {
        if let data = UserDefaults.standard.data(forKey: documentsKey),
           let decoded = try? JSONDecoder().decode([Document].self, from: data) {
            documents = decoded.sorted { $0.modifiedAt > $1.modifiedAt }
        } else {
            // Create a welcome document for first-time users
            let welcomeDoc = Document(
                title: "Welcome to TOME",
                content: """
                Welcome to the Writer's Desk!

                This is your minimalist writing environment where you can focus on your words without distractions.

                Features:
                • Clean, distraction-free interface
                • AI writing assistance
                • Rich text formatting
                • Automatic saving
                • Document organization

                Start typing to create your first document, or tap the + button to begin a new one.
                """,
                category: .notes
            )
            documents = [welcomeDoc]
            saveDocuments()
        }
    }

    func saveDocuments() {
        if let encoded = try? JSONEncoder().encode(documents) {
            UserDefaults.standard.set(encoded, forKey: documentsKey)
        }
    }

    // MARK: - Export

    func exportDocument(_ document: Document, to url: URL) throws {
        try document.content.write(to: url, atomically: true, encoding: .utf8)
    }
}
