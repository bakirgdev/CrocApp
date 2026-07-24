CC WORK
- > napisi neki prompt da claude pogleda app, fully je istestira sa subagentima i vidi je li codewise i to spremana za relase i slicno. ugl reci radi si implementation plan in phases i sad nek on isplanira i uradi review cijele app i fixa sve sto treba i commita redom fino. ovo je posljednja provjera pred spremanje za app store i objavu v1.

TO DO
- github issue & pr templates
- brew cask
- specialized skills/commands/agents while developing for QOL/DevEx (release, format, actions,... ask Claude Code for suggestions)
- landing website (static, github pages, domain pointed - build)
- docs website (static, github pages, domain pointed - find nice provider)
- README.md
- for sharing this OSS, make blog on bakir.dev as entrypoint to everything about the project, then share blog link with curated msg to each recipient
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
- prompt about camera and local network should be after onboarding closed on first launch!

V1.1 DESIGN COPY (Claude Design)
- explore the /desing-sync command what it does
- rules:
  - only use sf icons
  - only use defaul device font
  - make design tokens in markdown files in `design/` directory (needs to be used in landing and docs pages)
  - features for history (make if not present): toggle on/off, delete each row, delete all
