import SwiftUI
import AppKit

/// A proper NSTextView-based code editor that actually works
struct ProperCodeEditor: NSViewRepresentable {
    @Binding var text: String
    let fileExtension: String
    let onTextChange: (String) -> Void
    let onCursorChange: (Int, String) -> Void // position, current line
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = CodeTextView()
        
        // Configure text view
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = NSColor.white
        textView.backgroundColor = NSColor.clear
        textView.insertionPointColor = NSColor.white
        
        // Configure text container for proper layout
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 8
        textView.textContainerInset = NSSize(width: 8, height: 8)
        
        // Enable line numbers and syntax highlighting
        textView.delegate = context.coordinator
        textView.onTextChange = onTextChange
        textView.onCursorChange = onCursorChange
        textView.fileExtension = fileExtension
        
        // Configure scroll view
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.scrollerStyle = .overlay
        
        // Set initial text
        textView.string = text
        textView.applySyntaxHighlighting()
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? CodeTextView else { return }
        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            textView.applySyntaxHighlighting()
            // Restore cursor position
            textView.setSelectedRange(selectedRange)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        let parent: ProperCodeEditor
        
        init(_ parent: ProperCodeEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? CodeTextView else { return }
            
            // Update text binding
            parent.text = textView.string
            parent.onTextChange(textView.string)
            
            // Apply syntax highlighting
            textView.applySyntaxHighlighting()
            
            // Get cursor position and current line
            let cursorPosition = textView.selectedRange().location
            let currentLine = textView.getCurrentLine()
            parent.onCursorChange(cursorPosition, currentLine)
        }
    }
}

/// Custom NSTextView with syntax highlighting and line tracking
class CodeTextView: NSTextView {
    var onTextChange: ((String) -> Void)?
    var onCursorChange: ((Int, String) -> Void)?
    var fileExtension: String = ""
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupEditor()
    }
    
    private func setupEditor() {
        // Configure for code editing
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isContinuousSpellCheckingEnabled = false
        isGrammarCheckingEnabled = false
    }
    
    func getCurrentLine() -> String {
        let cursorPosition = selectedRange().location
        let text = string
        
        // Find start of current line
        var lineStart = text.startIndex
        var currentIndex = text.startIndex
        var charCount = 0
        
        for char in text {
            if charCount == cursorPosition {
                break
            }
            if char == "\n" {
                lineStart = text.index(after: currentIndex)
            }
            currentIndex = text.index(after: currentIndex)
            charCount += 1
        }
        
        // Find end of current line
        var lineEnd = text.endIndex
        currentIndex = lineStart
        
        while currentIndex < text.endIndex {
            if text[currentIndex] == "\n" {
                lineEnd = currentIndex
                break
            }
            currentIndex = text.index(after: currentIndex)
        }
        
        return String(text[lineStart..<lineEnd])
    }
    
    func getCursorPositionInLine() -> Int {
        let cursorPosition = selectedRange().location
        let text = string
        
        // Count characters from start of line to cursor
        var lineStart = 0
        var currentPos = 0
        
        for char in text {
            if currentPos == cursorPosition {
                break
            }
            if char == "\n" {
                lineStart = currentPos + 1
            }
            currentPos += 1
        }
        
        return cursorPosition - lineStart
    }
    
    func getIndentationAtCursor() -> Int {
        let currentLine = getCurrentLine()
        var indentCount = 0
        
        for char in currentLine {
            if char == " " {
                indentCount += 1
            } else if char == "\t" {
                indentCount += 4
            } else {
                break
            }
        }
        
        return indentCount
    }
    
    func applySyntaxHighlighting() {
        let fullRange = NSRange(location: 0, length: string.count)
        let attributedString = NSMutableAttributedString(string: string)
        
        // Reset to default style
        attributedString.addAttribute(.foregroundColor, value: NSColor.white, range: fullRange)
        attributedString.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular), range: fullRange)
        
        // Apply syntax highlighting based on file extension
        applySyntaxHighlighting(to: attributedString, fileType: fileExtension)
        
        // Update the text view
        textStorage?.setAttributedString(attributedString)
    }
    
    private func applySyntaxHighlighting(to attributedString: NSMutableAttributedString, fileType: String) {
        let text = attributedString.string
        
        // Keywords for different languages
        let swiftKeywords = ["func", "var", "let", "if", "else", "for", "while", "class", "struct", "enum", "import", "return", "true", "false", "nil", "self", "super", "switch", "case", "default", "break", "continue", "public", "private", "internal", "static", "override", "final"]
        let pythonKeywords = ["def", "class", "if", "else", "elif", "for", "while", "import", "from", "return", "True", "False", "None", "self", "super", "break", "continue", "pass", "try", "except", "finally", "with", "as", "lambda", "global", "nonlocal"]
        let jsKeywords = ["function", "var", "let", "const", "if", "else", "for", "while", "return", "true", "false", "null", "undefined", "this", "super", "class", "extends", "import", "export", "default", "break", "continue", "try", "catch", "finally", "async", "await"]
        
        let keywords: [String]
        switch fileType.lowercased() {
        case "swift":
            keywords = swiftKeywords
        case "py", "python":
            keywords = pythonKeywords
        case "js", "ts", "javascript", "typescript":
            keywords = jsKeywords
        default:
            keywords = swiftKeywords + pythonKeywords + jsKeywords
        }
        
        // Highlight keywords
        for keyword in keywords {
            let regex = try! NSRegularExpression(pattern: "\\b\(NSRegularExpression.escapedPattern(for: keyword))\\b")
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: text.count))
            for match in matches {
                attributedString.addAttribute(.foregroundColor, value: NSColor(red: 0.8, green: 0.4, blue: 1.0, alpha: 1.0), range: match.range) // Purple
            }
        }
        
        // Highlight strings
        let stringRegex = try! NSRegularExpression(pattern: "\"[^\"]*\"|'[^']*'")
        let stringMatches = stringRegex.matches(in: text, range: NSRange(location: 0, length: text.count))
        for match in stringMatches {
            attributedString.addAttribute(.foregroundColor, value: NSColor(red: 0.4, green: 0.8, blue: 0.4, alpha: 1.0), range: match.range) // Green
        }
        
        // Highlight comments
        let commentRegex = try! NSRegularExpression(pattern: "//.*$|#.*$", options: .anchorsMatchLines)
        let commentMatches = commentRegex.matches(in: text, range: NSRange(location: 0, length: text.count))
        for match in commentMatches {
            attributedString.addAttribute(.foregroundColor, value: NSColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0), range: match.range) // Gray
        }
        
        // Highlight numbers
        let numberRegex = try! NSRegularExpression(pattern: "\\b\\d+\\.?\\d*\\b")
        let numberMatches = numberRegex.matches(in: text, range: NSRange(location: 0, length: text.count))
        for match in numberMatches {
            attributedString.addAttribute(.foregroundColor, value: NSColor(red: 1.0, green: 0.6, blue: 0.4, alpha: 1.0), range: match.range) // Orange
        }
    }
    
    override func keyDown(with event: NSEvent) {
        // Handle Tab key for autocomplete
        if event.keyCode == 48 { // Tab key
            if let coordinator = delegate as? ProperCodeEditor.Coordinator {
                // Check if there's an autocomplete suggestion to accept
                // This would be handled by the parent view
                return
            }
        }
        
        super.keyDown(with: event)
    }
}