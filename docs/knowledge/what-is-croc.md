# What is croc

Facts checked against croc **v11.5.5**, the pinned version: the source read in the Go module cache, and CLI behaviour read in `src/cli`. Before trusting any of this against a newer croc, follow `croc-upgrade-playbook.md`. Terms: `../GLOSSARY.md`.

Source: https://github.com/schollz/croc

## Identity

- A CLI tool to "easily and securely send things from one computer to another": any file, folder or text, between any two machines, with a short code phrase.
- Author Zack Scholl (schollz). Go, MIT license.
- No port forwarding or local server needed.
- Its README credits magic-wormhole as the idea. It adds resumable and multi-file transfers.
- A browser client lives at getcroc.com.

## How a transfer works

### 1. Code phrase

- A generated code is three random words from the EFF short wordlist #1 (1296 words), joined by hyphens (`codephrase.Generate`).
- A custom code comes from `--code` (at least 6 characters) or the `CROC_SECRET` environment variable. Older `NNNN-word-word` codes still parse (legacy split, see step 2).
- On Unix, `send --code X` in the default (non-classic) mode exits without sending and tells you to use `CROC_SECRET=X croc send ...`. A receive code given as an argument is refused the same way. `croc --classic` lifts both. Prefer `CROC_SECRET` for scripting.
- The receiver takes the code as one argument, or as three or four arguments joined with hyphens.

### 2. Rendezvous

Both sides connect to a relay and join a room named `SHA-256(selector + "croc")`.

- The selector is the first word of a three-word code, the first two words of a four-word code, and the first 4 characters of any other code (legacy).
- Two concurrent transfers whose codes share the selector, on the same relay, collide into one room ("room full"). With generated codes that is about 1 in 1296 per relay. Custom codes and test scripts must differ in the selector.

Relay choice:

- With no `--relay` or `--relay6` (or `CROC_RELAY`, `CROC_RELAY6`), no `--local` and no `--ip`, the CLI uses a public pool: `1.getcroc.com:9009` to `4.getcroc.com:9009` (`publicrelay.Relays`).
- Both sides pick the relay from the code: `RelayIndex` is the SHA-256 of the whole code read as a big-endian integer, modulo 4.
- A sender with no custom code uses the relay cached in a `best-relay` file in croc's config dir. Otherwise it probes all four (1 s timeout), caches the first to answer a ping, and generates codes until one maps to that relay (`GenerateForRelay`). A send on a generated code that fails with a relay connection error clears the cache.
- The pool path blanks the IPv6 relay.
- The old single default still exists: `models.DEFAULT_RELAY` (`croc.schollz.com:9009`) and `DEFAULT_RELAY6` (`croc6.schollz.com:9009`) are what `--relay` and `--relay6` default to.

Ports: transfer ports default to 9009-9013, control port first.

### 3. PAKE

- The passphrase part of the code (the final two words of a three-word code) feeds PAKE2 (`github.com/schollz/pake/v3` v3.2.0, Boneh-Shoup construction) through `src/pakekey`. `pakekey` binds the exchange to the purpose, room and role of each side.
- The default curve is P-256 (`--curve`: p256, p384, p521, siec, ed25519).
- It turns the weak phrase into a strong session key. The relay never learns it.
- The peer PAKE protocol is versioned (`pakekey.ProtocolVersion` = 2) and fails closed on a mismatch.

### 4. Encryption

Everything is end to end.

- The PAKE session key goes through HKDF-SHA256 with a 32-byte salt and a transcript of both PAKE messages, the room, the curve and the identities (`pakekey.Derive`). That yields a 32-byte traffic key plus two key-confirmation keys.
- Each side proves it holds the key (HMAC-SHA256 tags) before data flows.
- After that, everything on the wire is **AES-256-GCM** (`crypt.NewAESGCM`, a random 12-byte nonce prepended to each message).
- `crypt.New` (PBKDF2-HMAC-SHA256, 100 iterations) protects only the client-to-relay password handshake (`src/tcp`), not transfer data.
- `crypt.NewArgon2` (Argon2id with XChaCha20-Poly1305) and `EncryptChaCha` / `DecryptChaCha` exist in the same file but have no non-test call site in v11.5.5. Do not describe croc as Argon2- or ChaCha-based.
- The relay sees ciphertext only. It is untrusted by design.

### 5. Transport

Data is DEFLATE-compressed (HuffmanOnly; `--no-compress` disables it) and chunked at 32 KB.

- A file whose first 256 KB shrinks by under 2% is sent uncompressed.
- The sender chooses the data path with `--transport` (`auto` default, `derp`, `relay`). Receivers always follow the sender.

**relay**: chunks are claimed from a shared queue by up to 8 parallel TCP connections, one per relay transfer port. This is croc's classic speed trick.

**Tailcat**: two native v11 clients build PAKE-bound node identities and carry TCP streams over an in-process userspace WireGuard network. It starts on DERP and moves to direct UDP when NAT traversal works.

- `auto` offers Tailcat only when the total send is at least 128 MiB (`autoTailcatThresholdBytes`), and races it against the relay, which starts 350 ms later. `derp` requires Tailcat.
- A browser peer, an older client or a failed setup falls back to the relay ports. `derp` disables that fallback.
- `--transport` cannot be combined with `--local` unless it is `auto`.
- A build without Tailcat downgrades `derp` to `relay`.
- Setup fetches the DERP map from `https://tailcat.dev/derpmap.json` at runtime. Below the threshold, or with `relay`, none of those servers is contacted.
- CrocApp exposes only `auto` and `relay` (`crocmobile-bridge.md`, "Engine behavior invariants", "Transport").

