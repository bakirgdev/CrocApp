# Physical-device test checklist

The simulator cannot verify any of these. Run them on a real iOS 26 device before store submission — this is the hardware gate. Nothing here has been run yet.

## Background continuation (BGContinuedProcessingTask)
- [ ] Start multi-GB receive, background the app → system Live Activity shows title + progress + cancel
- [ ] Transfer completes in background (best-effort; low-progress kills expected under pressure)
- [ ] Force-expire (long background under memory pressure) → reopen app shows "iOS paused the transfer…" message; restarting same transfer and choosing Replace resumes partial file (croc resume; Keep Both saves a new copy instead)
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

## Transport and Tailcat gate
Owner-run on a physical iPhone, against the Mac CLI (`/opt/homebrew/bin/croc`, v11). Use a file of at least 130 MiB, because croc starts Tailcat only for sends of 128 MiB or more (`crocmobile-bridge.md`, "Transport"). Under Automatic croc races Tailcat against its relay, so the CLI `--debug` log shows which side offered it. Report each SHA-256 (`shasum -a 256` on the Mac; copy a file received on the iPhone to the Mac to hash it) so Claude can compare them with the source file's. Pass for the gate is (a) to (c) complete with equal SHA-256 and no crash or hang. (d) is informational.
- [ ] (a) Settings > Connection = Automatic. Send the file from the iPhone to `croc --debug --yes` on the Mac, once with the app in the foreground and once switching to another app mid-transfer and back. Pass: both transfers complete, the SHA-256 matches the source, and the CLI log contains `tailcat-offer`
- [ ] (b) Connection = Relay only. Same send, foreground. Pass: the transfer completes, the SHA-256 matches, and the CLI log has no `tailcat-offer`
- [ ] (c) On the Mac run `croc --debug --ignore-stdin send --transport auto <file>` and receive on the iPhone, once in the foreground and once backgrounded mid-transfer. Pass: both complete and the SHA-256 matches
- [ ] (d) Informational: on the Mac run `croc --debug --ignore-stdin send --transport derp <file>` and receive on the iPhone. Note whether it completes. This records whether Tailcat's own data path works on iOS; on the development Mac the same flag failed CLI to CLI (`../known-issues.md`, Harnesses)
- Archived iOS app size, with Tailcat (measured 2026-10-14 with `scripts/build-appstore.sh ios`, export only): `CrocApp.ipa` 18.5 MB (18,471,600 bytes); `CrocApp.app` in the archive 25 MB, of which the main executable (Go engine linked in) is 20.3 MB (20,332,352 bytes)

If (a) to (c) fail: build the engine with `-tags croc_no_tailcat` in `scripts/build-xcframework.sh`, remove the Connection setting and the "Direct path for large files" item in How it works (its relay item stays), and file a `future` issue. A build without Tailcat downgrades croc's `derp` to `relay` (`what-is-croc.md`).
