# Releasing CrocApp

How CrocApp is signed, notarized, updated and uploaded, and the checklist for cutting a release. The toolchain, first build and verification harnesses are in `BUILDING.md`.

## Release channels

| Channel | What ships | Built by |
|---|---|---|
| Direct download | A Developer ID signed, notarized, stapled disk image for Apple silicon Macs. The app updates itself through Sparkle. Published on GitHub Releases. | `scripts/build-devid.sh`, run by `.github/workflows/release.yml` |
| App Store | iOS, iPadOS and macOS on one App Store Connect record (universal purchase), bundle ID `com.bakirgdev.CrocApp`. Builds go to TestFlight; a release goes through Submit for Review. | `scripts/build-appstore.sh` |

- The direct download is the `CrocApp Direct` target: macOS only, arm64, bundle ID `com.bakirgdev.CrocApp.direct`, product `CrocApp.app`. Its sources are the `app/CrocApp/` synchronized group plus `app/CrocAppDirect/`, built with the Swift condition `DIRECT`. It links Sparkle (SwiftPM, this target only) and shows **Check for Updates…** in the app menu.
- The App Store builds come from the `CrocApp` target and scheme. Its product is also `CrocApp.app`.
- One channel per Mac: both targets produce `CrocApp.app`, so the disk image copy replaces an App Store copy in /Applications. Their data stays apart (separate bundle IDs). The landing download section and the docs site install page say so; keep them in step.
- In one shared DerivedData, each scheme's build replaces the other's. The harness scripts and CI use their own `-derivedDataPath`; otherwise build Direct last.
- Which channels have shipped: `knowledge/project-overview.md`, "Status".

## Direct download (Developer ID)

`scripts/build-devid.sh [out-dir]` builds the signed, notarized, stapled disk image. The default out-dir is `dist` and the output is `CrocApp-<version>-arm64.dmg`. In order, it:

1. Finds the "Developer ID Application" identity for team `HBSU359M33` by SHA-1 and archives the `CrocApp Direct` scheme (Release, arm64) with manual signing and the provisioning profile "CrocApp Direct Developer ID". Prints `archive: OK`.
2. Exports with `app/Config/ExportOptions-DevID.plist` and runs `codesign --verify --strict --deep`. Prints `DEVID-EXPORT-OK`.
3. Zips the app, notarizes it (`xcrun notarytool submit --wait`), staples it, and runs `syspolicy_check distribution` on the stapled app. Prints `DEVID-APP-NOTARIZED-OK`.
4. Builds the disk image with `scripts/build-dmg.sh` (prints `DMG-OK`), signs it with a timestamp, notarizes and staples it, then runs `stapler validate` and `spctl -a -vv -t open --context context:primary-signature`. Prints `DEVID-NOTARIZED-OK`.

Notes on the script:

- The app and the disk image are notarized separately, so an app copied out of the image opens offline on first launch.
- The script exits 1 when no Developer ID identity is present.
- It does not use `syspolicy_check notary-submission`. On macOS 27 that check fails every app that is not yet notarized ("Gatekeeper rejected this file"), so a real notarization problem is read from the notary log instead.
- `syspolicy_check distribution` needs a stapled app, which is why it runs after the app's notarization.
- `DEVID_WORK` sets the scratch directory (archive, DerivedData, logs).

To run it locally you need:

- A "Developer ID Application" identity for team `HBSU359M33` in the keychain search list.
- The "CrocApp Direct Developer ID" profile in `~/Library/Developer/Xcode/UserData/Provisioning Profiles/`.
- Notary credentials, one of:
  - a keychain profile, default `crocapp-notary` (set `NOTARY_KEYCHAIN_PROFILE` to use another name);
  - `NOTARY_KEY` (path to the `.p8`), `NOTARY_KEY_ID` and `NOTARY_ISSUER`, the form CI uses.
- `brew install create-dmg` (CI uses the release pinned in `release.yml`).

