---
sidebar_position: 1
title: Troubleshooting
description: "Fixes for common CrocApp problems: a transfer that never connects, a rejected code, permission prompts, interrupted transfers and missing files."
---

# Troubleshooting

## The transfer never connects

CrocApp tries the local network and the relay at once and uses whichever connects first. Finding devices on the local network uses UDP multicast, which some networks block, such as guest Wi-Fi with client isolation. The relay path still works there, so:

- Check that both devices have internet access.
- Check the [local network permission](#local-network-access-is-off).
- Start the sender first, then the receiver (see below).
- If you see "This is taking longer than usual", double-check the code and make sure the other device is ready.

## Check the relay

If a transfer says "Couldn't reach the relay" or "The relay rejected its password", open **Settings** and tap **Check Relay…** (on a Mac, the button is in the **General** and **Relay** tabs). It tests the relay and the local network and says what to change. [Run your own relay](guide/own-relay.md#check-a-relay) explains each result.

## The receiver started first

If the receiver joins before the sender has started, the receive fails with "The other device wasn't ready" and "Start the send there first, or use a faster connection, then enter the code again." The sending device can say "The code phrases don't match" at the same moment. This hits custom codes, and the croc command line sending with a fixed code. Start the send again first, then the receive.

## No internet

With no connection, a send with a generated code fails before a code appears, with "No public relay answered". Reconnect and tap **Try Again**, or turn on **Local Network Only** in [Settings](guide/settings.md#transfer) when both devices share a network.

If only croc's public relay is unreachable from your network, set a [custom relay](guide/settings.md#relay) you control, or use **Local Network Only**.

## The code is rejected, or Receive stays disabled

- A code needs at least 6 characters. **Receive** stays disabled until it has them.
- A wrong code fails at once with "The code phrases don't match".
- "That code is already in use" means another transfer holds that custom code. Pick another.
- Codes that start with the same word can land in the same relay room. Generated codes rarely collide.

## A link or QR code does not open CrocApp

- A link only fills in the code. Tap **Receive** to connect. If a transfer is already running, CrocApp keeps the link and stays on that transfer.
- If the phone camera opens `crocapp.dev/r/` in the browser, CrocApp is not installed or iOS did not hand the link over. Tap **Open in CrocApp** on that page, or copy the link into the **Receive** field.
- On a Mac the link may open in the browser. **Open in CrocApp** on the page still works.
- **Receive in Your Browser** fails when the sender uses a custom relay or **Local Network Only**. The browser client knows only the default relays.
- A [Send as link](guide/send-as-link.md) QR code does not open CrocApp from the Camera app. Use **Scan QR Code** inside CrocApp.

## The other device uses an older croc

The other device needs croc 11 or newer. When both sides reach the same relay, CrocApp says "The other device's croc is outdated". Often it does not: with a generated code, or when the two use different relays, the app keeps waiting. If a transfer with a croc 10 user never connects, ask them to upgrade.

## Local network access is off

The first time CrocApp needs the local network, the system asks for permission. If you refuse it, or the permission seems stuck (an iOS quirk where a granted permission does not work until you toggle it or restart), CrocApp falls back to the relay and shows **Local network access is off**. Tap **Open Settings** and turn on CrocApp under Privacy & Security > Local Network. This applies on iOS and on Mac.

## Scan QR Code does not work

On iOS, scanning needs camera access. If you refused it, CrocApp shows "Camera access denied". Tap **Open Settings** and allow it. If it says "Camera access restricted", a parental control or device policy blocks it, and Settings cannot change that. Type or paste the code instead.

## A transfer stopped in the background

On iOS, a transfer keeps running when you leave the app and shows a Live Activity, but iOS can stop it, more likely for a transfer with little progress. Keep CrocApp in the foreground for a transfer you do not want interrupted.

To resume, tap **Try Again** or start the same transfer again, and choose **Replace** for the partly received files. **Keep Both** saves a new copy instead of resuming.

## Received files are not where I expect

- On iOS, files land in the app's Documents folder, visible in the Files app.
- **Open in Files** appears only when the destination is that default folder. For a folder you picked, such as one in cloud storage, open it from the Files app.
- On a Mac, the default is `Downloads/CrocApp`. **Show in Finder** or ⇧⌘R opens it.

## Auto-accept and a sender who confirms

With **Auto-Accept Transfers** on and a sender using croc's `--ask` option, the transfer fails, and CrocApp says "Auto-accept can't answer this sender". Tap **Open Settings** and turn off **Auto-Accept Transfers**, or ask the sender to send without `--ask`.

## A cancelled transfer does not stop

If CrocApp says "The cancelled transfer didn't stop", the transfer engine kept running after you cancelled, and CrocApp cannot start another transfer until it restarts. Quit CrocApp and open it again.

## Still stuck

Ask on [GitHub Discussions](https://github.com/bakirgdev/CrocApp/discussions), or see [Support](https://crocapp.dev/support/).
