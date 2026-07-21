# What is croc

Facts current as of 2026-07-21 (croc v10.4.14). Source: https://github.com/schollz/croc

## Identity

CLI tool to "easily and securely send things from one computer to another": any file/folder/text, between any two machines, via a short code phrase. Author Zack Scholl (schollz). Go (1.22+), MIT license, ~36k GitHub stars, 195+ releases, very actively maintained. Single static binary, zero dependencies, no port forwarding needed. Inspired by magic-wormhole; adds resumability, multi-file transfers, and full-duplex relay comms.

## How a transfer works

1. **Code phrase**: sender gets `NNNN-word-word-word` (4-digit PIN + mnemonicode words from 4 random bytes). Custom via `--code` (min 6 chars) or `CROC_SECRET` env var (preferred; keeps secret off process list).
2. **Rendezvous**: both sides connect to a relay and join a room named `SHA-256(secret[:4] + "croc")`. Default public relay `croc.schollz.com:9009` (IPv6: `croc6.schollz.com`); transfer ports 9009-9013.
3. **PAKE**: full secret feeds PAKE2 (`github.com/schollz/pake/v3`, Boneh-Shoup construction). Default curve P-256 (`--curve`; SIEC was original default, dropped after cryptographer criticism). Yields a strong session key from the weak phrase; relay never learns it.
4. **Encryption**: end-to-end. Session key stretched via Argon2id (legacy path: PBKDF2/100 iter); data encrypted with AES-256-GCM or ChaCha20-Poly1305 (both in `src/crypt`; runtime default unverified). Relay sees ciphertext only — untrusted by design.
5. **Transport**: files DEFLATE-compressed (HuffmanOnly, `--no-compress` to disable), chunked at 32 KB, striped across parallel TCP connections (one per relay port, chunk index mod port count) — this is croc's speed trick.
6. **Local path**: sender also starts a local relay and advertises via UDP multicast (`schollz/peerdiscovery`, ~500 ms window). Local vs external relay race concurrently; first successful handshake wins. Same-LAN transfers never touch the internet.
7. **Resume + integrity**: interrupted transfers resume (receiver scans partial file for zeroed chunks). Hash: xxhash default; imohash (sampled, for huge files), md5, highway via `--hash`.

## Feature surface (GUI must eventually cover)

- Send: files, folders, multiple files, raw text (`--text`), zip-before-send (`--zip`), exclusions (`--exclude`, `--git`)
- Receive: `--yes` auto-accept, `--overwrite`, output dir (`--out`)
- Code: random, custom (`--code`), env (`CROC_SECRET`), QR code display (`--qrcode`)
- Transport: custom relay (`--relay`, `--relay6`, `--pass`), self-hosted relay (`croc relay`, min 2 TCP ports, `--transfers`), SOCKS5 proxy incl. Tor (`--socks5`), HTTP proxy (`--connect`), upload throttle (`--throttleUpload`), curve + hash selection
- IPv6-first, IPv4 fallback

```bash
croc send file.txt                    # -> prints 9822-word-word-word
croc 9822-word-word-word              # receiver
croc --relay myserver:9009 send f     # self-hosted relay
```

## Security history

Sept 2023: Matthias Gerstner (SUSE) review of v9.6.5 → 8 issues, CVE-2023-43616..43621: dangerous file overwrites (`authorized_keys`), zip path traversal, ANSI escapes in filenames, secret prefix as room name, cleartext local-IP message, secret visible on cmdline. Fixed in 9.6.6+; breaking protocol change became v10.0.0. No formal audit since (none found). GUI implication: croc's threat model assumes an untrusted relay and trusted endpoints — CrocApp should surface receive confirmations and never invent auto-accept defaults.

## Facts relevant to CrocApp

- Importable as Go library: `github.com/schollz/croc/v10/src/croc` (`croc.New(croc.Options{...})`). Pure Go + x/crypto → gomobile binding plausible (untested; see ADR 0006).
- v10.4.14 (2026-07-20) added a **native Kotlin Android client in-repo**. No official or community iOS build exists — CrocApp fills a real gap, and the Android client is a reference for mobile integration questions.
- Likely iOS friction points: UDP multicast discovery (needs `com.apple.developer.networking.multicast` entitlement) and listening sockets for the local relay.
- Default relay password constant `"pass123"`; `TCP_BUFFER_SIZE` 64 KB; chunk size 32 KB.
