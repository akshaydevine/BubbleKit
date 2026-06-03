// BKChatSampleData.swift
// ⚠️ FOR PREVIEWS & DEMO ONLY — Do NOT use in production.
// In your app, pass real data via BKChatViewModel(chatInfo:currentUser:messages:)

import SwiftUI

public enum BKChatSampleData {

    // MARK: - Sample Participants (demo only)

    public static let me = BKContact(
        id: "me",
        name: "You",
        avatar: .initials("ME", .white, Color(hex: "#007AFF")),
        isOnline: true
    )

    public static let leia = BKContact(
        id: "leia",
        name: "Leia Organa",
        avatar: .url(URL(string: "https://i.pravatar.cc/150?img=47")!),
        isOnline: true
    )

    // MARK: - Sample Chat Info (demo only)

    public static let groupChatInfo = BKChatInfo(
        title:    "Sample Group",
        subtitle: "3 members",
        avatar:   .url(URL(string: "https://i.pravatar.cc/150?img=33")!),
        isGroup:  true
    )

    // MARK: - Sample Messages (demo only)

    public static let messages: [BKMessage] = [
        BKMessage(
            id: "m1",
            sender: me,
            attachments: [
                .image(URL(string: "https://picsum.photos/seed/flowers/600/400")!)
            ],
            sentAt: Date().addingTimeInterval(-86400 * 2 - 600),
            isOutgoing: true,
            readReceipt: .read
        ),
        BKMessage(
            id: "m2",
            sender: leia,
            text: "Hey! Nice photo 😊",
            sentAt: Date().addingTimeInterval(-86400),
            isOutgoing: false,
            readReceipt: .delivered,
            reactions: [BKReaction(emoji: "👍", count: 1, byMe: false)]
        ),
        BKMessage(
            id: "m3",
            sender: me,
            text: "Thanks! How are you?",
            sentAt: Date(),
            isOutgoing: true,
            readReceipt: .read
        )
    ]
}
