// BKMessageBubbleView.swift

import SwiftUI
import QuickLook
import AVFoundation

public struct BKMessageBubbleView: View {

    let message:    BKMessage
    let showAvatar: Bool
    @ObservedObject var viewModel: BKChatViewModel
    @Environment(\.bubbleKitTheme) private var theme

    // QuickLook for documents
    @State private var qlURL:        URL?  = nil
    @State private var showQL:       Bool  = false

    // Audio playback
    @State private var audioPlayer:  AVAudioPlayer? = nil
    @State private var isPlaying:    Bool  = false
    @State private var playProgress: Double = 0
    @State private var playTimer:    Timer? = nil
    @State private var previewURL: URL? = nil
    
    private var bubbleBg: Color {
        message.isOutgoing ? theme.colors.appleBlue : Color(.systemGray6)
    }
    private var bubbleText: Color {
        message.isOutgoing ? .white : theme.colors.appleBlack
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: 8) {

            // Avatar (incoming only)
            if !message.isOutgoing {
                Group {
                    if showAvatar {
                        BKAvatarView(contact: message.sender, size: 32)
                    } else {
                        Color.clear.frame(width: 32)
                    }
                }
            }

            VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: 3) {

                // Sender name
                if !message.isOutgoing && showAvatar {
                    Text(message.sender.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.colors.appleGrey)
                        .padding(.leading, 4)
                }

                // Translated pill
                if message.isTranslated && !message.isDeleted {
                    translatedPill
                }

                // Reactions above bubble
                if !message.reactions.isEmpty {
                    reactionsRow.padding(.bottom, 2)
                }

                // Bubble
                bubbleBody
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 0.35) {
                        guard !message.isDeleted else { return }
                        viewModel.showContext(for: message)
                    }

