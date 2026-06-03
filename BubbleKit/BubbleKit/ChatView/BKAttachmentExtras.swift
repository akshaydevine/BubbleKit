// BKAttachmentExtras.swift
// Implements the Contact, Music, and Pay attachment flows for BKChatView.
//
// Drop this file into your BubbleKit target alongside BKChatView.swift.
// No other files need to change — BKChatView already calls the three
// show* state booleans defined here via the attachGridItem closures
// (see the patch comment at the bottom of this file for the wiring diff).

import SwiftUI
import Contacts
import ContactsUI
import MediaPlayer

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - 1. Contact Picker
// ─────────────────────────────────────────────────────────────────────────────

/// A native CNContactPickerViewController wrapped in SwiftUI.
/// On selection it sends a `BKMessage` whose text is formatted as a vCard-lite
/// summary and whose attachment is a `.document` pointing to a temp .vcf file.
struct BKContactPickerSheet: View {

    let onSend: (BKMessage) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        BKCNPickerRepresentable { contact in
            let msg = makeContactMessage(from: contact)
            onSend(msg)
            dismiss()
        } onCancel: {
            dismiss()
        }
        .ignoresSafeArea()
    }

    // Build a BKMessage carrying the contact as a .document(.vcf) attachment.
    private func makeContactMessage(from contact: CNContact) -> BKMessage {
        let fullName = CNContactFormatter.string(from: contact, style: .fullName)
                    ?? contact.familyName

        // Write a minimal VCF to a temp file so the bubble can show "Open in…"
        var vcfLines = ["BEGIN:VCARD", "VERSION:3.0"]
        vcfLines.append("FN:\(fullName)")
        for phone in contact.phoneNumbers {
            vcfLines.append("TEL;TYPE=\(phone.label ?? "VOICE"):\(phone.value.stringValue)")
        }
        for email in contact.emailAddresses {
            vcfLines.append("EMAIL:\(email.value)")
        }
        vcfLines.append("END:VCARD")
        let vcfString = vcfLines.joined(separator: "\n")

        let tmpURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".vcf")
        try? vcfString.write(to: tmpURL, atomically: true, encoding: .utf8)

        return BKMessage(
            sender:      BKChatSampleData.me,
            text:        "📇 \(fullName)",
            attachments: [.document(tmpURL, filename: "\(fullName).vcf")],
            sentAt:      Date(),
            isOutgoing:  true,
            readReceipt: .sent
        )
    }
}

/// UIViewControllerRepresentable wrapper for CNContactPickerViewController.
private struct BKCNPickerRepresentable: UIViewControllerRepresentable {

    let onPick:   (CNContact)  -> Void
    let onCancel: ()           -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker           = CNContactPickerViewController()
        picker.delegate      = context.coordinator
        // Ask for the fields we embed in the VCF
        picker.displayedPropertyKeys = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactPhoneNumbersKey,
            CNContactEmailAddressesKey,
            CNContactThumbnailImageDataKey
        ]
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick, onCancel: onCancel) }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onPick:   (CNContact) -> Void
        let onCancel: ()          -> Void

        init(onPick: @escaping (CNContact) -> Void, onCancel: @escaping () -> Void) {
            self.onPick   = onPick
            self.onCancel = onCancel
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onPick(contact)
        }
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            onCancel()
        }
    }
}


// ─────────────────────────────────────────────────────────────────────────────
// MARK: - 2. Music Picker
// ─────────────────────────────────────────────────────────────────────────────

/// Lets the user pick a song from their Apple Music / local library.
/// On iOS the native MPMediaPickerController is used.
/// The selected item is sent as an `.audio` attachment whose URL points to the
/// asset's `assetURL` (available for DRM-free tracks) or a plain text message
/// for protected tracks.
struct BKMusicPickerSheet: View {

    let onSend: (BKMessage) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var authStatus: MPMediaLibraryAuthorizationStatus = MPMediaLibrary.authorizationStatus()
    @State private var showDenied = false

