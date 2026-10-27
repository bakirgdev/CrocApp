---
sidebar_position: 7
title: Mac menu bar and keyboard shortcuts
description: Send files and clipboard text from the Mac menu bar, open CrocApp at login, and the keyboard shortcuts on Mac and iPad.
---

# Mac menu bar and keyboard shortcuts

## Quick send from the menu bar

CrocApp puts an icon in the Mac menu bar. Click it to open a small window that sends without opening the main window.

| Control | What it does |
|---|---|
| Drop area | Drop files or folders here to send them |
| **Choose Files…** | Opens a file panel to pick files and folders |
| **Send Clipboard Text** | Sends the text on the clipboard. If there is none, the window says so |
| **Open CrocApp** | Brings the main window forward, or opens it if you closed it |

Click the icon first, then drop. You cannot drop files onto the icon itself.

CrocApp has one main window. Closing it does not quit CrocApp: the menu bar icon stays and a transfer keeps running. Click the Dock icon, open a CrocApp link or choose **Open CrocApp** to bring the window back.

Once a send starts, the window shows the code, a QR code, **Copy Code**, progress and **Cancel**. Quick send always uses a generated code. To choose your own, use the [main window](sending.md#custom-code).

The window shares the one active transfer with the main window, and with [Shortcuts](shortcuts.md). It will not start a second one. If a receive needs you to accept or decline, the window says to open CrocApp, because that prompt lives in the main window.

Turn the icon off with **Show in Menu Bar**, or start CrocApp at login with **Open at Login**, in [Settings](settings.md#receive-and-menu-bar-mac).

## Keyboard shortcuts

These work on Mac and on iPad with a keyboard. The toolbar's History, How It Works and Settings buttons each have a menu item with a shortcut. **Send…**, **Send Clipboard Text…**, **Receive…** and **Paste Code…** are disabled while a transfer is running.

| Command | Shortcut |
|---|---|
| **Send…** (File menu) | ⌘1 |
| **Send Clipboard Text…** (File menu) | ⌥⌘1 |
| **Receive…** (File menu) | ⌘2 |
| **Paste Code…** (File menu) | ⌥⌘2 |
| **History** (File menu) | ⌘3 |
| **Show Receive Folder in Finder** (Mac) or **Show Receive Folder in Files** (iPad) | ⇧⌘R |
| **Cancel Transfer** (Transfer menu), while a transfer can be cancelled | ⌘. |
| **Copy Code** (Transfer menu), while a code is showing | ⇧⌘C |
| **How It Works** (Help menu) | ⌘? |
| **Settings…** (the Settings window on Mac, the app menu on iPad) | ⌘, |

**Send Clipboard Text…** opens **Send** with the text on the clipboard in the **Text** tab. **Paste Code…** opens **Receive** with the code phrase or link on the clipboard in the code field. Neither starts a transfer: you tap **Send** or **Receive**. On iPad, iPadOS may ask you to allow CrocApp to paste the first time.
