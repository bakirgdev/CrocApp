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

## Docs and UI

- [ ] User-visible change: a line under `## [Unreleased]` in `CHANGELOG.md` (it becomes the release notes verbatim), and the docs that describe the change updated (root `AGENTS.md`, "Docs"; `scripts/verify-docs.sh` passes)
- [ ] UI change: before and after screenshots on every affected platform; follows `design/`, checked in light and dark, `scripts/verify-design.sh` passes
