import Foundation
import IRISCore

struct FileSkill {
    let path: URL
    let name: String
    let description: String
    let keywords: [String]
    let instructions: String

    static func parse(from url: URL) -> FileSkill? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("---") else { return nil }

        let parts = trimmed.components(separatedBy: "\n---")
        guard parts.count >= 2 else { return nil }

        let frontmatter = parts[0].replacingOccurrences(of: "---", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        let body = parts.dropFirst().joined(separator: "\n---").trimmingCharacters(in: .whitespacesAndNewlines)

        var name = ""
        var description = ""
        var keywords: [String] = []

        for line in frontmatter.components(separatedBy: "\n") {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.hasPrefix("name:") {
                name = extractValue(trimmedLine, key: "name")
            } else if trimmedLine.hasPrefix("description:") {
                description = extractValue(trimmedLine, key: "description")
            } else if trimmedLine.hasPrefix("keywords:") {
                let raw = extractValue(trimmedLine, key: "keywords")
                keywords = raw
                    .replacingOccurrences(of: "[", with: "")
                    .replacingOccurrences(of: "]", with: "")
                    .components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        }

        guard !name.isEmpty else { return nil }

        return FileSkill(
            path: url,
            name: name,
            description: description,
            keywords: keywords,
            instructions: body
        )
    }

    func matches(task: String) -> Bool {
        let lower = task.lowercased()
        let nameWords = name.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        let descWords = description.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count > 3 }
        let allTerms = keywords.map { $0.lowercased() } + nameWords + descWords

        var matchCount = 0
        for term in allTerms {
            if lower.contains(term) { matchCount += 1 }
        }
        return matchCount >= 2
    }

    func toIRISSkill() -> Skill {
        Skill(
            id: "file-\(name)",
            name: name.replacingOccurrences(of: "-", with: " ").capitalized,
            description: description,
            icon: "doc.text.magnifyingglass",
            intents: keywords,
            capabilities: [.executeShell],
            allowedActions: [.runCommand],
            canAutoExecute: false,
            instructions: instructions
        )
    }

    private static func extractValue(_ line: String, key: String) -> String {
        let raw = String(line.dropFirst(key.count + 1)).trimmingCharacters(in: .whitespaces)
        return raw.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
    }
}
