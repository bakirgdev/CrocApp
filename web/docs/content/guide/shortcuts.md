---
sidebar_position: 8
title: Shortcuts and Siri
description: Three CrocApp actions for the Shortcuts app, Siri and Spotlight, to send files, send text and receive, and what each one returns.
---

# Shortcuts and Siri

CrocApp adds three actions to the Shortcuts app on iPhone, iPad and Mac. Use them in your own shortcuts, or say or type the phrase in Siri and Spotlight.

| Action | Phrase | Input | Returns |
|---|---|---|---|
| **Send Files with CrocApp** | "Send files with CrocApp" | Files or folders | The code, as text |
| **Send Text with CrocApp** | "Send text with CrocApp" | Text | The code, as text |
| **Receive with CrocApp** | "Receive with CrocApp" | A code or a link | The received files |

The actions also show up in the Shortcuts app as ready-made shortcuts, so you can run them without setting anything up.

## Sending

Both send actions use a generated code. They finish as soon as croc has a code, not when the transfer ends, and show "The code is X. Keep CrocApp open until the transfer ends." Pass the returned code to a Message, a Copy to Clipboard action or anything else that can reach the other device.

**Keep CrocApp open until the other device finishes.** The sender has to stay online for the whole transfer, and closing CrocApp early ends it. For this reason the actions open CrocApp in the foreground: a transfer can last longer than the 30 seconds iOS gives a background action.

## Receiving

**Receive with CrocApp** takes a croc code or any link CrocApp opens: a `crocapp://` link, a `crocapp.dev/r/` link, a `getcroc.com` link, or a [Send as link](send-as-link.md) link. It waits until the transfer ends, then returns the received files and shows "Received 3 items." (or "Received 1 item.")

Received text comes back as a file named `Received text.txt`.

The action does not accept or decline for you. The prompt appears in CrocApp unless **Auto-Accept Transfers** is on in [Settings](settings.md#confirmation). If a received file has the same name as an existing one, the **When a File Already Exists** setting decides (Keep Both or Replace), and the action returns the new copies.

## Find past transfers

**Find Transfers** lists your [History](history.md) in a shortcut: filter by date, direction (sent or received), status or file name, and sort by date. Each result has a name, direction, status, date, file names and size, and opening one opens CrocApp at History. It returns nothing while **Save Transfer History** is off. It never returns a code phrase.

## Send from the Mac Services menu

On a Mac, select files in Finder or text in any app, then choose **Send with CrocApp** from the app menu's **Services** submenu (or the right-click menu). CrocApp comes forward at Send with the selection ready. Nothing is sent until you press Send. Text longer than 1 MiB is refused. If the item is missing, open System Settings > Keyboard > Keyboard Shortcuts > Services and check that it is on.

## One transfer at a time

CrocApp runs one transfer at a time. If one is already running, the action fails with "CrocApp is already sending or receiving. Wait for it to finish."

## See also

- [Send](sending.md) and [Receive](receiving.md) for the same flows in the app.
- [Mac menu bar and keyboard shortcuts](menu-bar.md) for sending from the Mac menu bar.
