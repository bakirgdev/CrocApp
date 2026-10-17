# Threat model and assurance case

Why CrocApp's security requirements are met, for a reviewer who wants to check. Scope: CrocApp 1.0 (iOS, iPadOS and macOS), the `crocmobile/` Go bridge, the `CrocKit` package, the share extension, and the release pipeline. The transfer protocol belongs to [croc](https://github.com/schollz/croc) v11.5.4 (pinned in `crocmobile/go.mod`); this document says what CrocApp relies on there and what it adds. To report a vulnerability, see [`SECURITY.md`](../SECURITY.md).

**No third-party security audit of croc or CrocApp has been done.** Everything below is the maintainer's own analysis, backed by the code and tests it names. Where a claim is read from croc's source and not run here, it says so.

## 1. Security requirements

The user-facing claims are the approved list in `design/content.md` ("Claims"). Each row names the mechanism that meets it and the section that argues it.

| # | Requirement (as published) | Met by | Argued in |
|---|---|---|---|
| R1 | Transfers are end-to-end encrypted. | PAKE-derived transfer key, AES-256-GCM, in croc; CrocApp implements no cryptography | 4.1 |
| R2 | The code phrase authenticates both devices (PAKE). | PAKE2 plus HMAC-SHA256 key confirmation, in croc | 4.1 |
| R3 | The relay only ever sees ciphertext. | Relay forwards the encrypted stream; the relay hop has its own authentication | 4.2 |
| R4 | Send as link: files are encrypted on your device before they reach the link server, and the key travels in the link's `#` fragment, which browsers never send to a server. | croc `storecrypto` (croc-store-v1) | 4.4 |
| R5 | When the two devices connect over the local network, the data stays on that network. | croc's local connection; Local network only setting | 4.2 |
| R6 | No accounts, analytics, ads or tracking; history stays on the device. | No such code or endpoints; local SwiftData history | 5 |

Requirements CrocApp adds on top of the protocol, because the app is where files meet the user's disk:

| # | Requirement |
|---|---|
| R7 | A received file name cannot write outside the chosen output folder or inject extra paths. |
| R8 | Nothing is written for a transfer the user declines, and receive does not overwrite existing files unless the user chooses Replace. |
| R9 | Secrets the user enters (relay password, proxy credentials, Send as link receipts) are not stored in plaintext preferences. |
| R10 | A release that fails signature, notarization or update-signing checks does not ship; a user can verify what they run. |

### Non-goals

CrocApp does not defend against, and does not claim to:

- **A compromised device.** Malware or a debugger on either device sees the files and the code phrase.
- **Someone who has the code phrase.** Whoever holds it can complete the exchange. Share it over a channel you trust. A receive shows the file list and waits for the user to accept (auto-accept is off by default), and the optional both-sides-confirm setting (croc `--ask`) adds a confirmation on the sender.
- **Metadata visible to the network and the relay.** IP addresses, timing and the volume of data are visible to the relay operator and on-path observers. Whether the relay also sees anything derived from the code phrase (croc picks the relay room from its first word: `src/codephrase/codephrase.go:194-222`, read from source per `docs/known-issues.md`) is not analysed here. Unknown.
- **Anonymity.** No claim is made.
- **A weak custom code phrase.** The app accepts any code of at least 6 bytes (`minCodeLength`, `crocmobile/crocmobile.go`). A code that is easy to guess is easy to guess online. The entropy of generated codes is croc's and is not assessed here.
- **A malicious or compromised link server's availability.** It holds ciphertext and can delete it or refuse service.
- **The browser receive path.** "Receive in Your Browser" opens croc's own web app at `getcroc.com`, which serves the JavaScript that decrypts the file and receives the code in the query string. It is outside the claims (see `web/docs/content/security-and-privacy.md`).

## 2. Assets

