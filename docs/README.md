# CrocApp docs

How CrocApp is built, how it works inside, and how it ships. For using the app, see the docs site at [crocapp.dev/docs](https://crocapp.dev/docs/) (source in `web/docs/content/`). For anything visual or any UI copy, start at [`design/AGENTS.md`](../design/AGENTS.md). Writing or editing a doc here follows [`AGENTS.md`](AGENTS.md).

## About the project

CrocApp is a free, open-source, native SwiftUI app for [croc](https://github.com/schollz/croc), the file-transfer command line tool. It runs on iOS, iPadOS and macOS, and covers most of croc's features behind a simple interface.

### Status

The first public release is 1.1.0: a notarized direct download for the Mac (Sparkle updates), followed by the iOS, iPadOS and Mac App Store builds, which are submitted to App Review and not yet on the App Store. [`ROADMAP.md`](ROADMAP.md) lists what comes next, and [`RELEASING.md`](RELEASING.md) covers the channels.

### Why

- croc has a strong design (PAKE-secured, relay-assisted, end-to-end encrypted transfers), but it is command line only, so most people cannot use it.
- A native app brings that design to a wider audience.
- No official, maintained native Apple app for croc exists. The paid, closed-source iCroc is the only Apple-native croc client known, and it embeds an old croc (10.x). The Android client `croc-app` runs the croc binary as a subprocess, which iOS forbids.

### Goals

1. A real, working, shippable app, not a demo.
2. A healthy open-source project: users, contributors, good repo hygiene.
3. The author learns Apple development (Swift, SwiftUI, Xcode) along the way.

### Constraints and context

- One developer: Bakir Gracic. The repo is public at `github.com/bakirgdev/CrocApp`.
- Built almost entirely with Claude Code, with minimal manual coding. Tooling and docs are written to keep AI sessions cheap and accurate.
- Minimum OS: iOS 26.0, iPadOS 26.0 and macOS 26.0. Toolchain: Xcode 27 ([`knowledge/tooling.md`](knowledge/tooling.md)).
- License: MIT.

### Non-goals

- Windows, Linux or Android clients.
- Reimplementing or forking croc. CrocApp wraps it.
- Paid features. The app stays free; the only money is optional donations.

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
| [`ROADMAP.md`](ROADMAP.md) | You want to know what is planned and what will not be |
| [`knowledge/features.md`](knowledge/features.md) | You need to know whether a feature exists, on which platform, and which croc option it maps to |
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
