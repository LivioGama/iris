//
//  IRISFuturisticGazeIndicator.swift
//  IRIS
//
//  Created by Claude on 2025-01-17.
//

import SwiftUI
import IRISGaze
import IRISCore

/// Futuristic gaze indicator that feels like an intelligent presence
struct IRISFuturisticGazeIndicator: View {
    let gazePoint: CGPoint
    let detectedElement: DetectedElement?
    let config: GazeIndicatorConfig
    let screen: NSScreen
    let snapToElement: Bool

    @State private var awarenessIntensity: Double = 0.3
    @State private var consciousnessPulse: Double = 1.0
    @State private var timer: Timer?

    private let indicatorSize: CGFloat = 160

    /// Computes the display position - snaps to element center if enabled and element exists
    private var snappedPosition: CGPoint? {
        guard snapToElement,
              let element = detectedElement,
              let localBounds = convertToLocalCoordinates(element.bounds),
              localBounds.width > 0,
              localBounds.height > 0 else {
            return nil
        }

        // Snap to center of the detected element
        return CGPoint(x: localBounds.midX, y: localBounds.midY)
    }

    var body: some View {
        let effectivePosition = snappedPosition ?? gazePoint

        ZStack {
            // Element rectangle highlight (when detected) - absolute positioning
            // Only show if the element is on THIS screen
            if let element = detectedElement,
               let localBounds = convertToLocalCoordinates(element.bounds),
               localBounds.width > 0,
               localBounds.height > 0 {
                elementHighlight(for: localBounds)
                    .allowsHitTesting(false)
            }

            // Gaze indicators - positioned at gaze point or snapped to element center
            ZStack {
                // Main consciousness field
                consciousnessField
                    .allowsHitTesting(false)

                // Awareness indicator (always visible for now to debug)
                awarenessIndicator
                    .opacity(detectedElement != nil ? 1.0 : 0.3)
                    .transition(.scale.combined(with: .opacity))
            }
            .position(effectivePosition)
            // Smooth animation only when snapping is enabled - jumps between elements
            .animation(snapToElement ? .spring(response: 0.25, dampingFraction: 0.8) : nil, value: detectedElement?.bounds)
        }
        .onAppear {
            startConsciousnessCycle()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private var consciousnessField: some View {
        ZStack {
            // Outer consciousness ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            config.color.opacity(0.4),
                            config.color.opacity(0.2),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .frame(width: indicatorSize * 0.9, height: indicatorSize * 0.9)
                .scaleEffect(consciousnessPulse)
                .blur(radius: 1)

            // Intelligence field
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            config.color.opacity(awarenessIntensity),
                            config.color.opacity(awarenessIntensity * 0.5),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: indicatorSize / 3
                    )
                )
                .frame(width: indicatorSize * 0.7, height: indicatorSize * 0.7)
                .blur(radius: 8)

            // Inner awareness core
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            config.color.opacity(0.8),
                            config.color.opacity(0.4)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.6), lineWidth: 1)
                        .blur(radius: 1)
                )
                .frame(width: 20, height: 20)
                .shadow(color: config.color.opacity(0.5), radius: 12)
        }
    }

    private var awarenessIndicator: some View {
        Circle()
            .stroke(
                LinearGradient(
                    colors: [
                        config.color.opacity(0.6),
                        config.color.opacity(0.4),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 2
            )
            .frame(width: indicatorSize * 0.6, height: indicatorSize * 0.6)
            .scaleEffect(1 + (awarenessIntensity * 0.3))
    }

    private func startConsciousnessCycle() {
        // Awareness breathing - discrete random jumps every 2.5s (original algorithm)
        timer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 1.0)) {
                awarenessIntensity = Double.random(in: 0.2...0.4)
                consciousnessPulse = Double.random(in: 0.95...1.05)
            }
        }
    }

    // MARK: - Element Highlighting
    /// Convert element bounds from global Accessibility coordinates to window local coordinates
    private func convertToLocalCoordinates(_ globalBounds: CGRect) -> CGRect? {
        guard !globalBounds.isNull else { return nil }

        let standardized = globalBounds.standardized
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }

        // Use primary screen (origin 0,0) as reference, NOT NSScreen.main
        let primaryScreen = NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.screens[0]
        let referenceMaxY = primaryScreen.frame.maxY
        let appKitRect = CGRect(
            x: standardized.origin.x,
            y: referenceMaxY - (standardized.origin.y + standardized.height),
            width: standardized.width,
            height: standardized.height
        )

        let screenFrame = screen.frame
        let intersection = appKitRect.intersection(screenFrame)
        guard !intersection.isNull, !intersection.isEmpty else {
            return nil
        }

        let localX = intersection.origin.x - screenFrame.minX
        let localBottomY = intersection.origin.y - screenFrame.minY
        let localTopY = screenFrame.height - localBottomY - intersection.height

        let localRect = CGRect(
            x: localX,
            y: localTopY,
            width: intersection.width,
            height: intersection.height
        )

        let logEntry = "🔁 Highlight conversion \(screen.localizedName ?? "screen"): AX \(standardized) → AppKit \(appKitRect) → Local \(localRect) | primaryOrigin \(primaryScreen.frame.origin)"
        print(logEntry)
        try? logEntry.appendLine(to: "/tmp/iris_detection.log")

        return localRect
    }

    private func elementHighlight(for localBounds: CGRect) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            config.color.opacity(0.15),
                            config.color.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: localBounds.width, height: localBounds.height)
                .position(x: localBounds.midX, y: localBounds.midY)

            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    LinearGradient(
                        colors: [
                            config.color.opacity(0.8),
                            config.color.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: localBounds.width, height: localBounds.height)
                .position(x: localBounds.midX, y: localBounds.midY)
        }
    }
}
