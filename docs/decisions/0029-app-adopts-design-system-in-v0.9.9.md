# 0029. The app adopts `design/` directly, pulled forward into this release

Status: accepted
Date: 2026-07-28

## Context

ADR 0015 extracted the design system into `design/` so three consumers could share it: the SwiftUI app, the landing page, and the docs site. The app was the one consumer still reaching for raw colours and literal constants — `AccentColor.colorset` predated `design/` entirely (single universal colour, no dark variant), and views mixed off-grid spacing, bare corner radii, and a hardcoded 420pt content width. The restyle itself had no scheduled release; it was open-ended, cosmetic work that could happen whenever.

A release-readiness pass over the rest of the app (panic recovery at the gobind boundary, `AutoVerify` gated out of Release, the export-compliance declaration) made this release the first one actually worth shipping. Doing that without also fixing the accent-colour and literal-constant mismatch `docs/known-issues.md` had been carrying as a blocking-release item made no sense once the rest of the app was ready.

## Decision

- **The app adopts `design/` through a Swift token layer**, `app/CrocApp/Support/DesignTokens.swift`: `Spacing`, `Radius`, `BorderWidth`, `ControlHeight`, `IconSize`, `LayoutCap`, `ComponentMetrics`, `Motion`, plus `Color` aliases. Views stop hand-rolling these values.
- **Colour aliases with no system equivalent become asset-catalog colour sets**, not `Color` literals in Swift, so light/dark switches at the asset layer instead of an `#if` branch on `colorScheme` in every call site. Ten new sets (`ColorAccentPressed`, `ColorAccentText`, `ColorAccentTextOnTint`, `ColorOnAccent`, `ColorPaper`, `ColorScrim`, and the four `ColorStatus*Tint` sets) join the corrected `AccentColor` (`#1E9E6A` light / `#2DC585` dark, per `design/brand.md`).
- **Where a token already matches a system semantic exactly, the alias routes there instead of duplicating an asset.** `Color.accentFill` is `.accentColor`, not a duplicate asset — so `.tint()` and system chrome pick it up for free.
- **`TrustBadge`, `StatusBanner`, and `StatusBlock` are built to `design/components.md`.** All three previously coloured body text with a status colour, which measures 1.96–2.95:1 and fails AA (ADR 0016's rule: a status colour is a fill, never a foreground); the tint and glyph carry the meaning now, the label stays primary.
- **The UIKit/AppKit split for colour resolution lives in exactly one file**, `DesignTokens.swift`, rather than scattered across views.

## Consequences

- `docs/known-issues.md`'s accent-colour and literal-value items are resolved; `CodeField` and `FileRow` (`design/components.md`) are not yet built as their own components, and no shadow token exists yet for the QR frame's specced `--shadow-md` — both remain open there.
- Ten new colour sets are a maintenance surface: a future token change in `design/colors.md` means updating the matching `.colorset/Contents.json` by hand, same drift risk ADR 0015 already accepted for `design/tokens.css`.
- The restyle stayed cosmetic (ADR 0015's consequence still holds): no accept-gate flow, phase state machine, or prompt-pipe event handling changed to land it.
