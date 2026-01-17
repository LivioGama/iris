import Foundation
import GoogleGenerativeAI
import IRISCore

/// Defines the tools available to the Gemini Agent
struct AgentTools {
    
    static var allTools: [Tool] {
        return [
            Tool(functionDeclarations: [
                clickFunction,
                typeFunction,
                scrollFunction, // Need to implement scroll in ActionExecutor if not there
                openAppFunction,
                searchFunction,
                readFileFunction, // For "Crazy Folder"
                writeFileFunction,
                runCommandFunction // Dangerous? Maybe restrict.
            ])
        ]
    }
    
    // MARK: - Interaction Tools
    
    static let clickFunction = FunctionDeclaration(
        name: "click",
        description: "Simulates a mouse click at the given coordinates on screen.",
        parameters: [
            "x": Schema(type: .number, description: "X coordinate"),
            "y": Schema(type: .number, description: "Y coordinate")
        ],
        requiredParameters: ["x", "y"]
    )
    
    static let typeFunction = FunctionDeclaration(
        name: "type_text",
        description: "Types the specified text at the current cursor location.",
        parameters: [
            "text": Schema(type: .string, description: "The text to type")
        ],
        requiredParameters: ["text"]
    )
    
    static let scrollFunction = FunctionDeclaration(
        name: "scroll",
        description: "Scrolls the screen.",
        parameters: [
            "direction": Schema(type: .string, description: "Direction to scroll ('up', 'down')"),
            "amount": Schema(type: .integer, description: "Amount to scroll (optional, default 5)")
        ],
        requiredParameters: ["direction"]
    )
    
    // MARK: - System Tools
    
    static let openAppFunction = FunctionDeclaration(
        name: "open_app",
        description: "Opens or activates an application by name.",
        parameters: [
            "app_name": Schema(type: .string, description: "Name of the application (e.g. 'Safari', 'Mail')")
        ],
        requiredParameters: ["app_name"]
    )
    
    static let searchFunction = FunctionDeclaration(
        name: "google_search",
        description: "Performs a Google search in the default browser.",
        parameters: [
            "query": Schema(type: .string, description: "Search query")
        ],
        requiredParameters: ["query"]
    )
    
    // MARK: - File System Tools (For 'Crazy Folder' demo)
    
    static let readFileFunction = FunctionDeclaration(
        name: "read_file",
        description: "Reads the content of a file at a specific path.",
        parameters: [
            "path": Schema(type: .string, description: "Absolute path to the file")
        ],
        requiredParameters: ["path"]
    )
    
    static let writeFileFunction = FunctionDeclaration(
        name: "write_file",
        description: "Writes content to a file at a specific path.",
        parameters: [
            "path": Schema(type: .string, description: "Absolute path to the file"),
            "content": Schema(type: .string, description: "Content to write")
        ],
        requiredParameters: ["path", "content"]
    )
    
    static let runCommandFunction = FunctionDeclaration(
        name: "run_terminal_command",
        description: "Runs a shell command. Use with caution.",
        parameters: [
            "command": Schema(type: .string, description: "The zsh command to run")
        ],
        requiredParameters: ["command"]
    )
}