                // Time + receipt
                timeRow
            }
            .frame(
                maxWidth: UIScreen.main.bounds.width * 0.72,
                alignment: message.isOutgoing ? .trailing : .leading
            )

            if !message.isOutgoing { Spacer(minLength: 0) }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: message.isOutgoing ? .trailing : .leading)
        .quickLookPreview($previewURL)
        .onDisappear {   // ✅ ADD THIS
                audioPlayer?.stop()
                audioPlayer = nil
                playTimer?.invalidate()
                playTimer = nil
                isPlaying = false
                playProgress = 0
            }
    }

    // MARK: - Bubble Body

    @ViewBuilder
    private var bubbleBody: some View {
        if message.isDeleted {
            HStack(spacing: 6) {
                Image(systemName: "nosign")
                    .font(.system(size: 14))
                    .foregroundColor(theme.colors.appleGrey)
                Text("Message deleted")
                    .font(.system(size: 15))
                    .foregroundColor(theme.colors.appleGrey)
                    .italic()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 18))

        } else {
            let hasText     = !(message.text?.isEmpty ?? true)
            let imageAtts   = message.attachments.filter { if case .image = $0 { return true }; return false }
            let docAtts     = message.attachments.filter { if case .document = $0 { return true }; return false }
            let audioAtts   = message.attachments.filter { if case .audio = $0 { return true }; return false }
            let locationAtts = message.attachments.filter { if case .location = $0 { return true }; return false } // NEW
            
            VStack(alignment: .leading, spacing: 0) {

                // Reply quote
                if let reply = message.replyTo {
                    replyQuote(reply)
                }

                // ── Location attachments (NEW) ───────────────────────────
                ForEach(locationAtts) { att in
                    if case .location(let url, let lat, let lon, let address) = att {
                        locationBubble(url: url, latitude: lat, longitude: lon, address: address)
                    }
                }
                
                // ── Document attachments ──────────────────────────────
                ForEach(docAtts) { att in
                    if case .document(let url, let filename) = att {
                        documentBubble(url: url, filename: filename)
                    }
                }

                // ── Audio / voice note ────────────────────────────────
                ForEach(audioAtts) { att in
                    if case .audio(let url, let duration) = att {
                        audioBubble(url: url, duration: duration)
                    }
                }

                // ── Images ────────────────────────────────────────────
                if !imageAtts.isEmpty && !hasText {
                    attachmentGrid(imageAtts)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)

                } else if !imageAtts.isEmpty && hasText {
                    VStack(alignment: .leading, spacing: 0) {
                        attachmentGrid(imageAtts)
                        Text(message.text!)
                            .font(.system(size: 16))
                            .foregroundColor(bubbleText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                    .background(bubbleBg)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                } else if hasText && docAtts.isEmpty && audioAtts.isEmpty {
                    Text(message.text ?? "")
                        .font(.system(size: 16))
                        .foregroundColor(bubbleText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(bubbleBg)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                } else if hasText {
                    // Text below doc/audio
                    Text(message.text ?? "")
                        .font(.system(size: 16))
                        .foregroundColor(bubbleText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                }
            }
            .if(message.replyTo != nil && !(message.text?.isEmpty ?? true)) { v in
                v.background(bubbleBg).clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
    
    @ViewBuilder
    private func locationBubble(url: URL, latitude: Double, longitude: Double, address: String?) -> some View {
        Button {
            // Open Apple Maps
            UIApplication.shared.open(url)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Map Preview
                ZStack(alignment: .bottomLeading) {
                    // Static map preview using Apple Maps snapshot API
                    AsyncImage(url: URL(string: "https://maps.apple.com/maps?q=\(latitude),\(longitude)&z=15&size=300x150")) { phase in
                        switch phase {
                        case .empty:
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 150)
                                .overlay(ProgressView())
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 150)
                                .clipped()
                        case .failure:
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 150)
                                .overlay(
                                    Image(systemName: "map")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Address overlay
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "location.fill")
                                .font(.system(size: 12))
                            Text(address ?? "Location")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Capsule())
                    }
                    .padding(10)
                }
                
                // Bottom row with directions button
                HStack {
                    Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                        .font(.system(size: 14))
                    Text("Open in Maps")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                }
                .foregroundColor(message.isOutgoing ? .white : theme.colors.appleBlue)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    message.isOutgoing ? Color.white.opacity(0.15) : theme.colors.appleBlue.opacity(0.1)
                )
            }
            .background(bubbleBg)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .frame(maxWidth: 280)
        }
        .buttonStyle(.plain)
    }


    // MARK: - Document Bubble

    private func documentBubble(url: URL, filename: String) -> some View {
        let ext  = (filename as NSString).pathExtension.uppercased()
        let icon = iconForExtension(ext)
        let col  = colorForExtension(ext)

        return Button {
            previewURL = url
//            qlURL  = url
//            showQL = true
        } label: {
            HStack(spacing: 10) {
                // File icon badge
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(col.opacity(0.15))
                        .frame(width: 46, height: 46)
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(col)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(filename)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(message.isOutgoing ? .white : theme.colors.appleBlack)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(ext.isEmpty ? "File" : "\(ext) Document")
                        .font(.system(size: 11))
                        .foregroundColor(message.isOutgoing ? .white.opacity(0.7) : theme.colors.appleGrey)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(message.isOutgoing ? .white.opacity(0.8) : theme.colors.appleBlue)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(bubbleBg)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .frame(maxWidth: 280)
        }
        .buttonStyle(.plain)
    }

    private func iconForExtension(_ ext: String) -> String {
        switch ext {
        case "PDF":                         return "doc.richtext.fill"
        case "DOC", "DOCX":                return "doc.fill"
        case "XLS", "XLSX":                return "tablecells.fill"
        case "PPT", "PPTX":                return "rectangle.stack.fill"
        case "ZIP", "RAR", "7Z":           return "archivebox.fill"
        case "MP3", "M4A", "WAV", "AAC":   return "music.note"
        case "MP4", "MOV", "AVI":          return "film.fill"
        default:                            return "doc.fill"
        }
    }

    private func colorForExtension(_ ext: String) -> Color {
        switch ext {
        case "PDF":                 return .red
        case "DOC", "DOCX":        return Color(hex: "#2B5CE6")
        case "XLS", "XLSX":        return Color(hex: "#217346")
        case "PPT", "PPTX":        return Color(hex: "#D24726")
        case "ZIP", "RAR", "7Z":   return Color(hex: "#FF9500")
        default:                    return Color(hex: "#007AFF")
        }
    }

    // MARK: - Audio / Voice Note Bubble

    private func audioBubble(url: URL, duration: Int) -> some View {
        HStack(spacing: 10) {
            // Play/pause button
            Button {
                togglePlayback(url: url, totalDuration: duration)
            } label: {
                ZStack {
                    Circle()
                        .fill(message.isOutgoing ? Color.white.opacity(0.25) : theme.colors.appleBlue.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16))
                        .foregroundColor(message.isOutgoing ? .white : theme.colors.appleBlue)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 5) {
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(message.isOutgoing ? Color.white.opacity(0.3) : Color(.systemGray4))
                            .frame(height: 3)
                        Capsule()
                            .fill(message.isOutgoing ? Color.white : theme.colors.appleBlue)
                            .frame(width: geo.size.width * playProgress, height: 3)
                    }
                }
                .frame(height: 3)

                // Duration
                Text(isPlaying
                     ? formatAudioTime(Int(Double(duration) * playProgress))
                     : formatAudioTime(duration))
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundColor(message.isOutgoing ? .white.opacity(0.8) : theme.colors.appleGrey)
            }

            // Mic icon
            Image(systemName: "waveform")
                .font(.system(size: 16))
                .foregroundColor(message.isOutgoing ? .white.opacity(0.7) : theme.colors.appleGrey)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(bubbleBg)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .frame(maxWidth: 260)
    }

    private func togglePlayback(url: URL, totalDuration: Int) {
        if isPlaying {
            audioPlayer?.pause()
            playTimer?.invalidate()
            playTimer = nil
            isPlaying = false
        } else {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
                let player = try AVAudioPlayer(contentsOf: url)
                player.play()
                audioPlayer = player
                isPlaying   = true
                let total   = player.duration > 0 ? player.duration : Double(max(totalDuration, 1))
                playTimer   = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { t in
                    if let p = audioPlayer, p.isPlaying {
                        playProgress = p.currentTime / total
                    } else {
                        t.invalidate()
                        playTimer    = nil
                        isPlaying    = false
                        playProgress = 0
                    }
                }
            } catch {
                print("Audio playback error: \(error)")
            }
        }
    }

    private func formatAudioTime(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: - Reply Quote

    private func replyQuote(_ reply: BKMessageReply) -> some View {
        Button {
            // Scroll to the original message and flash-highlight it
            viewModel.scrollToAndHighlight(messageID: reply.id)
        } label: {
            HStack(alignment: .center, spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(message.isOutgoing ? Color.white.opacity(0.8) : theme.colors.appleBlue)
                    .frame(width: 3, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(reply.senderName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(message.isOutgoing ? .white : theme.colors.appleBlue)
                        .lineLimit(1)

                    if let text = reply.text, !text.isEmpty {
                        Text(text)
                            .font(.system(size: 12))
                            .foregroundColor(message.isOutgoing ? .white.opacity(0.8) : theme.colors.appleGrey)
                            .lineLimit(1)
                    } else if reply.imageURL != nil {
                        Label("Photo", systemImage: "photo")
                            .font(.system(size: 12))
                            .foregroundColor(message.isOutgoing ? .white.opacity(0.7) : theme.colors.appleGrey)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let url = reply.imageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFill()
                        case .failure:          Image(systemName: "photo").foregroundColor(.gray)
                        default:               Color.gray.opacity(0.2)
                        }
                    }
                    .frame(width: 36, height: 36)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .fixedSize()
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(message.isOutgoing ? Color.white.opacity(0.15) : theme.colors.appleBlue.opacity(0.08))
            .cornerRadius(10)
            .padding(.horizontal, 4)
            .padding(.top, 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Attachment Grid (images only)

    @ViewBuilder
    private func attachmentGrid(_ items: [BKAttachment]) -> some View {
        switch items.count {
        case 1:
            imageCell(items[0]).frame(maxWidth: 280).frame(height: 220)
        case 2:
            VStack(spacing: 2) {
                imageCell(items[0]).frame(height: 160)
                imageCell(items[1]).frame(height: 160)
            }.frame(maxWidth: 280)
        case 3:
            HStack(spacing: 2) {
                imageCell(items[0]).frame(width: 186, height: 250)
                VStack(spacing: 2) {
                    imageCell(items[1]).frame(height: 124)
                    imageCell(items[2]).frame(height: 124)
                }
            }.frame(maxWidth: 280)
        default:
            let visible = Array(items.prefix(4))
            let extra   = items.count - 4
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    imageCell(visible[0]).frame(height: 138)
                    imageCell(visible[1]).frame(height: 138)
                }
                HStack(spacing: 2) {
                    imageCell(visible[2]).frame(height: 138)
                    ZStack {
                        imageCell(visible[3])
                        if extra > 0 {
                            Color.black.opacity(0.45)
                            Text("+\(extra)")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }.frame(height: 138)
                }
            }.frame(maxWidth: 280)
        }
    }

    private func imageCell(_ att: BKAttachment) -> some View {
        let allURLs = message.attachments.compactMap(\.imageURL)
        let idx     = allURLs.firstIndex(of: att.imageURL ?? URL(fileURLWithPath: "")) ?? 0
        return Group {
            if let url = att.imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default:               Rectangle().fill(theme.colors.lightGrey)
                    }
                }
            } else {
                Rectangle().fill(theme.colors.lightGrey)
            }
        }
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture { viewModel.openImages(allURLs, startIndex: idx) }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Translated Pill

    private var translatedPill: some View {
        Button { viewModel.toggleTranslation(for: message) } label: {
            HStack(spacing: 4) {
                Image(systemName: "character.bubble").font(.system(size: 11))
                Text("Translated · Show Original").font(.system(size: 12))
            }
            .foregroundColor(theme.colors.appleBlue)
        }
        .buttonStyle(.plain)
        .padding(.leading, 4)
    }

    // MARK: - Reactions

    private var reactionsRow: some View {
        HStack(spacing: 4) {
            ForEach(message.reactions) { r in
                Button { viewModel.react(emoji: r.emoji, to: message) } label: {
                    HStack(spacing: 3) {
                        Text(r.emoji).font(.system(size: 15))
                        if r.count > 1 {
                            Text("\(r.count)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(theme.colors.appleGrey)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(
                        r.byMe ? theme.colors.appleBlue.opacity(0.15) : Color(.systemGray6)
                    ))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, message.isOutgoing ? 0 : 4)
    }

    // MARK: - Time Row

    private var timeRow: some View {
        HStack(spacing: 3) {
            Text(BKChatViewModel.formattedTime(message.sentAt))
                .font(.system(size: 11))
                .foregroundColor(theme.colors.appleGrey)
            if message.isOutgoing { readReceiptIcon }
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var readReceiptIcon: some View {
        switch message.readReceipt {
        case .sent:
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(theme.colors.appleGrey)
        case .delivered:
            doubleCheck(color: theme.colors.appleGrey)
        case .read:
            doubleCheck(color: theme.colors.appleBlue)
        }
    }

    private func doubleCheck(color: Color) -> some View {
        HStack(spacing: -4) {
            Image(systemName: "checkmark").font(.system(size: 10, weight: .semibold))
            Image(systemName: "checkmark").font(.system(size: 10, weight: .semibold))
        }
        .foregroundColor(color)
    }
}

// MARK: - QuickLook wrapper

// Replace your current QuickLookView and QLPreviewControllerWrapper with this:

struct QuickLookView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let previewController = QLPreviewController()
        previewController.dataSource = context.coordinator
        previewController.delegate = context.coordinator
        
        let navigationController = UINavigationController(rootViewController: previewController)
        navigationController.navigationBar.prefersLargeTitles = false
        navigationController.navigationBar.tintColor = .systemBlue
        
        // Add a done button
        previewController.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: context.coordinator,
            action: #selector(Coordinator.dismiss)
        )
        
        return navigationController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(url: url, parent: self)
    }
    
    class Coordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
        let url: URL
        let parent: QuickLookView
        
        init(url: URL, parent: QuickLookView) {
            self.url = url
            self.parent = parent
            super.init()
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return url as QLPreviewItem
        }
        
        @objc func dismiss() {
            if let navigationController = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first?.windows.first?.rootViewController?.presentedViewController as? UINavigationController {
                navigationController.dismiss(animated: true)
            }
        }
        
        func previewControllerWillDismiss(_ controller: QLPreviewController) {
            // Clean up if needed
        }
    }
}

final class QLPreviewControllerWrapper: UIViewController, QLPreviewControllerDataSource {
    let url: URL
    init(url: URL) { self.url = url; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let ql = QLPreviewController()
        ql.dataSource = self
        present(ql, animated: true)
    }

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        url as QLPreviewItem
    }
}

// MARK: - View+if helper

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}

// MARK: - Location Bubble
