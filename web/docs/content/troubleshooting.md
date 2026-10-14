---
sidebar_position: 6
title: Troubleshooting
description: "Real, sourced fixes for common CrocApp problems: stalled transfers, rejected codes, backgrounding limits, and permission issues."
---

# Troubleshooting

## Transfer stalls or never connects

CrocApp races a direct local-network connection against the relay and uses whichever connects first. Local-network peer discovery uses UDP multicast, and it is not guaranteed to work on every network — some networks (client-isolation-style Wi-Fi, for example) return no local peers at all, even though the relay path still works fine. If a transfer stalls at "Waiting" or "Connecting":

- Check that both devices have working internet access, so the relay path can work even if the local path can't.
- Check the [local network permission](#local-network-permission-prompt) below.
- There is no in-app fix for a network that blocks multicast discovery outright; the transfer should still complete over the relay.

## Code rejected or the receive button stays disabled

- A code phrase must be at least 6 characters. The **Receive** button stays disabled until you've entered enough.
- A wrong code fails immediately rather than hanging.
- If you're using a custom code you also use for testing or scripting, note that codes sharing their first word can collide into the same relay room. Generated codes rarely do: two share a first word about once in 1296.

## A link or QR code does not open CrocApp

- A link only fills in the code on **Receive**; nothing connects until you tap **Receive**. If a transfer is already running, the link is kept and CrocApp does not move you away from it.
- If the phone camera opens `crocapp.dev/r/` in the browser instead of the app, CrocApp is not installed, or iOS has not opened the link in it. Tap **Open in CrocApp** on that page, or copy the link into the **Receive** field.
- On Mac, links from the direct download may open the page rather than the app; **Open in CrocApp** on the page still works. Universal links are not yet confirmed for that build.
- **Receive in your browser** fails if the sender uses a custom relay or Local network only. The browser client knows only the default relays; receive in CrocApp instead.

## The other side is using a different croc version

CrocApp embeds croc v11.5.4 as its engine. It's built to interoperate with the `croc` CLI in both directions. The other side needs croc 11 or newer: croc 10 cannot complete a transfer with the app. When both sides reach the same relay, the app says the other device runs an older croc. Often they do not (with a generated code, or when the two use different relays), and the app just keeps waiting for the other side, so if a transfer with a croc 10 user never connects, ask them to upgrade to croc 11.

## iOS backgrounding limits

iOS does not allow raw TCP transfers to keep running arbitrarily in the background. CrocApp uses `BGContinuedProcessingTask` (iOS 26+) to keep a transfer going and show a system Live Activity, but it's best-effort: the system can end it under memory pressure, and a low-progress transfer is more likely to be killed than a nearly-finished one. For a transfer you don't want interrupted, keep CrocApp in the foreground until it finishes. If it does get cut off, croc's own resume behavior means restarting the same transfer picks up from where it left off rather than starting over, as long as you choose **Replace** for the partly received files. **Keep Both** saves the partly received file as a new copy instead of resuming it.

## Local network permission prompt

On first local-network use, iOS shows a system prompt asking to allow CrocApp to find devices on your local network. If you deny it, or the grant ends up "stuck" (a known iOS quirk where a granted permission doesn't actually work until you toggle it or reboot), CrocApp falls back to the relay only. If you see the banner "Local network access is off — transfers use the relay only," use its **Open Settings** button to check Settings › Privacy › Local Network.

## Received files not visible where expected

- On iOS, received files land in the app's Documents folder, which is visible in the Files app by default.
- If your receive destination was set to a folder picked through a cloud-storage provider (rather than a local location), the **Open in Files** button after a receive may not open it correctly — this is a known limitation. Navigate to the folder manually in the Files app instead.

## Relay unreachable

CrocApp uses croc's public relay by default. If it's unreachable from your network, you can set a [custom relay](guide/settings-and-trust.md) you control instead, or turn on **Local network only** if both devices are on the same network and you don't need the relay at all.

## Auto-accept and `--ask` senders

If you have auto-accept on and the sender is using croc's `--ask` confirmation flag, the transfer can be auto-declined, and CrocApp's message currently blames the wrong side ("the other side declined") rather than explaining that your own auto-accept setting caused it. This is a known issue with no fix yet; turning off auto-accept avoids it.

## No cancel button while reviewing an incoming transfer

Once you're looking at the incoming file list, **Decline** is the only way out — there's no separate cancel button at that stage, and the transfer-ended notification can lag slightly while croc finishes reconnect attempts underneath. This is expected behavior, not a bug.
