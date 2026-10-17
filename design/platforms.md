# Platforms

iPhone, iPad, macOS and the two websites run the same tokens and components. This is the short list of what legitimately differs. `swiftui.md` and `web.md` say which API; this says which layout and input model.

Rule of thumb: **density, chrome and input change. Nothing else does.** A screen that needs a different component on macOS was designed wrong on iPhone.

## The column

`--content-max-width` (480px) is the app's content column on every device. Extra width becomes margin, never wider text. The websites use the web caps instead (`spacing-layout.md` → Web layout).

## iPhone

The baseline every screen is designed at: compact width, touch only, no hover, sheets full height with detents. The only device with haptics (`motion.md`).

## iPad

The iPhone layout, centered, with the column cap doing the work.

- **Menu bar.** `AppCommands` reaches iPad through the hardware-keyboard menu bar, so every menu action has a keyboard-reachable equivalent.
- **Pointer.** A trackpad gives iPad hover (below) and pointer effects on bare icon buttons. Nothing may require a pointer, because most iPads have none.
- **Sheets** present as form sheets in regular width. Their content does not change.

## macOS

- **Windows.** Main window opens at 560×700, minimum 480×560. Settings opens at 480×780, minimum 480×420. No sidebar, split view or tab bar: one job, one column.
- **Settings** is the Settings scene (⌘,), a grouped `Form` (`components.md` → System controls).
- **Menu bar extra.** A 300-wide window for quick sends (`components.md` → MenuBarQuickSend).
- **Drop is window-wide**, with the overlay (`components.md` → DropZone).
- **No camera, no QR scan, no local-network prompt.** Absent, not disabled, and no placeholder.
- **Menu bar is a real surface.** Anything the toolbar can do, the menu can do, with a shortcut. Right-click menus are additive shortcuts.

## Web

Landing page and docs site: a pointer and a keyboard, both themes following the OS, page-width layout (`web.md`). No haptics, no glass by default.

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
