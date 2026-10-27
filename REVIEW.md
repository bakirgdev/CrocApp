# Review rules

What reviewers (`sdlc-reviewer`, the managed Code Review service) weigh in this repo. Rules for every review, including local `/code-review`, live in `AGENTS.md`.

## What failure means here

| Area | Failure means | Important when |
| --- | --- | --- |
| Transfer engine and bridge (`crocmobile/`, `CrocKit/`, `TransferController`) | it loses or leaks a file | a transfer does not complete, data is corrupted, plaintext or a code phrase leaks |
| Settings, secrets, persistence | it loses user data or exposes a secret | a write deletes the old value before the new one is saved, a secret leaves the Keychain or device, a failed save is hidden |
| CI and release (`.github/`, `scripts/`) | it breaks the gate or ships wrong | a step cannot run, `ci pass` can go green without its checks, a release is signed, tagged or versioned wrongly |
| Docs | it lies | a claim does not match the code, or a "verified" claim names no version |
| UI and design | it breaks `design/` | a literal replaces a token, a theme or contrast rule fails, copy ignores `design/content.md` |

Style and wording are Nit at most.

## Nits

Report at most 5.

## Do not report

- Lockfiles and resolved pins: `crocmobile/go.sum`, `web/docs/pnpm-lock.yaml`, `Package.resolved`.
- `project.pbxproj` diffs that only register files.
- `*.xcstrings` catalogs, unless the change is to an English source string.
- Anything CI already enforces: link and path validity (`scripts/verify-docs.sh`), token parity, contrast and the no-literals lint (`scripts/verify-design.sh`), swift-format, golangci, `ci pass`.

## Evidence

- Every behavior claim cites `file:line`, not an inference from a name.
- The summary starts with a count of findings and says "nothing to fix" when there are none.
- A transfer-path change without quoted harness output counts as "not verified", not as passing.

## Always check

1. A change to `crocmobile/session.go`, `CrocKit/Sources/` or `TransferController` quotes its transfer harness output (`docs/BUILDING.md`, "Verification harnesses") or says "not verified".
2. A user-visible change updates `CHANGELOG.md` under `## [Unreleased]` and the matching page in `web/docs/content/`.
3. The docs named in the "You changed" table of `AGENTS.md` are updated.
4. New app text is localizable (String Catalogs).
5. New values come from `design/` tokens, not literals.
6. Every action is pinned to a full commit SHA with a `# vX.Y.Z` comment.
7. A new file that CI reads is in the `changes` regex of the job that reads it.
8. A write path never deletes the old value before the new one is saved.

## Always human

A person approves changes to these paths. `/sdlc-deploy` treats them as `high` risk.

- `crocmobile/session.go` and `CrocKit/Sources/` (encrypted-transfer path, PAKE handshake)
- `*.entitlements`
- Secret storage: the Keychain code in `app/CrocApp/Models/AppSettings.swift`
- `.github/workflows/` (all workflows, `release.yml` above all)
- `scripts/build-appstore.sh`, `scripts/build-devid.sh`, `scripts/build-dmg.sh`
- Sparkle and signing config (`app/Config/CrocApp-Direct-Info.plist`, `app/Config/ExportOptions-*.plist`)
- `SECURITY.md`, `docs/THREAT-MODEL.md`
- `.claude/`