    var body: some View {
        Group {
            switch authStatus {
            case .authorized:
                BKMPPickerRepresentable { item in
                    let msg = makeMusicMessage(from: item)
                    onSend(msg)
                    dismiss()
                } onCancel: {
                    dismiss()
                }
                .ignoresSafeArea()

            case .notDetermined:
                requestView

            default:
                deniedView
            }
        }
        .onAppear {
            authStatus = MPMediaLibrary.authorizationStatus()
        }
    }

    // ── Sub-views ──────────────────────────────────────────────────────────

    private var requestView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "music.note.list")
                .font(.system(size: 52))
                .foregroundColor(.pink)
            Text("Allow access to Music")
                .font(.title3.bold())
            Text("BubbleKit needs access to your music library to share songs.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
            Button("Allow Access") {
                MPMediaLibrary.requestAuthorization { status in
                    DispatchQueue.main.async { authStatus = status }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)
            Button("Cancel", role: .cancel) { dismiss() }
            Spacer()
        }
        .padding()
    }

    private var deniedView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "music.note.list")
                .font(.system(size: 52))
                .foregroundColor(.gray)
            Text("Music Access Denied")
                .font(.title3.bold())
            Text("Please enable Music access in Settings → Privacy → Media & Apple Music.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            Button("Cancel", role: .cancel) { dismiss() }
            Spacer()
        }
        .padding()
    }

    // ── Message builder ────────────────────────────────────────────────────

    private func makeMusicMessage(from item: MPMediaItem) -> BKMessage {
        let title   = item.title   ?? "Unknown Track"
        let artist  = item.artist  ?? "Unknown Artist"
        let durationSec = Int(item.playbackDuration)

        if let assetURL = item.assetURL {
            // DRM-free: embed as an audio attachment
            return BKMessage(
                sender:      BKChatSampleData.me,
                text:        "🎵 \(title) — \(artist)",
                attachments: [.audio(assetURL, duration: durationSec)],
                sentAt:      Date(),
                isOutgoing:  true,
                readReceipt: .sent
            )
        } else {
            // DRM-protected: send as a text-only music card
            return BKMessage(
                sender:      BKChatSampleData.me,
                text:        "🎵 \(title)\n\(artist)",
                sentAt:      Date(),
                isOutgoing:  true,
                readReceipt: .sent
            )
        }
    }
}

/// UIViewControllerRepresentable for MPMediaPickerController.
private struct BKMPPickerRepresentable: UIViewControllerRepresentable {

    let onPick:   (MPMediaItem) -> Void
    let onCancel: ()            -> Void

    func makeUIViewController(context: Context) -> MPMediaPickerController {
        let picker             = MPMediaPickerController(mediaTypes: .music)
        picker.allowsPickingMultipleItems = false
        picker.showsCloudItems            = false
        picker.delegate                   = context.coordinator
        picker.prompt                     = "Share a song"
        return picker
    }

    func updateUIViewController(_ uiViewController: MPMediaPickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick, onCancel: onCancel) }

    final class Coordinator: NSObject, MPMediaPickerControllerDelegate {
        let onPick:   (MPMediaItem) -> Void
        let onCancel: ()            -> Void

        init(onPick: @escaping (MPMediaItem) -> Void, onCancel: @escaping () -> Void) {
            self.onPick   = onPick
            self.onCancel = onCancel
        }

        func mediaPicker(_ mediaPicker: MPMediaPickerController,
                         didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
            guard let item = mediaItemCollection.items.first else { return }
            onPick(item)
        }

        func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
            onCancel()
        }
    }
}


// ─────────────────────────────────────────────────────────────────────────────
// MARK: - 3. Pay Sheet
// ─────────────────────────────────────────────────────────────────────────────

/// An iMessage-Pay–style payment request/send sheet.
/// Keeps all logic local — integrate with your real payment SDK by replacing
/// the `onConfirm` closure implementation in BKChatView.
struct BKPaySheet: View {

