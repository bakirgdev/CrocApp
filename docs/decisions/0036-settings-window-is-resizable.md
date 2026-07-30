# 0036. The macOS Settings window is resizable

Status: accepted
Date: 2026-07-30

## Context

The Settings window was a fixed 480x450 that refused `AXSize` writes. Two entries in `../known-issues.md` were filed against that as permanent facts: the window could not be photographed whole, so `scripts/capture-screenshots.sh` stopped mid-row wherever the form ran longer.

It was never a platform limit. A `Settings` scene's default `.automatic` window resizability resolves to `.contentSize`, where minimum equals maximum equals the content's size — `WindowGroup`, `Window` and `DocumentGroup` resolve to `.contentMinSize` instead. The repo never overrode it, so the "fixed" size was just `SettingsView`'s own `.frame(width: 480)` plus whatever height the form asked for.

The owner asked for the window to be resizable.

## Decision

`.windowResizability(.contentMinSize)` on the `Settings` scene, plus `.defaultSize(width: 480, height: 780)`, and `SettingsView`'s `.frame(width: 480)` becomes `.frame(minWidth: 480, minHeight: 420)`.

All three parts are needed, and the reason is measured rather than assumed:

- With only `.contentMinSize`, AppKit chose its own opening width — about 900 — and the fixed-width form sat marooned in the middle with dead margins on both sides. `.defaultSize` pins the opening geometry.
- With `.frame(width:)` still fixed, widening the window would keep producing those margins. `minWidth` lets the form grow with it.

## Consequences

- Both "Accepted" known-issues entries about the Settings window are gone: it resizes, and the capture script now catches every section down to Confirmation.
- 780 is taller than a typical macOS Settings window. It is the height that fits this form; if sections are added, either the number moves or the window opens scrolled.
- The window is now a resizable surface the design system has no spec for at arbitrary sizes. The grouped `Form` handles it, but a future two-column settings layout would need a real spec first.
- The caret fix (`defaultFocus` steering initial focus to the Show in Finder button) is independent of this and would have been needed either way.
