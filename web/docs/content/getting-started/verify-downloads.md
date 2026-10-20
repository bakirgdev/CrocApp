---
sidebar_position: 5.5
title: Verify a release
description: What each CrocApp release asset is, and how to check one is notarized, built by the release workflow and unmodified.
---

# Verify a release

Each release on the [releases page](https://github.com/bakirgdev/CrocApp/releases) carries four assets:

| Asset | What it is |
|---|---|
| `CrocApp-<version>-arm64.dmg` | The Mac app, as a disk image |
| `appcast.xml` | The update feed Sparkle reads |
| `Croc.xcframework-<version>.zip` | The prebuilt Go engine, for building from source |
| `SHA256SUMS.txt` | Checksums for the disk image and the engine archive |

No app zip is published. The disk image is the only file of the app.

## Notarized and stapled

The app inside the disk image is signed with a Developer ID certificate with the hardened runtime and a timestamp. The app and the disk image are each notarized by Apple and stapled, so macOS verifies them without a network connection. Check the disk image yourself:

```bash
xcrun stapler validate CrocApp-<version>-arm64.dmg
spctl -a -vv -t open --context context:primary-signature CrocApp-<version>-arm64.dmg
```

## Build attestation

The release workflow makes a [build provenance attestation](https://github.com/bakirgdev/CrocApp/attestations) for the disk image, the engine archive and `appcast.xml` after stapling, because stapling rewrites the disk image and the attestation has to cover the bytes that ship. Verify any of them before you run it:

```bash
gh attestation verify <file> --repo bakirgdev/CrocApp \
  --signer-workflow bakirgdev/CrocApp/.github/workflows/release.yml
```

The `--signer-workflow` flag is the recommended form: it proves the file came from the release workflow, not just any workflow in the repository. Without it, `gh attestation verify <file> --repo bakirgdev/CrocApp` checks only the repository.

## Checksums

`SHA256SUMS.txt` ships alongside the assets and covers the disk image and the engine archive.

## Updates

Only the disk image build updates itself, through Sparkle 2. Every update in `appcast.xml` is signed with an EdDSA (Ed25519) key. The private key is a secret of the repository's `release` environment, which runs only after the maintainer approves the run, plus the maintainer's own copy. CrocApp has one maintainer, so no second person reviews that approval. The app carries the matching public key and installs an update only when the signature matches.

The feed is served over HTTPS from this repository's releases, and update checks send no system profile. The App Store builds contain no Sparkle and no update feed.

## If a check fails

An asset that fails any of these checks, or one that appears anywhere other than this repository's releases page, is worth reporting. See the [security policy](https://github.com/bakirgdev/CrocApp/blob/main/SECURITY.md) and [Security and privacy](security-and-privacy.md).
