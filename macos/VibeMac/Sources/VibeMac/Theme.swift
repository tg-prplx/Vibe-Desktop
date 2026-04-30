import AppKit
import SwiftUI

enum VibeTheme {
    static let mistralOrange = NSColor(hex: 0xFF8205)
    static let background = NSColor(hex: 0x141414)
    static let sidebar = NSColor(hex: 0x171717)
    static let workspace = NSColor(hex: 0x1A1A1A)
    static let inspector = NSColor(hex: 0x181818)
    static let panel = NSColor(hex: 0x222222)
    static let panelElevated = NSColor(hex: 0x2A2A2A)
    static let terminalBackground = NSColor(hex: 0x161616)
    static let terminalForeground = NSColor(hex: 0xECECEC)
    static let mutedText = NSColor(hex: 0xA0A0A0)
    static let border = NSColor(hex: 0x3A3A3A)
    static let selection = NSColor(hex: 0x303030)
    static let badge = NSColor(hex: 0x2D2D2D)
    static let warningSurface = NSColor(hex: 0x282828)
    static let errorSurface = NSColor(hex: 0x282828)
    static let red = NSColor(hex: 0xFF5F57)
    static let green = NSColor(hex: 0x55D187)
    static let yellow = NSColor(hex: 0xF5C35B)
    static let blue = NSColor(hex: 0x8E8E8E)
    static let magenta = NSColor(hex: 0xB0B0B0)
    static let cyan = NSColor(hex: 0xB8B8B8)
    static let brightBlack = NSColor(hex: 0x707070)

    static let swiftBackground = Color(nsColor: background)
    static let swiftSidebar = Color(nsColor: sidebar)
    static let swiftWorkspace = Color(nsColor: workspace)
    static let swiftInspector = Color(nsColor: inspector)
    static let swiftPanel = Color(nsColor: panel)
    static let swiftPanelElevated = Color(nsColor: panelElevated)
    static let swiftTerminalBackground = Color(nsColor: terminalBackground)
    static let swiftForeground = Color(nsColor: terminalForeground)
    static let swiftMuted = Color(nsColor: mutedText)
    static let swiftBorder = Color(nsColor: border)
    static let swiftSelection = Color(nsColor: selection)
    static let swiftBadge = Color(nsColor: badge)
    static let swiftWarningSurface = Color(nsColor: warningSurface)
    static let swiftErrorSurface = Color(nsColor: errorSurface)
    static let swiftOrange = Color(nsColor: mistralOrange)
    static let swiftCyan = Color(nsColor: cyan)
    static let swiftGreen = Color(nsColor: green)
    static let swiftYellow = Color(nsColor: yellow)
    static let swiftRed = Color(nsColor: red)
    static let swiftBlue = Color(nsColor: blue)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        self.init(
            calibratedRed: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: alpha
        )
    }
}
