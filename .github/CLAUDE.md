# .github/

GitHub's config for this repo: CI, releases, Pages, dependabot, issue forms, PR template.

## Layout

| Path | Purpose |
| --- | --- |
| `workflows/ci.yml` | push-main + PR gate: a `changes` job gates lint, Go checks and `go test -race`, the contrast check, and the macOS and iOS Simulator builds (the macOS leg also runs `swift test` for CrocKit and `xcodebuild test` for `CrocAppTests`), and `interop (local relay)` (`scripts/verify-interop.sh` against a `croc relay` on 127.0.0.1, on `macos-26`); `ci pass` aggregates them |
| `workflows/release.yml` | on `v*` tag: verify tag against `MARKETING_VERSION` in `app/Config/Version.xcconfig`, then (in environment `release`) run `scripts/build-devid.sh` for the signed, notarized, stapled DMG, write the Sparkle `appcast.xml`, build the xcframework zip and `SHA256SUMS.txt`, attest, publish. `workflow_dispatch` is a rehearsal: no tag or CHANGELOG check, no publish |
| `workflows/go-weekly.yml` | Monday scan on a clock, files or updates one `security` issue on failure |
| `workflows/github-pages.yml` | builds `_site` on PR, also deploys on push to main |
| `workflows/reusable-*.yml` | `workflow_call` only. Edit the check here, never in a caller |
| `workflows/scorecard.yml` | OpenSSF Scorecard on push to main, Wednesday cron, `branch_protection_rule`, and dispatch; publishes results and uploads SARIF to code scanning |
| `dependabot.yml` | github-actions `/`, gomod `/crocmobile`, swift `/app` (Xcode project, SwiftPM), npm `/web/docs`, weekly |

## Rules

**Pin every action to a full commit SHA with a `# vX.Y.Z` comment.** Dependabot rewrites both together. Resolve the SHA, never recall it:

```bash
gh api repos/OWNER/REPO/releases/latest --jq .tag_name
gh api repos/OWNER/REPO/git/ref/tags/TAG --jq '.object.type + " " + .object.sha'
# type "tag" is annotated: deref with git/tags/SHA --jq .object.sha
```

**Versions live in files, not in workflow text.** Xcode in `.xcode-version`, Node in `web/docs/.nvmrc`, Go in `crocmobile/go.mod`, govulncheck and gomobile in its `tool` block, the croc v10 test peer in `scripts/croc-v10.version`. Runners are pinned (`ubuntu-24.04`, `macos-26`, `xcode-27`) and are the one thing dependabot cannot see.

**`ci pass` is an interface.** `main` requires a pull request (0 approvals) and the `ci pass` check, admins included, so renaming that job breaks merging.

## Gotchas

- **Fork pull requests get a read-only `GITHUB_TOKEN`.** Any step that writes a comment, label, or issue needs `github.event.pull_request.head.repo.full_name == github.repository`, or a green run goes red.
- **A label named in config must already exist** in the repo. Dependabot silently drops missing ones, and a `labels:` filter on `listForRepo` silently matches nothing, which breaks issue dedup.
- **Go jobs cross-target `darwin/arm64`** because the module only ships through gomobile. Tools have to be built for the runner (`env -u GOOS -u GOARCH go build -o ...`) and then run under the job's env.
- **YAML anchors work** in workflows here (`paths: &site-paths` / `*site-paths` in `github-pages.yml`), despite the common claim that Actions rejects them.
- **`release.yml` parses `CHANGELOG.md`.** It requires a Keep a Changelog heading, dated: `## [1.2.3] - YYYY-MM-DD`. Change the changelog's heading style and the tag stops releasing. Following practices from [Keep a Changelog](https://keepachangelog.com/).

## Expiring notes

Each subsection describes a trap that will stop existing. **Delete a subsection the moment its fix lands**, independently of the others. A stale warning costs more than no warning.

### corepack

`github-pages.yml` gets pnpm with `corepack enable pnpm`, reading the version from `packageManager` in `web/docs/package.json`. Node still bundles corepack at the pinned `.nvmrc` version, but Node is removing it. When a `.nvmrc` bump makes that step fail, replace it with a direct pnpm install at the `packageManager` version, or `pnpm/action-setup`. Delete this once swapped.
