// ContentView.swift
// Per-user static chat data — each conversation shows its own unique messages.

import SwiftUI
import Combine

final class DelegateHolder: ObservableObject {
    let delegate: MyAppDelegate
    init() { self.delegate = MyAppDelegate() }
}

// MARK: - Per-User Static Message Bank
// Add / edit messages here. Key = BKConversation.id (matches BKSampleData record ids).

private enum StaticMessages {

    static func messages(for conversationID: String, contact: BKContact, currentUser: BKContact) -> [BKMessage] {
        let bank = allMessages(contact: contact, currentUser: currentUser)
        return bank[conversationID] ?? defaultMessages(contact: contact, currentUser: currentUser)
    }

    // ── Unique messages per user ─────────────────────────────────────────

    private static func allMessages(contact: BKContact, currentUser: BKContact) -> [String: [BKMessage]] {
        [

            // Hell Boy
            "hellboy": [
                msg(id: "hb1", sender: contact,      text: "yo what's good 🤘",                   daysAgo: 3),
                msg(id: "hb2", sender: currentUser,  text: "not much bro, you?",                  daysAgo: 3),
                msg(id: "hb3", sender: contact,      text: "bro I need a bassist for Saturday",   daysAgo: 2),
                msg(id: "hb4", sender: currentUser,  text: "I might be free, what time?",         daysAgo: 2),
                msg(id: "hb5", sender: contact,      text: "like 7pm at the usual spot",          daysAgo: 1),
                msg(id: "hb6", sender: currentUser,  text: "yeah I'm in 🔥",                      daysAgo: 1),
                msg(id: "hb7", sender: contact,      text: "Hi. I gotta rehearse at 2 today",     hoursAgo: 1),
            ],

            // Kevin Rosal
            "kevin": [
                msg(id: "kv1", sender: contact,      text: "bro you still have that nintendo switch?", daysAgo: 5),
                msg(id: "kv2", sender: currentUser,  text: "nah I sold it ages ago lol",              daysAgo: 5),
                msg(id: "kv3", sender: contact,      text: "ok ok, cause I found a buyer for mine",   daysAgo: 4),
                msg(id: "kv4", sender: currentUser,  text: "how much they offering?",                 daysAgo: 4),
                msg(id: "kv5", sender: contact,      text: "dude $1500 💀",                           daysAgo: 3),
                msg(id: "kv6", sender: currentUser,  text: "WHAT no way lmaooo sell it immediately",  daysAgo: 3),
                msg(id: "kv7", sender: contact,      text: "I just sold my nintendo switch for $1500", hoursAgo: 1, reactions: [BKReaction(emoji: "😂", count: 2, byMe: true)]),
            ],

            // Eumin Lee
            "eumin": [
                msg(id: "eu1", sender: currentUser,  text: "you working from the library today?",     daysAgo: 2),
                msg(id: "eu2", sender: contact,      text: "nah it's packed in there",                daysAgo: 2),
                msg(id: "eu3", sender: currentUser,  text: "coffee shop then?",                       daysAgo: 2),
                msg(id: "eu4", sender: contact,      text: "lol no wifi there either",                daysAgo: 1),
                msg(id: "eu5", sender: currentUser,  text: "where are you working from??",            hoursAgo: 3),
                msg(id: "eu6", sender: contact,      text: "I'm using burger kings wifi 😅",          hoursAgo: 1),
                msg(id: "eu7", sender: currentUser,  text: "bro 💀 at least get the whopper",         minutesAgo: 20),
            ],

            // Jessica Walsh
            "jessica": [
                msg(id: "jw1", sender: contact,      text: "did you catch the KCRW stream last night?", daysAgo: 3),
                msg(id: "jw2", sender: currentUser,  text: "missed it unfortunately 😭",               daysAgo: 3),
                msg(id: "jw3", sender: contact,      text: "it was SO good, Floating Points went off",  daysAgo: 3),
                msg(id: "jw4", sender: currentUser,  text: "ok I'll catch the replay for sure",         daysAgo: 2),
                msg(id: "jw5", sender: contact,      text: "Cut chemist is doing an hour DJ set tomorrow nite on kcrw", daysAgo: 1),
                msg(id: "jw6", sender: currentUser,  text: "no way!! setting a reminder rn",            daysAgo: 1),
                msg(id: "jw7", sender: contact,      text: "it starts at 10pm, don't miss it 🎧",      hoursAgo: 2),
            ],

            // Greg Adams
            "greg": [
                msg(id: "gr1", sender: contact,      text: "hey are you free this weekend?",           daysAgo: 4),
                msg(id: "gr2", sender: currentUser,  text: "Saturday or Sunday?",                      daysAgo: 4),
                msg(id: "gr3", sender: contact,      text: "Saturday night, we're doing dinner",       daysAgo: 4),
                msg(id: "gr4", sender: currentUser,  text: "I should be good, what time?",             daysAgo: 3),
                msg(id: "gr5", sender: contact,      text: "like 8:30ish, Casa Vega",                  daysAgo: 3),
                msg(id: "gr6", sender: currentUser,  text: "perfect, I'll be there!",                  daysAgo: 2),
                msg(id: "gr7", sender: contact,      text: "Can you pick me up around 8?",             daysAgo: 2, readReceipt: .delivered),
            ],

            // Keith Alva
            "keithalva": [
                msg(id: "ka1", sender: currentUser,  text: "bro when is the new track dropping??",    daysAgo: 3),
                msg(id: "ka2", sender: contact,      text: "been in the studio all week for this 🔥", daysAgo: 3),
                msg(id: "ka3", sender: currentUser,  text: "I can't wait man the snippets sounded 🔥", daysAgo: 2),
                msg(id: "ka4", sender: contact,      text: "mastering it tonight hopefully",           daysAgo: 1),
                msg(id: "ka5", sender: currentUser,  text: "let me know when it's live!!",             daysAgo: 1),
                msg(id: "ka6", sender: contact,      text: "Just dropped the new track, lmk what you think", hoursAgo: 2, readReceipt: .delivered),
            ],
        ]
    }

