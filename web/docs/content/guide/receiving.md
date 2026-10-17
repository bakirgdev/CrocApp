---
sidebar_position: 2
title: Receiving files
description: How to receive a transfer in CrocApp, review the file list, and handle conflicts.
---

# Receiving files

![CrocApp on iOS showing a receive of three files with Decline and Accept buttons](/img/screenshots/iphone/receive-incoming-light.png#gh-light-mode-only)![CrocApp on iOS showing a receive of three files with Decline and Accept buttons](/img/screenshots/iphone/receive-incoming-dark.png#gh-dark-mode-only)

Open **Receive** from the home screen.

## Entering a code

Type the **Code Phrase** into the field, paste it with the **Paste** button, or (iOS only) tap **Scan QR Code** to scan the sender's QR code. The **Receive** button stays disabled until the entered code is at least 6 characters long.

You can also paste a link, or open one from outside the app (for example by scanning the QR code with the camera). CrocApp fills in the code and waits: nothing connects until you tap **Receive**. See [Code phrases](code-phrases.md#accepted-forms) for the link forms it accepts, and for receiving in a browser instead.

A link from [Send as link](stored-transfers.md) works the same way: paste it, or scan its QR code on iOS, and the code field is replaced by a **Receive from Link** row naming the link server. Tapping **Receive** then shows the usual file list below, with **Keep Both** and **Replace**; auto-accept does not apply to it.

## Choosing where files land

Below the code field, CrocApp shows the current destination folder. Tap **Change** to pick a different one, or **Reset** to return to the default.

Defaults differ by platform:

- **macOS**: `Downloads/CrocApp`
- **iOS**: the app's Documents folder, which is visible in the Files app

## Accepting or declining

After you tap **Receive** and connect to the sender, CrocApp shows the full file list with sizes and a total. From here:

- **Accept** starts the transfer. It appears alone when nothing at the destination clashes with the files being received, and it then means Keep Both (below).
- **Decline** refuses it. This is the only way to refuse once you have seen the list. There is no cancel button at this stage.

If the sender has [Confirm on both sides](power-options.md) turned on, the sender must also confirm before the transfer proceeds.

If you know the sender's address, you can connect to it directly with **Sender IP** under [Advanced settings](advanced-settings.md#network).

## Overwrite and conflicts

CrocApp never overwrites an existing file unless you say so. If any file being received already exists at the destination, the accept screen shows a banner that says how many items already exist and what each choice does, and replaces **Accept** with two choices, besides **Decline**:

- **Keep Both** (the prominent default) saves the new file under a new name next to the old one: `name (1).ext`, then `name (2).ext`, and so on.
- **Replace** overwrites the existing file. A partly received file resumes where it stopped instead of restarting.

A file that already exists with identical content is left as it is under either choice. Files with unsafe names (for example, ones trying to escape the destination folder) block the accept buttons entirely, as a safety measure on top of croc's own name sanitization.

A folder sent as a zip arrives as a single `.zip` name, so the preview cannot see which of its files already exist. The sheet then offers only **Accept**, which is Keep Both: it silently keeps the existing files and skips the matching ones in the archive. Replace and auto-accept keep them too. To get the sender's copies, move the old folder away before receiving.

## Auto-accept

Auto-accept is **off by default**. When off, you always see the file-list preview above before anything is saved. Turning it on (in [power options](power-options.md)) skips that preview. That page describes the warning CrocApp shows when it is enabled. Because there is no sheet to ask, a setting under it, **When a File Already Exists**, decides between Keep Both (the default) and Replace. Replace overwrites existing files, except inside a zipped folder, where the existing files are kept (see above).

## After the transfer

When it finishes, CrocApp shows **Transfer complete** (or a message if something went wrong) with a button to open the destination: **Open in Files** on iOS, **Show in Finder** on macOS. The File menu also has **Show Receive Folder in Finder** (macOS) and **Show Receive Folder in Files** (iPad), both ⇧⌘R; see [Menu bar](menu-bar.md#ipad-file-menu-commands).

A [Shortcuts](shortcuts.md) action can receive for you with a code or link and return the files.
