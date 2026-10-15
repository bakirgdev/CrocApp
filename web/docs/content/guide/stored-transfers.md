---
sidebar_position: 4
title: Send as Link
description: "Upload encrypted files to a transfer server and share a link, so the receiver can download later without being online at the same time."
---

# Send as link (stored transfers)

**Send as link** uploads your files, encrypted on your device, to a transfer server and gives you a link. The receiver opens the link and downloads the files whenever they like, until the link expires or runs out of downloads. You do not need to stay online, and the two devices never connect to each other.

This is croc's *stored transfer* feature. The croc command line has the same feature, so the two interoperate.

## When to use it instead of a code

| | Code phrase | Send as link |
|---|---|---|
| Both devices online at the same time | Required | Not required |
| Receivers | One transfer per code | Up to the download count you set |
| Folders and text | Yes | No, files only |
| Where the files rest | Nowhere, they travel through a relay or directly | On the transfer server until the link ends |
| End it early | Cancel while it runs | [Revoke](#history-and-revoking) at any time before it expires |

Use a code phrase when both people are available now, or for folders and text. Use a link when the receiver is not around, or when several people need the same files.

## Sending

1. Open **Send** and add files.
2. Turn on **Send as link**.
3. Choose **Link lasts**: **1 hour**, **1 day** (the default) or **7 days**.
4. Set **Downloads allowed**, from 1 (the default) to 100.
5. Tap **Upload**.

A line under the options names the server the files will go to. While it runs, the screen reads **Uploading** with progress and a note that the files are encrypted on this device. It shows no relay badge, because an upload does not use a relay.

The **Send as link** switch is disabled, with a line saying why, when text is selected or a folder is staged. Switch to **Files**, remove the folders, or send them with a code instead. The custom code field is hidden while **Send as link** is on, since there is no code.

The relay, **Connection** and **Local network only** settings do not apply to an upload. The SOCKS5 and HTTP proxies under [Advanced settings](advanced-settings.md#network) do apply, to uploads, downloads and revokes. If the server address in [Settings](#the-server-setting) is invalid, the Send screen shows the problem and **Upload** stays disabled.

## The result screen

When the upload finishes, CrocApp shows **Link ready**, the time the link works until, and the number of downloads. Below that are:

- a QR code of the link
- the link itself
- **Copy Link**, which puts the link on the clipboard
- **Share Link**, which opens the system share sheet

CrocApp does not show the link again after you tap **Done**, and [History](history.md) never stores it. Copy or share it first. If you lose it, revoke the upload from History and send again.

On iOS, **Copy Link** keeps the link off Universal Clipboard, so it does not paste on your other Apple devices. The link contains the decryption key, which is why. macOS offers no such option, so on a Mac CrocApp cannot keep the copied link off Universal Clipboard.

The link is a bearer secret: anyone who has it can download the files until it ends. Send it over a channel you would trust with the files.

## Receiving

In **Receive**, paste the link with the **Paste** button, type or paste it into the field, or on iOS tap **Scan QR Code** and scan the QR from the result screen. The code field is replaced by a row reading **Download link from** and the server's host name, with a **Clear** button. Nothing downloads until you tap **Receive**.

CrocApp then fetches the file list and shows the usual **Incoming transfer** preview. Choose **Accept**, or **Keep Both** or **Replace** if a file with the same name already exists, exactly as in [Receiving files](receiving.md#overwrite-and-conflicts-f8). Auto-accept never applies to a link: you always see the preview first. The progress screen reads **Downloading**.

The phone's Camera app does not open CrocApp for these links. They point at the transfer server, and CrocApp's universal links cover only `crocapp.dev/r/`. A camera scan opens the server's own page in the browser. In CrocApp use **Scan QR Code** or paste the link.

### Receiving in a browser

Opening the link in any browser shows the transfer server's own page. For the default server that is a getcroc.com page run by croc's author, not by CrocApp. The key is in the part of the link after the `#`, which browsers do not send to the server, so the page decrypts in your browser. That means a browser download trusts the page the server serves, in the same way as [receiving a code in a browser](code-phrases.md#receiving-a-link). To avoid that trust, receive in CrocApp or the croc CLI.

A link that has expired, been revoked or run out of downloads reports so in CrocApp: "This link has expired, was revoked, or has no downloads left."

## History and revoking

A stored upload appears in [History](history.md) with the server's host name and one of:

- **Link expires** and the time, while it is live
- **Link expired** and the time
- **Link revoked** and the time

Choose **Revoke Link** to end it early. On macOS use the row's context menu. On iOS use the context menu (touch and hold) or swipe the row left and tap **Revoke**. A confirmation asks "Revoke this link?" and says the files are deleted from the server and the link stops working for everyone. If the server no longer has the upload, CrocApp treats the revoke as done.

**Revoke Link** appears only while the link is live and this device still holds the upload's receipt. A transfer you received, or a link that has already expired, has nothing to revoke. Deleting a History row, or clearing History, removes the place you revoke from, so revoke first if you want the link dead.

## The server setting

Under the **Send as link** section of Settings (the Settings scene on macOS, the settings screen on iOS), the **Server** field holds the transfer server. The default is `https://getcroc.com`, run by croc's author, not by CrocApp. A **Reset** button appears once you change it.

The address is checked as you type:

- It must use `https`. Plain `http` is allowed only for `localhost` (including `127.0.0.1` and `::1`).
- It must be the address only: nothing after the host name, no path, query or fragment.

The server must speak croc's stored-transfer protocol. The server you upload to decides how long it keeps files and which limits it enforces. The server in a received link is the one in the link, whatever your setting says.

## Limits

CrocApp refuses, before uploading, a send of more than 100 files, more than 1 GiB in total, or more than 100 downloads. Those are croc's defaults. A server with lower limits, or one that rate-limits uploads, can still refuse an upload, and CrocApp then says the server refused it for size, file count, download limit, or too many recent uploads.

Only regular files go in a link. Folders and text do not.

## Privacy

The files are encrypted on your device before upload. The key is the part of the link after the `#`, which CrocApp and browsers never send to the server.

The server sees the encrypted bytes, how large they are, the lifetime and download count you chose, and the usual details of any web request, such as your IP address and the time. It does not see the file contents or the key. CrocApp has not verified whether the server can read file names, so do not rely on names being hidden.

Anyone who has the whole link can decrypt the files, so the link itself is the secret.

On your device:

- [History](history.md) keeps only the server host and the upload id for a stored upload, never the link or the upload token.
- The receipt, which holds the upload token and the link, lives only in the iOS or macOS Keychain. CrocApp removes it when you revoke and at the first launch after the link expires.
- CrocApp makes no network request for a stored upload except to the server in Settings. See [Security and privacy](../security-and-privacy.md).

## If iOS interrupts an upload

An upload is wrapped in iOS background processing, so it can continue when you leave the app, but iOS may stop it. If it does, CrocApp shows "Upload interrupted: iOS stopped it in the background. Try again." A stored transfer cannot resume, so trying again means starting the upload over from the beginning, which produces a new link. A download that iOS stops reads "Download interrupted: iOS stopped it in the background. Open the link again."

Keep the app in the foreground for a large upload if you can.
