// BKConversationListView.swift

import SwiftUI

public struct BKConversationListView: View {

    @StateObject private var viewModel = BKConversationListViewModel()
    @State private var showCompose: Bool = false

    private let theme:             BubbleKitTheme
    private let dataSource:        any BKDataSource
    private let eventDelegate:     (any BKEventDelegate)?
    private let uiDelegate:        (any BKUIDelegate)?
    private let title:             String
    public  var pinnedDisplayMode: BKPinnedDisplayMode = .horizontalScroll

    /// ✅ Optional closure — bind this to hide/show your custom tab bar.
    /// Called with `true` when chat detail opens, `false` when it closes.
    public var onChatNavigationChanged: ((Bool) -> Void)? = nil

    public init(
        title:             String                 = "Messages",
        theme:             BubbleKitTheme         = .default,
        dataSource:        any BKDataSource,
        eventDelegate:     (any BKEventDelegate)? = nil,
        uiDelegate:        (any BKUIDelegate)?    = nil,
        pinnedDisplayMode: BKPinnedDisplayMode    = .horizontalScroll,
        onChatNavigationChanged: ((Bool) -> Void)? = nil  // ✅ new
    ) {
        self.title                   = title
        self.theme                   = theme
        self.dataSource              = dataSource
        self.eventDelegate           = eventDelegate
        self.uiDelegate              = uiDelegate
        self.pinnedDisplayMode       = pinnedDisplayMode
        self.onChatNavigationChanged = onChatNavigationChanged
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                theme.colors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    if !viewModel.isSelectMessagesMode && !viewModel.isEditPinsMode {
                        BKSearchBar(
                            text:        $viewModel.searchQuery,
                            isSearching: $viewModel.isSearching,
                            viewModel:   viewModel
                        )
                    }

                    // ✅ Select toolbar sits at the TOP, right below the nav bar
                    if viewModel.isSelectMessagesMode {
                        selectMessagesToolbar
                    }

                    if !viewModel.pinnedEntries.isEmpty && !viewModel.isSearching {
                        BKPinnedRowView(viewModel: viewModel, displayMode: pinnedDisplayMode)
                    }

                    conversationList
                }

