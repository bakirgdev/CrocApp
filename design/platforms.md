# Platforms

iPhone, iPad, macOS and the two websites run the same tokens and components. This is the short list of what legitimately differs. `swiftui.md` and `web.md` say which API; this says which layout and input model.

Rule of thumb: **density, chrome and input change. Nothing else does.** Navigation structure is chrome: the screens inside it are the same on every device. A screen that needs a different component on macOS was designed wrong on iPhone.

## The column

`--content-max-width` (480px) is the app's content column on every device: the cap on a screen's content. Extra width becomes margin, never wider text. The websites use the web caps instead (`spacing-layout.md` → Web layout).

## Layout by width

The app has two layouts and picks one by width, never by device. Width is the horizontal size class: iPad Slide Over and a narrow Split View are compact, an iPad window wide enough for two columns is regular, and every Mac window is regular (SwiftUI reports macOS as always regular). The layout changes live as a window resizes.

| | Compact | Regular |
|---|---|---|
| Where | iPhone, iPad Slide Over, narrow iPad Split View | iPad at full width and in wide windows, every Mac window |
| Structure | Home, then one `NavigationStack` | `NavigationSplitView`: sidebar and detail |
| Entry | Send and Receive on Home. History, Settings and How It Works in the toolbar | the sidebar rows |
| Settings | pushed from Home | iPad: a sidebar row. Mac: the Settings scene (⌘,), never a row |

**Sidebar.** Rows in this order: Send, Receive, History, and on iPad Settings (glyphs in `iconography.md`). The system's sidebar style, selection and material; we draw nothing on it (`materials.md`). The row of the active transfer's direction shows its state (`components.md` → SidebarRow). How It Works stays a toolbar button on the detail and pushes inside the detail column, as Advanced settings does.

**Columns.** Two, no content column. The sidebar takes the system's default width on iPad, and the system owns how it shows, hides and resizes it on both platforms. On the Mac the default is 144, which cuts "Receive" to an ellipsis beside its Review badge (measured with the real rows), so the Mac sidebar asks for a minimum of 200, an ideal of 240 and a maximum of 320, and the user can still drag it. The detail takes the rest.

**The cap inside the detail.** The detail column fills the window; its content does not. Each detail screen caps its content at `--content-max-width` and centers it, so extra width is margin on both sides and text never lengthens (`spacing-layout.md` → Layout cap). The cap sits on the screen's content, never on the split view, the sidebar or a toolbar. Forms, lists and the transfer screens all take it. A sheet presents as a form sheet at its own width.

**A live request is never lost** (`components.md` → AcceptGate). In regular width the Receive row carries a Review badge, and every detail screen except the gate shows the same info banner at its top, because the sidebar can be hidden. "Except the gate" means the row of the transfer's direction is selected and nothing is pushed over it: a screen pushed on top of the gate carries the banner. The banner's **Review** selects that row and answers nothing. A send that asks both sides to confirm is the same kind of question: the Send row carries the badge, and the banner uses the confirm screen's own words ("The other device is connected").

## Windows and scenes

The app has one main window on Mac and one scene on iPad. The transfer is app-wide and runs one at a time, so a second window could only mirror the first with navigation of its own. The Mac main window is a single-instance `Window` scene and iPad turns multiple scenes off (`UIApplicationSupportsMultipleScenes` NO), so the sidebar selection and the path inside each detail live in the one `AppRouter.shared`. A receive link, a shared file or a drop navigates that window, and only when no transfer is active.

Closing the Mac window leaves CrocApp running: the menu bar item stays and a running transfer finishes. A Dock click, a receive link or **Open CrocApp** in the menu bar window brings the window back.

## iPhone

The baseline every screen is designed at: compact width, touch only, no hover, sheets full height with detents. The only device with haptics (`motion.md`).

## iPad

Regular width gets the sidebar layout, compact width the iPhone layout (above).

- **Menu bar.** `AppCommands` reaches iPad through the hardware-keyboard menu bar, so every menu action has a keyboard-reachable equivalent. The commands are the Mac's (macOS → Menu bar commands), plus **Settings…** (⌘,) in the app menu, because the iPad has no Settings scene.
- **Pointer.** A trackpad gives iPad hover (below) and pointer effects on bare icon buttons. Nothing may require a pointer, because most iPads have none.
- **Sheets** present as form sheets in regular width. Their content does not change.

## macOS

