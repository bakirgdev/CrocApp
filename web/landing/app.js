/* Everything here is an enhancement. With JavaScript off the page still reads,
   the nav still jumps, the FAQ still opens and the theme still follows the OS. */
(() => {
  "use strict";

  const root = document.documentElement;

  /* The features below are independent, so a throw in one must not take the
     others down with it. Anything that fails leaves its markup as it shipped,
     which is always a working state. */
  const feature = (fn) => {
    try {
      fn();
    } catch (e) {
      console.error(e);
    }
  };

  /* ---- Theme toggle ---- */

  feature(() => {
    const toggle = document.getElementById("theme-toggle");
    if (!toggle) return;

    const osDark = matchMedia("(prefers-color-scheme: dark)");
    const currentTheme = () => root.dataset.theme || (osDark.matches ? "dark" : "light");

    /* The two <meta name="theme-color"> tags carry the values (--bg-base light
       and dark) with a media condition each. A pinned theme has to override the
       OS, so both tags take the pinned theme's value; following the OS restores
       the shipped values and with them the media-based choice. */
    const metaFor = { light: null, dark: null };
    for (const meta of document.querySelectorAll('meta[name="theme-color"]')) {
      const media = meta.getAttribute("media") || "";
      if (media.includes("light")) metaFor.light = meta;
      else if (media.includes("dark")) metaFor.dark = meta;
    }
    const shipped = {
      light: metaFor.light && metaFor.light.getAttribute("content"),
      dark: metaFor.dark && metaFor.dark.getAttribute("content"),
    };

    const syncChrome = () => {
      const pinned = root.dataset.theme;
      for (const key of ["light", "dark"]) {
        if (!metaFor[key]) continue;
        metaFor[key].setAttribute("content", pinned ? shipped[pinned] : shipped[key]);
      }
    };

    const relabel = () =>
      toggle.setAttribute(
        "aria-label",
        currentTheme() === "dark" ? "Switch to light theme" : "Switch to dark theme"
      );

    syncChrome();
    relabel();
    toggle.hidden = false;

    toggle.addEventListener("click", () => {
      const next = currentTheme() === "dark" ? "light" : "dark";
      root.dataset.theme = next;
      syncChrome();
      relabel();
      try {
        localStorage.setItem("theme", next);
      } catch (e) {
        /* Storage disabled: the toggle still works, it just is not remembered. */
      }
    });

    /* Until an explicit choice is made the page follows the OS, so the label has
       to follow it too. */
    osDark.addEventListener("change", relabel);
  });

  /* ---- GitHub star count ----

     The page's only third-party request. Unauthenticated api.github.com allows
     60/hr per IP, and a carrier NAT shares one address between every visitor
     behind it, so the cache is the source and the network is only the refresh:
     a cached value paints before the request goes out, a value under MAX_AGE
     skips the request, and a failure leaves whatever the cache painted. */

  feature(() => {
    const slot = document.getElementById("stars-count");
    const wrap = document.getElementById("stars");
    if (!slot || !wrap) return;

    const KEY = "stars:bakirgdev/CrocApp";
    const MAX_AGE = 6 * 60 * 60 * 1000;
    const TIMEOUT = 6000;

    /* GitHub's own abbreviation, never wider than four characters, which is what
       lets the slot size itself to its contents. Truncated, not rounded: a count
       that reads higher than the repository has is the error worth ruling out. */
    const abbreviate = (n) => {
      if (n < 1000) return String(n);

      const [value, digits, suffix] =
        n < 1e4 ? [n / 1e3, 1, "k"] : n < 1e6 ? [n / 1e3, 0, "k"] : [n / 1e6, 1, "M"];

      const truncated = Math.floor(value * 10 ** digits) / 10 ** digits;
      return (Number.isInteger(truncated) ? String(truncated) : truncated.toFixed(digits)) + suffix;
    };

    /* Zero is shown: hiding it made an empty slot mean both "no stars yet" and
       "the request failed". Only a non-count keeps the slot empty. */
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
        /* Anything else under this key is a tampered or foreign value. */
        if (typeof entry.count !== "number" || typeof entry.at !== "number") return null;
        return entry;
      } catch (e) {
        return null;
      }
    };

    const cached = read();
    if (cached) show(cached.count);
    if (cached && Date.now() - cached.at < MAX_AGE) return;

    /* Without a bound a hung connection leaves a first visit's slot empty for as
       long as the tab is open. */
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
      const href = link.getAttribute("href");
      if (!href.startsWith("#")) continue;
      const section = document.getElementById(href.slice(1));
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
          /* "location", not "true": these are places within one page. */
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
