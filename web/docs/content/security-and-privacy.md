---
sidebar_position: 5
title: Security and privacy
description: What CrocApp guarantees, what it does and does not collect, and how to report a vulnerability.
---

# Security and privacy

## What CrocApp guarantees

Transfers are end-to-end encrypted, the code phrase authenticates both devices (PAKE), and the relay only ever sees ciphertext. That is the whole claim.

:::warning
CrocApp has **not had a formal third-party security audit**. Do not treat it as audited or certified.
:::

## How it works

- **One code, one transfer.** Every transfer uses a fresh code phrase. Whoever has the code can join the transfer, so share it over a channel you trust.
- **The code phrase authenticates both devices.** Both devices run PAKE (password-authenticated key exchange) with the code phrase. A wrong code fails immediately.
- **End-to-end encrypted.** Everything is encrypted on your device and decrypted on the other one.
- **The relay only ever sees ciphertext.** When the two devices cannot connect directly, an internet relay forwards the encrypted stream. You can also run your own relay and set it in Settings.
- **A direct connection for large files.** With the default **Automatic** connection setting, a send of 128 MiB or more also tries a direct connection, set up through `tailcat.dev`, with its own relays (`*.ipn.dev`) when the devices cannot reach each other. Whichever path connects first carries the transfer, and it is end-to-end encrypted on either path. Those servers are contacted only for such a send. Choose **Relay Only** under [power options](guide/power-options.md) and your sends never contact them. A receive follows the sender's choice, so receiving a large file from a sender on Automatic (or the croc CLI's default) can use them.
- **The local network.** When the two devices connect over the local network, the data stays on that network. The local connection and the relay race, and the faster one wins.
- **Send as link.** [Send as link](guide/stored-transfers.md) encrypts the files on your device before they reach the link server, and the key travels in the link's `#` fragment, which browsers never send to a server. The link server is the one named in Settings, by default `https://getcroc.com`, run by croc's author and not by CrocApp. A link send contacts that server and nothing else. Anyone with the whole link can decrypt the files, and you can revoke the link from [History](guide/history.md).
- **Links carry the code in the fragment.** A `https://crocapp.dev/r/#<code>` link keeps the code after the `#`, which browsers never send to a server. The page at that address makes no network request and sets a `no-referrer` policy. Anyone who sees the link still has the code, so share it the way you would share the code.
- **You stay in control.** A receive shows the file list and waits for you to accept or decline. Auto-accept is off unless you turn it on.

## Receiving in a browser

The link page offers **Receive in Your Browser**, which opens `https://getcroc.com/?code=<code>`. That is croc's own web app, not run by CrocApp. The code travels in the query string there, so it reaches getcroc.com's server. The browser path also depends on getcroc.com fully, because getcroc.com serves the JavaScript that decrypts the file. It reaches only croc's default relays. The CrocApp and croc CLI paths do not have this dependency. If that is more than you want to depend on, receive in CrocApp.

## Privacy

- CrocApp has no accounts, analytics, ads or tracking.
- History stays on the device. See [History](guide/history.md) for exactly what it records.
- You can point CrocApp at your own croc relay instead of the default public one.
- The disk image build checks github.com for updates through Sparkle and installs only updates whose signature matches the key built into the app. It sends no system profile. See [Verify a release](verify-downloads.md) for how to check a release. The App Store builds contain no updater.
- Dependencies in the Go engine (`crocmobile/`) are scanned by `govulncheck` in CI when the Go code or the Go CI workflows change, and on a weekly schedule.

The [privacy policy](https://crocapp.dev/privacy/) lists every server CrocApp can contact, what each one can see, and how long a link send is kept.

## Reporting a vulnerability

Report privately through [GitHub Security Advisories](https://github.com/bakirgdev/CrocApp/security/advisories/new). Never open a public issue, discussion or pull request for a suspected vulnerability.

Useful to include: what an attacker gains and what access they would need, reproduction steps (code phrase flow, relay, platform), the CrocApp version or commit plus OS version and device, and whether the same behavior reproduces with the upstream `croc` CLI.

Full policy, scope, and what is out of scope (the transfer protocol itself belongs to croc upstream): [`SECURITY.md`](https://github.com/bakirgdev/CrocApp/blob/main/SECURITY.md) on GitHub.
