// ContentView.swift
// Updated integration example — handles all new events.

import SwiftUI
import Combine

final class DelegateHolder: ObservableObject {
    let delegate: MyAppDelegate
    init() { self.delegate = MyAppDelegate() }
}

final class MyAppDelegate: BKFullDelegate {

    private var allConversations: [BKConversation] = BKSampleData.conversations
    private var pins:             [BKPinnedEntry]  = BKSampleData.pinnedEntries

    // ── BKDataSource ──────────────────────────────────────────────────────

    func conversations(for filter: BKConversationFilter) -> [BKConversation] {
        switch filter {
        case .all:    return allConversations
        case .unread: return allConversations.filter { !$0.isRead || $0.unreadCount > 0 }
        case .groups: return allConversations.filter { $0.participants.count > 1 }
        }
    }
    func pinnedEntries() -> [BKPinnedEntry]? { pins }

    /// Host can add extra actions after the SDK-prepended pin action.
    func contextActions(for conversation: BKConversation) -> [BKContextAction] {
        var actions = BKContextAction.defaults   // Select Messages + Edit Pins
        actions.append(BKContextAction(title: "Mute", icon: "bell.slash"))
        return actions
    }

    /// Optional — return nil to use SDK default (Select Messages + Edit Pins).
    func editMenuActions() -> [BKEditAction]? { nil }

    // ── BKEventDelegate ───────────────────────────────────────────────────

    func bubbleKit(didHandle event: BKConversationEvent) {
        switch event.kind {
        case .tap:         print("Opened: \(event.conversation.displayName)")
        case .swipeDelete: allConversations.removeAll { $0.id == event.conversation.id }
        case .swipePin:    togglePin(event.conversation)
        case .contextAction(let a): handleContextAction(a, for: event.conversation)
        default: break
        }
    }

    func bubbleKit(didHandle event: BKPinnedEvent) {
        switch event.kind {
        case .add:
            // SDK already updated the ViewModel; sync local array so future
            // calls to pinnedEntries() reflect the new state.
            if !pins.contains(where: { $0.contact.id == event.entry.contact.id }) {
                pins.append(event.entry)
            }
            print("Pinned: \(event.entry.contact.name)")
        case .remove:
            pins.removeAll { $0.id == event.entry.id }
            print("Unpinned: \(event.entry.contact.name)")
        case .reorder(let from, let to):
            guard pins.indices.contains(from), pins.indices.contains(to) else { return }
            let moved = pins.remove(at: from)
            pins.insert(moved, at: to)
        default: break
        }
    }

    func bubbleKitDidTapEdit(isOpen: Bool) {
        print("Edit menu \(isOpen ? "opened" : "closed")")
    }

    func bubbleKit(didSelectEditAction action: BKEditAction) {
        switch action.id {
        case BKEditAction.selectMessagesID:
            print("Enter select-messages mode")
            // → put your UI into multi-select mode here
        case BKEditAction.editPinsID:
            print("Open pin-editing screen")
            // → push a pin-management view here
        default:
            print("Edit action: \(action.title)")
        }
    }

    func bubbleKit(destinationFor conversation: BKConversation) -> AnyView? {
        AnyView(ChatDetailView(conversation: conversation))
    }
    func bubbleKitDidTapCompose() { print("Compose tapped") }

    // ── BKUIDelegate ──────────────────────────────────────────────────────

    func bubbleKit(badgeViewFor unreadCount: Int) -> AnyView? {
        guard unreadCount > 0 else { return nil }
        return AnyView(
            ZStack {
                Circle().fill(Color.purple).frame(width: 20, height: 20)
                Text(unreadCount > 9 ? "9+" : "\(unreadCount)")
                    .font(.system(size: 11, weight: .bold)).foregroundColor(.white)
            }
        )
    }
    func bubbleKit(rowViewFor conversation: BKConversation) -> AnyView?               { nil }
    func bubbleKit(avatarViewFor contact: BKContact, size: CGFloat) -> AnyView?        { nil }
    func bubbleKitPinnedRowView(entries: [BKPinnedEntry]) -> AnyView?                  { nil }
    func bubbleKit(pinnedCellViewFor entry: BKPinnedEntry) -> AnyView?                 { nil }
    func bubbleKit(popoverViewFor conversation: BKConversation,
                   actions: [BKContextAction]) -> AnyView?                             { nil }
    func bubbleKitEmptyStateView(for filter: BKConversationFilter) -> AnyView?         { nil }
    func bubbleKitEmptySearchView(query: String) -> AnyView?                           { nil }
    func bubbleKitLeadingBarItems() -> AnyView?                                        { nil }
    func bubbleKitTrailingBarItems() -> AnyView?                                       { nil }
    func bubbleKitSearchBarView(query: Binding<String>) -> AnyView?                    { nil }

    // ── Helpers ───────────────────────────────────────────────────────────

    private func togglePin(_ conv: BKConversation) {
        if let idx = pins.firstIndex(where: { $0.contact.id == conv.participants.first?.id }) {
            pins.remove(at: idx)
        } else if pins.count < 9, let contact = conv.participants.first {
            pins.append(BKPinnedEntry(contact: contact))
        }
    }

    private func handleContextAction(_ action: BKContextAction, for conversation: BKConversation) {
        switch action.title {
        case "Edit Pins": print("Open pin editor")
        case "Mute":      print("Mute \(conversation.displayName)")
        default:          break
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: ContentView
// ─────────────────────────────────────────────────────────────────────────────

struct ContentView: View {
    @StateObject private var holder = DelegateHolder()
    @State private var useGridLayout = false

    var body: some View {
        BubbleKit.makeConversationList(
            pinnedDisplayMode: useGridLayout ? .grid : .horizontalScroll,
            delegate: holder.delegate
        )
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: Chat detail screen
// ─────────────────────────────────────────────────────────────────────────────

struct ChatDetailView: View {
    let conversation: BKConversation
    var body: some View {
        VStack {
            Spacer()
            Text("Chat with \(conversation.displayName)")
                .font(.title2).foregroundColor(.secondary)
            Spacer()
        }
        .navigationTitle(conversation.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: Previews
// ─────────────────────────────────────────────────────────────────────────────

#Preview("Horizontal Scroll") { BubbleKit.preview }
#Preview("Grid Layout")        { BubbleKit.previewGrid }
#Preview("Dark")               { BubbleKit.makeConversationList(theme: .dark, delegate: DefaultBubbleKitDelegate()) }
