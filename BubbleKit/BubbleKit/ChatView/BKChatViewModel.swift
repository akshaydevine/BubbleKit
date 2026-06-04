// BKChatViewModel.swift

import SwiftUI
import Combine

public final class BKChatViewModel: ObservableObject {

    // MARK: - Published

    @Published public var sections:             [BKMessageSection] = []
    @Published public var inputText:            String             = ""
    @Published public var scrollToID:           String?            = nil
    @Published public var highlightedMessageID: String?            = nil

    // Context menu
    @Published public var contextMessage:   BKMessage?         = nil

    // Reply
    @Published public var replyTarget:      BKMessageReply?    = nil

    // Fullscreen image gallery
    @Published public var fullscreenURL:    URL?               = nil
    @Published public var fullscreenImages: [URL]              = []
    @Published public var fullscreenIndex:  Int                = 0

    // Photo picker
    @Published public var showPhotoPicker:  Bool               = false

    // Voice recording
    @Published public var isRecording:      Bool               = false

    // Edit mode
    @Published public var editMode:         BKMessageEditMode  = .none

    // Thread reply
    @Published public var threadTarget:     BKMessageReply?    = nil

    // Pinned messages bar
    @Published public var pinnedMessages:   [BKMessage]        = []
    @Published public var showPinnedBar:    Bool               = false

    // MARK: - Info

    public var chatInfo: BKChatInfo

    // MARK: - Current User (SDK user passes their own logged-in user)
    /// The logged-in user sending messages. Set this before using the chat.
    public var currentUser: BKContact

    // MARK: - Delegate

    public weak var eventDelegate: (any BKChatEventDelegate)?

    // MARK: - Private

    private var allMessages: [BKMessage] = []

    // MARK: - Init

    /// - Parameters:
    ///   - chatInfo: Title, subtitle, avatar for the chat/conversation.
    ///   - currentUser: The logged-in user (YOUR user). Used as sender for outgoing messages.
    ///   - messages: Initial messages to display (from your API/DB).
    public init(
        chatInfo:    BKChatInfo,
        currentUser: BKContact,
        messages:    [BKMessage] = []
    ) {
        self.chatInfo    = chatInfo
        self.currentUser = currentUser
        self.allMessages = messages
        self.sections    = Self.group(messages)
    }

    // Token incremented each call — cancels any in-flight highlight from a previous tap
    private var highlightToken: Int = 0

