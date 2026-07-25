/* Everything here is an enhancement. With JavaScript off the page still reads,
   the nav still jumps, the FAQ still opens and the theme still follows the OS.
   Nothing below may become load-bearing. */
(() => {
  "use strict";

  const root = document.documentElement;

  const toggle = document.getElementById("theme-toggle");

  /* No stored value means "follow the OS", hence the media-query fallback. */
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
        /* Storage disabled: the toggle still works, it just is not remembered. */
      }
    });
  }

  /* The page's only third-party request. Unauthenticated api.github.com is
     60/hr per IP, so a failure must leave the slot empty rather than break. */
  const stars = document.getElementById("stars");

  if (stars) {
    fetch("https://api.github.com/repos/bakirgdev/CrocApp", {
      headers: { Accept: "application/vnd.github+json" },
    })
      .then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
      .then((data) => {
        const n = data.stargazers_count;
        /* "GitHub 0" reads as a broken widget. No number is the better state. */
        if (typeof n !== "number" || n < 1) return;
        stars.textContent = n >= 1000 ? (n / 1000).toFixed(1) + "k" : String(n);
        stars.hidden = false;
      })
      .catch(() => {});
  }

  /* Markup ships these hidden so a button never promises what it cannot do. */
  const copyButtons = document.querySelectorAll("[data-copy]");

  if (copyButtons.length && navigator.clipboard) {
    for (const button of copyButtons) {
      const source = document.querySelector(button.dataset.copy);
      if (!source) continue;

      button.hidden = false;

      button.addEventListener("click", () => {
        navigator.clipboard.writeText(source.textContent.trim()).then(
          () => {
            const label = button.querySelector("[data-copy-label]");
            const glyph = button.querySelector("use");
            if (!label || !glyph) return;

            label.textContent = "Copied";
            glyph.setAttribute("href", "#i-check");

            setTimeout(() => {
              label.textContent = "Copy";
              glyph.setAttribute("href", "#i-copy");
            }, 2000);
          },
          () => {}
        );
      });
    }
  }

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

        /* Topmost visible section wins, so scrolling up and down agree. */
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
      /* Top band only: current once the heading nears the nav. */
      { rootMargin: "-20% 0px -70% 0px" }
    );

    for (const section of sections) observer.observe(section);
  }
})();