| Asset | Where it lives | Why it matters |
|---|---|---|
| File and text contents | Sender and receiver devices; ciphertext in transit | Confidentiality, integrity |
| Code phrase | Screen, QR and `https://crocapp.dev/r/#<code>` link; never stored in full in History (first word or two characters only) | Whoever has it can join the transfer |
| Transfer key | Memory of the Go engine, one session | Decrypts the transfer |
| Send as link key | The link's `#` fragment; the receipt in the Keychain | Anyone with the whole link decrypts the files |
| Relay password, proxy credentials | Keychain (`app/CrocApp/Support/KeychainStore.swift`) | Access to the user's own relay or proxy |
| Received files on disk | The output folder the user chose | Must not be written outside it |
| App binary and updates | GitHub releases, App Store | Integrity of what users run |
| Signing identities and keys | GitHub `release` environment secrets | Control over what ships as CrocApp |

## 3. Actors and threats

| Actor | Capability assumed | Threat | Response |
|---|---|---|---|
| Network attacker (on path) | Reads, drops, modifies traffic | Read or alter a transfer; learn metadata | Encrypted and authenticated end to end (4.1). Metadata exposure accepted (non-goals). |
| Relay operator (public pool or custom) | Sees everything the relay sees; can drop or delay | Read data; impersonate a device | Sees ciphertext only. The relay is not trusted for confidentiality or for who the other device is (4.2). Can refuse service. |
| Link server operator | Stores ciphertext and metadata it is given | Read files; serve altered files | Key is not sent to it (4.4). Files and manifest are authenticated by AES-GCM; the link server cannot forge a valid chunk without the key (croc `storecrypto`, not re-derived here). |
| Someone guessing the code phrase | Can contact the relay and try codes | Join a transfer | PAKE lets one run test one guess and a wrong guess fails the exchange (4.1). Captured traffic gives no offline guessing material (property of PAKE, strong inference). A public relay limits admission to 30 connections a minute per address (`docs/known-issues.md`), which is relay policy, not an app control. |
| The other device, malicious | Completed the exchange legitimately | Send hostile names, huge sizes, a changed list; abuse prompts | Section 7, rows W1 to W6. |
| Malicious files received | Opened later by the user | Content-level attacks (malware, parser bugs in other apps) | Out of scope: CrocApp never opens or executes received files. |
| Other apps and users on the device | Same user account, or a different app | Read secrets or staged files | Sandbox, Keychain, App Group scoping (section 4.3, W7). |
| Supply chain / update channel attacker | Compromise a dependency, a CI runner, a release asset or the feed | Ship a modified app | Section 4.5, W11 and W12. |

## 4. Trust boundaries

```
 Device A (sandboxed app)                                   Device B
 +----------------------------------------------+          +--------------+
 | SwiftUI app  --B1-->  CrocKit  --B2-->  Go    |          |  CrocApp or  |
 | (TransferController)  (actor)   crocmobile    |          |  croc CLI    |
 |        ^                         + croc v11.5.4|          +------^-------+
 |        |B3                          |         |                 |
 | Share extension (App Group)         | B4      |                 | B5 (PAKE + AES-GCM,
 +--------|-----------------------------|---------+                 |     end to end)
          |                             v                           |
   other apps / Files          Relay (pool or own) <----------------+
                               Link server (Send as link)   B6
 Update channel: GitHub releases + appcast.xml  --B7-->  Direct (DMG) build only
 CI: GitHub Actions `release` environment  --B8-->  signed, notarized, attested assets
```

| Boundary | Crosses | What is trusted on the far side | Control |
|---|---|---|---|
| B1 SwiftUI to `CrocKit` | Typed Swift calls | Nothing from the network; the layer above is the user | `CrocEngine` is the single caller of Go; `TransferController` the single caller of `CrocEngine` (`docs/ARCHITECTURE.md`) |
| B2 `CrocKit` to Go (gomobile) | Scalars and strings; file lists and progress as JSON; paths joined by `\n` | Go side trusts the joined path list | `CrocEngine.joinedPaths` refuses line breaks; Go `splitPaths` keeps names exact; malformed JSON becomes a failure (`DelegateBridge`) |
| B3 App to share extension, via App Group | Staged files and `manifest.json` | The manifest is data, not trusted | `ShareInbox.refresh` filters names with `ReceivedName.isUnsafe`; the extension has only the App Group entitlement and no network |
| B4 Go engine to the network and filesystem | Sockets, files, process-global `Chdir`, stdin | Everything on the wire | Section 7 |
| B5 Device to the other device | Encrypted stream, direct or via relay | Only a device that proved knowledge of the code phrase; still treated as untrusted for names and sizes | PAKE, key confirmation, per-message AES-GCM; names and sizes validated on receipt (W1 to W4) |
| B6 Device to relay or link server | Ciphertext, plus metadata | Neither is trusted with plaintext | Separate relay-hop authentication; link server gets ciphertext only (4.2, 4.4) |
| B7 Update channel | `appcast.xml` and update archives | Not trusted until the EdDSA signature matches the key in the app | Sparkle 2, `SUPublicEDKey` (4.5) |
| B8 CI to published assets | Build, sign, notarize, attest | Runner is trusted only inside an approved `release` run | 4.5 |

