// BKChatView.swift
// Telegram/Stream-style chat screen.
// Fixes:
//  1. Reply banner — compact strip with solid background, no layout blowout
//  2. + button → Telegram-style grid panel (Photos / Camera / File / Location / Audio)
//  3. Mic button — Telegram-style inline recording bar (timer, waveform, slide-to-cancel, lock)
//  4. Nav bar overlap resolved via proper VStack safe-area layout

import SwiftUI
import PhotosUI
import AVFoundation
import CoreLocation
import UniformTypeIdentifiers
import Combine

public struct BKChatView: View {

    @ObservedObject public var viewModel: BKChatViewModel
    @Environment(\.bubbleKitTheme) private var theme

    // Photo picker
    @State private var pickerItems:       [PhotosPickerItem] = []
    @State private var showPhotoPicker:   Bool               = false
    @State private var showCamera:        Bool               = false

    // Document picker
    @State private var showDocPicker:     Bool               = false

    // Attachment bottom panel
    @State private var showAttachPanel:   Bool               = false

    // Contact / Music / Pay sheets
    @State private var showContactPicker: Bool               = false
    @State private var showMusicPicker:   Bool               = false
    @State private var showPaySheet:      Bool               = false

    // Voice recording
    @State private var audioRecorder:     AVAudioRecorder?   = nil
    @State private var recordingURL:      URL?               = nil
    @State private var isRecording:       Bool               = false
    @State private var recordSeconds:     Int                = 0
    @State private var recordTimer:       Timer?             = nil
    @State private var wavePhase:         CGFloat            = 0
    @State private var waveAmplitudes:    [CGFloat]          = Array(repeating: 0.3, count: 30)
    @State private var waveTimer:         Timer?             = nil
    @State private var isRecordingLocked: Bool               = false
    @State private var micDragOffset:     CGFloat            = 0

    // Location
    @StateObject private var locationDelegate = LocationManagerDelegate()
    @State private var isSendingLocation: Bool = false
    @State private var locationError: String?

    // Focus
    @FocusState private var inputFocused: Bool

    private let quickEmojis = ["😂", "👍", "❤️", "👎", "😮", "+"]

    // Full emoji picker — use a simple wrapper so sheet(item:) works reliably
    @State private var emojiPickerTarget: EmojiPickerTarget? = nil