    // ── Fallback for pinned-only contacts (no conversation row) ──────────

    private static func defaultMessages(contact: BKContact, currentUser: BKContact) -> [BKMessage] {
        [
            msg(id: "\(contact.id)_d1", sender: currentUser, text: "Hey! 👋",                      daysAgo: 2),
            msg(id: "\(contact.id)_d2", sender: contact,     text: "Hey, what's up?",               daysAgo: 2),
            msg(id: "\(contact.id)_d3", sender: currentUser, text: "Not much, just checking in 😊", hoursAgo: 3),
            msg(id: "\(contact.id)_d4", sender: contact,     text: "Same here! Talk soon 🙌",       hoursAgo: 1),
        ]
    }

    // ── Builder helpers ──────────────────────────────────────────────────

    private static func msg(
        id:           String,
        sender:       BKContact,
        text:         String,
        daysAgo:      Double   = 0,
        hoursAgo:     Double   = 0,
        minutesAgo:   Double   = 0,
        readReceipt:  BKReadReceipt = .read,
        reactions:    [BKReaction]  = [],
        attachment:   BKAttachment? = nil
    ) -> BKMessage {
        let offset = -(daysAgo * 86400 + hoursAgo * 3600 + minutesAgo * 60)
        let isOutgoing = sender.id == "me"
        return BKMessage(
            id:           id,
            sender:       sender,
            text:         text,
            attachments:  attachment.map { [$0] } ?? [],
            sentAt:       Date().addingTimeInterval(offset),
            isOutgoing:   isOutgoing,
            readReceipt:  readReceipt,
            reactions:    reactions
        )
    }
}

// MARK: - App Delegate

final class MyAppDelegate: BKFullDelegate {

    private var allConversations: [BKConversation] = BKSampleData.conversations
    private var pins:             [BKPinnedEntry]  = BKSampleData.pinnedEntries

    // The logged-in user — replace with your real auth user
    private let currentUser = BKChatSampleData.me

    // Per-conversation ViewModel cache — keeps message history alive on back/reopen
    private var chatViewModels: [String: BKChatViewModel] = [:]

    // MARK: - BKDataSource

    func conversations(for filter: BKConversationFilter) -> [BKConversation] {
        switch filter {
        case .all:    return allConversations
        case .unread: return allConversations.filter { !$0.isRead || $0.unreadCount > 0 }
        case .groups: return allConversations.filter { $0.participants.count > 1 }
        }
    }

    func pinnedEntries() -> [BKPinnedEntry]? { pins }

