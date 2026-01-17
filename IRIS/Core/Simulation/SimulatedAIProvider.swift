import Foundation
import AppKit
import Combine
import AVFoundation
import IRISCore

/// Simulated AI provider that returns mock responses
/// Perfect for testing voice interaction and action execution without Gemini API
@MainActor
public class SimulatedAIProvider: NSObject, AIProvider, ObservableObject {
    @Published public var isListening = false
    @Published public var isProcessing = false
    @Published public var liveTranscription = ""
    @Published public var liveGeminiResponse = ""
    @Published public var chatMessages: [ChatMessage] = []
    @Published public var capturedScreenshot: NSImage?
    @Published public var proactiveSuggestions: [ProactiveSuggestion] = []
    
    public var responsePublisher: AnyPublisher<String, Never> {
        $liveGeminiResponse.eraseToAnyPublisher()
    }
    
    private var listeningTimer: Timer?
    private var processingTimer: Timer?
    private var mockResponseIndex = 0
    
    // Mock responses for testing different interaction patterns
    private let mockResponses = [
        "I can see you're looking at the Safari browser. Would you like me to search for something?",
        "I detected a code editor with Python syntax. Should I help you debug this?",
        "You're hovering over a button. Would you like me to click it?",
        "I see a form with text fields. Can I help you fill it out?",
        "There's a notification panel visible. Should I dismiss it?",
    ]
    
    private let mockDelay: TimeInterval
    
    public override init() {
        self.mockDelay = SimulationConfig.mockResponseDelay
        super.init()
        
        if SimulationConfig.verboseSimulationLogging {
            print("🤖 [SIM] SimulatedAIProvider initialized with \(mockDelay)s response delay")
        }
    }
    
    public func receiveAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Mock audio input - just log it
        if SimulationConfig.verboseSimulationLogging {
            print("🎤 [SIM] Received audio buffer: \(buffer.frameLength) frames")
        }
    }
    
    public func startLiveSession() {
        if SimulationConfig.verboseSimulationLogging {
            print("🟢 [SIM] Live session started")
        }
        startListening()
    }
    
    public func stopLiveSession() {
        if SimulationConfig.verboseSimulationLogging {
            print("🔴 [SIM] Live session stopped")
        }
        stopListening()
    }
    
    public func startListening() {
        guard !isListening else { return }
        isListening = true
        liveTranscription = ""
        liveGeminiResponse = ""
        
        if SimulationConfig.verboseSimulationLogging {
            print("🎧 [SIM] Listening started")
        }
        
        // Simulate voice input detection
        listeningTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.simulateVoiceInput()
            }
        }
    }
    
    public func stopListening() {
        guard isListening else { return }
        isListening = false
        listeningTimer?.invalidate()
        listeningTimer = nil
        
        if SimulationConfig.verboseSimulationLogging {
            print("🔇 [SIM] Listening stopped")
        }
        
        // Trigger mock response
        triggerMockResponse()
    }
    
    public func setContinuousScreenCaptureScreen(_ screen: NSScreen?) {
        if SimulationConfig.verboseSimulationLogging {
            if let screen = screen {
                print("📺 [SIM] Screen capture set to \(Int(screen.frame.width))x\(Int(screen.frame.height))")
            } else {
                print("📺 [SIM] Screen capture cleared")
            }
        }
    }
    
    // MARK: - Private Mock Methods
    
    private func simulateVoiceInput() {
        // Simulate partial transcription
        let samplePhrases = [
            "Hey",
            "Hey I",
            "Hey I need",
            "Hey I need help",
            "Hey I need help with",
            "Hey I need help with this",
        ]
        
        if liveTranscription.isEmpty {
            liveTranscription = samplePhrases.randomElement() ?? "Hello"
        } else {
            // Gradually build up the transcription
            let parts = liveTranscription.split(separator: " ")
            if parts.count < 6 {
                liveTranscription = samplePhrases[min(parts.count, samplePhrases.count - 1)]
            }
        }
    }
    
    private func triggerMockResponse() {
        guard !isProcessing else { return }
        isProcessing = true
        
        // Schedule mock response after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + mockDelay) { [weak self] in
            MainActor.assumeIsolated {
                self?.generateMockResponse()
            }
        }
    }
    
    private func generateMockResponse() {
        defer { isProcessing = false }
        
        // Select a mock response
        let response = mockResponses[mockResponseIndex % mockResponses.count]
        mockResponseIndex += 1
        
        // Simulate streaming response character by character
        liveGeminiResponse = ""
        var charIndex = 0
        
        let streamTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard charIndex < response.count else {
                    timer.invalidate()
                    self?.addMockChatMessage(response)
                    // Auto-generate empty suggestions for now
                    self?.proactiveSuggestions = []
                    if SimulationConfig.verboseSimulationLogging {
                        print("✅ [SIM] Response complete: \(response)")
                    }
                    return
                }
                
                let endIndex = response.index(response.startIndex, offsetBy: charIndex + 1)
                self?.liveGeminiResponse = String(response[..<endIndex])
                charIndex += 1
            }
        }
    }
    
    private func addMockChatMessage(_ text: String) {
        let message = ChatMessage(
            role: .assistant,
            content: text,
            timestamp: Date()
        )
        chatMessages.append(message)
    }
}