    public init(viewModel: BKChatViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Pinned messages bar
            if viewModel.showPinnedBar, let pinned = viewModel.pinnedMessages.last {
                pinnedBar(pinned)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            messageList
            inputBar
        }
        .animation(.spring(response: 0.3), value: viewModel.showPinnedBar)
        .background(theme.colors.background)
        .toolbarBackground(theme.colors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { chatToolbar }
        .bubbleKitTheme(theme)
        // ── Overlays ──────────────────────────────────────────────────
        .overlay {
            if let msg = viewModel.contextMessage {
                contextOverlay(for: msg)
                    .transition(.opacity)
                    .animation(.spring(response: 0.3, dampingFraction: 0.85), value: viewModel.contextMessage?.id)
            }
        }
        // ── Sheets ────────────────────────────────────────────────────
        .sheet(isPresented: Binding(
            get: { !viewModel.fullscreenImages.isEmpty },
            set: { if !$0 { viewModel.fullscreenImages = []; viewModel.fullscreenURL = nil } }
        )) {
            ImageGalleryView(
                urls:         viewModel.fullscreenImages,
                currentIndex: viewModel.fullscreenIndex
            ) { viewModel.fullscreenImages = []; viewModel.fullscreenURL = nil }
        }
        .sheet(isPresented: $showCamera) {
            CameraPickerView { image in
                guard let img = image,
                      let data = img.jpegData(compressionQuality: 0.85) else { return }
                sendImageData(data)
            }
        }
        .sheet(isPresented: $showDocPicker) {
            DocumentPickerView { urls in
                for url in urls {
                    let msg = BKMessage(
                        sender:      viewModel.currentUser,
                        attachments: [.document(url, filename: url.lastPathComponent)],
                        sentAt:      Date(),
                        isOutgoing:  true,
                        readReceipt: .sent
                    )
                    viewModel.appendMessage(msg)
                }
            }
        }
        // ── Photo picker ──────────────────────────────────────────────
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection:   $pickerItems,
            matching:    .images
        )
        .onChange(of: pickerItems) { items in
            guard !items.isEmpty else { return }
            let group = DispatchGroup()
            var urls: [URL] = Array(repeating: URL(fileURLWithPath: ""), count: items.count)
            for (i, item) in items.enumerated() {
                group.enter()
                item.loadTransferable(type: Data.self) { result in
                    if case .success(let data) = result, let data {
                        let filename = UUID().uuidString + ".jpg"
                        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                        try? data.write(to: url)
                        urls[i] = url
                    }
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                let validURLs = urls.filter { !$0.path.isEmpty && $0.path != "/" }
                guard !validURLs.isEmpty else { return }
                let msg = BKMessage(
                    sender:      viewModel.currentUser,
                    attachments: validURLs.map { .image($0) },
                    sentAt:      Date(),
                    isOutgoing:  true,
                    readReceipt: .sent
                )
                viewModel.appendMessage(msg)
            }
            pickerItems = []
        }
        // ── Contact / Music / Pay sheets ──────────────────────────────
        .sheet(isPresented: $showContactPicker) { contactSheetView() }
        .sheet(isPresented: $showMusicPicker)   { musicPickerView()  }
        .sheet(isPresented: $showPaySheet)      { paySheetView()     }
        // ── Full emoji picker sheet ───────────────────────────────────
        .sheet(item: $emojiPickerTarget) { target in
            EmojiPickerSheet { selectedEmoji in
                withAnimation { viewModel.react(emoji: selectedEmoji, to: target.message) }
                emojiPickerTarget = nil
                viewModel.dismissContext()
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        // ── Attachment panel ──────────────────────────────────────────
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showAttachPanel {
                attachPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.9), value: showAttachPanel)
        // Auto-send location once permission is granted or location arrives
        .onChange(of: locationDelegate.authorizationStatus) { status in
            if isSendingLocation,
               status == .authorizedWhenInUse || status == .authorizedAlways {
                locationDelegate.requestCurrentLocation()
            }
        }
        .onChange(of: locationDelegate.currentLocation) { location in
            guard isSendingLocation, let location else { return }
            sendLocationMessage(location)
        }
    }

    // MARK: - Send image helper

    private func sendImageData(_ data: Data) {
        let filename = UUID().uuidString + ".jpg"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: url)
        DispatchQueue.main.async {
            let msg = BKMessage(
                sender:      viewModel.currentUser,
                attachments: [.image(url)],
                sentAt:      Date(),
                isOutgoing:  true,
                readReceipt: .sent
            )
            viewModel.appendMessage(msg)
        }
    }

    // MARK: - Send location helper

    private func sendCurrentLocation() {
        // Always use the persistent locationDelegate (@StateObject) — never create a
        // temporary CLLocationManager here; it gets deallocated before its delegate
        // callback fires, causing the "must respond to didUpdateLocations" crash.
        switch locationDelegate.authorizationStatus {

        case .notDetermined:
            locationDelegate.requestPermission()
            showLocationPermissionAlert()

        case .authorizedWhenInUse, .authorizedAlways:
            if let location = locationDelegate.currentLocation {
                sendLocationMessage(location)
            } else {
                isSendingLocation = true
                locationDelegate.requestCurrentLocation()
            }

        case .denied, .restricted:
            showLocationDeniedAlert()

        @unknown default:
            break
        }
    }

    // Helper method to show permission request alert
    private func showLocationPermissionAlert() {
        let alert = UIAlertController(
            title: "Location Access Needed",
            message: "Please allow location access to share your current location in the chat.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        presentAlert(alert)
    }

    // Helper method to show location denied alert
    private func showLocationDeniedAlert() {
        let alert = UIAlertController(
            title: "Location Access Denied",
            message: "You've denied location access. Please enable it in Settings to share your location.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        presentAlert(alert)
    }

    // Helper to present alerts from SwiftUI view
    private func presentAlert(_ alert: UIAlertController) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return
        }
        rootVC.present(alert, animated: true)
    }

    // Update sendLocationMessage to handle loading state
    private func sendLocationMessage(_ location: CLLocation) {
        isSendingLocation = false
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        
        // Create Apple Maps URL
        let mapsURLString = "https://maps.apple.com/?q=\(lat),\(lon)"
        guard let mapsURL = URL(string: mapsURLString) else { return }
        
        // Optional: Reverse geocode to get address
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [self] placemarks, error in
            let address = placemarks?.first?.name ?? "📍 Location"
            
            let msg = BKMessage(
                sender: viewModel.currentUser,
                attachments: [.location(mapsURL, latitude: lat, longitude: lon, address: address)],
                sentAt: Date(),
                isOutgoing: true,
                readReceipt: .sent
            )
            DispatchQueue.main.async {
                self.viewModel.appendMessage(msg)
            }
        }
    }

//
//    private func sendLocationMessage(_ location: CLLocation) {
//        let lat = location.coordinate.latitude
//        let lon = location.coordinate.longitude
//        let mapsURL = "https://maps.apple.com/?q=\(lat),\(lon)"
//        let text = "📍 \(mapsURL)"
//
//        let msg = BKMessage(
//            sender: viewModel.currentUser,
//            text: text,
//            sentAt: Date(),
//            isOutgoing: true,
//            readReceipt: .sent
//        )
//        viewModel.appendMessage(msg)
//    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.sections) { section in
                        dateSeparator(section.date).padding(.vertical, 10)
                        ForEach(Array(section.messages.enumerated()), id: \.element.id) { idx, msg in
                            let prev       = idx > 0 ? section.messages[idx - 1].sender.id : nil
                            let showAvatar = prev != msg.sender.id || idx == 0
                            BKMessageBubbleView(
                                message:    msg,
                                showAvatar: showAvatar,
                                viewModel:  viewModel
                            )
                            .padding(.top, showAvatar && idx > 0 ? 10 : 2)
                            .id(msg.id)
                            // WhatsApp-style yellow highlight flash
                            .background(
                                viewModel.highlightedMessageID == msg.id
                                    ? Color.yellow.opacity(0.35)
                                    : Color.clear
                            )
                            .animation(.easeInOut(duration: 0.25), value: viewModel.highlightedMessageID)
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .scrollContentBackground(.hidden)
            .background(theme.colors.background)
            // Dismiss keyboard when user drags the message list
            .scrollDismissesKeyboard(.interactively)
            // Dismiss keyboard when user taps anywhere on the message list
            .onTapGesture {
                inputFocused   = false
                showAttachPanel = false
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            }
            .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 0) }
            .onAppear {
                guard let last = viewModel.sections.last?.messages.last else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
            .onChange(of: viewModel.scrollToID) { id in
                guard let id else { return }
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .bottom) }
            }
            // ── Scroll to latest message when keyboard opens ──────────────
            .onReceive(NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillShowNotification)
            ) { _ in
                guard let last = viewModel.sections.last?.messages.last else { return }
                // Small delay lets the keyboard animation start first so the
                // scroll lands at the true bottom after the layout has shifted.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()

            // Edit mode banner
            if case .editing(let msg) = viewModel.editMode {
                editBanner(msg)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            // Thread reply banner
            else if let thread = viewModel.threadTarget {
                threadBanner(thread)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            // Normal reply banner
            else if let reply = viewModel.replyTarget {
                replyBanner(reply)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.25), value: viewModel.replyTarget != nil)
            }

            if isRecording {
                // ── Telegram-style inline recording bar ──────────────
                recordingBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isRecording)
            } else {
                // ── Normal input row ──────────────────────────────────
                HStack(alignment: .bottom, spacing: 10) {

                    // + Attachment
                    Button {
                        inputFocused = false
                        showAttachPanel.toggle()
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(theme.colors.lightGrey, lineWidth: 1.5)
                                .frame(width: 34, height: 34)
                            Image(systemName: showAttachPanel ? "xmark" : "plus")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(theme.colors.appleBlack)
                                .animation(.spring(response: 0.2), value: showAttachPanel)
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
                            .focused($inputFocused)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .onSubmit { viewModel.sendMessage() }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(theme.colors.lightGrey, lineWidth: 1)
                    )

                    // Send / Mic / Confirm Edit
                    if case .editing = viewModel.editMode {
                        Button {
                            viewModel.commitEdit()
                            inputFocused = false
                        } label: {
                            ZStack {
                                Circle().fill(Color.green).frame(width: 34, height: 34)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                    } else if viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        micButton
                    } else {
                        Button {
                            viewModel.sendMessage()
                            inputFocused = false
                        } label: {
                            ZStack {
                                Circle().fill(theme.colors.appleBlue).frame(width: 34, height: 34)
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

    // MARK: - Telegram-style Recording Bar

    private var recordingBar: some View {
        HStack(spacing: 0) {

            // Delete / cancel (trash)
            Button {
                cancelRecording()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 18))
                    .foregroundColor(.red)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            // Waveform + timer
            HStack(spacing: 10) {
                // Red pulsing dot
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .opacity(isRecording ? 1 : 0)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                        value: isRecording
                    )

                // Timer
                Text(formatRecordingTime(recordSeconds))
                    .font(.system(size: 15, weight: .medium).monospacedDigit())
                    .foregroundColor(theme.colors.appleBlack)
                    .frame(width: 42, alignment: .leading)

                // Animated waveform
                waveformView
                    .frame(height: 28)
            }
            .frame(maxWidth: .infinity)

            // Lock button (when not locked) or locked indicator
            if !isRecordingLocked {
                // Slide up to lock hint
                VStack(spacing: 2) {
                    Image(systemName: "lock")
                        .font(.system(size: 14))
                        .foregroundColor(theme.colors.appleGrey)
                    Image(systemName: "chevron.up")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(theme.colors.appleGrey)
                }
                .frame(width: 36)
                .opacity(0.7)
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 16))
                    .foregroundColor(theme.colors.appleBlue)
                    .frame(width: 36)
            }

            // Send button
            Button {
                stopRecording()
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
            .padding(.trailing, 12)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 10)
        .background(theme.colors.background)
        .onAppear { startWaveAnimation() }
        .onDisappear { stopWaveAnimation() }
    }

    // MARK: - Waveform

    private var waveformView: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<waveAmplitudes.count, id: \.self) { i in
                    Capsule()
                        .fill(Color.red.opacity(0.75))
                        .frame(
                            width: 2.5,
                            height: max(4, waveAmplitudes[i] * geo.size.height)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func startWaveAnimation() {
        waveTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
            withAnimation(.linear(duration: 0.08)) {
                waveAmplitudes = waveAmplitudes.dropFirst() + [CGFloat.random(in: 0.2...1.0)]
            }
        }
    }

    private func stopWaveAnimation() {
        waveTimer?.invalidate()
        waveTimer = nil
    }

    private func formatRecordingTime(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: - Mic Button

    private var micButton: some View {
        Button {
            startRecording()
        } label: {
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
    }

    // MARK: - Recording helpers

    private func startRecording() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            guard granted else { return }
            DispatchQueue.main.async {
                let session = AVAudioSession.sharedInstance()
                try? session.setCategory(.record, mode: .default)
                try? session.setActive(true)

                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + ".m4a")
                let settings: [String: Any] = [
                    AVFormatIDKey:            Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey:          12000,
                    AVNumberOfChannelsKey:    1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                ]
                if let recorder = try? AVAudioRecorder(url: url, settings: settings) {
                    recorder.record()
                    audioRecorder  = recorder
                    recordingURL   = url
                    isRecording    = true
                    recordSeconds  = 0
                    isRecordingLocked = false

                    // Start timer
                    recordTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                        recordSeconds += 1
                    }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
        }
    }

    private func stopRecording() {
        guard isRecording, let recorder = audioRecorder else { return }
        recorder.stop()
        recordTimer?.invalidate()
        recordTimer   = nil
        isRecording   = false
        audioRecorder = nil

        if let url = recordingURL {
            let dur = recordSeconds
            let msg = BKMessage(
                sender:      viewModel.currentUser,
                attachments: [.audio(url, duration: dur)],
                sentAt:      Date(),
                isOutgoing:  true,
                readReceipt: .sent
            )
            viewModel.appendMessage(msg)
            recordingURL = nil
        }
        recordSeconds = 0
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    private func cancelRecording() {
        audioRecorder?.stop()
        recordTimer?.invalidate()
        recordTimer   = nil
        audioRecorder = nil
        recordingURL  = nil
        isRecording   = false
        recordSeconds = 0
        isRecordingLocked = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    // MARK: - Attach Panel (Telegram grid style)

    private var attachPanel: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 14)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 20) {
                attachGridItem(icon: "photo.on.rectangle.angled", label: "Photos", color: Color(hex: "#34C759")) {
                    showAttachPanel = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { showPhotoPicker = true }
                }
                attachGridItem(icon: "camera.fill", label: "Camera", color: Color(hex: "#FF9500")) {
                    showAttachPanel = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { showCamera = true }
                }
                attachGridItem(icon: "doc.fill", label: "File", color: Color(hex: "#007AFF")) {
                    showAttachPanel = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { showDocPicker = true }
                }
                attachGridItem(icon: "location.fill", label: "Location", color: Color(hex: "#FF3B30")) {
                    showAttachPanel = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        sendCurrentLocation()
                    }
                }
//                attachGridItem(icon: "mic.fill", label: "Audio", color: Color(hex: "#AF52DE")) {
//                    showAttachPanel = false
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { startRecording() }
//                }
//                attachGridItem(icon: "person.2.fill", label: "Contact", color: Color(hex: "#5AC8FA")) {
//                    showAttachPanel = false
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { showContactPicker = true }
//                }
//                attachGridItem(icon: "music.note", label: "Music", color: Color(hex: "#FF2D55")) {
//                    showAttachPanel = false
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { showMusicPicker = true }
//                }
//                attachGridItem(icon: "bitcoinsign.circle.fill", label: "Pay", color: Color(hex: "#30B0C7")) {
//                    showAttachPanel = false
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { showPaySheet = true }
//                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color(.systemBackground))
        .overlay(Divider(), alignment: .top)
    }

    private func attachGridItem(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(color)
                        .frame(width: 58, height: 58)
                        .shadow(color: color.opacity(0.35), radius: 6, x: 0, y: 3)
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.colors.appleGrey)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Reply Banner

    private func replyBanner(_ reply: BKMessageReply) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(theme.colors.appleBlue)
                .frame(width: 3, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text("Reply to \(reply.senderName)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.colors.appleBlue)
                    .lineLimit(1)

                Group {
                    if let text = reply.text, !text.isEmpty {
                        Text(text)
                    } else if reply.imageURL != nil {
                        Label("Photo", systemImage: "photo")
                    } else {
                        Text("Message")
                    }
                }
                .font(.system(size: 12))
                .foregroundColor(theme.colors.appleGrey)
                .lineLimit(1)
            }

            Spacer()

            if let url = reply.imageURL {
                AsyncImage(url: url) { p in
                    if case .success(let img) = p {
                        img.resizable().scaledToFill()
                    } else {
                        Color.gray.opacity(0.15)
                    }
                }
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }

            Button { viewModel.cancelReply() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 19))
                    .foregroundColor(theme.colors.appleGrey)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Edit Banner

    private func editBanner(_ message: BKMessage) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "pencil")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(theme.colors.appleBlue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text("Edit Message")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.colors.appleBlue)
                Text(message.text ?? "")
                    .font(.system(size: 12))
                    .foregroundColor(theme.colors.appleGrey)
                    .lineLimit(1)
            }

            Spacer()

            Button { viewModel.cancelEdit() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 19))
                    .foregroundColor(theme.colors.appleGrey)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
    }

    // MARK: - Thread Reply Banner

    private func threadBanner(_ reply: BKMessageReply) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.purple)
                .frame(width: 3, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text("Thread Reply to \(reply.senderName)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.purple)
                    .lineLimit(1)
                Group {
                    if let text = reply.text, !text.isEmpty {
                        Text(text)
                    } else {
                        Label("Photo", systemImage: "photo")
                    }
                }
                .font(.system(size: 12))
                .foregroundColor(theme.colors.appleGrey)
                .lineLimit(1)
            }

            Spacer()

            Button { viewModel.cancelThreadReply() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 19))
                    .foregroundColor(theme.colors.appleGrey)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Pinned Messages Bar

    private func pinnedBar(_ message: BKMessage) -> some View {
        Button {
            // WhatsApp behaviour: tap bar → scroll to message + flash highlight
            viewModel.scrollToAndHighlight(messageID: message.id)
        } label: {
            HStack(spacing: 10) {
                // Blue accent line + pin icon
                VStack(spacing: 2) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9))
                        .foregroundColor(theme.colors.appleBlue)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(theme.colors.appleBlue)
                        .frame(width: 3, height: 24)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Pinned Message")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.colors.appleBlue)
                    Group {
                        if let text = message.text, !text.isEmpty {
                            Text(text)
                        } else if message.attachments.contains(where: { if case .image = $0 { return true }; return false }) {
                            Label("Photo", systemImage: "photo")
                        } else {
                            Text("Message")
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundColor(theme.colors.appleGrey)
                    .lineLimit(1)
                }

                Spacer()

                // "View" hint
                Text("View")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.colors.appleBlue)

                // Unpin button
                Button {
                    withAnimation { viewModel.togglePin(message: message) }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(theme.colors.appleGrey)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .overlay(Divider(), alignment: .bottom)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Context Menu Overlay

    private func contextOverlay(for message: BKMessage) -> some View {
        // Use GeometryReader so we can size things explicitly — no ScrollView
        // sitting over the backdrop (that was the dismiss bug).
        GeometryReader { geo in
            ZStack {
                // ── 1. Dimmed backdrop — full screen, always on top of message list ──
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.25)) { viewModel.dismissContext() }
                    }

                // ── 2. Content column ────────────────────────────────────────────────
                VStack(spacing: 12) {
                    Spacer(minLength: 0)

                    // Quick-emoji pill
                    HStack(spacing: 0) {
                        ForEach(quickEmojis, id: \.self) { emoji in
                            Button {
                                if emoji == "+" {
                                    emojiPickerTarget = EmojiPickerTarget(message: message)
                                } else {
                                    withAnimation { viewModel.react(emoji: emoji, to: message) }
                                }
                            } label: {
                                ZStack {
                                    Text(emoji == "+" ? "" : emoji)
                                        .font(.system(size: 28))
                                    if emoji == "+" {
                                        Image(systemName: "plus")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.primary)
                                    }
                                }
                                .frame(width: 52, height: 52)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(.regularMaterial, in: Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, alignment: message.isOutgoing ? .trailing : .leading)

                    // Message bubble preview (non-interactive)
                    BKMessageBubbleView(
                        message:    message,
                        showAvatar: true,
                        viewModel:  viewModel
                    )
                    .scaleEffect(1.02)
                    .allowsHitTesting(false)

                    // Action menu
                    VStack(spacing: 0) {
                        actionRow(icon: "arrowshape.turn.up.left", label: "Reply", color: .primary) {
                            viewModel.reply(to: message)
                        }
                        Divider().padding(.leading, 52)

                        actionRow(
                            icon:  message.isPinned ? "pin.slash" : "pin",
                            label: message.isPinned ? "Unpin from conversation" : "Pin to conversation",
                            color: .primary
                        ) {
                            viewModel.togglePin(message: message)
                        }
                        Divider().padding(.leading, 52)

                        if message.text != nil && message.isOutgoing {
                            actionRow(icon: "pencil", label: "Edit Message", color: .primary) {
                                viewModel.startEdit(message: message)
                            }
                            Divider().padding(.leading, 52)
                        }

                        actionRow(icon: "trash", label: "Delete Message", color: .red) {
                            viewModel.deleteMessage(message)
                        }
                    }
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 4)
                    .padding(.horizontal, 16)

                    Spacer(minLength: 40)
                }
                // The VStack must NOT fill the whole screen — only its content area
                // is interactive. Taps outside it fall through to the backdrop above.
                .allowsHitTesting(true)
            }
        }
    }

    private func actionRow(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                    .frame(width: 28)
                Text(label)
                    .font(.system(size: 17))
                    .foregroundColor(color)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Date Separator

    private func dateSeparator(_ date: Date) -> some View {
        Text(BKChatViewModel.formattedSectionDate(date))
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(theme.colors.appleGrey)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color(.systemGray6)))
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var chatToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            VStack(spacing: 1) {
                Text(viewModel.chatInfo.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(theme.colors.appleBlack)
                if let sub = viewModel.chatInfo.subtitle {
                    Text(sub)
                        .font(.system(size: 12))
                        .foregroundColor(theme.colors.appleGrey)
                }
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            BKAvatarView(
                contact: BKContact(
                    id: "chat-avatar",
                    name: viewModel.chatInfo.title,
                    avatar: viewModel.chatInfo.avatar
                ),
                size: 34
            )
        }
    }
}