### 6. Local path

- The sender also starts a local relay and broadcasts its port over UDP multicast (`schollz/peerdiscovery`, default group 239.255.255.250 via `--multicast`, IPv4 and IPv6).
- The receiver races discovery (200 ms search, 500 ms cap) against the relay dial, staggered by 75 ms. Whichever connection completes first wins. If the relay wins, the receiver still asks the sender for its local IPs and tries them directly.
- Same-LAN transfers never touch the internet.
- Discovery is not guaranteed. It returned zero peers every time on one AP-isolated (client isolation) network, for both the stock CLI and crocmobile. That was seen with the previous croc pin and not re-tested on v11. Root cause not isolated.
- Workaround: `--ip <senderLAN-IP>:9009` on the receiver connects directly to the sender's local relay control port (the first local relay port, 9009 unless busy). It skips discovery and never touches the public relay.

### 7. Resume and integrity

- Interrupted transfers resume: the receiver scans the partial file for zeroed chunks.
- An existing file of the same size is hashed and skipped when equal.
- The hash is xxhash by default. `--hash` offers imohash (sampled), md5 and highway.

### 8. Reconnect

A dropped transfer is retried up to 10 times, with a backoff of 100 ms doubling to a 5 s cap. Each attempt uses a fresh random room. After that it fails with `transfer disconnected after 10 reconnect attempts`.

## Feature surface

- **Send**: files, folders, multiple files, raw text (`--text`), piped stdin, zip before send (`--zip`), exclusions (`--exclude`, `--exclude-file`, `--git`).
- **Receive**: `--yes` auto-accept, `--overwrite`, `--rename` (receive an existing name as `name (1).ext` instead of prompting), output dir (`--out`), `--stdout`.
- **Code**: random, custom (`--code`), env (`CROC_SECRET`), a QR code of the web receive URL `https://getcroc.com/?code=...` (`--qrcode`), and the code copied to the clipboard by default (`--disable-clipboard`).
- **Transport**:
  - custom relay (`--relay`, `--relay6`, `--pass`);
  - self-hosted relay (`croc relay`, at least 2 TCP ports, `--ports`, `--transfers`, admission limits);
  - data path (`--transport auto|derp|relay`);
  - SOCKS5 proxy including Tor (`--socks5`, relay DNS resolved by the proxy);
  - HTTP proxy (`--connect`);
  - upload throttle (`--throttleUpload`);
  - curve and hash selection;
  - local only (`--local`).
- **Stored transfers**: `croc store` (or `send --store`) uploads client-side-encrypted files to a service (default `https://getcroc.com`). It sets a limited number of downloads (`--downloads`, default 1) and a lifetime (`--expiration`, default 1d). The receiver uses the printed link or token. The sender revokes with `--revoke`. This is separate from the live PAKE protocol.
- **Shared terminal**: `croc ssh` hosts or joins a terminal with six-word invitations over a Tailcat path, with a relay fallback.
- **IPv6**: tried first (50 ms head start), IPv4 as fallback.

```bash
croc send file.txt                                   # -> prints word-word-word
CROC_SECRET=word-word-word croc                      # receiver (Unix)
croc --relay myserver:9009 send f                    # self-hosted relay
```

## Known CVEs

- A security review of croc led to the CVEs CVE-2023-43616 to CVE-2023-43621. One of them is the secret visible in the process list to local users (CVE-2023-43621), which is why Unix needs `CROC_SECRET`. CVE-2023-43620 is terminal escapes in file names (per the module's `packaging/distributions/security-evidence.md`).
- The descriptions of the other CVEs, and the exact version that fixed each one, are not verified here. The module's Alpine package file lists the six CVEs under the 10.0.11 package, and says nothing more.
- The breaking protocol change that followed shipped as croc 10.0.0.
- The v11 repository references no formal audit.
- GUI implication: croc's threat model assumes an untrusted relay and trusted endpoints. CrocApp therefore surfaces receive confirmations and never invents auto-accept defaults.

## Facts relevant to CrocApp

- **Library use**: croc is importable as `github.com/schollz/croc/v11/src/croc`. Use `croc.New(croc.Options{...})`, or `croc.NewCtx(ctx, opts)` to pass a context, which crocmobile does. It is pure Go plus `x/crypto`, so a gomobile binding works.
- **New `Options` in v11**: `Transport`, `Rename`, and `PublicRelay` (set when the relay came from the pool; it only changes the receive hint the sender prints).
- **Peers need croc 11 or newer.** A v10 and a v11 peer cannot complete a transfer:
  - v11 rejects a PAKE message without protocol version 2 (`peer uses unsupported PAKE protocol version 0; upgrade both croc clients`).
  - v10.5.0's `message.Message` has no version field at all.
  - The v11 key schedule also differs from v10's.
- **v10 peers often never meet.** v10 derives the relay room from the code's first 4 characters, and v11 from the first word. v10's default relay is not always the pool relay a v11 code maps to. So `peerVersion` fires only when both reach the same room.
- **Other clients**: croc's README lists a community native Kotlin client (`croc-app`, on F-Droid) that is not in the croc repo. `prior-art.md` covers its subprocess architecture, which is unusable on iOS. The README also lists `croc-desktop` (Wails, croc in process) with experimental iOS and Android builds. No dedicated free native iOS client is listed, so CrocApp fills a real gap.
- **iOS friction points**:
  - UDP multicast discovery needs the `com.apple.developer.networking.multicast` entitlement.
  - The local relay needs listening sockets.
- **Constants**: default relay password `"pass123"`, `TCP_BUFFER_SIZE` 64 KB, chunk size 32 KB.
