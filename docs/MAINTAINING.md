# Maintaining CrocApp

How the project runs after 1.1.0: recurring dates, release cadence, support channels and what happens if the maintainer is away. One maintainer (Bakir Gracic) holds the Apple account, the signing secrets, the domain and repo admin. The release mechanics live in `RELEASING.md`; this file is the policy around them.

## Calendar

| When | What | Where it is tracked |
| --- | --- | --- |
| Every Monday | Read the "Pinned versions to update" issue and the Dependabot PRs; merge what is green | `.github/workflows/pin-watch.yml`, `dependabot.yml` |
| January 2027 | Renew the Developer ID certificate and profile before they expire on 2027-02-01 | `RELEASING.md`, "One-time setup", steps 2 and 5 |
| Before 2027-08-01 | Bump `Expires` in `security.txt` | `known-issues.md`, "Landing page" |
| 2027-08-27, then yearly | Apple Developer Program membership renewal | Apple account |
| Whenever App Store Connect shows one | Accept updated agreements; uploads are blocked until then | `RELEASING.md`, "One-time setup" |
| June (WWDC) to September | Build on the new Xcode beta from the third beta, ship a compatibility release by the OS launch | This file, "OS cycle" |

## OS cycle

- Support the current major OS and the one before it. The minimum moves up each September, in the first release after the new OS ships.
- Test on betas from the third beta; file Feedback for regressions in system frameworks instead of working around them early.
- The Xcode pin follows `BUILDING.md`, "When the toolchain changes"; release candidates never build a release.

## croc upstream

- Follow croc minor and patch releases once `docs/knowledge/croc-upgrade-playbook.md` and the interop harness pass, normally within two weeks.
- Hold a release back (as with croc 11.6) when it breaks progress, interop or error classification, and say why in the hold's issue.

## Releases

- Ship when ready, no fixed rhythm. A patch (`X.Y.Z+1`) carries fixes, toolchain bumps and small polish; a minor (`X.Y+1.0`) carries features or visible UI changes.
- The disk image and both App Store builds come from the same commit and version. The disk image ships first because it needs no review; the App Store builds follow when App Review allows.
- No public TestFlight group for now; internal testing only.

## Security

- Reports arrive through private vulnerability reporting (`SECURITY.md`). Acknowledge within 3 days; fix high-severity issues within 14 days.
- A security fix ships as a disk image at once (Sparkle reaches Direct users within a day) and as App Store builds with an expedited review request.

## Users and support

- Bugs go to Issues, questions to Discussions (`.github/ISSUE_TEMPLATE/config.yml` routes them). Check both weekly; reply to new issues within 7 days.
- Reply to App Store reviews in App Store Connect weekly; point bug reports to Issues.
- No stale bot: issues are closed by hand with a reason.

## Knowing whether it works

The app collects no data, by design, and that does not change. The signals:

| Signal | Where | How often |
| --- | --- | --- |
| Crashes | Xcode Organizer, TestFlight Crashes | Weekly in the two weeks after a release, then monthly |
| Downloads, conversion | App Store Connect, Analytics (opt-in aggregates) | Monthly |
| Disk image downloads, stars | GitHub release assets, repo Insights | Monthly |

## Contributors

- Outside contributions are welcome under `CONTRIBUTING.md`. Small, self-contained issues get the `good first issue` label.
- Only the maintainer merges. A second maintainer would get merge rights under the same rules (`.github/AGENTS.md`).

## Money

Free, with optional donations on the website only. No paid tier, tip jar or in-app purchase: each would change the App Store privacy answers and the "free" positioning.

## Bus factor and exit

- Credentials (Apple account, signing `.p12` and its password, the domain registrar, GitHub) live in the maintainer's password manager. Nobody else can renew a certificate or ship a release today.
- If the project stops: archive the repo, put a notice on the website, and remove the app from sale once it breaks on a new OS.
- `RELEASING.md` and `BUILDING.md` stay complete enough to release from a clean Mac.
