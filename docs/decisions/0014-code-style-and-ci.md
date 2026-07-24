# 0014. Code style and CI

Status: accepted
Date: 2026-07-24

## Context

Repo had no formatter, no linter, no pinned toolchain and no CI. Style drifted per file, `crocmobile` shipped vendored croc + transitive deps with nothing watching for CVEs, and "does it still build" was a manual local step.

Survey of current Apple/Go tooling (2026) ruled out the heavier options: Tuist/XcodeGen solve pbxproj merge conflicts a solo repo does not have, SwiftLint's rule enforcement pays off across contributors rather than 36 files, Danger needs a PR flow that does not exist yet.

## Decision

- **swift-format** (toolchain-bundled, no install) as the only Swift formatter. Config in `.swift-format`.
- **golangci-lint** + **govulncheck** for `crocmobile/`. Config in `crocmobile/.golangci.yml`.
- **`.xcode-version`** pins the Xcode baseline; CI reads it rather than hardcoding a version.
- **GitHub Actions** `.github/workflows/ci.yml`: format check, Go lint/vuln, and macOS + iOS-simulator builds.
- **xcbeautify** formats xcodebuild output in CI only. Local builds keep `rtk proxy xcodebuild` + redirect to file.

Deferred, not rejected: SwiftLint, Periphery, Danger, real notarization (see `docs/knowledge/tooling.md`).

## Consequences

- `.swift-format` sets 4-space indent and `indentConditionalCompilationBlocks: false` to match existing code and Xcode's editor. The swift-format defaults (2 spaces, indented `#if` bodies) would have rewritten every file and fought Xcode on every Return keypress.
- CI cannot skip `scripts/build-xcframework.sh`; the binaryTarget is gitignored (ADR 0006), so every build job pays the gomobile bind cost.
- The Go job runs on `ubuntu-latest` with `GOOS=darwin GOARCH=arm64`. Cheap runner, but it analyses the platform the code actually ships on.
- CI does **not** run `scripts/verify-*.sh`. Those need a public relay and are flaky on shared runners. Green CI still is not evidence a transfer works (see CLAUDE.md).
