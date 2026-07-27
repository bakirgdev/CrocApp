# 0020. The landing page's star count is cache-first, with the API as the refresh
Status: accepted
Date: 2026-07-26

## Context

`web/landing/app.js` reads the repository's star count from `api.github.com` and writes it into the nav. It is the page's only third-party request and the only thing that sends a visitor's IP off the origin, on a page whose own copy promises "no advertising, and no analytics".

Unauthenticated `api.github.com` allows 60 requests per hour **per IP**, not per visitor. Behind an office egress or a carrier NAT, one shared address serves every visitor behind it, so the budget can be spent by strangers and the count then disappears for all of them at once. The original code fetched on every load and, on any failure, left the slot empty — correct, but it made the common failure the common outcome for exactly the audiences most likely to share an IP.

## Decision

`localStorage`, keyed `stars:bakirgdev/CrocApp`, holding `{ count, at }`.

- **The cache paints before the request goes out.** A repeat visit never waits on the network.
- **The slot is exactly as wide as its number, and absent when it has none.** A reserved floor was tried first and removed: at 28px it was wider than "0" and wider than any two-digit count, so on the counts the repository actually has it read as a gap inside the button rather than as space held for something. What it bought was a bar that could not shift when a number arrived late, and the formatter below caps that shift at four characters on the one load that has to go to the network. The empty slot is `display: none`, which also keeps it out of the accessibility tree.
- **Under 6 hours old, no request is made at all.** A star count is not information that decays in minutes.
- **A failed, aborted or rate-limited fetch leaves whatever the cache painted standing, however old.** A count that is days stale is not wrong in a way any visitor can act on; an empty slot is.
- **A first visit with no cache and no network shows nothing.** The slot stays empty rather than showing a bracket with nothing in it — the one case that cannot do better, and now the only case that leaves the slot empty.
- **The stored value is validated on read.** Anything under that key that is not two numbers is treated as no cache at all, and a `localStorage` that throws is caught, because storage is an enhancement here and never load-bearing.
- **The request is bounded by an `AbortController` at 6 s**, so a hung connection cannot hold a first-time visitor's slot empty for the life of the tab.

**`0` is rendered.** Hiding it was the earlier rule, on the reasoning that "GitHub 0" reads as a broken widget. It made the empty slot mean two unrelated things — no stars yet, and the request failed — and while the repository sat at zero the live page was indistinguishable from one whose fetch was broken, which is how the count came to be missing on crocapp.dev. Only a value that is not a count at all now leaves the slot empty.

**The count is abbreviated the way GitHub's own counters abbreviate it**, which also bounds the string at four characters and so bounds the slot: exact below 1000, one decimal to 9999 (`1.2k`), whole thousands to 999999 (`12k`, `104k`), one decimal above that (`1.2M`). Truncated rather than rounded, so 1999 reads `1.9k` — a count that reads higher than the repository has is the one error worth ruling out. A trailing `.0` is dropped, so a round thousand is `1k`.

## Rejected

- **Baking the count in at deploy.** Strictly better on every axis except one: zero client requests, zero rate-limit exposure, zero layout shift, and it survives JavaScript being off. Rejected only because the number would then be as stale as the last push to `web/`, which on a quiet week is staler than six hours. Worth revisiting if the page ever stops being the thing that changes most often.
- **A shields.io badge.** No JavaScript, but it moves the third-party request from one visitor in six hours to every visitor on every load, and hands a third party the same IP the fetch was meant to economise.
- **Dropping the count.** Defensible — it would make the page fully self-contained. Kept because it is the only social proof on a page for a product that has nothing to download yet.

## Consequences

- A visitor sees a number up to 6 hours behind, and after an outage possibly much further behind, with nothing on the page saying so. Accepted: the alternative is showing nothing.
- The privacy story improves as a side effect. A returning visitor hits GitHub at most once per 6 hours instead of once per page load. It does not go to zero: an uncached visitor's IP still reaches GitHub on a page whose own FAQ says "no advertising, and no analytics". Baking the count in at deploy is the only option that closes that gap entirely.
- One `localStorage` key is now written by the page beyond `theme`. Neither is personal data and neither is read by anything else.
- A first, uncached load can widen the nav's right cluster by up to four characters when the number lands. Bounded and one-time; every later load paints from cache before the request goes out.
- `--stars-slot-min` is gone from `design/tokens.css` and `design/spacing-layout.md`. Nothing else referenced it.
