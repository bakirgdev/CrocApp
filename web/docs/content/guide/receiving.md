---
sidebar_position: 2
title: Receiving Files
description: How to receive a transfer in CrocApp, review the incoming file list, and handle conflicts.
---

# Receiving files

![CrocApp on iOS showing an incoming transfer of three files with Decline and Accept buttons](/img/screenshots/ios-receive-light.png#gh-light-mode-only)![CrocApp on iOS showing an incoming transfer of three files with Decline and Accept buttons](/img/screenshots/ios-receive-dark.png#gh-dark-mode-only)

Open **Receive** from the home screen.

## Entering a code (F4)

Type the **Code phrase** into the field, paste it with the **Paste** button, or (iOS only) tap **Scan QR Code** to scan the sender's QR code. The **Receive** button stays disabled until the entered code is at least 6 characters long.

## Choosing where files land (F7)

Below the code field, CrocApp shows the current destination folder. Tap **Change** to pick a different one, or **Reset** to return to the default.

Defaults differ by platform:

- **macOS**: `Downloads/CrocApp`
- **iOS**: the app's Documents folder, which is visible in the Files app

## Accepting or declining (F9)

After you tap **Receive** and connect to the sender, CrocApp shows **Incoming transfer**: the full file list with sizes and a total. From here:

- **Accept** starts the transfer.
- **Decline** refuses it. This is the only way to refuse once you've seen the list — there is no cancel button at this stage.

If the sender has [Confirm on both sides](power-options.md) turned on, the sender must also confirm before the transfer proceeds.

## Overwrite and conflicts (F8)

CrocApp always allows overwriting on receive. If any incoming file already exists at the destination, the accept screen adds a warning: the affected items will be replaced, and any partially-received file resumes rather than restarting. Files with unsafe names (for example, ones trying to escape the destination folder) block **Accept** entirely, as a safety measure on top of croc's own name sanitization.

## Auto-accept (F18)

Auto-accept is **off by default**. When off, you always see the file-list preview above before anything is saved. Turning it on (in [power options](power-options.md)) skips that preview — see that page for the exact warning CrocApp shows when it's enabled.

## After the transfer

When it finishes, CrocApp shows **Transfer complete** (or a message if something went wrong) with a button to open the destination: **Open in Files** on iOS, **Show in Finder** on macOS.
