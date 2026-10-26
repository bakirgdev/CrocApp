# Apple platform constraints

Apple-side rules the app has to live inside. Each item says how it was checked:

- **Verified in this repo**: proven by code or a build here.
- **From Apple docs, not re-checked**: taken from Apple documentation. Apple changes these, so re-read the current docs (context7 or the web) before you write code against them.

## Hard constraints

### iOS background execution

- Raw TCP stops when the app is backgrounded. iOS has no background mode for arbitrary sockets, and background `URLSession` is HTTP only. (From Apple docs, not re-checked.)
- The lifeline is `BGContinuedProcessingTask` (iOS 26 and later, not macOS). The user starts it from the foreground, a system Live Activity is mandatory, `Progress` reporting is mandatory, and the identifier must be in `BGTaskSchedulerPermittedIdentifiers`. Runtime is best effort: the system kills tasks under pressure, low-progress ones first. (From Apple docs, not re-checked.)
- A transfer must therefore be resumable, and checkpoint when the task expires.
- In the foreground, set `isIdleTimerDisabled`.
- Verified in this repo: the system draws the Live Activity itself (title, subtitle, progress, cancel), so a custom ActivityKit widget is redundant.
- Verified in this repo: no `UIBackgroundModes` key is needed.
- Verified in this repo: `BGTaskSchedulerPermittedIdentifiers` accepts a wildcard (`prefix.*`) for continued-processing tasks.
- Verified in this repo: the handler registers dynamically just before submit, so nothing is needed in `didFinishLaunching`.
- Verified in this repo: the simulator always throws on `submit`, so a foreground-only fallback is mandatory.
- The code is `BackgroundCoordinator`.

### LAN discovery and multicast

- croc finds LAN peers with UDP multicast (schollz/peerdiscovery). On iOS that needs the restricted entitlement `com.apple.developer.networking.multicast`, which Apple grants per team and per profile type, TestFlight included. (From Apple docs, not re-checked.)
- The entitlement has been requested and is pending. The iOS entitlements file does not have it yet, so 1.0 ships without it, and the iOS multicast setting is hidden.
- Bonjour (`NWBrowser`, `NWListener`) needs no entitlement, but the stock croc command line cannot discover a Bonjour peer because the protocols differ.
- Without the entitlement the relay path still works. Only the LAN race is lost.

### Other hard limits

- **Share extension**: about 120 MB memory, no long-running work, no `BGContinuedProcessingTask`. The pattern is `NSItemProvider.loadFileRepresentation`, a stream copy into the App Group container, then the main app runs the transfer. (From Apple docs, not re-checked.)
- **No process spawning on iOS**, so croc is linked as a library only.
- **Mac App Store requires the sandbox.** The app uses `com.apple.security.network.client` and `.server` (the server entitlement is for the local relay listener), plus `files.user-selected.read-write` and `files.downloads.read-write`. Verified in this repo (`app/CrocApp/CrocApp.entitlements`). The direct download needs notarization and the hardened runtime; the sandbox is optional there.
- **Wi-Fi Aware** (iOS and iPadOS 26) gives AirDrop-class direct Wi-Fi but does not exist on macOS 26. It could only be an optional iOS-to-iOS fast path, never the main transport. (From Apple docs, not re-checked.)

## Papercuts

### Local network permission

- Needs `NSLocalNetworkUsageDescription` and `NSBonjourServices` in `Info.plist`. The prompt appears on the first LAN operation. Relay (WAN) traffic does not trigger it. Apple's TN3179 is the authority.
- Denial fails silently, and the OS has known flakiness: no re-prompt after reinstall, or "granted" yet broken until a toggle or reboot. The app needs a pre-flight check and diagnostics. (From Apple docs, not re-checked.)
- Verified in this repo: no official API reports the authorization state, including on iOS 26. `LocalNetworkChecker` runs a Bonjour self-probe instead: a browser stuck in `.waiting` until timeout means denied.
- The probe itself raises the prompt, so never treat the first `.waiting` as a denial.

### Files and storage

- Files from `fileImporter` are security-scoped URLs. Call `startAccessingSecurityScopedResource`, and keep bookmarks to resume across launches.
- Received files show in the Files app only with `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace`.

### Build tooling

- gomobile breaks now and then on new Xcode major versions. Budget time for it.
- Verified in this repo: Xcode 27.1 with Go 1.27.3 builds cleanly. The macOS slice of the xcframework must be arm64 only (golang/go#73119). The device framework layout problem (golang/go#66500) is fixed in the x/mobile version pinned here, and App Store Connect accepted the upload (`../RELEASING.md`, "App Store builds").

### macOS app behavior (verified in this repo)

- Declaring `CFBundleDocumentTypes` makes AppKit treat bare launch arguments as documents to open. Two adjacent bare arguments leave the app without a default window, so test harnesses must pass flag-style arguments.
- Declaring `CFBundleDocumentTypes` also makes Xcode inject `LSSupportsOpeningDocumentsInPlace = NO`, which fails validation. Override it with `INFOPLIST_KEY_LSSupportsOpeningDocumentsInPlace[sdk=macosx*] = YES`.
- A scripted launch hangs in window restoration unless you pass `-ApplePersistenceIgnoreState YES`.
- `xcodebuild archive` for generic macOS ignores `ONLY_ACTIVE_ARCH`. Pass `ARCHS=arm64` while the xcframework macOS slice is arm64 only.
- With the sandbox on, croc's local relay listener binds TCP 9009 (confirmed with `lsof`).
- `syspolicy_check distribution` checks notarization readiness without submitting.

### Other

- `BGContinuedProcessingTask` lowers QoS in the background, so transfers run slower. That is acceptable.
- Liquid Glass: standard SwiftUI controls restyle for free on the Xcode 26 and later SDKs. Custom chrome needs `.glassEffect()`. The compatibility opt-out flag goes away in the next major OS. (From Apple docs, not re-checked.)
- The iOS 26 Network framework has a Swift API (`NetworkConnection`, `NetworkListener`, `NetworkBrowser`) that is preferred over `NWConnection` callbacks. (From Apple docs, not re-checked.)

## App Store review

Other file-transfer apps built on the same ideas (croc and wormhole clients, LocalSend) are on the App Store, and an embedded Go runtime is allowed. This is inferred from those apps, not from a ruling by Apple.

Two low risks remain:

- Explain the code phrase model and the default public relay in the review notes (`app-store-listing.md`, "Review notes").
- Do not imply that croc's author endorses the app. Naming and branding fall under guideline 5.2.
