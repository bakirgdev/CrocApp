---
sidebar_position: 2
title: Your First Transfer
description: A walkthrough of one send and one receive in CrocApp, using the app's actual on-screen labels.
---

# Your first transfer

![CrocApp on macOS showing Ready to send with the code phrase, a Copy Code button, and a QR code](/img/screenshots/mac-send-light.png#gh-light-mode-only)![CrocApp on macOS showing Ready to send with the code phrase, a Copy Code button, and a QR code](/img/screenshots/mac-send-dark.png#gh-dark-mode-only)

CrocApp's home screen has two buttons: **Send** and **Receive**. Everything else follows from a three-step flow:

1. The sender picks files, a folder, or a snippet of text.
2. CrocApp generates a code phrase. Speak it, message it, or show it as a QR code.
3. The receiver enters the phrase, sees the file list, and accepts.

Both sides run PAKE over the code phrase to derive a session key, so the phrase never crosses the network in the clear and the relay never learns it. Files are encrypted with the code phrase; the relay only ever sees ciphertext. Same Wi-Fi or different continents, CrocApp finds the fastest path automatically.

## Sending

1. From the home screen, tap or click **Send**.
2. Under **What to send**, pick **Files** or **Text**.
   - For files: use **Add Files** or **Add Folder**, or drag files onto the drop area (macOS).
   - For text: type or paste into the text box.
3. Optionally set a **Custom code** (at least 6 characters) instead of a generated one.
4. Tap **Send**.
5. CrocApp shows **Ready to send** with the code phrase, a **Copy Code** button, and a QR code. Share the code with the receiver over a channel you trust.
6. Once the receiver connects and accepts, the transfer starts. When it finishes, CrocApp shows **Transfer complete**.

## Receiving

1. From the home screen, tap or click **Receive**.
2. Enter the **Code phrase** the sender gave you, paste it, or (on iOS) tap **Scan QR Code**.
3. Check the destination folder shown below the code field; change it with **Change** if needed.
4. Tap **Receive**.
5. CrocApp shows **Incoming transfer** with the file list and total size. Review it, then tap **Accept** or **Decline**.
6. When the transfer finishes, CrocApp shows **Transfer complete** with a button to open the destination folder (**Open in Files** on iOS, **Show in Finder** on macOS).

For the full detail on each step, see [Sending files](../guide/sending.md) and [Receiving files](../guide/receiving.md).
