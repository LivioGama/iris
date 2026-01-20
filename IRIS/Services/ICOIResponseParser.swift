import Foundation
import IRISCore

/// Parses structured Gemini responses into ICOI UI elements
/// Handles markdown-like formatting and extracts actionable components
public class ICOIResponseParser {

    public init() {}

    /// Parses a Gemini response text into structured ICOI elements
    public func parse(responseText: String, intent: ICOIIntent = .general) -> ICOIParsedResponse {
        var elements: [ICOIResponseElement] = []
        let lines = responseText.components(separatedBy: .newlines)

        var currentIndex = 0

        while currentIndex < lines.count {
            let line = lines[currentIndex].trimmingCharacters(in: .whitespacesAndNewlines)

            if line.isEmpty {
                currentIndex += 1
                continue
            }

            // Check for headings (# ## ###)
            if let heading = parseHeading(line) {
                elements.append(heading)
                currentIndex += 1
                continue
            }

            // Check for numbered options (Option 1:, **Option 1:**)
            if let option = parseNumberedOption(line, remainingLines: Array(lines[currentIndex...])) {
                elements.append(option.element)
                currentIndex += option.linesConsumed
                continue
            }

            // Check for code blocks (```language)
            if let codeBlock = parseCodeBlock(startingAt: currentIndex, in: lines) {
                elements.append(codeBlock.element)
                currentIndex += codeBlock.linesConsumed
                continue
            }

            // Check for bullet lists (- item)
            if let bulletList = parseBulletList(startingAt: currentIndex, in: lines) {
                elements.append(bulletList.element)
                currentIndex += bulletList.linesConsumed
                continue
            }

            // Check for action items (✅ or ⏳ or - [ ] or - [x])
            if let actionItem = parseActionItem(line) {
                elements.append(actionItem)
                currentIndex += 1
                continue
            }

            // Default to paragraph
            if !line.isEmpty {
                elements.append(.paragraph(text: line))
            }

            currentIndex += 1
        }

        // For code improvement intent, extract old/new code and improvements
        if intent == .codeImprovement {
            let codeComparison = extractCodeComparison(from: responseText, elements: elements)
            return ICOIParsedResponse(
                elements: elements,
                oldCode: codeComparison.oldCode,
                newCode: codeComparison.newCode,
                codeLanguage: codeComparison.language,
                improvements: codeComparison.improvements
            )
        }

        return ICOIParsedResponse(elements: elements)
    }

    /// Extracts old code, new code, and improvements for code improvement intent
    private func extractCodeComparison(from text: String, elements: [ICOIResponseElement]) -> (oldCode: String?, newCode: String?, language: String?, improvements: [String]) {
        var oldCode: String? = nil
        var newCode: String? = nil
        var language: String? = nil
        var improvements: [String] = []

        // Track which section we're in to assign code blocks correctly
        var inOriginalSection = false
        var inImprovedSection = false
        var foundOriginalCode = false

        for element in elements {
            if case .heading(_, let text) = element {
                let lowercased = text.lowercased()

                // Detect "Original Code" section
                if lowercased.contains("original") && lowercased.contains("code") {
                    inOriginalSection = true
                    inImprovedSection = false
                }
                // Detect "Improved Code" section
                else if lowercased.contains("improved") && lowercased.contains("code") {
                    inOriginalSection = false
                    inImprovedSection = true
                }
                // Detect improvements section
                else if lowercased.contains("improvement") ||
                        lowercased.contains("better") ||
                        lowercased.contains("changes") ||
                        lowercased.contains("key") {
                    inOriginalSection = false
                    inImprovedSection = false
                }
            }
            // Extract code blocks based on current section
            else if case .codeBlock(let lang, let code) = element {
                if inOriginalSection && !foundOriginalCode {
                    oldCode = code
                    language = lang
                    foundOriginalCode = true
                } else if inImprovedSection || (!foundOriginalCode) {
                    // If we haven't found original code yet, treat first code block as improved
                    // (for backward compatibility with responses that only provide improved code)
                    newCode = code
                    if language == nil {
                        language = lang
                    }
                }
            }
            // Extract improvements from bullet lists
            else if case .bulletList(let items) = element {
                // Only add to improvements if we're not in a code section
                if !inOriginalSection && !inImprovedSection {
                    improvements.append(contentsOf: items)
                }
            }
        }

        return (oldCode: oldCode, newCode: newCode, language: language, improvements: improvements)
    }

