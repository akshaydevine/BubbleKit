// BKContextPopoverView.swift
// Long-press popover: shows only Pin/Unpin and Delete.

import SwiftUI

struct BKContextPopoverView: View {

    let conversation: BKConversation
    @ObservedObject var viewModel: BKConversationListViewModel
    @Environment(\.bubbleKitTheme) private var theme

    var body: some View {
        let actions = viewModel.contextActions(for: conversation)

        if let custom = viewModel.uiDelegate?.bubbleKit(
            popoverViewFor: conversation, actions: actions) {
            custom
        } else {
            defaultPopover(actions: actions)
        }
    }

    private func defaultPopover(actions: [BKContextAction]) -> some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ────────────────────────────────────────
            HStack(spacing: 12) {
                BKAvatarView(contact: conversation.participants[0], size: 40)
                Text(conversation.displayName)
                    .font(theme.typography.senderName)
                    .foregroundColor(theme.colors.appleBlack)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()

            // ── Actions ───────────────────────────────────────
            ForEach(Array(actions.enumerated()), id: \.element.id) { idx, action in
                Button {
                    withAnimation(.spring(response: 0.2)) {
                        viewModel.didSelectContextAction(action, for: conversation)
                    }
                } label: {
                    HStack {
                        Text(action.title)
                            .font(theme.typography.popoverItem)
                            .foregroundColor(
                                action.role == .destructive ? .red : theme.colors.appleBlack
                            )
                        Spacer()
                        Image(systemName: action.icon)
                            .font(.system(size: 16))
                            .foregroundColor(
                                action.role == .destructive ? .red : theme.colors.appleGrey
                            )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if idx < actions.count - 1 {
                    Divider()
                }
            }
        }
        .background(theme.colors.popoverBackground)
        .clipShape(RoundedRectangle(cornerRadius: theme.layout.cornerRadius))
        .shadow(
            color: theme.effects.bubbleShadow.color,
            radius: theme.effects.bubbleShadow.radius,
            x: theme.effects.bubbleShadow.x,
            y: theme.effects.bubbleShadow.y
        )
    }
}
