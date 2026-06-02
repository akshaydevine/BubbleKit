// BubbleKitTheme.swift
// Matches the Figma "Message UIKit" color & effect styles exactly.

import SwiftUI

// MARK: - Color Palette

public struct BubbleKitColors {
    public var appleBlack:        Color
    public var appleGrey:         Color
    public var lightGrey:         Color
    public var white:             Color
    public var notifyPurple:      Color
    public var appleBlue:         Color
    public var messageSentNew:    Color
    public var messageSentOld:    Color
    public var background:        Color
    public var rowBackground:     Color
    public var searchBackground:  Color
    public var pinnedBackground:  Color
    public var popoverBackground: Color
    public var separator:         Color

    public static let `default` = BubbleKitColors(
        appleBlack:        Color(hex: "#000000"),
        appleGrey:         Color(hex: "#8E8E93"),
        lightGrey:         Color(hex: "#C7C7CC"),
        white:             Color(hex: "#FFFFFF"),
        notifyPurple:      Color(hex: "#AF52DE"),
        appleBlue:         Color(hex: "#007AFF"),
        messageSentNew:    Color(hex: "#007AFF"),
        messageSentOld:    Color(hex: "#C7C7CC"),
        background:        Color(hex: "#FFFFFF"),
        rowBackground:     Color(hex: "#FFFFFF"),
        searchBackground:  Color(hex: "#F2F2F7"),
        pinnedBackground:  Color(hex: "#FFFFFF"),
        popoverBackground: Color(hex: "#FFFFFF"),
        separator:         Color(hex: "#C6C6C8")
    )

    public static let dark = BubbleKitColors(
        appleBlack:        Color(hex: "#FFFFFF"),
        appleGrey:         Color(hex: "#8E8E93"),
        lightGrey:         Color(hex: "#3A3A3C"),
        white:             Color(hex: "#1C1C1E"),
        notifyPurple:      Color(hex: "#BF5AF2"),
        appleBlue:         Color(hex: "#0A84FF"),
        messageSentNew:    Color(hex: "#0A84FF"),
        messageSentOld:    Color(hex: "#48484A"),
        background:        Color(hex: "#000000"),
        rowBackground:     Color(hex: "#1C1C1E"),
        searchBackground:  Color(hex: "#1C1C1E"),
        pinnedBackground:  Color(hex: "#000000"),
        popoverBackground: Color(hex: "#2C2C2E"),
        separator:         Color(hex: "#38383A")
    )
}

// MARK: - Typography

public struct BubbleKitTypography {
    public var navigationTitle:   Font
    public var senderName:        Font
    public var messagePreview:    Font
    public var timestamp:         Font
    public var pinnedName:        Font
    public var badgeCount:        Font
    public var searchPlaceholder: Font
    public var popoverItem:       Font

    public static let `default` = BubbleKitTypography(
        navigationTitle:   .system(size: 17, weight: .semibold),
        senderName:        .system(size: 17, weight: .semibold),
        messagePreview:    .system(size: 15, weight: .regular),
        timestamp:         .system(size: 15, weight: .regular),
        pinnedName:        .system(size: 11, weight: .regular),
        badgeCount:        .system(size: 12, weight: .bold),
        searchPlaceholder: .system(size: 17, weight: .regular),
        popoverItem:       .system(size: 17, weight: .regular)
    )
}

// MARK: - Effects

public struct BubbleKitEffects {
    public var bubbleShadow: ShadowStyle
    public var avatarShadow: ShadowStyle

    public struct ShadowStyle {
        public var color:   Color
        public var radius:  CGFloat
        public var x:       CGFloat
        public var y:       CGFloat
    }

    public static let `default` = BubbleKitEffects(
        bubbleShadow: ShadowStyle(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 2),
        avatarShadow: ShadowStyle(color: Color.black.opacity(0.18), radius: 4, x: 0, y: 1)
    )
}

// MARK: - Layout Metrics

public struct BubbleKitLayout {
    public var avatarDiameter:       CGFloat
    public var pinnedAvatarDiameter: CGFloat
    public var rowHeight:            CGFloat
    public var pinnedRowHeight:      CGFloat
    public var horizontalPadding:    CGFloat
    public var avatarToTextSpacing:  CGFloat
    public var pinnedColumns:        Int
    public var storyRingWidth:       CGFloat
    public var badgeHeight:          CGFloat
    public var cornerRadius:         CGFloat

    public static let `default` = BubbleKitLayout(
        avatarDiameter:       56,   // increased from 50 to match Figma
        pinnedAvatarDiameter: 72,   // increased from 60 to match Figma
        rowHeight:            80,   // increased from 72 to match Figma
        pinnedRowHeight:      100,  // increased from 88 to match Figma
        horizontalPadding:    16,
        avatarToTextSpacing:  12,
        pinnedColumns:        9,
        storyRingWidth:       3,
        badgeHeight:          20,
        cornerRadius:         10
    )
}

// MARK: - Master Theme

public struct BubbleKitTheme {
    public var colors:     BubbleKitColors
    public var typography: BubbleKitTypography
    public var effects:    BubbleKitEffects
    public var layout:     BubbleKitLayout

    public static let `default` = BubbleKitTheme(
        colors:     .default,
        typography: .default,
        effects:    .default,
        layout:     .default
    )

    public static let dark = BubbleKitTheme(
        colors:     .dark,
        typography: .default,
        effects:    .default,
        layout:     .default
    )
}

// MARK: - Environment Key

private struct BubbleKitThemeKey: EnvironmentKey {
    static let defaultValue: BubbleKitTheme = .default
}

public extension EnvironmentValues {
    var bubbleKitTheme: BubbleKitTheme {
        get { self[BubbleKitThemeKey.self] }
        set { self[BubbleKitThemeKey.self] = newValue }
    }
}

public extension View {
    func bubbleKitTheme(_ theme: BubbleKitTheme) -> some View {
        environment(\.bubbleKitTheme, theme)
    }
}

// MARK: - Color hex init

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch h.count {
        case 3: (a,r,g,b) = (255,(int>>8)*17,(int>>4&0xF)*17,(int&0xF)*17)
        case 6: (a,r,g,b) = (255,int>>16,int>>8&0xFF,int&0xFF)
        case 8: (a,r,g,b) = (int>>24,int>>16&0xFF,int>>8&0xFF,int&0xFF)
        default:(a,r,g,b) = (255,0,0,0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}