                if viewModel.showEditMenu {
                    Color.clear
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { withAnimation { viewModel.dismissEditMenu() } }
                }
            }
            .navigationTitle(
                viewModel.isSelectMessagesMode ? "Select Messages" :
                viewModel.isEditPinsMode       ? "Edit Pins"       : title
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarItems }
            .overlay(alignment: .top) {
                if viewModel.showEditMenu {
                    editDropdown
                        .padding(.leading, 16)
                        .zIndex(200)
                        .transition(.scale(scale: 0.9, anchor: .topLeading).combined(with: .opacity))
                        .animation(.spring(response: 0.22, dampingFraction: 0.85), value: viewModel.showEditMenu)
                }
            }
            // ── Navigation destinations (INSIDE NavigationStack) ──────────
            .navigationDestination(isPresented: Binding(
                get: { viewModel.selectedConversation != nil },
                set: { if !$0 {
                    viewModel.selectedConversation = nil
                    viewModel.onChatNavigationChanged?(false)  // ✅ chat closed
                }}
            )) {
                if let conv = viewModel.selectedConversation,
                   let dest = viewModel.destination(for: conv) {
                    dest
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { viewModel.selectedPinnedEntry != nil },
                set: { if !$0 {
                    viewModel.selectedPinnedEntry = nil
                    viewModel.onChatNavigationChanged?(false)  // ✅ chat closed
                }}
            )) {
                if let entry = viewModel.selectedPinnedEntry,
                   let dest = viewModel.pinnedDestination(for: entry) {
                    dest
                }
            }
            .overlay {
                if viewModel.contextConversation != nil {
                    contextPopoverOverlay
                }
            }
            .overlay {
                if viewModel.pinnedContextEntry != nil {
                    pinnedContextOverlay
                }
            }
        }
        // ── Applied outside NavigationStack ───────────────────────────────
        .bubbleKitTheme(theme)
        .onAppear { wire() }
    }

    // MARK: - Conversation List
    // FIX 1: Replaced ScrollView+LazyVStack+BKSwipeableRow with a plain List.
    // Root cause of broken swipes: ScrollView's vertical pan gesture always
    // takes priority over the custom horizontal DragGesture inside BKSwipeableRow,
    // so the swipe never starts. SwiftUI List uses UITableView internally, which
    // correctly separates vertical scroll from horizontal swipe at the UIKit level.
    // .swipeActions() on List rows is the correct, reliable API for this pattern.

    @ViewBuilder
    private var conversationList: some View {
        let items = viewModel.displayedConversations
        if items.isEmpty {
            emptyState
        } else {
            List {
//                if let entry = viewModel.selectedPinnedEntry,
//                   let dest = viewModel.pinnedDestination(for: entry) {
//                    NavigationLink(
//                        destination: dest,
//                        isActive: Binding(
//                            get: { viewModel.selectedPinnedEntry?.id == entry.id },
//                            set: { if !$0 { viewModel.selectedPinnedEntry = nil } }
//                        )
//                    ) { EmptyView() }
//                        .frame(width: 0, height: 0)
//                        .hidden()
//                        .listRowInsets(EdgeInsets())
//                        .listRowSeparator(.hidden)
//                }
                ForEach(items) { conversation in
                    conversationRow(conversation)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.visible)
                        .listRowBackground(theme.colors.rowBackground)
                        // Swipe actions are hidden in select-messages mode
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if !viewModel.isSelectMessagesMode {
                                Button(role: .destructive) {
                                    withAnimation { viewModel.didSwipeDelete(conversation) }
                                } label: {
                                    Label("Delete", systemImage: "trash.fill")
                                }
                                Button {
                                    viewModel.didSwipeArchive(conversation)
                                } label: {
                                    Label("Archive", systemImage: "archivebox.fill")
                                }
                                .tint(theme.colors.appleGrey)
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            if !viewModel.isSelectMessagesMode {
                                Button {
                                    viewModel.didSwipePin(conversation)
                                } label: {
                                    Label(
                                        viewModel.isPinned(conversation) ? "Unpin" : "Pin",
                                        systemImage: viewModel.isPinned(conversation) ? "pin.slash.fill" : "pin.fill"
                                    )
                                }
                                .tint(theme.colors.appleBlue)
                            }
                        }
                }
            }
            .listStyle(.plain)
            .background(theme.colors.background)
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func conversationRow(_ conversation: BKConversation) -> some View {
        if viewModel.isSelectMessagesMode {
            selectableRow(conversation)
        } else {
            normalRow(conversation)
        }
    }

    // How this works:
    // ┌─────────────────────────────────────────────────────┐
    // │ List row (zero insets, full screen width)           │
    // │ ┌──────────────────────────────────────────────────┐│
    // │ │ ZStack (fills row)                               ││
    // │ │  • BKConversationRowView — slid RIGHT by 48pt   ││
    // │ │    so it stays fully inside the row bounds       ││
    // │ │  • Checkmark — pinned to leading edge of ZStack  ││
    // │ │    inside the 48pt gap, never clipped            ││
    // │ └──────────────────────────────────────────────────┘│
    // └─────────────────────────────────────────────────────┘
    private let checkmarkSlot: CGFloat = 48   // gap revealed to the left of the row

    private func selectableRow(_ conversation: BKConversation) -> some View {
        let selected = viewModel.isConversationSelected(conversation)
        return ZStack(alignment: .leading) {
            // Row content shifted right — fits inside the List cell, nothing overflows
            BKConversationRowView(conversation: conversation, viewModel: viewModel)
                .padding(.leading, checkmarkSlot)

            // Checkmark lives in the revealed left gap — always fully visible
            checkmark(selected: selected)
                .frame(width: 24, height: 24)
                .padding(.leading, (checkmarkSlot - 24) / 2)   // centred in the slot
        }
        .contentShape(Rectangle())
        .onTapGesture { viewModel.toggleConversationSelection(conversation) }
        .background(theme.colors.rowBackground)
    }

    // FIX 1 (continued): normalRow no longer wraps BKSwipeableRow.
    // Tap and long-press are handled with standard SwiftUI modifiers.
    // Swipe is handled by .swipeActions on the List row above.
    private func normalRow(_ conversation: BKConversation) -> some View {
        let destination = viewModel.destination(for: conversation)

        return BKConversationRowView(conversation: conversation, viewModel: viewModel)
            .contentShape(Rectangle())
            .onTapGesture {
                if destination != nil { viewModel.selectedConversation = conversation }
                viewModel.didTap(conversation)
            }
            .onLongPressGesture(minimumDuration: 0.4, maximumDistance: 10) {
                viewModel.didLongPress(conversation)
            }
    }

    // MARK: - Checkmark bubble

    @ViewBuilder
    private func checkmark(selected: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(selected ? theme.colors.appleBlue : theme.colors.lightGrey, lineWidth: 2)
                .frame(width: 24, height: 24)
            if selected {
                Circle().fill(theme.colors.appleBlue).frame(width: 24, height: 24)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .animation(.spring(response: 0.2), value: selected)
    }

    // MARK: - Select Messages top toolbar

    private var selectMessagesToolbar: some View {
        VStack(spacing: 0) {
            HStack {
                // Select All / Deselect All
                Button {
                    withAnimation(.spring(response: 0.2)) {
                        viewModel.isAllSelected ? viewModel.deselectAll() : viewModel.selectAll()
                    }
                } label: {
                    Text(viewModel.isAllSelected ? "Deselect All" : "Select All")
                        .font(.system(size: 15))
                        .foregroundColor(theme.colors.appleBlue)
                }

                Spacer()

                // Delete
                Button(role: .destructive) {
                    viewModel.deleteSelectedConversations()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                        Text("Delete")
                    }
                    .font(.system(size: 15))
                }
                .disabled(viewModel.selectedConversationIDs.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(theme.colors.background)

            Divider()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.2), value: viewModel.isSelectMessagesMode)
    }

    // MARK: - Toolbar items

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {

        ToolbarItem(placement: .navigationBarLeading) {
            if viewModel.isSelectMessagesMode || viewModel.isEditPinsMode {
                Button("Done") {
                    withAnimation {
                        if viewModel.isSelectMessagesMode { viewModel.exitSelectMessagesMode() }
                        if viewModel.isEditPinsMode       { viewModel.exitEditPinsMode() }
                    }
                }
                .foregroundColor(theme.colors.appleBlue)
                .fontWeight(.semibold)
            } else if let custom = viewModel.uiDelegate?.bubbleKitLeadingBarItems() {
                custom
            } else {
                Button { withAnimation { viewModel.didTapEdit() } } label: {
                    Text("Edit").foregroundColor(theme.colors.appleBlue)
                }
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            if viewModel.isSelectMessagesMode || viewModel.isEditPinsMode {
                EmptyView()
            } else if let custom = viewModel.uiDelegate?.bubbleKitTrailingBarItems() {
                custom
            } else {
                HStack(spacing: 16) {
                    Button {} label: {
                        Image(systemName: "person.2.circle").foregroundColor(theme.colors.appleBlue)
                    }
                    Button {
                        showCompose = true
                        viewModel.didTapCompose()
                    } label: {
                        Image(systemName: "square.and.pencil").foregroundColor(theme.colors.appleBlue)
                    }
                    .sheet(isPresented: $showCompose) {
                        if let contacts = viewModel.dataSource?.conversations(for: .all)
                            .flatMap({ $0.participants }) {
                            BKComposeView(
                                contacts: Array(Set(contacts)),
                                onSend: { recipients, firstMessage in
                                    showCompose = false
                                    viewModel.eventDelegate?.bubbleKitDidTapCompose()
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Edit Dropdown

    private var editDropdown: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(viewModel.editMenuActions.enumerated()), id: \.element.id) { idx, action in
                Button { withAnimation { viewModel.didSelectEditAction(action) } } label: {
                    HStack(spacing: 12) {
                        Text(action.title)
                            .font(theme.typography.popoverItem)
                            .foregroundColor(action.role == .destructive ? .red : theme.colors.appleBlack)
                        Spacer()
                        Image(systemName: action.icon)
                            .foregroundColor(action.role == .destructive ? .red : theme.colors.appleGrey)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                }
                .buttonStyle(.plain)
                if idx < viewModel.editMenuActions.count - 1 { Divider() }
            }
        }
        .frame(width: 220)
        .background(theme.colors.popoverBackground)
        .clipShape(RoundedRectangle(cornerRadius: theme.layout.cornerRadius))
        .shadow(color: theme.effects.bubbleShadow.color,
                radius: theme.effects.bubbleShadow.radius,
                x: theme.effects.bubbleShadow.x,
                y: theme.effects.bubbleShadow.y)
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        if viewModel.isSearching,
           let custom = viewModel.uiDelegate?.bubbleKitEmptySearchView(query: viewModel.searchQuery) {
            custom
        } else if !viewModel.isSearching,
                  let custom = viewModel.uiDelegate?.bubbleKitEmptyStateView(for: viewModel.activeFilter) {
            custom
        } else {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: viewModel.isSearching ? "magnifyingglass" : "bubble.left.and.bubble.right")
                    .font(.system(size: 52)).foregroundColor(theme.colors.lightGrey)
                Text(viewModel.isSearching
                     ? "No results for \"\(viewModel.searchQuery)\""
                     : "No Messages")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(theme.colors.appleGrey)
                Spacer()
            }
        }
    }

    // MARK: - Context Popover Overlay

    @ViewBuilder
    private var contextPopoverOverlay: some View {
        if let conv = viewModel.contextConversation {
            ZStack {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.2)) {
                            viewModel.contextConversation = nil
                        }
                    }

                BKContextPopoverView(conversation: conv, viewModel: viewModel)
                    .frame(width: 270)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 8)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: conv.id)
        }
    }

    // MARK: - Pinned Context Overlay

    @ViewBuilder
    private var pinnedContextOverlay: some View {
        if let entry = viewModel.pinnedContextEntry {
            ZStack {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.2)) {
                            viewModel.pinnedContextEntry = nil
                        }
                    }

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        BKAvatarView(contact: entry.contact, size: 40)
                        Text(entry.contact.name.replacingOccurrences(of: "• ", with: ""))
                            .font(theme.typography.senderName)
                            .foregroundColor(theme.colors.appleBlack)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                    Divider()

                    Button {
                        withAnimation(.spring(response: 0.2)) {
                            viewModel.pinnedContextEntry = nil
                            viewModel.didRemovePin(entry)
                        }
                    } label: {
                        HStack {
                            Text("Remove Pin")
                                .font(theme.typography.popoverItem)
                                .foregroundColor(.red)
                            Spacer()
                            Image(systemName: "pin.slash")
                                .font(.system(size: 16))
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: 270)
                .fixedSize(horizontal: false, vertical: true)
                .background(theme.colors.popoverBackground)
                .clipShape(RoundedRectangle(cornerRadius: theme.layout.cornerRadius))
                .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 8)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: entry.id)
        }
    }

    // MARK: - Wire

    private func wire() {
        viewModel.dataSource             = dataSource
        viewModel.eventDelegate          = eventDelegate
        viewModel.uiDelegate             = uiDelegate
        viewModel.onChatNavigationChanged = onChatNavigationChanged  // ✅ wire callback
        viewModel.reload()
    }
}
