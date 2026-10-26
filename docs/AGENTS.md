# docs/

Contributor and internals documentation: how CrocApp is built, how it works inside, how it ships, and what is known to be wrong with it. `README.md` indexes every file. How to use the app lives on the docs site (`web/docs/content/`); every visual and copy rule lives in `design/`.

## Where a fact goes

| Fact | File |
| --- | --- |
| How the layers fit together, who owns what state | `ARCHITECTURE.md` |
| Toolchain, first build, lint, tests, transfer harnesses | `BUILDING.md` |
| Signing, notarization, Sparkle, App Store uploads, the release checklist | `RELEASING.md` |
| A term a newcomer cannot infer | `GLOSSARY.md` |
| What is planned and what is not | `ROADMAP.md` |
| Why the security claims hold | `THREAT-MODEL.md` |
| A defect, limitation or risk the project lives with | `known-issues.md` |
| Deep reference on one subsystem or process | `knowledge/<topic>.md` |

One fact has one home. Everywhere else links to that home instead of restating it. Code, config files and `--help` output own their own values: a doc records the reason, the constraint and the trap, which no file shows.

## Writing rules

- **State what is true now.** Facts, constraints, reasons and direction. Leave out dates, run IDs, plan or ticket IDs and "first we tried" stories: git history keeps them, and they go stale. A fact checked against an upstream names the version it was checked against ("croc v11.5.5", "Xcode 27 SDK").
- **Check before writing.** Read the code, config or upstream source a claim is about. Mark anything not checked as "not verified", "inferred" or "unknown", in those words.
- **Cite by file and heading text**, as in `BUILDING.md`, "Verification harnesses". Never by section number or line number.
- **Plain English for a developer new to this repo.** One idea per sentence. A bullet stays a few lines; split anything longer, and use a table when rows compare. Define a term on first use or link `GLOSSARY.md`. Commas, colons or parentheses, not em dashes.
- **UI words match the app exactly**: the control's label in bold, in the app's capitalization (`design/content.md`, "Capitalization").
- **Headings are stable.** Other files cite them, so renaming one means updating every citation (`git grep` the old text).

## Keeping docs true

- A change is finished when the docs describing it match it. The root `AGENTS.md`, "Docs", maps each area of code to the docs it must keep in step.
- A stale or wrong fact you notice gets fixed or deleted in the same change.
- `known-issues.md` gains an item when a defect is found and left; the item goes when the defect is fixed.
- `scripts/verify-docs.sh` checks every relative link and repo path in the markdown docs, and CI runs it. Run it after any docs edit.
