MISC:
- GITHUB RULES TO ENFORCE WHEN v0.9.9: main cannot be directly pushed on, disallow force pushes or anything with force, main can be contributed only via PR, CI from PR MUST pass, pages preview MUST pass on PR for landing and/or docs page development (+ maybe more)
- make docs.yml GH workflow nicely like landing.yml when docs are made!
- add note somewhere to track what things need review after something:
  - gh workflows mac version update 26 to 27 and onwards only when new apple software versions across platforms release (in this case bump mac image to mac27)
- ask AI to use claude.md file skill/plugin, then verify each claim in @CLAUDE.md, fix, imrpove, add missed things, delete unnecessary ones, fix if needed and greatly simplify and/or shorten the file - all while following best practices
- add domain of the project to private main gmail acc GSC
- "list known issues from the markdown file, understand each, research how to fix, and suggest a plan what and how to fix, i approve the plan, you write a optimized prompt to fix in one go in next clean session"

TODO LANDING
- add docs page URL somewhere in app, in nav, or separate section or whatever is best
- App Store URL for the iPhone & iPad card: the badge at `web/landing/index.html` (`assets/img/app-store.svg`) is an unlinked `<img>` until the listing exists. Wrap it in an `<a>` when it does.
- Mac App Store URL for the Mac card: same, `assets/img/mac-app-store.svg`.
- Verify the Homebrew cask line actually works before the brew card claims it: `brew install --cask crocapp` is printed with a copy button and nothing has published that cask yet. Blocked on notarization (see docs/known-issues.md).
- Verify `https://github.com/bakirgdev/CrocApp/releases/latest` resolves once a release exists — the "Mac, direct" card links to it and GitHub 404s that path on a repo with zero releases.
- CONTRIBUTING.md — the Contribute section links to `blob/main/CONTRIBUTING.md` and the file does not exist yet. 404 until it does.
- SECURITY.md — footer links to `blob/main/SECURITY.md`, same.
- CODE_OF_CONDUCT.md — footer links to `blob/main/CODE_OF_CONDUCT.md`, same.
- "How to build" links to `blob/main/README.md` with no anchor. Add a build section to the README and point the link at its exact `#anchor`.
- `web/landing/llms.txt` states "Not yet released" and lists the channels as pending. Update it on the first release, in the same change that updates the page copy — the two must agree.
- Footer carries a hand-typed "Page last updated" date. Bump it when the page copy changes (the sitemap's lastmod is stamped automatically by landing.yml; this one is not).
- `assets/banner.webp` is unused. `design/brand.md` assigns it to the README header, the landing hero and the social card; it appears in none of them. Use it or drop the claim.
- Apple ships the store badges in black and white; the repo has black only, and dark mode inverts it in CSS. Drop in Apple's white asset if the inversion ever looks wrong.

CC NEXT PROMPT
- > make some nice prompt for CC to review the whole app, fully test it, check if codewise and otherwise is ready, performant, optimized, code optimized for human contributors and AI, well commented but healthy doses (short is better), users ready, all features work. review, then make planned phases, then plan each phase and do it via multiple prompts using subagents for phase's plan. commit where fit and push on each phase done. deep but simple recap of what's done/verified/fixes. these are last checks of the app itself before app store publish. one known fix needed: prompt user for camera and local network permission after onboarding screen is closed on first launch and check state before using each feature

TO DO TASK LIST
- copy design from claude design in app for v1.1.0
- brew cask
- specialized skills/commands/agents while developing for QOL/DevEx (release, format, actions,... ask Claude Code for suggestions)
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
