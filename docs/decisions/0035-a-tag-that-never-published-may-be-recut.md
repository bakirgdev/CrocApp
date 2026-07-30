# 0035. A tag whose run never published may be re-cut, by fast-forward

Status: accepted
Date: 2026-07-30

## Context

ADR 0032 turns on immutable releases and says plainly that a bad asset cannot be swapped, only replaced by a new version. That is the right rule for anything users can download.

The first `v0.9.9` tag produced nothing users could download. Its `release` job failed to start at all:

```
##[error]Unable to resolve action `actions/download-artifact@ea165f8...`, unable to find version `ea165f8...`
```

The pin was `actions/upload-artifact` v4.6.2's commit, pasted onto `download-artifact`, where no such commit exists. The `build` job passed; the `release` job died on the first step. No release object was created, no asset was uploaded, and `/releases/latest` still resolved to nothing.

So the tag pointed at a commit that had never been published from, and re-using the number was not a swap of anything.

## Decision

A `v*` tag may be re-cut **only** when nothing was ever published from it. Before moving it, confirm both:

- `gh release list` does not list the version, and
- `gh run list --workflow=release.yml` shows no successful run for that tag.

If either check fails, the tag is spent — burn the number and cut the next one instead.

**Deleting the remote tag is not actually possible in this repository, and that is deliberate.** The `Releases 'v*' ruleset` targets `refs/tags/v*`, forbids `deletion` and `non_fast_forward`, and has no bypass actors, so `git push origin :refs/tags/v0.9.9` is rejected outright:

```
! [remote rejected] v0.9.9 (push declined due to repository rule violations)
```

Do **not** weaken or disable that ruleset to get around it. The supported move, when the old tag commit is an ancestor of the new one, is a fast-forward update, which the ruleset permits:

```
git merge-base --is-ancestor v0.9.9^{commit} HEAD   # must pass
git tag -f -a v0.9.9 -m "CrocApp 0.9.9" <new-commit>
git push origin refs/tags/v0.9.9 --force
```

If the old tag commit is *not* an ancestor, the tag cannot be moved and cannot be deleted — burn the number.

Rehearse with `workflow_dispatch` before moving the tag, not after.

## Consequences

- The version number stays meaningful. v0.9.9 is the first release rather than a gap followed by v0.9.10 that nobody can explain.
- Immutability is unchanged in substance: it protects published artifacts, and there were none.
- The rehearsal path does **not** exercise the whole pipeline. `workflow_dispatch` skips the `release` job entirely (`if: startsWith(github.ref, 'refs/tags/v')`), which is exactly the job that failed. A green dispatch is evidence the build works, not evidence the publish works — the tag push remains the first real test of anything inside `release`. Pin-only mistakes like this one are therefore best caught by checking the SHA resolves (`gh api repos/<owner>/<repo>/git/refs/tags`) before committing the pin.
- Moving a published-from tag is still destructive and stays an explicit, owner-authorised act. This ADR records when it is defensible, not a licence to do it routinely.
- The ruleset is the backstop, not this document. It is what actually stops a spent tag being reused, and it kept working even when a session set out to delete one — which is the point of writing rules down in the repository rather than in prose.
- v0.9.9's re-cut worked because `72c989f` was an ancestor of the merged `21e7501`. That is the normal shape (the failed tag predates the fix), but it is not guaranteed.
