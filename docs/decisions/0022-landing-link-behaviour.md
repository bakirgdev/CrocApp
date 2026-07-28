# 0022. The landing page scrolls smoothly to its own sections and sends every other link to a new tab
Status: accepted
Date: 2026-07-27

## Context

`web/landing/index.html` is one page with a sticky nav and four in-page destinations (`#why`, `#how`, `#features`, `#download`), plus `#top` and `#main` for the brand and the skip link. It also carries twenty links off-site, nearly all of them to the repository.

Two things were wrong with that. A fragment jump put the target's first line under the nav, because the browser scrolls the target to viewport top and the bar is painted over it — so every nav click landed on a heading the visitor could not read. And an off-site link replaced the page, which on a one-page site with no build to download means the visitor's place in it is gone; the two donation buttons already opened in a new tab, so the behaviour was also inconsistent with itself.

## Decision

Both fixes live on the scroll container, in `styles.css` section 2:

- **`scroll-padding-block-start: calc(var(--nav-height-web) + var(--space-5))` on `html`.** Padding on the scroller, not `scroll-margin` on each section: it covers the skip link and any id linked from off the page, and it cannot be forgotten when a section is added. The `--space-5` on top of the bar height is the gap between the two, so the target does not land flush against the hairline.
- **`scroll-behavior: smooth` on `html`**, scoped to the element that actually scrolls so a nested scroller keeps its own instant behaviour. Section 14's `prefers-reduced-motion` block already restores `auto`.

Every link whose `href` is off-origin carries `target="_blank" rel="noopener"`. Same-origin links that point at a real page rather than a section, which today means the docs site at `/docs/` in the nav and the footer, navigate in the current tab and carry no new-tab affordance: the visitor is still on crocapp.dev, so there is no place to lose. Links that are a bare label — the nav's GitHub button, the hero and download and contribute buttons, the footer nav — also carry `<span class="u-visually-hidden">(opens in a new tab)</span>`, matching the two donation buttons that already did. Links inside running prose and card titles do not: the announcement mid-sentence costs more than it tells, and those links read as citations, where leaving the page is the expected outcome anyway.

## Consequences

- The nav offset is tied to `--nav-height-web`. A bar that grows past that token — a second row, a wrapping label — silently under-shoots, and nothing in CI catches it.
- Twenty tabs is what a visitor who clicks everything ends up with. Accepted: none of these links is a step in a flow, so none of them is somewhere the visitor wants to be *instead* of here.
- `rel="noopener"` is redundant on every current browser, which implies it for `target="_blank"`. Kept because it is one attribute and the alternative is an assumption about the floor.
