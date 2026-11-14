# Review rules

What reviewers (people, the managed Code Review service) weigh in this repo. The verification, docs and design rules in the root `AGENTS.md` apply to every review too, including local `/code-review`.

## What failure means here

| Area | Failure means | Important when |
| --- | --- | --- |
| Transfer engine and bridge (`crocmobile/`, `CrocKit/`, `TransferController`) | it loses or leaks a file | a transfer does not complete, data is corrupted, plaintext or a code phrase leaks |
| Settings, secrets, persistence | it loses user data or exposes a secret | a write deletes the old value before the new one is saved, a secret leaves the Keychain or device, a failed save is hidden |
| CI and release (`.github/`, `scripts/`) | it breaks the gate or ships wrong | a step cannot run, `ci pass` can go green without its checks, a release is signed, tagged or versioned wrongly |
| Docs | it lies | a claim does not match the code, or a "verified" claim names no version |
| UI and design | it breaks `design/` | a raw color replaces a token, a theme or contrast rule fails, copy ignores `design/voice.md` |

Style and wording are Nit at most, and at most 5 are reported.

## Do not report

- Lockfiles and resolved pins: `crocmobile/go.sum`, `web/docs/pnpm-lock.yaml`, `Package.resolved`.
- `project.pbxproj` diffs that only register files, and `*.xcstrings` catalogs unless an English source string changed.
- Anything CI already enforces: link and path validity (`scripts/verify-docs.sh`), token parity, contrast and the raw-color lint (`scripts/verify-design.sh`), swift-format, golangci, `ci pass`.

## Evidence

- Every behavior claim cites `file:line`, not an inference from a name.
- The summary starts with a count of findings and says "nothing to fix" when there are none.
- A transfer-path change without quoted harness output counts as "not verified", not as passing.

## Always check

- Every action is pinned to a full commit SHA with a `# vX.Y.Z` comment.
- A new file that CI reads is in the `changes` regex of the job that reads it.
- A write path never deletes the old value before the new one is saved.

## Always human

A person approves changes to `crocmobile/session.go`, `CrocKit/Sources/`, `*.entitlements`, secret storage (`KeychainStore.swift` and its callers), `.github/workflows/`, `scripts/build-appstore.sh`, `build-devid.sh` and `build-dmg.sh`, Sparkle and signing config (`CrocApp-Direct-Info.plist`, `ExportOptions-*.plist`), `SECURITY.md` and `docs/THREAT-MODEL.md`.
