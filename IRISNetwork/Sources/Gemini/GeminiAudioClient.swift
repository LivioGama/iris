import Foundation
import AVFoundation

/// Client for Gemini 2.5 Flash Native Audio Preview API
/// Handles text-to-speech conversion using native audio model
public class GeminiAudioClient {
    private var apiKey: String
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"
    private let model = "gemini-2.5-flash-native-audio-preview-12-2025"
    
    public init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    /// Updates the API key
    /// - Parameter newKey: The new API key to use
    public func updateAPIKey(_ newKey: String) {
        self.apiKey = newKey
    }
    
    /// Generates audio response from text prompt
    /// - Parameters:
    ///   - text: The text to convert to speech
    ///   - voiceName: Voice to use (default: "Puck")
    /// - Returns: PCM audio data that can be played
    public func generateAudioResponse(text: String, voiceName: String = "Puck") async throws -> Data {
        guard !apiKey.isEmpty else {
            throw GeminiAudioError.missingAPIKey
        }
        
        let endpoint = "\(baseURL)/\(model):generateContent"
        guard let url = URL(string: endpoint) else {
            throw GeminiAudioError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": text]
                    ]
                ]
            ],
            "generationConfig": [
                "responseModalities": ["AUDIO"],
                "speechConfig": [
                    "voiceConfig": [
                        "prebuiltVoiceConfig": [
                            "voiceName": voiceName
                        ]
                    ]
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("🎤 Requesting audio response from Gemini...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiAudioError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GeminiAudioError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        // Parse response to extract audio data
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let inlineData = firstPart["inlineData"] as? [String: Any],
              let base64Audio = inlineData["data"] as? String else {
            throw GeminiAudioError.invalidAudioData
        }
        
        // Decode base64 audio data
        guard let audioData = Data(base64Encoded: base64Audio) else {
            throw GeminiAudioError.invalidAudioData
        }
        
        print("✅ Received audio response: \(audioData.count) bytes")
        return audioData
    }
    
    /// Plays PCM audio data
    /// - Parameter pcmData: Raw PCM audio data from Gemini API
    public func playAudio(_ pcmData: Data) throws {
        // Gemini returns PCM audio at 24kHz, mono, 16-bit
        let sampleRate: Double = 24000
        let channels: UInt32 = 1
        let bitsPerChannel: UInt32 = 16
        
        // Create audio format
        let audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: true
        )
        
        guard let format = audioFormat else {
            throw GeminiAudioError.audioFormatError
        }
        
        // Calculate frame capacity
        let frameCapacity = UInt32(pcmData.count) / (bitsPerChannel / 8)
        
        guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
            throw GeminiAudioError.audioBufferError
        }
        
        audioBuffer.frameLength = frameCapacity
        
        // Copy PCM data to buffer
        let audioBufferPointer = audioBuffer.int16ChannelData?[0]
        pcmData.withUnsafeBytes { rawBufferPointer in
            guard let baseAddress = rawBufferPointer.baseAddress else { return }
            audioBufferPointer?.update(from: baseAddress.assumingMemoryBound(to: Int16.self), count: Int(frameCapacity))
        }
        
        // Play audio
        let audioEngine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()
        
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)
        
        try audioEngine.start()
        
        playerNode.scheduleBuffer(audioBuffer) {
            print("🔊 Audio playback completed")
            audioEngine.stop()
        }
        
        playerNode.play()
        
        print("🔊 Playing audio response...")
    }
}

// MARK: - Errors
public enum GeminiAudioError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case invalidAudioData
    case audioFormatError
    case audioBufferError
    
    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "GEMINI_API_KEY not set"
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from Gemini API"
        case .apiError(let statusCode, let message):
            return "Gemini API error \(statusCode): \(message)"
        case .invalidAudioData:
            return "Failed to decode audio data from response"
        case .audioFormatError:
            return "Failed to create audio format"
        case .audioBufferError:
            return "Failed to create audio buffer"
        }
    }
}
