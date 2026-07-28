# Contributing to CrocApp

Thanks for taking the time. CrocApp is free, MIT-licensed, and open to any pull request: bug fixes, features, docs, design, landing page. You do not need permission or an assigned issue to start.

Two things make this repo different from a typical SwiftUI app, and most review friction comes from missing them:

1. **A green build is not evidence a transfer works.** Real behavior is proven by live-transfer harnesses in `scripts/`, not by the compiler.
2. **Anything visual is bound to `design/`.** Tokens only, SF Symbols only, system font only.

Both are spelled out below.

| | |
|---|---|
| [Code of Conduct](CODE_OF_CONDUCT.md) | How we behave here |
| [Where to start](#where-to-start) | Issues, labels, feature numbers |
| [Setup](#setup) | Toolchain, first build, croc CLI |
| [Branches and commits](#branches-and-commits) | Conventional Branch + Conventional Commits |
| [Code style](#code-style) | swift-format, golangci-lint, dependencies |
| [Design rules](#design-rules) | Tokens, symbols, themes, screenshots |
| [Verification](#verification) | What to run, and how to report it |
| [Docs](#docs) | ADRs, knowledge, known issues |
| [AI-assisted contributions](#ai-assisted-contributions) | Allowed, with disclosure |
| [Opening a pull request](#opening-a-pull-request) | Flow and expectations |
| [Unlikely to be merged](#unlikely-to-be-merged) | Save yourself the work |
| [Licensing](#licensing) | Inbound equals outbound |

## Code of Conduct

This project follows the [Contributor Covenant 3.0](CODE_OF_CONDUCT.md). Taking part means agreeing to it. Report problems to <bakirgdev@gmail.com>.

## Where to start

Before filing anything, check [`docs/known-issues.md`](docs/known-issues.md). Every defect in there was found on purpose and consciously not fixed, so a bug report that repeats one is a duplicate on arrival.

| You want to | Go to |
|---|---|
| Report a bug | [Bug report form](https://github.com/bakirgdev/CrocApp/issues/new?template=bug_report.yml) |
| Propose a feature | [Feature request form](https://github.com/bakirgdev/CrocApp/issues/new?template=feature_request.yml) |
| Ask a question or float an idea | [Discussions](https://github.com/bakirgdev/CrocApp/discussions) |
| Report a vulnerability | [Private advisory](https://github.com/bakirgdev/CrocApp/security/advisories/new), never a public issue. See [SECURITY.md](SECURITY.md) |
| Report a transfer, relay, or crypto bug that also reproduces with the `croc` CLI | [Upstream croc](https://github.com/schollz/croc/issues) |

Useful labels: `good first issue`, `help wanted`, `bug`, `enhancement`, `documentation`.

Features carry stable numbers (`F1`, `F2`, …) used across code comments, issues, and the README. The roadmap, including what shipped and what is deferred, is [`docs/knowledge/features.md`](docs/knowledge/features.md). Reference the number when it exists.

> [!TIP]
> Any PR is welcome, but for a large feature or a refactor that touches the transfer engine, open an issue or a discussion first. Not for approval, just so you do not spend a weekend on something that collides with work already in flight.

## Setup

Requires **macOS 26**, **Xcode 26.6** (the pin lives in [`.xcode-version`](.xcode-version)), and **Go 1.26.5 or newer**. `gomobile` and `gobind` install themselves on first run.

```bash
git clone https://github.com/bakirgdev/CrocApp.git
cd CrocApp
scripts/build-xcframework.sh   # Go engine -> CrocKit/Croc.xcframework
open app/CrocApp.xcodeproj
```

> [!IMPORTANT]
> A fresh clone builds nothing until the xcframework exists. `CrocKit`'s binary target points at a gitignored build artifact, so `scripts/build-xcframework.sh` is not optional. Rerun it after any change under `crocmobile/`. See [ADR 0006](docs/decisions/0006-gomobile-binding.md).

The verification harnesses also need the real `croc` CLI and outbound network access to the public relay:

```bash
go install github.com/schollz/croc/v10@v10.5.0   # lands at ~/go/bin/croc, the default
# or: brew install croc
```

Env: `CROC` overrides the CLI path (default `~/go/bin/croc`), `SIM` picks the simulator (default `iPhone 17 Pro`; list them with `xcrun simctl list devices`).

Deeper references: [`docs/BUILDING.md`](docs/BUILDING.md) for the exact toolchain and troubleshooting, [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the system map, [`docs/GLOSSARY.md`](docs/GLOSSARY.md) for unfamiliar terms.

### What lives where

| Path | What it is | Read first |
|---|---|---|
| `crocmobile/` | Go wrapper around croc v10.5.0, bound into `Croc.xcframework`. `session.go` is the engine | [`docs/knowledge/crocmobile-bridge.md`](docs/knowledge/crocmobile-bridge.md) |
| `CrocKit/` | Swift package: `CrocEngine` actor, `AsyncStream<TransferEvent>` | same file |
| `app/CrocApp/` | SwiftUI app, iOS + macOS | [`docs/knowledge/app-ui-architecture.md`](docs/knowledge/app-ui-architecture.md) |
| `app/CrocShare/` | Share extension | same file |
| `design/` | Canonical design system for app, landing, docs | [`design/README.md`](design/README.md) |
| `web/landing/` | The crocapp.dev landing page | `design/README.md` |
| `docs/` | Knowledge base, ADRs, known issues | [`docs/knowledge/README.md`](docs/knowledge/README.md) |
| `scripts/` | Build and live-transfer verification harnesses | the script headers |

> [!WARNING]
> The bridge and UI knowledge files hold hard-won invariants: event ordering, fd0 prompt-pipe semantics, per-file sender answers, relay-address blanking, room collisions on 4-character code prefixes. Most "obvious" fixes in those areas re-break one of them. Read the relevant file before you edit.

## Branches and commits

Branch off `main`, using [Conventional Branch](https://conventional-branch.github.io/) naming:

```
feat/qr-scan-torch
fix/relay-address-blanking
docs/contributing-guide
chore/bump-golangci-lint
refactor/transfer-controller-state
```

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>
```

| Type | Use for |
|---|---|
| `feat` | New user-visible capability |
| `fix` | Bug fix |
| `docs` | Docs, ADRs, README, comments-only changes |
| `style` | Formatting only, no behavior change |
| `refactor` | Restructuring with no behavior change |
| `perf` | Performance work |
| `build` | Build scripts, gomobile, Xcode project settings, dependencies |
| `ci` | Workflows under `.github/` |
| `chore` | Everything else with no source impact |

Scopes, one per commit, matching the repo layout: `app`, `share`, `crockit`, `crocmobile`, `design`, `landing`, `docs`, `ci`, `scripts`, `assets`. Omit the scope when a change genuinely spans everything.

Rules for the subject line: imperative and present tense ("add", not "added" or "adds"), lowercase after the colon, no trailing period, roughly 72 characters or fewer. Put the why in the body when it is not obvious from the diff. Breaking changes get a `!` after the scope and a `BREAKING CHANGE:` footer.

```
fix(crocmobile): blank the relay address on LAN-only transfers

The receiver rendered the relay host even when the connection never
left the subnet, which reads as a privacy leak. Blank it at the event
boundary rather than in the view, so both platforms inherit the fix.

Fixes #42
```

Keep commits scoped. One logical change per commit beats one commit per file, and beats a single commit for an entire feature.

## Code style

Match the surrounding file. When in doubt, the formatter decides.

```bash
# Swift, from the repo root. Same commands CI runs
xcrun swift-format format --in-place --recursive --parallel app/CrocApp app/CrocShare CrocKit/Sources
xcrun swift-format lint --recursive --parallel --strict app/CrocApp app/CrocShare CrocKit/Sources

# Go, from crocmobile/
golangci-lint run ./...
govulncheck ./...
```

swift-format ships with the toolchain, so there is nothing to install. Config lives in [`.swift-format`](.swift-format): 4-space indent, non-indented `#if` bodies. Go config is in [`crocmobile/.golangci.yml`](crocmobile/.golangci.yml). Rationale for the whole toolchain is [ADR 0014](docs/decisions/0014-code-style-and-ci.md).

Other expectations:

- **Comments explain why, never what.** Do not delete existing comments unless the code they describe is going away.
- **Stay in scope.** No drive-by refactors, no renaming unrelated symbols, no reformatting files your change does not touch. A diff that is 90% noise gets sent back.
- **No new third-party dependencies** without agreeing on them in an issue first. Every dependency in `crocmobile/` ends up inside a shipped binary that moves people's files.
- Swift concurrency is used as designed: `CrocEngine` is an actor, UI state is main-actor. Do not add locks or dispatch queues to work around a warning.

## Design rules

Anything visual, in the app or on the web, starts at [`design/README.md`](design/README.md). Its binding rules, in short:

1. **Tokens, not literals.** No raw hex, px, pt, or duration in app or site code. If a value is missing, add the token to `design/` first (and mirror it into `design/tokens.css` for web).
2. **SF Symbols only in the app.** Never bundle an icon font, never draw a custom glyph where a symbol exists.
3. **System font only.** No bundled Apple font files, ever. They are not redistributable.
4. **Both themes, always.** Every surface has a light and a dark value.
5. **Accessibility floor is binding**: 4.5:1 for body text, 3:1 for large text and UI boundaries, 44x44pt minimum hit target, `prefers-reduced-motion` and `prefers-reduced-transparency` respected, and never encode transfer direction in color alone.

UI pull requests need **before and after screenshots in both light and dark**, and on both platforms if both are affected.

## Verification

This is the part reviewers actually check.

A build that compiles proves nothing about a transfer. CI deliberately does not run the harnesses (they need a public relay and are flaky on shared runners), so that job falls on you.

| What you changed | What to run |
|---|---|
| Any Swift under `app/` or `CrocKit/Sources/` | swift-format lint, plus a macOS and/or iOS Simulator build |
| Anything in `crocmobile/` | `golangci-lint run ./...`, `govulncheck ./...`, then `scripts/build-xcframework.sh` |
| `crocmobile/session.go`, `CrocKit/Sources/`, or `TransferController` | the matching harness below, no exceptions |
| Share extension | `scripts/verify-share-sim.sh` |
| `web/landing/` | Load it locally: `cp design/tokens.css web/landing/ && python3 -m http.server --directory web/landing` |
| Docs, ADRs, comments only | Nothing beyond reading it back |

```bash
scripts/verify-interop.sh     # 9 scenarios, engine <-> croc CLI, both directions, decline, cancel, relay, LAN
scripts/verify-app-mac.sh     # macOS app, 6 directions: both ways, --local, custom relay, --no-compress, --ask
scripts/verify-app-sim.sh     # iOS simulator, CLI -> app via --auto-receive
scripts/verify-share-sim.sh   # share-extension handoff (App Group staging) -> CLI receive
```

Builds, if you prefer the command line to Xcode:

```bash
cd app
xcodebuild -scheme CrocApp -destination 'platform=macOS' -derivedDataPath /tmp/dd-mac build
xcodebuild -scheme CrocApp -destination "platform=iOS Simulator,name=$SIM" -derivedDataPath /tmp/dd-sim build
```

**Paste the harness output into the pull request.** Not a summary of it, the output.

> [!IMPORTANT]
> If you could not run something, write **"not verified"** and say why (no macOS 26 machine, no outbound network, no croc CLI). That is an honest, acceptable answer and the maintainer will run it before merge. A silent gap, or a claim that something passed when it was never run, is not. Unverified transfer-path changes are not merged, by anyone.

## Docs

Documentation is part of the change, not a follow-up. Before you open the PR:

| What happened | Where it goes |
|---|---|
| You made or reversed an architectural decision | New ADR in [`docs/decisions/`](docs/decisions/README.md), next number. Reversing an old one means a new ADR plus `Status: superseded by NNNN` on the old |
| A fact inside an existing ADR stopped being true | Overwrite it in place. No amendment markers, git history is the changelog. Re-verify what it claims |
| You learned something durable about the project | Add or update a file in [`docs/knowledge/`](docs/knowledge/README.md), and `CLAUDE.md` if it changes how the repo is worked in |
| You fixed a listed defect | Delete its line from [`docs/known-issues.md`](docs/known-issues.md) |
| You found a defect and consciously left it | Add a line to `docs/known-issues.md` |
| You noticed a stale or wrong doc | Fix or delete it in the same PR |

Keep docs small, dense, direct. Never cite a `TODO.md` or `PLAN.md` from inside `docs/`; those are scratch files that get deleted, and a doc pointing at one rots immediately. Do not use "Phase N" as a fact anywhere. Say what the thing is, not when it was built.

If nothing was doc-worthy, tick that box in the PR template and say so.

## AI-assisted contributions

Allowed, and used heavily here. This repo carries a `CLAUDE.md` and a `.claude/` directory for exactly that reason.

Two conditions:

- **Disclose it.** If a model wrote a substantial part of the change, say so in the pull request. One line is enough. It tells the reviewer where to look harder, and nobody is judged for it.
- **You own the code.** You understand every line, you can explain why each one is there, and you ran the [verification](#verification) yourself. "The model said it works" is not verification.

Bulk-generated pull requests that the author has not read, does not understand, or cannot verify get closed without review. That is a statement about unreviewed output, not about tooling.

## Opening a pull request

1. Fork, branch off `main`, commit as described above.
2. Rebase on the current `main` so the diff is clean.
3. Open the PR against `main` and fill in [the template](.github/pull_request_template.md): what and why, the verification commands with their output, the docs checklist, screenshots for UI.
4. Link the issue with `Fixes #123` when one exists.
5. Keep it focused. Two unrelated changes are two pull requests.

Draft PRs are welcome for early feedback. Mark them as drafts so it is clear what you want.

What to expect: CrocApp has one maintainer, so review time varies and there is no response-time promise. Comments will be direct and specific, and that is about the code, never about you. Merges are squashed, so your branch's intermediate commits do not need to be pretty, but the final PR title does (it becomes the commit subject, so give it the same Conventional Commits treatment).

Things that get sent back rather than merged: unverified changes to the transfer path, raw hex or px in UI code, unrelated reformatting mixed into a fix, a new dependency nobody discussed, and PRs whose description does not say what was actually run.

## Unlikely to be merged

Not a hard no, but open an issue first and expect a long conversation. These run against decisions that are already recorded:

| Change | Why |
|---|---|
| Windows, Linux, or Android support | Apple-platform only by design. The croc CLI covers everywhere else and interoperates with the app |
| Support for iOS or macOS below 26 | Floor is pinned at exactly `26.0`, never a minor ([ADR 0003](docs/decisions/0003-min-os-ios26-macos26.md)) |
| Telemetry, analytics, crash reporting, ads | No data leaves the device. This is a product promise, not a technical gap |
| A paid tier, license keys, or in-app purchases | MIT and free, permanently. Funding is optional sponsorship only |
| Shelling out to the `croc` binary instead of the embedded library | The Go library binding is the whole architecture ([ADR 0006](docs/decisions/0006-gomobile-binding.md)) |
| A new third-party dependency | Discuss it first. Everything in `crocmobile/` ships inside the binary |
| A UIKit or AppKit rewrite of a SwiftUI surface | Native SwiftUI is the deliberate choice ([ADR 0005](docs/decisions/0005-native-swiftui.md)) |
| Bundled fonts or icon sets | Undistributable in Apple's case, and unnecessary in every other |
| Rewriting croc's protocol or crypto | Belongs [upstream](https://github.com/schollz/croc), where the whole ecosystem gets it |

## Licensing

CrocApp is [MIT](LICENSE). By opening a pull request you agree that your contribution is licensed under the same terms. There is no CLA and no sign-off requirement.

Do not paste code you did not write and cannot license this way, including code from projects under a copyleft or proprietary license.

## Contact

Issues and [Discussions](https://github.com/bakirgdev/CrocApp/discussions) for anything public, <bakirgdev@gmail.com> for Code of Conduct matters, and a [private advisory](https://github.com/bakirgdev/CrocApp/security/advisories/new) for vulnerabilities.
