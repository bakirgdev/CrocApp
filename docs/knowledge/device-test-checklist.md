# Physical-device test checklist

The simulator cannot verify any of these. Run them on a real iOS 26 device before store submission — this is the hardware gate. Nothing here has been run yet.

## Background continuation (BGContinuedProcessingTask)
- [ ] Start multi-GB receive, background the app → system Live Activity shows title + progress + cancel
- [ ] Transfer completes in background (best-effort; low-progress kills expected under pressure)
- [ ] Force-expire (long background under memory pressure) → reopen app shows "iOS paused the transfer…" message; restarting same transfer resumes partial file (croc resume)
- [ ] Cancel from the system Live Activity → app shows cancelled state
- [ ] Wildcard identifier registers OK on-device (fallback static id is the backstop; check console for register() failures)

## Share extension
- [ ] Photos → share sheet → CrocApp: stages, "Open CrocApp" instruction shown
- [ ] Files app → share multiple files → CrocApp: all staged
- [ ] Open app afterwards → staged sheet appears → Send completes to another device
- [ ] Large video (>500 MB) stages without extension being killed (memory cap)

## Files app visibility
- [ ] "On My iPhone → CrocApp" appears after first receive; received files visible
- [ ] "Open in Files" button lands in the right folder
- [ ] "Open in Files" with a user-picked provider folder (iCloud Drive etc.): known silent no-op (shareddocuments:// resolves local paths only) — confirm no crash, consider hiding button there later

## Local network
- [ ] First transfer triggers local-network permission prompt
- [ ] Deny → banner appears with Settings shortcut; relay transfer still succeeds
- [ ] Multicast entitlement still pending Apple approval → LAN discovery expected to lose the race even when granted (constraint doc §2)

## Idle timer
- [ ] Screen stays awake during a long foreground transfer; sleeps normally after
