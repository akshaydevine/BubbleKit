// BubbleKitModels.swift

import SwiftUI

// MARK: - Conversation

public struct BKConversation: Identifiable {
    public let id: String
    public var participants:       [BKContact]
    public var displayName:        String
    public var lastMessage:        String
    public var lastMessageTime:    Date
    public var isRead:             Bool
    public var unreadCount:        Int
    public var isPinned:           Bool
    public var isMuted:            Bool
    public var hasTypingIndicator: Bool
    public var userInfo:           [String: AnyHashable]

    public init(
        id: String = UUID().uuidString,
        participants: [BKContact],
        displayName: String? = nil,
        lastMessage: String,
        lastMessageTime: Date = Date(),
        isRead: Bool = true,
        unreadCount: Int = 0,
        isPinned: Bool = false,
        isMuted: Bool = false,
        hasTypingIndicator: Bool = false,
        userInfo: [String: AnyHashable] = [:]
    ) {
        self.id = id
        self.participants = participants
        self.displayName = displayName ?? participants.map(\.name).joined(separator: ", ")
        self.lastMessage = lastMessage
        self.lastMessageTime = lastMessageTime
        self.isRead = isRead
        self.unreadCount = unreadCount
        self.isPinned = isPinned
        self.isMuted = isMuted
        self.hasTypingIndicator = hasTypingIndicator
        self.userInfo = userInfo
    }
}

// MARK: - Contact

public struct BKContact: Identifiable, Hashable {
    public let id: String
    public var name:     String
    public var avatar:   BKAvatar
    public var isOnline: Bool
    public var userInfo: [String: AnyHashable]

    public init(
        id: String = UUID().uuidString,
        name: String,
        avatar: BKAvatar = .placeholder,
        isOnline: Bool = false,
        userInfo: [String: AnyHashable] = [:]
    ) {
        self.id = id; self.name = name; self.avatar = avatar
        self.isOnline = isOnline; self.userInfo = userInfo
    }

    public static func == (lhs: BKContact, rhs: BKContact) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Avatar

public enum BKAvatar: Hashable {
    case url(URL)
    case image(String)
    case systemSymbol(String)
    case initials(String, Color, Color)
    case placeholder
}

// MARK: - Status Content
// Optional user-set status shown as a bubble above the pinned avatar.
// Text: plain string or emoji.
// Image: a URL to a user-uploaded photo.

public enum BKStatusContent {
    case text(String)               // plain string or emoji
    case image(URL)                 // user-uploaded photo
    case both(String, URL)          // caption text + image shown together

    /// Returns the text component if present.
    public var text: String? {
        switch self {
        case .text(let t):      return t
        case .both(let t, _):   return t
        case .image:            return nil
        }
    }

    /// Returns the image URL component if present.
    public var imageURL: URL? {
        switch self {
        case .image(let u):     return u
        case .both(_, let u):   return u
        case .text:             return nil
        }
    }
}

// MARK: - Pinned Entry

public struct BKPinnedEntry: Identifiable {
    public let id: String
    public var contact:        BKContact
    public var conversation:   BKConversation?
    public var hasUnread:      Bool
    public var unreadCount:    Int
    /// Optional status set by the contact — shown as a bubble above the pinned avatar.
    public var status:         BKStatusContent?

    public init(
        id: String = UUID().uuidString,
        contact: BKContact,
        conversation: BKConversation? = nil,
        hasUnread: Bool = false,
        unreadCount: Int = 0,
        status: BKStatusContent? = nil
    ) {
        self.id = id
        self.contact = contact
        self.conversation = conversation
        self.hasUnread = hasUnread
        self.unreadCount = unreadCount
        self.status = status
    }

    static func stub(contact: BKContact) -> BKPinnedEntry? {
        BKPinnedEntry(contact: contact)
    }
}

// MARK: - Context Action

public struct BKContextAction: Identifiable {
    public let id: String
    public var title: String
    public var icon:  String
    public var role:  Role

    public enum Role { case normal, destructive, primary }

    public init(id: String = UUID().uuidString, title: String, icon: String, role: Role = .normal) {
        self.id = id; self.title = title; self.icon = icon; self.role = role
    }

    public static let addToPinID      = "bk.builtin.addToPin"
    public static let deleteID        = "bk.builtin.delete"
    public static let removeFromPinID = "bk.builtin.removeFromPin"

    public static func pinAction(isPinned: Bool) -> BKContextAction {
        isPinned
            ? BKContextAction(id: removeFromPinID, title: "Remove from Pin", icon: "pin.slash", role: .destructive)
            : BKContextAction(id: addToPinID,      title: "Add to Pin",      icon: "pin",       role: .normal)
    }

    public static let defaults: [BKContextAction] = [
        BKContextAction(title: "Select Messages", icon: "checkmark.circle", role: .normal),
        BKContextAction(title: "Edit Pins",       icon: "pin",              role: .normal)
    ]
}

// MARK: - Edit Action

public struct BKEditAction: Identifiable {
    public let id:    String
    public var title: String
    public var icon:  String
    public var role:  Role

    public enum Role { case normal, destructive }

    public init(id: String = UUID().uuidString, title: String, icon: String, role: Role = .normal) {
        self.id = id; self.title = title; self.icon = icon; self.role = role
    }

    public static let selectMessagesID = "bk.edit.selectMessages"
    public static let editPinsID       = "bk.edit.editPins"

    public static let defaults: [BKEditAction] = [
        BKEditAction(id: selectMessagesID, title: "Select Messages", icon: "checkmark.circle"),
        BKEditAction(id: editPinsID,       title: "Edit Pins",       icon: "pin")
    ]
}

// MARK: - Filter

public enum BKConversationFilter: String, CaseIterable, Identifiable {
    case all, unread, groups
    public var id: String { rawValue }
    public var label: String {
        switch self { case .all: return "All"; case .unread: return "Unread"; case .groups: return "Groups" }
    }
}

// MARK: - Events

public struct BKConversationEvent {
    public enum Kind {
        case tap, longPress, swipeArchive, swipeDelete, swipePin
        case contextAction(BKContextAction)
    }
    public let conversation: BKConversation
    public let kind: Kind
}

public struct BKPinnedEvent {
    public enum Kind {
        case tap, longPress, add, reorder(from: Int, to: Int), remove
    }
    public let entry: BKPinnedEntry
    public let kind:  Kind
}