    func contextActions(for conversation: BKConversation) -> [BKContextAction] {
        var actions = BKContextAction.defaults
        actions.append(BKContextAction(title: "Mute", icon: "bell.slash"))
        return actions
    }

    func editMenuActions() -> [BKEditAction]? { nil }

    // MARK: - BKEventDelegate

    func bubbleKit(didHandle event: BKConversationEvent) {
        switch event.kind {
        case .tap:
            print("Opened: \(event.conversation.displayName)")
        case .swipeDelete:
            allConversations.removeAll { $0.id == event.conversation.id }
            chatViewModels.removeValue(forKey: event.conversation.id)
        case .swipePin:
            togglePin(event.conversation)
        case .contextAction(let a):
            handleContextAction(a, for: event.conversation)
        default: break
        }
    }

    func bubbleKit(didHandle event: BKPinnedEvent) {
        switch event.kind {
        case .add:
            if !pins.contains(where: { $0.contact.id == event.entry.contact.id }) {
                pins.append(event.entry)
            }
        case .remove:
            pins.removeAll { $0.id == event.entry.id }
        case .reorder(let from, let to):
            guard pins.indices.contains(from), pins.indices.contains(to) else { return }
            let moved = pins.remove(at: from)
            pins.insert(moved, at: to)
        default: break
        }
    }

    func bubbleKitDidTapEdit(isOpen: Bool) {}
    func bubbleKit(didSelectEditAction action: BKEditAction) {}

    // MARK: - Per-conversation destination
    // Returns a CACHED ViewModel for each conversation so message history
    // is preserved when the user navigates back and reopens the chat.

    func bubbleKit(destinationFor conversation: BKConversation) -> AnyView? {

        // Return cached VM — preserves typed / sent messages on re-open
        if let existing = chatViewModels[conversation.id] {
            return AnyView(BKChatView(viewModel: existing))
        }

        let contact = conversation.participants.first ?? BKChatSampleData.leia

        // ✅ Load unique static messages for THIS user
        let messages = StaticMessages.messages(
            for:         conversation.id,
            contact:     contact,
            currentUser: currentUser
        )

        let chatVM = BKChatViewModel(
            chatInfo: BKChatInfo(
                title:    conversation.displayName,
                subtitle: conversation.participants.count > 1
                              ? "\(conversation.participants.count) members"
                              : nil,
                avatar:   conversation.participants.first?.avatar ?? .placeholder,
                isGroup:  conversation.participants.count > 1
            ),
            currentUser: currentUser,
            messages:    messages
        )

        // Update conversation list row when user sends a new message
        chatVM.eventDelegate = SentMessageHandler(
            conversationID: conversation.id,
            onNewMessage: { [weak self] msg in
                self?.updateLastMessage(msg, for: conversation.id)
            }
        )

        chatViewModels[conversation.id] = chatVM
        return AnyView(BKChatView(viewModel: chatVM))
    }

    func bubbleKitDidTapCompose() {}

    // MARK: - BKUIDelegate

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

    // MARK: - Private Helpers

    private func updateLastMessage(_ message: BKMessage, for conversationID: String) {
        guard let idx = allConversations.firstIndex(where: { $0.id == conversationID }) else { return }
        allConversations[idx].lastMessage     = message.text ?? "Attachment"
        allConversations[idx].lastMessageTime = message.sentAt
        allConversations[idx].isRead          = true
    }

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

// MARK: - SentMessageHandler

final class SentMessageHandler: BKChatEventDelegate {
    private let conversationID: String
    private let onNewMessage:   (BKMessage) -> Void

    init(conversationID: String, onNewMessage: @escaping (BKMessage) -> Void) {
        self.conversationID = conversationID
        self.onNewMessage   = onNewMessage
    }

    func bkChat(didSend message: BKMessage) {
        onNewMessage(message)
    }
}

// MARK: - ContentView

struct ContentView: View {
    @StateObject private var holder = DelegateHolder()
    @State private var useGridLayout = true

    var body: some View {
        BubbleKit.makeConversationList(
            pinnedDisplayMode: useGridLayout ? .grid : .horizontalScroll,
            delegate: holder.delegate
        )
    }
}

// MARK: - Previews

#Preview("Horizontal Scroll") { BubbleKit.preview }
#Preview("Grid Layout")        { BubbleKit.previewGrid }
#Preview("Dark")               { BubbleKit.makeConversationList(theme: .dark, delegate: DefaultBubbleKitDelegate()) }
