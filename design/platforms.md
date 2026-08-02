# Platforms

iPhone, iPad and macOS run the same tokens and the same components. This file is the short list of what legitimately differs. `swiftui.md` says which API to reach for; this says which layout and which input model to design against.

Rule of thumb: **density, chrome and input change. Nothing else does.** A screen that needs a different component on macOS is a screen that was designed wrong on iPhone.

## The column

`--content-max-width` (480px) is the content column on every platform, including macOS and iPad. Extra width becomes margin, never wider text. A 480px column on a 13" display looks deliberate; a 900px settings row does not.

Sheets cap at `--sheet-max-width` (540px).

## iPhone

The baseline every screen is designed at. Compact width, touch only, no hover, no pointer, system sheets full-height with detents.

## iPad

Same layout as iPhone, centred, with the column cap doing the work. Three differences:

- **Menu bar.** `AppCommands` reaches iPad through the hardware-keyboard menu bar, so every File-menu action must have a keyboard-reachable equivalent.
- **Pointer.** A trackpad or a Magic Keyboard gives iPad a pointer, so hover applies (below) and pointer effects are allowed on bare icon buttons.
- **Sheets present as form sheets** in regular width rather than full height. The content inside does not change.

Nothing in the app may require a pointer, because most iPads do not have one.

## macOS

- **Window.** Main window opens at 480×780 and is resizable from its content minimum. Settings opens at 560×700 with a 480×420 floor. No sidebar, no split view, no tab bar: this app has one job and one column.
- **Settings is a `Form`**, `.formStyle(.grouped)`, in the standard Settings scene (⌘,). It is not a screen inside the window.
- **Drop is window-wide.** The whole window is a drop target, with the full-window "Drop to send" overlay (`components.md` → DropZone). The Send list's own drop target wins while the pointer is over it.
- **No camera, no QR scan, no local-network prompt.** Those iOS affordances are absent, not disabled, and no macOS screen shows a placeholder for them.
- **Menu bar is a real surface.** Anything the toolbar can do, the menu can do, with a shortcut.
- **Right-click exists.** Context menus are additive shortcuts, never the only path to an action.

## Hover

Hover exists on macOS, on iPad with a pointer, and on both websites. It never exists on touch.

**Hover applies the element's pressed background, and nothing else.** No scale, no lift, no shadow change, no movement. Pressed is then hover plus `--press-scale`. Transition `--dur-fast` `--ease-standard`.

Two hard rules:

1. **Nothing is only discoverable on hover.** No hover-only buttons, no hover-only labels, no hover-to-reveal remove controls. Touch users and keyboard users get the same affordances at rest.
2. **Hover is not focus.** A hovered element does not take `--shadow-focus-ring`; that belongs to `:focus-visible` alone.

## What must not diverge

| Never platform-specific |
|---|
| The accept gate. Auto-accept stays off on every platform unless the user turns it on |
| Direction wording. "Sending" / "Receiving" as words, everywhere |
| The code phrase format and its mono treatment |
| Contrast rules and the accessibility floor |
| Token values. A platform may pick a different API, never a different number |
