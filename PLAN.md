# PLAN — CrocApp landing page

Working document for building `crocapp.dev`. Delete or archive once the page ships.

Status: **plan approved.** Phase 0 (tokens) done and pushed. Phase 1 owner-side infrastructure done. Remaining phase 1 work is the deploy workflow itself.

---

## 1. Goal

One static page at `https://crocapp.dev` that:

- explains what CrocApp is and why it exists, to someone who has never heard of croc
- shows what the app looks like before the visitor commits to a download
- gets the download, the GitHub star, or the sponsorship
- credits croc correctly and states the unaffiliated relationship (required by `design/brand.md`)
- is the first surface someone lands on from HN / r/opensource / the croc README PR

Secondary: it is the visual proof that `design/` produces a coherent system across app and web.

## 2. Locked decisions

| Decision | Choice | Why |
|---|---|---|
| Ship framing | **As if already shipped.** Full download matrix. | Approved 2026-07-25. Store links are imminent. |
| Domain | **`crocapp.dev`**, owned. Apex + `www` redirect. | Bought. `.dev` is HSTS-preloaded → HTTPS mandatory, Pages provisions it. |
| Hero visual | **CSS-built app UI**, no screenshots. | App restyle not done. CSS mockup is on-brand day one, weighs nothing, tracks token changes. |
| Stack | **Hand-written HTML + CSS + ~3 KB vanilla JS. No build step, no npm.** | Repo has zero JS today. A `package.json` in a Swift/Go repo is a maintenance tax the page does not need. |
| Analytics | **None.** Zero tracking scripts. | A privacy-first transfer app that loads a tracker is a bad look. |
| Star count | **Live, via `api.github.com`.** | Approved. This is the page's *only* third-party request — see §9 risk. |
| Missing URLs | **`href="#"` placeholders**, tracked in `TODO.md` § "Landing page — pending links & assets". | Approved. |
| Design tokens | **Web tokens added to `design/`**, not literals. | Done, phase 0. |
| Mascot format | **Stays PNG.** No webp re-encode. | Owner decision 2026-07-25. 51 KB, transparent, already in `assets/`. |
| Favicons | Generated from `assets/mascot.png` via realfavicongenerator.com, live in `web/landing/assets/img/favicon/`. | Owner-supplied. Note this means the **tab icon is the mascot, not the app icon** (`assets/CrocAppIcon.icon`) — deliberate if you like it, a mismatch to fix if not. |

## 3. Page architecture

Single page, 13 sections, anchor nav. Order is the argument: *what → why you can't do this today → how → what you get → get it → who made it → help.*

| # | id | Section | Purpose |
|---|---|---|---|
| 1 | — | Sticky glass nav | wordmark, 4 anchors, theme toggle, GitHub link + live star count |
| 2 | `#top` | Hero | H1, deck, Download + GitHub CTAs, CSS app mockup, trust pills |
| 3 | `#why` | Why this exists | the three things that don't work, then croc's answer |
| 4 | `#how` | How it works | 3 steps + collapsed "what happens underneath" |
| 5 | `#features` | Features | 4 groups, ~24 items, Lucide inline SVG |
| 6 | `#download` | Download | 4 channel cards + requirements |
| 7 | `#croc` | Powered by croc | attribution + unaffiliated disclaimer |
| 8 | `#made` | How it was made | gomobile bridge, SwiftUI, AI-first, ADRs |
| 9 | `#inspiration` | Inspirations | prior art, credited honestly |
| 10 | `#contribute` | Contribute | what help is wanted, where to start |
| 11 | `#support` | Support | Sponsors + Buy Me a Coffee, calm framing |
| 12 | `#faq` | FAQ | 8 `<details>` — no JS needed |
| 13 | — | Footer | license, unaffiliated notice, mascot |

### Copy direction

Voice per `design/brand.md`: **trustworthy, private, fast, calm — in that order.** No exclamation marks, no urgency, no confetti. Plain language; the cryptography detail is one disclosure deeper, never in the headline.

**Hero**