### The release workflow

`.github/workflows/release.yml` runs the same script. It starts on a `v*` tag push or on `workflow_dispatch`.

- **A tag run** runs `swift-format` and the Go checks, then the build job.
  - It checks the tag against `MARKETING_VERSION` and against a dated heading in `CHANGELOG.md` (see "Each release").
  - It builds, signs and notarizes, then writes a signed `appcast.xml` with Sparkle's `generate_appcast`, seeded with the latest release's appcast and with the CHANGELOG section embedded as release notes.
  - It attests the stapled files, then publishes the disk image, `appcast.xml`, the `Croc.xcframework` zip and `SHA256SUMS.txt`.
  - It fails when the build number is not above every build in the published `appcast.xml`, because Sparkle only offers a higher `CFBundleVersion`.
- **A `workflow_dispatch` run** is a rehearsal. It skips the tag and CHANGELOG checks and the publish job, only warns about the build number, and publishes nothing. It can only run once the workflow is on `main`, because dispatch needs the workflow on the default branch and the environment allows `main`.
- **The build job** runs in the `release` environment: a required reviewer, and a deployment policy limited to branch `main` and tags `v*`.

Before it signs the appcast, the workflow checks that `SPARKLE_ED_PRIVATE_KEY` matches the built app's `SUPublicEDKey`. After signing, it checks that the new item carries `sparkle:edSignature`. With a mismatched key `generate_appcast` only warns, exits 0 and writes the item unsigned, which every client rejects.

The `release` environment holds seven secrets:

| Secret | Holds |
|---|---|
| `DEVID_P12_BASE64` | Developer ID Application certificate and key, base64 `.p12` |
| `DEVID_P12_PASSWORD` | the `.p12` password |
| `DEVID_PROFILE_BASE64` | the "CrocApp Direct Developer ID" profile, base64 |
| `ASC_KEY_P8` | App Store Connect API key (`.p8` text) used by `notarytool` |
| `ASC_KEY_ID` | that key's ID |
| `ASC_ISSUER_ID` | that key's issuer ID |
| `SPARKLE_ED_PRIVATE_KEY` | Sparkle Ed25519 release private key, passed to `generate_appcast` on stdin |

### Export options

Three export option files live under `app/Config/`. All share `teamID` `HBSU359M33` and `destination` `export`.

| File | `method` | Channel |
|---|---|---|
| `ExportOptions-DevID.plist` | `developer-id` | Direct download. Manual signing, `signingCertificate` "Developer ID Application", profile "CrocApp Direct Developer ID" for `com.bakirgdev.CrocApp.direct`. Used by `scripts/build-devid.sh`. |
| `ExportOptions-iOS.plist` | `app-store-connect` | iOS App Store and TestFlight, from the `CrocApp` scheme on `generic/platform=iOS`. Automatic signing. Used by `scripts/build-appstore.sh`. |
| `ExportOptions-MAS.plist` | `app-store-connect` | Mac App Store and TestFlight, from the `CrocApp` scheme on `generic/platform=macOS`. Same keys as the iOS file. Used by `scripts/build-appstore.sh`. |

The two App Store files also set `signingStyle` `automatic` and `manageAppVersionAndBuildNumber` false. `build-appstore.sh --upload` leaves the committed files alone: it sets `destination` to `upload` in a scratch copy, so they always describe an export to disk.

### Sparkle configuration

Two build settings on the `CrocApp Direct` target configure Sparkle:

- `SPARKLE_PUBLIC_ED_KEY` is the release public key (public by design). Read the current value from the pbxproj or the built app's `SUPublicEDKey`.
- `SPARKLE_FEED_URL` is `https://github.com/bakirgdev/CrocApp/releases/latest/download/appcast.xml`.

The release key is plain text that the owner keeps (made with `openssl`, see "One-time setup"), not a keychain item, so Sparkle's `generate_keys` is not used. The owner's copy is the `SPARKLE_ED_PRIVATE_KEY` secret.

