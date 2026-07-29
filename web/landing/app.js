/* Everything here is an enhancement. With JavaScript off the page still reads,
   the nav still jumps, the FAQ still opens and the theme still follows the OS.
   Nothing below may become load-bearing. */
(() => {
  "use strict";

  const root = document.documentElement;

  /* The four features below are independent, so a throw in one must not take
     the other three down with it. Anything that fails leaves its markup in the
     state it shipped in, which is always a working state. */
  const feature = (fn) => {
    try {
      fn();
    } catch (e) {
      /* Nothing to report to: the page has no error surface by design. */
    }
  };

  /* ---- Theme toggle ---- */

  feature(() => {
    const toggle = document.getElementById("theme-toggle");
    if (!toggle) return;

    const osDark = matchMedia("(prefers-color-scheme: dark)");

    /* No stored value means "follow the OS", hence the media-query fallback. */
    const currentTheme = () => root.dataset.theme || (osDark.matches ? "dark" : "light");

    const relabel = () =>
      toggle.setAttribute(
        "aria-label",
        currentTheme() === "dark" ? "Switch to light theme" : "Switch to dark theme"
      );

    relabel();
    toggle.hidden = false;

    toggle.addEventListener("click", () => {
      const next = currentTheme() === "dark" ? "light" : "dark";
      root.dataset.theme = next;
      relabel();
      try {
        localStorage.setItem("theme", next);
      } catch (e) {
        /* Storage disabled: the toggle still works, it just is not remembered. */
      }
    });

    /* While no explicit choice has been made the page follows the OS, so the
       label has to follow it too — otherwise a machine that flips at sunset
       leaves the button describing the theme it is already in. */
    osDark.addEventListener("change", relabel);
  });

  /* ---- GitHub star count ----

     The page's only third-party request, and the only one that sends a
     visitor's IP anywhere. Unauthenticated api.github.com allows 60/hr per IP,
     which sounds ample until an office or a carrier NAT shares one address
     between every visitor behind it — then the count vanishes for all of them
     at once. So the cache is the source and the network is the refresh:

       - a cached value paints before the request goes out, so a repeat visit
         never waits on the network and the nav does not resize late;
       - a value under 6 hours old skips the request entirely;
       - a failed or rate-limited fetch leaves whatever the cache painted
         standing, however old, because a star count that is a few days stale
         is never wrong in a way that matters;
       - a first visit with no cache and no network shows nothing, which is
         now the only thing an empty slot means.

     The slot sizes itself to its number rather than to a reserved floor, so
     the only load that can move the nav is the one that had no cache to paint
     from, and the formatter below bounds that move at four characters. */

  feature(() => {
    const slot = document.getElementById("stars-count");
    const wrap = document.getElementById("stars");
    if (!slot || !wrap) return;

    const KEY = "stars:bakirgdev/CrocApp";
    const MAX_AGE = 6 * 60 * 60 * 1000;
    const TIMEOUT = 6000;

    /* The abbreviation GitHub's own counters use. Never wider than four
       characters, which is what lets the slot size itself to its contents:

         0 .. 999        exact           0, 7, 942
         1e3 .. 9999     one decimal     1.2k, 9.9k
         1e4 .. 999999   whole           12k, 104k
         1e6 and up      one decimal     1.2M

       Truncated, not rounded: 1999 is not 2k yet, and a count that reads
       higher than the repository has is the one error worth ruling out.
       A trailing ".0" is dropped, so a round thousand reads "1k". */
    const abbreviate = (n) => {
      if (n < 1000) return String(n);

      const [value, digits, suffix] =
        n < 1e4 ? [n / 1e3, 1, "k"] : n < 1e6 ? [n / 1e3, 0, "k"] : [n / 1e6, 1, "M"];

      const truncated = Math.floor(value * 10 ** digits) / 10 ** digits;
      return (Number.isInteger(truncated) ? String(truncated) : truncated.toFixed(digits)) + suffix;
    };

    /* Zero is shown. Hiding it made an empty slot mean two different things —
       "no stars yet" and "the request failed" — and the repo sitting at zero
       was indistinguishable from a broken widget for as long as that lasted.
       Only a value that is not a count at all keeps the slot empty. */
    const show = (n) => {
      if (!Number.isFinite(n) || n < 0) return;
      slot.textContent = abbreviate(Math.floor(n));
      wrap.classList.remove("is-empty");
    };

    const read = () => {
      try {
        const raw = localStorage.getItem(KEY);
        if (!raw) return null;
        const entry = JSON.parse(raw);
        /* Anything else under our key is another origin's leftovers or a
           tampered value, and is treated as no cache at all. */
        if (typeof entry.count !== "number" || typeof entry.at !== "number") return null;
        return entry;
      } catch (e) {
        return null;
      }
    };

    const cached = read();
    if (cached) show(cached.count);
    if (cached && Date.now() - cached.at < MAX_AGE) return;

    /* Without a bound a hung connection leaves a first-time visitor's slot
       empty for as long as the tab is open. */
    const abort = new AbortController();
    const timer = setTimeout(() => abort.abort(), TIMEOUT);

    fetch("https://api.github.com/repos/bakirgdev/CrocApp", {
      headers: { Accept: "application/vnd.github+json" },
      signal: abort.signal,
    })
      .then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
      .then((data) => {
        const n = data.stargazers_count;
        if (typeof n !== "number") return;
        try {
          localStorage.setItem(KEY, JSON.stringify({ count: n, at: Date.now() }));
        } catch (e) {
          /* Storage disabled: every load refetches, which still works. */
        }
        show(n);
      })
      .catch(() => {})
      .finally(() => clearTimeout(timer));
  });

  /* ---- Current section in the nav ---- */

  feature(() => {
    if (!("IntersectionObserver" in window)) return;

    const linkFor = new Map();
    const sections = [];

    for (const link of document.querySelectorAll(".nav__link")) {
      const section = document.getElementById(link.getAttribute("href").slice(1));
      if (!section) continue;
      linkFor.set(section, link);
      sections.push(section);
    }

    if (!sections.length) return;

    const visible = new Set();

    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting) visible.add(entry.target);
          else visible.delete(entry.target);
        }

        /* Topmost visible section wins, so scrolling up and down agree. */
        const active = sections.find((section) => visible.has(section));

        for (const [section, link] of linkFor) {
          /* "location", not "true": these are places within one page, which
             is exactly what the location token is for. */
          if (section === active) link.setAttribute("aria-current", "location");
          else link.removeAttribute("aria-current");
        }
      },
      /* Top band only: current once the heading nears the nav. */
      { rootMargin: "-20% 0px -70% 0px" }
    );

    for (const section of sections) observer.observe(section);
  });
})();
