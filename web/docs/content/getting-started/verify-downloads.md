---
sidebar_position: 3
title: Verify a release
description: What each CrocApp release asset is, and how to check a download is notarized, built by the release workflow and unmodified.
---

# Verify a release

Each release on the [releases page](https://github.com/bakirgdev/CrocApp/releases) has four assets:

| Asset | What it is |
|---|---|
| `CrocApp-<version>-arm64.dmg` | The Mac app, as a disk image |
| `appcast.xml` | The update feed the app reads |
| `Croc.xcframework-<version>.zip` | The prebuilt Go engine, for building from source |
| `SHA256SUMS.txt` | Checksums for the disk image and the engine archive |

The disk image is the only file of the app. No separate app zip is published.

## Notarized and stapled

The app inside the disk image is signed with a Developer ID certificate. Apple has notarized both the app and the disk image, and each carries its notarization ticket, so macOS verifies them offline. To check the disk image:

```bash
xcrun stapler validate CrocApp-<version>-arm64.dmg
spctl -a -vv -t open --context context:primary-signature CrocApp-<version>-arm64.dmg
```

## Build attestation

The release workflow records a [build provenance attestation](https://github.com/bakirgdev/CrocApp/attestations) for the disk image, the engine archive and `appcast.xml`. Verify one before you run it:

```bash
gh attestation verify <file> --repo bakirgdev/CrocApp \
  --signer-workflow bakirgdev/CrocApp/.github/workflows/release.yml
```

`--signer-workflow` proves the file came from the release workflow, not just any workflow in the repository. Without it, the check covers only the repository.

## Checksums

`SHA256SUMS.txt` lists a SHA-256 checksum for the disk image and for the engine archive. Download it next to the disk image, then run this in the folder that holds both:

```bash
grep 'arm64.dmg' SHA256SUMS.txt | shasum -a 256 -c
```

It prints `CrocApp-<version>-arm64.dmg: OK` when the file matches.

`SHA256SUMS.txt` itself has no attestation. It catches a damaged or incomplete download, but it does not prove who built the file. For that, use the attestation above.

## Updates

Only the disk image build updates itself. Every update in `appcast.xml` is signed, and the app installs an update only when the signature matches the key built into it. The feed is served over HTTPS from this repository's releases, and update checks send no system profile. The App Store builds contain no updater.

## If a check fails

A file that fails any check, or that appears anywhere other than this repository's releases page, is worth reporting. See the [security policy](https://github.com/bakirgdev/CrocApp/blob/main/SECURITY.md).