// MARK: - Document Picker

struct DocumentPickerView: UIViewControllerRepresentable {
    var onPick: ([URL]) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.pdf, .plainText, .spreadsheet, .presentation, .zip, .data, .item]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var onPick: ([URL]) -> Void
        init(onPick: @escaping ([URL]) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            DispatchQueue.main.async { self.onPick(urls) }
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
    }
}

// MARK: - Camera Picker

struct CameraPickerView: UIViewControllerRepresentable {
    var onImage: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate   = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var onImage: (UIImage?) -> Void
        init(onImage: @escaping (UIImage?) -> Void) { self.onImage = onImage }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            onImage(info[.originalImage] as? UIImage)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            onImage(nil)
        }
    }
}

// MARK: - Helpers

private struct IdentifiableURL: Identifiable {
    let id  = UUID()
    let url: URL
    init(_ url: URL) { self.url = url }
}

// MARK: - Swipeable Image Gallery Viewer
//
// Fix: TabView steals the horizontal drag gesture from the image, so swiping
// ON the image did nothing. Replaced with a UIPageViewController bridge
// (BKPageViewController) that lets us control gesture priority correctly:
//  • Scale < 1.3 → page swipe wins (UIPageViewController handles it natively)
//  • Scale ≥ 1.3 → pan gesture on image wins, paging is disabled

