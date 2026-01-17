import Foundation

/// Represents different types of elements that can be parsed from ICOI responses
public enum ICOIResponseElement: Equatable {
    case heading(level: Int, text: String)
    case paragraph(text: String)
    case bulletList(items: [String])
    case numberedOption(number: Int, title: String, content: String)
    case codeBlock(language: String, code: String)
    case actionItem(text: String, assignee: String?, completed: Bool)

    /// Human-readable description for debugging
    public var description: String {
        switch self {
        case .heading(let level, let text):
            return "Heading \(level): \(text)"
        case .paragraph(let text):
            return "Paragraph: \(text)"
        case .bulletList(let items):
            return "Bullet List (\(items.count) items)"
        case .numberedOption(let number, let title, let content):
            return "Option \(number): \(title)"
        case .codeBlock(let language, let code):
            return "Code Block (\(language)): \(code.prefix(50))"
        case .actionItem(let text, let assignee, let completed):
            let status = completed ? "✅" : "⏳"
            return "\(status) Action: \(text) (\(assignee ?? "unassigned"))"
        }
    }

    public static func == (lhs: ICOIResponseElement, rhs: ICOIResponseElement) -> Bool {
        switch (lhs, rhs) {
        case (.heading(let l1, let t1), .heading(let l2, let t2)):
            return l1 == l2 && t1 == t2
        case (.paragraph(let t1), .paragraph(let t2)):
            return t1 == t2
        case (.bulletList(let i1), .bulletList(let i2)):
            return i1 == i2
        case (.numberedOption(let n1, let ti1, let c1), .numberedOption(let n2, let ti2, let c2)):
            return n1 == n2 && ti1 == ti2 && c1 == c2
        case (.codeBlock(let l1, let c1), .codeBlock(let l2, let c2)):
            return l1 == l2 && c1 == c2
        case (.actionItem(let t1, let a1, let comp1), .actionItem(let t2, let a2, let comp2)):
            return t1 == t2 && a1 == a2 && comp1 == comp2
        default:
            return false
        }
    }
}

/// Parsed ICOI response containing structured elements
public struct ICOIParsedResponse {
    public let elements: [ICOIResponseElement]
    public let hasOptions: Bool
    public let hasCodeBlock: Bool
    public let hasActionItems: Bool

    // For code improvement intent: extract old vs new code and improvements
    public let oldCode: String?
    public let newCode: String?
    public let codeLanguage: String?
    public let improvements: [String]

    public init(elements: [ICOIResponseElement], oldCode: String? = nil, newCode: String? = nil, codeLanguage: String? = nil, improvements: [String] = []) {
        self.elements = elements
        self.oldCode = oldCode
        self.newCode = newCode
        self.codeLanguage = codeLanguage
        self.improvements = improvements

        self.hasOptions = elements.contains(where: {
            if case .numberedOption = $0 { return true }
            return false
        })
        self.hasCodeBlock = elements.contains(where: {
            if case .codeBlock = $0 { return true }
            return false
        })
        self.hasActionItems = elements.contains(where: {
            if case .actionItem = $0 { return true }
            return false
        })
    }

    /// Convenience method to get all numbered options
    public var numberedOptions: [(number: Int, title: String, content: String)] {
        elements.compactMap { element in
            if case .numberedOption(let number, let title, let content) = element {
                return (number, title, content)
            }
            return nil
        }.sorted { $0.number < $1.number }
    }

    /// Convenience method to get the code block if present
    public var codeBlock: (language: String, code: String)? {
        for element in elements {
            if case .codeBlock(let language, let code) = element {
                return (language, code)
            }
        }
        return nil
    }

    /// Check if this is a code comparison response (has old and new code)
    public var hasCodeComparison: Bool {
        return oldCode != nil && newCode != nil
    }
}
