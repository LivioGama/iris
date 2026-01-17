import Foundation
import Combine
import AppKit
import AVFoundation
import IRISCore

/// Protocol for AI interaction (real Gemini API or simulated)
public protocol AIProvider: AnyObject {
    /// Whether AI is currently listening for voice input
    var isListening: Bool { get }
    
    /// Whether AI is currently processing/generating a response
    var isProcessing: Bool { get }
    
    /// Latest live transcription from voice input
    var liveTranscription: String { get }
    
    /// Live streaming response from AI
    var liveGeminiResponse: String { get }
    
    /// Chat messages in current conversation
    var chatMessages: [ChatMessage] { get }
    
    /// Screenshot currently being analyzed
    var capturedScreenshot: NSImage? { get }
    
    /// Proactive suggestions based on screen context
    var proactiveSuggestions: [ProactiveSuggestion] { get }
    
    /// Publisher for response updates
    var responsePublisher: AnyPublisher<String, Never> { get }
    
    /// Receive audio buffer from microphone
    func receiveAudioBuffer(_ buffer: AVAudioPCMBuffer)
    
    /// Start live AI session (continuous listening + processing)
    func startLiveSession()
    
    /// Stop live AI session
    func stopLiveSession()
    
    /// Start listening for voice input
    func startListening()
    
    /// Stop listening for voice input
    func stopListening()
    
    /// Set screen for continuous capture during live session
    func setContinuousScreenCaptureScreen(_ screen: NSScreen?)
}