- **Windows.** The main window opens at 880×700, minimum 720×560. The minimum is `--content-max-width` plus 240 for the sidebar at its ideal width (Layout by width → Columns), so the detail never drops under the column at the sidebar's default. The opening width is 240 plus 640, which leaves the 480 column 80 of margin on each side. A window frame saved by an earlier build wins over the opening size, and the minimum clamps it. Settings opens at 480×780, minimum 480×420: it is one form, not a split view.
- **No tab bar and no third column.** The sidebar is the system's: the user can hide it.
- **Settings** is the Settings scene (⌘,), a grouped `Form` (`components.md` → System controls).
- **Menu bar extra.** A 300-wide window for quick sends (`components.md` → MenuBarQuickSend). Its icon and the Dock tile carry the transfer's state (System surfaces).
- **Drop is window-wide**, with the overlay (`components.md` → DropZone).
- **No camera, no QR scan, no local-network prompt.** Absent, not disabled, and no placeholder.
- **Menu bar is a real surface.** Anything the toolbar can do, the menu can do, with a shortcut. Right-click menus are additive shortcuts. The commands are below.

### Menu bar commands

Labels follow `content.md` → Capitalization: Title Case, and an ellipsis only where the command opens something to finish. Every command that moves the user goes through `AppRouter` (`swiftui.md` → Navigation), so it lands in either layout.

