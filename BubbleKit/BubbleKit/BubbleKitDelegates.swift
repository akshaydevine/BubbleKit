// BubbleKitDelegates.swift
//
// Additions vs previous:
//   • BKDataSource.editMenuActions()    — optional override for Edit button items.
//   • BKEventDelegate.bubbleKitDidTapEdit(isOpen:)  — fired when Edit is tapped.
//   • BKEventDelegate.bubbleKit(didSelectEditAction:) — fired when a menu item is chosen.

import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: 1. Data Source
// ─────────────────────────────────────────────────────────────────────────────

public protocol BKDataSource: AnyObject {
    func conversations(for filter: BKConversationFilter) -> [BKConversation]
    func conversations(matching query: String) -> [BKConversation]?
    func pinnedEntries() -> [BKPinnedEntry]?
    func contextActions(for conversation: BKConversation) -> [BKContextAction]
    /// Items shown in the Edit button dropdown. Return nil to use SDK defaults.
    func editMenuActions() -> [BKEditAction]?
}

public extension BKDataSource {
    func conversations(matching query: String) -> [BKConversation]? { nil }
    func contextActions(for conversation: BKConversation) -> [BKContextAction] { BKContextAction.defaults }
    func editMenuActions() -> [BKEditAction]? { nil }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: 2. Event Delegate
// ─────────────────────────────────────────────────────────────────────────────

public protocol BKEventDelegate: AnyObject {
    func bubbleKit(didHandle event: BKConversationEvent)
    func bubbleKit(didHandle event: BKPinnedEvent)
    func bubbleKit(didChangeSearchQuery query: String)
    func bubbleKit(didBeginSearch: Bool)
    func bubbleKit(didCancelSearch: Bool)
    func bubbleKit(destinationFor conversation: BKConversation) -> AnyView?
    func bubbleKitDidTapCompose()
    func bubbleKit(didChangeFilter filter: BKConversationFilter)
    /// Fired when the "Edit" navigation-bar button is tapped.
    func bubbleKitDidTapEdit(isOpen: Bool)
    /// Fired when the user selects an item from the Edit dropdown.
    func bubbleKit(didSelectEditAction action: BKEditAction)
}

public extension BKEventDelegate {
    func bubbleKit(didHandle event: BKConversationEvent) {}
    func bubbleKit(didHandle event: BKPinnedEvent) {}
    func bubbleKit(didChangeSearchQuery query: String) {}
    func bubbleKit(didBeginSearch: Bool) {}
    func bubbleKit(didCancelSearch: Bool) {}
    func bubbleKit(destinationFor conversation: BKConversation) -> AnyView? { nil }
    func bubbleKitDidTapCompose() {}
    func bubbleKit(didChangeFilter filter: BKConversationFilter) {}
    func bubbleKitDidTapEdit(isOpen: Bool) {}
    func bubbleKit(didSelectEditAction action: BKEditAction) {}
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: 3. UI Delegate
// ─────────────────────────────────────────────────────────────────────────────

public protocol BKUIDelegate: AnyObject {
    func bubbleKit(rowViewFor conversation: BKConversation) -> AnyView?
    func bubbleKit(avatarViewFor contact: BKContact, size: CGFloat) -> AnyView?
    func bubbleKit(badgeViewFor unreadCount: Int) -> AnyView?
    func bubbleKitPinnedRowView(entries: [BKPinnedEntry]) -> AnyView?
    func bubbleKit(pinnedCellViewFor entry: BKPinnedEntry) -> AnyView?
    func bubbleKit(popoverViewFor conversation: BKConversation,
                   actions: [BKContextAction]) -> AnyView?
    func bubbleKitEmptyStateView(for filter: BKConversationFilter) -> AnyView?
    func bubbleKitEmptySearchView(query: String) -> AnyView?
    func bubbleKitLeadingBarItems() -> AnyView?
    func bubbleKitTrailingBarItems() -> AnyView?
    func bubbleKitSearchBarView(query: Binding<String>) -> AnyView?
}

public extension BKUIDelegate {
    func bubbleKit(rowViewFor conversation: BKConversation) -> AnyView?                { nil }
    func bubbleKit(avatarViewFor contact: BKContact, size: CGFloat) -> AnyView?         { nil }
    func bubbleKit(badgeViewFor unreadCount: Int) -> AnyView?                           { nil }
    func bubbleKitPinnedRowView(entries: [BKPinnedEntry]) -> AnyView?                   { nil }
    func bubbleKit(pinnedCellViewFor entry: BKPinnedEntry) -> AnyView?                  { nil }
    func bubbleKit(popoverViewFor conversation: BKConversation,
                   actions: [BKContextAction]) -> AnyView?                              { nil }
    func bubbleKitEmptyStateView(for filter: BKConversationFilter) -> AnyView?          { nil }
    func bubbleKitEmptySearchView(query: String) -> AnyView?                            { nil }
    func bubbleKitLeadingBarItems() -> AnyView?                                         { nil }
    func bubbleKitTrailingBarItems() -> AnyView?                                        { nil }
    func bubbleKitSearchBarView(query: Binding<String>) -> AnyView?                     { nil }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: 4. Combined Delegate
// ─────────────────────────────────────────────────────────────────────────────

public typealias BKFullDelegate = BKDataSource & BKEventDelegate & BKUIDelegate

// ─────────────────────────────────────────────────────────────────────────────
// MARK: 5. Default implementation
// ─────────────────────────────────────────────────────────────────────────────

public final class DefaultBubbleKitDelegate: BKFullDelegate {

    public init() {}

    public func conversations(for filter: BKConversationFilter) -> [BKConversation] {
        BKSampleData.conversations
    }
    public func pinnedEntries() -> [BKPinnedEntry]? {
        BKSampleData.pinnedEntries
    }
    public func bubbleKit(didHandle event: BKConversationEvent) {
        print("[BubbleKit] conversation event → \(event.conversation.displayName)")
    }
    public func bubbleKit(didHandle event: BKPinnedEvent) {
        switch event.kind {
        case .add:    print("[BubbleKit] pinned.add    → \(event.entry.contact.name)")
        case .remove: print("[BubbleKit] pinned.remove → \(event.entry.contact.name)")
        default:      print("[BubbleKit] pinned event  → \(event.entry.contact.name)")
        }
    }
    public func bubbleKitDidTapEdit(isOpen: Bool) {
        print("[BubbleKit] Edit menu \(isOpen ? "opened" : "closed")")
    }
    public func bubbleKit(didSelectEditAction action: BKEditAction) {
        print("[BubbleKit] Edit action: \(action.title)")
    }
}