> # Send files anywhere. Encrypted end to end.
>
> CrocApp is a free, open-source app for iPhone, iPad and Mac. Pick a file, read out a code phrase, done. No account, no upload to anyone's cloud, no same-network requirement.

Trust pills: `End-to-end encrypted` · `No account` · `Open source, MIT` · `Works across networks`

**Why this exists** — four cards, the first three are the problem:

- **AirDrop** — Apple to Apple, and you both need to be in the same room.
- **LAN tools** — same Wi-Fi only. Guest networks and client isolation break them silently.
- **Cloud drops** — you upload your file to a company first, then send a link. They have the file.
- **CrocApp** — a code phrase. Same room or different continents. The relay only ever sees ciphertext.

**How it works** — 3 steps, then a `<details>` disclosure:

1. Choose files, a folder, or text.
2. CrocApp shows a code phrase: `8412-mirage-cobalt-fresco`.
3. The other side types it in. Transfer starts.

<details> "What happens underneath" — bounded strictly by `brand.md`'s allowed claim:

- The code phrase never crosses the network in the clear. Both sides run PAKE over it to derive a session key the relay never learns.
- Files are encrypted before they leave your device.
- The relay is untrusted by design. It forwards ciphertext and nothing else.
- On the same network, CrocApp connects to the other device directly and skips the relay entirely.

**Do not** extend past those four statements. No "military-grade", no "unhackable", no audit claim (there has been no formal audit — `docs/knowledge/what-is-croc.md`).

**Features** — 4 groups drawn from `docs/knowledge/features.md` (V1 only; V1.x items must not appear as if shipped):

- *Send* — F1 F2 F3 F30 F6 F16 F17
- *Receive* — F4 F5 F6 F9 F8 F7
- *Trust & control* — F36 F13 F14 F18 F19 F15
- *Native* — F10 (Live Activity) F12 F11, Files app, Mac drag-and-drop, light/dark, Dynamic Type + VoiceOver

**Download** — 4 cards: iOS App Store, Mac App Store, notarized DMG (Developer ID), Homebrew cask (`brew install --cask crocapp`, copy button). Requirements line: *iOS 26 or later · macOS 26 or later*. Per ADR 0007.

**Powered by croc** — non-negotiable text:

