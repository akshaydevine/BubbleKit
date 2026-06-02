// BKConversationListViewModel.swift

import SwiftUI
import Combine

public final class BKConversationListViewModel: ObservableObject {

    // MARK: - Published State

    @Published public var conversations:        [BKConversation] = []
    @Published public var pinnedEntries:        [BKPinnedEntry]  = []
    @Published public var searchQuery:          String           = ""
    @Published public var isSearching:          Bool             = false
    @Published public var activeFilter:         BKConversationFilter = .all
    @Published public var selectedConversation: BKConversation?
    @Published public var contextConversation:  BKConversation?
    @Published public var showEditMenu:         Bool             = false
    /// Set when user long-presses a pinned avatar — drives the pinned context popover
    @Published public var pinnedContextEntry:   BKPinnedEntry?  = nil

    @Published public var isSelectMessagesMode:    Bool         = false
    @Published public var selectedConversationIDs: Set<String>  = []
    @Published public var isEditPinsMode:          Bool         = false

    // MARK: - Delegates

    public weak var dataSource:    (any BKDataSource)?
    public weak var eventDelegate: (any BKEventDelegate)?
    public weak var uiDelegate:    (any BKUIDelegate)?

    // MARK: - Derived

    public var displayedConversations: [BKConversation] {
        if isSearching && !searchQuery.isEmpty { return searchResults }
        return conversations
    }

    public var editMenuActions: [BKEditAction] {
        dataSource?.editMenuActions() ?? BKEditAction.defaults
    }

