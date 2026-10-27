<!-- Keep it short. Delete what does not apply. First time here? See CONTRIBUTING.md. -->
<!-- Title: Conventional Commits advised, type(scope): subject. It becomes the squashed commit subject on main. -->

## What and why

<!-- What changes and why. Link the issue: Fixes #123 -->

AI assistance: none / partial / substantial
<!-- If a model wrote part of this change, you still own it: read it, understand it, verify it. -->

## Verification

CI runs formatting, lint, the builds and the unit tests. List what you ran beyond that, with the result. Write "not verified" for anything you skipped.

- [ ] New or changed behavior has an automated test (Go in `crocmobile/`, Swift in `CrocKit/Tests/` or `app/CrocAppTests/`)
- [ ] Matching `scripts/verify-*.sh` harness, required for changes to `crocmobile/session.go`, `CrocKit/Sources/`, or `TransferController`
- [ ] Tested by hand on: macOS / iOS / iPadOS (device or Simulator)

```
harness output: the summary lines and any failures, not the whole log
```

## Docs

- [ ] User-visible change: a line under `## [Unreleased]` in `CHANGELOG.md`, written for someone deciding whether to update. That section becomes the release notes verbatim
- [ ] Internals changed: the docs that describe them updated (root `AGENTS.md`, "Docs")
- [ ] Defect fixed or accepted: its `docs/known-issues.md` line deleted or added
- [ ] Nothing doc-worthy
- [ ] `scripts/verify-docs.sh` passes

## UI changes

Before and after screenshots, light and dark, on every affected platform.

- [ ] Tokens, SF Symbols and the system font only
- [ ] Both themes checked
- [ ] `scripts/verify-design.sh` passes
- [ ] Screenshots recaptured and published if the UI changed (`scripts/capture-screenshots.sh`, then `--copy-web`)
