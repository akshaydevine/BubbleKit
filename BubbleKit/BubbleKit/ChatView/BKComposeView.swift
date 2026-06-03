// BKComposeView.swift
// "New Message" compose screen — matches Figma iOS 17 iMessage spec exactly.
//
// Usage (from BubbleKit):
//   BKComposeView(contacts: myContacts) { recipients, firstMessage in
//       // create conversation and navigate to BKChatView
//   }

import SwiftUI
import Combine

// MARK: - Public entry point

public struct BKComposeView: View {

    // All contacts available to search/pick
    let contacts: [BKContact]

    // Called when user taps Send with at least one recipient
    // → (recipients, optionalFirstMessageText)
    let onSend: ([BKContact], String?) -> Void

    // Called when user taps Cancel
    let onCancel: (() -> Void)?

    @Environment(\.bubbleKitTheme) private var theme
    @Environment(\.dismiss)        private var dismiss

    @StateObject private var vm: BKComposeViewModel

    public init(
        contacts:  [BKContact],
        onSend:    @escaping ([BKContact], String?) -> Void,
        onCancel:  (() -> Void)? = nil
    ) {
        self.contacts  = contacts
        self.onSend    = onSend
        self.onCancel  = onCancel
        _vm = StateObject(wrappedValue: BKComposeViewModel(allContacts: contacts))
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                toField
                Divider()
                suggestionsList
                Spacer()
                inputBar
            }
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel?()
                        dismiss()
                    }
                    .foregroundColor(theme.colors.appleBlue)
                }
            }
        }
        .bubbleKitTheme(theme)
    }

    // MARK: - To: Field

    private var toField: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Text("To:")
                    .font(.system(size: 17))
                    .foregroundColor(theme.colors.appleBlack)
                    .padding(.leading, 16)

                // Selected recipient chips
                ForEach(vm.recipients) { contact in
                    recipientChip(contact)
                }

                // Text input
                TextField("", text: $vm.searchQuery)
                    .font(.system(size: 17))
                    .foregroundColor(theme.colors.appleBlack)
                    .frame(minWidth: 120)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { vm.addFirstSuggestion() }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)
            .frame(minWidth: UIScreen.main.bounds.width - 60)
        }
        .frame(height: 48)
        .overlay(alignment: .trailing) {
            // + button
            Button {
                vm.showContactPicker = true
            } label: {
                ZStack {
                    Circle()
                        .fill(theme.colors.appleBlue)
                        .frame(width: 28, height: 28)
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .padding(.trailing, 14)
        }
        .sheet(isPresented: $vm.showContactPicker) {
            contactPickerSheet
        }
    }

    private func recipientChip(_ contact: BKContact) -> some View {
        HStack(spacing: 4) {
            Text(contact.name)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
            Button {
                vm.remove(contact)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(theme.colors.appleBlue))
    }

    // MARK: - Suggestions List (search results)

    @ViewBuilder
    private var suggestionsList: some View {
        if !vm.searchQuery.isEmpty && !vm.suggestions.isEmpty {
            List(vm.suggestions) { contact in
                Button {
                    vm.add(contact)
                } label: {
                    HStack(spacing: 12) {
                        BKAvatarView(contact: contact, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(contact.name)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(theme.colors.appleBlack)
                            if case .url = contact.avatar {
                                Text("iMessage")
                                    .font(.system(size: 13))
                                    .foregroundColor(theme.colors.appleBlue)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .listRowBackground(theme.colors.background)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            }
            .listStyle(.plain)
            .background(theme.colors.background)
        }
    }

    // MARK: - Contact Picker Sheet

    private var contactPickerSheet: some View {
        NavigationStack {
            List(vm.allContacts) { contact in
                Button {
                    vm.add(contact)
                    vm.showContactPicker = false
                } label: {
                    HStack(spacing: 12) {
                        BKAvatarView(contact: contact, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(contact.name)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(theme.colors.appleBlack)
                        }
                        Spacer()
                        if vm.recipients.contains(where: { $0.id == contact.id }) {
                            Image(systemName: "checkmark")
                                .foregroundColor(theme.colors.appleBlue)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .listRowBackground(theme.colors.background)
            }
            .listStyle(.plain)
            .navigationTitle("Add Recipients")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { vm.showContactPicker = false }
                        .foregroundColor(theme.colors.appleBlue)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Input Bar

    @FocusState private var inputFocused: Bool

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: 10) {

                // + button
                ZStack {
                    Circle()
                        .stroke(theme.colors.lightGrey, lineWidth: 1.5)
                        .frame(width: 34, height: 34)
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.colors.appleBlack)
                }

                // Text field
                ZStack(alignment: .leading) {
                    if vm.messageText.isEmpty {
                        Text("iMessage")
                            .font(.system(size: 16))
                            .foregroundColor(theme.colors.appleGrey)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .allowsHitTesting(false)
                    }
                    TextField("", text: $vm.messageText, axis: .vertical)
                        .font(.system(size: 16))
                        .foregroundColor(theme.colors.appleBlack)
                        .lineLimit(1...5)
                        .focused($inputFocused)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .onSubmit { trySend() }
                }
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(theme.colors.lightGrey, lineWidth: 1)
                )

                // Send / Mic
                if vm.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ZStack {
                        Circle()
                            .stroke(theme.colors.lightGrey, lineWidth: 1.5)
                            .frame(width: 34, height: 34)
                        Image(systemName: "mic")
                            .font(.system(size: 16))
                            .foregroundColor(theme.colors.appleBlack)
                    }
                } else {
                    Button { trySend() } label: {
                        ZStack {
                            Circle()
                                .fill(vm.recipients.isEmpty
                                      ? theme.colors.lightGrey
                                      : theme.colors.appleBlue)
                                .frame(width: 34, height: 34)
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.recipients.isEmpty)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(theme.colors.background)
            .animation(.spring(response: 0.2), value: vm.messageText.isEmpty)
        }
    }

    // MARK: - Helpers

    private func trySend() {
        guard !vm.recipients.isEmpty else { return }
        let text = vm.messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        onSend(vm.recipients, text.isEmpty ? nil : text)
        dismiss()
    }
}

// MARK: - ViewModel

final class BKComposeViewModel: ObservableObject {

    @Published var recipients:        [BKContact] = []
    @Published var searchQuery:       String      = ""
    @Published var messageText:       String      = ""
    @Published var showContactPicker: Bool        = false

    let allContacts: [BKContact]

    var suggestions: [BKContact] {
        guard !searchQuery.isEmpty else { return [] }
        let q = searchQuery.lowercased()
        return allContacts.filter { contact in
            !recipients.contains(where: { $0.id == contact.id }) &&
            contact.name.lowercased().contains(q)
        }
    }

    init(allContacts: [BKContact]) {
        self.allContacts = allContacts
    }

    func add(_ contact: BKContact) {
        guard !recipients.contains(where: { $0.id == contact.id }) else { return }
        recipients.append(contact)
        searchQuery = ""
    }

    func remove(_ contact: BKContact) {
        recipients.removeAll { $0.id == contact.id }
    }

    func addFirstSuggestion() {
        if let first = suggestions.first { add(first) }
    }
}

// MARK: - BubbleKit convenience

public extension BubbleKit {

    /// Present the New Message compose screen.
    /// - Parameters:
    ///   - contacts: The contact list to search from.
    ///   - onSend:   Called with selected recipients + optional first message text.
    ///   - onCancel: Called when the user dismisses without sending.
    static func makeComposeView(
        contacts: [BKContact],
        onSend:   @escaping ([BKContact], String?) -> Void,
        onCancel: (() -> Void)? = nil
    ) -> some View {
        BKComposeView(contacts: contacts, onSend: onSend, onCancel: onCancel)
    }
}
