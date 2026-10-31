---
sidebar_position: 4
title: Uninstall and data
description: How to remove CrocApp from iPhone, iPad and Mac, where it keeps data, and what deleting the app does and does not remove.
---

# Uninstall and data

## What CrocApp stores

| Data | Where | Removed by deleting the app? |
|---|---|---|
| Settings, including the receive folder you chose | The app's preferences | Yes |
| [History](guide/history.md) | A database in the app's own storage | Yes |
| Relay password, the two proxies, [saved codes](guide/code-phrases.md#saved-codes), and receipts for [Send as link](guide/send-as-link.md) | The Keychain | Mac: no (checked on a development build only). iPhone and iPad: not verified |
| Received files, iOS | The app's **Documents** folder | Yes: they are deleted with the app |
| Received files, Mac | `Downloads/CrocApp`, or the folder you chose | No |
| Files staged by the share sheet, iOS | The app's shared storage | Yes |

CrocApp keeps nothing in the cloud and has no account, so there is nothing to delete on a server, except a [Send as link](guide/send-as-link.md) upload that has not expired.

## Before you delete

You can leave this out if you do not care about leftovers. Each step is in the app:

1. **Revoke live links.** In **History**, choose **Revoke Link** on any link that has not expired. This deletes the files from the link server. Without a receipt on the device, you cannot revoke later.
2. **Clear History.** Tap **Clear**, then **Clear All**.
3. **Remove secrets.** In [Settings](guide/settings.md), empty **Password** under **Relay**, then in **Advanced** choose **Reset to Defaults**, which also removes the saved proxies.
4. **Mac only:** turn off **Open at Login** in Settings, or the login item stays registered until you remove it in System Settings > General > Login Items.
5. **Save any received files you want.** On iOS they live in the app's Documents folder and go with the app.

Keychain items for a revoked link are removed on revoke, and for an expired link at the next launch. On Mac, deleting the app leaves the other Keychain items in place, and they are not in your login keychain, so steps 1 and 3 are the way to remove them. This was checked on a development build, not on the App Store or disk image build. Where they show in Keychain Access or the Passwords app is not verified. On iPhone and iPad, whether they survive deleting the app is not verified, which is why step 3 comes first.

Pre-release builds before 1.1.0 kept these items in the login keychain on Mac, and CrocApp does not read or remove them. If you used one of those builds, remove them in Keychain Access: search for `com.bakirgdev.CrocApp`.

## iPhone and iPad

Touch and hold the CrocApp icon, tap **Remove App**, then **Delete App**. The app's preferences, history and Documents folder go with it.

Shortcuts that use CrocApp's actions stop working. Delete them in the Shortcuts app if you no longer want them.

## Mac, App Store build

Move **CrocApp** from **Applications** to the Trash. The menu bar icon goes with it. CrocApp is sandboxed, so its preferences and history sit in `~/Library/Containers/com.bakirgdev.CrocApp`. Delete that folder to remove them.

## Mac, disk image build

Move **CrocApp** from **Applications** to the Trash. Its sandbox container is `~/Library/Containers/com.bakirgdev.CrocApp.direct`. Delete that folder to remove the preferences and history, including the updater's own choices.

The updater (Sparkle) is part of the app, so there is no separate updater to remove.

If you used both builds, remember that they take each other's place in **Applications** (see [Requirements and install](getting-started/install.md#disk-image)). Each has its own container.
