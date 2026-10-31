# Threat model and assurance case

Why CrocApp's security requirements are met, for a reviewer who wants to check. Scope: CrocApp on iOS, iPadOS and macOS (release status: `knowledge/project-overview.md`, "Status"), the `crocmobile/` Go bridge, the `CrocKit` package, the share extension, and the release pipeline. The transfer protocol belongs to [croc](https://github.com/schollz/croc) v11.5.5 (pinned in `crocmobile/go.mod`); this document says what CrocApp relies on there and what it adds. To report a vulnerability, see [`SECURITY.md`](../SECURITY.md).

**No third-party security audit of croc or CrocApp has been done.** Everything below is the maintainer's own analysis, backed by the code and tests it names. Where a claim is read from croc's source and not run here, it says so.

## Security requirements

The user-facing claims are the approved list in `design/voice.md` ("Claims"). Each row names the mechanism that meets it and the section that argues it.

| Requirement (as published) | Met by | Argued in |
|---|---|---|
| **End-to-end encryption**: Transfers are end-to-end encrypted. | PAKE-derived transfer key, AES-256-GCM, in croc; CrocApp implements no cryptography | Key agreement and data protection |
| **Authenticated devices**: The code phrase authenticates both devices (PAKE). | PAKE2 plus HMAC-SHA256 key confirmation, in croc | Key agreement and data protection |
| **Relay sees ciphertext**: The relay only ever sees ciphertext. | Relay forwards the encrypted stream; the relay hop has its own authentication | Relay and local network |
| **Send as Link encryption**: Send as Link: files are encrypted on your device before they reach the link server, and the key travels in the link's `#` fragment, which browsers never send to a server. | croc `storecrypto` (croc-store-v1) | Send as Link |
| **Local network stays local**: When the two devices connect over the local network, the data stays on that network. | croc's local connection; Local Network Only setting | Relay and local network |
| **No tracking**: No accounts, analytics, ads or tracking; history stays on the device. | No such code or endpoints; local SwiftData history | Privacy |

Requirements CrocApp adds on top of the protocol, because the app is where files meet the user's disk:

| Requirement |
|---|
| **Safe received names**: A received file name cannot write outside the chosen output folder or inject extra paths. |
| **No unconsented writes**: Nothing is written for a transfer the user declines, and receive does not overwrite existing files unless the user chooses Replace. |
| **Secrets out of preferences**: Secrets the user enters (relay password, proxy credentials, Send as Link receipts) are not stored in plaintext preferences. |
| **Verifiable releases**: A release that fails signature, notarization or update-signing checks does not ship; a user can verify what they run. |

### Non-goals

CrocApp does not defend against, and does not claim to:

- **A compromised device.** Malware or a debugger on either device sees the files and the code phrase.
- **Someone who has the code phrase.** Whoever holds it can complete the exchange. Share it over a channel you trust. **Copy Code** leaves the code on the pasteboard for 5 minutes, and on Universal Clipboard, because copying on a Mac and pasting on an iPhone is a core use. Until it expires, any app that reads the pasteboard can read it. Expiry works as for the link under Send as Link, and whether it also expires on the other device is not verified. A receive shows the file list and waits for the user to accept (auto-accept is off by default), and the optional both-sides-confirm setting (croc `--ask`) adds a confirmation on the sender.
- **Metadata visible to the network and the relay.** IP addresses, timing and the volume of data are visible to the relay operator and on-path observers. Whether the relay also sees anything derived from the code phrase (croc picks the relay room from its first word: `src/codephrase/codephrase.go:194-222`, read from source per `known-issues.md`) is not analysed here. Unknown.
- **Anonymity.** No claim is made.
- **A weak custom code phrase.** The app accepts any code of at least 6 bytes (`minCodeLength`, `crocmobile/crocmobile.go`). A code that is easy to guess is easy to guess online. The entropy of generated codes is croc's and is not assessed here.
- **A malicious or compromised link server's availability.** It holds ciphertext and can delete it or refuse service.
- **The browser receive path.** "Receive in Your Browser" opens croc's own web app at `getcroc.com`, which serves the JavaScript that decrypts the file and receives the code in the query string. It is outside the claims (see `web/docs/content/security-and-privacy.md`).

