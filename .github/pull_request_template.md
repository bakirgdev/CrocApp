<!-- Keep it short. Delete sections that do not apply. First time here? See CONTRIBUTING.md. -->

<!-- Title: Conventional Commits advised, type(scope): subject. It becomes the squashed commit subject on main. -->

## What and why

Fixes # because...

AI assistance: none / partial / substantial
<!-- If a model wrote part of this change, you still own it: read it, understand it, verify it. -->

## Verification

A green build is not evidence a transfer works. List the commands you actually ran and their result. Write "not verified" for anything you skipped.

- [ ] `scripts/format-swift.sh --lint`
- [ ] `golangci-lint run ./...` (only if `crocmobile/` changed)
- [ ] macOS and/or iOS Simulator build
- [ ] Matching `scripts/verify-*.sh` harness, required for changes to `crocmobile/session.go`, `CrocKit/Sources/`, or `TransferController`

```
paste harness output here (if long, paste the summary lines and any failures, not the whole log)
```

## Docs

- [ ] Anything a user would notice → a line under `## [Unreleased]` in `CHANGELOG.md`. Write it for someone deciding whether to update, not as a summary of this diff. That section becomes the release notes verbatim
- [ ] Durable knowledge → `docs/knowledge/` and/or `AGENTS.md`
- [ ] Defect fixed or accepted → `docs/known-issues.md` line deleted or added
- [ ] Nothing doc-worthy

## UI changes

Before/after screenshots for both light and dark, and both platforms if affected. UI must use `design/` tokens, SF Symbols, and the system font.
