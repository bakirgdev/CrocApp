CC NEXT PROMPT
- > make some nice prompt for CC to review the whole app, fully test it, check if codewise and otherwise is ready, performant, optimized, code optimized for human contributors and AI, well commented but healthy doses (short is better), users ready, all features work. review, then make planned phases, then plan each phase and do it via multiple prompts using subagents for phase's plan. commit where fit and push on each phase done. deep but simple recap of what's done/verified/fixes. these are last checks of the app itself before app store publish. one known fix needed: prompt user for camera and local network permission after onboarding screen is closed on first launch and check state before using each feature

LANDING PAGE — PENDING LINKS & ASSETS
Every item here is an `href="#"` placeholder in web/landing/index.html until it exists.
Plan: PLAN.md. Grep for `href="#"` to find them all.

URLs needed
- iOS App Store listing URL
- Mac App Store listing URL
- notarized DMG download URL (GitHub release asset)
- Homebrew cask — tap/formula name, confirm `brew install --cask crocapp` is the real command
- TestFlight public link (if a beta channel stays open post-launch)
- CONTRIBUTING.md (already listed below — landing "Contribute" section links to it)
- CODE_OF_CONDUCT.md (already listed below)
- SECURITY.md (already listed below)
- docs/BUILDING.md (already listed below — landing links "how to build")
- "good first issue" label URL — needs the label to exist and have issues in it

Assets — to do
- replace og.jpg with a 1200×630 card built from design tokens: mascot, CrocApp wordmark, the hero H1, crocapp.dev. Reasons: current file is 1200×797 so every platform centre-crops ~21% off top and bottom; it carries no wordmark/headline/URL so a share renders as an untitled drawing; it uses sky blue + kelly green instead of croc green #1E9E6A, against the one-accent rule in design/brand.md; and its crocodile is not the one in assets/mascot.png, so two mascots read as two brands. This is the asset every HN/Reddit/X/Slack share renders before anyone reads a word.

Assets — done
- favicon set generated from assets/mascot.png, in web/landing/assets/img/favicon/
- favicon.svg deleted: it was a 69 KB base64 PNG in an <svg> wrapper, not a vector, and browsers prefer it over the 3.6 KB PNG
- site.webmanifest fixed: icon paths were root-absolute and would 404; purpose was maskable-only and cropped the mascot; theme/background colors were #000000, now #1E9E6A / #FFFFFF (keep in sync with design/colors.md by hand — JSON cannot read CSS custom properties)
- mascot stays PNG, no webp re-encode (owner decision)

Owner actions — done 2026-07-25
- DNS records for crocapp.dev at the registrar
- Settings → Pages → Source = GitHub Actions, custom domain, Enforce HTTPS
- domain verified at github.com/settings/pages

TO DO TASK LIST
- copy design from claude design in app
- github issue & pr templates
- brew cask
- specialized skills/commands/agents while developing for QOL/DevEx (release, format, actions,... ask Claude Code for suggestions)
- README.md
- protect main branch to have it contributed on only via PRs
- protect main from force pushes of any type
- before enabling CI as a required status check: swap the `paths` allowlist in ci.yml for a change-detection job that reports success. A filtered-out PR currently runs zero jobs, which leaves a required check pending forever (see docs/knowledge/tooling.md)
- pin third-party actions to commit SHAs (maxim-lobanov/setup-xcode, golangci/golangci-lint-action); mutable major tags are a supply-chain hole
- CONTRIBUTING.md — how to build, branch/PR conventions, code style, how to run tests, DCO/CLA if any (none needed for MIT solo project)
- CODE_OF_CONDUCT.md — Contributor Covenant is the default choice, low effort, signals a welcoming project
- CHANGELOG.md — Keep a Changelog format, even if sparse early on
- NOTICE or THIRD_PARTY_LICENSES.md — explicit croc MIT attribution + any Go module licenses you vendor (gomobile bindings pull in deps)
- release workflow
- docs workflow
- docs/GLOSSARY.md
- SECURITY.md — given the CROC_SECRET/argv invariant, worth a short policy on how to report security issues privately (email, not public issue) since transfer secrets are the whole trust model
- docs/ARCHITECTURE.md — SwiftUI app structure, how the Go engine is bridged (gobind), where the sandbox boundaries are. This is also your Swift learning trail, worth keeping current
- docs/BUILDING.md — exact Xcode version, Go version, gomobile setup steps. Given the "verify gomobile/Xcode compat on every update" invariant, this file should be the living record of what worked