## Assets

| Asset | Where it lives | Why it matters |
|---|---|---|
| File and text contents | Sender and receiver devices; ciphertext in transit | Confidentiality, integrity |
| Code phrase | Screen, QR and `https://crocapp.dev/r/#<code>` link; never stored in full in History (first word or two characters only) | Whoever has it can join the transfer |
| Transfer key | Memory of the Go engine, one session | Decrypts the transfer |
| Send as Link key | The link's `#` fragment; the receipt in the Keychain, on this device only | Anyone with the whole link decrypts the files |
| Relay password, proxy credentials | Keychain, on this device only (`app/CrocApp/Support/KeychainStore.swift`): never synced, and not restored to another device from a backup. An item written by an earlier build takes this class on its next write | Access to the user's own relay or proxy |
| Received files on disk | The output folder the user chose. The result list offers Quick Look, sharing and drag-out of a file under the name the sender gave it, which passed `ReceivedName.isUnsafe` before it was saved | Must not be written outside it; a name that reads as another one never reaches Quick Look, Share or a drag |
| App binary and updates | GitHub releases, App Store | Integrity of what users run |
| Signing identities and keys | GitHub `release` environment secrets | Control over what ships as CrocApp |

## Actors and threats

| Actor | Capability assumed | Threat | Response |
|---|---|---|---|
| Network attacker (on path) | Reads, drops, modifies traffic | Read or alter a transfer; learn metadata | Encrypted and authenticated end to end (Key agreement and data protection). Metadata exposure accepted (non-goals). |
| Relay operator (public pool or custom) | Sees everything the relay sees; can drop or delay | Read data; impersonate a device | Sees ciphertext only. The relay is not trusted for confidentiality or for who the other device is (Relay and local network). Can refuse service. |
| Link server operator | Stores ciphertext and metadata it is given | Read files; serve altered files | Key is not sent to it (Send as Link). Files and manifest are authenticated by AES-GCM; the link server cannot forge a valid chunk without the key (croc `storecrypto`, not re-derived here). |
| Someone guessing the code phrase | Can contact the relay and try codes | Join a transfer | PAKE lets one run test one guess and a wrong guess fails the exchange (Key agreement and data protection). Captured traffic gives no offline guessing material (property of PAKE, strong inference). A public relay limits admission to 30 connections a minute per address (`known-issues.md`), which is relay policy, not an app control. |
| The other device, malicious | Completed the exchange legitimately | Send hostile names, huge sizes, a changed list; abuse prompts | The first six rows of Common weaknesses countered (path traversal, injection, overflow, time-of-check, authentication, resource use). |
| Malicious files received | Opened later by the user | Content-level attacks (malware, parser bugs in other apps) | Out of scope: CrocApp never opens or executes received files. |
| Someone who can search the Mac or iPhone (Spotlight, Shortcuts) | Types in Spotlight, or runs a shortcut, on the unlocked device | Learn which files the user sent or received | Names go to Spotlight only with **Show History in Spotlight** on (off by default) and with **Save Transfer History** on; never a code or code hint (Privacy). Accepted when on: the system, not CrocApp, decides who can search the index. |
| Other apps and users on the device | Same user account, or a different app | Read secrets or staged files | Sandbox, Keychain, App Group scoping (App sandbox and entitlements; cleartext credentials in Common weaknesses countered). |
| Supply chain / update channel attacker | Compromise a dependency, a CI runner, a release asset or the feed | Ship a modified app | Build, update and release; update integrity and outdated components in Common weaknesses countered. |

## Trust boundaries

