# docs/knowledge

Evergreen project knowledge: what this project is, what croc is and how it works, and the invariants that outlive any individual feature. Written dense, for AI-session consumption first and humans second.

What does not belong here: decisions and their rationale (`../decisions/`), open defects and deferred work (`../known-issues.md`), and anything that is a snapshot of work in progress. Stale facts get fixed or deleted in the session that notices them — see root `CLAUDE.md`, "Docs self-heal".

## Files

| File | Read it when |
|---|---|
| `project-overview.md` | you need the goals, constraints, and non-goals in one screen |
| `what-is-croc.md` | you need croc's transfer protocol, crypto, CLI surface, or security history |
| `features.md` | you need the F-number for a feature, or whether it has shipped |
| `crocmobile-bridge.md` | **before touching** `crocmobile/session.go`, `CrocKit/Sources/`, or the event contract |
| `app-ui-architecture.md` | **before touching** any view that observes `TransferController` |
| `apple-platform-constraints.md` | you are up against iOS backgrounding, sandboxing, entitlements, or App Store review |
| `tooling.md` | CI is failing, a linter is complaining, or you want to know why a tool was skipped |
| `croc-upgrade-playbook.md` | upstream croc released a new version |
| `device-test-checklist.md` | you are about to test on real iOS hardware |
| `prior-art.md` | you are making a UX, positioning, or distribution call |
| `docs-site.md` | **before touching** `web/docs/` |
| `screenshots.md` | you need to re-capture, add, or move an app screenshot |

Anything visual — app views, landing page, docs site — starts at `design/CLAUDE.md` instead.
