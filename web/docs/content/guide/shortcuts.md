---
sidebar_position: 9
title: Shortcuts
description: Three CrocApp actions for the Shortcuts app, Siri and Spotlight, to send files, send text and receive, and what each one returns.
---

# Shortcuts

CrocApp adds three actions to the Shortcuts app on iPhone, iPad and Mac. Use them in your own shortcuts, or say or type the phrase in Siri and Spotlight.

| Action | Phrase | Input | Returns |
|---|---|---|---|
| **Send Files with CrocApp** | "Send files with CrocApp" | Files or folders | The code, as text |
| **Send Text with CrocApp** | "Send text with CrocApp" | Text | The code, as text |
| **Receive with CrocApp** | "Receive with CrocApp" | A code or a link | The received files |

The actions also show up in the Shortcuts app as ready-made shortcuts, so you can run them without setting anything up.

## Sending

Both send actions use a generated code. They finish as soon as croc has a code, not when the transfer ends, and show "The code is X. Keep CrocApp open until the transfer ends." Pass the returned code to a Message, a Copy to Clipboard action or anything else that can reach the receiver.

**Keep CrocApp open until the receiver finishes.** The sender has to stay online for the whole transfer, and closing CrocApp early ends it. For this reason the actions open CrocApp in the foreground: a transfer can last longer than the 30 seconds iOS gives a background action.

## Receiving

**Receive with CrocApp** takes a croc code or any link CrocApp opens: a `crocapp://` link, a `crocapp.dev/r/` link, a `getcroc.com` link, or a [Send as link](stored-transfers.md) link. It waits until the transfer ends, then returns the received files and shows "Received N items."

Received text comes back as a file named `Received text.txt`.

The action does not answer the incoming-files prompt. The prompt appears in CrocApp unless **Auto-accept** is on in [Settings](power-options.md). If a received file has the same name as an existing one, the **When a file already exists** setting decides (Keep Both or Replace), and the action returns the new copies.

## One transfer at a time

CrocApp runs one transfer at a time. If one is already running, the action fails with "CrocApp is already sending or receiving. Wait for it to finish."

## Finder Quick Action

On a Mac, Shortcuts can offer a shortcut as a Quick Action in Finder. A shortcut that uses **Send Files with CrocApp** should work as one, with no extra setup. This has not been checked on a Mac yet.

## See also

- [Sending files](sending.md) and [Receiving files](receiving.md) for the same flows in the app.
- [Menu bar](menu-bar.md) for sending from the Mac menu bar.
