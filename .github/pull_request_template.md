<!-- Keep it short. Delete sections that do not apply. First time here? See CONTRIBUTING.md. -->

<!-- Title follows Conventional Commits: type(scope): subject. It becomes the squashed commit subject. -->

<!-- If a model wrote a substantial part of this change, say so in one line. You still own it: read it, understand it, verify it. -->

## What and why

Fixes # because...

## Verification

A green build is not evidence a transfer works. List the commands you actually ran and their result. Write "not verified" for anything you skipped.

- [ ] `xcrun swift-format lint --recursive --parallel --strict app/CrocApp app/CrocShare CrocKit/Sources`
- [ ] `golangci-lint run ./...` (only if `crocmobile/` changed)
- [ ] macOS and/or iOS Simulator build
- [ ] Matching `scripts/verify-*.sh` harness — required for changes to `crocmobile/session.go`, `CrocKit/Sources/`, or `TransferController`

```
paste harness output here (if long, paste the summary lines and any failures, not the whole log)
```

## Docs

- [ ] Durable knowledge → `docs/knowledge/` and/or `CLAUDE.md`
- [ ] Defect fixed or accepted → `docs/known-issues.md` line deleted or added
- [ ] Nothing doc-worthy

## UI changes

Before/after screenshots for both light and dark, and both platforms if affected. UI must use `design/` tokens, SF Symbols, and the system font.
