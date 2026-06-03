// BKSampleData.swift

import SwiftUI

public enum BKSampleData {

    // MARK: - Single Source of Truth
    //
    // One `Record` per person. All three derived arrays (contacts, conversations,
    // pinnedEntries) are built from this table — add, remove, or edit in one place.
    //
    // Columns:
    //   Contact      → id, name, avatarURL, isOnline
    //   Conversation → lastMessage + lastMessageTime (nil = no conversation row)
    //   Pinned strip → isPinnedEntry, pinnedHasUnread, pinnedUnreadCount, pinnedStatus

    private struct Record {
        // ── Contact ───────────────────────────────────────
        var id:        String
        var name:      String
        var avatarURL: String
        var isOnline:  Bool

        // ── Conversation (nil fields = not in conversation list) ──
        var lastMessage:     String?       = nil
        var lastMessageTime: TimeInterval? = nil   // seconds relative to now; negative = past
        var isRead:          Bool          = true
        var unreadCount:     Int           = 0
        var isPinned:        Bool          = false

        // ── Pinned strip (isPinnedEntry = false → not shown in strip) ─
        var isPinnedEntry:     Bool             = false
        var pinnedHasUnread:   Bool             = false
        var pinnedUnreadCount: Int              = 0
        // Pass a BKStatusContent directly — supports .text, .image, or nil.
        // No ambiguity: exactly one value, the type makes the intent explicit.
        var pinnedStatus:      BKStatusContent? = nil
    }

    // ── Master Table ──────────────────────────────────────────────────────────

    private static let records: [Record] = [

        // Pinned-only (appear in strip, no conversation row)
        Record(id: "lyndsey",    name: "Lyndsey",      avatarURL: "https://i.pravatar.cc/150?img=47", isOnline: true,
               isPinnedEntry: true, pinnedStatus: .text("Hi. I gotta rehearse at 2 today")),

        Record(id: "mom",        name: "Mom ❤️",        avatarURL: "https://i.pravatar.cc/150?img=45", isOnline: false,
               isPinnedEntry: true, pinnedHasUnread: true, pinnedUnreadCount: 2,
               pinnedStatus: .image(URL(string: "https://picsum.photos/seed/mom/120/60")!)),

        Record(id: "elliott",    name: "Elliott",       avatarURL: "https://i.pravatar.cc/150?img=12", isOnline: true,
               isPinnedEntry: true),

        Record(id: "lauren",     name: "Lauren",        avatarURL: "https://i.pravatar.cc/150?img=9",  isOnline: false,
               isPinnedEntry: true),

        Record(id: "iddris",     name: "Iddris",        avatarURL: "https://i.pravatar.cc/150?img=51", isOnline: true,
               isPinnedEntry: true, pinnedHasUnread: true, pinnedUnreadCount: 1,
               pinnedStatus: .text("RIP to my youth 🎸")),

        Record(id: "thenbhd",    name: "The NBHD",      avatarURL: "https://i.pravatar.cc/150?img=15", isOnline: false,
               isPinnedEntry: true),

        Record(id: "canyonclub", name: "Canyon Club",   avatarURL: "https://i.pravatar.cc/150?img=33", isOnline: false,
               isPinnedEntry: true),

        Record(id: "tobias",     name: "Tobias",        avatarURL: "https://i.pravatar.cc/150?img=60", isOnline: true,
               isPinnedEntry: true),

        Record(id: "karla",      name: "Karla",         avatarURL: "https://i.pravatar.cc/150?img=23", isOnline: true,
               isPinnedEntry: true, pinnedHasUnread: true, pinnedUnreadCount: 4),

        // Both text caption + image thumbnail shown together above the avatar
        Record(id: "zara",       name: "Zara",           avatarURL: "https://i.pravatar.cc/150?img=29", isOnline: true,
               isPinnedEntry: true, pinnedHasUnread: true, pinnedUnreadCount: 1,
               pinnedStatus: .both("Just landed! 🛫", URL(string: "https://picsum.photos/seed/zara/120/60")!)),

        // Conversation-only (appear in list, not in pinned strip)
        Record(id: "hellboy",    name: "Hell Boy",      avatarURL: "https://i.pravatar.cc/150?img=3",  isOnline: false,
               lastMessage: "Hi. I gotta rehearse at 2 today",                           lastMessageTime: -3600,   isRead: false),

        Record(id: "kevin",      name: "Kevin Rosal",   avatarURL: "https://i.pravatar.cc/150?img=18", isOnline: false,
               lastMessage: "I just sold my nintendo switch for $1500",                  lastMessageTime: -3900),

        Record(id: "eumin",      name: "Eumin Lee",     avatarURL: "https://i.pravatar.cc/150?img=7",  isOnline: false,
               lastMessage: "I'm using burger kings wifi",                               lastMessageTime: -4200),

        Record(id: "jessica",    name: "Jessica Walsh", avatarURL: "https://i.pravatar.cc/150?img=25", isOnline: true,
               lastMessage: "Cut chemist is doing an hour DJ set tomorrow nite on kcrw", lastMessageTime: -86400),

        Record(id: "greg",       name: "Greg Adams",    avatarURL: "https://i.pravatar.cc/150?img=52", isOnline: false,
               lastMessage: "Can you pick me up around 8?",                              lastMessageTime: -172800, isRead: false, unreadCount: 3),

        Record(id: "keithalva",  name: "Keith Alva",    avatarURL: "https://i.pravatar.cc/150?img=56", isOnline: true,
               lastMessage: "Just dropped the new track, lmk what you think",           lastMessageTime: -7200,   isRead: false, unreadCount: 1),
    ]

    // MARK: - Derived: Contacts

    public static let contacts: [BKContact] = records.map { r in
        BKContact(
            id:       r.id,
            name:     r.name,
            avatar:   .url(URL(string: r.avatarURL)!),
            isOnline: r.isOnline
        )
    }

    // O(1) lookup used by the two derived arrays below
    private static let contactMap: [String: BKContact] =
        Dictionary(uniqueKeysWithValues: contacts.map { ($0.id, $0) })

    private static func contact(_ id: String) -> BKContact {
        contactMap[id] ?? contacts[0]
    }

    // MARK: - Derived: Conversations

    public static let conversations: [BKConversation] = records.compactMap { r in
        guard let message = r.lastMessage,
              let offset  = r.lastMessageTime
        else { return nil }

        return BKConversation(
            id:              r.id,
            participants:    [contact(r.id)],
            lastMessage:     message,
            lastMessageTime: Date().addingTimeInterval(offset),
            isRead:          r.isRead,
            unreadCount:     r.unreadCount,
            isPinned:        r.isPinned
        )
    }

    // MARK: - Derived: Pinned Entries

    public static let pinnedEntries: [BKPinnedEntry] = records.compactMap { r in
        guard r.isPinnedEntry else { return nil }
        // Use existing conversation or create a stub so the chat screen can open
        let conv = conversations.first { $0.id == r.id } ?? BKConversation(
            id:              r.id,
            participants:    [contact(r.id)],
            lastMessage:     "",
            lastMessageTime: Date()
        )
        return BKPinnedEntry(
            contact:      contact(r.id),
            conversation: conv,
            hasUnread:    r.pinnedHasUnread,
            unreadCount:  r.pinnedUnreadCount,
            status:       r.pinnedStatus
        )
    }
}
