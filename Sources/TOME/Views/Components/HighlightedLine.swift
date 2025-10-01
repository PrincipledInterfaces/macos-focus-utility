import SwiftUI

struct HighlightedLine: View {
    let text: String
    let fileExtension: String
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tokenizeLine(text).enumerated()), id: \.offset) { _, token in
                Text(token.text)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(colorForToken(token))
            }
        }
    }
    
    private func tokenizeLine(_ line: String) -> [Token] {
        var tokens: [Token] = []
        let words = line.components(separatedBy: .whitespacesAndNewlines)
        
        for (index, word) in words.enumerated() {
            if !word.isEmpty {
                tokens.append(Token(text: word, type: getTokenType(word)))
            }
            // Add spaces between words (except after last word)
            if index < words.count - 1 {
                tokens.append(Token(text: " ", type: .normal))
            }
        }
        
        return tokens
    }
    
    private func getTokenType(_ word: String) -> TokenType {
        // Check for comments
        if word.hasPrefix("//") || word.hasPrefix("#") {
            return .comment
        }
        
        // Check for strings
        if (word.hasPrefix("\"") && word.hasSuffix("\"")) || (word.hasPrefix("'") && word.hasSuffix("'")) {
            return .string
        }
        
        // Check for keywords
        let keywords = ["func", "var", "let", "if", "else", "for", "while", "class", "struct", "enum", "import", "return", "true", "false", "nil", "self", "def", "print", "function", "const"]
        if keywords.contains(word) {
            return .keyword
        }
        
        // Check for numbers
        if Double(word) != nil {
            return .number
        }
        
        return .normal
    }
    
    private func colorForToken(_ token: Token) -> Color {
        switch token.type {
        case .keyword:
            return Color(red: 0.8, green: 0.4, blue: 1.0) // Purple
        case .string:
            return Color(red: 0.4, green: 0.8, blue: 0.4) // Green
        case .comment:
            return Color(red: 0.6, green: 0.6, blue: 0.6) // Gray
        case .number:
            return Color(red: 1.0, green: 0.6, blue: 0.4) // Orange
        case .normal:
            return .clear // Let underlying text show
        }
    }
}

struct Token {
    let text: String
    let type: TokenType
}

enum TokenType {
    case keyword
    case string
    case comment
    case number
    case normal
}