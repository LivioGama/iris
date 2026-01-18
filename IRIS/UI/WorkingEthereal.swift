//
//  WorkingEthereal.swift
//  IRIS
//
//  Working ethereal floating overlay that actually shows
//

import SwiftUI
import IRISCore
import IRISNetwork

/// Working ethereal floating overlay - replaces traditional overlay with pure floating elements
struct WorkingEthereal: View {
    @ObservedObject var geminiService: GeminiAssistantOrchestrator

    var body: some View {
        ZStack {
            // Only show when overlay visibility flag is set
            if geminiService.isOverlayVisible {
                etherealElements
            }
        }
    }

    @ViewBuilder
    private var etherealElements: some View {
        Group {
            // Top-left: subtle presence indicators
            VStack {
                HStack {
                    Spacer()
                    presenceIndicators
                    Spacer()
                }
                Spacer()
            }

            // Center: when active, shows the spirit
            VStack {
                Spacer()
                etherealSoul
                Spacer()
            }

            // Bottom-right: minimal state whispers
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    etherealState
                    Spacer().frame(width: 40)
                }
                Spacer().frame(height: 100)
            }
        }
    }

    // MARK: - Ethereal Components

    // Pure presence - just a dot of consciousness
    @ViewBuilder
    private var presenceIndicators: some View {
        HStack(spacing: 12) {
            if geminiService.isListening || geminiService.isProcessing {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.cyan.opacity(0.8), Color.cyan.opacity(0.1)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 20
                        )
                    )
                    .frame(width: 8, height: 8)
                    .shadow(color: Color.cyan.opacity(0.3), radius: 12, x: 0, y: 0)
                    .scaleEffect(1.2)
                    .animation(.smooth(duration: 1.2).repeatForever(autoreverses: true), value: UUID())
            }
        }
        .padding(.trailing, 40)
        .padding(.top, 40)
    }

    // The soul - abstraction of AI presence
    @ViewBuilder
    private var etherealSoul: some View {
        VStack(spacing: 24) {
            // When listening or processing, show abstract elements
            if geminiService.isListening {
                // Floating audio waves - pure energy, no containers
                etherealAudioField

                // Live transcription as ghost text
                if !geminiService.liveTranscription.isEmpty {
                    FloatingText(
                        text: geminiService.liveTranscription,
                        color: .cyan
                    )
                }
            } else if geminiService.isProcessing {
                // AI thinking indication
                ThinkingIndicator()

                if !geminiService.liveGeminiResponse.isEmpty {
                    FloatingText(
                        text: geminiService.liveGeminiResponse,
                        color: .purple
                    )
                }
            }
        }
    }

    // Audio field - abstract energy waves
    @ViewBuilder
    private var etherealAudioField: some View {
        HStack(spacing: 4) {
            ForEach(0..<28) { i in
                etherealWaveBar(at: i)
            }
        }
        .opacity(0.7)
        .scaleEffect(0.9)
    }

    // Individual wave bar - pure abstraction
    @ViewBuilder
    private func etherealWaveBar(at index: Int) -> some View {
        let randomHeight = CGFloat.random(in: 12...96)
        let delay = Double(index) * 0.05
        let lifetime = Double.random(in: 1.6...2.8)
        let opacityFactor = Double.random(in: 0.4...0.9)

        RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    colors: [
                        Color.cyan.opacity(0.8),
                        Color.blue.opacity(0.4),
                        Color.cyan.opacity(0.1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 3, height: CGFloat.random(in: 8...randomHeight))
            .opacity(opacityFactor)
            .animation(
                .easeInOut(duration: lifetime)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: CGFloat.random(in: 8...96)
            )
    }

    // Ghost text - barely visible whisper
    @ViewBuilder
    private func FloatingText(text: String, color: Color) -> some View {
        VStack(spacing: 12) {
            Text(text)
                .foregroundColor(Color.white.opacity(0.85))
                .font(.system(size: 20, weight: .thin, design: .rounded))
                .tracking(0.8)
                .lineSpacing(8)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 700, maxHeight: 120)
                .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 6)
                .opacity(0.9)
                .scaleEffect(0.95)
                .animation(.smooth(duration: 0.6), value: text)
        }
    }

    // State indication - whisper from the void
    @ViewBuilder
    private var etherealState: some View {
        if geminiService.isListening {
            VStack(spacing: 4) {
                Text("Listening...")
                    .foregroundColor(Color.white.opacity(0.6))
                    .font(.system(size: 10, weight: .ultraLight, design: .monospaced))
                    .tracking(3)

                Text("AI consciousness")
                    .foregroundColor(Color.cyan.opacity(0.7))
                    .font(.system(size: 8, weight: .ultraLight))
                    .tracking(2)
            }
            .opacity(0.8)
            .animation(.easeIn(duration: 0.8).delay(Double.random(in: 0...1.5)), value: "listening")
        } else if geminiService.isProcessing {
            Text("Thinking...")
                .foregroundColor(Color.purple.opacity(0.6))
                .font(.system(size: 10, weight: .ultraLight, design: .rounded))
                .tracking(2)
                .opacity(0.7)
                .animation(.easeIn(duration: 0.8), value: "thinking")
        }
    }
}

// MARK: - Supporting Components

struct ThinkingIndicator: View {
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 3) {
                ForEach(0..<3) { dot in
                    Circle()
                        .fill(Color.purple.opacity(0.6))
                        .frame(width: 6, height: 6)
                        .scaleEffect(1.1)
                }
            }
            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: UUID())
        }
    }
}
