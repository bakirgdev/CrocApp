# TODO

Personal scratch list. Not a doc — never cite from `docs/`.

## FROM REFACTOR

### MAINTAINER
- see and manage discussions on github via GUI!
- maybe later add codeowners?

### CLAUDE CODE
- in contribution guide or somewhere fitting there should be a word about rtk and caveman, i.e. any tool used by the original creator/maintainer that are opinionated, so every other contributor can set those up and know what they do, since i want to enforce those. research and suggest implementation (dont do! just suggest). right now i know those are custom project mcp servers, custom plugins needing to be used etc.
- via local gh cli, if you can, fetch what current issue labels exists and their colors, then suggest if there are any labels missing or that would be good to be added, suggest only, i approve.
- revise what harnesses and verifications are actually needed for PR template and update them, reduce harshness on PR makers for this.
- what is the best PR merging strategy for this repo? suggest, i approve. (squash, rebase, merge commit, etc.)
- make newe file MAINTENANCE.md where you will store things needing attention for maintenance of the project. first thing, in the Monthly section is to check versions of github actions workflows e.g. 'actions/checkout' or 'actions/upload-pages-artifact' and bump if safe, etc.
- any ideas for new github workflows for this project? suggest, i approve. (e.g. for PRs, for releases, for security, for code quality, etc. - anything!)
- add direction correction for updating docs: since CLAUDE.md files will also be per dir, claude should update those only if something core changed by overwriting, not appending what changed. on each file modify it should be as the file is freshly generated to reflect actual image of what is describes, not historical info!
- in maintenance file add entry to weekly check for skills updates in .claude dir
- when reviewing the app itself: is it nicely styled and working for all devices supporting ios/macos 26? iphone 11 and onwards and macs with m1 onward?
- conduct research and suggest authoritative skills to add to project that will benefit the project
- make screenshots of app: every possible view, for iphone, ipad and mac devices, both in dark and light mode, show some mock data to demonstrate the app's functionality.
- when tsgo (typescript v7) becomes stable and has version with API and docusaurus supports it, update the versions for it in the project and update docusaurus app if there are any breaking changes.
- refactor app/, CrocKit/ and crocmobile like other directories, you skipped those for later phase of refactoring/validation/improvement. same for: .gitignore (everything must be done so cc decides if anything else to add or something to remove/update), docs/ (everything must be refactored in order to upate docs to actual state of app)
- Sync CrocApp's design system into its two mirrors. design/ is canonical: start
at design/CLAUDE.md, read what it indexes, run scripts/verify-contrast.py.
Bring web/landing, web/docs and app/CrocApp in line with it, including the
rules that have no code yet (hover, haptics, phase choreography, loading
buttons, capitalization, number formats). Never invent a value: if one is
missing, add the token to design/ first. If the shipped code looks better than
the spec, stop and ask instead of changing either. Verify with a macOS and an
iOS build, swift-format lint, and the landing page loaded locally; report
anything not run as "not verified".

--

## Before repo public release

- Main branch: no direct pushes, contributions via PR only
- Main branch: block force pushes of any kind
- main branch: block merge if not all checks pass
- main branch: block merge if not at least 1 approval is present
- add appropriate rules for pushing tags, since new tags build releases on github, only maintainers can do it!
- Required status check: CI from the PR must pass
- Required status check: Pages preview must pass for landing and/or docs page changes
- Review for more rules worth adding at the same time
- Build specialized skills/commands/agents for QOL/DevEx while developing (release, format, actions, etc.) — ask Claude Code for suggestions
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

Also owner-only, at submission: answer the App Store Connect encryption questionnaire. `ITSAppUsesNonExemptEncryption` is now `true` in both plists (croc bundles its own AES-256-GCM/ChaCha20-Poly1305, so no exemption applies). The plist value and the answer you give must agree.

## Homebrew, some day

Cask channel is dropped. Nothing in the repo, the docs or the web surfaces mentions brew any more. Two things to revisit before that changes:

- **Submit to `homebrew/cask` only when both gates are clear.** (1) Real notarization: `notarytool submit --wait` + `stapler staple`, plus a Developer ID cert. Homebrew drops casks failing Gatekeeper from 2026-09-01. (2) Notability: a self-submitted cask (PR author owns the repo) needs **90 forks, 90 watchers, 225 stars**. Below that the audit rejects it automatically. Do not bother with an own tap as a workaround — Homebrew 6.0 made third-party taps untrusted by default, so it costs users a `brew trust` step or a fully qualified token
- **In-app update checker vs. Homebrew.** If an updater is ever added to the app, it must not fight a cask install: Homebrew owns upgrades for what it installed, so a self-replacing bundle would clobber it. Standard answer is to detect the install location or ship the updater only in the DMG build. Decide this *when* the updater is designed, not after a cask exists