    public func scrollToAndHighlight(messageID: String) {
        // ── Fix 1: always reset to nil first so onChange fires even for the same ID ──
        highlightedMessageID = nil
        scrollToID = nil

        highlightToken += 1
        let token = highlightToken

        // Small tick so the nil publish above is committed before we set the new ID
        DispatchQueue.main.async {
            // ── Fix 2: set scrollToID after nil tick so onChange always fires ─────
            self.scrollToID = messageID

            // ── Fix 3: longer delay so scroll animation finishes first ────────────
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                guard self.highlightToken == token else { return }   // stale tap — ignore
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.highlightedMessageID = messageID
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                    guard self.highlightToken == token else { return }
                    withAnimation(.easeOut(duration: 0.4)) {
                        self.highlightedMessageID = nil
                    }
                }
            }
        }
    }

    // MARK: - Load

    public func load(messages: [BKMessage]) {
        allMessages = messages
        sections    = Self.group(messages)
        scrollToBottom()
    }

    // MARK: - Send

    public func appendMessage(_ message: BKMessage) {
        append(message)
        eventDelegate?.bkChat(didSend: message)
    }

    public func sendMessage() {
        if case .editing = editMode {
            commitEdit()
            return
        }

        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let msg = BKMessage(
            sender:      currentUser,   // ✅ uses SDK user's contact
            text:        trimmed,
            sentAt:      Date(),
            isOutgoing:  true,
            readReceipt: .sent,
            replyTo:     replyTarget ?? threadTarget
        )
        append(msg)
        inputText    = ""
        replyTarget  = nil
        threadTarget = nil
        eventDelegate?.bkChat(didSend: msg)
    }

    // MARK: - Context menu actions

    public func showContext(for message: BKMessage) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        contextMessage = message
    }

    public func dismissContext() {
        contextMessage = nil
    }

    public func react(emoji: String, to message: BKMessage) {
        contextMessage = nil
        updateMessage(id: message.id) { msg in
            if let idx = msg.reactions.firstIndex(where: { $0.emoji == emoji }) {
                if msg.reactions[idx].byMe {
                    msg.reactions[idx].count = max(0, msg.reactions[idx].count - 1)
                    if msg.reactions[idx].count == 0 { msg.reactions.remove(at: idx) }
                } else {
                    msg.reactions[idx].count += 1
                    msg.reactions[idx].byMe = true
                }
            } else {
                msg.reactions.append(BKReaction(emoji: emoji, count: 1, byMe: true))
            }
        }
    }

    public func reply(to message: BKMessage) {
        contextMessage = nil
        replyTarget    = BKMessageReply(message: message)
    }

    public func cancelReply() {
        replyTarget = nil
    }

    public func copyText(_ message: BKMessage) {
        contextMessage = nil
        UIPasteboard.general.string = message.text ?? ""
    }

    public func deleteMessage(_ message: BKMessage) {
        contextMessage = nil
        updateMessage(id: message.id) { $0.isDeleted = true }
    }

    public func toggleTranslation(for message: BKMessage) {
        updateMessage(id: message.id) { $0.isTranslated.toggle() }
    }

    // MARK: - Edit Message

    public func startEdit(message: BKMessage) {
        contextMessage = nil
        guard let text = message.text, !text.isEmpty else { return }
        editMode   = .editing(message)
        inputText  = text
    }

    public func commitEdit() {
        guard case .editing(let original) = editMode else { return }
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { cancelEdit(); return }
        updateMessage(id: original.id) { $0.text = trimmed }
        inputText = ""
        editMode  = .none
    }

    public func cancelEdit() {
        inputText = ""
        editMode  = .none
    }

    // MARK: - Thread Reply

    public func threadReply(to message: BKMessage) {
        contextMessage = nil
        threadTarget   = BKMessageReply(message: message)
        updateMessage(id: message.id) { $0.threadReplyCount += 1 }
    }

    public func cancelThreadReply() {
        threadTarget = nil
    }

    // MARK: - Pin / Unpin Message

    public func togglePin(message: BKMessage) {
        contextMessage = nil
        let nowPinned = !message.isPinned
        updateMessage(id: message.id) { $0.isPinned = nowPinned }
        pinnedMessages = allMessages.filter { $0.isPinned }
        showPinnedBar  = !pinnedMessages.isEmpty
    }

    public func dismissPinnedBar() {
        showPinnedBar = false
    }

    // MARK: - Image viewer

    public func openImage(_ url: URL) {
        openImages([url], startIndex: 0)
    }

    public func openImages(_ urls: [URL], startIndex: Int = 0) {
        contextMessage   = nil
        fullscreenImages = urls
        fullscreenIndex  = startIndex
        fullscreenURL    = urls.first
    }

    // MARK: - Helpers

    private func append(_ message: BKMessage) {
        allMessages.append(message)
        sections = Self.group(allMessages)
        scrollToBottom()
    }

    private func updateMessage(id: String, mutation: (inout BKMessage) -> Void) {
        if let idx = allMessages.firstIndex(where: { $0.id == id }) {
            mutation(&allMessages[idx])
            sections = Self.group(allMessages)
        }
    }

    private func scrollToBottom() {
        DispatchQueue.main.async { self.scrollToID = self.allMessages.last?.id }
    }

    // MARK: - Date grouping

    static func group(_ messages: [BKMessage]) -> [BKMessageSection] {
        let cal = Calendar.current
        var dict:   [(key: Date, value: [BKMessage])] = []
        var dayMap: [Date: Int] = [:]
        for msg in messages {
            let day = cal.startOfDay(for: msg.sentAt)
            if let i = dayMap[day] { dict[i].value.append(msg) }
            else { dayMap[day] = dict.count; dict.append((day, [msg])) }
        }
        return dict.map { BKMessageSection(id: $0.key.ISO8601Format(), date: $0.key, messages: $0.value) }
    }

    // MARK: - Formatting

    public static func formattedTime(_ date: Date) -> String {
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none
        return f.string(from: date)
    }

    public static func formattedSectionDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}

// MARK: - Chat Event Delegate

public protocol BKChatEventDelegate: AnyObject {
    func bkChat(didSend message: BKMessage)
    func bkChat(didTapAttachment attachment: BKAttachment, in message: BKMessage)
    func bkChat(didLongPress message: BKMessage)
}

public extension BKChatEventDelegate {
    func bkChat(didSend message: BKMessage) {}
    func bkChat(didTapAttachment attachment: BKAttachment, in message: BKMessage) {}
    func bkChat(didLongPress message: BKMessage) {}
}