struct ImageGalleryView: View {
    let urls:         [URL]
    let currentIndex: Int
    let onClose:      () -> Void

    @State private var pageIndex: Int = 0

    var body: some View {
        NavigationView {
            BKPageViewController(
                urls:      urls,
                pageIndex: $pageIndex
            )
            .ignoresSafeArea()
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { onClose() }.foregroundColor(.white)
                }
                ToolbarItem(placement: .principal) {
                    if urls.count > 1 {
                        Text("\(pageIndex + 1) / \(urls.count)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            let url = urls[pageIndex]
                            if let data = try? Data(contentsOf: url),
                               let img  = UIImage(data: data) {
                                let av = UIActivityViewController(activityItems: [img], applicationActivities: nil)
                                UIApplication.shared.connectedScenes
                                    .compactMap { $0 as? UIWindowScene }
                                    .first?.windows.first?
                                    .rootViewController?.present(av, animated: true)
                            }
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up").foregroundColor(.white)
                    }
                }
            }
        }
    }
}

// MARK: - UIPageViewController bridge

/// Wraps UIPageViewController so each page owns its own zoom/pan state
/// and gesture priority is handled correctly at the UIKit level.
struct BKPageViewController: UIViewControllerRepresentable {

    let urls:      [URL]
    @Binding var pageIndex: Int

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pvc = UIPageViewController(
            transitionStyle:  .scroll,
            navigationOrientation: .horizontal
        )
        pvc.view.backgroundColor = .black
        pvc.dataSource = context.coordinator
        pvc.delegate   = context.coordinator

