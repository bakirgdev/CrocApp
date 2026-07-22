# Prior art & growth notes

Research digest 2026-07-22.

## Landscape

Apple-native croc niche effectively empty: only iCroc (paid, closed-source, stale since 2024, embeds croc v10.0.8). Android: crocgui (Go+Fyne, 311★), croc-app (Kotlin/Compose, 85★, best mobile UX reference — but subprocess architecture, not portable to iOS). Desktop: crock (Electron, 32★, best desktop UX reference). Adjacent: LocalSend (85k★, LAN-only — breaks on guest/mDNS-hostile networks and iOS backgrounding; croc's relay model is the differentiator), PairDrop, Rymdport, Destiny (wormhole Flutter, stale), Winden, Blip.

## UX patterns to adopt

- Two-verb home: giant Send / Receive, nothing else.
- QR both directions; clipboard code auto-detect on receive.
- Clipboard/text snippet transfer = top real-world use case (croc-app author's #1).
- Transfer history + saved codes for repeat pairs.
- Custom relay first-class + relay indicator (trust anxiety is real; explain PAKE/E2E in-app).
- Receive preview (file list, sizes) before accept; sanitize filenames; explicit overwrite confirm — answers croc's 2023 audit class of issues, marketing point.
- Deeplink `croc://<code>` encoded in QR (crock does this).
- Positioning: "works when AirDrop/LocalSend don't — different networks, different continents."

## Growth playbook (LocalSend-derived)

- Repo description = pitch one-liner; screenshots/recordings top of README; store badges.
- Ship minimal fast, iterate in public; donations only, no monetization.
- Distribution breadth: App Store + TestFlight public link + DMG + brew cask (ADR 0007).
- Post-launch: PR adding CrocApp to croc README GUI section (how crocgui/croc-app get found); HN, r/selfhosted, r/opensource, Mac blogs (MacStories et al.); translations early.
