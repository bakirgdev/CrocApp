CC WORK
- > make some nice prompt for CC to review the whole app, fully test it, check if codewise and otherwise is ready, performant, optimized, code optimized for human contributors and AI, well commented but healthy doses (short is better), users ready, all features work. review, then make planned phases, then plan each phase and do it via multiple prompts using subagents for phase's plan. commit where fit and push on each phase done. deep but simple recap of what's done/verified/fixes. these are last checks of the app itself before app store publish. one known fix needed: prompt user for camera and local network permission after onboarding screen is closed on first launch and check state before using each feature

TO DO
- copy design from claude design in app
- github issue & pr templates
- brew cask
- specialized skills/commands/agents while developing for QOL/DevEx (release, format, actions,... ask Claude Code for suggestions)
- README.md
- protect main branch to have it contributed on only via PRs
- protect main from force pushes of any type
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