        if let first = context.coordinator.vc(at: pageIndex) {
            pvc.setViewControllers([first], direction: .forward, animated: false)
        }
        return pvc
    }

    func updateUIViewController(_ pvc: UIPageViewController, context: Context) {
        guard let current = pvc.viewControllers?.first as? BKImagePageVC else { return }
        if current.index != pageIndex,
           let target = context.coordinator.vc(at: pageIndex) {
            let dir: UIPageViewController.NavigationDirection = pageIndex > current.index ? .forward : .reverse
            pvc.setViewControllers([target], direction: dir, animated: true)
        }
    }

    // MARK: Coordinator

    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        let parent: BKPageViewController

        init(_ parent: BKPageViewController) { self.parent = parent }

        func vc(at index: Int) -> BKImagePageVC? {
            guard parent.urls.indices.contains(index) else { return nil }
            return BKImagePageVC(url: parent.urls[index], index: index)
        }

        // DataSource
        func pageViewController(_ pvc: UIPageViewController,
                                 viewControllerBefore vc: UIViewController) -> UIViewController? {
            guard let page = vc as? BKImagePageVC else { return nil }
            return self.vc(at: page.index - 1)
        }
        func pageViewController(_ pvc: UIPageViewController,
                                 viewControllerAfter vc: UIViewController) -> UIViewController? {
            guard let page = vc as? BKImagePageVC else { return nil }
            return self.vc(at: page.index + 1)
        }

        // Delegate — sync pageIndex binding after swipe
        func pageViewController(_ pvc: UIPageViewController,
                                 didFinishAnimating finished: Bool,
                                 previousViewControllers: [UIViewController],
                                 transitionCompleted completed: Bool) {
            guard completed,
                  let page = pvc.viewControllers?.first as? BKImagePageVC else { return }
            parent.pageIndex = page.index
        }
    }
}