## Disk image

The macOS download's Finder window is the first CrocApp anyone sees. `scripts/build-dmg.sh` passes this geometry to `create-dmg`, so change the script and this section together.

- **Window** 660×400, icons 128, the app at (165, 170) and the Applications alias at (495, 170).
- **Background** `assets/dmg-background.tiff`, a 1x and 2x multi-representation TIFF (`tiffutil -cathidpicheck bg.png bg@2x.png -out dmg-background.tiff`) filled with `--bg-secondary` dark. Positions are centers measured from the image top, which Finder draws under the 32pt title bar: the title "CrocApp" (title3 semibold, `--label-1` dark) at y 44, a Lucide `arrow-right` midway between the icons at y 170 (44×44, stroke 1.5, `--label-2-text` dark), one label plate under each icon at y 254 (140×26, radius 13, `rgba(235,235,245,0.85)`), and the hint "Drag CrocApp onto Applications" (footnote, `--label-2-text` dark) at y 316.
- **Dark only, with label plates.** Finder shows one fixed image regardless of appearance, and with a background picture set it draws icon labels black in both appearances (verified on macOS 27). The plates keep those labels readable on the dark fill; a plate center sits 84pt below its icon center, where Finder puts a 128pt icon's label. Keep everything inside the top 340pt, because Finder clips at about 368pt under the title bar, and 340 with the path bar on. No mascot or accent.

## Testing a Sparkle update locally

This proves that a Release `CrocApp Direct` build installs a newer one. It uses a throwaway Ed25519 key, never the release key, and a feed on localhost. Sparkle accepts an `http` localhost feed and only logs a warning about HTTPS, so no ATS exception is needed.

Sparkle's tools come with the package, at `<DerivedData>/SourcePackages/artifacts/sparkle/Sparkle/bin/`. Work in a scratch directory with a `feed/` folder.

1. Make a throwaway key (raw 32-byte seed and public key, base64):
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
5. Copy build 1 somewhere writable (`ditto dd1/Build/Products/Release/CrocApp.app apps/CrocApp.app`) and launch it. Choose **Check for Updates…**, then **Install Update**, then **Install and Relaunch** in Sparkle's standard UI. From the second launch on, Sparkle first asks about automatic checks.
6. Expect the old process to exit, a new process to start, and `apps/CrocApp.app` to report `CFBundleVersion` 2.

A known hang after **Install and Relaunch** on the first launch of the Direct bundle ID on a Mac is tracked in `known-issues.md`, "Release".

## App Store builds

`scripts/build-appstore.sh [--upload] [ios|macos]...` builds the `CrocApp` scheme (Release) for the App Store channels. No platform argument means both. For each platform it:

1. Archives for `generic/platform=iOS` or `generic/platform=macOS` and prints `<platform> archive: OK`.
2. Runs `xcodebuild -exportArchive` with `ExportOptions-iOS.plist` or `ExportOptions-MAS.plist`.
   - Without `--upload`, it writes `CrocApp.ipa` (iOS) or `CrocApp.pkg` (macOS) to the scratch directory and prints `APPSTORE-EXPORT-OK <platform>`. Nothing leaves the Mac.
   - With `--upload`, it sets `destination` to `upload` in a scratch copy of the plist and sends the build to App Store Connect (TestFlight). It prints `APPSTORE-UPLOAD-OK <platform>`.

`APPSTORE_WORK` sets the scratch directory (archives, DerivedData, per-step logs). The script deletes it first. On failure it prints the tail of the failing log and its path.

To run it you need:

