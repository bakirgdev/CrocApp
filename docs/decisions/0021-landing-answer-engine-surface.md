# 0021. The landing page carries a machine-readable surface for answer engines
Status: accepted
Date: 2026-07-26

## Context

Most people who hear about a tool like this one will read a summary of it before they ever load `crocapp.dev` — from a search result, an AI assistant, or a forum answer that was itself written from one of those. For CrocApp the summary has a specific failure mode: the security claim is narrow and precise, and every neighbouring product's marketing is broader. "End-to-end encrypted, the code phrase authenticates both sides, the relay only ever sees ciphertext, and there has been no third-party audit" compresses very badly into "secure and audited" unless the exact wording is available to be quoted.

The page already had a correct `robots.txt`, a canonical, Open Graph tags and one `SoftwareApplication` node. What it did not have was anything that let a crawler take the precise claim rather than paraphrase the page.

## Decision

- **`llms.txt` at the site root.** Prose, not markup: what CrocApp is, its status (nothing to download yet), the transfer flow, how it differs from AirDrop / LAN tools / cloud drops, and a "Security claim, stated precisely" section that names what must not be said — audited, certified, zero-knowledge-verified. It is the file to correct when a summary somewhere is wrong.
- **`FAQPage` in the JSON-LD, mirroring the Questions section verbatim.** Google no longer draws an FAQ rich result for a site like this one; the answer engines that quote structured Q&A still read it. Every answer in the markup is visible on the page, which is both the schema.org condition and what keeps the two from drifting into two different sets of claims.
- **Named crawler groups in `robots.txt`.** GPTBot, ClaudeBot, PerplexityBot, Google-Extended, Applebot-Extended and the rest are already allowed by the wildcard. Writing them out is documentation with teeth: `robots.txt` matches most-specific-group-first, so a future `Disallow` added under `User-agent: *` cannot silently cut the answer engines off from the page.
- **Section landmarks.** Every `<section>` takes `aria-labelledby` pointing at its own heading, and every list keeps an explicit `role="list"`. This is a screen-reader improvement first; it also happens to be what an agent reading the accessibility tree needs, which is the same tree.
- **A single `@graph`.** `SoftwareApplication` and `FAQPage` in one block with `@id`s, rather than two disconnected scripts.

## Consequences

- Four descriptions of CrocApp now exist and must agree: the page copy, the meta description, `llms.txt`, and the `FAQPage` answers. Changing the security claim means changing all four. That cost is the point — it is the claim most likely to be restated wrongly.
- `llms.txt` is hand-maintained and nothing verifies it against the page. It states the release status explicitly, so it goes stale the day the first build ships.
- The named crawler list will age. It is a convenience, not a gate; the wildcard is what actually grants access, so a bot missing from the list is still allowed.