### 4.1 Key agreement and data protection (croc)

Facts verified against croc v11.5.4 and pake v3.2.0 source:

- **Key agreement:** PAKE2 (Boneh and Shoup) from `schollz/pake` v3.2.0, with fresh random secrets per session drawn from `crypto/rand`. CrocApp sets curve P-256 by default (`NewOptionsDefault` in `crocmobile/crocmobile.go`); p384, p521, siec and ed25519 are selectable under Advanced settings.
- **Transfer key:** HKDF-SHA256 over the PAKE secret, the transcript and a fresh salt (`src/pakekey/pakekey.go:110`). Key confirmation uses HMAC-SHA256 compared with `hmac.Equal`. A device that does not know the code phrase fails here.
- **Data:** AES-256-GCM with a random nonce per message (`src/crypt/crypt.go`).
- **File-integrity hash:** `xxhash` by default; md5, imohash and highway are selectable. It is an integrity check on the file, not a security control.

CrocApp implements none of this. It passes the code phrase and options to croc and shows the result.

### 4.2 Relay and local network

The relay hop is authenticated with its own PAKE using the relay password (an outbound credential), separate from the end-to-end exchange; the relay sees ciphertext only. The default relay password is croc's built-in value, which is public in croc's source and provides no secrecy; it gates the relay, not the data. With a custom relay, the user sets the password in Settings and it is held in the Keychain.

Local network only (`OnlyLocal`) keeps the connection on the local network. With Connection = Automatic, a send of 128 MiB or more can also use Tailcat (`tailcat.dev`, `*.ipn.dev`); the data is end-to-end encrypted on either path, and Relay Only never contacts them (`Options.Transport`). The trust badge names the configured route, not the path that carried the data (`docs/known-issues.md`, Accepted).

### 4.3 App sandbox and entitlements

| Target | Entitlements | Why |
|---|---|---|
| macOS app (`app/CrocApp/CrocApp.entitlements`) | `app-sandbox`, `network.client`, `network.server`, `files.user-selected.read-write`, `files.downloads.read-write`, associated domain `applinks:crocapp.dev` | `network.server` is only for croc's local relay listener; `downloads.read-write` is for the default output folder `~/Downloads/CrocApp` |
| iOS app (`app/CrocApp/CrocApp-iOS.entitlements`) | App Group `group.com.bakirgdev.CrocApp`, associated domain | Share extension handoff; universal links |
| Direct (DMG) build (`app/CrocAppDirect/CrocAppDirect.entitlements`) | The macOS set plus two `temporary-exception.mach-lookup.global-name` entries for Sparkle's installer services (`-spks`, `-spki`) | Sandboxed Sparkle updates |
| Share extension (`app/CrocShare/CrocShare.entitlements`) | App Group only | Copies files into the group container; no network |

`ENABLE_APP_SANDBOX` and `ENABLE_HARDENED_RUNTIME` are set to `YES` on the app targets in `app/CrocApp.xcodeproj/project.pbxproj`. User-picked URLs are accessed through security-scoped bookmarks and released at the end of the transfer (`docs/ARCHITECTURE.md`, "Sandbox boundaries").

### 4.4 Send as link

