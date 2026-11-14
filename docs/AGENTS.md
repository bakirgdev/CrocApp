# docs/

Contributor and internals documentation: how CrocApp is built, how it works inside, and how it ships. `README.md` indexes every file. How to use the app lives on the docs site (`web/docs/content/`); every visual and copy principle lives in `design/`.

## Where a fact goes

| Fact | File |
| --- | --- |
| How the layers fit together, who owns what state | `ARCHITECTURE.md` |
| Toolchain, first build, lint, tests, transfer harnesses | `BUILDING.md` |
| Signing, notarization, Sparkle, App Store uploads, the release checklist | `RELEASING.md` |
| A term a newcomer cannot infer | `GLOSSARY.md` |
| Why the security claims hold | `THREAT-MODEL.md` |
| A defect or limit the project lives with | not a doc: a GitHub issue labelled `known` |
| Deep reference on one subsystem or process | `knowledge/<topic>.md` |

One fact has one home. Everywhere else links to that home instead of restating it. Code, config files and `--help` output own their own values: a doc records the reason, the constraint and the trap, which no file shows.

## Writing rules

- **State what is true now.** Facts, constraints, reasons and direction. Leave out dates, run IDs, plan or ticket IDs and "first we tried" stories: git history keeps them, and they go stale. A fact checked against an upstream names the version it was checked against ("Xcode 27 SDK"), except croc: only `knowledge/what-is-croc.md` names the exact croc version, and every other doc says "croc 11".
- **Check before writing.** Read the code, config or upstream source a claim is about. Mark anything not checked as "not verified", "inferred" or "unknown", in those words.
- **Cite by file and heading text**, as in `BUILDING.md`, "Verification harnesses". Never by section number or line number.
- **Plain English for a developer new to this repo.** One idea per sentence. A bullet stays a few lines; split anything longer, and use a table when rows compare. Define a term on first use or link `GLOSSARY.md`. Commas, colons or parentheses, not em dashes.
- **UI words match the app exactly**: the control's label in bold, in the app's capitalization (`design/voice.md`, "Capitalization").
- **Headings are stable.** Other files cite them, so renaming one means updating every citation (`git grep` the old text).

## Keeping docs true

- A change is finished when the docs describing it match it. The root `AGENTS.md`, "Docs", names the docs that user-visible, croc-version and security changes must update.
- A stale or wrong fact you notice gets fixed or deleted in the same change.
- `scripts/verify-docs.sh` checks every relative link and repo path in the markdown docs, and CI runs it. Run it after any docs edit. It also checks that the heading a citation quotes exists (`file`, "Heading" or a link followed by `, "Heading"`), compared as plain text without a leading number or code ticks; a citation in another shape is not checked, so check those by hand.
