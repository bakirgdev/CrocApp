---
sidebar_position: 1
title: Sending files
description: How to send files, folders, and text in CrocApp, including the share extension and the one-active-transfer rule.
---

# Sending files

![The CrocApp Send screen on macOS with three files staged and the Send button ready](/img/screenshots/mac/send-files-light.png#gh-light-mode-only)![The CrocApp Send screen on macOS with three files staged and the Send button ready](/img/screenshots/mac/send-files-dark.png#gh-dark-mode-only)

Open **Send** from the home screen. The **What to Send** picker switches between two modes:

## Files

- **Add Files** opens a file picker; you can select multiple files at once.
- **Add Folder** picks a whole folder to send.
- On macOS, you can also drag files or folders onto the drop area.
- Picked items appear in a list, each removable with its **x** button.

## Text

Type or paste into the text box, or use the **Paste** button to pull the current clipboard contents in directly (an explicit action, never a silent background read).

## Custom code

The **Custom Code** field is optional. Leave it blank for a generated code, or enter your own (minimum 6 characters) so it can be shared through a channel you already trust, for example by dictating it over a call.

## Starting the send

Tap **Send**. CrocApp shows the generated (or custom) code phrase, a **Copy Code** button, a QR code the other device can scan, and a **Share Link** button. The QR code and the link open CrocApp on the other device, or a page at `crocapp.dev/r/` if it does not have the app (see [Code phrases](code-phrases.md#receiving-a-link)). With a custom relay or Local network only, a note on the screen says that receiving in a browser needs the default relays. The screen also shows a trust badge describing which relay path is in use.

## Send as link

Instead of a code, **Send as Link** (files only) sends your files, encrypted on your device, to a link server and gives you a link the other device can open later, with no need to be online at the same time. You choose how long the link lasts and how many downloads it allows. See [Send as link](stored-transfers.md).

## Menu bar and Shortcuts

On a Mac, the [menu bar icon](menu-bar.md) sends files or clipboard text without opening the main window. On any device, [Shortcuts](shortcuts.md) can send files and text for you and hand back the code.

## One active transfer at a time

CrocApp allows exactly one active transfer at a time, matching a limit in the underlying engine. You cannot start a second send or receive while one is in progress; finish or cancel the current transfer first.

## Share extension (iOS only)

On iOS, you can share files into CrocApp from any other app's share sheet. Shared items are staged, and a **Shared Files** sheet appears with **Discard** and **Send** buttons when you next open CrocApp. Choosing **Send** carries the staged files into the normal Send flow.

## Staged files sheet

The staged-files sheet lists every item that was shared in, so you can review what will be sent before committing to it.

## What the sender sees during the transfer

Once the other device connects, CrocApp shows **Ready to send** and waits. If [**Confirm on Both Sides**](power-options.md) is on, you get a prompt reading **The other device is connected**, with **Send** and **Cancel**, before anything moves. During transfer, CrocApp shows per-file and overall progress with speed, plus a **Cancel** button.
