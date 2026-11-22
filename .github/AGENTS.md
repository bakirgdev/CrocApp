# .github/

GitHub's config for this repo: CI, releases, Pages, dependabot, issue forms, PR template.

## Layout

| Path | Purpose |
| --- | --- |
| `workflows/ci.yml` | push-main + PR gate. A `changes` job diffs the base against the head and gates only `build`, `interop` and `go`; `docs checks`, `design checks`, `shellcheck` and `site build` (pull requests only; on push, `github-pages.yml` builds the site) always run. `shellcheck` also runs shfmt and actionlint, `site build` runs `scripts/assemble-site.sh`, `tsc` and Biome on the docs site, and the macOS leg of `build` runs `scripts/format-swift.sh --lint`. There is no DerivedData cache. `ci pass` aggregates them |
| `workflows/release.yml` | on `v*` tag: `gate` requires the tagged commit on `main` with a green `ci pass` (`checks: read`); check the tag against `MARKETING_VERSION` and `CHANGELOG.md`, then (environment `release`) sign, notarize, write the Sparkle appcast, attest, publish. `workflow_dispatch` is a rehearsal that publishes nothing and takes its notes from `## [Unreleased]`; `scripts/release-check.sh` covers the tag checks it skips. The build job also lints Swift formatting |
| `workflows/go-weekly.yml` | Monday run of the Go checks, so new govulncheck findings surface without a code change, plus `go test -fuzz` for 30 s per `Fuzz*` target (a failing input is uploaded as the `fuzz-failures` artifact); files or updates one `security` issue on failure through a `gh` step |
| `workflows/github-pages.yml` | on push to main (site paths only): builds `_site` and deploys it. The pre-merge check of the same build is the `site build` job in `ci.yml` |
| `workflows/reusable-*.yml` | `workflow_call` only. Edit the check here, never in a caller |
| `workflows/codeql.yml` | CodeQL advanced setup (Actions and Go with `croc_no_tailcat`; no JavaScript or TypeScript) on PRs and pushes touching `crocmobile/` or the workflows, plus a Tuesday cron. Swift is not analyzed (a known limit, tracked as a GitHub issue labelled `known`). The repo's default setup stays off, or SARIF uploads fail |
| `workflows/pin-watch.yml` | Monday run of `scripts/pin-watch.sh`; keeps one "Pinned versions to update" issue in step with the report. It also reads the Sparkle and docs-site npm pins Dependabot does not watch. A failed run files no issue |
| `workflows/relay-automerge.yml` | on Dependabot PRs: turns on squash auto-merge only for the croc image bump in `relay/compose.yml` (non-major), so it lands once `ci pass` is green. Dokploy deploys `relay/` on push to `main` (watch path `relay/**`), so the merge redeploys the relay at relay.crocapp.dev |
| `workflows/scorecard.yml` | OpenSSF Scorecard: Wednesday cron, `branch_protection_rule`, dispatch |
| `dependabot.yml` | github-actions, gomod `/crocmobile` and docker-compose `/relay` only (Sparkle and the docs-site npm pins are in `pin-watch`), weekly except gomod and docker-compose. github-actions and gomod group minor and patch, majors one PR each. `github-actions` carries a 7-day `cooldown` (`default-days`), so a release is not adopted the day it ships; security updates ignore it. gomod runs daily for croc, its only direct requirement: a minor's PR opens after 3 days (`semver-minor-days`), a patch's after 1 for review, and croc stays out of the `go-deps` group; a croc bump follows `docs/knowledge/croc-upgrade-playbook.md`. docker-compose bumps the relay's croc image daily after a 3-day cooldown, ungrouped, majors ignored |

## Rules

**Pin every action to a full commit SHA with a `# vX.Y.Z` comment.** Dependabot rewrites both together. Resolve the SHA, never recall it:

```bash
gh api repos/OWNER/REPO/releases/latest --jq .tag_name
gh api repos/OWNER/REPO/git/ref/tags/TAG --jq '.object.type + " " + .object.sha'
# type "tag" is annotated: deref with git/tags/SHA --jq .object.sha
```

**Versions live in files, not in workflow text.** Xcode in `.xcode-version`, Node in `web/docs/.nvmrc` (and `engines` in `web/docs/package.json`), pnpm in `packageManager` in `web/docs/package.json`, Go in `crocmobile/go.mod`, govulncheck and gomobile in its `tool` block, the croc v10 test peer in `scripts/croc-v10.version`. A tool downloaded in a workflow (shfmt, create-dmg) is pinned by `*_VERSION` and `*_SHA256` env next to the download. `.github/workflows/pin-watch.yml` reports what Dependabot cannot update, runner labels included (`docs/knowledge/tooling.md`, "Keeping versions current", which also records why TypeScript is held to patch updates). Xcode is selected with `xcode-select -s` on its path, not an action.

**`ci pass` is an interface.** `main` requires a pull request (0 approvals), the `ci pass` check on a branch that is up to date with `main`, resolved conversations and linear history, with no admin bypass, so renaming that job blocks every merge. Merging is squash-only (title = PR title, body = PR body). Actions settings also require full-SHA pins.

**A new file the `build`, `go` or `interop` job reads goes into the `changes` regex**, or edits to that file skip the job. The other jobs always run.

**Minutes are free here** (public repo, standard GitHub-hosted runners, `xcode-27` included). The limit that bites is 5 concurrent macOS jobs on the Free plan, so optimize macOS jobs for wall clock, and never move a job to a larger runner, which is billed.

## Gotchas

- **Fork pull requests get a read-only `GITHUB_TOKEN`.** Any step that writes a comment, label, or issue needs `github.event.pull_request.head.repo.full_name == github.repository`, or a green run goes red.
- **A label named in config must already exist** in the repo. Dependabot silently drops missing ones, and a `labels:` filter on `listForRepo` silently matches nothing, which breaks issue dedup.
- **Dependabot bumps only direct Go requirements.** The `tool` block's modules (`x/mobile`, `x/vuln`) are `// indirect`, so `pin-watch` reports them and you bump them by hand: `go get tool` in `crocmobile/`.
- **Go jobs cross-target `darwin/arm64`** because the module only ships through gomobile. Tools have to be built for the runner (`env -u GOOS -u GOARCH go build -o ...`) and then run under the job's env.
- **`release.yml` parses `CHANGELOG.md`.** It requires a [Keep a Changelog](https://keepachangelog.com/) heading, dated: `## [1.2.3] - YYYY-MM-DD`. Change the heading style and the tag stops releasing. The notes end at the next `## [` heading or at the first line starting `[label]: `, so a reference-style link definition inside a version section cuts its release notes short; use inline links there.
