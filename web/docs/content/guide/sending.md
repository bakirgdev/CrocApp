---
sidebar_position: 1
title: Sending Files
description: How to send files, folders, and text in CrocApp, including the share extension and the one-active-transfer rule.
---

# Sending files

Open **Send** from the home screen. The **What to send** picker switches between two modes:

## Files (F1, F2)

- **Add Files** opens a file picker; you can select multiple files at once.
- **Add Folder** picks a whole folder to send.
- On macOS, you can also drag files or folders onto the drop area.
- Picked items appear in a list, each removable with its **x** button.

## Text (F3)

Type or paste into the text box, or use the **Paste** button to pull the current clipboard contents in directly (this is an explicit action, not a silent background read).

## Custom code (F5)

The **Custom code** field is optional. Leave it blank for a generated code, or enter your own (minimum 6 characters) so it can be shared through a channel you already trust — for example, dictating it over a call.

## Starting the send

Tap **Send**. CrocApp shows the generated (or custom) code phrase, a **Copy Code** button, and a QR code (F6) the receiver can scan. The screen also shows a trust badge describing which relay path is in use.

## One active transfer at a time

CrocApp allows exactly one active transfer at a time, matching a limit in the underlying engine. You cannot start a second send or receive while one is in progress; finish or cancel the current transfer first.

## Share extension (iOS only, F30)

On iOS, you can share files into CrocApp from any other app's share sheet. Shared items are staged, and a **Shared files** sheet appears with **Discard** and **Send** buttons when you next open CrocApp. Choosing **Send** carries the staged files into the normal Send flow.

## Staged files sheet

The staged-files sheet lists every item that was shared in, so you can review what will be sent before committing to it.

## What the sender sees during the transfer

Once the receiver connects, CrocApp shows **Ready to send** and waits. If [both-sides confirm](power-options.md) is on, you get a **Receiver connected** prompt with **Send** / **Cancel** before anything moves. During transfer, CrocApp shows per-file and overall progress with speed, plus a **Cancel** button.
