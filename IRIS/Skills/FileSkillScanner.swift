import Foundation

class FileSkillScanner {
    static let shared = FileSkillScanner()

    var skillDirectories: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent(".iris/skills"),
            home.appendingPathComponent(".gemini/skills"),
        ]
    }

    private init() {}

    func scanAll() -> [FileSkill] {
        var skills: [FileSkill] = []
        let fm = FileManager.default

        for dir in skillDirectories {
            guard fm.fileExists(atPath: dir.path) else { continue }
            guard let subdirs = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else { continue }

            for subdir in subdirs {
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: subdir.path, isDirectory: &isDir), isDir.boolValue else { continue }

                let skillFile = subdir.appendingPathComponent("SKILL.md")
                guard fm.fileExists(atPath: skillFile.path) else { continue }

                if let skill = FileSkill.parse(from: skillFile) {
                    skills.append(skill)
                    print("📂 FileSkillScanner: Found skill '\(skill.name)' at \(skillFile.path)")
                }
            }
        }

        return skills
    }

    func findSkill(for task: String) -> FileSkill? {
        let all = scanAll()
        return all.first { $0.matches(task: task) }
    }
}
