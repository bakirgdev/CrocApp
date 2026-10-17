# Governance

CrocApp has one maintainer. The maintainer makes the final call on everything: what gets merged, what ships, and what the project will not do. This file says how that works in practice and what to expect.

## How decisions are made

| Kind of decision | Where it happens | Where it is recorded |
|---|---|---|
| Bug fix, docs, small change | Pull request review | The merged PR, squash-merged to `main` |
| Feature or larger change | An [issue](https://github.com/bakirgdev/CrocApp/issues) or a [discussion](https://github.com/bakirgdev/CrocApp/discussions) first, then a pull request | The issue and the PR. Deferred ideas carry the `future` label (see the [roadmap](docs/ROADMAP.md)) |
| Something the project will not do | Same as above | The ["Unlikely to be merged" table](CONTRIBUTING.md#unlikely-to-be-merged) in `CONTRIBUTING.md` |
| Known defect or papercut the project lives with | Same as above | The "Accepted" section of [`docs/known-issues.md`](docs/known-issues.md) |
| Release | The maintainer | [`CHANGELOG.md`](CHANGELOG.md) (Keep a Changelog, [Semantic Versioning](https://semver.org/spec/v2.0.0.html)) |

`main` requires a pull request and a passing `ci pass` check, and merging is squash-only. Admin bypass of those rules exists for the maintainer.

## Disagreements

Argue the case in the issue or pull request, in terms of the code and the project's recorded decisions. Anyone can raise a decision again with new information. If it does not settle, the maintainer decides, and the reasoning is written in the thread. Conduct problems are handled under the [Code of Conduct](CODE_OF_CONDUCT.md), not by this process.

## Roles

| Role | Who | Responsibilities |
|---|---|---|
| Maintainer | Bakir Gracić ([@bakirgdev](https://github.com/bakirgdev)) | Triage issues and discussions. Review and merge pull requests. Set direction and keep the roadmap and the recorded decisions current. Cut releases, including signing, notarization and attestation. Answer vulnerability reports as described in [`SECURITY.md`](SECURITY.md). Enforce the [Code of Conduct](CODE_OF_CONDUCT.md). |
| Contributor | Anyone who opens an issue, a discussion or a pull request | Follow [`CONTRIBUTING.md`](CONTRIBUTING.md): tests for changed behavior, the design rules, disclosure of AI assistance, MIT licensing of the contribution. Follow the Code of Conduct. Report vulnerabilities privately. |

No other roles exist today. The maintainer is currently the only committer, reviewer, release manager and security contact.

## Becoming a maintainer

Sustained, good-quality contributions, and an invitation from the maintainer. There is no application process.

## Continuity

The project has one maintainer and no second person with release or repository admin access. This is an accepted gap, not something with a plan behind it. If the maintainer becomes unavailable, releases, security responses and merges stop. The code is MIT-licensed, so anyone can fork it.

## Changing this file

Open a pull request against `GOVERNANCE.md`. The maintainer decides, like everything else.
