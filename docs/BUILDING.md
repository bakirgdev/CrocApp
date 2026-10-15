# Building CrocApp from source

Deep reference for the exact toolchain and the exact steps from a fresh clone to a running app. `README.md` ("Build from source") and `CONTRIBUTING.md` ("Setup") carry the short version and link here for detail; this file grounds every version, flag, and path they use, it does not restate them.

## 1. Prerequisites

| Tool | Required version | Pinned in | Install (macOS) |
|---|---|---|---|
| Host OS | macOS 26 | README, CONTRIBUTING.md | — |
| Xcode | `27.0` | `.xcode-version` | Apple Developer downloads, or `xcodes install 27.0` |
| Go | `>= 1.27.2` | `crocmobile/go.mod` (`go 1.27.2`) | `brew install go` |
| gomobile / gobind | pinned by the `tool` block in `crocmobile/go.mod` (`golang.org/x/mobile`) | `scripts/build-xcframework.sh` rebuilds both into `.tools/` on every run | nothing to install by hand |
| swift-format | ships with the Xcode 27.0 toolchain (`docs/knowledge/tooling.md` records the bundled toolchain as Swift 6.4) | `.swift-format` (formatting rules; the binary itself is not separately versioned in this repo) | none, invoke via `scripts/format-swift.sh` |
| golangci-lint | `2.x`; CI pins `v2.14.0` exactly | `.github/workflows/reusable-go.yml` (`golangci-lint-action`, `version: v2.14.0`); rule config in `crocmobile/.golangci.yml` (`version: "2"` schema) | `brew install golangci-lint` |
| govulncheck | pinned by the `tool` block in `crocmobile/go.mod` (`golang.org/x/vuln`) | `.github/workflows/reusable-go.yml` (called by `ci.yml`, `release.yml`, `go-weekly.yml`) | `cd crocmobile && go tool govulncheck ./...` |
| create-dmg | unpinned | `.github/workflows/release.yml` installs it with `brew` | `brew install create-dmg`. Needed only by `scripts/build-dmg.sh`, not for a plain build |
| croc CLI | `v11.5.4`, to match the embedded engine | `crocmobile/go.mod` (`github.com/schollz/croc/v11 v11.5.4`) | `brew install croc` (lands at `$HOMEBREW_PREFIX/bin/croc`, the harnesses' default). Needed only for `scripts/verify-*.sh` and `crockit-verify`, not for a plain build |

## 2. First build from a fresh clone

Nothing Swift builds before the xcframework exists. `CrocKit/Package.swift` declares:

```swift
.binaryTarget(name: "Croc", path: "Croc.xcframework"),
```

`CrocKit/Croc.xcframework/` is gitignored (`.gitignore`, "gomobile build output: xcframework not committed"), so a fresh clone has no file there and every Swift build fails until one exists. `scripts/build-xcframework.sh` is step one, not optional.

```bash
# from the repo root
git clone https://github.com/bakirgdev/CrocApp.git
cd CrocApp
scripts/build-xcframework.sh   # Go engine -> CrocKit/Croc.xcframework
open app/CrocApp.xcodeproj
```

The shared schemes `CrocApp` (builds the app, tests `CrocAppTests`), `CrocApp Direct` (the Developer ID build, section 7, no test action) and `CrocShare` are committed under `app/CrocApp.xcodeproj/xcshareddata/xcschemes/`, so `xcodebuild -scheme CrocApp` works on a fresh clone without opening Xcode. A new target needs its scheme committed there too; per-user schemes in `xcuserdata/` stay gitignored.

Command-line builds, exactly as CLAUDE.md and CI run them:

```bash
# from app/
xcodebuild -scheme CrocApp -destination 'platform=macOS' -derivedDataPath /tmp/dd-mac build
xcodebuild -scheme CrocApp -destination "platform=iOS Simulator,name=$SIM" -derivedDataPath /tmp/dd-sim build
```

`SIM` defaults to `iPhone 17 Pro` (used the same way in `scripts/verify-app-sim.sh`, `scripts/verify-share-sim.sh`, and CLAUDE.md). List installed runtimes with `xcrun simctl list devices`.

## 3. What build-xcframework.sh actually does

From the repo root, the script `cd`s into `crocmobile/`, runs `go mod download`, then:

```bash
gomobile bind \
  -target ios,iossimulator,macos/arm64 \
  -iosversion 26.0 -macosversion 26.0 \
  -o "../CrocKit/Croc.xcframework" \
  .
```

- **Targets**: `ios`, `iossimulator`, `macos/arm64`. Only an arm64 macOS slice, no `macos/amd64`.
- **`-iosversion` / `-macosversion`**: both `26.0`, matching the deployment target everywhere else in the repo (section 6).
- **Output**: `CrocKit/Croc.xcframework`, removed and rebuilt on every run (`rm -rf "$OUT"` before binding).
- **Why arm64-only on macOS**: [golang/go#73119](https://github.com/golang/go/issues/73119), gomobile cannot currently produce a multi-arch macOS bind. `Croc.xcframework` therefore has no `x86_64` slice, and Intel Macs that can otherwise run macOS 26 (the 2019 MacBook Pro 16", 2020 iMac, and 2019 Mac Pro) cannot run CrocApp. The pbxproj pins `ARCHS[sdk=macosx*] = arm64` for this reason; removing that pin does not restore Intel support, it just breaks the link.
- **iOS device archives**: [golang/go#66500](https://github.com/golang/go/issues/66500) is a device-slice layout issue that affects App Store archives specifically, not simulator or local device builds. It is closed (fixed in x/mobile CL 574055 and 575115, included in our pin), and the first App Store upload on 2026-10-14 passed validation (section 7, "App Store builds").

`gomobile`/`gobind` are built from the `golang.org/x/mobile` version in the `tool` block of `crocmobile/go.mod`. If a future release regresses the bind, pin `x/mobile` to the last good version there and record it in `docs/knowledge/tooling.md`.

## 4. Format and lint

Exact command CI runs, from the repo root:

```bash
scripts/format-swift.sh --lint
```

That is the only Swift check the `swift-format` CI job runs. Locally, drop the flag to rewrite in place first; the script lints afterwards either way:

```bash
scripts/format-swift.sh
```

The script owns the list of paths swift-format covers (`app/CrocApp`, `app/CrocAppDirect`, `app/CrocShare`, `app/CrocAppTests`, `CrocKit/Sources`, `CrocKit/Tests`, `CrocKit/Package.swift`). A new Swift target goes in there, so CI and every doc pick it up at once. `CrocKit` is listed file-by-file because a recursive run there descends into `.build/` and `Croc.xcframework/`.

**Trap**: `format --in-place` does not fix lint-only rules, several enabled rules only flag and never rewrite (for example `ReplaceForEachWithForLoop`, `OnlyOneTrailingClosureArgument`, `AlwaysUseLowerCamelCase`). A clean `format` run is not evidence `lint --strict` will pass, which is why the script always runs both. Full list and rationale: `docs/knowledge/tooling.md`.

Go, from `crocmobile/`:

```bash
go build ./...
go vet ./...
env -u GOOS -u GOARCH go test -race ./...
golangci-lint run ./...
govulncheck ./...
```

Unit tests for Swift, after `scripts/build-xcframework.sh`:

```bash
swift test --package-path CrocKit
(cd app && xcodebuild test -scheme CrocApp -destination 'platform=macOS')
```

`go build`/`go vet` are what CI's go job runs alongside tests, lint and vuln, under `GOOS=darwin GOARCH=arm64` (the job analyzes the platform the code ships on, on a cheap Linux runner). If you install `govulncheck` yourself in a shell that already has `GOOS`/`GOARCH` set, see the troubleshooting table below, `go install` will silently misplace the binary.

## 5. Verification harnesses

A green build is **not** evidence a transfer works. CI runs only `verify-interop.sh`, against a local relay (job `interop (local relay)`, `docs/knowledge/tooling.md`). The other harnesses and the public-pool scenario need a public relay or a device and are flaky on shared runners, so running them is on whoever touched the transfer path.

| Harness | Proves | Needs | Env vars |
|---|---|---|---|
| `scripts/verify-interop.sh` | 15 scenarios, crocmobile (via its `croctest` CLI) ↔ croc CLI: file/folder/text both directions, decline, cancel both directions, forced relay, LAN-only, a croc v10 peer in both directions (R8: crocmobile reports failure code `peerVersion`), every public pool relay in both directions (LAN off, asserting which relay each side used), and the receive file policy (12: a file onto an existing one with Keep Both and Replace, answered at the prompt and preset with `-yes`, then a zipped folder received twice with each policy and accept mode), and the transport (13: a 130 MiB send in each of `auto` and `relay`, both directions, asserting byte equality and that the CLI `--debug` log shows a `tailcat-offer` under `auto` and none under `relay`), and stored transfers (14: against a loopback `croctest store-server`, a wrapper upload downloaded by the CLI, a CLI upload downloaded by the wrapper, a revoke after which the download fails, and an existing name with Keep Both, Replace and a declined preview), and the Advanced options that change the wire (15, each against the CLI with the matching flag: curve, hash, base port with transfers and the sender IP, multicast group, SOCKS5 and HTTP proxy, internal DNS; the curve and hash cases assert which side's setting the other adopts, a mismatch included). With `RELAY` set every transfer uses that relay and the pool (11), transport (13), proxy and internal DNS (15) scenarios are skipped; 14 and the rest of 15 need no public relay and still run | croc CLI, croc v10 CLI (`scripts/croc-v10.version`), outbound network (public relay) unless `RELAY` is set | `CROC`, `CROC_V10`, `RELAY` |
| `scripts/verify-app-mac.sh` | macOS app, 12 scenarios: CLI→app receive (plus SwiftData history), app→CLI send, `--local`, custom self-hosted relay, `--no-compress`, `--ask` (both sides confirm), and a CLI send onto an existing file received with `--when-exists keepBoth|replace` (prints `MAC-COLLIDE-OK`), and a 130 MiB transfer in each direction under `--transport auto` and `--transport relay` (prints `MAC-TRANSPORT-OK`); then stored transfers (9, `MAC-STORE-OK`), a send started through the menu-bar view model with a file and with clipboard text (10, `MAC-MENUBAR-OK`; it saves and restores the text on the pasteboard), Open at login following `SMAppService.status` (11, `MAC-LOGIN-OK`; it registers the login item and unregisters it again), and the three Shortcuts actions run through their `perform()` against the CLI (12, `MAC-INTENT-OK`; the receive saves into the real `~/Downloads/CrocApp` and deletes the file); in the app-as-sender scenarios the CLI receiver starts only after the app writes `verify-code-ready.txt` | outbound network (scenario 8 also reaches `tailcat.dev`), croc CLI, a macOS app build | `CROC` |
| `scripts/verify-app-sim.sh` | iOS simulator, CLI→app via the `--auto-receive` launch argument, gated on a byte-identical diff | outbound network, croc CLI, an iOS Simulator | `CROC`, `SIM` |
| `scripts/verify-share-sim.sh` | Share-extension handoff: files staged into the App Group container the way `CrocShare` does, app launched with `--auto-share-send`, received by the croc CLI (the receiver starts only after the app writes `verify-code-ready.txt`, since a receiver that joins the room first fails) | outbound network, croc CLI, an iOS Simulator | `CROC`, `SIM` |
| `crockit-verify` (run via `swift run --package-path CrocKit crockit-verify send\|receive\|twice ...`) | Swift-layer send/receive, cancel fired mid-wire, and two transfers back-to-back in one process (proves fd0/stdout/cwd/mutex restoration composes) | outbound network, croc CLI, macOS only | optional `CROC_RELAY`, `CROC_PASS` to point at a private relay |

`CROC` overrides the CLI path (default `$HOMEBREW_PREFIX/bin/croc`, falling back to `/opt/homebrew/bin/croc`); `SIM` picks the simulator (default `iPhone 17 Pro`). `CROC_V10` is the croc v10 binary for `verify-interop.sh` scenario 10 (default `$HOME/go/bin/croc`; install with `go install github.com/schollz/croc/v10@$(cat scripts/croc-v10.version)`), and the script fails at start if it is not the version in `scripts/croc-v10.version`. `RELAY=host:port` sends every transfer of `verify-interop.sh` through that relay instead of the public pool. CI raises the local relay's admission limits as a margin, because every connection comes from 127.0.0.1 and croc v11's relay admits 30 joins a minute per address by default (a run on default limits passed on 2026-10-13):

```bash
croc relay --host 127.0.0.1 --ports 9309,9310,9311,9312,9313 --source-join-limit 1000 --room-join-limit 1000
RELAY=127.0.0.1:9309 scripts/verify-interop.sh
```

Local signed macOS builds of `CrocApp` need a provisioning profile, because `app/CrocApp/CrocApp.entitlements` carries Associated Domains (`applinks:crocapp.dev`). `scripts/verify-app-mac.sh` and `scripts/capture-screenshots.sh` therefore pass `-allowProvisioningUpdates` to their macOS `xcodebuild`, and Xcode needs an account in team `HBSU359M33`. The first time on a new Mac, also pass `-allowProvisioningDeviceRegistration` once so the Mac is registered as a development device. A contributor outside that team cannot sign these builds; unsigned builds (`CODE_SIGNING_ALLOWED=NO`, what CI does) still work.

A harness case that tests an answer given mid-transfer must start the transfer with the opposite or default setting, or it proves only the start options: `croctest -policy` sets the Options only under `-yes`, and `AutoVerify --when-exists` answers the sheet without touching `settings.whenFileExists`.

Any change to `crocmobile/session.go`, `CrocKit/Sources/`, or `TransferController` needs the matching harness run, its output quoted, not summarized. If a harness could not be run, say "not verified" and why.

## 6. Build settings that must not be casually changed

- **Swift 6 language mode everywhere.** `SWIFT_VERSION = 6.0` on every target (`CrocApp`, `CrocApp Direct`, `CrocShare`, `CrocAppTests`, all build configurations, `app/CrocApp.xcodeproj/project.pbxproj`) and `CrocKit`'s `swift-tools-version: 6.0`. On top of that, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES`: types are MainActor-isolated by default, `nonisolated` is the explicit opt-out, and strict concurrency violations are build errors, not warnings.
- **Deployment target is `26.0` everywhere, never a minor.** `IPHONEOS_DEPLOYMENT_TARGET = 26.0` and `MACOSX_DEPLOYMENT_TARGET = 26.0` in the pbxproj, `platforms: [.iOS("26.0"), .macOS("26.0")]` in `CrocKit/Package.swift`, and `-iosversion 26.0 -macosversion 26.0` in `scripts/build-xcframework.sh`. All four must move together.
- **macOS is arm64-only.** `"ARCHS[sdk=macosx*]" = arm64` in the pbxproj. `Croc.xcframework` has no `x86_64` macOS slice (golang/go#73119, section 3), so this pin exists to fail the link cleanly rather than let an Intel archive attempt one that cannot succeed.
- **One version source, `app/Config/Version.xcconfig`.** It holds `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` and is the base configuration of the project-level Debug and Release configurations, so every target inherits it. Do not set either in a target's build settings. The build number is bumped in its own commit before each upload or tag, and `release.yml`'s tag check reads `MARKETING_VERSION` from this file. A tag run also fails when the build number is not above every build in the published `appcast.xml`, because Sparkle only offers a higher `CFBundleVersion`; a rehearsal only warns.
- **Go toolchain pin, `>= 1.27.2` in `crocmobile/go.mod`.** Bumping it means rerunning `scripts/build-xcframework.sh` to confirm the bind still works on the new toolchain before trusting anything downstream.

## 7. Distribution builds

`scripts/build-devid.sh [out-dir]` builds the signed, notarized, stapled macOS disk image (default out-dir `dist`, output `CrocApp-<version>-arm64.dmg`). It does, in order:

1. Resolves the "Developer ID Application" identity for team `HBSU359M33` by SHA-1 and archives the `CrocApp Direct` scheme (Release, arm64) with manual signing and the provisioning profile "CrocApp Direct Developer ID". Prints `archive: OK`.
2. Exports with `Config/ExportOptions-DevID.plist` and runs `codesign --verify --strict --deep`. Prints `DEVID-EXPORT-OK`.
3. Zips the app, notarizes it (`xcrun notarytool submit --wait`), staples it, and runs `syspolicy_check distribution` on the stapled app. Prints `DEVID-APP-NOTARIZED-OK`.
4. Builds the DMG with `scripts/build-dmg.sh` (prints `DMG-OK`), signs it with a timestamp, notarizes and staples it, then runs `stapler validate` and `spctl -a -vv -t open --context context:primary-signature`. Prints `DEVID-NOTARIZED-OK`.

The app and the DMG are notarized separately, so an app copied out of the image opens offline on first launch. The script exits 1 when no Developer ID identity is present (it used to print `DEVID-PENDING-CERT` and exit 0). `syspolicy_check notary-submission` is not used: on macOS 27 it fails every app that is not yet notarized ("Gatekeeper rejected this file", spctl `source=Unnotarized Developer ID`), so a real notarization problem is read from the notary log instead. `syspolicy_check distribution` needs a stapled app, which is why it runs after the app's notarization. A local run passed with both submissions `Accepted`, both staples validated and spctl reporting `accepted, source=Notarized Developer ID`.

To run it locally you need:

- a "Developer ID Application" identity for team `HBSU359M33` in the keychain search list (created at developer.apple.com, Certificates)
- the "CrocApp Direct Developer ID" profile in `~/Library/Developer/Xcode/UserData/Provisioning Profiles/`
- the notary credentials as a keychain profile, by default `crocapp-notary`: `xcrun notarytool store-credentials crocapp-notary --key <p8> --key-id <id> --issuer <issuer>`. Set `NOTARY_KEYCHAIN_PROFILE` to use another name, or `NOTARY_KEY`, `NOTARY_KEY_ID` and `NOTARY_ISSUER` (the CI form) to pass the App Store Connect key directly
- `brew install create-dmg`

`DEVID_WORK` sets the scratch directory (archive, DerivedData, logs).

`.github/workflows/release.yml` runs the same script. It starts on a `v*` tag push or on `workflow_dispatch`. A tag run checks the tag against `MARKETING_VERSION` and the dated `CHANGELOG.md` heading, builds, signs, notarizes, writes a signed `appcast.xml` (Sparkle's `generate_appcast`, seeded with the latest release's appcast, the CHANGELOG section embedded as release notes), attests the stapled files, and publishes the DMG, `appcast.xml`, the `Croc.xcframework` zip and `SHA256SUMS.txt`. A `workflow_dispatch` run is a rehearsal: it skips the tag and CHANGELOG checks and the publish job, and publishes nothing. The build job runs in the `release` environment (required reviewer, deployment policy limited to branch `main` and tags `v*`), which holds seven secrets:

| Secret | Holds |
|---|---|
| `DEVID_P12_BASE64` | Developer ID Application certificate and key, base64 `.p12` |
| `DEVID_P12_PASSWORD` | `.p12` password |
| `DEVID_PROFILE_BASE64` | "CrocApp Direct Developer ID" profile, base64 |
| `ASC_KEY_P8` | App Store Connect API key (`.p8` text) used by `notarytool` |
| `ASC_KEY_ID` | that key's ID |
| `ASC_ISSUER_ID` | that key's issuer ID |
| `SPARKLE_ED_PRIVATE_KEY` | Sparkle Ed25519 release private key, passed to `generate_appcast` on stdin |

Before it signs the appcast, the workflow checks that `SPARKLE_ED_PRIVATE_KEY` matches the built app's `SUPublicEDKey`, and after, that the new item carries `sparkle:edSignature`: on a mismatched key `generate_appcast` only warns, exits 0 and writes the item unsigned, which every client rejects.

A dispatch rehearsal can only run once this workflow is on `main`, because dispatch needs the workflow on the default branch and the environment allows `main`. It has not run yet (`docs/known-issues.md`, "Harnesses").

Three export option files, all under `app/Config/`:

| File | `method` | Channel |
|---|---|---|
| `ExportOptions-DevID.plist` | `developer-id` | Direct-download DMG: manual signing, `signingCertificate` "Developer ID Application", profile "CrocApp Direct Developer ID" for `com.bakirgdev.CrocApp.direct` (the `CrocApp Direct` target); exercised by `scripts/build-devid.sh` |
| `ExportOptions-iOS.plist` | `app-store-connect` | iOS App Store and TestFlight, from the `CrocApp` scheme on `generic/platform=iOS`; automatic signing; exercised by `scripts/build-appstore.sh` |
| `ExportOptions-MAS.plist` | `app-store-connect` | Mac App Store and TestFlight, from the `CrocApp` scheme on `generic/platform=macOS`; same keys as the iOS file; exercised by `scripts/build-appstore.sh` |

All three share `teamID` `HBSU359M33` and `destination` `export`. The two App Store files also set `signingStyle` `automatic` and `manageAppVersionAndBuildNumber` false. `build-appstore.sh --upload` leaves them alone: it sets `destination` to `upload` in a scratch copy, so the committed files always describe an export to disk.

The `CrocApp Direct` target is the Developer ID channel. It is macOS only and arm64, with bundle ID `com.bakirgdev.CrocApp.direct` and product `CrocApp.app` (the same product name as the App Store target). Its sources are the `app/CrocApp/` synchronized group plus `app/CrocAppDirect/`, built with the Swift condition `DIRECT`. It links Sparkle 2.10.0 (SwiftPM, this target only) and shows "Check for Updates…" in the app menu. Because both targets produce `CrocApp.app`, in one shared DerivedData each scheme's build replaces the other's `CrocApp.app`; the harness scripts and CI use their own `-derivedDataPath`, or build Direct last.

`SPARKLE_PUBLIC_ED_KEY` on the Direct target is set to the owner's release public key. The key was made as plain text with `openssl genpkey -algorithm ed25519` (the base64 raw 32-byte private seed and public key, the format step 1 of the procedure below makes), not with Sparkle's `generate_keys`, which stores it in the keychain; the owner keeps the private key and it is the `SPARKLE_ED_PRIVATE_KEY` secret. `SPARKLE_FEED_URL` is `https://github.com/bakirgdev/CrocApp/releases/latest/download/appcast.xml`.

### Testing a Sparkle update locally

Proves a Release `CrocApp Direct` build installs a newer one. It uses a throwaway Ed25519 key, never the release key, and a feed on localhost (Sparkle accepts an `http` localhost feed and only logs a warning about HTTPS; no ATS exception is needed).

Sparkle's tools come with the package: `<DerivedData>/SourcePackages/artifacts/sparkle/Sparkle/bin/`. Work in a scratch directory with a `feed/` folder.

1. Throwaway key (raw 32-byte seed and public key, base64):
   ```bash
   openssl genpkey -algorithm ed25519 -out key.pem
   openssl pkey -in key.pem -outform DER | tail -c 32 | base64 > priv.b64
   openssl pkey -in key.pem -pubout -outform DER | tail -c 32 | base64 > pub.b64
   ```
2. Build twice, as build 1 and build 2, from `app/`:
   ```bash
   for N in 1 2; do
     xcodebuild -scheme 'CrocApp Direct' -configuration Release -destination 'platform=macOS' \
       -derivedDataPath "dd$N" -allowProvisioningUpdates CURRENT_PROJECT_VERSION=$N \
       "SPARKLE_PUBLIC_ED_KEY=$(cat pub.b64)" SPARKLE_FEED_URL=http://127.0.0.1:8765/appcast.xml build
   done
   ```
3. Zip build 2 into `feed/` and write the signed appcast:
   ```bash
   ditto -c -k --sequesterRsrc --keepParent dd2/Build/Products/Release/CrocApp.app feed/CrocApp-2.zip
   generate_appcast --ed-key-file - --download-url-prefix http://127.0.0.1:8765/ feed < priv.b64
   ```
4. Serve it: `cd feed && python3 -m http.server 8765 --bind 127.0.0.1`.
5. Copy build 1 somewhere writable (`ditto dd1/Build/Products/Release/CrocApp.app apps/CrocApp.app`), launch it, choose "Check for Updates…", then "Install Update", then "Install and Relaunch" in Sparkle's standard UI. From the second launch on, Sparkle first asks about automatic checks.
6. Expect the old process to exit, a new process to start, and `apps/CrocApp.app` to report `CFBundleVersion` 2.

4 of 5 runs of this procedure passed; the first run hung after "Install and Relaunch" (`docs/known-issues.md`, "Harnesses").

### App Store builds

`scripts/build-appstore.sh [--upload] [ios|macos]...` builds the `CrocApp` scheme (Release) for the App Store channels. No platform argument means both. For each platform it:

1. Archives for `generic/platform=iOS` or `generic/platform=macOS` and prints `<platform> archive: OK`.
2. Runs `xcodebuild -exportArchive` with `ExportOptions-iOS.plist` or `ExportOptions-MAS.plist`.
   - Without `--upload`, it writes `CrocApp.ipa` (iOS) or `CrocApp.pkg` (macOS) to the scratch directory and prints `APPSTORE-EXPORT-OK <platform>`. Nothing leaves the Mac.
   - With `--upload`, it sets `destination` to `upload` in a scratch copy of the plist and sends the build to App Store Connect (TestFlight). It prints `APPSTORE-UPLOAD-OK <platform>`.

`APPSTORE_WORK` sets the scratch directory (archives, DerivedData, per-step logs); the script deletes it first. On failure the script prints the tail of the failing log and its path.

To run it you need:

- Xcode signed in to the Apple ID that belongs to team `HBSU359M33` (Settings > Accounts). Signing is automatic and cloud-managed through `-allowProvisioningUpdates`, so no Apple Distribution or Mac Installer certificate has to be in the keychain.
- `CrocKit/Croc.xcframework` built (`scripts/build-xcframework.sh`).
- The App Store Connect record "CrocApp" (iOS and macOS on one record, bundle ID `com.bakirgdev.CrocApp`).
- A build number App Store Connect has not seen for this version. The build number is always `CURRENT_PROJECT_VERSION` in `app/Config/Version.xcconfig` (`manageAppVersionAndBuildNumber` is false), and App Store Connect refuses a number it has already seen for that `MARKETING_VERSION`. Bump it in its own commit before every upload, then run the script without `--upload` first if the change is in doubt.

First upload: 2026-10-14, iOS and macOS 1.0.0 (1). Both ended `** EXPORT SUCCEEDED **` and `Uploaded package is processing`. Things it taught:

- **`MinimumOSVersion = 100.0`.** gomobile writes this into the framework `Info.plist` (x/mobile `bind_iosapp.go`, a SwiftPM workaround). The upload accepted it, so `build-xcframework.sh` is not patched. [golang/go#66500](https://github.com/golang/go/issues/66500) is closed, fixed in x/mobile CL 574055 and 575115, which our pinned x/mobile includes.
- **"Upload Symbols Failed".** The only warning, for `Croc.framework` (iOS) and `A` (macOS). Xcode embeds a 50 KB stub `Croc.framework` dylib with no dSYM, because the gomobile xcframework is a static archive linked into the app binary. It is not an ITMS warning (`docs/known-issues.md`, "Accepted").
- **App category.** `LSApplicationCategoryType` is `public.app-category.utilities`, set as `INFOPLIST_KEY_LSApplicationCategoryType` on `CrocApp` and `CrocApp Direct`. Without it the macOS archive warned "No App Category is set".
- **Privacy manifest.** `app/CrocApp/PrivacyInfo.xcprivacy` declares required-reason APIs the Go engine reaches: `FileTimestamp` (`C617.1`, `3B52.1`) and `SystemBootTime` (`35F9.1`), besides `UserDefaults` (`CA92.1`). The engine is linked statically into the app binary and imports `stat`, `fstat`, `fstatat`, `lstat` and `mach_absolute_time` (`nm -u`); it does not import `statfs`, `statvfs` or `getattrlist`, so there is no `DiskSpace` entry. Whether the processed builds trigger an ITMS-91053 email is not known until the owner checks the developer-account mail (Owner steps, below).
- **Export compliance** failed the first attempt; see the next section.

### Export compliance

Both app `Info.plist` files (`app/Config/CrocApp-Info.plist`, `CrocApp-macOS-Info.plist`) set `ITSAppUsesNonExemptEncryption` to `false`. The first upload attempt, with `true` and no `ITSEncryptionExportComplianceCode`, failed with `Invalid Export Compliance Code. The export compliance key value [] in the app's Info.plist doesn't match the key value of the app's export compliance documentation.`

`false` is a legal position, not only a way past the check: croc's encryption (AES-256-GCM, PAKE) is standard and its source is public, so the app relies on the open-source exemption (EAR 742.15(b), the owner's 1.0 decision). Apple's own table makes `false` coherent only while France is excluded, so 1.0 ships without France in its availability, and a `future` issue adds France after an ANSSI declaration (the key then becomes `true` with an issued code). The research, the exact answers to give if App Store Connect still asks, and the open SIEC question are in `docs/knowledge/app-store-listing.md`, "Export compliance"; the owner's two actions are in `docs/known-issues.md`, "Release". If the exemption does not hold, set the key to `true` and add the `ITSEncryptionExportComplianceCode` that App Store Connect issues after the documentation is approved.

### Owner steps

Everything below is done by a person, not by a script. It is written so the next release can repeat it. IDs in brackets match the release plan. Each step is marked done (with the date) or remaining.

1. **Agreements, tax and banking.** Done 2026-10-12. In App Store Connect, accept the Free Apps and Paid Apps agreements, fill in tax and bank details, and declare EU Digital Services Act trader status with public contact details. Before each release, check that no agreement shows as pending or needing re-acceptance.
2. **Developer ID Application certificate [O1].** Done 2026-10-12.
   1. At developer.apple.com, Certificates, create a "Developer ID Application" certificate (a certificate signing request comes from Keychain Access, Certificate Assistant). Download it and double-click it to install into the login keychain.
   2. Check it: `security find-identity -v -p codesigning` lists "Developer ID Application" for team `HBSU359M33`.
   3. In Keychain Access, export the certificate with its private key as a `.p12` with a password. Keep the `.p12` and the password in the password manager. They become the `DEVID_P12_BASE64` and `DEVID_P12_PASSWORD` secrets (step 7).
3. **Notarization API key [O2].** Done 2026-10-12, verified 2026-10-14. In App Store Connect, create a team API key named "CrocApp notarization" with the Developer role (the role is enough for `notarytool`). Download the `.p8` (Apple offers it once) and note the Key ID and Issuer ID; keep all three in the password manager. Then, in a terminal:
   ```bash
   xcrun notarytool store-credentials crocapp-notary --key <p8 path> --key-id <key id> --issuer <issuer id>
   xcrun notarytool history --keychain-profile crocapp-notary
   ```
   The second command answering confirms the key works. The three values are also the CI secrets `ASC_KEY_P8`, `ASC_KEY_ID` and `ASC_ISSUER_ID`.
4. **Bundle IDs and the App Store Connect record [O4].** Done.
   1. `com.bakirgdev.CrocApp` and `com.bakirgdev.CrocApp.CrocShare` exist (2026-10-12), and the App Store Connect record "CrocApp" exists: iOS and macOS on one record (universal purchase), bundle ID `com.bakirgdev.CrocApp`, name reserved.
   2. `com.bakirgdev.CrocApp.direct` was created on 2026-10-13 by Xcode automatic signing. The same run registered this Mac as a development device and signed both app IDs with Associated Domains. On a new Mac, build once with `-allowProvisioningUpdates -allowProvisioningDeviceRegistration`.
5. **Developer ID provisioning profile [O10].** Done 2026-10-14. At developer.apple.com, Profiles, create a Developer ID profile named "CrocApp Direct Developer ID" for `com.bakirgdev.CrocApp.direct` with Associated Domains. It expires in 2044. Download it and copy it into `~/Library/Developer/Xcode/UserData/Provisioning Profiles/` (`scripts/build-devid.sh` needs it there). Its base64 is the `DEVID_PROFILE_BASE64` secret.
6. **Sparkle release key [O6].** Done 2026-10-14. In your own terminal, so the key material never goes through anyone else:
   ```bash
   openssl genpkey -algorithm ed25519 -out k.pem && echo "private: $(openssl pkey -in k.pem -outform DER | tail -c 32 | base64)" && echo "public: $(openssl pkey -in k.pem -pubout -outform DER | tail -c 32 | base64)" && rm k.pem
   ```
   Save the `private:` line in the password manager (it becomes `SPARKLE_ED_PRIVATE_KEY`, step 7). Put the `public:` line in `SPARKLE_PUBLIC_ED_KEY` on the `CrocApp Direct` target. It is `7vFYkIXDHGPg4FHsWDCe3Qz546DfdyQbRKQZOO8zYsE=` and is public. The key is deliberately plain text that the owner keeps, not a keychain item, so Sparkle's `generate_keys` is not used.
7. **GitHub `release` environment [O7].** Done 2026-10-12 and 2026-10-14. The environment `release` exists with required reviewer `bakirgdev`, and its deployment policy allows branch `main` and tags `v*`. To create or rotate one of its secrets (table in this section, above), pipe the value from a file so it is never printed or typed:
   ```bash
   gh secret set DEVID_P12_PASSWORD --env release < password.txt
   base64 < cert.p12 | gh secret set DEVID_P12_BASE64 --env release
   ```
   Use the `gh` account that matches the repo owner. All seven secrets were set on 2026-10-14, after checking locally that the Sparkle private key derives the committed public key, the password opens the `.p12`, and the `.p8` with its key ID and issuer authenticates `notarytool history`.
8. **Approve a release run.** Remaining, each release. A `v*` tag push or a `workflow_dispatch` pauses `release.yml` at the `release` environment. Open the run in GitHub Actions and approve the deployment as the required reviewer (or `gh api -X POST repos/<owner>/<repo>/actions/runs/<id>/pending_deployments -F 'environment_ids[]=<env id>' -f state=approved -f comment=...`). Done for 1.0.0 on 2026-10-15: the `workflow_dispatch` rehearsal from `main` (run 38750570268) ended `success` with the `release` job skipped, then tag `v1.0.0` (run 38751704094) published the DMG, `SHA256SUMS.txt`, the xcframework zip and `appcast.xml`; the DMG passes `stapler validate` and `spctl` ("Notarized Developer ID").
9. **Physical iPhone [O8].** Done: an iPhone on iOS 26 or later, Developer Mode on, shown in Xcode's Devices and Simulators window, and Xcode signed in with the Apple ID that `scripts/build-appstore.sh` uses. Remaining: run the device checklist whenever a slice asks for it.
10. **Multicast entitlement [O3].** Remaining, pending. The request went in on 2026-10-12 at developer.apple.com/contact/request/networking-multicast, Apple request ID WA7J9P8GM7. Check the developer-account email for Apple's reply. If it is granted, Apple adds "Multicast Networking" as a capability on `com.bakirgdev.CrocApp`, and the `com.apple.developer.networking.multicast` entitlement can then be added to the iOS target. If it is not granted by submission, ship without it, hide the iOS multicast setting, and file a `future` issue quoting WA7J9P8GM7.
11. **croc maintainer [O5].** Done 2026-10-14. The maintainer was emailed on 2026-10-12 about the name, the public relay pool default, the Tailcat/DERP `auto` default, getcroc.com stored transfers and the browser link. The owner treats the reply as a yes to all of them (owner's word, the reply text is not in the repo), so no default changes. Ask the owner once more before Submit for Review (R41).
12. **Upload to TestFlight.** Done for 1.0.0 (1) on 2026-10-14 and 1.0.0 (2) on 2026-10-15. For each later build: bump `CURRENT_PROJECT_VERSION` in `app/Config/Version.xcconfig` and commit, then run `scripts/build-appstore.sh --upload`. It prints `APPSTORE-UPLOAD-OK ios` and `APPSTORE-UPLOAD-OK macos`.
13. **After each upload, check the result.** Done for build 1 on 2026-10-14 (no ITMS warning email; the iOS and macOS builds processed). Repeat for every upload.
    1. Open the developer-account email. Apple sends ITMS warnings or errors there after processing (for example ITMS-91053, a missing required-reason API declaration). Fix what it names in `PrivacyInfo.xcprivacy` and upload a new build number.
    2. In App Store Connect, open the app's TestFlight tab and confirm both the iOS and the macOS build finished processing and are not marked invalid.
14. **Internal testers.** Done for build 1 on 2026-10-14 (an internal group exists with the owner in it, and both builds are in TestFlight). In TestFlight, create an internal group (or add yourself as an internal tester), assign build 1 to it, then install it from TestFlight on the iPhone and on the Mac and open it once on each.
15. **Universal link in the Direct build.** Done 2026-10-14: the owner reported that the Direct build's universal link passed (the details are not recorded). Before that, with the stapled Direct app from `build-devid.sh` (2026-10-14, all checks passed), LaunchServices returned no app link for `https://crocapp.dev/r/...`, for the Direct build and for the dev `CrocApp` build alike, and the Mac was locked so Safari could not be tried. Check it by hand: on an unlocked Mac, install the Direct app in /Applications, click a `https://crocapp.dev/r/...` link in Safari or Notes, and see whether CrocApp opens. If it does not, Direct relies on the `crocapp://` button.
16. **App Store Connect listing [O9].** Remaining. Set pricing and availability (France excluded, see Export compliance), pasting the fields from `docs/knowledge/app-store-listing.md`, the privacy answers, age rating, the export compliance answers, screenshots and metadata. Then Submit for Review. Before submitting, repeat steps 10 and 11 and re-check the export compliance question.

Reminders to give the owner: ask for the croc maintainer's reply before the first 1.0 feature build; check for Apple's reply to the multicast request before building the multicast setting; and before Submit for Review do both again.

## 8. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `conflicting nullability specifier on return types` warning while building `CrocKit` | gomobile-generated `Croc.framework/Headers/Crocmobile.objc.h` declares `- (nullable instancetype)init;` on `CrocmobileOptions`, clashing with `NSObject`'s `nonnull init` | Expected, ignorable. Regenerated on every `build-xcframework.sh` run, cannot be fixed in Swift (`docs/knowledge/tooling.md`) |
| Xcode or `xcodebuild` fails immediately, missing binary target / no such module `Croc` | `CrocKit/Croc.xcframework` does not exist (gitignored, absent on a fresh clone) | Run `scripts/build-xcframework.sh` first |
| `scripts/build-xcframework.sh` exits `error: go not installed` | Go not on `PATH` | `brew install go` |
| `gomobile: command not found` right after the script claims to have installed it | `$(go env GOPATH)/bin` not on this shell's `PATH` | The script exports it only for its own run; for a direct `gomobile` invocation afterward, `export PATH="$PATH:$(go env GOPATH)/bin"` |
| macOS build in CI is unsigned | CI's `build (macOS)` job passes `CODE_SIGNING_ALLOWED=NO` (no signing identity on the runner) | Expected in CI. Locally, a signed build needs a `Mac Development` identity and a provisioning profile (section 5, Associated Domains), so pass `-allowProvisioningUpdates` |
| `go install .../cmd@latest` (gomobile, gobind, govulncheck) produces a binary you cannot find or run | `GOOS`/`GOARCH` set in the shell (as CI's go job sets `darwin`/`arm64`) makes `go install` drop the binary at `$GOPATH/bin/darwin_arm64/…` instead of `$GOPATH/bin/…` | Install with `env -u GOOS -u GOARCH go install ...`, then run the tool with the original env intact if the analysis itself needs to target darwin (`docs/knowledge/tooling.md`) |
| A hand-rolled `swift-format format --in-place` reports clean, but `lint --strict` (what CI runs) still fails | Several enabled rules are lint-only and never rewrite | Use `scripts/format-swift.sh`, which always lints after formatting; see the rule list in `docs/knowledge/tooling.md` |

## 9. When the toolchain changes

- **Xcode bump**: update `.xcode-version` (single line). Confirm the `xcode-27` GitHub runner image actually carries that exact version first (`docs/knowledge/tooling.md` notes the image carries 27.0 (default), 27.1 and 27.2 beta). Rerun `scripts/build-xcframework.sh` to confirm gomobile still binds clean, then the full build matrix, then at least one `verify-*.sh` harness live.
- **Go bump**: update `go 1.x.y` in `crocmobile/go.mod`, rerun `scripts/build-xcframework.sh`.
- **croc bump**: `go get github.com/schollz/croc/v11@vX.Y.Z` in `crocmobile/` (`brew upgrade croc` for the test CLI), rebind, then update every place that names the version by hand: `README.md` FAQ, `CONTRIBUTING.md`'s croc-install line, this file's prerequisites table, and `docs/knowledge/crocmobile-bridge.md`. Check `docs/knowledge/croc-upgrade-playbook.md` for the full procedure.
- **golangci-lint bump**: change the `version:` input on the `golangci-lint-action` step in `.github/workflows/reusable-go.yml`; update `crocmobile/.golangci.yml`'s schema `version:` if the new major changes it.
- **gomobile/gobind**: pinned by the `tool` block in `crocmobile/go.mod`; bump with `go get golang.org/x/mobile@latest`. If a bind regresses on a new release, pin the last good version there and record it in `docs/knowledge/tooling.md`.
- Whatever changed, re-check whether [golang/go#73119](https://github.com/golang/go/issues/73119) (macOS multi-arch bind) has been fixed upstream before assuming it still blocks Intel Mac support; it is a live gate on real behavior, not just a build warning. [golang/go#66500](https://github.com/golang/go/issues/66500) (iOS device archive layout) is closed and the first App Store upload passed (section 7).
