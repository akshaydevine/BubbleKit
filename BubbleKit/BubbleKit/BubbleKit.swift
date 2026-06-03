// BubbleKit.swift
// Public API surface.  Import BubbleKit to get everything.
//
// Changes vs original:
//   • `makeConversationList` now accepts `pinnedDisplayMode` parameter.
//   • `preview` defaults to .horizontalScroll (unchanged behaviour).

@_exported import SwiftUI

public typealias BubbleKitConversationListView = BKConversationListView
public typealias BubbleKitConversation         = BKConversation
public typealias BubbleKitContact              = BKContact
public typealias BubbleKitAvatar               = BKAvatar
public typealias BubbleKitPinnedEntry          = BKPinnedEntry
public typealias BubbleKitContextAction        = BKContextAction

public enum BubbleKit {

    /// Create a ready-to-present conversation list view.
    /// - Parameters:
    ///   - title:             Navigation bar title (default "Messages")
    ///   - theme:             Visual theme (default matches Figma spec)
    ///   - pinnedDisplayMode: `.horizontalScroll` (original) or `.grid` (3-col × 3-row)
    ///   - delegate:          Single object conforming to `BKFullDelegate`
    public static func makeConversationList<D: BKFullDelegate>(
        title:             String              = "Messages",
        theme:             BubbleKitTheme      = .default,
        pinnedDisplayMode: BKPinnedDisplayMode = .horizontalScroll,
        delegate:          D,
        onChatNavigationChanged: ((Bool) -> Void)? = nil  // ✅ new
    ) -> some View {
        BKConversationListView(
            title:                   title,
            theme:                   theme,
            dataSource:              delegate,
            eventDelegate:           delegate,
            uiDelegate:              delegate,
            pinnedDisplayMode:       pinnedDisplayMode,
            onChatNavigationChanged: onChatNavigationChanged  // ✅ pass through
        )
    }

    /// Zero-config preview using built-in sample data (horizontal scroll layout).
    public static var preview: some View {
        BKConversationListView(
            title:      "Messages",
            dataSource: DefaultBubbleKitDelegate()
        )
    }

    /// Zero-config preview using the grid layout.
    public static var previewGrid: some View {
        BKConversationListView(
            title:             "Messages",
            dataSource:        DefaultBubbleKitDelegate(),
            pinnedDisplayMode: .grid
        )
    }
}