    private var searchResults:  [BKConversation] = []
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    public init() {
        $searchQuery
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] q in self?.handleSearch(q) }
            .store(in: &cancellables)

        $activeFilter
            .sink { [weak self] f in self?.reload(filter: f) }
            .store(in: &cancellables)
    }

    // MARK: - Load

    public func reload(filter: BKConversationFilter? = nil) {
        let f = filter ?? activeFilter
        conversations = dataSource?.conversations(for: f) ?? []
        pinnedEntries = dataSource?.pinnedEntries() ?? []
    }

    // MARK: - Search

    private func handleSearch(_ query: String) {
        guard !query.isEmpty else { searchResults = []; return }
        if let custom = dataSource?.conversations(matching: query) {
            searchResults = custom
        } else {
            let q = query.lowercased()
            searchResults = conversations.filter {
                $0.displayName.lowercased().contains(q) ||
                $0.lastMessage.lowercased().contains(q)
            }
        }
        eventDelegate?.bubbleKit(didChangeSearchQuery: query)
    }

    // MARK: - Pin helpers

    public func isPinned(_ conversation: BKConversation) -> Bool {
        guard let contact = conversation.participants.first else { return false }
        return pinnedEntries.contains { $0.contact.id == contact.id }
    }

    func didAddPin(_ conversation: BKConversation) {
        guard let contact = conversation.participants.first,
              !isPinned(conversation) else { return }

        let entry = BKPinnedEntry(
            contact:      contact,
            conversation: conversation,
            hasUnread:    conversation.unreadCount > 0,
            unreadCount:  conversation.unreadCount
        )
        pinnedEntries.append(entry)
        eventDelegate?.bubbleKit(didHandle: BKPinnedEvent(entry: entry, kind: .add))
    }

    // MARK: - Context Actions
    // Only shows: Pin/Unpin + Delete

    func contextActions(for conversation: BKConversation) -> [BKContextAction] {
        let pinAction = BKContextAction.pinAction(isPinned: isPinned(conversation))
        let deleteAction = BKContextAction(
            id:    BKContextAction.deleteID,
            title: "Delete",
            icon:  "trash",
            role:  .destructive
        )
        return [pinAction, deleteAction]
    }

    // MARK: - Edit Menu

    func didTapEdit() {
        showEditMenu.toggle()
        eventDelegate?.bubbleKitDidTapEdit(isOpen: showEditMenu)
    }

    func didSelectEditAction(_ action: BKEditAction) {
        showEditMenu = false
        switch action.id {
        case BKEditAction.selectMessagesID:
            enterSelectMessagesMode()
        case BKEditAction.editPinsID:
            enterEditPinsMode()
        default:
            break
        }
        eventDelegate?.bubbleKit(didSelectEditAction: action)
    }

    func dismissEditMenu() {
        showEditMenu = false
    }

    // MARK: - Select Messages Mode

    func enterSelectMessagesMode() {
        isSelectMessagesMode = true
        isEditPinsMode = false
        selectedConversationIDs = []
    }

    func exitSelectMessagesMode() {
        isSelectMessagesMode = false
        selectedConversationIDs = []
    }

    func toggleConversationSelection(_ conversation: BKConversation) {
        if selectedConversationIDs.contains(conversation.id) {
            selectedConversationIDs.remove(conversation.id)
        } else {
            selectedConversationIDs.insert(conversation.id)
        }
    }

    func isConversationSelected(_ conversation: BKConversation) -> Bool {
        selectedConversationIDs.contains(conversation.id)
    }

    func deleteSelectedConversations() {
        conversations.removeAll { selectedConversationIDs.contains($0.id) }
        selectedConversationIDs = []
        exitSelectMessagesMode()
    }

    var isAllSelected: Bool {
        !conversations.isEmpty && selectedConversationIDs.count == conversations.count
    }

    func selectAll() {
        selectedConversationIDs = Set(conversations.map(\.id))
    }

    func deselectAll() {
        selectedConversationIDs = []
    }

    // MARK: - Edit Pins Mode

    func enterEditPinsMode() {
        isEditPinsMode = true
        isSelectMessagesMode = false
    }

    func exitEditPinsMode() {
        isEditPinsMode = false
    }

    // MARK: - Conversation actions

    func didTap(_ conversation: BKConversation) {
        if isSelectMessagesMode {
            toggleConversationSelection(conversation)
            return
        }
        eventDelegate?.bubbleKit(didHandle: BKConversationEvent(conversation: conversation, kind: .tap))
    }

    func didLongPress(_ conversation: BKConversation) {
        guard !isSelectMessagesMode else { return }
        selectedConversation = nil
        contextConversation  = conversation
        eventDelegate?.bubbleKit(didHandle: BKConversationEvent(conversation: conversation, kind: .longPress))
    }

    func didSelectContextAction(_ action: BKContextAction, for conversation: BKConversation) {
        contextConversation = nil

        switch action.id {

        case BKContextAction.addToPinID:
            // Add to pinned entries
            didAddPin(conversation)

        case BKContextAction.removeFromPinID:
            // Remove from pinned entries
            if let contact = conversation.participants.first {
                pinnedEntries.removeAll { $0.contact.id == contact.id }
                if let entry = BKPinnedEntry.stub(contact: contact) {
                    eventDelegate?.bubbleKit(didHandle: BKPinnedEvent(entry: entry, kind: .remove))
                }
            }

        case BKContextAction.deleteID:
            // Delete the conversation from the list
            withAnimation {
                conversations.removeAll { $0.id == conversation.id }
            }
            eventDelegate?.bubbleKit(didHandle: BKConversationEvent(conversation: conversation, kind: .swipeDelete))

        default:
            eventDelegate?.bubbleKit(didHandle: BKConversationEvent(conversation: conversation,
                                                                     kind: .contextAction(action)))
        }
    }

    func didSwipeDelete(_ conversation: BKConversation) {
        conversations.removeAll { $0.id == conversation.id }
        eventDelegate?.bubbleKit(didHandle: BKConversationEvent(conversation: conversation, kind: .swipeDelete))
    }

    func didSwipePin(_ conversation: BKConversation) {
        if isPinned(conversation) {
            // Remove from pinned
            if let contact = conversation.participants.first {
                pinnedEntries.removeAll { $0.contact.id == contact.id }
                if let entry = BKPinnedEntry.stub(contact: contact) {
                    eventDelegate?.bubbleKit(didHandle: BKPinnedEvent(entry: entry, kind: .remove))
                }
            }
        } else {
            // Add to pinned
            didAddPin(conversation)
        }
        eventDelegate?.bubbleKit(didHandle: BKConversationEvent(conversation: conversation, kind: .swipePin))
    }

    func didSwipeArchive(_ conversation: BKConversation) {
        eventDelegate?.bubbleKit(didHandle: BKConversationEvent(conversation: conversation, kind: .swipeArchive))
    }

    func didTapPinned(_ entry: BKPinnedEntry) {
        eventDelegate?.bubbleKit(didHandle: BKPinnedEvent(entry: entry, kind: .tap))
    }

    func showPinnedContext(for entry: BKPinnedEntry) {
        pinnedContextEntry = entry
    }

    func didLongPressPinned(_ entry: BKPinnedEntry) {
        eventDelegate?.bubbleKit(didHandle: BKPinnedEvent(entry: entry, kind: .longPress))
    }

    func didReorderPins(from: Int, to: Int) {
        guard from != to,
              pinnedEntries.indices.contains(from),
              pinnedEntries.indices.contains(to) else { return }
        let moved = pinnedEntries.remove(at: from)
        pinnedEntries.insert(moved, at: to)
        eventDelegate?.bubbleKit(didHandle: BKPinnedEvent(entry: moved,
                                                           kind: .reorder(from: from, to: to)))
    }

    func didRemovePin(_ entry: BKPinnedEntry) {
        pinnedEntries.removeAll { $0.id == entry.id }
        eventDelegate?.bubbleKit(didHandle: BKPinnedEvent(entry: entry, kind: .remove))
    }

    func didTapCompose() {
        eventDelegate?.bubbleKitDidTapCompose()
    }

    func beginSearch() {
        isSearching = true
        eventDelegate?.bubbleKit(didBeginSearch: true)
    }

    func cancelSearch() {
        isSearching   = false
        searchQuery   = ""
        searchResults = []
        eventDelegate?.bubbleKit(didCancelSearch: true)
    }

    func destination(for conversation: BKConversation) -> AnyView? {
        guard !isSelectMessagesMode else { return nil }
        return eventDelegate?.bubbleKit(destinationFor: conversation)
    }
}
