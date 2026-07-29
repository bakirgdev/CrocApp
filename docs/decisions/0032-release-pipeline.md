# 0032. Releases are cut by a workflow, from a tag

Status: accepted
Date: 2026-07-29

## Context

The macOS direct download (ADR 0031) needs an artifact somebody can fetch. Building it by hand on the maintainer's Mac makes the artifact unverifiable — nobody can tell what went into it — and there is no Developer ID certificate yet, so the first release cannot be signed properly regardless of where it is built.

`main` is moving to contribution-by-PR with no force pushes, which rules out any workflow that writes to the repository: a `GITHUB_TOKEN` push would simply be rejected.

## Decision

`.github/workflows/release.yml`, with two deliberately asymmetric entry points:

- **`workflow_dispatch`** takes a version string, builds everything, uploads it as a workflow artifact. No tag, no release. This is the rehearsal path.
- **`push` on `v*`** runs the same build and then publishes the release.

Around that:

- The workflow runs the full check set itself — `swift-format lint --strict`, `golangci-lint`, `go vet`, `govulncheck` — rather than trusting that branch protection ran `ci.yml` on the tagged commit. `ci.yml`'s `paths` filter means a filtered-out commit runs zero jobs.
- The version comes from the tag and is checked against every `MARKETING_VERSION` in `project.pbxproj`. Disagreement fails the build. The workflow never edits the project file.
- Assets: the DMG, the zipped `.app`, the zipped `Croc.xcframework`, and `SHA256SUMS.txt`. Every one gets a build provenance attestation (`actions/attest-build-provenance`).
- The release body is the `CHANGELOG.md` section for that version, byte for byte, and nothing else. No generated pull-request list: a version gets one description, not two that drift apart. `CHANGELOG.md` is therefore the thing to edit when the release notes are wrong.
- Third-party actions are pinned to commit SHAs.
- Immutable releases are enabled on the repository, so published assets and tags are frozen and each release carries a signed attestation.

`scripts/build-dmg.sh` wraps a built `.app` with `create-dmg`, to the geometry in `design/components.md` → DiskImage.

## Consequences

- v0.9.9 ships **ad-hoc signed**, because `CODE_SIGN_IDENTITY=-` is the only signature available without a Developer ID certificate. Gatekeeper refuses it on first launch after download; the release notes have to say so and give the Privacy & Security route. Tracked in `../known-issues.md`.
- Publishing is immediate — not a draft, not a prerelease — so `/releases/latest` starts resolving on the first tag, and the landing page's download button with it. Combined with immutable releases this means a bad asset cannot be swapped; it is replaced by a new version. The rehearsal path exists precisely so that does not happen.
- `create-dmg` is a build-time dependency, installed by the workflow with `brew`. It is not needed for a plain `xcodebuild` build.
- A tag can only be cut from a commit whose `MARKETING_VERSION` already matches, so bumping the version is a pull request like any other change.
- Once a Developer ID certificate exists, the signing and notarization steps replace the ad-hoc line inside the existing build job. Nothing else in the workflow changes shape.
