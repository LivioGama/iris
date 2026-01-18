//
//  EtherealFloatingOverlay.swift
//  IRIS
//
//  Truly ethereal overlay - no physical boundaries, pure abstract AI presence
//

import SwiftUI
import IRISCore
import IRISNetwork
import AppKit

/// Pure ethereal overlay - individual floating elements, no containers, no connections
struct EtherealFloatingOverlay: View {
    @ObservedObject var geminiService: GeminiAssistantOrchestrator

    var body: some View {
        // NOTHING exists when no screenshot - completely ethereal
        if geminiService.capturedScreenshot != nil {
            etherealElements
        }
    }

    @ViewBuilder
    private var etherealElements: some View {
        ZStack {
            // Individual floating elements positioned independently across the screen

            // Top-left area: gentle nudge awareness
            VStack {
                HStack {
                    Spacer().frame(width: 20)

                    if geminiService.isListening || geminiService.isProcessing || !geminiService.chatMessages.isEmpty {
                        // Tiny ethereal presence indicator
                        etherealPresence
                    }

                    Spacer()
                }
                Spacer().frame(height: 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Center: when active, show the soul
            if geminiService.isListening || geminiService.isProcessing {
                VStack {
                    Spacer().frame(height: NSScreen.main?.frame.height ?? 1600 * 0.2)

                    // Floating audio soul - no container, just essence
                    etherealSoul

                    Spacer()
                }
            }

            // Bottom-right: minimalist state whisper
            VStack {
                Spacer().frame(height: NSScreen.main?.frame.height ?? 1600 * 0.7)

                HStack {
                    Spacer()

                    // State indication - barely perceptible
                    if geminiService.isListening {
                        etherealState("Listening...")
                    } else if geminiService.isProcessing {
                        etherealState("Thinking...")
                    }

                    Spacer().frame(width: 40)
                }

                Spacer().frame(height: 100)
            }
        }
        .allowsHitTesting(false) // Never interfere with underlying apps
    }

    // MARK: - Ethereal Components

    // Pure presence - just a dot of consciousness
    @ViewBuilder
    private var etherealPresence: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color.cyan.opacity(0.6), Color.cyan.opacity(0.1)],
                    center: .center,
                    startRadius: 0,
                    endRadius: 20
                )
            )
            .frame(width: 8, height: 8)
            .shadow(color: Color.cyan.opacity(0.2), radius: 10, x: 0, y: 0)
            .scaleEffect(1.3)
            .opacity(0.8)
            .animation(.smooth(duration: 1.2).repeatForever(autoreverses: true), value: UUID())
    }

    // The soul - pure abstraction of listening
    @ViewBuilder
    private var etherealSoul: some View {
        VStack(spacing: 48) {
            // Abstract audio visualization - pure energy
            etherealAudioField

            // Live transcription appears as ghost text
            if !geminiService.liveTranscription.isEmpty {
                etherealGhostText(geminiService.liveTranscription)
            }
        }
        .padding(.horizontal, 60)
    }

    // Audio field - abstract energy waves
    @ViewBuilder
    private var etherealAudioField: some View {
        HStack(spacing: 6) {
            ForEach(0..<36) { _ in
                etherealWaveBar
            }
        }
        .opacity(0.7)
        .scaleEffect(0.9)
    }

    // Individual wave bar - pure abstraction
    @ViewBuilder
    private var etherealWaveBar: some View {
        let randomHeight = CGFloat.random(in: 12...96)
        let delay = Double.random(in: 0...2.0)

        Rectangle()
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
            .opacity(Double.random(in: 0.3...0.9))
            .animation(
                .easeInOut(duration: Double.random(in: 0.8...2.4))
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: CGFloat.random(in: 8...96)
            )
    }

    // Ghost text - barely visible whisper
    @ViewBuilder
    private func etherealGhostText(_ text: String) -> some View {
        VStack(spacing: 12) {
            // Main text - ghostly presence
            Text(text)
                .foregroundColor(Color.white.opacity(0.85))
                .font(.system(size: 20, weight: .thin, design: .rounded))
                .tracking(0.8)
                .lineSpacing(8)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 700, maxHeight: 120)
                .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 6)
                .opacity(0.9)

            // Ghostly subtitle
            if text.count > 10 {
                Text("I understand")
                    .foregroundColor(Color.white.opacity(0.5))
                    .font(.system(size: 11, weight: .ultraLight, design: .rounded))
                    .tracking(2)
            }
        }
        .scaleEffect(0.95)
        .animation(.smooth(duration: 0.6), value: text)
    }

    // State indication - whisper from the void
    @ViewBuilder
    private func etherealState(_ text: String) -> some View {
        Text(text)
            .foregroundColor(Color.white.opacity(0.4))
            .font(.system(size: 10, weight: .ultraLight, design: .monospaced))
            .tracking(3)
            .opacity(0.6)
            .animation(.easeIn(duration: 0.8).delay(Double.random(in: 0...1.5)), value: text)
    }
}
