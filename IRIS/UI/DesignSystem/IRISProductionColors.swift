import SwiftUI

/// Color scheme configuration that adapts based on development/production mode
/// Development: Vibrant, eye-catching colors for visibility during testing
/// Production: Subtle, professional colors for end users
public struct IRISProductionColors {
    
    // MARK: - Gaze Indicator Colors
    
    /// Primary gaze indicator color
    public static var gazeIndicatorPrimary: Color {
        if SimulationConfig.isDevelopmentMode {
            // Development: Vibrant cyan
            return Color(hex: "00D9FF")
        } else {
            // Production: Soft cool gray — visible but refined
            return Color(hex: "C8D0DC").opacity(0.18)
        }
    }

    /// Secondary gaze indicator color (for gradients)
    public static var gazeIndicatorSecondary: Color {
        if SimulationConfig.isDevelopmentMode {
            // Development: Vibrant purple
            return Color(hex: "7B61FF")
        } else {
            // Production: Subtle cool accent
            return Color(hex: "B0BCC8").opacity(0.12)
        }
    }

    /// Gaze indicator shadow/glow
    public static var gazeIndicatorGlow: Color {
        if SimulationConfig.isDevelopmentMode {
            // Development: Strong cyan glow
            return Color(hex: "00D9FF").opacity(0.6)
        } else {
            // Production: Near-invisible shadow
            return Color.black.opacity(0.03)
        }
    }
    
    // MARK: - Overlay Background Colors
    
    /// Main overlay background
    public static var overlayBackground: Color {
        if SimulationConfig.isDevelopmentMode {
            // Development: Darker with more presence
            return Color.black.opacity(0.85)
        } else {
            // Production: Very subtle, barely visible
            return Color.black.opacity(0.5)
        }
    }
    
    /// Overlay glass effect tint
    public static var overlayGlassTint: Color {
        if SimulationConfig.isDevelopmentMode {
            // Development: Pronounced purple tint
            return Color(hex: "9177C7").opacity(0.25)
        } else {
            // Production: Very subtle gray tint
            return Color.gray.opacity(0.08)
        }
    }
    
    // MARK: - Text & Message Colors
    
    /// Gemini response text gradient start
    public static var geminiTextStart: Color {
        if SimulationConfig.isDevelopmentMode {
            // Development: Vibrant purple
            return Color(hex: "9177C7")
        } else {
            // Production: Soft gray-blue
            return Color(hex: "B8C5D0")
        }
    }
    
    /// Gemini response text gradient end
    public static var geminiTextEnd: Color {
        if SimulationConfig.isDevelopmentMode {
            // Development: Bright white
            return Color.white
        } else {
            // Production: Soft white
            return Color.white.opacity(0.85)
        }
    }
    
    /// Message bubble background
    public static var messageBubbleBackground: Color {
        if SimulationConfig.isDevelopmentMode {
            // Development: Purple with strong presence
            return Color(hex: "9177C7").opacity(0.15)
        } else {
            // Production: Very subtle gray
            return Color.gray.opacity(0.05)
        }
    }
    
    // MARK: - Accent Colors for States
    
    /// Tracking enabled accent
    public static var trackingEnabledAccent: Color {
        if SimulationConfig.isDevelopmentMode {
            // Development: Bright cyan
            return Color(hex: "00D9FF")
        } else {
            // Production: Subtle green
            return Color(hex: "9BC5A3").opacity(0.7)
        }
    }
    
    /// Tracking disabled accent
    public static var trackingDisabledAccent: Color {
        if SimulationConfig.isDevelopmentMode {
            // Development: Bright red
            return Color(hex: "FF6B6B")
        } else {
            // Production: Subtle gray
            return Color(hex: "C5C5C5").opacity(0.6)
        }
    }
    
    // MARK: - Settings Panel Colors
    
    /// Settings panel indicator (tracking on)
    public static var settingsIndicatorOn: Color {
        if SimulationConfig.isDevelopmentMode {
            return Color.cyan
        } else {
            return Color(hex: "A8D5BA").opacity(0.8)
        }
    }
    
    /// Settings panel indicator (tracking off)
    public static var settingsIndicatorOff: Color {
        if SimulationConfig.isDevelopmentMode {
            return Color.red
        } else {
            return Color(hex: "D5A8A8").opacity(0.7)
        }
    }
    
    // MARK: - Gemini Branding Colors (Blue/Purple/Pink)
    
    /// Gemini blue - primary brand color
    public static var geminiBlue: Color {
        if SimulationConfig.isDevelopmentMode {
            return Color(hex: "4796E3")
        } else {
            return Color(hex: "B8C5D0").opacity(0.6)
        }
    }
    
    /// Gemini purple - secondary brand color
    public static var geminiPurple: Color {
        if SimulationConfig.isDevelopmentMode {
            return Color(hex: "9177C7")
        } else {
            return Color(hex: "C8D0E0").opacity(0.5)
        }
    }
    
    /// Gemini pink/red - tertiary brand color
    public static var geminiPink: Color {
        if SimulationConfig.isDevelopmentMode {
            return Color(hex: "CA6673")
        } else {
            return Color(hex: "D5D5D5").opacity(0.4)
        }
    }
    
    // MARK: - Helper Functions for Opacity Variants
    
    /// Returns Gemini blue with specified opacity
    public static func geminiBlue(_ opacity: Double) -> Color {
        return geminiBlue.opacity(opacity)
    }
    
    /// Returns Gemini purple with specified opacity
    public static func geminiPurple(_ opacity: Double) -> Color {
        return geminiPurple.opacity(opacity)
    }
    
    /// Returns Gemini pink with specified opacity
    public static func geminiPink(_ opacity: Double) -> Color {
        return geminiPink.opacity(opacity)
    }
    
    /// Light blue variant for text gradients
    public static var geminiBlueLight: Color {
        if SimulationConfig.isDevelopmentMode {
            return Color(hex: "B8D4F0")
        } else {
            return Color.white.opacity(0.7)
        }
    }
    
    /// Light purple variant for text gradients
    public static var geminiPurpleLight: Color {
        if SimulationConfig.isDevelopmentMode {
            return Color(hex: "C4B5F0")
        } else {
            return Color.white.opacity(0.65)
        }
    }
}
