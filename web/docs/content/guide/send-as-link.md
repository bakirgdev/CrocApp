---
sidebar_position: 4
title: Send as link
description: "Send encrypted files to a link server and share a link, so the other device can receive later without being online at the same time."
---

# Send as link

**Send as Link** sends your files, encrypted on your device, to a link server and gives you a link. The other device opens the link and receives the files whenever it likes, until the link expires or runs out of downloads. You do not need to stay online, and the two devices never connect to each other.

This is croc's *stored transfer* feature. The croc command line has the same feature, so the two work together.

## When to use it instead of a code

| | Code phrase | Send as link |
|---|---|---|
| Both devices online at the same time | Required | Not required |
| Devices that can receive | One per code | Up to the number of downloads you set |
| Folders and text | Yes | No, files only |
| Where the files rest | Nowhere, they travel through a relay or directly | On the link server until the link ends |
| End it early | Cancel while it runs | [Revoke](#history-and-revoking) at any time before it expires |

Use a code phrase when both people are available now, or for folders and text. Use a link when the other device is not around, or when several people need the same files.

## Sending

1. Open **Send** and add files.
2. Turn on **Send as Link**.
3. Choose **Link Lasts**: **1 Hour**, **1 Day** (the default) or **7 Days**.
4. Set **Downloads allowed**, from 1 (the default) to 100.
5. Tap **Send as Link**.

A line under the options names the link server the files will go to. While it runs, the screen reads **Sending** with progress and a note that the files are encrypted on this device. It shows no relay badge, because a link send does not use a relay.

The **Send as Link** switch is disabled, with a line saying why, when text is selected or a folder is staged. Switch to **Files**, remove the folders, or send them with a code instead. The custom code field is hidden while **Send as Link** is on, since there is no code.

The relay, **Connection** and **Local Network Only** settings do not apply to a link send. The SOCKS5 and HTTP proxies under [Advanced settings](advanced-settings.md#network) do apply, to sends, receives and revokes. If the server address in [Settings](#the-link-server-setting) is invalid, the Send screen shows the problem and **Send as Link** stays disabled.

## The result screen

When the send finishes, CrocApp shows **Link ready**, the time the link works until, and the number of downloads. Below that are:

- a QR code of the link
- the link itself
- **Copy Link**, which puts the link on the clipboard
- **Share Link**, which opens the system share sheet

CrocApp does not show the link again after you tap **Done**, and [History](history.md) never stores it. Copy or share it first. If you lose it, revoke the link from History and send again.

On iOS, **Copy Link** keeps the link off Universal Clipboard, so it does not paste on your other Apple devices. The link contains the key, which is why. macOS offers no such option, so on a Mac CrocApp cannot keep the copied link off Universal Clipboard.

Anyone who has the whole link can open the files until it ends. Send it over a channel you would trust with the files.

## Receiving

In **Receive**, paste the link with the **Paste** button, type or paste it into the field, or on iOS tap **Scan QR Code** and scan the QR code from the result screen. The code field is replaced by a **Receive from Link** row with the link server's host name and a **Clear** button. Nothing is fetched until you tap **Receive**.

CrocApp then fetches the file list and shows it for review. Choose **Accept**, or **Keep Both** or **Replace** if a file with the same name already exists, exactly as in [Receiving files](receiving.md#overwrite-and-conflicts). Auto-accept never applies to a link: you always see the file list first. The progress screen reads **Receiving**.

The phone's Camera app does not open CrocApp for these links. They point at the link server, and CrocApp's universal links cover only `crocapp.dev/r/`. A camera scan opens the link server's own page in the browser. In CrocApp use **Scan QR Code** or paste the link.

### Receiving in a browser

Opening the link in any browser shows the link server's own page. For the default server that is a getcroc.com page run by croc's author, not by CrocApp. The key is in the part of the link after the `#`, which browsers do not send to a server, so the page decrypts in your browser. That means a browser receive depends on the page the link server serves, in the same way as [receiving a code in a browser](code-phrases.md#receiving-a-link). To avoid that dependency, receive in CrocApp or the croc CLI.

A link that has expired, been revoked or run out of downloads says so in CrocApp: "This link has expired, was revoked, or has no downloads left."

## History and revoking

A link send appears in [History](history.md) with the link server's host name and one of:

- **Link expires** and the time, while it is live
- **Link expired** and the time
- **Link revoked** and the time

Choose **Revoke Link** to end it early. On macOS use the row's context menu. On iOS use the context menu (touch and hold) or swipe the row left and tap **Revoke**. A confirmation asks "Revoke this link?" and says the files are deleted from the link server and the link stops working for everyone. If the link server no longer has the files, CrocApp treats the revoke as done.

**Revoke Link** appears only while the link is live and this device still holds the receipt for the send. A transfer you received, or a link that has already expired, has nothing to revoke. Deleting a History row, or clearing History, removes the place you revoke from, so revoke first if you want the link ended.

## The link server setting

Under the **Send as Link** section of Settings (the Settings scene on macOS, the settings screen on iOS), the **Server** field holds the link server. The default is `https://getcroc.com`, run by croc's author, not by CrocApp. A **Reset** button appears once you change it.

The address is checked as you type:

- It must use `https`. Plain `http` is allowed only for `localhost` (including `127.0.0.1` and `::1`).
- It must be the address only: nothing after the host name, no path, query or fragment.

The link server must speak croc's stored-transfer protocol. The link server you send to decides how long it keeps files and which limits it enforces. The link server in a received link is the one in the link, whatever your setting says.

## Limits

CrocApp refuses, before sending, a send of more than 100 files, more than 1 GiB in total, or more than 100 downloads allowed. Those are croc's defaults. A link server with lower limits, or one that rate-limits sends, can still refuse, and CrocApp then says the server refused it for size, file count, download limit, or too many recent sends.

Only regular files go in a link. Folders and text do not.

## Privacy

The files are encrypted on your device before they reach the link server, and the key travels in the link's `#` fragment, which browsers never send to a server. CrocApp makes no network request for a link send except to the link server in Settings.

The link server sees the size of the encrypted data, the lifetime and download count you chose, and the usual details of any web request, such as your IP address and the time. CrocApp has not verified whether the link server can read file names, so do not rely on names being hidden.

Anyone who has the whole link can decrypt the files, so treat the link itself with care.

On your device:

- [History](history.md) keeps only the link server's host and the transfer id for a link send, never the link or the token that revokes it.
- The receipt, which holds that token and the link, lives only in the iOS or macOS Keychain. CrocApp removes it when you revoke and at the first launch after the link expires.
- See [Security and privacy](../security-and-privacy.md) for the full list of what CrocApp can contact.

## If iOS interrupts a send

A link send is wrapped in iOS background processing, so it can continue when you leave the app, but iOS may stop it. If it does, CrocApp says iOS stopped it in the background and asks you to try again. A link send cannot resume, so trying again starts over from the beginning and produces a new link. If iOS stops a receive from a link, open the link again.

Keep the app in the foreground for a large send if you can.
