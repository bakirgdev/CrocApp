/*
 * CrocApp landing page. No dependencies, no build step, no analytics.
 *
 * Everything here is an enhancement. With JavaScript off the page still
 * reads, the nav still jumps, the FAQ still opens and the theme still
 * follows the OS — only the toggle, the star count and the copy buttons
 * are lost. Nothing below may become load-bearing.
 */
(() => {
  "use strict";

  const root = document.documentElement;

  /* --- Theme -------------------------------------------------------------
   * The inline script in <head> has already applied any stored preference
   * before first paint; this only handles the toggle itself. No stored value
   * means "follow the OS", which is why the initial read falls back to the
   * media query rather than assuming light.
   */
  const toggle = document.getElementById("theme-toggle");

  const currentTheme = () =>
    root.dataset.theme ||
    (matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light");

  const labelFor = (theme) =>
    theme === "dark" ? "Switch to light theme" : "Switch to dark theme";

  if (toggle) {
    toggle.setAttribute("aria-label", labelFor(currentTheme()));

    toggle.addEventListener("click", () => {
      const next = currentTheme() === "dark" ? "light" : "dark";
      root.dataset.theme = next;
      toggle.setAttribute("aria-label", labelFor(next));
      try {
        localStorage.setItem("theme", next);
      } catch (e) {
        /* Private mode or storage disabled: the toggle still works for this
           page view, it just will not be remembered. Not worth surfacing. */
      }
    });
  }

  /* --- Star count --------------------------------------------------------
   * The page's only third-party request. Unauthenticated api.github.com is
   * 60/hr per IP, so this must never be required for anything: the slot is
   * empty until a number arrives, and any failure leaves it empty rather
   * than showing a zero, a dash or an error.
   */
  const stars = document.getElementById("stars");

  if (stars) {
    fetch("https://api.github.com/repos/bakirgdev/CrocApp", {
      headers: { Accept: "application/vnd.github+json" },
    })
      .then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
      .then((data) => {
        const n = data.stargazers_count;
        // A zero is truthful and useless: "GitHub 0" reads as a broken widget,
        // and the slot exists to show traction. No number is the better state.
        if (typeof n !== "number" || n < 1) return;
        stars.textContent = n >= 1000 ? (n / 1000).toFixed(1) + "k" : String(n);
        stars.hidden = false;
      })
      .catch(() => {
        /* Rate limited, offline, or blocked. Silence is the correct outcome. */
      });
  }

  /* --- Nav active state --------------------------------------------------
   * Marks the anchor whose section is currently on screen. Guarded because
   * a browser without IntersectionObserver should lose the highlight, not
   * the nav.
   */
  const links = Array.from(document.querySelectorAll(".nav__link"));

  if (links.length && "IntersectionObserver" in window) {
    const byId = new Map();
    const sections = [];

    for (const link of links) {
      const id = link.getAttribute("href").slice(1);
      const section = document.getElementById(id);
      if (!section) continue;
      byId.set(section, link);
      sections.push(section);
    }

    const visible = new Set();

    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting) visible.add(entry.target);
          else visible.delete(entry.target);
        }

        // Topmost visible section wins, so scrolling up and down agree.
        let active = null;
        for (const section of sections) {
          if (visible.has(section)) {
            active = section;
            break;
          }
        }

        for (const [section, link] of byId) {
          if (section === active) link.setAttribute("aria-current", "true");
          else link.removeAttribute("aria-current");
        }
      },
      // Top band only: a section counts as "current" once its heading is
      // near the nav, not when its last pixel scrolls into view.
      { rootMargin: "-20% 0px -70% 0px" }
    );

    for (const section of sections) observer.observe(section);
  }
})();
