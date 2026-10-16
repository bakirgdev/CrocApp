# Contributing to CrocApp

Thanks for taking the time. CrocApp is free, MIT-licensed, and open to any pull request: bug fixes, features, docs, design, landing page. You do not need permission or an assigned issue to start.

Two things make this repo different from a typical SwiftUI app, and most review friction comes from missing them:

1. **A green build is not evidence a transfer works.** Real behavior is proven by live-transfer harnesses in `scripts/`, not by the compiler.
2. **Anything visual is bound to `design/`.** Tokens only, SF Symbols only, system font only.

| | |
|---|---|
| [Code of Conduct](#code-of-conduct) | How we behave here |
| [Where to start](#where-to-start) | Issues, discussions, upstream |
| [Setup](#setup) | First build, repo layout |
| [Commits](#commits) | Message conventions |
| [Code style](#code-style) | Formatters, linters, scope |
| [Design rules](#design-rules) | Tokens, symbols, screenshots |
| [Verification](#verification) | What to run, and how to report it |
| [Docs](#docs) | Changelog, knowledge, known issues |
| [AI-assisted contributions](#ai-assisted-contributions) | Allowed, with disclosure |
| [Opening a pull request](#opening-a-pull-request) | Flow and expectations |
| [Unlikely to be merged](#unlikely-to-be-merged) | Save yourself the work |
| [Licensing](#licensing) | Inbound equals outbound |

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

Issues labeled `help wanted` are open for anyone to pick up.

> [!TIP]
> For a large feature or a refactor that touches the transfer engine, open an issue or a discussion first. Not for approval, just so you do not spend a weekend on something that collides with work already in flight.

## Setup

Requires **macOS 26**, **Xcode 27**, and **Go 1.27.2** (or newer).

```bash
git clone https://github.com/bakirgdev/CrocApp.git
cd CrocApp
```

Also needed: `croc` CLI (`brew install croc`) and outbound network access to the public relay.

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

# Go
golangci-lint run ./...
govulncheck ./...
```

- **Comments explain why, never what.** Do not delete existing comments unless the code they describe is going away.
- **Stay in scope.** No drive-by refactors, no renaming unrelated symbols, no reformatting files your change does not touch.
- **No new third-party dependencies** without agreeing on them in an issue first. New dependency may end up shipped somewhere that moves people's files!

## Design rules

Anything visual, in the app, the web or elsewhere, follows [`design/CLAUDE.md`](design/CLAUDE.md). In short, fixed design principles (brandbook), like: design tokens instead of raw hex, px, pt, or durations; SF Symbols only; system font only; a light and a dark value for every surface.

UI pull requests need **before and after screenshots in both light and dark**, and on both platforms if both are affected.

## AI-assisted contributions

Allowed, and used heavily here. Two conditions:

- **Disclose it.** Own the responsibility to report even if we live in the day and age where it may be considered as norm. Fill in the AI assistance line in the PR template. It tells the reviewer where to look harder, and nobody is judged for it.
- **You own the code.** You understand every line, you can explain why each one is there, and you ran all verifications and checks yourself. "The model said it works" is not verification.

Bulk-generated pull requests that the author has not read, does not understand, or cannot verify get closed without review.

## Opening a pull request

1. Fork the repo and branch off `main`.
2. Rebase on the current `main` before opening, so the diff is clean.
3. Open the PR against `main` with a Conventional Commits title, and fill in [the template](.github/pull_request_template.md).
4. Link the issue with `Fixes #123` when one exists.
5. Keep it focused. Two unrelated changes are two pull requests.

Draft PRs are welcome for early feedback.

CrocApp has one maintainer, so review time varies and there is no response-time promise. Review comments are direct and about the code, never about you.

## Unlikely to be merged

Not a hard no, but open an issue first and expect a long conversation. These run against decisions that are already recorded:

| Change | Why |
|---|---|
| Support for iOS or macOS below 26 | The floor is 26.0 |
| Telemetry, analytics, crash reporting, ads | No data leaves the device. This is a product promise, not a technical gap |
| A paid tier, license keys, or in-app purchases | MIT and free, permanently. Funding is optional sponsorship only |
| A UIKit or AppKit rewrite of a SwiftUI surface | Native SwiftUI is the deliberate choice |
| Bundled fonts or icon sets | Apple's fonts are not redistributable, and SF Symbols and the system font make the rest unnecessary |
| Rewriting croc's protocol or crypto | Belongs [upstream](https://github.com/schollz/croc), where the whole ecosystem gets it |

## Licensing

CrocApp is [MIT](LICENSE). By opening a pull request you agree that your contribution is licensed under the same terms. There is no CLA and no sign-off requirement.

Do not paste code you did not write and cannot license this way, including code from projects under a copyleft or proprietary license.
