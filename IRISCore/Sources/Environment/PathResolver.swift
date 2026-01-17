import Foundation

/// Resolves paths for bundled resources and development environments
/// Ensures the application works in both development and distribution modes
public enum PathResolver {

    /// Represents the current execution environment
    public enum Environment {
        case development
        case xcodeBuild
        case bundled
    }

    /// Detects the current execution environment
    public static func detectEnvironment() -> Environment {
        let bundlePath = Bundle.main.bundlePath

        if bundlePath.contains("/.build/") {
            return .development
        } else if bundlePath.contains("/DerivedData/") {
            return .xcodeBuild
        } else if bundlePath.contains(".app/") {
            return .bundled
        }

        return .development
    }

    /// Resolves the project root directory
    /// - Returns: The absolute path to the project root
    public static func resolveProjectRoot() -> String? {
        let environment = detectEnvironment()
        let bundlePath = Bundle.main.bundlePath

        switch environment {
        case .development:
            // Swift Package Manager build
            if let projectRoot = bundlePath.components(separatedBy: "/.build/").first {
                return projectRoot
            }

        case .xcodeBuild:
            // Xcode DerivedData build - check for workspace info
            if let workspaceData = Bundle.main.infoDictionary?["PROJECT_ROOT"] as? String {
                return workspaceData
            }
            // Fallback: try to find project root from current directory
            let currentDir = FileManager.default.currentDirectoryPath
            if FileManager.default.fileExists(atPath: "\(currentDir)/Package.swift") {
                return currentDir
            }

        case .bundled:
            // Production app bundle
            // Check if resources are bundled in Contents/Resources
            let resourcesPath = (bundlePath as NSString).deletingLastPathComponent
            let contentsPath = (resourcesPath as NSString).deletingLastPathComponent
            return contentsPath
        }

        return nil
    }

    /// Resolves the Python executable path
    /// - Returns: The absolute path to the Python executable, or nil if not found
    public static func resolvePythonPath() -> String? {
        let environment = detectEnvironment()

        switch environment {
        case .development, .xcodeBuild:
            // Development mode: use virtual environment
            guard let projectRoot = resolveProjectRoot() else { return nil }
            let venvPath = "\(projectRoot)/gaze_env/bin/python3"

            if FileManager.default.fileExists(atPath: venvPath) {
                return venvPath
            }

            // Fallback to system Python if venv doesn't exist
            return "/usr/bin/python3"

        case .bundled:
            // Production mode: use bundled Python
            guard let projectRoot = resolveProjectRoot() else { return nil }
            let bundledPythonPath = "\(projectRoot)/Resources/python/bin/python3"

            if FileManager.default.fileExists(atPath: bundledPythonPath) {
                return bundledPythonPath
            }

            // Fallback to system Python
            return "/usr/bin/python3"
        }
    }

    /// Resolves the Python script path
    /// - Parameter scriptName: The name of the Python script (e.g., "eye_tracker.py")
    /// - Returns: The absolute path to the script, or nil if not found
    public static func resolvePythonScript(named scriptName: String) -> String? {
        let environment = detectEnvironment()

        switch environment {
        case .development, .xcodeBuild:
            // Development mode: script in project root
            guard let projectRoot = resolveProjectRoot() else { return nil }
            let scriptPath = "\(projectRoot)/\(scriptName)"

            if FileManager.default.fileExists(atPath: scriptPath) {
                return scriptPath
            }

        case .bundled:
            // Production mode: script in bundle resources
            guard let projectRoot = resolveProjectRoot() else { return nil }
            let bundledScriptPath = "\(projectRoot)/Resources/scripts/\(scriptName)"

            if FileManager.default.fileExists(atPath: bundledScriptPath) {
                return bundledScriptPath
            }
        }

        return nil
    }

    /// Checks if a virtual environment is active and valid
    /// - Returns: True if a valid virtual environment is detected
    public static func isVirtualEnvironmentActive() -> Bool {
        guard let projectRoot = resolveProjectRoot() else { return false }
        let venvPath = "\(projectRoot)/gaze_env"
        let pythonPath = "\(venvPath)/bin/python3"

        return FileManager.default.fileExists(atPath: pythonPath)
    }

    /// Validates that all required paths exist for Python execution
    /// - Parameter scriptName: The name of the Python script to validate
    /// - Returns: A tuple containing (isValid, errorMessage)
    public static func validatePythonEnvironment(scriptName: String) -> (isValid: Bool, errorMessage: String?) {
        guard let pythonPath = resolvePythonPath() else {
            return (false, "Python executable not found")
        }

        guard FileManager.default.fileExists(atPath: pythonPath) else {
            return (false, "Python executable does not exist at: \(pythonPath)")
        }

        guard let scriptPath = resolvePythonScript(named: scriptName) else {
            return (false, "Python script '\(scriptName)' not found")
        }

        guard FileManager.default.fileExists(atPath: scriptPath) else {
            return (false, "Python script does not exist at: \(scriptPath)")
        }

        return (true, nil)
    }

    /// Gets debug information about the current environment
    /// - Returns: A dictionary containing environment details
    public static func getEnvironmentInfo() -> [String: String] {
        let environment = detectEnvironment()
        let bundlePath = Bundle.main.bundlePath
        let projectRoot = resolveProjectRoot() ?? "Unknown"
        let pythonPath = resolvePythonPath() ?? "Not found"
        let isVenvActive = isVirtualEnvironmentActive()

        return [
            "environment": String(describing: environment),
            "bundlePath": bundlePath,
            "projectRoot": projectRoot,
            "pythonPath": pythonPath,
            "virtualEnvActive": String(isVenvActive)
        ]
    }
}