```
 Device A (sandboxed app)                                   Device B
 +----------------------------------------------+          +--------------+
 | SwiftUI app  ------>  CrocKit  ------>  Go    |          |  CrocApp or  |
 | (TransferController)  (actor)   crocmobile    |          |  croc CLI    |
 |        ^                         + croc v11.5.5|          +------^-------+
 |        |                            |         |                 |
 | Share extension (App Group)         |         |                 | (PAKE + AES-GCM,
 +--------|-----------------------------|---------+                 |     end to end)
          |                             v                           |
   other apps / Files          Relay (pool or own) <----------------+
                               Link server (Send as Link)
 Update channel: GitHub releases + appcast.xml  ------>  Direct (DMG) build only
 CI: GitHub Actions `release` environment  ------>  signed, notarized, attested assets
```

| Boundary | Crosses | What is trusted on the far side | Control |
|---|---|---|---|
| **SwiftUI to `CrocKit`** | Typed Swift calls | Nothing from the network; the layer above is the user | `CrocEngine` is the single caller of Go; `TransferController` the single caller of `CrocEngine` (`ARCHITECTURE.md`, "Layer diagram") |
| **`CrocKit` to Go (gomobile)** | Scalars and strings; file lists and progress as JSON; paths joined by `\n` | Go side trusts the joined path list | `CrocEngine.joinedPaths` refuses line breaks; Go `splitPaths` keeps names exact; malformed JSON becomes a failure (`DelegateBridge`) |
| **App to share extension, via App Group** | Staged files and `manifest.json` | The manifest is data, not trusted | `ShareInbox.refresh` ignores a manifest whose batch name is not `batch-` and a UUID (`ShareHandoff.isValidBatchName`) and filters file names with `ReceivedName.isUnsafe`; the extension has only the App Group entitlement (and the sandbox on macOS) and no network |
| **Go engine to the network and filesystem** | Sockets, files, process-global `Chdir`, stdin | Everything on the wire | Common weaknesses countered |
| **Device to the other device** | Encrypted stream, direct or via relay | Only a device that proved knowledge of the code phrase; still treated as untrusted for names and sizes | PAKE, key confirmation, per-message AES-GCM; names and sizes validated on receipt (path traversal, injection, overflow and time-of-check rows of Common weaknesses countered) |
| **Device to relay or link server** | Ciphertext, plus metadata | Neither is trusted with plaintext | Separate relay-hop authentication; link server gets ciphertext only (Relay and local network, Send as Link) |
| **Update channel** | `appcast.xml` and update archives | Not trusted until the EdDSA signature matches the key in the app | Sparkle 2, `SUPublicEDKey` (Build, update and release) |
| **CI to published assets** | Build, sign, notarize, attest | Runner is trusted only inside an approved `release` run | Build, update and release |

### Key agreement

Facts verified against croc v11.5.5 and pake v3.2.0 source:

- **Key agreement:** PAKE2 (Boneh and Shoup) from `schollz/pake` v3.2.0, with fresh random secrets per session drawn from `crypto/rand`. CrocApp fixes curve P-256 (`crocCurve` in `crocmobile/network.go`) and has no curve setting. A sender adopts the curve its receiver announces (`croc.go`), so a CLI receiver can still pick another curve that pake offers, including `siec`.
- **Transfer key:** HKDF-SHA256 over the PAKE secret, the transcript and a fresh salt (`src/pakekey/pakekey.go:110`). Key confirmation uses HMAC-SHA256 compared with `hmac.Equal`. A device that does not know the code phrase fails here.
- **Data:** AES-256-GCM with a random nonce per message (`src/crypt/crypt.go`).
- **File-integrity hash:** `xxhash`, croc's default, which CrocApp does not let the user change. A receiver adopts the sender's hash, so a CLI sender can use md5, imohash or highway. It is an integrity check on the file, not a security control.

CrocApp implements none of this. It passes the code phrase and options to croc and shows the result.

### Relay and local network

The relay hop is authenticated with its own PAKE using the relay password (an outbound credential), separate from the end-to-end exchange; the relay sees ciphertext only. The default relay password is croc's built-in value, which is public in croc's source and provides no secrecy; it gates the relay, not the data. With a custom relay, the user sets the password in Settings and it is held in the Keychain.