- Xcode signed in to the Apple ID that belongs to team `HBSU359M33` (Settings, Accounts). Signing is automatic and cloud-managed through `-allowProvisioningUpdates`, so no Apple Distribution or Mac Installer certificate has to be in the keychain.
- `CrocKit/Croc.xcframework` built (`scripts/build-xcframework.sh`).
- The App Store Connect record "CrocApp" (iOS and macOS on one record, bundle ID `com.bakirgdev.CrocApp`).
- A build number App Store Connect has not seen for this version. The build number is always `CURRENT_PROJECT_VERSION` in `app/Config/Version.xcconfig` (`manageAppVersionAndBuildNumber` is false), and App Store Connect refuses a number it has already seen for that `MARKETING_VERSION`. Bump it in its own commit before every upload. Run the script without `--upload` first if the change is in doubt.

Facts about the upload that look like problems but are not:

- **`MinimumOSVersion = 100.0`.** gomobile writes this into the framework `Info.plist` (x/mobile `bind_iosapp.go`, an SwiftPM workaround). App Store Connect accepts it, so `build-xcframework.sh` does not patch it.
- **"Upload Symbols Failed".** This is the only warning, for `Croc.framework` (iOS) and `A` (macOS). Xcode embeds a 50 KB stub `Croc.framework` dylib with no dSYM, because the gomobile xcframework is a static archive linked into the app binary. It is not an ITMS warning (`known-issues.md`, "Accepted").
- **App category.** `LSApplicationCategoryType` is `public.app-category.utilities`, set as `INFOPLIST_KEY_LSApplicationCategoryType` on `CrocApp` and `CrocApp Direct`. Without it the macOS archive warns "No App Category is set".

### Privacy manifest

`app/CrocApp/PrivacyInfo.xcprivacy` declares the required-reason APIs the Go engine reaches: `FileTimestamp` (`C617.1`, `3B52.1`) and `SystemBootTime` (`35F9.1`), besides `UserDefaults` (`CA92.1`). The engine is linked statically into the app binary and imports `stat`, `fstat`, `fstatat`, `lstat` and `mach_absolute_time` (checked with `nm -u`). It does not import `statfs`, `statvfs` or `getattrlist`, so there is no `DiskSpace` entry. Re-run `nm -u` after a croc or Go bump.

### Checking the result of an upload

After every upload:

1. Open the developer-account email. Apple sends ITMS warnings or errors there after processing (for example ITMS-91053, a missing required-reason API declaration). Fix what it names in `PrivacyInfo.xcprivacy` and upload a new build number.
2. In App Store Connect, open the app's TestFlight tab and confirm that both the iOS and the macOS build finished processing and are not marked invalid.
3. Install the build from TestFlight on an iPhone and on a Mac, and open it once on each. An internal TestFlight group with the owner in it is enough.

## Export compliance

Both app `Info.plist` files (`app/Config/CrocApp-Info.plist`, `app/Config/CrocApp-macOS-Info.plist`) set `ITSAppUsesNonExemptEncryption` to `false`. Setting it to `true` without an `ITSEncryptionExportComplianceCode` fails the upload with `Invalid Export Compliance Code`.

- `false` is a position, not only a way past the check. croc's encryption (AES-256-GCM, PAKE) is standard and its source is public, so the app relies on the open-source exemption (EAR 742.15(b)).
- Apple's own table makes `false` coherent only while France is excluded. The first App Store release therefore ships without France in its availability. A later release adds France after an ANSSI declaration, and the key then becomes `true` with an issued code.
- SIEC is no longer a separate question for the app: CrocApp has no curve setting and uses P-256 itself. croc still links the `siec` curve and a sender adopts its receiver's curve, so a CLI receiver can pick it (`app-store-listing.md`, "Export compliance").
- If the exemption does not hold, set the key to `true` and add the `ITSEncryptionExportComplianceCode` that App Store Connect issues after the documentation is approved.

The research and the exact answers to give if App Store Connect asks are in `docs/knowledge/app-store-listing.md`, "Export compliance". The owner's open actions are in `known-issues.md`, "Release".

## One-time setup

These steps are done by a person, not by a script. Follow them on a new machine, or to rotate one item. Keep every secret in a password manager, and never paste key material into a shared terminal or chat.

