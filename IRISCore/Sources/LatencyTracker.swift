import Foundation

public struct LatencyMetrics {
    public var t0_voiceStart: Date?
    public var t1_chunkSent: Date?
    public var t2_chunkReceived: Date?
    public var t3_audioPlayed: Date?
    public var tInterrupt: Date?
    
    public var perceivedLatency: TimeInterval? {
        guard let t0 = t0_voiceStart, let t3 = t3_audioPlayed else { return nil }
        return t3.timeIntervalSince(t0)
    }
    
    public var networkLatency: TimeInterval? {
        guard let t1 = t1_chunkSent, let t2 = t2_chunkReceived else { return nil }
        return t2.timeIntervalSince(t1)
    }
    
    public var interruptLatency: TimeInterval? {
        guard let t0 = t0_voiceStart, let ti = tInterrupt else { return nil }
        return ti.timeIntervalSince(t0)
    }
    
    public init() {}
    
    public mutating func reset() {
        t0_voiceStart = nil
        t1_chunkSent = nil
        t2_chunkReceived = nil
        t3_audioPlayed = nil
        tInterrupt = nil
    }
    
    public func logToFile() {
        var lines: [String] = ["📊 Latency Metrics:"]
        
        if let perceived = perceivedLatency {
            lines.append("  Perceived (t0→t3): \(String(format: "%.0f", perceived * 1000))ms")
        }
        if let network = networkLatency {
            lines.append("  Network (t1→t2): \(String(format: "%.0f", network * 1000))ms")
        }
        if let interrupt = interruptLatency {
            lines.append("  Interrupt: \(String(format: "%.0f", interrupt * 1000))ms")
        }
        
        let message = lines.joined(separator: "\n")
        print(message)
        try? message.appendLine(to: "/tmp/iris_latency.log")
    }
}

public class LatencyTracker: ObservableObject {
    public static let shared = LatencyTracker()
    
    @Published public var currentMetrics = LatencyMetrics()
    @Published public var lastPerceivedLatency: TimeInterval?
    
    private init() {}
    
    public func markVoiceStart() {
        currentMetrics.t0_voiceStart = Date()
    }
    
    public func markChunkSent() {
        if currentMetrics.t1_chunkSent == nil {
            currentMetrics.t1_chunkSent = Date()
        }
    }
    
    public func markChunkReceived() {
        if currentMetrics.t2_chunkReceived == nil {
            currentMetrics.t2_chunkReceived = Date()
        }
    }
    
    public func markAudioPlayed() {
        if currentMetrics.t3_audioPlayed == nil {
            currentMetrics.t3_audioPlayed = Date()
            lastPerceivedLatency = currentMetrics.perceivedLatency
            currentMetrics.logToFile()
        }
    }
    
    public func markInterrupt() {
        currentMetrics.tInterrupt = Date()
        if let interruptLatency = currentMetrics.interruptLatency {
            let msg = "⚡ Barge-in latency: \(String(format: "%.0f", interruptLatency * 1000))ms"
            print(msg)
            try? msg.appendLine(to: "/tmp/iris_latency.log")
        }
    }
    
    public func reset() {
        currentMetrics.reset()
    }
}