// MARK: - Per-page VC with independent zoom/pan

final class BKImagePageVC: UIViewController {

    let url:   URL
    let index: Int

    private let scrollView  = UIScrollView()
    private let imageView   = UIImageView()
    private var task:        URLSessionDataTask?

    init(url: URL, index: Int) {
        self.url   = url
        self.index = index
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        // ScrollView handles zoom + pan — no gesture conflicts
        scrollView.delegate                       = self
        scrollView.minimumZoomScale               = 1
        scrollView.maximumZoomScale               = 5
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator   = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.backgroundColor                = .black
        view.addSubview(scrollView)

        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .black
        scrollView.addSubview(imageView)

        // Double-tap to zoom
        let dbl = UITapGestureRecognizer(target: self, action: #selector(doubleTap(_:)))
        dbl.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(dbl)

        loadImage()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = view.bounds
        imageView.frame  = scrollView.bounds
        scrollView.contentSize = imageView.bounds.size
        centerImage()
    }

    // MARK: - Image loading

    private func loadImage() {
        // Try cache first
        if let cached = URLCache.shared.cachedResponse(for: URLRequest(url: url)),
           let img = UIImage(data: cached.data) {
            imageView.image = img; return
        }
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.center = view.center
        indicator.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin,
                                      .flexibleLeftMargin, .flexibleRightMargin]
        view.addSubview(indicator)
        indicator.startAnimating()

        task = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data, let img = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                indicator.removeFromSuperview()
                self.imageView.image = img
            }
        }
        task?.resume()
    }

    // MARK: - Zoom helpers

    private func centerImage() {
        let bw = scrollView.bounds.width
        let bh = scrollView.bounds.height
        let fw = imageView.frame.width
        let fh = imageView.frame.height
        imageView.frame.origin = CGPoint(
            x: max((bw - fw) / 2, 0),
            y: max((bh - fh) / 2, 0)
        )
    }

    @objc private func doubleTap(_ gr: UITapGestureRecognizer) {
        if scrollView.zoomScale > 1 {
            scrollView.setZoomScale(1, animated: true)
        } else {
            let pt = gr.location(in: imageView)
            let rect = CGRect(x: pt.x - 50, y: pt.y - 50, width: 100, height: 100)
            scrollView.zoom(to: rect, animated: true)
        }
    }
}

