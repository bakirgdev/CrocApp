MISC:
- GITHUB RULES TO ENFORCE WHEN v0.9.9: main cannot be directly pushed on, disallow force pushes or anything with force, main can be contributed only via PR, CI from PR MUST pass, pages preview MUST pass on PR for landing and/or docs page development (+ maybe more)
- make docs.yml GH workflow nicely like landing.yml when docs are made!
- add note somewhere to track what things need review after something:
  - gh workflows mac version update 26 to 27 and onwards only when new apple software versions across platforms release (in this case bump mac image to mac27)
- fix proj's claude md to prefer simpler responses with simpler words but retaining details
- add 2 badges from app store and mac app store to website from here: https://developer.apple.com/app-store/marketing/guidelines/
- ask AI to check if xcode and go mcp servers can be wrapped in caveman-shrink for compression
- ask AI to check if .swift-format has industry standard rules appropriate/fitting for OSS project and contributions
- ask AI to use claude.md file skill/plugin, then verify each claim in @CLAUDE.md, fix, imrpove, add missed things, delete unnecessary ones, fix if needed and greatly simplify and/or shorten the file - all while following best practices

CC NEXT PROMPT
- > make some nice prompt for CC to review the whole app, fully test it, check if codewise and otherwise is ready, performant, optimized, code optimized for human contributors and AI, well commented but healthy doses (short is better), users ready, all features work. review, then make planned phases, then plan each phase and do it via multiple prompts using subagents for phase's plan. commit where fit and push on each phase done. deep but simple recap of what's done/verified/fixes. these are last checks of the app itself before app store publish. one known fix needed: prompt user for camera and local network permission after onboarding screen is closed on first launch and check state before using each feature

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