    /// Called with (amount, note, isSending) where isSending=true means "Send",
    /// false means "Request".
    let onConfirm: (Decimal, String, Bool) -> Void
    @Environment(\.dismiss) private var dismiss

    // ── State ──────────────────────────────────────────────────────────────
    @State private var amountString: String  = ""
    @State private var note:         String  = ""
    @State private var isSend:       Bool    = true   // true = Send, false = Request
    @FocusState private var amountFocused: Bool

    private var amount: Decimal? {
        guard let d = Decimal(string: amountString), d > 0 else { return nil }
        return d
    }

    private var formattedAmount: String {
        guard let a = amount else { return "₹0" }
        return "₹\(a)"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ── Amount display ───────────────────────────────────────
                VStack(spacing: 8) {
                    Text(amountString.isEmpty ? "₹0" : "₹\(amountString)")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundColor(amountString.isEmpty ? .secondary : .primary)
                        .animation(.spring(response: 0.2), value: amountString)
                        .padding(.top, 32)

                    // Send / Request toggle
                    Picker("", selection: $isSend) {
                        Text("Send").tag(true)
                        Text("Request").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    .padding(.top, 4)
                }
                .padding(.bottom, 28)

                Divider()

                // ── Note field ───────────────────────────────────────────
                HStack {
                    Image(systemName: "text.bubble")
                        .foregroundColor(.secondary)
                    TextField("Add a note (optional)", text: $note)
                        .font(.system(size: 16))
                        .submitLabel(.done)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

                Divider()

                // ── Keypad ───────────────────────────────────────────────
                payKeypad
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                Spacer()

                // ── Confirm button ───────────────────────────────────────
                Button {
                    guard let a = amount else { return }
                    onConfirm(a, note, isSend)
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isSend ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .font(.system(size: 20))
                        Text(isSend ? "Send ₹\(amountString.isEmpty ? "0" : amountString)"
                                    : "Request ₹\(amountString.isEmpty ? "0" : amountString)")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(amount == nil
                                  ? Color(.systemGray4)
                                  : (isSend ? Color(hex: "#30B0C7") : Color.green))
                    )
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
                .disabled(amount == nil)
                .animation(.spring(response: 0.2), value: isSend)
            }
            .background(Color(.systemBackground).ignoresSafeArea())
            .navigationTitle("Apple Pay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // ── Custom keypad ──────────────────────────────────────────────────────

    private let keys: [[String]] = [
        ["1","2","3"],
        ["4","5","6"],
        ["7","8","9"],
        [".","0","⌫"]
    ]

    private var payKeypad: some View {
        VStack(spacing: 12) {
            ForEach(keys, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(row, id: \.self) { key in
                        Button {
                            keyTapped(key)
                        } label: {
                            Text(key)
                                .font(.system(size: 26, weight: .medium, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.systemGray6))
                                )
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func keyTapped(_ key: String) {
        switch key {
        case "⌫":
            if !amountString.isEmpty { amountString.removeLast() }
        case ".":
            // Only one decimal point, and at most 2 decimal places
            guard !amountString.contains(".") else { return }
            amountString += amountString.isEmpty ? "0." : "."
        default:
            // Max 2 decimal places
            if let dotIndex = amountString.firstIndex(of: ".") {
                let decimals = amountString.distance(from: dotIndex, to: amountString.endIndex) - 1
                guard decimals < 2 else { return }
            }
            // Prevent leading zeros
            if amountString == "0" && key != "." { amountString = key; return }
            amountString += key
        }
    }
}


// ─────────────────────────────────────────────────────────────────────────────
// MARK: - BKChatView Extension — wiring three new sheets
// ─────────────────────────────────────────────────────────────────────────────
//
// Add the following properties and modifiers to BKChatView.
// They are declared in an extension so they compile alongside the main struct
// with no changes to BKChatView.swift itself — just drop this file in.
//
// HOWEVER, you must also update the three attachGridItem closures in
// attachPanel (BKChatView.swift lines ~714–722) to flip the booleans:
//
//   attachGridItem(icon: "person.2.fill", label: "Contact", …) {
//       showAttachPanel = false
//       DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
//           showContactPicker = true        // ← ADD THIS
//       }
//   }
//   attachGridItem(icon: "music.note", label: "Music", …) {
//       showAttachPanel = false
//       DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
//           showMusicPicker = true          // ← ADD THIS
//       }
//   }
//   attachGridItem(icon: "bitcoinsign.circle.fill", label: "Pay", …) {
//       showAttachPanel = false
//       DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
//           showPaySheet = true             // ← ADD THIS
//       }
//   }
//
// Also add the three @State vars to BKChatView's main struct body and
// add the .sheet() modifiers to the view body (see BKChatView+Extras below).

extension BKChatView {

    // ── Sheet state (add these @State vars to BKChatView's struct) ──────────
    //
    // @State private var showContactPicker: Bool = false
    // @State private var showMusicPicker:   Bool = false
    // @State private var showPaySheet:      Bool = false
    //
    // (Cannot be declared in an extension on a struct — add to the struct itself.)

    // ── Contact message builder (call from .sheet closure) ─────────────────
    func contactSheetView() -> some View {
        BKContactPickerSheet { msg in
            viewModel.appendMessage(msg)
        }
    }

    // ── Music message builder (call from .sheet closure) ───────────────────
    func musicPickerView() -> some View {
        BKMusicPickerSheet { msg in
            
            viewModel.appendMessage(msg)
        }
    }

    // ── Pay message builder (call from .sheet closure) ─────────────────────
    func paySheetView() -> some View {
        BKPaySheet { amount, note, isSend in
            let emoji  = isSend ? "💸" : "🙏"
            let verb   = isSend ? "Sent" : "Requested"
            let noteStr = note.isEmpty ? "" : "\n\(note)"
            let msg = BKMessage(
                sender:      BKChatSampleData.me,
                text:        "\(emoji) \(verb) ₹\(amount)\(noteStr)",
                sentAt:      Date(),
                isOutgoing:  true,
                readReceipt: .sent
            )
            viewModel.appendMessage(msg)
        }
    }
}


// ─────────────────────────────────────────────────────────────────────────────
// MARK: - BKChatView+Extras  (complete, self-contained modified BKChatView)
// ─────────────────────────────────────────────────────────────────────────────
//
// If you prefer a standalone drop-in rather than patching BKChatView.swift,
// copy the three @State additions and three .sheet() additions shown below
// into BKChatView.swift.
//
// --- Inside `BKChatView` struct body (after existing @State declarations): ---
//
//   @State private var showContactPicker: Bool = false
//   @State private var showMusicPicker:   Bool = false
//   @State private var showPaySheet:      Bool = false
//
// --- Inside `var body: some View { ... }`, after the last .sheet() call: ----
//
//   .sheet(isPresented: $showContactPicker) {
//       contactSheetView()
//   }
//   .sheet(isPresented: $showMusicPicker) {
//       musicPickerView()
//   }
//   .sheet(isPresented: $showPaySheet) {
//       paySheetView()
//   }
//
// --- Inside attachPanel, update the three stubs: ---
//
//   attachGridItem(icon: "person.2.fill", label: "Contact", color: Color(hex: "#5AC8FA")) {
//       showAttachPanel = false
//       DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { showContactPicker = true }
//   }
//   attachGridItem(icon: "music.note", label: "Music", color: Color(hex: "#FF2D55")) {
//       showAttachPanel = false
//       DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { showMusicPicker = true }
//   }
//   attachGridItem(icon: "bitcoinsign.circle.fill", label: "Pay", color: Color(hex: "#30B0C7")) {
//       showAttachPanel = false
//       DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { showPaySheet = true }
//   }