Local Network Only (`OnlyLocal`) keeps the connection on the local network. The engine is croc's relay-only build (`croc_no_tailcat`, set in `scripts/build-xcframework.sh`), so the relay and the LAN are the only data paths. There is no Tailcat, DERP or `tailcat.dev` path in the shipped binary, and no setting to turn one on. The trust badge names the configured route, not the path that carried the data (`known-issues.md`, Accepted).

### App sandbox and entitlements

| Target | Entitlements | Why |
|---|---|---|
| macOS app (`app/CrocApp/CrocApp.entitlements`) | `app-sandbox`, `network.client`, `network.server`, `files.user-selected.read-write`, `files.downloads.read-write`, associated domain `applinks:crocapp.dev` | `network.server` is only for croc's local relay listener; `downloads.read-write` is for the default output folder `~/Downloads/CrocApp` |
| iOS app (`app/CrocApp/CrocApp-iOS.entitlements`) | App Group `group.com.bakirgdev.CrocApp`, associated domain, multicast networking | Share extension handoff; universal links; local-network discovery |
| Direct (DMG) build (`app/CrocAppDirect/CrocAppDirect.entitlements`) | The macOS set plus two `temporary-exception.mach-lookup.global-name` entries for Sparkle's installer services (`-spks`, `-spki`) | Sandboxed Sparkle updates |
| Share extension, iOS (`app/CrocShare/CrocShare.entitlements`) | App Group only | Copies files into the group container; no network |
| Widgets extension (`app/CrocWidgets/*.entitlements`, copies of the share extension's) | App Group; `app-sandbox` on the Mac | Reads `last-transfer.json`: direction, outcome, item count, date and, only with the user's switch, one file name. Never a code phrase, link or key. The app deletes the file when Save Transfer History is off. No network |
| Share extension, macOS (`CrocShare-macOS.entitlements`, `CrocShareDirect.entitlements`) | `app-sandbox` and the team-prefixed App Group (macOS app and Direct carry the same group) | Copies the files and folders Finder shares into the group container; no network, no file entitlement (the system grants access to the shared items). On macOS, any process signed by team `HBSU359M33` can read the group container, so a staged file is as exposed as any file of the user until the app consumes it |

`ENABLE_APP_SANDBOX` and `ENABLE_HARDENED_RUNTIME` are set to `YES` on the app targets in `app/CrocApp.xcodeproj/project.pbxproj`. User-picked URLs are accessed through security-scoped bookmarks and released at the end of the transfer (`ARCHITECTURE.md`, "Platform split").

### Send as Link

- `crocmobile/store.go` uses croc's `storecrypto` (croc-store-v1): a 32-byte random key, HKDF subkeys, AES-GCM-encrypted chunks and manifest.
- The link server receives ciphertext and the transfer ID; the key stays in the link's `#` fragment.
- The link server origin must be `https`, or `http` on loopback only: enforced in Go (`validateStoreOrigin`, `store.go`), because App Transport Security does not cover Go sockets. The settings field asks that same check (`AppSettings.storedServerError` calls `EngineSetting.storeServer`), and `TransferLink` checks a received link again at parse time.
- **Copy Link** asks the system to keep the link on this device, off Universal Clipboard, and to drop it from the pasteboard after 5 minutes. On macOS the app does the dropping, so it only happens while the app is running and only if nothing else was copied since. How each platform does it: `knowledge/app-ui-architecture.md`, "Support helpers". Not verified on hardware: the link staying off Universal Clipboard, the iOS expiry and clipboard managers skipping the copy (`knowledge/device-test-checklist.md`, "Clipboard").
- A receipt in the Keychain lets the sender revoke the link; anyone holding the whole link can decrypt until it expires or is revoked.

### Build, update and release

- **Signing:** the DMG app is signed with a Developer ID certificate, hardened runtime and timestamp; the app and the DMG are notarized and stapled (`.github/workflows/release.yml`, `web/docs/content/getting-started/verify-downloads.md`). App Store builds go through Apple's signing and review.
- **Updates (Direct build only):** Sparkle 2 over HTTPS (`SPARKLE_FEED_URL` build setting in `app/CrocApp.xcodeproj/project.pbxproj`, read by `SUFeedURL`). The app carries the EdDSA public key (`SUPublicEDKey`) and installs an update only if the signature matches. `release.yml` fails the run if the appcast entry lacks `sparkle:edSignature` (around line 228). `SUEnableSystemProfiling` is `false` (`app/Config/CrocApp-Direct-Info.plist`). App Store builds contain no updater.
- **Provenance:** a GitHub build provenance attestation covers the DMG, the engine archive and `appcast.xml`, made after stapling (`actions/attest-build-provenance` in `release.yml`). Verification commands are in `web/docs/content/getting-started/verify-downloads.md`.
- **Pipeline hygiene:** third-party actions are pinned to commit SHAs; checkouts set `persist-credentials: false`; the release job runs in the `release` environment, which needs maintainer approval and allows only `main` and `v*` tags; the signing material is removed from the runner at the end of the job. Dependabot covers GitHub Actions, Go modules and Swift packages (`.github/dependabot.yml`).

## Privacy

CrocApp has no account system and no analytics or advertising code. History is a local SwiftData store (`TransferRecord`, `app/CrocApp/Models/TransferHistory.swift`) holding up to 20 file names per record, counts, sizes, a code hint and status, never the full code phrase or file contents (`web/docs/content/guide/history.md`). The **Save Transfer History** setting (on by default) stops new records. Transfer names leave the History screen in two ways. Shortcuts and Siri can read them through the Find Transfers action (`HistoryEntityQuery`), which answers only while **Save Transfer History** is on; any shortcut the user runs, and anything it passes on, sees them. The Spotlight index (`HistorySpotlightIndex.swift`) holds them too, so any process or person who can search Spotlight on that account sees file names and the direction, status, date and size. That index has its own switch, **Show History in Spotlight**, off by default, and turning it or Save Transfer History off removes every item CrocApp added (a failed removal is retried at the next change and at launch, so a name can linger until then). Neither surface ever carries a code phrase or code hint (`HistoryEntity`). The same holds for every glanceable surface (notifications, widgets, controls, the Live Activity, the menu bar and the Dock, Handoff): none shows a code phrase, a link (its `#` fragment is the key) or file contents, and a local notification (`TransferNotifier`) says only "Transfer complete", "Transfer failed" or that files wait for an answer, with the failure's title (which names no file). A notification can be read from a locked screen or by someone beside the Mac, so file names appear only after the user turns on **Show File Names in Notifications** (off by default), and then only the one name of a single file or a count, and the system hides the body when the user hides previews. The Dock badge shows a percent or "1". Notifications are posted to the system on the same device and go nowhere else (`knowledge/app-ui-architecture.md`, "System surfaces"). The Mac Services item **Send with CrocApp** reads only the selection the user hands it, stages it, and starts nothing; it takes at most 1 MiB of text. The servers the app can contact are listed in the [privacy policy](https://crocapp.dev/privacy/). The link page at `crocapp.dev/r/` makes no network request and sets a `no-referrer` policy. Every landing page (`web/landing/`) ships a `<meta http-equiv>` Content-Security-Policy with `default-src 'self'` and `connect-src 'self'`, so a page cannot call a third party even if script were injected (`knowledge/landing-page.md`, "Content-Security-Policy"). The pages load only their own files and keep only the theme choice in local storage.

## Design principles applied

Saltzer and Schroeder, with the evidence for each.

| Principle | How it shows up |
|---|---|
| Economy of mechanism | CrocApp implements no cryptography and does not fork croc. One bridge (`crocmobile/`), one Swift caller (`CrocEngine`), one state machine (`TransferController`). |
| Fail-safe defaults | Auto-accept off. Receive defaults to Keep Both; an unknown policy string never overwrites (`PolicyKeepBoth`, `parsePolicy`). The stdin answers queued behind an accept are always "n" (`keptPromptAnswers`, `crocmobile/session.go`). Link server must be `https`. |
| Complete mediation | Every incoming file list is checked on arrival (`ReceivedName.isUnsafe` in `TransferController`); Accept is disabled when a name is blocked (`TransferStatusView`), and under auto-accept the transfer is cancelled. The share extension manifest is re-validated on read: the batch name by `ShareHandoff.isValidBatchName`, each file name by `ReceivedName.isUnsafe`. |
| Open design | croc and CrocApp are open source; no secret algorithm. The only secrets are keys and passwords. |
| Separation of privilege | Releases need a maintainer approval of the `release` environment. Update signing (Sparkle EdDSA key) and app signing (Developer ID identity) are separate keys. |
| Least privilege | App sandbox; only the file-access and network entitlements listed in "App sandbox and entitlements"; share extension has no network; secrets in the data-protection Keychain (`kSecUseDataProtectionKeychain`, so macOS too) with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` and never synchronizable, not in `UserDefaults`; workflow `permissions` scoped per job. |
| Least common mechanism | One transfer at a time (`activeMu`), because croc mutates process-global state (`Chdir`, stdin and stdout). Network globals are restored on error and panic (`TestNetworkGlobalsRestoredAfterPanic`). |
| Psychological acceptability | A receive shows the file list and waits for the user. The trust badge names the route. Blocked names show a reason instead of failing silently. |
| Compromise recording | Build provenance attestations, notarization, signed updates; Send as Link receipts allow revoke. |

## Common weaknesses countered

| Weakness (CWE) | Countermeasure | Where | Pinned by |
|---|---|---|---|
| **Path traversal in received names** (CWE-22) | Names with an absolute path, `..` component, backslash, NUL or control character block the transfer. The check reads Unicode scalars, so a combining mark after `/` or `\` cannot hide the separator. croc applies its own receive-path policy as well (it refuses, for example, a name with a trailing space) | `app/Shared/ReceivedName.swift`, `TransferController` | `ReceivedNameTests` |
| **Spoofed names in the accept sheet** (CWE-451) | Names with a bidirectional control (U+202E turns `invoice<U+202E>fdp.exe` into what reads as `invoiceexe.pdf`) or a line or paragraph separator block the transfer, like an unsafe path. Every bidi control is blocked, including the LRM, RLM and ALM marks (conservative; `known-issues.md`). Other format characters stay allowed because real names need them (the joiner in emoji sequences, the non-joiner in Persian and Indic names, tag characters in subdivision flags). A name is drawn and recorded in its shown form: each such scalar is written as its code point (`ReceivedName.shown`), in the accept sheet, the progress line, the result list and the history record. A record an earlier build wrote still holds the raw name (`known-issues.md`) | `app/Shared/ReceivedName.swift`, `TransferController` | `ReceivedNameTests` |
| **Argument and command injection through names** (CWE-88, CWE-74) | A name with a line break cannot become extra send paths: refused in Swift before the join and split exactly in Go. `*` in a name is escaped so croc's glob sends only that file | `CrocEngine.joinedPaths`; `splitPaths`, `sendFilesInfo` in `crocmobile/` | `SendPathValidationTests`, `TestSplitPathsKeepsNamesExact`, `TestSendFilesInfoTakesPathsLiterally`, `FuzzSplitPaths` |
| **Integer overflow and wraparound** (CWE-190) | Declared sizes and sums are clamped to 1 PiB before they reach Swift; `relayPorts` checks the range without overflow | `addReported`, `maxReportedBytes` in `session.go`; `relayPorts` in `network.go` | `TestProgressSnapshotCapsDeclaredSizes`, `TestFileListJSONCapsDeclaredSizes`, the `relayPorts` tests in `network_test.go` |
| **Time-of-check changes after consent** (CWE-367 style) | After an accepted receive, a reconnecting sender cannot get a new file list accepted: the queued stdin answer is "n", so the receive ends. Existing files inside a zipped folder are kept even under Replace | `keptPromptAnswers`, `promptPolicyAnswers` in `session.go` | `TestAnswerUngatedPromptsNeverAccepts`, `TestPolicyAnswersFitPipeBuffer`, `TestDrainPromptInputClearsLeftoverAnswers` |
| **Missing authentication** (CWE-306) | The code phrase gates the exchange (PAKE); the relay hop has its own authentication; the receiver confirms the file list | croc (Key agreement and data protection, Relay and local network); `IncomingRequestView` | Interop harnesses (`scripts/verify-interop.sh`) |
| **Unrestricted resource use** (CWE-400) | One transfer at a time; stored sends capped by file count and size before anything is sent; reported sizes clamped; History capped per record and in total (`knowledge/app-ui-architecture.md`, "History"); the share extension activates for at most 25 files, images or movies of each type. No cap on total received size is added by CrocApp | `store.go` limits; `TransferHistory.swift`; `app/Config/CrocShare-Info.plist` | `TestStoreSendLimitsFailBeforeUpload`, `TestStoreSendOversizeFailsBeforeHashing` |
| **Cleartext storage and exposure of credentials** (CWE-312, CWE-532) | Relay password, proxy credentials and Send as Link receipts live in the Keychain, on this device only (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, never synchronizable), so a backup restored to another device does not carry them (an item an earlier build wrote keeps its old class until its next write); Keychain failures log the `OSStatus` only; a relay password or proxy whose Keychain write fails shows an error under its field instead of seeming saved, and the error never names the value; proxy validation errors never quote the value; History keeps a code hint, never the full code. | `KeychainStore.swift`, `AppSettings.swift`, `StoredTransferVault.swift`, `network.go` | `AppSettingsPersistenceTests`, `AppSettingsAdvancedTests`, `StoredTransferVaultTests`, `FuzzProxyURL`. The accessibility class is not pinned: a real Keychain needs a signed build, and CI builds unsigned |
| **Weak or broken cryptography** (CWE-327) | No custom cryptography. AES-256-GCM, HKDF-SHA256, HMAC-SHA256 and PAKE2 come from croc and pake; `crypto/rand` for secrets. The integrity hash is not used for security | croc v11.5.5, pake v3.2.0 | Not tested by CrocApp; relies on upstream |
| **Insecure transport for link server** (CWE-319) | `https` required, `http` allowed on loopback only; checked in Go (the settings field asks it) and again in Swift for a received link | `validateStoreOrigin`; `TransferLink`; `AppSettings.storedServerError` | `TestValidateSetting`, `SettingsValidationTests`, `TransferLinkTests`, `TestStoreReceiveRejectsBadLinks` |
| **Panic or crash from untrusted input** (CWE-248, CWE-476) | Exported Go entry points recover and report an error; delegate callbacks survive a panicking delegate; malformed JSON from the bridge becomes a failure event | `crocmobile.go`, `store.go`, `DelegateBridge.swift` | `TestStoreCallbacksSurviveAPanickingDelegate`, `TestReportPanicPayloadIsOther`, `TestNetworkGlobalsRestoredAfterPanic`, `DelegateBridgeTests` |
| **Update fetched without integrity check** (CWE-494) | Sparkle EdDSA verification over an HTTPS feed; release job fails without `sparkle:edSignature`; notarization; attestations | Build, update and release | `verify-downloads` steps; CI release rehearsal |
| **Vulnerable and outdated components** (CWE-1104) | `govulncheck`, `go vet`, `go test -race`, `golangci-lint` on every Go change (`.github/workflows/reusable-go.yml`); weekly 30 s run of each Go fuzz target (`go-weekly.yml`); CodeQL default setup; secret scanning with push protection; Dependabot | `.github/` | CI |
| **Unsafe handling of untrusted staged files** (CWE-73) | Share extension copies files with a unique batch directory per share (`batch-` and a UUID, from `ShareHandoff.makeBatchName`) and never reads payload into memory. The app treats a manifest whose batch name fails `ShareHandoff.isValidBatchName` as absent, so the name is never joined to a path, and re-validates each file name with `ReceivedName.isUnsafe`. The extension stages a file whose name `ReceivedName` rejects as `shared-file` | `ShareStager.swift`, `ShareInbox.swift`, `app/Shared/ShareHandoff.swift` | `ShareInboxTests` (the `shared-file` rename in `ShareStager` is not unit-tested) |

The path traversal, injection, overflow and time-of-check rows cover glob `*` in names, line breaks and text-direction controls in names, trailing-space names, a reconnect swapping the file list after accept, and impossible declared sizes. Receive does not overwrite existing files by default.

### Send staging

Photos, dropped and pasted images are copied into `SendStaging` under the temporary directory (`app-ui-architecture.md`, "Support helpers"). The folder is deleted by path, so the delete is the sensitive step. `SendStaging.discard` resolves the staging root once and builds the delete target from it plus the one slot name the caller's path carries, never from the caller's path. It refuses a symlink in the slot's place, and it needs a slot with an item below it, so a path that merely looks staged cannot remove the root, a sibling folder or a symlink's target. The check and the delete share one function, so what passes the check is exactly what is deleted. `SendStagingTests` covers a symlinked slot, a path outside the root, `..` segments and the root itself.

## Residual risks and accepted issues

| Risk | Status |
|---|---|
| No third-party audit of croc or CrocApp | Open. Stated on every surface that discusses security at length. |
| Protocol-level weaknesses in croc, PAKE or the relay design | Upstream scope (`SECURITY.md`). CrocApp tracks croc releases (`knowledge/croc-upgrade-playbook.md`). |
| croc prints the code phrase, and a non-default relay password, to stderr on every send | Accepted. Nothing in the app captures stderr; a Finder, Dock or Home Screen launch connects it to `/dev/null` (strong inference, not measured on a device). A harness or Xcode debug session does capture it. `known-issues.md`. |
| `release.yml` passes the signing `.p12` and keychain passwords on `security` argv | Accepted for a single-tenant runner. Do not run on a shared runner. |
| `create-dmg` is installed unpinned during the release build | Accepted. `known-issues.md`. |
| Secrets that earlier Mac builds wrote to the login keychain are no longer read or deleted by CrocApp | Accepted, no migration (the app has no users). Not a new exposure: the items keep the access control they were created with. Removal by hand: `known-issues.md`. |
| One maintainer approves releases, so there is no second reviewer on the `release` environment | Accepted. Disclosed in `SECURITY.md`, and `RELEASING.md` describes the approval gate. |
| Compromise of the Sparkle EdDSA private key or the `release` secrets | Would allow signed malicious updates or releases. Mitigation is limited to approval gating and attestation, which a compromised pipeline could also satisfy. |
| A sender can offer a very large total size; CrocApp adds no disk quota | The accept sheet shows the file list; the user decides. |
| `poll()` reads croc client fields without synchronization | Worst case is a wrong progress number; bounds-checked. `known-issues.md`. |
| `golang.org/x/crypto` GO-2026-5932 (`openpgp`) with no fixed version | Not imported or called (`govulncheck`). `known-issues.md`. |
| Metadata (IP, timing, volume) visible to relay and network | Accepted (Non-goals). |
| The trust badge names the configured route, not the path used | Accepted; the claim that the relay sees ciphertext holds on every path. |
| Entitlement exceptions: `network.server`, Sparkle mach-lookup (Direct build) | Each has a stated reason (App sandbox and entitlements). |

## Keeping this current

Follow `AGENTS.md`. Update this file in the same pull request when any of these change:

- the croc or pake version, curve defaults, or the Send as Link format;
- an entitlement, the App Group, the share extension's inputs, or the sandbox settings;
- where secrets are stored;
- the release workflow: signing, notarization, attestation, Sparkle keys or feed;
- a new weakness class gets a fix: add a row to Common weaknesses countered with its test.

Docs rules are in [`AGENTS.md`](AGENTS.md). Related: [`SECURITY.md`](../SECURITY.md), [`ARCHITECTURE.md`](ARCHITECTURE.md), [`known-issues.md`](known-issues.md), `web/docs/content/security-and-privacy.md`, `web/docs/content/getting-started/verify-downloads.md`.
