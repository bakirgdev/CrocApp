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

    /* A <picture> source cannot read [data-theme], so a pinned theme rewrites
       each source's media condition: "all" always matches (dark pinned), "not
       all" never does (light pinned). Unpinned, the shipped prefers-color-scheme
       condition comes back and the OS decides. A pin that disagrees with the OS
       downloads the OS variant first; that is the only double fetch. */
    const sources = [...document.querySelectorAll("source[data-theme-source]")];
    for (const source of sources) source.dataset.media = source.getAttribute("media");

    const syncPictures = () => {
      const pinned = root.dataset.theme;
      for (const source of sources) {
        source.setAttribute("media", pinned ? (pinned === "dark" ? "all" : "not all") : source.dataset.media);
      }
    };

    syncChrome();
    syncPictures();
    relabel();
    toggle.hidden = false;

    toggle.addEventListener("click", () => {
      const next = currentTheme() === "dark" ? "light" : "dark";
      root.dataset.theme = next;
      syncChrome();
      syncPictures();
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
})();
