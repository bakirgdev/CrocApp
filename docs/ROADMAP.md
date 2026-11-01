# Roadmap

What CrocApp intends to do and not do. This is intent, not a promise: priorities change, and one maintainer sets the pace (see [`GOVERNANCE.md`](../GOVERNANCE.md)). The plan changes by pull request to this file. To propose something, open a [discussion](https://github.com/bakirgdev/CrocApp/discussions) or a [feature request](https://github.com/bakirgdev/CrocApp/issues/new?template=feature_request.yml).

Shipped work is in [`CHANGELOG.md`](../CHANGELOG.md). Release status is in [`docs/README.md`](README.md), "Status".

## Next milestone

**v1.1.0 is the first public release**: the notarized direct download for the Mac, then the App Store for iPhone, iPad and Mac. Its scope is the [v1.1.0 milestone](https://github.com/bakirgdev/CrocApp/milestone/1). Its open items are listed in [`known-issues.md`](known-issues.md), "Release", and the steps are in [`RELEASING.md`](RELEASING.md), "App Store builds".

## Ongoing

| Commitment | How |
|---|---|
| Track croc releases | Bump the pinned croc version following the [upgrade playbook](knowledge/croc-upgrade-playbook.md), so code phrases keep working between CrocApp and the croc CLI |
| Security fixes | Handled as described in [`SECURITY.md`](../SECURITY.md) |
| Dependency updates | Dependabot PRs (weekly), plus a weekly Go vulnerability check and fuzz run in CI |
| Newer Apple OS releases | Keep CrocApp working on them. The minimum stays iOS, iPadOS and macOS 26.0 |
| Known issues | Tracked in [`known-issues.md`](known-issues.md) |

## Planned

Each planned item is a GitHub issue, so it can be discussed, linked and closed by the pull request that ships it. This file does not repeat them:

| Where | What |
|---|---|
| [v1.1.0 milestone](https://github.com/bakirgdev/CrocApp/milestone/1) | Everything in the next release |
| [`future` label](https://github.com/bakirgdev/CrocApp/issues?q=is%3Aissue+is%3Aopen+label%3Afuture) | Approved for a release after v1.1.0, such as localization and the Homebrew cask |

## Not planned

| Not planned | Why |
|---|---|
| Anything in the [Unlikely to be merged](../CONTRIBUTING.md#unlikely-to-be-merged) table: iOS or macOS below 26, telemetry, a paid tier, a UIKit or AppKit rewrite, bundled fonts or icon sets, changes to croc's protocol or crypto | Recorded decisions, with the reason for each in that table |
| Windows, Linux or Android clients | Non-goal ([project non-goals](README.md#non-goals)). Interest can be shown in an [issue](https://github.com/bakirgdev/CrocApp/issues) |
| Forking or reimplementing croc | CrocApp wraps croc |
| A CrocApp web version | croc's own browser client at [getcroc.com](https://getcroc.com) already covers it |
| `--stdout` piping, `--classic` mode, `--remember` | Skipped in [`knowledge/features.md`](knowledge/features.md), "Skipped": CLI-only, insecure by design, and redundant with persistent settings |
