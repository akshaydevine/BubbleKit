// BKSearchBar.swift

import SwiftUI

struct BKSearchBar: View {

    @Binding var text: String
    @Binding var isSearching: Bool
    @ObservedObject var viewModel: BKConversationListViewModel
    @Environment(\.bubbleKitTheme) private var theme
    @FocusState private var focused: Bool

    @ViewBuilder
    var body: some View {
        // UIDelegate override
        if let custom = viewModel.uiDelegate?.bubbleKitSearchBarView(query: $text) {
            custom
        } else {
            defaultSearchBar
        }
    }

    private var defaultSearchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(theme.colors.appleGrey)
                    .font(.system(size: 15))

                TextField("Search", text: $text)
                    .font(theme.typography.searchPlaceholder)
                    .foregroundColor(theme.colors.appleBlack)
                    .focused($focused)
                    .onChange(of: focused) { f in
                        if f { viewModel.beginSearch() }
                    }

                if !text.isEmpty {
                    Button { text = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(theme.colors.appleGrey)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(theme.colors.searchBackground)
            .cornerRadius(10)

            if isSearching {
                Button("Cancel") {
                    focused = false
                    viewModel.cancelSearch()
                }
                .foregroundColor(theme.colors.appleBlue)
                .font(.system(size: 17))
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSearching)
        .padding(.horizontal, theme.layout.horizontalPadding)
        .padding(.bottom, 8)
    }
}
