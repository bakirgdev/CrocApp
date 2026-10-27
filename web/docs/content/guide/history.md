---
sidebar_position: 6
title: History
description: "CrocApp's local-only transfer history: what it records, what it never records, and how to delete entries."
---

# History

![The History screen on macOS listing past transfers with their direction, file counts, and status](../../screenshots/mac/history-light.webp#gh-light-mode-only)![The History screen on macOS listing past transfers with their direction, file counts, and status](../../screenshots/mac/history-dark.webp#gh-dark-mode-only)

CrocApp keeps a list of past transfers on your device. Open it from **History** in the sidebar (iPad and Mac), or from the clock icon on the home screen on iPhone and in a narrow window. It has no sync, no export and no server.

On iPhone, and on iPad in a narrow window, the home screen also lists your latest three transfers under **Recent transfers**, newest first. A transfer that did not finish starts its line with **Failed**, **Cancelled** or **Declined**. Tap a row to open History. With no transfers yet it says **No transfers yet**, and with **Save Transfer History** off the list is not shown.

## What is recorded

**Save Transfer History** in [Settings](settings.md) is on by default. Turn it off and nothing new is recorded. Entries already here stay until you delete them.

For each finished or failed transfer:

- the direction (sent or received), and whether it was text
- up to 20 file names, the file count and the total size. A name from another device is kept with any hidden or text-direction character written as its code point, such as `\u{202E}`
- a **code hint**: the first word of a code shaped like a generated one (for example `wiry-…`), or only the first two characters of any other code. The full phrase is never stored
- the date and the status: **Completed**, **Failed**, **Cancelled** or **Declined**
- for sends, bookmarks to the original files (up to 200) that make **Send Again** possible

File contents are never recorded.

## Send Again

For a past send, the row's context menu (or a swipe on iOS) offers **Send Again**, which stages the same files in a new send. If the originals were moved or deleted, CrocApp says so instead of sending nothing.

## Links you sent

A [Send as link](send-as-link.md) row shows the link server's host and when the link expires, then **Link expired** or **Link revoked**. Use **Revoke Link** in the row's context menu, in its detail or, on iOS, with a swipe to end a live link. You can also revoke it from the **Link ready** screen right after sending, which is the only place to do so with **Save Transfer History** off. The link itself is never stored here.

## Delete

- **Delete** in a row's context menu (or a swipe on iOS) removes that entry.
- **Clear** in the toolbar, then **Clear All**, removes the whole list.

Both remove the list only. Files you already received stay where they were saved.

Deleting a row whose link still works asks first: **Revoke Link and Delete** ends the link and deletes the row, and **Delete and Keep Link** deletes the row only. The link then keeps working until it expires, and you can no longer revoke it from here. Other rows delete at once.

## Row details

Open a row (click or tap it, or press Return on a Mac) to see its status, date, size, files and link, and to use **Send Again**, **Revoke Link** or **Delete** from there. Code hints are hidden when the screen is captured or screen-shared. Dates such as "yesterday" and a link's **Expires** line update while the screen is open.