extension BKImagePageVC: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
    func scrollViewDidZoom(_ scrollView: UIScrollView) { centerImage() }
}

// MARK: - Previews

// MARK: - Emoji Picker Target (Identifiable wrapper for sheet(item:))

struct EmojiPickerTarget: Identifiable {
    let id = UUID()
    let message: BKMessage
}

// MARK: - Emoji Picker Sheet

struct EmojiPickerSheet: View {
    let onSelect: (String) -> Void

    // All emoji categories displayed in a grid
    private let emojiCategories: [(String, [String])] = [
        ("Smileys", ["😀","😃","😄","😁","😆","😅","🤣","😂","🙂","🙃","😉","😊","😇","🥰","😍","🤩","😘","😗","😚","😙","🥲","😋","😛","😜","🤪","😝","🤑","🤗","🤭","🤫","🤔","🤐","🤨","😐","😑","😶","😏","😒","🙄","😬","🤥","😌","😔","😪","🤤","😴","😷","🤒","🤕","🤢","🤮","🤧","🥵","🥶","🥴","😵","🤯","🤠","🥳","🥸","😎","🤓","🧐","😕","😟","🙁","☹️","😮","😯","😲","😳","🥺","😦","😧","😨","😰","😥","😢","😭","😱","😖","😣","😞","😓","😩","😫","🥱","😤","😡","😠","🤬","😈","👿","💀","☠️","💩","🤡","👹","👺","👻","👽","👾","🤖"]),
        ("Gestures", ["👋","🤚","🖐","✋","🖖","👌","🤌","🤏","✌️","🤞","🤟","🤘","🤙","👈","👉","👆","🖕","👇","☝️","👍","👎","✊","👊","🤛","🤜","👏","🙌","👐","🤲","🤝","🙏","✍️","💅","🤳","💪","🦵","🦶","👂","🦻","👃","🧠","🫀","🫁","🦷","🦴","👀","👁","👅","👄","🫦"]),
        ("Hearts & Symbols", ["❤️","🧡","💛","💚","💙","💜","🖤","🤍","🤎","💔","❤️‍🔥","❤️‍🩹","❣️","💕","💞","💓","💗","💖","💘","💝","💟","☮️","✝️","☯️","🕉️","✡️","🔯","🪯","☦️","🛐","⛎","♈","♉","♊","♋","♌","♍","♎","♏","♐","♑","♒","♓","🆔","⚛️","🉑","☢️","☣️","📴","📳","🈶","🈚","🈸","🈺","🈷️","✴️","🆚","💮","🉐","㊙️","㊗️","🈴","🈵","🈹","🈲","🅰️","🅱️","🆎","🆑","🅾️","🆘","⛔","📛","🚫","💯","💢","♨️","🚷","🚯","🚳","🚱","🔞","📵","🔕","🔇","🔈","🔉","🔊","📣","📢","💬","💭","🗯"]),
        ("Animals", ["🐶","🐱","🐭","🐹","🐰","🦊","🐻","🐼","🐻‍❄️","🐨","🐯","🦁","🐮","🐷","🐸","🐵","🙈","🙉","🙊","🐒","🐔","🐧","🐦","🐤","🦆","🦅","🦉","🦇","🐺","🐗","🐴","🦄","🐝","🪱","🐛","🦋","🐌","🐞","🐜","🪲","🦟","🦗","🕷","🦂","🐢","🐍","🦎","🦖","🦕","🐙","🦑","🦐","🦞","🦀","🐡","🐠","🐟","🐬","🐳","🐋","🦈","🦭","🐊","🐅","🐆","🦓","🦍","🦧","🦣","🐘","🦛","🦏","🐪","🐫","🦒","🦘","🦬","🐃","🐂","🐄","🐎","🐖","🐏","🐑","🦙","🐐","🦌","🐕","🐩","🦮","🐕‍🦺","🐈","🐈‍⬛","🪶","🐓","🦃","🦤","🦚","🦜","🦢","🦩","🕊","🐇","🦝","🦨","🦡","🦫","🦦","🦥","🐁","🐀","🐿","🦔"]),
        ("Food", ["🍎","🍐","🍊","🍋","🍌","🍉","🍇","🍓","🫐","🍈","🍒","🍑","🥭","🍍","🥥","🥝","🍅","🍆","🥑","🥦","🥬","🥒","🌶","🫑","🧄","🧅","🥔","🍠","🥐","🥯","🍞","🥖","🥨","🧀","🥚","🍳","🧈","🥞","🧇","🥓","🥩","🍗","🍖","🌭","🍔","🍟","🍕","🫓","🥙","🧆","🌮","🌯","🫔","🥗","🥘","🫕","🥫","🍝","🍜","🍲","🍛","🍣","🍱","🥟","🦪","🍤","🍙","🍚","🍘","🍥","🥮","🍢","🧁","🍰","🎂","🍮","🍭","🍬","🍫","🍿","🍩","🍪","🌰","🥜","🍯","🧃","🥤","🧋","☕","🍵","🧉","🍺","🍻","🥂","🍷","🥃","🍸","🍹","🍾"]),
        ("Activities", ["⚽","🏀","🏈","⚾","🥎","🎾","🏐","🏉","🥏","🎱","🪀","🏓","🏸","🏒","🏑","🥍","🏏","🪃","🥅","⛳","🪁","🏹","🎣","🤿","🥊","🥋","🎽","🛹","🛼","🛷","⛸","🥌","🎿","⛷","🏂","🪂","🏋️","🤼","🤸","⛹️","🤺","🏇","🧘","🏄","🏊","🚴","🏆","🥇","🥈","🥉","🏅","🎖","🏵","🎗","🎫","🎟","🎪","🤹","🎭","🩰","🎨","🎬","🎤","🎧","🎼","🎵","🎶","🎹","🥁","🪘","🎷","🎺","🎸","🪕","🎻","🎲","♟","🎯","🎳","🎮","🎰","🧩"]),
        ("Travel", ["🚗","🚕","🚙","🚌","🚎","🏎","🚓","🚑","🚒","🚐","🛻","🚚","🚛","🚜","🏍","🛵","🛺","🚲","🛴","🛹","🛼","🚏","🛣","🛤","⛽","🚨","🚥","🚦","🛑","🚧","⚓","🛟","⛵","🚤","🛥","🛳","⛴","🚢","✈️","🛩","🛫","🛬","🪂","💺","🚁","🚟","🚠","🚡","🛰","🚀","🛸","🌍","🌎","🌏","🌐","🗺","🧭","🏔","⛰","🌋","🗻","🏕","🏖","🏜","🏝","🏞","🏟","🏛","🏗","🧱","🪨","🪵","🛖","🏘","🏚","🏠","🏡","🏢","🏣","🏤","🏥","🏦","🏨","🏩","🏪","🏫","🏬","🏭","🏯","🏰","💒","🗼","🗽"]),
    ]

