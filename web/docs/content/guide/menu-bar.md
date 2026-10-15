---
sidebar_position: 8
title: Menu Bar
description: Send files and clipboard text from the Mac menu bar, open CrocApp at login, and use the File menu commands on iPad.
---

# Menu bar

## macOS: quick send

CrocApp puts an icon in the Mac menu bar. Click it to open a small window where you can send without opening the main window.

| Control | What it does |
|---|---|
| **Drop files to send** | Drop files or folders on this area to send them |
| **Choose Files…** | Opens a file panel; pick files and folders to send |
| **Send Clipboard Text** | Sends the text on the clipboard. If the clipboard has no text, the window says so |

Dropping works only once the window is open. You cannot drop files onto the menu bar icon itself: click the icon first, then drop.

Once a send starts, the window shows the code, a QR code, **Copy Code**, progress and **Cancel**, the same as the Send screen. Quick send always uses a generated code; to choose your own, use the main window ([Sending files](sending.md)).

The window shares the one active transfer with the main window. It shows a transfer you started there, or from [Shortcuts](shortcuts.md), and it refuses to start a new one while another runs. If a receive needs your answer to the incoming-files prompt, the window tells you to open CrocApp, because the prompt lives in the main window. **Open CrocApp** at the bottom brings the main window forward.

### Settings

Under **Menu bar** in Settings (⌘,), on the General tab:

- **Show in menu bar** is on by default. Turn it off to remove the icon.
- **Open at login** is off by default. Turn it on to start CrocApp when you log in. The switch shows what macOS reports, so it follows a change you make in System Settings > General > Login Items. If macOS needs you to approve CrocApp there, the setting says so and an **Open Settings** button takes you to Login Items.

## iPad: File menu commands

On iPad, the iPadOS 26 menu bar lists the same File commands as the Mac:

| Command | Shortcut |
|---|---|
| **Send…** | ⌘1 |
| **Receive…** | ⌘2 |
| **Show Receive Folder in Files** | ⇧⌘R |

**Show Receive Folder in Files** opens the Files app at your receive folder. On a Mac the same shortcut reveals the folder in Finder. The Files hand-off has not been checked on an iPad yet.

## See also

- [Sending files](sending.md) for the full Send screen.
- [Shortcuts](shortcuts.md) for automating sends and receives.
- [Settings and trust](settings-and-trust.md) for where settings live.
