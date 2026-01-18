import Foundation
import AppKit

// Debug script to print screen information
print("🖥️  Screen Debug Information")
print("============================")

for (index, screen) in NSScreen.screens.enumerated() {
    let frame = screen.frame
    let visibleFrame = screen.visibleFrame
    let isMain = screen === NSScreen.main

    print("Screen \(index) \(isMain ? "(MAIN)" : ""):")
    print("  Frame: \(Int(frame.width))x\(Int(frame.height)) @ (\(Int(frame.origin.x)), \(Int(frame.origin.y)))")
    print("  Visible Frame: \(Int(visibleFrame.width))x\(Int(visibleFrame.height)) @ (\(Int(visibleFrame.origin.x)), \(Int(visibleFrame.origin.y)))")
    print("  Max Y: \(Int(frame.maxY))")
    print("  Localized Name: \(screen.localizedName)")
    print("")
}

let globalMaxY = NSScreen.screens.map { $0.frame.maxY }.max() ?? 0
print("🌍 Global Max Y: \(Int(globalMaxY))")
print("📊 Total screens: \(NSScreen.screens.count)")
