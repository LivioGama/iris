import Foundation

/// Centralized simulation configuration
/// Controls whether IRIS uses real gaze/AI or simulated versions
/// Toggle via environment variables: IRIS_USE_SIMULATION=true
public struct SimulationConfig {
    /// Enable simulation mode (uses mouse gaze, mock AI)
    public static var useSimulation: Bool {
        ProcessInfo.processInfo.environment["IRIS_USE_SIMULATION"] == "true"
    }
    
    /// Enable gaze simulation (tracks mouse cursor as gaze point)
    public static var simulateGaze: Bool {
        useSimulation
    }
    
    /// Enable AI simulation (returns mock responses instead of calling Gemini)
    public static var simulateAI: Bool {
        useSimulation
    }
    
    /// Log simulation events for debugging
    public static var verboseSimulationLogging: Bool {
        ProcessInfo.processInfo.environment["IRIS_SIMULATION_VERBOSE"] == "true"
    }
    
    /// Mock response delay (simulates API latency)
    public static var mockResponseDelay: TimeInterval {
        if let delayStr = ProcessInfo.processInfo.environment["IRIS_MOCK_RESPONSE_DELAY"],
           let delay = TimeInterval(delayStr) {
            return delay
        }
        return 0.5 // Default 500ms delay
    }
    
    /// Enables vibrant dev colors via IRIS_DEVELOPMENT_MODE=true
    public static var isDevelopmentMode: Bool {
        ProcessInfo.processInfo.environment["IRIS_DEVELOPMENT_MODE"] == "true"
    }
}
