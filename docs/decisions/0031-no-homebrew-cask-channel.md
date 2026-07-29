# 0031. Distribution channels, without Homebrew

Status: accepted
Date: 2026-07-28

## Context

ADR 0007 named five channels, Homebrew cask among them. Every prerequisite for a cask is further out than the prerequisites for the other four:

- Homebrew requires codesigning **and** notarization for casks from 2026-09-01, and removes casks that fail Gatekeeper. There is no Developer ID Application certificate yet, and `scripts/build-devid.sh` stops at `syspolicy_check distribution`, a dry run.
- `homebrew/cask` runs an automated notability check. A self-submitted cask — one where the pull request author owns the repository — needs 90 forks, 90 watchers and 225 stars. This repository is nowhere near that, and no amount of engineering moves the number.
- Homebrew 6.0.0 made third-party taps untrusted by default, so an own-tap fallback no longer installs with one unqualified command. It costs a `brew trust` step or a fully qualified token, which is a worse experience than the direct DMG download it would sit next to.

Carrying the channel anyway meant a landing-page card printing a command that does not work, a README row reading "Blocked", and a docs table promising something with no date on it.

## Decision

Four channels: iOS/iPadOS App Store, Mac App Store, macOS direct download (Developer ID signed, notarized DMG), and TestFlight for betas. No Homebrew cask, and no reference to one in the app, the docs, the README or the web surfaces.

The direct DMG is the whole story for technical macOS users until the App Store listings exist.

## Consequences

- Nothing advertises an install path that cannot be completed. The DMG on GitHub Releases is the only macOS route outside the store, and it is real as soon as a release is tagged.
- Revisiting is cheap and gated on two independent things: real notarization, and repository popularity clearing Homebrew's self-submission thresholds. Both are tracked outside `docs/`; neither is on a schedule.
- If a cask is ever submitted, in-app update checking has to be reconsidered at the same time. Homebrew owns upgrades for a cask-installed app, so an updater that downloads and replaces the bundle itself would fight it. That interaction does not exist today because there is no updater and no cask.
- ADR 0007's reasoning about the other four channels still holds; only the fifth one is withdrawn.