`crocmobile/store.go` uses croc's `storecrypto` (croc-store-v1): a 32-byte random key, HKDF subkeys, AES-GCM-encrypted chunks and manifest. The link server receives ciphertext and the transfer ID; the key stays in the link's `#` fragment. The link server origin must be `https`, or `http` on loopback only: enforced in Go (`validateStoreOrigin`, `store.go`), because App Transport Security does not cover Go sockets, and again at parse time (`TransferLink`, `AppSettings.storedServerError`). The copied link goes to the iOS pasteboard as `localOnly` so it stays off Universal Clipboard (`app/CrocApp/Support/Clipboard.swift`). A receipt in the Keychain lets the sender revoke the link; anyone holding the whole link can decrypt until it expires or is revoked.

### 4.5 Build, update and release

- **Signing:** the DMG app is signed with a Developer ID certificate, hardened runtime and timestamp; the app and the DMG are notarized and stapled (`.github/workflows/release.yml`, `web/docs/content/verify-downloads.md`). App Store builds go through Apple's signing and review.
- **Updates (Direct build only):** Sparkle 2 over HTTPS (`SPARKLE_FEED_URL` build setting in `app/CrocApp.xcodeproj/project.pbxproj`, read by `SUFeedURL`). The app carries the EdDSA public key (`SUPublicEDKey`) and installs an update only if the signature matches. `release.yml` fails the run if the appcast entry lacks `sparkle:edSignature` (around line 228). `SUEnableSystemProfiling` is `false` (`app/Config/CrocApp-Direct-Info.plist`). App Store builds contain no updater.
- **Provenance:** a GitHub build provenance attestation covers the DMG, the engine archive and `appcast.xml`, made after stapling (`actions/attest-build-provenance` in `release.yml`). Verification commands are in `web/docs/content/verify-downloads.md`.
- **Pipeline hygiene:** third-party actions are pinned to commit SHAs; checkouts set `persist-credentials: false`; the release job runs in the `release` environment, which needs maintainer approval and allows only `main` and `v*` tags; the signing material is removed from the runner at the end of the job. Dependabot covers GitHub Actions, Go modules and Swift packages (`.github/dependabot.yml`).

## 5. Privacy (R6)

