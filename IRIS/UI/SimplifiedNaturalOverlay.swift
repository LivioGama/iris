//
//  SimplifiedNaturalOverlay.swift
//  IRIS
//
//  Natural overlay that integrates seamlessly with existing IRIS ecosystem
//

import SwiftUI
import IRISCore
import IRISNetwork
import AppKit

/// Natural overlay that enhances existing system without breaking changes
struct SimplifiedNaturalOverlay: View {
    @ObservedObject var geminiService: GeminiAssistantOrchestrator

    var body: some View {
        ZStack {
            // Keep existing overlay as base
            GeminiResponseOverlayModern(geminiService: geminiService)

            // Natural enhancements when appropriate
            if geminiService.capturedScreenshot != nil {
                naturalEnhancements
            }
        }
    }

    @ViewBuilder
    private var naturalEnhancements: some View {
        if !geminiService.isListening && !geminiService.isProcessing && geminiService.chatMessages.isEmpty {
            // Natural thumbnail countdown
            NaturalThumbnailCountdown()
        } else {
            // Natural listening overlay
            NaturalListeningOverlay(geminiService: geminiService)
        }
    }
}

struct NaturalThumbnailCountdown: View {
    @State private var countdown = 5
    @State private var timerStarted = false
    @State private var glowing = true

    var body: some View {
        VStack {
            HStack {
                VStack(spacing: 8) {
                    // Glassmorphic thumbnail
                    ZStack {
                        // Background blur
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.05))
                            .background(
                                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.3),
                                                Color.cyan.opacity(0.2)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .frame(width: 120, height: 76)

                        // Glowing status indicator
                        Circle()
                            .fill(Color.cyan.gradient)
                            .frame(width: 6, height: 6)
                            .glowEffect()
                            .position(x: 110, y: 12)
                            .scaleEffect(glowing ? 1.5 : 1.0)
                            .opacity(glowing ? 0.6 : 0.3)

                        // Countdown text
                        if countdown > 0 {
                           Text("\(countdown)")
                               .foregroundColor(Color.cyan.opacity(0.9))
                               .font(.system(size: 11, weight: .bold, design: .rounded))
                               .padding(.top, 24)
                        }
                    }

                    // Subtle text
                    Text("Prepare...")
                        .foregroundColor(Color.white.opacity(0.6))
                        .font(.system(size: 10, weight: .medium))
                }

                Spacer()
            }
            .padding(20)

            Spacer()
        }
        .ignoresSafeArea()
        .onAppear {
            startCountdown()
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowing.toggle()
            }
        }
    }

    private func startCountdown() {
        guard !timerStarted else { return }
        timerStarted = true

        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            countdown -= 1
            if countdown <= 0 {
                timer.invalidate()
            }
        }
    }
}

struct NaturalListeningOverlay: View {
    @ObservedObject var geminiService: GeminiAssistantOrchestrator
    @State private var audioWaveform: [CGFloat] = []
    @State private var animating = true

    var body: some View {
        VStack(spacing: 32) {
            // Main floating overlay
            VStack(spacing: 20) {
                // Audio visualizer
                AudioWaveformVisualizer()
                    .frame(height: 80)

                Text("Listening to your voice...")
                    .foregroundColor(Color.white.opacity(0.95))
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                // Status indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.cyan.gradient)
                        .frame(width: 8, height: 8)
                        .glowEffect()

                    Text("Live")
                        .foregroundColor(Color.cyan.opacity(0.8))
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .padding(32)
            .background(
                GlassContainer(cornerRadius: 24)
                    .frame(maxWidth: 600, maxHeight: 180)
            )

            // Live transcript preview
            if !geminiService.liveTranscription.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("You said:")
                            .foregroundColor(Color.white.opacity(0.6))
                            .font(.system(size: 11, weight: .medium))

                        Spacer()

                        // Timestamp
                        Text(timeString())
                            .foregroundColor(Color.white.opacity(0.4))
                            .font(.system(size: 10, design: .monospaced))
                    }

                    Divider()
                        .background(Color.white.opacity(0.1))

                    Text(geminiService.liveTranscription)
                        .foregroundColor(Color.white.opacity(0.9))
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .lineSpacing(4)
                }
                .padding(16)
                .background(
                    GlassContainer(cornerRadius: 16)
                )
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 40)
    }

    private func timeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm"
        return formatter.string(from: Date())
    }
}

struct AudioWaveformVisualizer: View {
    @State private var animating = true

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<24) { _ in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.cyan.gradient.opacity(0.8))
                    .frame(width: 3, height: animating ? CGFloat.random(in: 4...64) : 4)
                    .animation(
                        .easeInOut(duration: Double.random(in: 0.2...0.6)).repeatForever(autoreverses: true),
                        value: animating
                    )
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                animating.toggle()
            }
        }
    }
}

struct GlassContainer: View {
    let cornerRadius: CGFloat

    init(cornerRadius: CGFloat = 18) {
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .background(
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.cyan.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.6
                    )
            )
    }
}

struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

extension View {
    func glowEffect() -> some View {
        self
            .overlay(
                Circle()
                    .fill(Color.cyan.opacity(0.4))
                    .frame(width: 30, height: 30)
                    .blur(radius: 20)
            )
    }
}
