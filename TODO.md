# TODO

Personal scratch list. Not a doc — never cite from `docs/`.

## Repo hardening (gate: v0.9.9)

Enforce on GitHub, all of these together:

- Main branch: no direct pushes, contributions via PR only
- Main branch: block force pushes of any kind
- Required status check: CI from the PR must pass
- Required status check: Pages preview must pass for landing and/or docs page changes
- Review for more rules worth adding at the same time
- **Before** making CI a required check: replace the `paths` allowlist in `ci.yml` with a change-detection job that reports success. Today a filtered-out PR runs zero jobs, so a required check stays pending forever (see `docs/knowledge/tooling.md`)
- Pin third-party actions to commit SHAs (`maxim-lobanov/setup-xcode`, `golangci/golangci-lint-action`) — mutable major tags are a supply-chain hole
- fix all security voulns flagged on github
- perform complete refactoring before public release

## Screenshots

Nothing exists in `assets/screenshots/` yet. Manifest of the six light/dark pairs to capture is in `assets/screenshots/README.md`. The app restyle has landed, so this is just blocked on a build worth photographing now.

- Capture the six pairs: mac-send, ios-receive, mac-settings, each light and dark, 2x, no device frames, no real codes
- Put them back in `README.md`. The `## Screenshots` section and its three `<picture>` blocks were removed because they rendered as broken images on the public repo page
- Add them to the docs guide pages (`web/docs/content/getting-started/first-transfer.md`, `guide/sending.md`, `guide/receiving.md`, `guide/settings-and-trust.md`). Images live in `web/docs/static/img/` and are referenced per locale, so add them once in English and the five locale trees inherit nothing: each locale copy needs the same markdown
- Landing page: decide whether the hero or the Features section gets one
- Store listings need their own separately sized set, not these

## Landing page (`web/landing/`)

- iPhone & iPad card: App Store badge (`assets/img/app-store.svg`) is an unlinked `<img>` in `index.html`. Wrap in `<a>` when the listing exists
- Mac card: same for the Mac App Store badge (`assets/img/mac-app-store.svg`)

## Signing cert (blocks every macOS release channel)

`scripts/build-devid.sh` archives fine, then stops at `DEVID-PENDING-CERT`. `security find-identity -v -p codesigning` shows one identity, `Apple Development: gracicbakir@icloud.com (5J25995FS2)`. No **Developer ID Application** cert exists, so nothing signable ships — not the unnotarized build, not notarization.

- Create a Developer ID Application cert at developer.apple.com (Certificates > Developer ID Application), install it in the login keychain, re-run `scripts/build-devid.sh`. Expect `DEVID-EXPORT-OK` then `DEVID-CHECK-OK`
- Only owner-account action; the script degrades on purpose rather than failing, so it will keep quietly saying PENDING until this is done
- After the cert: real notarization is still unwritten (`notarytool submit --wait` + `stapler staple`), see `docs/known-issues.md`
- Mac App Store is a separate cert (Apple Distribution / 3rd Party Mac Developer), and `Config/ExportOptions-MAS.plist` has still never been exercised

Also owner-only, at submission: answer the App Store Connect encryption questionnaire. `ITSAppUsesNonExemptEncryption` is now `true` in both plists (croc bundles its own AES-256-GCM/ChaCha20-Poly1305, so no exemption applies — `docs/decisions/0030-export-compliance-declaration.md`). The plist value and the answer you give must agree.

## Before tagging v0.9.9

- **Populate `CHANGELOG.md`'s `# v0.9.9` section.** It is still the "To populate" stub. The release job pulls that block as the release body and only fails on an *empty* section, so the stub would ship as the release notes
- Write the Gatekeeper instructions into that section: the build is ad-hoc signed, so first launch needs System Settings > Privacy & Security > Open Anyway. Verify the exact wording on a real macOS 26 download before publishing — the old Control-click > Open route no longer applies
- Rehearse first: Actions > Release > Run workflow, version `0.9.9`. It builds and uploads an artifact without tagging. Download the DMG, open it, check the window against `design/components.md` → DiskImage
- `scripts/build-dmg.sh` has never been run. `create-dmg` is not installed locally (`brew install create-dmg`)

## Homebrew, some day (not now)

Cask channel is dropped, see `docs/decisions/0031-no-homebrew-cask-channel.md`. Nothing in the repo, the docs or the web surfaces mentions brew any more. Two things to revisit before that changes:

- **Submit to `homebrew/cask` only when both gates are clear.** (1) Real notarization: `notarytool submit --wait` + `stapler staple`, plus a Developer ID cert. Homebrew drops casks failing Gatekeeper from 2026-09-01. (2) Notability: a self-submitted cask (PR author owns the repo) needs **90 forks, 90 watchers, 225 stars**. Below that the audit rejects it automatically. Do not bother with an own tap as a workaround — Homebrew 6.0 made third-party taps untrusted by default, so it costs users a `brew trust` step or a fully qualified token
- **In-app update checker vs. Homebrew.** If an updater is ever added to the app, it must not fight a cask install: Homebrew owns upgrades for what it installed, so a self-replacing bundle would clobber it. Standard answer is to detect the install location or ship the updater only in the DMG build. Decide this *when* the updater is designed, not after a cask exists

## Ops / external

- Build specialized skills/commands/agents for QOL/DevEx while developing (release, format, actions, etc.) — ask Claude Code for suggestions
- fix ADRs: all have to be accepted, reordered to make sense, optimized content. this is due to preparing repo for public release, so all ADRs must be nice and clean and organized and no traces of 'battlefield'.

## Prompts to run in a clean session
  
Known-issues sweep:

"
Read `docs/known-issues.md`. For every entry: find the real cause in the code and cite `file:line`, research the correct fix (context7, web, gopls/xcode MCP, or subagents, not guesses), and state its blast radius.

Output one plan: issues ranked by severity, each with root cause, chosen fix, files touched, and the command that verifies it. Change no code this session.

After I approve the plan, write a single self-contained prompt that carries out the whole thing in one clean session.

Think before answering (maximum reasoning)
"