1. **Agreements, tax and banking.** In App Store Connect, accept the Free Apps and Paid Apps agreements, fill in tax and bank details, and declare EU Digital Services Act trader status with public contact details. Before each release, check that no agreement shows as pending or needing re-acceptance.
2. **Developer ID Application certificate.**
   1. At developer.apple.com, Certificates, create a "Developer ID Application" certificate. The certificate signing request comes from Keychain Access, Certificate Assistant. Download the certificate and double-click it to install it into the login keychain.
   2. Check it: `security find-identity -v -p codesigning` lists "Developer ID Application" for team `HBSU359M33`.
   3. In Keychain Access, export the certificate with its private key as a `.p12` with a password. These become the `DEVID_P12_BASE64` and `DEVID_P12_PASSWORD` secrets.
3. **Notarization API key.** In App Store Connect, create a team API key (for example named "CrocApp notarization") with the Developer role, which is enough for `notarytool`. Download the `.p8` (Apple offers it once) and note the Key ID and Issuer ID. Then:
   ```bash
   xcrun notarytool store-credentials crocapp-notary --key <p8 path> --key-id <key id> --issuer <issuer id>
   xcrun notarytool history --keychain-profile crocapp-notary
   ```
   The second command answering confirms the key works. The three values are also the CI secrets `ASC_KEY_P8`, `ASC_KEY_ID` and `ASC_ISSUER_ID`.
4. **Bundle IDs and the App Store Connect record.** Six bundle IDs exist: `com.bakirgdev.CrocApp`, `com.bakirgdev.CrocApp.CrocShare`, `com.bakirgdev.CrocApp.CrocWidgets`, `com.bakirgdev.CrocApp.direct`, `com.bakirgdev.CrocApp.direct.CrocShare` and `com.bakirgdev.CrocApp.direct.CrocWidgets` (the two Direct extensions, which need no provisioning profile: they use the team-prefixed group like the share extension; the `.CrocWidgets` iOS ID needs the `group.com.bakirgdev.CrocApp` group like `.CrocShare`). Xcode automatic signing creates them on the first signed build. On a new Mac, build once with `-allowProvisioningUpdates -allowProvisioningDeviceRegistration`, which registers the Mac as a development device and signs the app IDs with Associated Domains. The App Store Connect record "CrocApp" holds iOS and macOS on one record (universal purchase) under `com.bakirgdev.CrocApp`.
5. **Developer ID provisioning profile.** At developer.apple.com, Profiles, create a Developer ID profile named "CrocApp Direct Developer ID" for `com.bakirgdev.CrocApp.direct` with Associated Domains and App Groups (the share extension's team-prefixed group `HBSU359M33.com.bakirgdev.CrocApp.direct` is in the app's entitlements, and Xcode rejects a profile without the capability). Download it and copy it into `~/Library/Developer/Xcode/UserData/Provisioning Profiles/`, where `scripts/build-devid.sh` needs it. Its base64 is the `DEVID_PROFILE_BASE64` secret. Renew the profile before it expires.
6. **Sparkle release key.** In your own terminal:
   ```bash
   openssl genpkey -algorithm ed25519 -out k.pem && echo "private: $(openssl pkey -in k.pem -outform DER | tail -c 32 | base64)" && echo "public: $(openssl pkey -in k.pem -pubout -outform DER | tail -c 32 | base64)" && rm k.pem
   ```
   Save the `private:` line in the password manager. It becomes `SPARKLE_ED_PRIVATE_KEY`. Put the `public:` line in `SPARKLE_PUBLIC_ED_KEY` on the `CrocApp Direct` target. Changing the key breaks updates for every installed copy, because clients only accept items signed by the key their app carries.
