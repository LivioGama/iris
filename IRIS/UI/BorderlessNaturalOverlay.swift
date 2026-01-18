//
//  BorderlessNaturalOverlay.swift
//  IRIS
//
//  Pure floating UI elements - no containers, no borders, no glass effects
//

import SwiftUI
import IRISCore
import IRISNetwork

/// Pure floating overlay with separate, disconnected UI elements
struct BorderlessNaturalOverlay: View {
    @ObservedObject var geminiService: GeminiAssistantOrchestrator

    var body: some View {
        ZStack {
            // Completely transparent base - no hit testing on background
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)

            // Floating elements that operate independently
            floatingElements
        }
    }

    @ViewBuilder
    private var floatingElements: some View {
        // Only show when screenshot is captured
        if geminiService.capturedScreenshot != nil {
            VStack {
                Spacer()
                HStack {
                    Spacer()

                    // Countdown indicator (top-right when preparing)
                    if !geminiService.isListening && !geminiService.isProcessing && geminiService.chatMessages.isEmpty {
                        floatingCountdown
                    }

                    Spacer()
                }

                Spacer()

                // Main floating elements center-bottom
                VStack(spacing: 24) {
                    // Audio visualizer (appears during listening)
                    if geminiService.isListening {
                        floatingAudioVisualizer
                    }

                    // Live text (appears during speaking)
                    if geminiService.isListening && !geminiService.liveTranscription.isEmpty {
                        floatingLiveText
                    }

                    // Status indicator
                    if geminiService.isListening || geminiService.isProcessing {
                        floatingStatus
                    }
                }
                .padding(.bottom, 100)  // Keep away from dock

                Spacer()
            }
        }
    }

    @ViewBuilder
    private var floatingCountdown: some View {
        VStack(spacing: 8) {
            // Pure text countdown - no container
            Text("5")
                .foregroundColor(Color.white.opacity(0.95))
                .font(.system(size: 72, weight: .thin, design: .rounded))
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                .animation(.smooth(duration: 0.5), value: geminiService.liveTranscription)

            Text("Ready when you are")
                .foregroundColor(Color.white.opacity(0.7))
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .tracking(1)
        }
        .padding(.trailing, 40)
        .padding(.top, 40)
    }

    @ViewBuilder
    private var floatingAudioVisualizer: some View {
        // Individual floating bars - no container
        HStack(spacing: 3) {
            ForEach(0..<28) { i in
                BarElement(index: i)
                    .padding(.horizontal, 1)
            }
        }
        .scaleEffect(0.8)
    }

    @ViewBuilder
    private var floatingLiveText: some View {
        // Pure floating text - no container
        VStack(spacing: 12) {
            Text("Understanding...")
                .foregroundColor(Color.white.opacity(0.8))
                .font(.system(size: 14, weight: .medium))
                .tracking(0.5)

            Text(geminiService.liveTranscription)
                .foregroundColor(Color.white.opacity(0.95))
                .font(.system(size: 18, weight: .regular, design: .rounded))
                .lineSpacing(6)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 600)
                .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
        }
    }

    @ViewBuilder
    private var floatingStatus: some View {
        // Floating indicator dot
        HStack(spacing: 12) {
            Circle()
                .fill(Color.cyan.gradient)
                .frame(width: 10, height: 10)
                .shadow(color: Color.cyan.opacity(0.4), radius: 12, x: 0, y: 0)
                .scaleEffect(1.2)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: UUID())

            Text("AI processing")
                .foregroundColor(Color.white.opacity(0.7))
                .font(.system(size: 13, weight: .medium))
                .tracking(0.5)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

/// Individual floating bar element - fully independent
struct BarElement: View {
    let index: Int
    @State private var height = CGFloat.random(in: 8...64)
    @State private var animating = false

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.cyan.gradient)
            .frame(width: 4, height: animating ? height : 4)
            .shadow(color: Color.cyan.opacity(0.3), radius: 6, x: 0, y: 0)
            .animation(
                .easeInOut(duration: Double.random(in: 0.3...0.8))
                    .repeatForever(autoreverses: true),
                value: animating
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    animating.toggle()
                    height = CGFloat.random(in: 8...64)
                }
            }
    }
}
