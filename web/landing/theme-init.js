/* Loaded synchronously in <head>, before the stylesheet paints, so a stored
   preference cannot flash. Only the two valid values pin a theme; anything else
   follows the OS. A script file, not inline, so the CSP needs no hash. */
try {
  var theme = localStorage.getItem("theme");
  if (theme === "light" || theme === "dark") document.documentElement.dataset.theme = theme;
} catch (e) {
  /* Storage blocked: the page follows the OS, which is the default. */
}
