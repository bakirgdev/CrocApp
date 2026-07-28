---
sidebar_position: 5
title: Security and Privacy
description: The exact security claim CrocApp makes, stated precisely, plus what data it collects (none) and how to report a vulnerability.
---

# Security and privacy

## The claim, stated precisely

Transfers are end-to-end encrypted, the code phrase authenticates both sides, and the relay only ever sees ciphertext. That is the entire claim.

:::warning
There has been **no formal third-party security audit** of croc, and CrocApp does not claim one. Do not treat CrocApp as audited, certified, or zero-knowledge-verified.
:::

## How it works

- **One code, one transfer.** Every transfer uses a short one-time code phrase. Whoever has the code is the transfer partner; share it over a channel you trust, and it expires with the transfer.
- **Strong keys from short codes.** Both devices run PAKE (password-authenticated key exchange) to turn the code phrase into a strong encryption key. The code itself never crosses the network, and a wrong code fails immediately.
- **End-to-end encrypted.** Everything is encrypted on your device and decrypted only on the other one. Nothing in between can read it.
- **The relay is just a pipe.** When devices can't connect directly, an internet relay forwards the encrypted stream. The relay never has the key — it sees only ciphertext. You can also run your own relay and set it in settings.
- **Local network when possible.** Devices on the same network transfer directly; the data never leaves your network. The local path and the relay race, and the faster one wins.
- **You stay in control.** Nothing is saved without your OK: incoming transfers show a file preview you accept or decline. Auto-accept is off unless you turn it on.

## What CrocApp does not do

- No telemetry, no analytics, no ads, no accounts.
- Transfer history is local to the device — see [History](guide/history.md) for exactly what it records.
- You can point CrocApp at your own croc relay instead of the default public one.
- Dependencies in the Go engine are scanned by `govulncheck` on every CI run and again on a weekly schedule.

## Reporting a vulnerability

Report privately through [GitHub Security Advisories](https://github.com/bakirgdev/CrocApp/security/advisories/new). Never open a public issue, discussion, or pull request for a suspected vulnerability.

Useful to include: what an attacker gains and what access they'd need, reproduction steps (code phrase flow, relay, platform), the CrocApp version or commit plus OS version and device, and whether the same behavior reproduces with the upstream `croc` CLI.

Full policy, scope, and what's out of scope (the transfer protocol itself belongs to croc upstream): [`SECURITY.md`](https://github.com/bakirgdev/CrocApp/blob/main/SECURITY.md) on GitHub.
