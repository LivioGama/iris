import Foundation

// MARK: - Recovery Action

public enum RecoveryAction {
    case retry
    case restart
    case checkAccessibility
    case checkAPIKey
    case checkPythonEnvironment
    case checkScreenRecordingPermission
    case checkMicrophonePermission
    case none

    public var description: String {
        switch self {
        case .retry:
            return "Try again"
        case .restart:
            return "Restart the service"
        case .checkAccessibility:
            return "Enable Accessibility permissions in System Preferences → Privacy & Security → Accessibility"
        case .checkAPIKey:
            return "Check your Gemini API key in Keychain or environment variables"
        case .checkPythonEnvironment:
            return "Ensure Python environment is set up correctly with required packages"
        case .checkScreenRecordingPermission:
            return "Enable Screen Recording permission in System Preferences → Privacy & Security → Screen Recording"
        case .checkMicrophonePermission:
            return "Enable Microphone permission in System Preferences → Privacy & Security → Microphone"
        case .none:
            return ""
        }
    }
}

// MARK: - IRIS Error

public enum IRISError: Error {
    // Python Process Errors
    case pythonProcessFailed(underlying: Error)
    case pythonProcessNotRunning
    case pythonScriptNotFound(path: String)
    case pythonPackageMissing(package: String)

    // Gemini API Errors
    case geminiAPIError(statusCode: Int, message: String)
    case geminiNetworkError(underlying: Error)
    case geminiInvalidResponse
    case geminiRateLimitExceeded
    case geminiAuthenticationFailed

    // Accessibility Errors
    case accessibilityNotEnabled
    case accessibilityElementNotFound
    case accessibilityPermissionDenied

    // Configuration Errors
    case configurationMissing(key: String)
    case invalidConfiguration(key: String, reason: String)

    // Media Errors
    case screenCaptureError(underlying: Error)
    case screenRecordingPermissionDenied
    case microphonePermissionDenied
    case audioServiceFailed(underlying: Error)
    case speechRecognitionFailed(underlying: Error)

    // Gaze Tracking Errors
    case gazeTrackingNotAvailable
    case gazeCalibrationFailed
    case gazeTrackingLost

    // General Errors
    case invalidInput(reason: String)
    case serviceNotInitialized(service: String)
    case operationTimeout(operation: String)
    case unknown(underlying: Error)

    // MARK: - User-Friendly Messages

