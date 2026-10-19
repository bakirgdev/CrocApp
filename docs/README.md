# CrocApp docs

How CrocApp is built, how it works inside, and how it ships. For using the app, see the docs site at [crocapp.dev/docs](https://crocapp.dev/docs/) (source in `web/docs/content/`). For anything visual or any UI copy, start at [`design/AGENTS.md`](../design/AGENTS.md). Writing or editing a doc here follows [`AGENTS.md`](AGENTS.md).

## Start here

| Read | When |
| --- | --- |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | First. The layers from croc to the SwiftUI views, who owns which state, how a transfer flows |
| [`BUILDING.md`](BUILDING.md) | Before your first build, and before running any check or harness |
| [`GLOSSARY.md`](GLOSSARY.md) | A term you cannot infer: PAKE, relay, gobind, prompt pipe, stored transfer |
| [`known-issues.md`](known-issues.md) | Before reporting or fixing a bug: it may be known, or accepted on purpose |

## Project

| Read | When |
| --- | --- |
| [`knowledge/project-overview.md`](knowledge/project-overview.md) | You need the goals, constraints and non-goals on one screen |
| [`ROADMAP.md`](ROADMAP.md) | You want to know what is planned and what will not be |
| [`knowledge/features.md`](knowledge/features.md) | You need to know whether a feature exists, on which platform, and which croc option it maps to |
| [`knowledge/prior-art.md`](knowledge/prior-art.md) | You are making a UX, positioning or distribution call |
| [`THREAT-MODEL.md`](THREAT-MODEL.md) | You change anything that touches files, secrets, the network or the release pipeline |

## Subsystems

| Read | Before you touch |
| --- | --- |
| [`knowledge/what-is-croc.md`](knowledge/what-is-croc.md) | Anything that depends on croc's protocol, crypto, relays or CLI |
| [`knowledge/crocmobile-bridge.md`](knowledge/crocmobile-bridge.md) | `crocmobile/`, `CrocKit/Sources/`, or the event and error contract between them |
| [`knowledge/app-ui-architecture.md`](knowledge/app-ui-architecture.md) | `TransferController` or any view that observes it |
| [`knowledge/apple-platform-constraints.md`](knowledge/apple-platform-constraints.md) | iOS backgrounding, sandboxing, entitlements, local network access |
| [`knowledge/tooling.md`](knowledge/tooling.md) | CI, a linter, a formatter, or a tool that was deliberately skipped |
| [`knowledge/docs-site.md`](knowledge/docs-site.md) | `web/docs/` |
| [`knowledge/landing-page.md`](knowledge/landing-page.md) | `web/landing/`: the home page, the `/r/` link page, `.well-known/`, `llms.txt` |
| [`knowledge/screenshots.md`](knowledge/screenshots.md) | Any app screenshot: capturing, adding or moving one |

## Processes

| Read | When |
| --- | --- |
| [`RELEASING.md`](RELEASING.md) | Signing, notarization, Sparkle, App Store uploads, cutting a release |
| [`knowledge/app-store-listing.md`](knowledge/app-store-listing.md) | Filling in App Store Connect: listing copy, review notes, privacy, export compliance |
| [`knowledge/device-test-checklist.md`](knowledge/device-test-checklist.md) | Testing on a real iPhone, iPad or Mac, before every App Store submission |
| [`knowledge/croc-upgrade-playbook.md`](knowledge/croc-upgrade-playbook.md) | Upstream croc released a new version |