    @State private var searchText: String = ""
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 8)

    private var filteredEmojis: [(String, [String])] {
        guard !searchText.isEmpty else { return emojiCategories }
        let q = searchText
        let all = emojiCategories.flatMap(\.1).filter { $0.contains(q) }
        return all.isEmpty ? [] : [("Results", all)]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search emoji", text: $searchText)
                    .font(.system(size: 16))
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Emoji grid
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12, pinnedViews: .sectionHeaders) {
                    ForEach(filteredEmojis, id: \.0) { category, emojis in
                        Section {
                            LazyVGrid(columns: columns, spacing: 4) {
                                ForEach(emojis, id: \.self) { emoji in
                                    Button {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        onSelect(emoji)
                                    } label: {
                                        Text(emoji)
                                            .font(.system(size: 30))
                                            .frame(width: 42, height: 42)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        } header: {
                            Text(category)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 4)
                                .padding(.top, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemBackground))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
    }
}

#Preview("Chat") {
    NavigationView {
        BKChatView(viewModel: BKChatViewModel(
            chatInfo: BKChatSampleData.groupChatInfo,
            currentUser: BKChatSampleData.me,
            messages: BKChatSampleData.messages
        ))
    }
}
// MARK: - Location Manager Delegate

class LocationManagerDelegate: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: String?
    
    private let manager = CLLocationManager()
    
    override init() {
        super.init()
        manager.delegate = self
    }
    
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }
    
    func requestCurrentLocation() {
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .notDetermined:
            requestPermission()
        default:
            locationError = "Location access denied"
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            locationError = "Location access denied"
        default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationError = error.localizedDescription
        print("Location error: \(error)")
    }
}
