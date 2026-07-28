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
- If you're using a custom code you also use for testing or scripting, note that codes sharing their first 4 characters can collide into the same relay room. Generated codes don't have this problem.

## The other side is using a different croc version

CrocApp embeds croc v10.5.0 as its engine. It's built to interoperate with the `croc` CLI in both directions. If the other side is running a very old or unusually new `croc` build, use a reasonably current CLI version to avoid protocol mismatches.

## iOS backgrounding limits

iOS does not allow raw TCP transfers to keep running arbitrarily in the background. CrocApp uses `BGContinuedProcessingTask` (iOS 26+) to keep a transfer going and show a system Live Activity, but it's best-effort: the system can end it under memory pressure, and a low-progress transfer is more likely to be killed than a nearly-finished one. For a transfer you don't want interrupted, keep CrocApp in the foreground until it finishes. If it does get cut off, croc's own resume behavior means restarting the same transfer picks up from where it left off rather than starting over.

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
