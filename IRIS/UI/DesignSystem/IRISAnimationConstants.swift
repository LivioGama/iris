//
//  IRISAnimationConstants.swift
//  IRIS
//
//  Centralized animation constants for consistent UI feel
//

import SwiftUI

/// Animation timing presets for IRIS UI
enum IRISAnimationTiming {
    /// Instant feedback - 0.15s (micro-interactions)
    static let instant: Double = 0.15
    
    /// Quick transitions - 0.2s (hover states, toggles)
    static let quick: Double = 0.2
    
    /// Standard transitions - 0.3s (state changes, reveals)
    static let standard: Double = 0.3
    
    /// Smooth transitions - 0.4s (modals, sheets)
    static let smooth: Double = 0.4
    
    /// Dramatic transitions - 0.6s (major state changes)
    static let dramatic: Double = 0.6
    
    /// Ambient pulse cycle - 2.0s (breathing effects)
    static let ambient: Double = 2.0
    
    /// Consciousness cycle - 2.5s (AI presence)
    static let consciousness: Double = 2.5
    
    /// Easing curves
    static let easeInOut = Animation.easeInOut(duration: standard)
    static let easeOut = Animation.easeOut(duration: standard)
    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.75)
    static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.6)
    static let snappy = Animation.spring(response: 0.25, dampingFraction: 0.8)
}

/// View modifiers for consistent animations
struct IRISHoverEffect: ViewModifier {
    @State private var isHovered = false
    
    var scale: CGFloat = 1.02
    var lift: CGFloat = -2
    var shadowRadius: CGFloat = 20
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? scale : 1.0)
            .offset(y: isHovered ? lift : 0)
            .shadow(
                color: Color.black.opacity(isHovered ? 0.3 : 0.15),
                radius: isHovered ? shadowRadius : 10,
                x: 0,
                y: isHovered ? 8 : 4
            )
            .animation(.easeOut(duration: IRISAnimationTiming.quick), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

struct IRISAppearEffect: ViewModifier {
    let delay: Double
    @State private var isVisible = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .onAppear {
                withAnimation(.easeOut(duration: IRISAnimationTiming.standard).delay(delay)) {
                    isVisible = true
                }
            }
    }
}

struct IRISStaggeredAppear: ViewModifier {
    let index: Int
    @State private var isVisible = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .scaleEffect(isVisible ? 1 : 0.95)
            .onAppear {
                withAnimation(
                    IRISAnimationTiming.spring.delay(Double(index) * 0.08)
                ) {
                    isVisible = true
                }
            }
    }
}

/// Glassmorphic card modifier
struct IRISGlassCard: ViewModifier {
    var tint: Color = .cyan
    var opacity: Double = 0.08
    var cornerRadius: CGFloat = 16
    
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                ZStack {
                    // Base layer
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    
                    // Tint gradient
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    tint.opacity(opacity),
                                    tint.opacity(opacity * 0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

extension View {
    /// Apply hover lift effect
    func irisHover(scale: CGFloat = 1.02, lift: CGFloat = -2) -> some View {
        modifier(IRISHoverEffect(scale: scale, lift: lift))
    }
    
    /// Apply appear animation with delay
    func irisAppear(delay: Double = 0) -> some View {
        modifier(IRISAppearEffect(delay: delay))
    }
    
    /// Apply staggered appear based on index
    func irisStaggered(index: Int) -> some View {
        modifier(IRISStaggeredAppear(index: index))
    }
    
    /// Apply glass card styling
    func irisGlass(tint: Color = .cyan, opacity: Double = 0.08) -> some View {
        modifier(IRISGlassCard(tint: tint, opacity: opacity))
    }
}