| Menu | Command | Shortcut | Enabled | What it does |
|---|---|---|---|---|
| File | **Send…** | ⌘1 | no transfer is active | opens Send |
| File | **Send Clipboard Text…** | ⌥⌘1 | no transfer is active | opens Send with the pasteboard's text in the Text tab. Never starts a send |
| File | **Receive…** | ⌘2 | no transfer is active | opens Receive |
| File | **Paste Code…** | ⌥⌘2 | no transfer is active | opens Receive with the pasteboard's code phrase or link in the code field. Never connects, the same rule as a deep link |
| File | **History** | ⌘3 | always | opens History (the toolbar's clock) |
| File | **Show Receive Folder in Finder** (Files on iPad) | ⇧⌘R | always | opens the receive folder |
| Transfer | **Cancel Transfer** | ⌘. | the phase offers Cancel: starting, waiting, connecting, a send's confirm, transferring. Never at the accept gate (`components.md` → AcceptGate) | cancels the transfer |
| Transfer | **Copy Code** | ⇧⌘C | a send is waiting and shows its code | copies the code phrase |
| Help | **How It Works** | ⌘? | always | pushes How It Works on the screen that is open (the toolbar's lock) |
| App (iPad) | **Settings…** | ⌘, | always | opens Settings. On the Mac the system's own **Settings…** item opens the Settings scene |

The two clipboard commands read the pasteboard when chosen. iOS may ask the user to allow that paste. A command that finds nothing usable still opens its screen, empty. **Clear** in History has no menu item (`docs/known-issues.md`).

## Web

Landing page and docs site: a pointer and a keyboard, both themes following the OS, page-width layout (`web.md`). No haptics, no glass by default.

## System surfaces

What the app puts outside its windows. Copy is `content.md` → System surfaces; settings that switch them off are `content.md` → Settings.

**On any glanceable surface, never:** a code phrase (it is the whole secret), a link (its `#` fragment is the key), the contents of a file or a text, or the code hint of a history record. A glanceable surface is one a bystander can read: a notification, a widget, a control, the Live Activity, the menu bar and the Dock. Styling is the system's: system widget and notification chrome, system text styles, the accent only as a fill or a glyph tint (`colors.md` rule 1), never a gradient, shadow or custom glass.

| Surface | iPhone | iPad | Mac |
|---|---|---|---|
| Notification | yes | yes | yes |
| Home Screen widget, Lock Screen widget | yes | yes | no |
| Control Center control | yes | yes | no |
| Live Activity (the system draws it while a transfer runs in the background: title, file name, progress, Cancel) | yes | yes | no |
| Menu bar icon, Dock tile | no | no | yes |

### Notifications

Local only: nothing is pushed from a server.

- **Two kinds**, each its own setting: an incoming transfer waiting for an answer, and a transfer that finished or failed.
- **Only while the app is not active.** Inside it, the gate and the result are already on screen. A notification is removed when the request is answered or the sender gives up, and when the app becomes active.
- **Interruption level is active.** Never time sensitive, never critical: a transfer can wait, and the calm rule holds on a Lock Screen too. No sound (`motion.md`).
- **Incoming has one action, Review**, a foreground action that opens the accept screen. Tapping the notification does the same. There is no Accept, because the file list must be on screen before a yes, and no Decline, because that answers the other device from a Lock Screen with nothing in view (`components.md` → AcceptGate).
- **Finished has no action.** Tapping it opens the result.
- **A cancel or decline the user made posts nothing**, the same rule as haptics.
- **Permission is asked in context**: the first time the user starts a send or opens a receive. Never at launch, never inside onboarding. When it is denied, the two settings are disabled and say why.
- **Previews hidden.** Each category carries a generic body for when the user hides previews (`content.md` → System surfaces).

### Widgets

Two widgets, system container, system margins, system text styles.

- **Quick Actions** (small; one glyph per action on the Lock Screen). Send and Receive, stacked, each at least `--hit-target-min` tall: the `.fill` direction glyph at `--icon-size-lg` and the word. Each opens its screen and starts nothing.
- **Recent Transfers** (medium; the latest on the Lock Screen, and inline). The Home recent rows (`components.md` → Home): direction glyph, name or count, relative date, up to three on medium. A tap opens that record in History. Only direction, status, display name or count and date cross to the widget. File names are marked private, so the system redacts them while the device is locked.
- **Empty.** With no transfers or with Save Transfer History off, the widget shows its empty line (`content.md` → System surfaces), never a stale row.
- **Accent.** Direction glyphs join the accented group, so tinted and accented Home Screens recolor them. Text stays primary and secondary.

### Control Center control

Two controls the user adds, also placeable on the Lock Screen and the Action button: **Send** (`arrow.up.circle.fill`) and **Receive** (`arrow.down.circle.fill`), each a glyph and one word. Tapping opens the app on that screen with nothing prefilled and nothing started: a control that started a transfer would send or open a receive without a look. No state, no number, no code. Tint is the accent, a fill.

### Menu bar icon (Mac)

The status item is one template glyph, monochrome in the system's menu bar color, with no animation: the menu bar is always on screen, so the state lives in the glyph's shape and its accessibility label, and the tooltip only restates it.

| State | When | Glyph | Beside it |
|---|---|---|---|
| idle | no transfer, or a finished one | `arrow.up.arrow.down.circle` | nothing |
| waiting | starting, waiting, connecting | `arrow.up.arrow.down.circle.fill` | nothing |
| transferring | transferring | `arrow.up.arrow.down.circle.fill` | the integer percent, tabular; nothing when the total is unknown |
| needs attention | a request waits for an answer, or a failure is not yet dismissed | `exclamationmark.circle.fill` | nothing |

The accessibility label is "CrocApp" and the state in words (`content.md` → System surfaces). It never carries a code phrase.

### Dock tile (Mac)

- **Badge.** "1" while a request waits for an answer, cleared when it is answered. Never a file count, never a failure.
- **Progress.** While transferring with a known total, a determinate bar along the icon's lower edge: height `--space-3`, inset `--space-3` from the sides and the bottom, `--radius-capsule`, track `--color-fill`, fill `--color-accent`. It never moves backwards, takes no animation, and goes when the phase leaves transferring. Not verified against icon art on a Dock.

### Received files

On a completed receive the files list below the StatusBlock as `FileRow`s (`components.md` → FileRow). Each row:

- **Quick Look** is its primary action: a tap on iPhone and iPad, Space on a Mac or an iPad with a keyboard. The system previews the file; the app never opens, runs or interprets a received file itself.
- **Share** is a trailing `ShareLink` on every platform (`iconography.md`).
- **Drag out** on iPad and Mac: the row drags as the file itself, a copy, and the received file stays where it is. iPhone has no drag between apps, so none.
- **A folder** has no Quick Look; its primary action is the existing folder button.
- **A text payload** is not a row: it is the selectable text block with Copy Text and Share.

Every action is also in the row's context menu, which is additive (`components.md` → System controls).

## Hover

Hover exists on macOS, iPad with a pointer, and the web. Never on touch.

**Hover applies the element's pressed background and nothing else**: no scale, lift, color or shadow change. On web, wrap hover styles in `@media (hover: hover)` so a tap never leaves one stuck.

1. **Nothing is only discoverable on hover.** Touch and keyboard users get the same affordances at rest.
2. **Hover is not focus.** A hovered element does not take the focus ring.

## What must not diverge

| Never platform-specific |
|---|
| The accept gate. Auto-accept is off by default everywhere and only the user turns it on |
| Direction wording: "Sending" and "Receiving" as words |
| The code phrase format and its mono treatment |
| Contrast rules and the accessibility floor |
| Token values. A platform may pick a different API, never a different number |
