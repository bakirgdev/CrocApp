---
sidebar_position: 7
title: History
description: "CrocApp's local-only transfer history: what it records, what it deliberately never records, and how to clear it."
---

# History (F12)

![CrocApp's History screen on macOS listing past transfers with their direction, file counts, and status](/img/screenshots/mac-history-light.png#gh-light-mode-only)![CrocApp's History screen on macOS listing past transfers with their direction, file counts, and status](/img/screenshots/mac-history-dark.png#gh-dark-mode-only)

CrocApp keeps a local list of past transfers, reachable from the home screen's history icon. It never leaves the device: there is no sync, no export, and no server involved.

## What's recorded

For each finished or failed transfer:

- Direction (sent or received) and whether it was a text transfer
- Up to 20 file names
- Total file count and total size
- A **code hint**: only the first segment of the code phrase (for example, "7291-…"), never the full phrase
- Date and status (completed, failed, cancelled, or declined)
- For sends, a set of file bookmarks used to support **Send Again** — captured all-or-nothing, and only up to 200 items; a record with no bookmarks simply doesn't offer Send Again

## What's never recorded

- File contents
- The full code phrase — only that first-segment hint
- Anything beyond the 20-name and 200-bookmark caps

## Stored uploads

A file sent with [Send as link](stored-transfers.md) is recorded with the server's host name and the time the link expires, then **Link expired** or **Link revoked** later. **Revoke Link**, in the row's context menu (and as a swipe action on iOS), deletes the upload from the server after a confirmation. The link and the upload token are never stored in History; they stay in the Keychain until the link is revoked or expires.

## Send Again

For a past send, the history entry's context menu (or swipe action on iOS) offers **Send Again** if bookmarks were captured for it. This re-stages the same files into a new send. If the original files were moved or deleted since, CrocApp tells you they're no longer available rather than silently sending nothing.

## Clearing history

Tap **Clear** in the history screen's toolbar, then confirm. This removes the list only — files you've already received stay exactly where they were saved.
