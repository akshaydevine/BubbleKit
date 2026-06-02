// BKPinnedRowView.swift

import SwiftUI

public enum BKPinnedDisplayMode {
    case horizontalScroll
    case grid
}

public struct BKPinnedRowView: View {

    @ObservedObject var viewModel: BKConversationListViewModel
    @Environment(\.bubbleKitTheme) private var theme
    public var displayMode: BKPinnedDisplayMode = .horizontalScroll

    public var body: some View {
        if let custom = viewModel.uiDelegate?.bubbleKitPinnedRowView(entries: viewModel.pinnedEntries) {
            custom
        } else {
            switch displayMode {
            case .horizontalScroll: horizontalScrollRow
            case .grid:             gridRow
            }
        }
    }

    // MARK: - Horizontal Scroll

    private var horizontalScrollRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(viewModel.pinnedEntries) { entry in
                    pinnedCell(entry: entry)
                }
            }
            .padding(.horizontal, theme.layout.horizontalPadding)
            .padding(.vertical, 10)
        }
        .background(theme.colors.pinnedBackground)
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: - Grid

    private let bubbleAreaH: CGFloat = 8  // reserved above row-1 for bubbles
    private let rowSpacing:  CGFloat = 8

    private var gridRow: some View {
        GeometryReader { geo in
            let availableWidth = geo.size.width - (theme.layout.horizontalPadding * 2)
            let cellWidth      = availableWidth / 3
            let entries        = Array(viewModel.pinnedEntries)

            if entries.count <= 9 {
                simpleGrid(entries: entries, cellWidth: cellWidth)
                    .padding(.horizontal, theme.layout.horizontalPadding)
                    .padding(.top, bubbleAreaH)
                    .padding(.bottom, 8)
            } else {
                let pageSize = 9
                let pages = stride(from: 0, to: entries.count, by: pageSize).map {
                    Array(entries[$0 ..< min($0 + pageSize, entries.count)])
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { _, page in
                            simpleGrid(entries: page, cellWidth: cellWidth)
                                .frame(width: availableWidth)
                                .padding(.horizontal, theme.layout.horizontalPadding)
                        }
                    }
                    .padding(.top, bubbleAreaH)
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(height: gridHeight)
        .background(theme.colors.pinnedBackground)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var gridHeight: CGFloat {
        let count   = viewModel.pinnedEntries.count
        let rows    = Int(ceil(Double(min(count, 9)) / 3.0))
        let avatarH = theme.layout.pinnedAvatarDiameter
        // name(13) + dot(8) + spacing(4+4)
        let nameRowH: CGFloat = 25
        let cellH = avatarH + nameRowH
        return bubbleAreaH
             + CGFloat(rows) * cellH
             + CGFloat(max(rows - 1, 0)) * rowSpacing
             + 8
    }

    private func simpleGrid(entries: [BKPinnedEntry], cellWidth: CGFloat) -> some View {
        let rows = Int(ceil(Double(entries.count) / 3.0))
        return VStack(alignment: .leading, spacing: rowSpacing) {
            ForEach(0 ..< rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0 ..< 3, id: \.self) { col in
                        let idx = row * 3 + col
                        if idx < entries.count {
                            pinnedCell(entry: entries[idx])
                                .frame(width: cellWidth)
                        } else {
                            Color.clear.frame(
                                width: cellWidth,
                                height: theme.layout.pinnedAvatarDiameter + 25
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Cell

    @ViewBuilder
    private func pinnedCell(entry: BKPinnedEntry) -> some View {
        if let custom = viewModel.uiDelegate?.bubbleKit(pinnedCellViewFor: entry) {
            custom
        } else {
            defaultPinnedCell(entry: entry)
        }
    }

    private func defaultPinnedCell(entry: BKPinnedEntry) -> some View {
        let diameter = theme.layout.pinnedAvatarDiameter

        return VStack(spacing: 3) {
            // Avatar — layout anchor, no extra height
            ZStack(alignment: .topTrailing) {
                // Plain avatar, NO ring, NO badge
                Group {
                    if let custom = viewModel.uiDelegate?.bubbleKit(avatarViewFor: entry.contact, size: diameter) {
                        custom
                    } else {
                        BKAvatarView(
                            contact:   entry.contact,
                            size:      diameter,
                            showRing:  false,   // no purple ring per Figma
                            ringColor: .clear
                        )
                    }
                }
                // Image thumbnail — shown for .image and .both
                .overlay(alignment: .topTrailing) {
                    if !viewModel.isEditPinsMode, let url = entry.status?.imageURL {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                                .frame(width: 34, height: 34)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(theme.colors.lightGrey)
                                .frame(width: 34, height: 34)
                        }
                        .offset(x: 10, y: 2)
                    }
                }
                // Text bubble — shown for .text and .both
                .overlay(alignment: .top) {
                    if !viewModel.isEditPinsMode, let message = entry.status?.text {
                        textBubble(message: message, diameter: diameter)
                            .alignmentGuide(.top) { d in d[.bottom] }
                    }
                }

                // Edit-pins remove button
                if viewModel.isEditPinsMode {
                    Button {
                        withAnimation(.spring(response: 0.25)) {
                            viewModel.didRemovePin(entry)
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(UIColor.systemGray3))
                                .frame(width: 22, height: 22)
                            Image(systemName: "minus")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .offset(x: 4, y: -4)
                }
            }

            // Name + optional blue dot row
            VStack(spacing: 2) {
                Text(entry.contact.name.replacingOccurrences(of: "• ", with: ""))
                    .font(theme.typography.pinnedName)
                    .foregroundColor(theme.colors.appleBlack)
                    .lineLimit(1)

                // Blue dot instead of purple ring/badge
                if entry.hasUnread && !viewModel.isEditPinsMode {
                    Circle()
                        .fill(theme.colors.messageSentNew)   // Apple blue
                        .frame(width: 7, height: 7)
                }
            }
            .frame(maxWidth: diameter)
        }
        .contentShape(Rectangle())
        .gesture(
            LongPressGesture(minimumDuration: 0.4, maximumDistance: 10)
                .onEnded { _ in
                    guard !viewModel.isEditPinsMode else { return }
                    viewModel.showPinnedContext(for: entry)
                }
        )
        .simultaneousGesture(
            TapGesture().onEnded {
                guard !viewModel.isEditPinsMode else { return }
                viewModel.didTapPinned(entry)
            }
        )
    }

    // MARK: - Text Bubble (above avatar, tail points down)

    private func textBubble(message: String, diameter: CGFloat) -> some View {
        VStack(spacing: 0) {
            Text(message)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(theme.colors.appleBlack)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.colors.popoverBackground)
                        .shadow(
                            color: theme.effects.bubbleShadow.color,
                            radius: theme.effects.bubbleShadow.radius,
                            x: theme.effects.bubbleShadow.x,
                            y: theme.effects.bubbleShadow.y
                        )
                )
                .frame(maxWidth: diameter + 20)

            // Downward tail
            Triangle()
                .fill(theme.colors.popoverBackground)
                .frame(width: 10, height: 6)
        }
    }
}

// MARK: - Triangle tail (points downward)

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Badge (kept for conversation list use)

public struct BKBadgeView: View {
    let count: Int
    @Environment(\.bubbleKitTheme) private var theme

    public var body: some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(theme.typography.badgeCount)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .frame(minWidth: theme.layout.badgeHeight)
            .frame(height: theme.layout.badgeHeight)
            .background(theme.colors.notifyPurple)
            .clipShape(Capsule())
    }
}
