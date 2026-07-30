# TODO

Personal scratch list. Not a doc — never cite from `docs/`.

## Before repo public release

- Main branch: no direct pushes, contributions via PR only
- Main branch: block force pushes of any kind
- Required status check: CI from the PR must pass
- Required status check: Pages preview must pass for landing and/or docs page changes
- Review for more rules worth adding at the same time
- Build specialized skills/commands/agents for QOL/DevEx while developing (release, format, actions, etc.) — ask Claude Code for suggestions
- fix ADRs: all have to be accepted, reordered to make sense, optimized content. this is due to preparing repo for public release, so all ADRs must be nice and clean and organized and no traces of 'battlefield'.
- **Before** making CI a required check: replace the `paths` allowlist in `ci.yml` with a change-detection job that reports success. Today a filtered-out PR runs zero jobs, so a required check stays pending forever (see `docs/knowledge/tooling.md`)
- Pin third-party actions to commit SHAs (`maxim-lobanov/setup-xcode`, `golangci/golangci-lint-action`) — mutable major tags are a supply-chain hole
- fix all security voulns flagged on github
- perform complete refactoring before public release

## AppStore + Notarization: Signing cert (blocks every macOS release channel)

`scripts/build-devid.sh` archives fine, then stops at `DEVID-PENDING-CERT`. `security find-identity -v -p codesigning` shows one identity, `Apple Development: gracicbakir@icloud.com (5J25995FS2)`. No **Developer ID Application** cert exists, so nothing signable ships — not the unnotarized build, not notarization.

- Create a Developer ID Application cert at developer.apple.com (Certificates > Developer ID Application), install it in the login keychain, re-run `scripts/build-devid.sh`. Expect `DEVID-EXPORT-OK` then `DEVID-CHECK-OK`
- Only owner-account action; the script degrades on purpose rather than failing, so it will keep quietly saying PENDING until this is done
- After the cert: real notarization is still unwritten (`notarytool submit --wait` + `stapler staple`), see `docs/known-issues.md`
- Mac App Store is a separate cert (Apple Distribution / 3rd Party Mac Developer), and `Config/ExportOptions-MAS.plist` has still never been exercised

Also owner-only, at submission: answer the App Store Connect encryption questionnaire. `ITSAppUsesNonExemptEncryption` is now `true` in both plists (croc bundles its own AES-256-GCM/ChaCha20-Poly1305, so no exemption applies — `docs/decisions/0030-export-compliance-declaration.md`). The plist value and the answer you give must agree.

## Homebrew, some day

Cask channel is dropped, see `docs/decisions/0031-no-homebrew-cask-channel.md`. Nothing in the repo, the docs or the web surfaces mentions brew any more. Two things to revisit before that changes:

- **Submit to `homebrew/cask` only when both gates are clear.** (1) Real notarization: `notarytool submit --wait` + `stapler staple`, plus a Developer ID cert. Homebrew drops casks failing Gatekeeper from 2026-09-01. (2) Notability: a self-submitted cask (PR author owns the repo) needs **90 forks, 90 watchers, 225 stars**. Below that the audit rejects it automatically. Do not bother with an own tap as a workaround — Homebrew 6.0 made third-party taps untrusted by default, so it costs users a `brew trust` step or a fully qualified token
- **In-app update checker vs. Homebrew.** If an updater is ever added to the app, it must not fight a cask install: Homebrew owns upgrades for what it installed, so a self-replacing bundle would clobber it. Standard answer is to detect the install location or ship the updater only in the DMG build. Decide this *when* the updater is designed, not after a cask exists
