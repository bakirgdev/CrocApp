# Claude Design workflow for CrocApp redesign

How to generate the app's visual redesign in Claude Design (claude.ai/design), then hand off to Claude Code for SwiftUI implementation.

## Facts (verified 2026-07)

- Claude Design generates working HTML/React on a canvas, not images. Iterate via chat (broad), inline comments (targeted), direct canvas editing.
- Design systems are **org-level**: upload assets → Claude extracts UI kit → publish → all new projects inherit it. Update later via "Remix" in org settings.
- Sequential prompts inside one project inherit prior context; batch 5-7 screens per prompt (150-300 words each). One mega-prompt degrades quality.
- Light/dark must be requested explicitly per prompt.
- Handoff: export ZIP/PDF/HTML or send directly to Claude Code, which continues from the generated code.
- Limitation: Liquid Glass renders as CSS backdrop-blur approximation. Treat output as visual spec; real fidelity comes from native `.glassEffect()` in SwiftUI.

## Process

1. claude.ai/design → create/switch org.
2. Org design-system setup: attach reference screenshots (iOS 26 Liquid Glass system apps; optionally current app), then run Prompt 1. Publish.
3. New project ("mobile app design" template) → run Prompts 2-5 in order, same project.
4. Iterate; if output drifts generic (teal gradients, serif), comment "use only design system tokens, SF Pro, croc green accent".
5. Hand off to Claude Code for SwiftUI translation.

## Prompts

Prompt texts live in the session that produced this doc; canonical copies below.

### 1 — Design system

Brand: trustworthy, private, fast, calm. Accent: deep croc green (#1E9E6A family). Tokens: semantic status colors, SF Pro + SF Mono, 4pt grid, concentric radii, 480pt content max-width, glass surface tints, both themes. Components (all interaction states): prominent/secondary/destructive buttons, glass panel, file row, segmented control, monospaced code field with paste, dual progress bars with speed, status banners, code-phrase display + QR frame, empty state, sheet header, E2E trust badge, settings rows.

### 2 — Core iPhone screens

Home (two-verb + trust badge + settings/history toolbar), Send Files (drop zone empty + filled list + custom code field), Send Text, Receive (code field + QR scan + output folder row), Staged Files sheet, share extension states.

### 3 — Transfer lifecycle

Waiting (code + copy + QR + spinner), Connecting, Incoming accept gate (plus overwrite-warning and blocked-unsafe variants; never auto-accept), Transferring (dual progress + speed, direction unambiguous), Done (files variant + received-text variant), Failed, local-network-denied banner.

### 4 — Planned screens

Settings (relay / transfer / receiving with auto-accept warning / about groups), "How it works" trust explainer (PAKE, relay sees ciphertext only), Transfer history (date groups, resend, clear, empty state), Onboarding (3 cards), QR scanner sheet + camera-unavailable fallback.

### 5 — macOS variants

Same two-verb layout, no sidebar. Home window with drop hint, desktop-density Send/Receive/transfer states, macOS Settings window, full-window "Drop to send" glass overlay. Identical tokens; only density/chrome/input affordances change.

## Design fixes to enforce in redesign

- Transfer screens must make direction (Sending vs Receiving) unambiguous — current UI bleeds active Send status onto Receive screen.
- Incoming accept gate needs a designed Cancel/exit affordance beyond Decline.
