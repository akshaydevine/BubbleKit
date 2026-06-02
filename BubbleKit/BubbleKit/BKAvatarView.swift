// BKAvatarView.swift

import SwiftUI

public struct BKAvatarView: View {
    let contact:  BKContact
    let size:     CGFloat
    let showRing: Bool         // purple story ring if has unread
    let ringColor: Color

    @Environment(\.bubbleKitTheme) private var theme

    public init(
        contact:   BKContact,
        size:      CGFloat,
        showRing:  Bool  = false,
        ringColor: Color = .pink
    ) {
        self.contact   = contact
        self.size      = size
        self.showRing  = showRing
        self.ringColor = ringColor
    }

    public var body: some View {
        avatarContent
            .frame(width: size, height: size)
            .clipShape(Circle())
            .shadow(
                color: theme.effects.avatarShadow.color,
                radius: theme.effects.avatarShadow.radius,
                x: theme.effects.avatarShadow.x,
                y: theme.effects.avatarShadow.y
            )
            .overlay(
                Circle()
                    .stroke(ringColor, lineWidth: showRing ? theme.layout.storyRingWidth : 0)
                    .padding(-theme.layout.storyRingWidth - 1)
                    .opacity(showRing ? 1 : 0)
            )
    }

    @ViewBuilder
    private var avatarContent: some View {
        switch contact.avatar {
        case .url(let url):
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                initialsView(contact.name, fg: .white, bg: theme.colors.appleGrey)
            }

        case .image(let name):
            Image(name)
                .resizable()
                .scaledToFill()

        case .systemSymbol(let sym):
            Image(systemName: sym)
                .resizable()
                .scaledToFit()
                .padding(size * 0.2)
                .foregroundColor(theme.colors.appleGrey)
                .background(theme.colors.lightGrey)

        case .initials(let text, let fg, let bg):
            initialsView(text, fg: fg, bg: bg)

        case .placeholder:
            Circle()
                .fill(theme.colors.lightGrey)
                .overlay(
                    Image(systemName: "person.fill")
                        .resizable().scaledToFit()
                        .padding(size * 0.22)
                        .foregroundColor(theme.colors.appleGrey)
                )
        }
    }

    private func initialsView(_ text: String, fg: Color, bg: Color) -> some View {
        ZStack {
            Circle().fill(bg)
            Text(initials(from: text))
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundColor(fg)
        }
    }

    private func initials(from name: String) -> String {
        // Use the explicit initials if stored, else derive from name
        if case .initials(let t, _, _) = contact.avatar { return t }
        let parts = name.components(separatedBy: " ")
        return parts.prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
    }
}
