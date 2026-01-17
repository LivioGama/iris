//
//  IRISFuturisticGazeIndicator.swift
//  IRIS
//
//  Enhanced gaze indicator with advanced animations and spatial depth
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
    var voiceActive: Bool = false
    
    @State private var awarenessIntensity: Double = 0.6
    @State private var consciousnessPulse: Double = 1.0
    @State private var timer: Timer?
    @State private var lastSnappedPosition: CGPoint? = nil
    @State private var voiceFlash: Bool = false
    @State private var orbRotation: Double = 0
    @State private var elementGlowIntensity: Double = 1.0
    
    private let indicatorSize: CGFloat = SimulationConfig.isDevelopmentMode ? 160 : 100
    private let verboseLogsEnabled = ProcessInfo.processInfo.environment["IRIS_VERBOSE_LOGS"] == "1"
    
    private var activeColor: Color {
        if voiceActive { return .red }
        return SimulationConfig.isDevelopmentMode ? config.color : IRISProductionColors.gazeIndicatorPrimary
    }

    private var accentColor: Color {
        if voiceActive { return .orange }
        return SimulationConfig.isDevelopmentMode ? Color(hex: "9177C7") : IRISProductionColors.gazeIndicatorSecondary
    }
    
    /// Computes the current element's center position if available
    private var currentElementCenter: CGPoint? {
        guard let element = detectedElement,
              let localBounds = convertToLocalCoordinates(element.bounds),
              localBounds.width > 0,
              localBounds.height > 0 else {
            return nil
        }
        return CGPoint(x: localBounds.midX, y: localBounds.midY)
    }
    
    var body: some View {
        // When snapping is enabled:
        // - If element detected: snap to element center
        // - If no element: stay at last snapped position (don't follow raw gaze)
        // When snapping is disabled: always follow raw gaze
        let effectivePosition: CGPoint = {
            if snapToElement {
                if let elementCenter = currentElementCenter {
                    return elementCenter
                } else if let lastPos = lastSnappedPosition {
                    return lastPos
                }
            }
            return gazePoint
        }()
        
        ZStack {
            // Element rectangle highlight (when detected) - absolute positioning
            if let element = detectedElement,
               let localBounds = convertToLocalCoordinates(element.bounds),
               localBounds.width > 0,
               localBounds.height > 0 {
                enhancedElementHighlight(for: localBounds)
                    .allowsHitTesting(false)
            }
            
            // Gaze indicators - positioned at gaze point or snapped to element center
            ZStack {
                // Outer energy field
                energyField
                    .allowsHitTesting(false)
                
                // Rotating orbital ring
                orbitalRing
                    .allowsHitTesting(false)
                
                // Main consciousness field
                consciousnessField
                    .allowsHitTesting(false)
                
                // Awareness indicator
                awarenessIndicator
                    .opacity(detectedElement != nil ? 1.0 : 0.4)
                    .transition(.scale.combined(with: .opacity))
            }
            .position(effectivePosition)
            .animation(snapToElement ? .spring(response: 0.25, dampingFraction: 0.8) : nil, value: detectedElement?.bounds)
        }
        .onAppear {
            startConsciousnessCycle()
            startOrbitalRotation()
            if let elementCenter = currentElementCenter {
                lastSnappedPosition = elementCenter
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
        .onChange(of: detectedElement?.bounds) {
            if snapToElement, let elementCenter = currentElementCenter {
                lastSnappedPosition = elementCenter
            }
            withAnimation(.easeInOut(duration: 0.3)) {
                elementGlowIntensity = 1.5
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    elementGlowIntensity = 1.0
                }
            }
        }
    }
    
    // MARK: - Enhanced Visual Components
    
    private var energyField: some View {
        return ZStack {
            // Pulsing outer ring
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(
                        activeColor.opacity(0.12 - Double(i) * 0.02),
                        lineWidth: voiceActive ? 3 : 1
                    )
                    .frame(width: indicatorSize * (1.0 + Double(i) * 0.15), height: indicatorSize * (1.0 + Double(i) * 0.15))
                    .scaleEffect(consciousnessPulse * (1.0 + Double(i) * 0.05))
                    .blur(radius: CGFloat(i) * 2)
                    .animation(
                        .easeInOut(duration: IRISAnimationTiming.consciousness)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.3),
                        value: consciousnessPulse
                    )
            }
        }
    }
    
    private var orbitalRing: some View {
        return ZStack {
            // Rotating gradient ring
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            activeColor.opacity(0.5),
                            accentColor.opacity(0.35),
                            activeColor.opacity(0.18),
                            accentColor.opacity(0.35),
                            activeColor.opacity(0.5)
                        ],
                        center: .center
                    ),
                    lineWidth: 1.5
                )
                .frame(width: indicatorSize * 0.75, height: indicatorSize * 0.75)
                .rotationEffect(.degrees(orbRotation))
                .blur(radius: 1)

            // Orbital dots
            ForEach(0..<4, id: \.self) { i in
                let angle = Double(i) * 90 + orbRotation * 0.5
                Circle()
                    .fill(activeColor.opacity(0.7))
                    .frame(width: 5, height: 5)
                    .offset(
                        x: cos(angle * .pi / 180) * indicatorSize * 0.375,
                        y: sin(angle * .pi / 180) * indicatorSize * 0.375
                    )
            }
        }
    }
    
    private var consciousnessField: some View {
        return ZStack {
            // Outer consciousness ring with gradient stroke
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            activeColor.opacity(voiceActive ? 0.5 : 0.25),
                            accentColor.opacity(voiceActive ? 0.3 : 0.12),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: voiceActive ? 3 : 1.2
                )
                .frame(width: indicatorSize * 0.9, height: indicatorSize * 0.9)
                .scaleEffect(voiceActive ? 1.15 : consciousnessPulse)
                .blur(radius: 1)

            // Intelligence field - radial glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            activeColor.opacity(voiceActive ? 0.5 : awarenessIntensity * 0.8),
                            accentColor.opacity(voiceActive ? 0.25 : awarenessIntensity * 0.35),
                            activeColor.opacity(voiceActive ? 0.1 : awarenessIntensity * 0.15),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: indicatorSize / 3
                    )
                )
                .frame(width: indicatorSize * 0.7, height: indicatorSize * 0.7)
                .blur(radius: 5)

            // Inner awareness core with shimmer
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            activeColor.opacity(0.85),
                            accentColor.opacity(0.55),
                            activeColor.opacity(0.35)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.6),
                                    Color.white.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                        .blur(radius: 0.5)
                )
                .frame(width: voiceActive ? 28 : 20, height: voiceActive ? 28 : 20)
                .shadow(color: activeColor.opacity(0.5), radius: voiceActive ? 25 : 12)
        }
        .animation(.easeInOut(duration: IRISAnimationTiming.quick), value: voiceActive)
    }
    
    private var awarenessIndicator: some View {
        return Circle()
            .stroke(
                LinearGradient(
                    colors: [
                        activeColor.opacity(0.6),
                        accentColor.opacity(0.4),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: voiceActive ? 3 : 1.5
            )
            .frame(width: indicatorSize * 0.55, height: indicatorSize * 0.55)
            .scaleEffect(1 + (awarenessIntensity * 0.25))
            .animation(.easeInOut(duration: IRISAnimationTiming.quick), value: voiceActive)
    }
    
    // MARK: - Enhanced Element Highlight
    
    private func enhancedElementHighlight(for localBounds: CGRect) -> some View {
        let isProduction = !SimulationConfig.isDevelopmentMode
        let glowScale = isProduction ? 0.8 : 1.0
        let borderOpacityScale = isProduction ? 0.7 : 1.0
        return ZStack {
            // Background glow
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    RadialGradient(
                        colors: [
                            activeColor.opacity(0.25 * elementGlowIntensity * glowScale),
                            activeColor.opacity(0.1 * elementGlowIntensity * glowScale),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: max(localBounds.width, localBounds.height) / 2
                    )
                )
                .frame(
                    width: localBounds.width + 20,
                    height: localBounds.height + 20
                )
                .position(x: localBounds.midX, y: localBounds.midY)
                .blur(radius: 8)

            // Main highlight fill
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [
                            activeColor.opacity(0.12 * elementGlowIntensity * glowScale),
                            activeColor.opacity(0.06 * elementGlowIntensity * glowScale)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: localBounds.width, height: localBounds.height)
                .position(x: localBounds.midX, y: localBounds.midY)

            // Animated border
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    LinearGradient(
                        colors: [
                            activeColor.opacity(0.9 * borderOpacityScale),
                            accentColor.opacity(0.7 * borderOpacityScale),
                            activeColor.opacity(0.5 * borderOpacityScale)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: localBounds.width, height: localBounds.height)
                .position(x: localBounds.midX, y: localBounds.midY)
                .overlay(
                    // Corner accents
                    cornerAccents(for: localBounds)
                )
        }
    }
    
    private func cornerAccents(for bounds: CGRect) -> some View {
        ZStack {
            // Top-left corner
            cornerAccent
                .position(x: bounds.minX, y: bounds.minY)
            
            // Top-right corner
            cornerAccent
                .position(x: bounds.maxX, y: bounds.minY)
            
            // Bottom-left corner
            cornerAccent
                .position(x: bounds.minX, y: bounds.maxY)
            
            // Bottom-right corner
            cornerAccent
                .position(x: bounds.maxX, y: bounds.maxY)
        }
    }
    
    private var cornerAccent: some View {
        ZStack {
            Circle()
                .fill(activeColor)
                .frame(width: 6, height: 6)
            Circle()
                .fill(Color.white.opacity(0.8))
                .frame(width: 3, height: 3)
        }
    }
    
    // MARK: - Animation Controllers
    
    private func startConsciousnessCycle() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 1.0)) {
                awarenessIntensity = Double.random(in: 0.5...0.85)
                consciousnessPulse = Double.random(in: 0.95...1.08)
            }
        }
    }
    
    private func startOrbitalRotation() {
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            orbRotation += 0.5
            if orbRotation >= 360 {
                orbRotation = 0
            }
        }
    }
    
    // MARK: - Coordinate Conversion
    
    private func convertToLocalCoordinates(_ globalBounds: CGRect) -> CGRect? {
        guard !globalBounds.isNull else { return nil }
        
        let standardized = globalBounds.standardized
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }
        
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
        
        if verboseLogsEnabled {
            let logEntry = "🔁 Highlight conversion \(screen.localizedName): AX \(standardized) → AppKit \(appKitRect) → Local \(localRect) | primaryOrigin \(primaryScreen.frame.origin)"
            print(logEntry)
            try? logEntry.appendLine(to: "/tmp/iris_detection.log")
        }
        
        return localRect
    }
}