7. **GitHub `release` environment and secrets.** The environment `release` has a required reviewer and a deployment policy that allows branch `main` and tags `v*`. To create or rotate a secret, pipe the value from a file so it is never printed or typed:
   ```bash
   gh secret set DEVID_P12_PASSWORD --env release < password.txt
   base64 < cert.p12 | gh secret set DEVID_P12_BASE64 --env release
   ```
   Use the `gh` account that matches the repo owner. After setting the secrets, check locally that the Sparkle private key derives the committed public key, the password opens the `.p12`, and the `.p8` with its key ID and issuer authenticates `notarytool history`.
8. **Physical devices.** An iPhone on iOS 26 or later with Developer Mode on, shown in Xcode's Devices and Simulators window, and Xcode signed in with the Apple ID that `scripts/build-appstore.sh` uses.

## Each release

1. **Bump the version.** In `app/Config/Version.xcconfig`, set `MARKETING_VERSION` for a new version, and raise `CURRENT_PROJECT_VERSION` for every upload or tag. Do this in its own pull request or commit. A tag run fails when the build number is not above every build in the published `appcast.xml`. App Store Connect refuses a build number it has already seen for that version.
2. **Write the CHANGELOG heading.** Rename `## [Unreleased]` and date it as `## [X.Y.Z] - YYYY-MM-DD` (Keep a Changelog). `release.yml` requires exactly that heading for the tagged version, requires the section to be non-empty, and publishes the section as the release notes and the Sparkle notes. `X.Y.Z` must be a plain dotted version.
3. **Update the website.** In `web/landing/index.html`, add `softwareVersion`, `downloadUrl` (the releases page), `releaseNotes` and `datePublished` (the release date) to the JSON-LD block, which carries none while nothing is public, and flip the Download section's "coming soon" copy to "available now" (the lead, the Mac disk image card and its "GitHub Releases" button label, which then becomes "Download Disk Image"), with the store cards once the apps are live. Do the same in `web/docs/content/getting-started/install.md` and in `web/landing/llms.txt` (the release status fact). In `web/landing/sitemap.xml`, bump `lastmod` for each page you changed. `datePublished` is then the first public release and stays (`knowledge/landing-page.md`, "Hand-maintained").
4. **Rehearse.** With the change on `main`, start the workflow from GitHub Actions with `workflow_dispatch`. Approve the `release` environment deployment as the required reviewer (in the run's page, or with `gh api -X POST repos/<owner>/<repo>/actions/runs/<id>/pending_deployments -F 'environment_ids[]=<env id>' -f state=approved -f comment=...`). The rehearsal builds, signs, notarizes and writes the appcast, and publishes nothing.
5. **Tag.** Tag the squashed commit on `main` as `vX.Y.Z` and push the tag. The tag must equal `MARKETING_VERSION`. Approve the `release` environment again.
6. **Verify the published DMG.** Download it from the release and run `xcrun stapler validate <dmg>` and `spctl -a -vv -t open --context context:primary-signature <dmg>`. Expect "Notarized Developer ID". Compare it against `SHA256SUMS.txt`, and run `gh attestation verify <file> --repo bakirgdev/CrocApp`.
7. **Check Sparkle.** Confirm the new item in `appcast.xml` carries `sparkle:edSignature`, and that an older installed build offers the update.
8. **Upload App Store builds** when the release includes the App Store: run `scripts/build-appstore.sh --upload`, then follow "Checking the result of an upload". It prints `APPSTORE-UPLOAD-OK ios` and `APPSTORE-UPLOAD-OK macos`.
9. **Run the device checklist** in `docs/knowledge/device-test-checklist.md` on a physical iPhone whenever a change calls for it.
10. **Before Submit for Review** (the first App Store release, 1.1.0), finish the open owner items:
   - The App Store Connect listing: pricing, availability without France, privacy answers, age rating, export compliance answers and screenshots. The field text is in `docs/knowledge/app-store-listing.md`.
   - An Accessibility Inspector and VoiceOver audit.
   - A check-in with the croc maintainer about the name, the public relay pool default, getcroc.com stored transfers and the browser link.
