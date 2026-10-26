# Roadmap

What CrocApp intends to do and not do. This is intent, not a promise: priorities change, and one maintainer sets the pace (see [`GOVERNANCE.md`](../GOVERNANCE.md)). The plan changes by pull request to this file. To propose something, open a [discussion](https://github.com/bakirgdev/CrocApp/discussions) or a [feature request](https://github.com/bakirgdev/CrocApp/issues/new?template=feature_request.yml).

Shipped work is in [`CHANGELOG.md`](../CHANGELOG.md). Release status is in [`knowledge/project-overview.md`](knowledge/project-overview.md), "Status".

## Next milestone

**1.1.0 is the first App Store release**, for iPhone, iPad and Mac. What gates Submit for Review is listed in [`known-issues.md`](known-issues.md), "Release", and the steps are in [`RELEASING.md`](RELEASING.md), "App Store builds".

## Ongoing

| Commitment | How |
|---|---|
| Track croc releases | Bump the pinned croc version following the [upgrade playbook](knowledge/croc-upgrade-playbook.md), so code phrases keep working between CrocApp and the croc CLI |
| Security fixes | Handled as described in [`SECURITY.md`](../SECURITY.md) |
| Dependency updates | Dependabot PRs (weekly; monthly for the docs site), plus a weekly Go vulnerability check and fuzz run in CI |
| Newer Apple OS releases | Keep CrocApp working on them. The minimum stays iOS, iPadOS and macOS 26.0 |
| Known issues | Tracked in [`known-issues.md`](known-issues.md) |

## Planned

Everything here is deferred until after the App Store release and carries the [`future` label](https://github.com/bakirgdev/CrocApp/issues?q=is%3Aissue+is%3Aopen+label%3Afuture).

| Area | Item |
|---|---|
| Distribution | [Publish a Homebrew cask once the repo meets homebrew/cask requirements](https://github.com/bakirgdev/CrocApp/issues/10) (see the README Download table) |
| Languages | [Localize the app and docs, with Crowdin for community translations](https://github.com/bakirgdev/CrocApp/issues/11), starting with Bosnian. The app's strings already reach String Catalogs, with English only (`knowledge/app-ui-architecture.md`, "Localization") |
| System integration | [macOS Finder Share extension](https://github.com/bakirgdev/CrocApp/issues/22) |
| | [Control Center control for sending and receiving](https://github.com/bakirgdev/CrocApp/issues/23) |
| | [Spotlight indexing of transfer history](https://github.com/bakirgdev/CrocApp/issues/24) (never code phrases or link keys) |
| | [Widgets for recent transfers and quick actions](https://github.com/bakirgdev/CrocApp/issues/25) |
| Web and upstream | [Talk to the croc maintainer about infrastructure and a web version](https://github.com/bakirgdev/CrocApp/issues/9) |
| | [Web app: send and receive files with croc from a browser](https://github.com/bakirgdev/CrocApp/issues/8) (to be reviewed; may be closed) |

## Approved, not started

No issue tracks these yet.

| Item | Note |
|---|---|
| Run your own relay from the Mac app | A menu bar relay server (`croc relay`) |
| Saved codes and favorite peers | App-native |
| Relay health check and diagnostics screen | App-native |
| Wi-Fi Aware direct path | Waits on Apple: available on iOS and iPadOS 26, absent on macOS 26. A fast path between two CrocApp devices |

## Not planned

| Not planned | Why |
|---|---|
| Anything in the [Unlikely to be merged](../CONTRIBUTING.md#unlikely-to-be-merged) table: iOS or macOS below 26, telemetry, a paid tier, a UIKit or AppKit rewrite, bundled fonts or icon sets, changes to croc's protocol or crypto | Recorded decisions, with the reason for each in that table |
| Windows, Linux or Android clients | Non-goal ([project overview](knowledge/project-overview.md)). Interest can be shown in an [issue](https://github.com/bakirgdev/CrocApp/issues) |
| Forking or reimplementing croc | CrocApp wraps croc |
| `--stdout` piping, `--classic` mode, `--remember` | Skipped in [`knowledge/features.md`](knowledge/features.md), "Skipped": CLI-only, insecure by design, and redundant with persistent settings |
