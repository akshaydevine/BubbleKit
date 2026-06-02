# BubbleKit

A plug-and-play SwiftUI conversation list UI kit — pixel-matched to the iOS Messages design. Drop it into any app via Swift Package Manager and get a fully functional chat list with pinned contacts, search, filters, swipe actions, and deep customisation hooks.

---

## Table of Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Conversation List Features](#conversation-list-features)
  - [Search](#search)
  - [Filter Tabs](#filter-tabs)
  - [Swipe Actions](#swipe-actions)
  - [Long-Press Context Menu](#long-press-context-menu)
  - [Edit Menu](#edit-menu)
  - [Select Messages Mode](#select-messages-mode)
- [Pinned Contacts](#pinned-contacts)
  - [Display Modes](#display-modes)
  - [Pin Status Content](#pin-status-content)
  - [Edit Pins Mode](#edit-pins-mode)
- [Theming](#theming)
  - [Built-in Themes](#built-in-themes)
  - [Custom Theme](#custom-theme)
- [Delegate System](#delegate-system)
  - [BKDataSource](#bkdatasource)
  - [BKEventDelegate](#bkeventdelegate)
  - [BKUIDelegate](#bkuidelegate)
- [Models Reference](#models-reference)
- [Sample Data](#sample-data)

---

## Requirements

- iOS 16.0+
- Swift 5.9+
- Xcode 15+

---

## Installation

### Swift Package Manager

1. In Xcode open **File → Add Package Dependencies**
2. Enter the repository URL:
   ```
   https://github.com/your-org/BubbleKit
   ```
3. Select **Up to Next Major Version** starting from `1.0.0`
4. Click **Add Package**

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/your-org/BubbleKit", from: "1.0.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: ["BubbleKit"]
    )
]
```

---

## Quick Start

The fastest way to get a working conversation list — one line:

```swift
import BubbleKit

struct ContentView: View {
    var body: some View {
        BubbleKit.preview          // horizontal scroll pins, sample data
        // BubbleKit.previewGrid   // grid layout pins, sample data
    }
}
```

### Production usage with your own delegate:

```swift
struct ContentView: View {
    @StateObject private var holder = DelegateHolder()

    var body: some View {
        BubbleKit.makeConversationList(
            title:             "Messages",
            theme:             .default,
            pinnedDisplayMode: .grid,
            delegate:          holder.delegate
        )
    }
}
```

`DelegateHolder` wraps your delegate as an `@StateObject` so it lives for the lifetime of the view:

```swift
final class DelegateHolder: ObservableObject {
    let delegate = MyAppDelegate()
}

final class MyAppDelegate: BKFullDelegate {
    // implement BKDataSource + BKEventDelegate + BKUIDelegate
}
```

---

## Conversation List Features

### Search

Built-in search bar appears above the list. Activates on focus and shows a **Cancel** button.

- Default: filters `displayName` and `lastMessage` locally
- Custom: implement `BKDataSource.conversations(matching:)` to run your own search (API, Core Data, etc.)

```swift
func conversations(matching query: String) -> [BKConversation]? {
    // return nil to use built-in local filter
    return myDatabase.search(query)
}
```

### Filter Tabs

Three built-in filter tabs — **All**, **Unread**, **Groups**. Switching fires `BKEventDelegate.bubbleKit(didChangeFilter:)`.

```swift
func bubbleKit(didChangeFilter filter: BKConversationFilter) {
    switch filter {
    case .all:    loadAll()
    case .unread: loadUnread()
    case .groups: loadGroups()
    }
}
```

### Swipe Actions

| Direction | Actions |
|-----------|---------|
| Trailing (left swipe) | **Delete** (red, full-swipe) · **Archive** (grey) |
| Leading (right swipe) | **Pin / Unpin** (blue, full-swipe) |

Swipe actions are automatically hidden when **Select Messages** mode is active.

Handle events via the event delegate:

```swift
func bubbleKit(didHandle event: BKConversationEvent) {
    switch event.kind {
    case .swipeDelete:  removeLocally(event.conversation)
    case .swipeArchive: archive(event.conversation)
    case .swipePin:     togglePin(event.conversation)
    default: break
    }
}
```

### Long-Press Context Menu

Long-pressing any row shows a popover with:
- **Pin / Unpin** — toggles pinned state
- **Delete** — removes from list with animation

Override the entire popover with your own view:

```swift
func bubbleKit(popoverViewFor conversation: BKConversation,
               actions: [BKContextAction]) -> AnyView? {
    AnyView(MyCustomPopover(conversation: conversation, actions: actions))
}
```

### Edit Menu

The **Edit** button in the navigation bar reveals a dropdown with two default actions:

| Action | ID constant |
|--------|-------------|
| Select Messages | `BKEditAction.selectMessagesID` |
| Edit Pins | `BKEditAction.editPinsID` |

Provide your own actions by implementing:

```swift
func editMenuActions() -> [BKEditAction]? {
    [
        BKEditAction(id: BKEditAction.selectMessagesID,
                     title: "Select Messages", icon: "checkmark.circle"),
        BKEditAction(id: BKEditAction.editPinsID,
                     title: "Edit Pins", icon: "pin"),
        BKEditAction(title: "Mark All Read", icon: "envelope.open"),
        BKEditAction(title: "Clear All",     icon: "trash", role: .destructive),
    ]
}
```

Return `nil` to use the SDK defaults. Handle selection:

```swift
func bubbleKit(didSelectEditAction action: BKEditAction) {
    switch action.id {
    case BKEditAction.selectMessagesID: enterMultiSelectMode()
    case BKEditAction.editPinsID:       showPinEditor()
    default: print("Custom action: \(action.title)")
    }
}
```

### Select Messages Mode

Activated from the Edit → Select Messages menu item. In this mode:

- A **checkmark circle** slides in from the left of each row
- Tapping a row toggles its selection (no navigation)
- Swipe actions are disabled
- A bottom toolbar appears with two buttons:

| Button | Behaviour |
|--------|-----------|
| **Select All** | Selects every conversation; label changes to **Deselect All** |
| **Delete** | Deletes all selected conversations; disabled when nothing selected |

- A **Done** button in the navigation bar exits the mode
- The list automatically insets its bottom so the last row is never hidden behind the toolbar

---

## Pinned Contacts

### Display Modes

Pass `pinnedDisplayMode` to `makeConversationList`:

```swift
// Horizontal scroll strip (default — original iOS Messages style)
BubbleKit.makeConversationList(pinnedDisplayMode: .horizontalScroll, delegate: delegate)

// 3-column grid (pages when > 9 pins)
BubbleKit.makeConversationList(pinnedDisplayMode: .grid, delegate: delegate)
```

| Mode | Max visible | Overflow behaviour |
|------|-------------|-------------------|
| `.horizontalScroll` | Unlimited | Scrolls horizontally |
| `.grid` | 9 per page | Paginates horizontally |

### Pin Status Content

Each pinned entry can show a status above its avatar. Three types are supported:

```swift
// Text bubble with tail pointing down
BKPinnedEntry(contact: contact, status: .text("Hi! Running 5 mins late 🏃"))

// Image thumbnail in the top-right corner of the avatar
BKPinnedEntry(contact: contact, status: .image(URL(string: "https://...")!))

// Both text bubble AND image thumbnail shown simultaneously
BKPinnedEntry(contact: contact, status: .both("Just landed! 🛫", URL(string: "https://...")!))

// No status
BKPinnedEntry(contact: contact, status: nil)
```

`BKStatusContent` convenience accessors — useful when rendering custom cells:

```swift
entry.status?.text      // String? — present for .text and .both
entry.status?.imageURL  // URL?    — present for .image and .both
```

### Edit Pins Mode

Activated from Edit → Edit Pins. In this mode each pinned cell shows a **minus (−)** remove button. Status overlays and blue unread dots are hidden while editing. Tap **Done** to exit.

Handle removal:

```swift
func bubbleKit(didHandle event: BKPinnedEvent) {
    switch event.kind {
    case .remove:           pins.removeAll { $0.id == event.entry.id }
    case .add:              pins.append(event.entry)
    case .reorder(let f, let t): pins.move(fromOffsets: [f], toOffset: t)
    default: break
    }
}
```

---

## Theming

### Built-in Themes

```swift
BubbleKit.makeConversationList(theme: .default, delegate: delegate)  // light
BubbleKit.makeConversationList(theme: .dark,    delegate: delegate)  // dark
```

### Custom Theme

All theme tokens are public structs — override only what you need:

```swift
var myColors = BubbleKitColors.default
myColors.notifyPurple   = Color(hex: "#FF2D55")   // red badge
myColors.appleBlue      = Color(hex: "#34C759")   // green accent
myColors.pinnedBackground = Color(hex: "#F9F9F9")

var myLayout = BubbleKitLayout.default
myLayout.avatarDiameter       = 52
myLayout.pinnedAvatarDiameter = 68
myLayout.rowHeight            = 76

var myTypography = BubbleKitTypography.default
myTypography.senderName = .system(size: 16, weight: .bold)

let myTheme = BubbleKitTheme(
    colors:     myColors,
    typography: myTypography,
    effects:    .default,
    layout:     myLayout
)

BubbleKit.makeConversationList(theme: myTheme, delegate: delegate)
```

#### Color tokens

| Token | Default (light) | Default (dark) | Usage |
|-------|----------------|----------------|-------|
| `appleBlack` | `#000000` | `#FFFFFF` | Names, primary text |
| `appleGrey` | `#8E8E93` | `#8E8E93` | Timestamps, previews |
| `appleBlue` | `#007AFF` | `#0A84FF` | Links, accents |
| `notifyPurple` | `#AF52DE` | `#BF5AF2` | Unread badge |
| `messageSentNew` | `#007AFF` | `#0A84FF` | Unread dot |
| `background` | `#FFFFFF` | `#000000` | Screen background |
| `rowBackground` | `#FFFFFF` | `#1C1C1E` | List row background |
| `pinnedBackground` | `#FFFFFF` | `#000000` | Pinned strip background |
| `popoverBackground` | `#FFFFFF` | `#2C2C2E` | Context menu background |
| `searchBackground` | `#F2F2F7` | `#1C1C1E` | Search bar fill |

#### Layout tokens

| Token | Default | Usage |
|-------|---------|-------|
| `avatarDiameter` | `56` | Conversation list avatar size |
| `pinnedAvatarDiameter` | `72` | Pinned strip avatar size |
| `rowHeight` | `80` | Minimum list row height |
| `horizontalPadding` | `16` | Left/right padding for rows and search |
| `storyRingWidth` | `3` | Story ring stroke width |
| `badgeHeight` | `20` | Unread badge height |
| `cornerRadius` | `10` | Popover corner radius |

---

## Delegate System

All three protocols are combined into `BKFullDelegate` for convenience. You can also wire them separately.

```swift
// All-in-one (recommended)
final class MyDelegate: BKFullDelegate { ... }

// Separate (advanced)
BKConversationListView(
    dataSource:    myDataSource,
    eventDelegate: myEventDelegate,
    uiDelegate:    myUIDelegate
)
```

### BKDataSource

Provides data to the SDK.

```swift
public protocol BKDataSource: AnyObject {
    // Required
    func conversations(for filter: BKConversationFilter) -> [BKConversation]

    // Optional — return nil to use SDK defaults
    func conversations(matching query: String) -> [BKConversation]?
    func pinnedEntries() -> [BKPinnedEntry]?
    func contextActions(for conversation: BKConversation) -> [BKContextAction]
    func editMenuActions() -> [BKEditAction]?
}
```

### BKEventDelegate

Receives user interaction events.

```swift
public protocol BKEventDelegate: AnyObject {
    func bubbleKit(didHandle event: BKConversationEvent)   // tap, swipe, long-press
    func bubbleKit(didHandle event: BKPinnedEvent)         // pin tap, add, remove, reorder
    func bubbleKit(didChangeSearchQuery query: String)
    func bubbleKit(didBeginSearch: Bool)
    func bubbleKit(didCancelSearch: Bool)
    func bubbleKit(destinationFor conversation: BKConversation) -> AnyView?
    func bubbleKitDidTapCompose()
    func bubbleKit(didChangeFilter filter: BKConversationFilter)
    func bubbleKitDidTapEdit(isOpen: Bool)
    func bubbleKit(didSelectEditAction action: BKEditAction)
}
```

Provide a navigation destination for conversation tap:

```swift
func bubbleKit(destinationFor conversation: BKConversation) -> AnyView? {
    AnyView(ChatView(conversation: conversation))
}
```

### BKUIDelegate

Swap out any visual component with your own.

```swift
public protocol BKUIDelegate: AnyObject {
    func bubbleKit(rowViewFor conversation: BKConversation) -> AnyView?
    func bubbleKit(avatarViewFor contact: BKContact, size: CGFloat) -> AnyView?
    func bubbleKit(badgeViewFor unreadCount: Int) -> AnyView?
    func bubbleKitPinnedRowView(entries: [BKPinnedEntry]) -> AnyView?
    func bubbleKit(pinnedCellViewFor entry: BKPinnedEntry) -> AnyView?
    func bubbleKit(popoverViewFor conversation: BKConversation,
                   actions: [BKContextAction]) -> AnyView?
    func bubbleKitEmptyStateView(for filter: BKConversationFilter) -> AnyView?
    func bubbleKitEmptySearchView(query: String) -> AnyView?
    func bubbleKitLeadingBarItems() -> AnyView?
    func bubbleKitTrailingBarItems() -> AnyView?
    func bubbleKitSearchBarView(query: Binding<String>) -> AnyView?
}
```

Return `nil` from any method to use the SDK default. Example — custom badge:

```swift
func bubbleKit(badgeViewFor unreadCount: Int) -> AnyView? {
    AnyView(
        Text("\(unreadCount)")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .padding(6)
            .background(Color.red)
            .clipShape(Circle())
    )
}
```

---

## Models Reference

### BKConversation

```swift
BKConversation(
    id:                 "c1",
    participants:       [contact],
    displayName:        "Alice",         // inferred from participants if nil
    lastMessage:        "See you soon!",
    lastMessageTime:    Date(),
    isRead:             false,
    unreadCount:        3,
    isPinned:           false,
    isMuted:            false,
    hasTypingIndicator: false
)
```

### BKContact

```swift
BKContact(
    id:       "alice",
    name:     "Alice",
    avatar:   .url(URL(string: "https://...")!),
    isOnline: true
)
```

Avatar types: `.url(URL)` · `.image(String)` · `.systemSymbol(String)` · `.initials(String, Color, Color)` · `.placeholder`

### BKPinnedEntry

```swift
BKPinnedEntry(
    contact:      contact,
    conversation: conversation,  // optional link back
    hasUnread:    true,
    unreadCount:  2,
    status:       .both("On my way! 🚗", imageURL)
)
```

### BKStatusContent

```swift
.text("Hello! 👋")                          // text bubble above avatar
.image(url)                                 // thumbnail top-right of avatar
.both("Caption", url)                       // text bubble + thumbnail together
```

---

## Sample Data

`BKSampleData` uses a single `Record` table as the source of truth. All three derived arrays (`contacts`, `conversations`, `pinnedEntries`) are computed from it — edit in one place only.

```swift
// Use built-in sample data in your delegate during development
func conversations(for filter: BKConversationFilter) -> [BKConversation] {
    BKSampleData.conversations
}

func pinnedEntries() -> [BKPinnedEntry]? {
    BKSampleData.pinnedEntries
}
```

To add a new person, append one `Record` to the master table:

```swift
// Pinned only (no conversation row)
Record(id: "sara", name: "Sara", avatarURL: "https://...", isOnline: true,
       isPinnedEntry: true, pinnedStatus: .text("Coffee? ☕️"))

// Conversation only (no pinned strip entry)
Record(id: "mike", name: "Mike", avatarURL: "https://...", isOnline: false,
       lastMessage: "See you at 6!", lastMessageTime: -1800, isRead: false)

// Both pinned and in conversation list
Record(id: "jen", name: "Jen", avatarURL: "https://...", isOnline: true,
       lastMessage: "Running late", lastMessageTime: -600,
       isPinnedEntry: true, pinnedStatus: .text("Running late"))
```

---

## License

MIT © 2026 BubbleKit
