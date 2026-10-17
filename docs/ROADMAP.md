# Roadmap

What CrocApp intends to do and not do, through 2027. This is intent, not a promise: priorities change, and one maintainer sets the pace (see [`GOVERNANCE.md`](../GOVERNANCE.md)). The plan changes by pull request to this file. To propose something, open a [discussion](https://github.com/bakirgdev/CrocApp/discussions) or a [feature request](https://github.com/bakirgdev/CrocApp/issues/new?template=feature_request.yml).

Last reviewed: 2026-10-18. Shipped work is in [`CHANGELOG.md`](../CHANGELOG.md); CrocApp 1.0.0 shipped 2026-10-15.

## Ongoing

| Commitment | How |
|---|---|
| Track croc releases | Bump the pinned croc version following the [upgrade playbook](knowledge/croc-upgrade-playbook.md), so code phrases keep working between CrocApp and the croc CLI |
| Security fixes | Handled as described in [`SECURITY.md`](../SECURITY.md) |
| Dependency updates | Dependabot PRs (weekly; monthly for the docs site), plus a weekly Go vulnerability check and fuzz run in CI |
| Newer Apple OS releases | Keep CrocApp working on them. The minimum stays iOS, iPadOS and macOS 26.0 |
| Known issues | Tracked in [`known-issues.md`](known-issues.md) |

## Planned

All of these are deferred until after 1.0 and carry the [`future` label](https://github.com/bakirgdev/CrocApp/issues?q=is%3Aissue+is%3Aopen+label%3Afuture).

| Area | Item |
|---|---|
| Distribution | [#10](https://github.com/bakirgdev/CrocApp/issues/10) Homebrew cask, once the repo meets homebrew/cask's acceptance policy (see the README Download table) |
| Languages | [#11](https://github.com/bakirgdev/CrocApp/issues/11) Localize the app and docs, starting with Bosnian, with Crowdin for community translations |
| System integration | [#22](https://github.com/bakirgdev/CrocApp/issues/22) macOS Finder Share extension |
| | [#23](https://github.com/bakirgdev/CrocApp/issues/23) Control Center control for sending and receiving |
| | [#24](https://github.com/bakirgdev/CrocApp/issues/24) Spotlight indexing of transfer history (never code phrases or link keys) |
| | [#25](https://github.com/bakirgdev/CrocApp/issues/25) Widgets for recent transfers and quick actions |
| Web and upstream | [#9](https://github.com/bakirgdev/CrocApp/issues/9) Talk to the croc maintainer about infrastructure and a web version |
| | [#8](https://github.com/bakirgdev/CrocApp/issues/8) Web app for sending and receiving from a browser (to be reviewed; may be closed) |

Also approved in [`knowledge/features.md`](knowledge/features.md) but not yet started: running your own relay from the Mac app (F29), saved codes and favorite peers (F33), a relay health check and diagnostics screen (F35). A Wi-Fi Aware direct path (F37) is listed as "Later".

## Not planned

| Not planned | Why |
|---|---|
| Anything in the [Unlikely to be merged](../CONTRIBUTING.md#unlikely-to-be-merged) table: iOS or macOS below 26, telemetry, a paid tier, a UIKit or AppKit rewrite, bundled fonts or icon sets, changes to croc's protocol or crypto | Recorded decisions, with the reason for each in that table |
| Windows, Linux or Android clients | Non-goal for now ([project overview](knowledge/project-overview.md)). Interest can be shown in an [issue](https://github.com/bakirgdev/CrocApp/issues) |
| Forking or reimplementing croc | CrocApp wraps croc |
| `--stdout` piping, `--classic` mode, `--remember` | Skipped in [`knowledge/features.md`](knowledge/features.md): CLI-only, insecure by design, and redundant with persistent settings |
