// BKChatInputView.swift
// NOTE: Input bar is now built inline inside BKChatView.
// This file is kept as a thin public wrapper so existing references don't break.

import SwiftUI

public struct BKChatInputView: View {

    @ObservedObject var viewModel: BKChatViewModel
    @Environment(\.bubbleKitTheme) private var theme
    @FocusState private var focused: Bool

    public var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(alignment: .bottom, spacing: 10) {

                // + Attach
                Button {
                    focused = false
                    viewModel.showPhotoPicker = true
                } label: {
                    ZStack {
                        Circle()
                            .stroke(theme.colors.lightGrey, lineWidth: 1.5)
                            .frame(width: 34, height: 34)
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(theme.colors.appleBlack)
                    }
                }
                .buttonStyle(.plain)

                // Text field
                ZStack(alignment: .leading) {
                    if viewModel.inputText.isEmpty {
                        Text("Send a message")
                            .font(.system(size: 16))
                            .foregroundColor(theme.colors.appleGrey)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .allowsHitTesting(false)
                    }
                    TextField("", text: $viewModel.inputText, axis: .vertical)
                        .font(.system(size: 16))
                        .foregroundColor(theme.colors.appleBlack)
                        .lineLimit(1...5)
                        .focused($focused)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .onSubmit { viewModel.sendMessage() }
                }
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(theme.colors.lightGrey, lineWidth: 1)
                )

                // Send / Mic
                if viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {} label: {
                        ZStack {
                            Circle()
                                .stroke(theme.colors.lightGrey, lineWidth: 1.5)
                                .frame(width: 34, height: 34)
                            Image(systemName: "mic")
                                .font(.system(size: 16))
                                .foregroundColor(theme.colors.appleBlack)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        viewModel.sendMessage()
                        focused = false
                    } label: {
                        ZStack {
                            Circle()
                                .fill(theme.colors.appleBlue)
                                .frame(width: 34, height: 34)
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(theme.colors.background)
            .animation(.spring(response: 0.2), value: viewModel.inputText.isEmpty)
        }
    }
}