> CrocApp is the interface. [croc](https://github.com/schollz/croc) is the engine — by Zack Scholl, MIT licensed. CrocApp embeds croc's Go library. It is unofficial and unaffiliated; nothing here implies endorsement by croc's author.

**How it was made** — genuinely differentiating content, keep it:

- croc's Go library compiled to an XCFramework with gomobile and driven from a Swift actor. Not a subprocess — iOS does not allow those, which is why the Android clients' architecture does not port (ADR 0006).
- SwiftUI, iOS 26 / macOS 26 minimum (ADR 0003).
- Built almost entirely with Claude Code by one person learning Apple development in the open.
- Every decision is a numbered ADR in the repo. Link `docs/decisions/`.

**Inspirations** — croc, magic-wormhole, LocalSend, croc-app (Android), crock (desktop), crocgui. Sourced from `docs/knowledge/prior-art.md`. Credit, don't disparage.

**FAQ** — 8 entries: Is it actually secure? · Do I need an account? · Does my file go through a server? · What if we're on the same Wi-Fi? · Does it work with the `croc` CLI? · Windows / Linux / Android? · Can I run my own relay? · What does it cost?

## 4. File layout

```
web/landing/
  index.html          single page, all sections, inline SVG icons
  styles.css          consumes tokens.css; zero raw hex/px
  app.js              theme toggle, copy button, star count, nav state (~3 KB, no deps)
  CNAME               crocapp.dev
  robots.txt
  sitemap.xml
  assets/img/
    og.jpg                             social card                      [supplied]
    mascot.png                         copied from assets/mascot.png
    banner.webp                        copied from assets/banner.webp
    favicon/
      favicon.ico                      legacy, multi-size               [supplied]
      favicon-96x96.png                                                 [supplied]
      apple-touch-icon.png             180×180                          [supplied]
      web-app-manifest-192x192.png                                      [supplied]
      web-app-manifest-512x512.png                                      [supplied]
      site.webmanifest                 paths + brand colors corrected

scripts/serve-landing.sh          copies design/tokens.css in, serves on :8000
.github/workflows/pages.yml       assemble + deploy
```

`favicon.svg` was deleted from the supplied set: realfavicongenerator emits a 69 KB `<svg>` wrapper around a base64 PNG. It is not a vector, and browsers that support SVG favicons prefer it over the 3.6 KB PNG — so shipping it costs 65 KB to render a 16px glyph. If a true vector mascot ever exists, add it back.

`site.webmanifest` needed three corrections after generation, worth knowing if it is ever regenerated:

- icon `src` values were root-absolute (`/web-app-manifest-192x192.png`) and would 404 from `/assets/img/favicon/`. Now relative.
- `purpose` was `maskable` on both icons with no `any` icon. The mascot runs edge-to-edge, so Android's inner-80% safe zone crops the tail and snout. Now `any`. True maskable support needs a re-export with padding and a filled background.
- `theme_color` / `background_color` were `#000000`. Now `--green-600` `#1E9E6A` / `--paper` `#FFFFFF`. These are the one place a literal hex is unavoidable — JSON cannot read CSS custom properties. Keep them in sync with `design/colors.md` by hand.

**`tokens.css` is never committed under `web/`.** The deploy workflow and the serve script both copy `design/tokens.css` into place. One source of truth, no drift, no build tool. `web/landing/tokens.css` goes in `.gitignore`.

### Token rules

- No raw hex, px, or duration in `styles.css`. Missing value → add the token to `design/` first (README rule 3).
- Container: `--content-max-width-web`. Prose: `--content-max-width-prose`. Hero/gallery: `--content-max-width-wide`.
- Display type: `.t-web-hero` / `.t-web-section` / `.t-web-sub` / `.t-web-lead`. Body and below stay on the app scale.
- Icons: inline Lucide SVG per the `design/iconography.md` mapping table. 24×24 viewBox, `fill:none`, `stroke:currentColor`, `aria-hidden="true"`. Never bundle the Lucide package.
- Both themes required. `[data-theme]` on `<html>` wins over `prefers-color-scheme`.
- **Light theme is the constrained one.** Small accent text and links use `--green-700` (4.94:1), never `--green-600` (3.41:1 on white).
- No gradients. No serif. One accent.

## 5. Deployment

### Workflow — `.github/workflows/pages.yml`

Separate from `ci.yml` (which is Xcode/Go and must not run for a CSS change).

- Trigger: `push` to `main` on `web/**`, `design/tokens.css`, `.github/workflows/pages.yml`; plus `workflow_dispatch`.
- Permissions: `contents: read`, `pages: write`, `id-token: write`.
- Concurrency group `pages`, `cancel-in-progress: false`.
- Steps: checkout → assemble into `_site/` → `actions/upload-pages-artifact` → `actions/deploy-pages`.

Assembly step, which is the whole "build":

```
mkdir -p _site
cp -R web/landing/. _site/
cp design/tokens.css _site/tokens.css
[ -d web/docs ] && cp -R web/docs _site/docs || true
```

That reserves `crocapp.dev/docs` now, so the docs site later is a directory drop rather than a workflow rewrite.

**The `CNAME` file must be inside the artifact.** Verified: GitHub does not generate one for custom Actions workflows, only for branch-published sites.

### DNS at the registrar for `crocapp.dev` — ✅ done by owner 2026-07-25

Recorded for reference and for whoever has to debug this later. Verified against GitHub Pages docs, 2026-07-25.

| Type | Name | Value |
|---|---|---|
| A | `@` | `185.199.108.153` |
| A | `@` | `185.199.109.153` |
| A | `@` | `185.199.110.153` |
| A | `@` | `185.199.111.153` |
| AAAA | `@` | `2606:50c0:8000::153` |
| AAAA | `@` | `2606:50c0:8001::153` |
| AAAA | `@` | `2606:50c0:8002::153` |
| AAAA | `@` | `2606:50c0:8003::153` |
| CNAME | `www` | `bakirgdev.github.io` |

If the registrar supports `ALIAS`/`ANAME` at the apex, that may replace the eight A/AAAA records.

### Repo settings — ✅ done by owner 2026-07-25

1. Settings → Pages → Source = **GitHub Actions**.
2. Settings → Pages → Custom domain = `crocapp.dev`, **Enforce HTTPS** on.
3. Domain **verified** at github.com/settings/pages (blocks subdomain takeover).

Still ship `CNAME` inside the artifact anyway. An Actions deploy that omits it can clear the custom-domain setting on the next run — the settings value alone is not a reliable anchor.

## 6. Phases

Phase 1 exists to prove the deploy pipeline end-to-end before any design work is at risk. DNS and Pages settings are already in place, so it is now a short phase — but do not skip it. A cert or CNAME problem on a `.dev` domain means an unreachable site, not a degraded one.

| Phase | Work | Done when |
|---|---|---|
| **0. Tokens** ✅ | web layout + display tokens into `design/` | pushed `29964a5` |
| **0b. Assets** ✅ | favicon set, og image, manifest corrections | supplied + fixed 2026-07-25 |
| **1. Pipeline** | `pages.yml`, `CNAME`, placeholder `index.html`, `serve-landing.sh`, `.gitignore` entry for `web/landing/tokens.css`. *Owner-side DNS + Pages settings already done.* | `https://crocapp.dev` serves "CrocApp — coming soon" over valid HTTPS; `www` redirects; favicon appears in the tab |
| **2. Primitives** | `styles.css`: reset on top of tokens, container/section/grid, buttons, cards, glass nav, pills, `<details>`, focus rings, dark theme, reduced motion | a primitives smoke page renders correctly in both themes at 375 / 768 / 1440 |
| **3. Hero** | nav + hero + CSS-built app mockup (Send screen: file rows, code phrase in `--type-code-hero` mono, trust badge, progress bar) + trust pills | hero is convincing at 375px and 1440px; mockup uses only tokens |
| **4. Content** | sections 3–13, all copy, Lucide inline SVGs, FAQ, footer | every section present, all copy final, zero lorem |
| **5. Meta** | wire the supplied favicon set into `<head>`, copy mascot + banner into `assets/img/`, OG + Twitter meta pointing at `og.jpg`, canonical, `theme-color` ×2, JSON-LD `SoftwareApplication`, `robots.txt`, `sitemap.xml` | social card previews correctly in a real debugger; no console errors; no 404 on any icon |
| **6. A11y & perf** | keyboard pass, contrast audit, `prefers-reduced-motion`, skip link, landmarks, Lighthouse | see §7 |
| **7. Launch** | fill real URLs from `TODO.md`, final proofread, croc README PR, HN / r/opensource / r/selfhosted | page links to nothing dead |

Phases 2–4 can be committed incrementally; the site is live from phase 1 so every push is visible.

## 7. Acceptance criteria

Must all hold before phase 7.

- Lighthouse mobile: Performance ≥ 95, Accessibility 100, Best Practices 100, SEO 100.
- Total transfer < 250 KB, and < 120 KB excluding images.
- Zero third-party requests except the single `api.github.com` star fetch. No web fonts.
- Renders correctly with **JavaScript disabled**: all content readable, nav works, FAQ opens, theme follows OS. Only the toggle, copy button and star count are lost.
- Both themes correct at 375 / 768 / 1024 / 1440 px.
- Full keyboard traversal, visible focus on every interactive element, skip-to-content link first in tab order.
- No raw hex, px, or ms literal in `styles.css` outside the reset. Grep-checked.
- Contrast: body ≥ 4.5:1, large text and UI boundaries ≥ 3:1, both themes.
- `prefers-reduced-motion: reduce` removes all transitions and any mockup animation.
- No claim in the copy exceeds the four allowed statements in §3.

Verification: Chrome DevTools MCP `lighthouse_audit` for scores, Playwright MCP for cross-viewport and both-theme screenshots, manual keyboard + VoiceOver pass on macOS.

## 8. Explicitly out of scope

- `web/docs/` — the path is reserved by the workflow, the site is a separate project.
- Any second page. Privacy policy and support page are App Store requirements and get planned with the store submission, not here.
- i18n. Prior art says translations matter, but not for v1 of a hand-written page — retrofitting is a rewrite, so revisit only if the page is judged worth generating.
- Newsletter, contact form, comments. Static page, no backend.
- Screenshot gallery. Slot is designed in phase 3 but stays absent until the app restyle produces real captures.

## 9. Risks

| Risk | Mitigation |
|---|---|
| **`og.jpg` is the most-seen asset and currently does not carry the brand.** See §10.1. | Owner decision pending. Nothing downstream is blocked; the meta tag points at whatever file sits at that path. |
| **CSS mockup drifts from the real app.** A visitor downloads and gets something else. | Rebuild the mockup from `design/components.md` measurements, not from imagination. Re-check it when the app restyle lands; swap for real screenshots once they exist. |
| `api.github.com` is the one external request. Unauthenticated limit is 60/hr per IP. | Fetch after paint, no layout shift, reserve the slot with the label only, hide the number silently on any failure. Never block render. |
| Store links promised but not live at launch. | `#` placeholders render as disabled cards with an honest label, not as working buttons that 404. |
| `.dev` HSTS means a cert failure = a fully unreachable site, not a plaintext fallback. | Phase 1 exists precisely to hit this before content work. Verify HTTPS end-to-end before phase 2. |
| Token drift between `design/*.md` and `tokens.css`. | Accepted per ADR 0015. The copy-at-deploy approach at least removes a *third* copy under `web/`. |
| Security copy overclaims. | §3 fixes the exact four allowed statements. Anything beyond needs a source in `docs/knowledge/what-is-croc.md`. |

## 10. For your review

Open items, roughly by cost of getting wrong. Items 2–4 and 6–8 were raised 2026-07-25 and are still unanswered.

1. **`og.jpg` — needs a decision before launch.** This is the single most-viewed brand asset: every share on HN, Reddit, X, Slack, iMessage and Discord renders it, usually before anyone reads a word. Four issues with the supplied file:
   - **Aspect is 1200×797 (1.5:1). The spec is 1200×630 (1.91:1).** Every platform centre-crops it, so roughly 21% off the top and bottom is lost — including part of the illustration.
   - **No wordmark, no headline, no URL.** A share renders as an untitled drawing. The card is doing zero explaining.
   - **Off-palette.** Sky blue and kelly green; croc green is `#1E9E6A`. `design/brand.md`: one accent, no secondary brand hue.
   - **Different crocodile from the mascot.** `assets/mascot.png` is a flat olive-green illustration; this is a blue-background sketch with a bird. Two mascots read as two brands.

   Options: (a) I generate a 1200×630 card from tokens — flat `--color-surface`, mascot, "CrocApp" wordmark, the H1, `crocapp.dev` — matching the page exactly; (b) you re-crop and re-style the existing art to 1.91:1 and add type; (c) ship it as-is and iterate after launch. **(a) is my recommendation.**
2. **Hero H1.** "Send files anywhere. Encrypted end to end." Alternates: *"The file transfer that doesn't care where you are."* / *"Anything, to anyone, anywhere. Encrypted."* / *"Works when AirDrop doesn't."* The last is the sharpest positioning but names a competitor in the H1.
2. **"How it was made" — how loud about AI?** Currently one honest line. It is a real differentiator and also a lightning rod on HN. Options: keep as-is, expand into a real story section, or drop it.
3. **Nav anchor set.** Four fits the glass bar: Features / How it works / Download / GitHub. Thirteen sections, four anchors — confirm which four.
4. **`www` behaviour.** Plan redirects `www` → apex. Confirm you don't want the reverse.
5. **Mascot placement.** `brand.md` allows it on the landing page. Currently footer only. Say if you want it in the hero — it changes the tone from "calm utility" toward "friendly".
6. **Screenshot section.** Ruled out for v1. Confirm you're fine launching with no photographic proof of the app.
7. **Phase 1 needs you.** DNS records and Pages settings are on your registrar and your GitHub account; I can't do those. Everything else I can.
8. **Do you want `web/docs` reserved now?** Costs three lines in the workflow, saves a rewrite later. Plan says yes.
