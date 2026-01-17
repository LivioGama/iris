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

        print("🔍 PathResolver.detectEnvironment: bundlePath = \(bundlePath)")

        // Check for bundled FIRST (most specific - check if path ends with .app)
        if bundlePath.hasSuffix(".app") || bundlePath.contains(".app/") {
            print("✅ Detected: .bundled")
            return .bundled
        }

        if bundlePath.contains("/.build/") {
            print("✅ Detected: .development")
            return .development
        } else if bundlePath.contains("/DerivedData/") || bundlePath.contains("/build/Build/Products/") {
            print("✅ Detected: .xcodeBuild")
            return .xcodeBuild
        }

        print("✅ Detected: .development (default)")
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
            // Handle DerivedData path FIRST (check before build path since DerivedData also contains "Build")
            if bundlePath.contains("/DerivedData/") {
                // Try common project locations
                let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
                let possiblePaths = [
                    "\(homeDir)/Documents/iris2",
                    "\(homeDir)/iris2",
                    "/Users/livio/Documents/iris2"
                ]

                for path in possiblePaths {
                    if FileManager.default.fileExists(atPath: "\(path)/Package.swift") {
                        print("📂 PathResolver: Found project root at \(path)")
                        return path
                    }
                }
                print("❌ PathResolver: None of the common paths contain Package.swift")
            }

            // Xcode DerivedData build - check for workspace info
            if let workspaceData = Bundle.main.infoDictionary?["PROJECT_ROOT"] as? String {
                return workspaceData
            }
            // Handle xcodebuild output directory (build/Build/Products/)
            if let projectRoot = bundlePath.components(separatedBy: "/build/Build/Products/").first {
                return projectRoot
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
            // Production mode: try to use development venv if available
            let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
            let devVenvPath = "\(homeDir)/Documents/iris2/gaze_env/bin/python3"

            if FileManager.default.fileExists(atPath: devVenvPath) {
                print("✅ PathResolver: Using development venv Python")
                return devVenvPath
            }

            // Try bundled Python if available
            guard let projectRoot = resolveProjectRoot() else { return nil }
            let bundledPythonPath = "\(projectRoot)/Resources/python/bin/python3"

            if FileManager.default.fileExists(atPath: bundledPythonPath) {
                return bundledPythonPath
            }

            // Fallback to system Python
            print("⚠️ PathResolver: Falling back to system Python")
            return "/usr/bin/python3"
        }
    }

    /// Resolves the Python script path
    /// - Parameter scriptName: The name of the Python script (e.g., "eye_tracker.py")
    /// - Returns: The absolute path to the script, or nil if not found
    public static func resolvePythonScript(named scriptName: String) -> String? {
        let environment = detectEnvironment()
        print("🔍 PathResolver: Resolving script '\(scriptName)' in environment: \(environment)")

        switch environment {
        case .development, .xcodeBuild:
            // Development mode: script in project root
            guard let projectRoot = resolveProjectRoot() else {
                print("❌ PathResolver: Could not resolve project root")
                return nil
            }
            print("📂 PathResolver: Project root = \(projectRoot)")

            let scriptPath = "\(projectRoot)/\(scriptName)"
            print("🔍 PathResolver: Checking script at: \(scriptPath)")

            if FileManager.default.fileExists(atPath: scriptPath) {
                print("✅ PathResolver: Script found at \(scriptPath)")
                return scriptPath
            } else {
                print("❌ PathResolver: Script not found at \(scriptPath)")
            }

        case .bundled:
            // Production mode: script in bundle resources
            let bundlePath = Bundle.main.bundlePath
            let resourcesPath = "\(bundlePath)/Contents/Resources"

            print("📂 PathResolver: bundlePath = \(bundlePath)")
            print("📂 PathResolver: resourcesPath = \(resourcesPath)")

            // Try scripts subdirectory first
            let scriptsPath = "\(resourcesPath)/scripts/\(scriptName)"
            print("🔍 PathResolver: Checking bundled script at: \(scriptsPath)")
            let scriptsExists = FileManager.default.fileExists(atPath: scriptsPath)
            print("   Result: \(scriptsExists ? "EXISTS ✅" : "NOT FOUND ❌")")
            if scriptsExists {
                print("✅ PathResolver: Found script in scripts/ subdirectory")
                return scriptsPath
            }

            // Fallback to root of Resources
            let rootScriptPath = "\(resourcesPath)/\(scriptName)"
            print("🔍 PathResolver: Checking bundled script at: \(rootScriptPath)")
            let rootExists = FileManager.default.fileExists(atPath: rootScriptPath)
            print("   Result: \(rootExists ? "EXISTS ✅" : "NOT FOUND ❌")")
            if rootExists {
                print("✅ PathResolver: Found script in Resources root")
                return rootScriptPath
            }

            // List what's actually in Resources
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: resourcesPath)
                print("📂 PathResolver: Contents of Resources: \(contents)")
            } catch {
                print("❌ PathResolver: Failed to list Resources: \(error)")
            }

            print("❌ PathResolver: Script not found in bundle resources")
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
