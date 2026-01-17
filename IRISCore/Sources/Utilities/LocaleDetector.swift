import Foundation

/// Utility for detecting user's locale and region
public class LocaleDetector {
    
    /// Checks if the current system locale is set to Germany
    /// - Returns: true if the user's region is Germany (DE)
    public static func isGermany() -> Bool {
        let locale = Locale.current
        
        // Check region code
        if let regionCode = locale.region?.identifier {
            return regionCode == "DE"
        }
        
        // Fallback: check language code
        if let languageCode = locale.language.languageCode?.identifier {
            return languageCode == "de"
        }
        
        return false
    }
    
    /// Gets the current region code (e.g., "DE", "US", "FR")
    /// - Returns: ISO region code or nil if not available
    public static func getCurrentRegion() -> String? {
        return Locale.current.region?.identifier
    }
    
    /// Gets the current language code (e.g., "de", "en", "fr")
    /// - Returns: ISO language code or nil if not available
    public static func getCurrentLanguage() -> String? {
        return Locale.current.language.languageCode?.identifier
    }
}