    /// Parses markdown-style headings
    private func parseHeading(_ line: String) -> ICOIResponseElement? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("###") {
            let text = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
            return .heading(level: 3, text: String(text))
        } else if trimmed.hasPrefix("##") {
            let text = trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces)
            return .heading(level: 2, text: String(text))
        } else if trimmed.hasPrefix("#") {
            let text = trimmed.dropFirst(1).trimmingCharacters(in: .whitespaces)
            return .heading(level: 1, text: String(text))
        }

        return nil
    }

    /// Parses numbered options with titles and content
    private func parseNumberedOption(_ line: String, remainingLines: [String]) -> (element: ICOIResponseElement, linesConsumed: Int)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Match patterns like "Option 1:", "**Option 1:**", "1.", etc.
        let optionPatterns = [
            "^\\*\\*Option (\\d+):\\s*(.+)\\*\\*$",  // **Option 1: Title**
            "^Option (\\d+):\\s*(.+)$",              // Option 1: Title
            "^(\\d+)\\.\\s*(.+)$"                     // 1. Title
        ]

        for pattern in optionPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: trimmed.count)) {

                let numberString = (trimmed as NSString).substring(with: match.range(at: 1))
                let title = (trimmed as NSString).substring(with: match.range(at: 2))

                guard let number = Int(numberString) else { continue }

                // Collect content lines until next option or heading
                var contentLines: [String] = []
                var linesConsumed = 1

                for i in 1..<remainingLines.count {
                    let nextLine = remainingLines[i].trimmingCharacters(in: .whitespacesAndNewlines)

                    // Stop if we hit another option or heading
                    if parseHeading(nextLine) != nil ||
                       parseNumberedOption(nextLine, remainingLines: []) != nil ||
                       nextLine.isEmpty {
                        break
                    }

                    contentLines.append(remainingLines[i])
                    linesConsumed += 1
                }

                let content = contentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                return (.numberedOption(number: number, title: title, content: content), linesConsumed)
            }
        }

        return nil
    }

    /// Parses code blocks with language detection
    private func parseCodeBlock(startingAt index: Int, in lines: [String]) -> (element: ICOIResponseElement, linesConsumed: Int)? {
        guard index < lines.count else { return nil }

        let line = lines[index].trimmingCharacters(in: .whitespaces)

        // Check for opening ``` with optional language
        guard line.hasPrefix("```") else { return nil }

        let language = line.dropFirst(3).trimmingCharacters(in: .whitespaces)

        // Find the closing ```
        var codeLines: [String] = []
        var currentIndex = index + 1

        while currentIndex < lines.count {
            let codeLine = lines[currentIndex]
            if codeLine.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                // Found closing ```
                let code = codeLines.joined(separator: "\n")
                return (.codeBlock(language: language.isEmpty ? "text" : language, code: code), currentIndex - index + 1)
            }
            codeLines.append(codeLine)
            currentIndex += 1
        }

        // No closing ``` found, treat as regular text
        return nil
    }

    /// Parses bullet lists
    private func parseBulletList(startingAt index: Int, in lines: [String]) -> (element: ICOIResponseElement, linesConsumed: Int)? {
        guard index < lines.count else { return nil }

        let line = lines[index].trimmingCharacters(in: .whitespaces)

        // Check if line starts with bullet marker
        guard line.hasPrefix("- ") || line.hasPrefix("• ") else { return nil }

        var bulletItems: [String] = []
        var currentIndex = index

        // Collect consecutive bullet items
        while currentIndex < lines.count {
            let currentLine = lines[currentIndex].trimmingCharacters(in: .whitespaces)

            if currentLine.hasPrefix("- ") {
                let item = currentLine.dropFirst(2).trimmingCharacters(in: .whitespaces)
                bulletItems.append(item)
            } else if currentLine.hasPrefix("• ") {
                let item = currentLine.dropFirst(2).trimmingCharacters(in: .whitespaces)
                bulletItems.append(item)
            } else if !currentLine.isEmpty {
                // Non-empty line that's not a bullet, stop collecting
                break
            } else {
                // Empty line, continue (might be spacing between bullets)
            }

            currentIndex += 1

            // Stop if next line is not empty and not a bullet
            if currentIndex < lines.count {
                let nextLine = lines[currentIndex].trimmingCharacters(in: .whitespaces)
                if !nextLine.isEmpty && !nextLine.hasPrefix("- ") && !nextLine.hasPrefix("• ") {
                    break
                }
            }
        }

        if bulletItems.isEmpty {
            return nil
        }

        return (.bulletList(items: bulletItems), currentIndex - index)
    }

    /// Parses action items with checkboxes
    private func parseActionItem(_ line: String) -> ICOIResponseElement? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Match patterns like "- [ ] Task" or "- [x] Task" or "✅ Task" or "⏳ Task"
        let patterns = [
            "^-\\s*\\[\\s*\\]\\s*(.+)$",  // - [ ] Task
            "^-\\s*\\[\\s*x\\s*\\]\\s*(.+)$", // - [x] Task
            "^✅\\s*(.+)$",              // ✅ Task
            "^⏳\\s*(.+)$",              // ⏳ Task
            "^❌\\s*(.+)$",              // ❌ Task
            "^✅\\s*(.+)\\s*\\((.+)\\)$", // ✅ Task (assignee)
            "^⏳\\s*(.+)\\s*\\((.+)\\)$"  // ⏳ Task (assignee)
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: trimmed.count)) {

                let text = (trimmed as NSString).substring(with: match.range(at: 1))
                var assignee: String? = nil
                var completed = false

                // Check for assignee in patterns with parentheses
                if match.numberOfRanges > 2 {
                    assignee = (trimmed as NSString).substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespaces)
                }

                // Determine completion status
                if trimmed.hasPrefix("✅") || trimmed.contains("[x]") {
                    completed = true
                }

                return .actionItem(text: text, assignee: assignee, completed: completed)
            }
        }

        return nil
    }
}
