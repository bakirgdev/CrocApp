# Contributing to CrocApp

Thanks for taking the time. CrocApp is free, MIT-licensed, and open to any pull request: bug fixes, features, docs, design, landing page. You do not need permission or an assigned issue to start.

Two things make this repo different from a typical SwiftUI app, and most review friction comes from missing them:

1. **A green build is not evidence a transfer works.** Real behavior is proven by live-transfer harnesses in `scripts/`, not by the compiler.
2. **Anything visual is bound to `design/`.** Tokens and system styles, SF Symbols only in the app, system font only.

## Code of Conduct

This project follows the [Contributor Covenant 3.0](CODE_OF_CONDUCT.md). Taking part means agreeing to it. Report problems to <bakirgdev@gmail.com>.

## Where to start

| You want to | Go to |
|---|---|
| Report a bug | [Bug report form](https://github.com/bakirgdev/CrocApp/issues/new?template=bug_report.yml) |
| Propose a feature | [Feature request form](https://github.com/bakirgdev/CrocApp/issues/new?template=feature_request.yml) |
| Ask a question or float an idea | [Discussions](https://github.com/bakirgdev/CrocApp/discussions) |
| Report a vulnerability | [Private advisory](https://github.com/bakirgdev/CrocApp/security/advisories/new), never a public issue. See [SECURITY.md](SECURITY.md) |
| Report a transfer, relay, or crypto bug that also reproduces with the `croc` CLI | [Upstream croc](https://github.com/schollz/croc/issues) |

Area labels (`macos`, `ios`, `ipados`, `engine`, `ui`, `docs-site`, `ci`) say which part of the project an issue touches.

> [!TIP]
> For a large feature or a refactor that touches the transfer engine, open an issue or a discussion first. Not for approval, just so you do not spend a weekend on something that collides with work already in flight.

## Setup

Requires a Mac with macOS 26 or newer, Xcode and Go. [`docs/BUILDING.md`](docs/BUILDING.md), "Prerequisites", lists the exact versions and where each is pinned.

```bash
git clone https://github.com/bakirgdev/CrocApp.git
cd CrocApp
```

The harnesses also need the `croc` CLI at the version pinned in `crocmobile/go.mod`. The first build, the toolchain table and every check are in [`docs/BUILDING.md`](docs/BUILDING.md); how the code fits together is in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

### Editor setup

Xcode needs nothing extra. For another SourceKit-LSP editor, run `xcode-build-server config -project app/CrocApp.xcodeproj -scheme CrocApp` once after a build (`brew install xcode-build-server`); the gitignored `buildServer.json` holds paths for your machine. For Go, set `GOFLAGS=-tags=croc_no_tailcat` so `gopls` sees the files the build does.

## Commits

Not enforced, but strongly advised: [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/) and the usual git message rules.

```
<type>(<scope>): <subject>

<body: why, when the diff does not make it obvious>

Fixes #42
```

- Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`. The scope is optional and names the area, such as `crocmobile` or `app`.
- Subject: imperative ("add", not "added"), lowercase after the colon, no trailing period, 72 characters or fewer.
- Breaking change: `!` after the type or scope, plus a `BREAKING CHANGE:` footer.

Pull requests are squash-merged, and the PR title becomes the commit subject on `main`. That makes the PR title the one place this convention matters most. Commits inside your branch can be as messy as you like.

## Code style

Match the surrounding file. When in doubt, the formatter decides.

```bash
# Swift
scripts/format-swift.sh            # rewrite in place, then lint
scripts/format-swift.sh --lint     # lint only, exactly what CI runs

# Go (from crocmobile/; the engine ships without Tailcat, see docs/BUILDING.md)
export GOFLAGS=-tags=croc_no_tailcat
golangci-lint run ./...
go tool govulncheck ./...
```

- **Comments explain why, never what.** Do not delete existing comments unless the code they describe is going away.
- **Stay in scope.** No drive-by refactors, no renaming unrelated symbols, no reformatting files your change does not touch.
- **No new third-party dependencies** without agreeing on them in an issue first. A dependency ships inside an app that reads and writes people's files.

## Design rules

Anything visual, in the app, the web or elsewhere, follows [`design/AGENTS.md`](design/AGENTS.md): design tokens and system text styles instead of raw colors and fixed sizes, the system control first, SF Symbols only in the app, system font only, a light and a dark value for every surface.

```bash
scripts/verify-design.sh   # tokens.css = DesignTokens.swift = color sets, every contrast ratio in `design/principles.md`, and no raw colors in web code
```

CI runs it on any change to `design/`, app Swift, color sets or web CSS. A failure means your change or `design/` is wrong: fix one of them, never the check. UI pull requests need **before and after screenshots in light and dark**, on both platforms if both are affected.

## Verification

A build that compiles proves nothing about a transfer. CI runs formatting, lint, the builds, the unit tests and `verify-interop.sh` against a local relay. Everything else that applies to your change is yours to run:

| What you changed | What to run |
|---|---|
| Swift under `app/` or `CrocKit/` | `scripts/format-swift.sh --lint`, the unit tests, a macOS and an iOS Simulator build |
| Anything in `crocmobile/` | `go test -race ./...` and `golangci-lint run ./...` with `GOFLAGS=-tags=croc_no_tailcat`, then `scripts/build-xcframework.sh` |
| `crocmobile/session.go`, `CrocKit/Sources/` or `TransferController` | the matching transfer harness, every time |
| Anything visual | `scripts/verify-design.sh` |
| Markdown | `scripts/verify-docs.sh` |

The commands, and what each harness covers and needs, are in [`docs/BUILDING.md`](docs/BUILDING.md) under "Format and lint" and "Verification harnesses".

### Tests

Non-UI logic gets unit tests: Go's `testing` in `crocmobile/`, Swift Testing in `CrocKit/Tests/` and `app/CrocAppTests/`. Tests that write settings or secrets use an injected store (`MemorySettingsStorage`, `FakeSecretStore`), never the real `UserDefaults` or Keychain, and never `UserDefaults(suiteName:)`, which leaves a plist behind in the sandbox container. There is no XCUITest: gestures and the camera are checked by hand, and transfers by the harnesses. A unit test never replaces a harness run.

**Paste the harness output into the pull request**, the summary lines and any failures. If you could not run something, write **"not verified"** and say why: the maintainer runs it before merge. Claiming a pass for something that never ran is the one answer that is not acceptable.

## Docs

Documentation is part of the change.

- A user-visible change gets a line under `## [Unreleased]` in [`CHANGELOG.md`](CHANGELOG.md), written for someone deciding whether to update.
- A change to how something works inside updates the doc that describes it: [`docs/AGENTS.md`](docs/AGENTS.md) says which file owns which fact, and has the writing rules.
- Fixing a listed defect deletes its item from [`docs/known-issues.md`](docs/known-issues.md); finding one and leaving it adds an item.
- Run `scripts/verify-docs.sh` after editing any markdown.

## AI-assisted contributions

Allowed, and used heavily here. Two conditions:

- **Disclose it.** Fill in the AI assistance line in the PR template, even though AI use is common. You are responsible for reporting it. It tells the reviewer where to look harder, and nobody is judged for it.
- **You own the code.** You understand every line, you can explain why each one is there, and you ran all verifications and checks yourself. "The model said it works" is not verification.

Bulk-generated pull requests that the author has not read, does not understand, or cannot verify get closed without review.

## Opening a pull request

1. Fork the repo and branch off `main`. Name the branch `<type>/<short-slug>` with a Conventional Commits type, for example `fix/receive-progress` or `feat/saved-codes`.
2. Add or update automated tests for new or changed behavior: Go tests in `crocmobile/`, Swift tests in `CrocKit/Tests/` or `app/CrocAppTests/`. A bug fix comes with a test that fails without it, where one is practical.
3. Rebase on the current `main` before opening, so the diff is clean.
4. Open the PR against `main` with a Conventional Commits title, and fill in [the template](.github/pull_request_template.md).
5. Link the issue with `Fixes #123` when one exists.
6. Keep it focused. Two unrelated changes are two pull requests.

Draft PRs are welcome for early feedback.

CrocApp has one maintainer, so review time varies and there is no response-time promise. Review comments are direct and about the code, never about you.

## Decisions and maintainers

CrocApp has one maintainer, Bakir Gracić ([@bakirgdev](https://github.com/bakirgdev)), who makes the final call on what is merged, what ships and what the project will not do. A bug fix, docs change or small change is decided in pull request review. A feature or larger change starts as an issue or discussion; ideas deferred for later carry the `future` label. A release is the maintainer's call ([`docs/RELEASING.md`](docs/RELEASING.md)).

To disagree, argue the case in the issue or pull request in terms of the code and the recorded decisions. If it does not settle, the maintainer decides and writes the reasoning in the thread. Conduct problems go through the [Code of Conduct](CODE_OF_CONDUCT.md), not this process.

`main` requires a pull request and a passing `ci pass` check on a branch that is up to date, and merging is squash-only. The rules apply to admins too, so the maintainer has no bypass.

Becoming a maintainer takes sustained, good contributions and an invitation. Continuity is an accepted gap: no second person has release or repository admin access, so if the maintainer becomes unavailable, releases, security responses and merges stop. The code is MIT-licensed, so anyone can fork it.

## Unlikely to be merged

Not a hard no, but open an issue first and expect a long conversation. These run against decisions that are already recorded:

| Change | Why |
|---|---|
| Support for iOS or macOS below 26 | The floor is 26.0 |
| Telemetry, analytics, crash reporting, ads | No data leaves the device. This is a product promise, not a technical gap |
| A paid tier, license keys, or in-app purchases | MIT and free, permanently. Funding is optional sponsorship only |
| A UIKit or AppKit rewrite of a SwiftUI surface | Native SwiftUI is the deliberate choice |
| Bundled fonts or icon sets | Apple's fonts are not redistributable, and SF Symbols and the system font make the rest unnecessary |
| A new UI language | The app ships in English only. Every new string still goes through a String Catalog (`docs/knowledge/tooling.md`, "Localization"), so a language needs no code change. Each language needs a maintainer who keeps it current |
| Rewriting croc's protocol or crypto | Belongs [upstream](https://github.com/schollz/croc), where the whole ecosystem gets it |

## Licensing

CrocApp is [MIT](LICENSE). By opening a pull request you agree that your contribution is licensed under the same terms. There is no CLA and no sign-off requirement.

Do not paste code you did not write and cannot license this way, including code from projects under a copyleft or proprietary license.