CrocApp has no account system and no analytics or advertising code. History is a local SwiftData store (`TransferRecord`, `app/CrocApp/Models/TransferHistory.swift`) holding up to 20 file names per record, counts, sizes, a code hint and status, never the full code phrase or file contents (`web/docs/content/guide/history.md`). The servers the app can contact are listed in the [privacy policy](https://crocapp.dev/privacy/). The link page at `crocapp.dev/r/` makes no network request and sets a `no-referrer` policy.

## 6. Design principles applied

Saltzer and Schroeder, with the evidence for each.

| Principle | How it shows up |
|---|---|
| Economy of mechanism | CrocApp implements no cryptography and does not fork croc. One bridge (`crocmobile/`), one Swift caller (`CrocEngine`), one state machine (`TransferController`). |
| Fail-safe defaults | Auto-accept off. Receive defaults to Keep Both; an unknown policy string never overwrites (`PolicyKeepBoth`, `parsePolicy`). The stdin answers queued behind an accept are always "n" (`keptPromptAnswers`, `crocmobile/session.go`). Link server must be `https`. |
| Complete mediation | Every incoming file list is checked on arrival (`ReceivedName.isUnsafe` in `TransferController`); Accept is disabled when a name is blocked (`TransferStatusView`), and under auto-accept the transfer is cancelled. The share extension manifest is re-validated on read. |
| Open design | croc and CrocApp are open source; no secret algorithm. The only secrets are keys and passwords. |
| Separation of privilege | Releases need a maintainer approval of the `release` environment. Update signing (Sparkle EdDSA key) and app signing (Developer ID identity) are separate keys. |
| Least privilege | App sandbox; only the file-access and network entitlements listed in 4.3; share extension has no network; secrets in the Keychain with `kSecAttrAccessibleAfterFirstUnlock`, not in `UserDefaults`; workflow `permissions` scoped per job. |
| Least common mechanism | One transfer at a time (`activeMu`), because croc mutates process-global state (`Chdir`, stdin and stdout). Network globals are restored on error and panic (`TestNetworkGlobalsRestoredAfterPanic`). |
| Psychological acceptability | A receive shows the file list and waits for the user. The trust badge names the route. Blocked names show a reason instead of failing silently. |
| Compromise recording | Build provenance attestations, notarization, signed updates; Send as link receipts allow revoke. |

## 7. Common weaknesses countered

| ID | Weakness (CWE) | Countermeasure | Where | Pinned by |
|---|---|---|---|---|
| W1 | Path traversal in received names (CWE-22) | Names with an absolute path, `..` component, backslash, NUL or control character block the transfer; croc applies its own receive-path policy as well (it refuses, for example, a name with a trailing space) | `app/CrocApp/Support/ReceivedName.swift`, `TransferController` | `ReceivedNameTests` |
| W2 | Argument and command injection through names (CWE-88, CWE-74) | A name with a line break cannot become extra send paths: refused in Swift before the join and split exactly in Go. `*` in a name is escaped so croc's glob sends only that file | `CrocEngine.joinedPaths`; `splitPaths`, `sendFilesInfo` in `crocmobile/` | `SendPathValidationTests`, `TestSplitPathsKeepsNamesExact`, `TestSendFilesInfoTakesPathsLiterally`, `FuzzSplitPaths` |
| W3 | Integer overflow and wraparound (CWE-190) | Declared sizes and sums are clamped to 1 PiB before they reach Swift; `relayPorts` checks the range without overflow (found by fuzzing, #32) | `addReported`, `maxReportedBytes` in `session.go`; `relayPorts` in `network.go` | `TestProgressSnapshotCapsDeclaredSizes`, `TestFileListJSONCapsDeclaredSizes`, `FuzzRelayPorts` |
| W4 | Time-of-check changes after consent (CWE-367 style) | After an accepted receive, a reconnecting sender cannot get a new file list accepted: the queued stdin answer is "n", so the receive ends. Existing files inside a zipped folder are kept even under Replace | `keptPromptAnswers`, `promptPolicyAnswers` in `session.go` | `TestAnswerUngatedPromptsNeverAccepts`, `TestPolicyAnswersFitPipeBuffer`, `TestDrainPromptInputClearsLeftoverAnswers` |
| W5 | Missing authentication (CWE-306) | The code phrase gates the exchange (PAKE); the relay hop has its own authentication; the receiver confirms the file list | croc (4.1, 4.2); `IncomingRequestView` | Interop harnesses (`scripts/verify-interop.sh`) |
| W6 | Unrestricted resource use (CWE-400) | One transfer at a time; stored sends capped by file count and size before anything is sent; reported sizes clamped; History capped at 20 names and 200 bookmarks; the share extension activates for at most 25 files, images or movies of each type. No cap on total received size is added by CrocApp | `store.go` limits; `TransferHistory.swift`; `app/Config/CrocShare-Info.plist` | `TestStoreSendLimitsFailBeforeUpload`, `TestStoreSendOversizeFailsBeforeHashing` |
| W7 | Cleartext storage and exposure of credentials (CWE-312, CWE-532) | Relay password, proxy credentials and Send as link receipts live in the Keychain; Keychain failures log the `OSStatus` only; proxy validation errors never quote the value; History keeps a code hint, never the full code. A legacy plaintext relay password is migrated into the Keychain | `KeychainStore.swift`, `AppSettings.swift`, `StoredTransferVault.swift`, `network.go` | `RelayPasswordMigrationTests`, `StoredTransferVaultTests`, `FuzzProxyURL` |
| W8 | Weak or broken cryptography (CWE-327) | No custom cryptography. AES-256-GCM, HKDF-SHA256, HMAC-SHA256 and PAKE2 come from croc and pake; `crypto/rand` for secrets. The integrity hash is not used for security | croc v11.5.4, pake v3.2.0 | Not tested by CrocApp; relies on upstream |
| W9 | Insecure transport for link server (CWE-319) | `https` required, `http` allowed on loopback only; checked in Go and in Swift | `validateStoreOrigin`; `TransferLink`; `AppSettings.storedServerError` | `StoredServerValidationTests`, `TransferLinkTests`, `TestStoreReceiveRejectsBadLinks` |
| W10 | Panic or crash from untrusted input (CWE-248, CWE-476) | Exported Go entry points recover and report an error; delegate callbacks survive a panicking delegate; malformed JSON from the bridge becomes a failure event | `crocmobile.go`, `store.go`, `DelegateBridge.swift` | `TestStoreCallbacksSurviveAPanickingDelegate`, `TestReportPanicPayloadIsOther`, `TestNetworkGlobalsRestoredAfterPanic`, `DelegateBridgeTests` |
| W11 | Update fetched without integrity check (CWE-494) | Sparkle EdDSA verification over an HTTPS feed; release job fails without `sparkle:edSignature`; notarization; attestations | 4.5 | `verify-downloads` steps; CI release rehearsal |
| W12 | Vulnerable and outdated components (CWE-1104) | `govulncheck`, `go vet`, `go test -race`, `golangci-lint` on every Go change (`.github/workflows/reusable-go.yml`); weekly 30 s run of each Go fuzz target (`go-weekly.yml`); CodeQL default setup; secret scanning with push protection; Dependabot | `.github/` | CI |
| W13 | Unsafe handling of untrusted staged files (CWE-73) | Share extension copies files with a unique batch directory per share and never reads payload into memory; the app re-validates manifest names | `ShareStager.swift`, `ShareInbox.swift` | Not unit-tested for the manifest filter. Unknown. |

The 1.0.0 security fixes in `CHANGELOG.md` correspond to W1, W2, W3 and W4: glob `*` in names, line breaks in names, trailing-space names, reconnect swapping the file list after accept, and impossible declared sizes. Receive does not overwrite existing files by default.

## 8. Residual risks and accepted issues

| Risk | Status |
|---|---|
| No third-party audit of croc or CrocApp | Open. Stated on every surface that discusses security at length. |
| Protocol-level weaknesses in croc, PAKE or the relay design | Upstream scope (`SECURITY.md`). CrocApp tracks croc releases (`docs/knowledge/croc-upgrade-playbook.md`). |
| croc prints the code phrase, and a non-default relay password, to stderr on every send | Accepted. Nothing in the app captures stderr; a Finder, Dock or Home Screen launch connects it to `/dev/null` (strong inference, not measured on a device). A harness or Xcode debug session does capture it. `docs/known-issues.md`. |
| `release.yml` passes the signing `.p12` and keychain passwords on `security` argv | Accepted for a single-tenant runner. Do not run on a shared runner. |
| `create-dmg` is installed unpinned during the release build | Accepted for 1.0. `docs/known-issues.md`. |
| One maintainer approves releases, so there is no second reviewer on the `release` environment | Accepted. Disclosed in `verify-downloads.md`. |
| Compromise of the Sparkle EdDSA private key or the `release` secrets | Would allow signed malicious updates or releases. Mitigation is limited to approval gating and attestation, which a compromised pipeline could also satisfy. |
| `manifest.batch` in the share extension's manifest is joined to the App Group path without a name check (`ShareInbox.refresh`) | Only a process with the same App Group can write it, so the writer is already inside the same-developer trust domain. Not countered by code; noted, not exploited. |
| A sender can offer a very large total size; CrocApp adds no disk quota | The accept sheet shows the file list; the user decides. |
| `poll()` reads croc client fields without synchronization | Worst case is a wrong progress number; bounds-checked. `docs/known-issues.md`. |
| `golang.org/x/crypto` GO-2026-5932 (`openpgp`) with no fixed version | Not imported or called (`govulncheck`). `docs/known-issues.md`. |
| Metadata (IP, timing, volume) visible to relay and network | Accepted (section 1). |
| The trust badge names the configured route, not the path used | Accepted; the claim that the relay sees ciphertext holds on every path. |
| Entitlement exceptions: `network.server`, Sparkle mach-lookup (Direct build) | Each has a stated reason (4.3). |

## 9. Keeping this current

Update this file in the same pull request when any of these change:

- the croc or pake version, curve defaults, or the Send as link format;
- an entitlement, the App Group, the share extension's inputs, or the sandbox settings;
- where secrets are stored;
- the release workflow: signing, notarization, attestation, Sparkle keys or feed;
- a new weakness class gets a fix: add a row to section 7 with its test.

Related: [`SECURITY.md`](../SECURITY.md), [`docs/ARCHITECTURE.md`](ARCHITECTURE.md), [`docs/known-issues.md`](known-issues.md), `web/docs/content/security-and-privacy.md`, `web/docs/content/verify-downloads.md`.
