import Foundation

class GeminiCLIService {
    static let shared = GeminiCLIService()

    let geminiPath = "/Users/livio/.nvm/versions/node/v22.22.0/bin/gemini"
    let skillsBaseDir: URL

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        skillsBaseDir = home.appendingPathComponent(".iris/skills")
        try? FileManager.default.createDirectory(at: skillsBaseDir, withIntermediateDirectories: true)
    }

    func learnAndExecute(task: String, context: String) async -> String {
        let logPrefix = "🧠 GeminiCLI"
        print("\(logPrefix): learnAndExecute task='\(task)'")
        try? "\(logPrefix): learnAndExecute task='\(task)' context='\(context)'".appendLine(to: "/tmp/iris_live_debug.log")

        if let existing = FileSkillScanner.shared.findSkill(for: task) {
            print("\(logPrefix): Found existing skill '\(existing.name)'")
            try? "\(logPrefix): Reusing skill '\(existing.name)'".appendLine(to: "/tmp/iris_live_debug.log")
            return await executeWithSkill(existing, task: task, context: context)
        }

        print("\(logPrefix): No skill found, learning...")
        try? "\(logPrefix): No skill match, invoking Gemini CLI to learn".appendLine(to: "/tmp/iris_live_debug.log")

        guard let newSkill = await learnSkill(task: task, context: context) else {
            return "I tried to learn how to do this but couldn't create a skill. The task was: \(task)"
        }

        SkillRegistry.shared.register(newSkill.toIRISSkill())
        print("\(logPrefix): Learned and registered skill '\(newSkill.name)'")
        try? "\(logPrefix): Skill '\(newSkill.name)' created and registered".appendLine(to: "/tmp/iris_live_debug.log")

        return await executeWithSkill(newSkill, task: task, context: context)
    }

    private func learnSkill(task: String, context: String) async -> FileSkill? {
        let slug = task.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .prefix(4)
            .joined(separator: "-")

        let skillDir = skillsBaseDir.appendingPathComponent(slug)
        let skillPath = skillDir.appendingPathComponent("SKILL.md")

        let prompt = """
        You need to learn how to: "\(task)"
        \(context.isEmpty ? "" : "Context: \(context)")

        1. Search the web to understand how to accomplish this
        2. Create the directory: \(skillDir.path)
        3. Write a skill file at \(skillPath.path) with this EXACT format:

        ---
        name: \(slug)
        description: "<one-line description of what this skill does>"
        keywords: [relevant, keywords, for, matching]
        ---
        # <Title>
        <Detailed step-by-step instructions for how to do this task>
        <Include specific commands, APIs, tools, and configurations>
        <Include common gotchas and edge cases>

        Focus on practical, actionable instructions with exact commands.
        The SKILL.md must start with --- on the first line.
        """

        do {
            let output = try await runGeminiCLI(prompt: prompt)
            try? "🧠 GeminiCLI learn output: \(output.prefix(500))".appendLine(to: "/tmp/iris_live_debug.log")

            if FileManager.default.fileExists(atPath: skillPath.path) {
                return FileSkill.parse(from: skillPath)
            }

            print("⚠️ GeminiCLI: SKILL.md not created at \(skillPath.path)")
            return nil
        } catch {
            print("❌ GeminiCLI learnSkill error: \(error)")
            try? "❌ GeminiCLI learnSkill error: \(error)".appendLine(to: "/tmp/iris_live_debug.log")
            return nil
        }
    }

    private func executeWithSkill(_ skill: FileSkill, task: String, context: String) async -> String {
        let prompt = """
        You are executing a learned skill. Follow these instructions:

        \(skill.instructions)

        ---
        Task: \(task)
        \(context.isEmpty ? "" : "Context: \(context)")

        Execute the task following the skill instructions above.
        """

        do {
            let output = try await runGeminiCLI(prompt: prompt)
            try? "✅ GeminiCLI execute output: \(output.prefix(500))".appendLine(to: "/tmp/iris_live_debug.log")
            return output.isEmpty ? "Task completed." : output
        } catch {
            let msg = "Failed to execute skill '\(skill.name)': \(error.localizedDescription)"
            try? "❌ GeminiCLI execute error: \(msg)".appendLine(to: "/tmp/iris_live_debug.log")
            return msg
        }
    }

    func runGeminiCLI(prompt: String, workingDir: String? = nil, yolo: Bool = true) async throws -> String {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()

        process.executableURL = URL(fileURLWithPath: geminiPath)
        var args = ["-p", prompt, "-o", "text"]
        if yolo { args.append("--yolo") }
        process.arguments = args

        process.standardOutput = stdout
        process.standardError = stderr

        if let dir = workingDir {
            process.currentDirectoryURL = URL(fileURLWithPath: dir)
        }

        var env = ProcessInfo.processInfo.environment
        let nodeBinDir = (geminiPath as NSString).deletingLastPathComponent
        if let existingPath = env["PATH"] {
            env["PATH"] = "\(nodeBinDir):\(existingPath)"
        } else {
            env["PATH"] = nodeBinDir
        }
        process.environment = env

        print("🚀 GeminiCLI: Running \(geminiPath) -p '\(prompt.prefix(80))...' \(yolo ? "--yolo" : "")")
        try? "🚀 GeminiCLI: spawn args=\(args.prefix(3))".appendLine(to: "/tmp/iris_live_debug.log")

        try process.run()

        return await withCheckedContinuation { continuation in
            process.terminationHandler = { _ in
                let outData = stdout.fileHandleForReading.readDataToEndOfFile()
                let errData = stderr.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outData, encoding: .utf8) ?? ""
                let errOutput = String(data: errData, encoding: .utf8) ?? ""

                if !errOutput.isEmpty {
                    print("⚠️ GeminiCLI stderr: \(errOutput.prefix(200))")
                }

                let exitCode = process.terminationStatus
                if exitCode != 0 {
                    print("❌ GeminiCLI exited with code \(exitCode)")
                }

                continuation.resume(returning: output)
            }
        }
    }
}
