// BKMessage.swift

import SwiftUI

// MARK: - Attachment

public enum BKAttachment: Identifiable {
    case image(URL)
    case video(URL, thumbnail: URL?)
    case document(URL, filename: String)          // PDF, docx, zip, etc.
    case audio(URL, duration: Int)
    case location(URL, latitude: Double, longitude: Double, address: String?)

    public var id: String {
        switch self {
        case .image(let url):          return url.absoluteString
        case .video(let url, _):       return url.absoluteString
        case .document(let url, _):    return url.absoluteString
        case .audio(let url, _):       return url.absoluteString
        case .location(let url, _, _, _): return url.absoluteString
        }
    }

    public var imageURL: URL? {
        switch self {
        case .image(let url):        return url
        case .video(_, let thumb):   return thumb
        case .document, .audio, .location:      return nil
        }
    }

    public var fileURL: URL {
        switch self {
        case .image(let url):       return url
        case .video(let url, _):    return url
        case .document(let url, _): return url
        case .audio(let url, _):    return url
        case .location(let url, _, _, _): return url
        }
    }
}

// MARK: - Read Receipt

public enum BKReadReceipt {
    case sent       // single tick
    case delivered  // double tick grey
    case read       // double tick blue
}

// MARK: - Reply Preview (breaks recursive struct cycle)

public final class BKMessageReply {
    public let id:          String
    public let senderName:  String
    public let text:        String?
    public let imageURL:    URL?

    public init(message: BKMessage) {
        self.id         = message.id
        self.senderName = message.sender.name
        self.text       = message.text
        self.imageURL   = message.attachments.first?.imageURL
    }
}

// MARK: - Edit Mode

public enum BKMessageEditMode {
    case none
    case editing(BKMessage)   // user is editing this message
}

// MARK: - Message

public struct BKMessage: Identifiable {
    public let id:           String
    public var sender:       BKContact
    public var text:         String?
    public var attachments:  [BKAttachment]
    public var sentAt:       Date
    public var isOutgoing:   Bool
    public var readReceipt:  BKReadReceipt
    public var replyTo:      BKMessageReply?
    public var isTranslated: Bool
    public var reactions:    [BKReaction]
    public var isDeleted:    Bool
    public var isPinned:     Bool
    public var threadReplyCount: Int

    public init(
        id:           String          = UUID().uuidString,
        sender:       BKContact,
        text:         String?         = nil,
        attachments:  [BKAttachment]  = [],
        sentAt:       Date            = Date(),
        isOutgoing:   Bool            = false,
        readReceipt:  BKReadReceipt   = .sent,
        replyTo:      BKMessageReply? = nil,
        isTranslated: Bool            = false,
        reactions:    [BKReaction]    = [],
        isDeleted:    Bool            = false,
        isPinned:     Bool            = false,
        threadReplyCount: Int         = 0
    ) {
        self.id           = id
        self.sender       = sender
        self.text         = text
        self.attachments  = attachments
        self.sentAt       = sentAt
        self.isOutgoing   = isOutgoing
        self.readReceipt  = readReceipt
        self.replyTo      = replyTo
        self.isTranslated = isTranslated
        self.reactions    = reactions
        self.isDeleted    = isDeleted
        self.isPinned     = isPinned
        self.threadReplyCount = threadReplyCount
    }
}

// MARK: - Reaction

public struct BKReaction: Identifiable {
    public let id:    String
    public var emoji: String
    public var count: Int
    public var byMe:  Bool

    public init(id: String = UUID().uuidString, emoji: String, count: Int = 1, byMe: Bool = false) {
        self.id    = id
        self.emoji = emoji
        self.count = count
        self.byMe  = byMe
    }
}

// MARK: - Date Section Header

public struct BKMessageSection: Identifiable {
    public let id:       String
    public var date:     Date
    public var messages: [BKMessage]
}

// MARK: - Chat Info

public struct BKChatInfo {
    public var title:    String
    public var subtitle: String?
    public var avatar:   BKAvatar
    public var isGroup:  Bool

    public init(title: String, subtitle: String? = nil, avatar: BKAvatar, isGroup: Bool = false) {
        self.title    = title
        self.subtitle = subtitle
        self.avatar   = avatar
        self.isGroup  = isGroup
    }
}
