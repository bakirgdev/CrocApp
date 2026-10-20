# .github/

GitHub's config for this repo: CI, releases, Pages, dependabot, issue forms, PR template.

## Layout

| Path | Purpose |
| --- | --- |
| `workflows/ci.yml` | push-main + PR gate. A `changes` job diffs the base against the head and gates the other jobs by area (`docs checks` always runs; `site build` runs `scripts/assemble-site.sh` and `tsc` on the docs when the site files change); `ci pass` aggregates them |
| `workflows/release.yml` | on `v*` tag: check the tag against `MARKETING_VERSION` and `CHANGELOG.md`, then (environment `release`) sign, notarize, write the Sparkle appcast, attest, publish. `workflow_dispatch` is a rehearsal that publishes nothing |
| `workflows/go-weekly.yml` | Monday run of the Go checks, so new govulncheck findings surface without a code change, plus `go test -fuzz` for 30 s per `Fuzz*` target (a failing input is uploaded as the `fuzz-failures` artifact); files or updates one `security` issue on failure |
| `workflows/github-pages.yml` | on push to main (site paths only): builds `_site` and deploys it. The pre-merge check of the same build is the `site build` job in `ci.yml`; keep its `site` regex and this `paths:` list in step |
| `workflows/reusable-*.yml` | `workflow_call` only. Edit the check here, never in a caller |
| `workflows/scorecard.yml` | OpenSSF Scorecard: Wednesday cron, `branch_protection_rule`, dispatch |
| `dependabot.yml` | github-actions, gomod `/crocmobile`, swift `/app` (reads the Xcode project's `Package.resolved`) weekly; npm `/web/docs` monthly. Minor and patch grouped, majors one PR each |

## Rules

**Pin every action to a full commit SHA with a `# vX.Y.Z` comment.** Dependabot rewrites both together. Resolve the SHA, never recall it:

```bash
gh api repos/OWNER/REPO/releases/latest --jq .tag_name
gh api repos/OWNER/REPO/git/ref/tags/TAG --jq '.object.type + " " + .object.sha'
# type "tag" is annotated: deref with git/tags/SHA --jq .object.sha
```

**Versions live in files, not in workflow text.** Xcode in `.xcode-version`, Node in `web/docs/.nvmrc`, pnpm in `packageManager` in `web/docs/package.json`, Go in `crocmobile/go.mod`, govulncheck and gomobile in its `tool` block, the croc v10 test peer in `scripts/croc-v10.version`. Runners are pinned (`ubuntu-26.04`, `macos-26`, `xcode-27`) and are the one thing dependabot cannot see.

**`ci pass` is an interface.** `main` requires a pull request (0 approvals) and the `ci pass` check (admins can bypass both), so renaming that job breaks merging. Merging is squash-only (title = PR title, body = PR body) and `main` requires linear history.

**A new file CI reads goes into the `changes` regex** of the job that reads it, or edits to that file skip the job.

**Minutes are free here** (public repo, standard GitHub-hosted runners, `xcode-27` included). The limit that bites is 5 concurrent macOS jobs on the Free plan, so optimize macOS jobs for wall clock, and never move a job to a larger runner, which is billed.

## Gotchas

- **Fork pull requests get a read-only `GITHUB_TOKEN`.** Any step that writes a comment, label, or issue needs `github.event.pull_request.head.repo.full_name == github.repository`, or a green run goes red.
- **A label named in config must already exist** in the repo. Dependabot silently drops missing ones, and a `labels:` filter on `listForRepo` silently matches nothing, which breaks issue dedup.
- **Dependabot bumps only direct Go requirements.** The `tool` block's modules (`x/mobile`, `x/vuln`) are `// indirect`, so bump them by hand: `go get tool` in `crocmobile/`.
- **Go jobs cross-target `darwin/arm64`** because the module only ships through gomobile. Tools have to be built for the runner (`env -u GOOS -u GOARCH go build -o ...`) and then run under the job's env.
- **`release.yml` parses `CHANGELOG.md`.** It requires a [Keep a Changelog](https://keepachangelog.com/) heading, dated: `## [1.2.3] - YYYY-MM-DD`. Change the heading style and the tag stops releasing. The notes end at the next `## [` heading or at the first line starting `[label]: `, so a reference-style link definition inside a version section cuts its release notes short; use inline links there.