    public var userMessage: String {
        switch self {
        // Python Process Errors
        case .pythonProcessFailed(let error):
            return "Python process failed: \(error.localizedDescription)"
        case .pythonProcessNotRunning:
            return "Python process is not running"
        case .pythonScriptNotFound(let path):
            return "Python script not found at: \(path)"
        case .pythonPackageMissing(let package):
            return "Required Python package '\(package)' is missing"

        // Gemini API Errors
        case .geminiAPIError(let statusCode, let message):
            return "Gemini API error (\(statusCode)): \(message)"
        case .geminiNetworkError(let error):
            return "Network error connecting to Gemini: \(error.localizedDescription)"
        case .geminiInvalidResponse:
            return "Gemini returned an invalid response"
        case .geminiRateLimitExceeded:
            return "Gemini API rate limit exceeded. Please wait a moment and try again."
        case .geminiAuthenticationFailed:
            return "Gemini authentication failed. Please check your API key."

        // Accessibility Errors
        case .accessibilityNotEnabled:
            return "Accessibility permissions are not enabled for IRIS"
        case .accessibilityElementNotFound:
            return "Could not detect UI element at this location"
        case .accessibilityPermissionDenied:
            return "Accessibility permission was denied"

        // Configuration Errors
        case .configurationMissing(let key):
            return "Missing configuration: \(key)"
        case .invalidConfiguration(let key, let reason):
            return "Invalid configuration for '\(key)': \(reason)"

        // Media Errors
        case .screenCaptureError(let error):
            return "Screen capture failed: \(error.localizedDescription)"
        case .screenRecordingPermissionDenied:
            return "Screen recording permission is required for IRIS to function"
        case .microphonePermissionDenied:
            return "Microphone permission is required for voice commands"
        case .audioServiceFailed(let error):
            return "Audio service failed: \(error.localizedDescription)"
        case .speechRecognitionFailed(let error):
            return "Speech recognition failed: \(error.localizedDescription)"

        // Gaze Tracking Errors
        case .gazeTrackingNotAvailable:
            return "Gaze tracking is not available"
        case .gazeCalibrationFailed:
            return "Gaze calibration failed. Please try again."
        case .gazeTrackingLost:
            return "Gaze tracking was lost. Please recenter yourself."

        // General Errors
        case .invalidInput(let reason):
            return "Invalid input: \(reason)"
        case .serviceNotInitialized(let service):
            return "Service '\(service)' is not initialized"
        case .operationTimeout(let operation):
            return "Operation '\(operation)' timed out"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }

    // MARK: - Recovery Actions

    public var recoveryAction: RecoveryAction? {
        switch self {
        // Python Process Errors
        case .pythonProcessFailed:
            return .checkPythonEnvironment
        case .pythonProcessNotRunning:
            return .restart
        case .pythonScriptNotFound:
            return .checkPythonEnvironment
        case .pythonPackageMissing:
            return .checkPythonEnvironment

        // Gemini API Errors
        case .geminiAPIError:
            return .retry
        case .geminiNetworkError:
            return .retry
        case .geminiInvalidResponse:
            return .retry
        case .geminiRateLimitExceeded:
            return .none
        case .geminiAuthenticationFailed:
            return .checkAPIKey

        // Accessibility Errors
        case .accessibilityNotEnabled:
            return .checkAccessibility
        case .accessibilityElementNotFound:
            return .none
        case .accessibilityPermissionDenied:
            return .checkAccessibility

        // Configuration Errors
        case .configurationMissing:
            return .checkAPIKey
        case .invalidConfiguration:
            return .none

        // Media Errors
        case .screenCaptureError:
            return .retry
        case .screenRecordingPermissionDenied:
            return .checkScreenRecordingPermission
        case .microphonePermissionDenied:
            return .checkMicrophonePermission
        case .audioServiceFailed:
            return .restart
        case .speechRecognitionFailed:
            return .retry

        // Gaze Tracking Errors
        case .gazeTrackingNotAvailable:
            return .checkPythonEnvironment
        case .gazeCalibrationFailed:
            return .retry
        case .gazeTrackingLost:
            return .none

        // General Errors
        case .invalidInput:
            return .none
        case .serviceNotInitialized:
            return .restart
        case .operationTimeout:
            return .retry
        case .unknown:
            return .retry
        }
    }

    // MARK: - Error Severity

    public enum Severity {
        case critical  // Prevents app from functioning
        case high      // Major feature broken
        case medium    // Minor feature issue
        case low       // Cosmetic or temporary issue
    }

    public var severity: Severity {
        switch self {
        case .pythonProcessFailed, .pythonProcessNotRunning, .pythonScriptNotFound:
            return .critical
        case .pythonPackageMissing:
            return .high
        case .geminiAPIError, .geminiNetworkError:
            return .high
        case .geminiInvalidResponse, .geminiRateLimitExceeded:
            return .medium
        case .geminiAuthenticationFailed:
            return .critical
        case .accessibilityNotEnabled, .accessibilityPermissionDenied:
            return .critical
        case .accessibilityElementNotFound:
            return .low
        case .configurationMissing:
            return .critical
        case .invalidConfiguration:
            return .high
        case .screenCaptureError:
            return .high
        case .screenRecordingPermissionDenied, .microphonePermissionDenied:
            return .critical
        case .audioServiceFailed:
            return .high
        case .speechRecognitionFailed:
            return .medium
        case .gazeTrackingNotAvailable:
            return .critical
        case .gazeCalibrationFailed:
            return .high
        case .gazeTrackingLost:
            return .medium
        case .invalidInput:
            return .low
        case .serviceNotInitialized:
            return .high
        case .operationTimeout:
            return .medium
        case .unknown:
            return .medium
        }
    }

    // MARK: - Should Retry

    public var shouldRetry: Bool {
        switch recoveryAction {
        case .retry, .restart:
            return true
        default:
            return false
        }
    }
}

// MARK: - LocalizedError Conformance

extension IRISError: LocalizedError {
    public var errorDescription: String? {
        return userMessage
    }

    public var recoverySuggestion: String? {
        return recoveryAction?.description
    }

    public var failureReason: String? {
        switch self {
        case .pythonProcessFailed(let error):
            return error.localizedDescription
        case .geminiNetworkError(let error):
            return error.localizedDescription
        case .screenCaptureError(let error):
            return error.localizedDescription
        case .audioServiceFailed(let error):
            return error.localizedDescription
        case .speechRecognitionFailed(let error):
            return error.localizedDescription
        case .unknown(let error):
            return error.localizedDescription
        default:
            return nil
        }
    }
}

// MARK: - Error Context

public struct ErrorContext {
    public let error: IRISError
    public let timestamp: Date
    public let location: String
    public let additionalInfo: [String: Any]

    public init(
        error: IRISError,
        location: String,
        additionalInfo: [String: Any] = [:]
    ) {
        self.error = error
        self.timestamp = Date()
        self.location = location
        self.additionalInfo = additionalInfo
    }

    public var description: String {
        var desc = """
        [\(timestamp.formatted())] \(location)
        Error: \(error.userMessage)
        Severity: \(error.severity)
        """

        if let recovery = error.recoveryAction {
            desc += "\nRecovery: \(recovery.description)"
        }

        if !additionalInfo.isEmpty {
            desc += "\nAdditional Info: \(additionalInfo)"
        }

        return desc
    }
}
