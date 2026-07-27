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
         what an empty slot has always meant here.

     The slot's width is reserved in CSS either way, so none of these paths can
     resize the nav after first paint. */

  feature(() => {
    const slot = document.getElementById("stars-count");
    const wrap = document.getElementById("stars");
    if (!slot || !wrap) return;

    const KEY = "stars:bakirgdev/CrocApp";
    const MAX_AGE = 6 * 60 * 60 * 1000;
    const TIMEOUT = 6000;

    /* "GitHub 0" reads as a broken widget. No number is the better state. */
    const show = (n) => {
      if (n < 1) return;
      slot.textContent = n >= 1000 ? (n / 1000).toFixed(1) + "k" : String(n);
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

  /* ---- Copy buttons ---- */

  feature(() => {
    /* Markup ships these hidden so a button never promises what it cannot do. */
    if (!navigator.clipboard) return;

    for (const button of document.querySelectorAll("[data-copy]")) {
      let source;
      try {
        source = document.querySelector(button.dataset.copy);
      } catch (e) {
        /* A malformed selector is an authoring mistake in one button, not a
           reason to leave the rest of them hidden. */
        continue;
      }

      const label = button.querySelector("[data-copy-label]");
      const glyph = button.querySelector("use");
      if (!source || !label || !glyph) continue;

      button.hidden = false;

      let reset;

      button.addEventListener("click", () => {
        navigator.clipboard.writeText(source.textContent.trim()).then(() => {
          label.textContent = "Copied";
          glyph.setAttribute("href", "#i-check");

          /* Without the clear, a second click inherits the first click's
             timer and the label snaps back almost immediately. */
          clearTimeout(reset);
          reset = setTimeout(() => {
            label.textContent = "Copy";
            glyph.setAttribute("href", "#i-copy");
          }, 2000);
        }, () => {});
      });
    }
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
