// BKConversationRowView.swift
// Single row in the conversation list.  Pixel-matches the Figma "Messages" screen.

import SwiftUI

public struct BKConversationRowView: View {

    let conversation: BKConversation
    @ObservedObject var viewModel: BKConversationListViewModel
    @Environment(\.bubbleKitTheme) private var theme

    public var body: some View {
        // UIDelegate override for entire row
        if let custom = viewModel.uiDelegate?.bubbleKit(rowViewFor: conversation) {
            custom
        } else {
            defaultRow
        }
    }

    private var defaultRow: some View {
        HStack(spacing: theme.layout.avatarToTextSpacing) {
            // ── Avatar ────────────────────────────────────────
            avatarStack

            // ── Text block ────────────────────────────────────
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(conversation.displayName)
                        .font(theme.typography.senderName)
                        .foregroundColor(theme.colors.appleBlack)
                        .lineLimit(1)

                    Spacer()

                    Text(formattedTime)
                        .font(theme.typography.timestamp)
                        .foregroundColor(theme.colors.appleGrey)
                }

                HStack(alignment: .top) {
                    Group {
                        if conversation.hasTypingIndicator {
                            typingDotsView
                        } else {
                            Text(conversation.lastMessage)
                                .font(theme.typography.messagePreview)
                                .foregroundColor(theme.colors.appleGrey)
                                .lineLimit(2)
                        }
                    }
                    Spacer()

                    // Unread indicator / badge
                    if conversation.unreadCount > 0 {
                        if let custom = viewModel.uiDelegate?.bubbleKit(badgeViewFor: conversation.unreadCount) {
                            custom
                        } else {
                            BKBadgeView(count: conversation.unreadCount)
                        }
                    } else if !conversation.isRead {
                        Circle()
                            .fill(theme.colors.messageSentNew)
                            .frame(width: 10, height: 10)
                    }
                }
            }
        }
        .padding(.horizontal, theme.layout.horizontalPadding)
        .frame(minHeight: theme.layout.rowHeight)
        .background(theme.colors.rowBackground)
    }

    // MARK: - Avatar

    @ViewBuilder
    private var avatarStack: some View {
        let size = theme.layout.avatarDiameter
        if let custom = viewModel.uiDelegate?.bubbleKit(
            avatarViewFor: conversation.participants[0], size: size) {
            custom
        } else if conversation.participants.count > 1 {
            // Group chat: stacked duo
            duoAvatar(size: size)
        } else {
            BKAvatarView(contact: conversation.participants[0], size: size)
        }
    }

    private func duoAvatar(size: CGFloat) -> some View {
        ZStack(alignment: .bottomTrailing) {
            BKAvatarView(contact: conversation.participants[0], size: size * 0.75)
                .alignmentGuide(.trailing) { _ in size }
            BKAvatarView(contact: conversation.participants[1], size: size * 0.75)
                .offset(x: size * 0.25, y: size * 0.25)
        }
        .frame(width: size, height: size)
    }

    // MARK: - Typing indicator (animated dots)

    private var typingDotsView: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(theme.colors.appleGrey)
                    .frame(width: 6, height: 6)
                    .opacity(0.4)
            }
        }
    }

    // MARK: - Time formatting

    private var formattedTime: String {
        let cal = Calendar.current
        let now = Date()
        if cal.isDateInToday(conversation.lastMessageTime) {
            let fmt = DateFormatter()
            fmt.timeStyle = .short
            fmt.dateStyle = .none
            return fmt.string(from: conversation.lastMessageTime)
        } else if cal.isDateInYesterday(conversation.lastMessageTime) {
            return "Yesterday"
        } else {
            let fmt = DateFormatter()
            fmt.dateFormat = "EEEE"  // "Tuesday"
            return fmt.string(from: conversation.lastMessageTime)
        }
    }
}
