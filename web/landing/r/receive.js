(function () {
  function readCode() {
    try {
      return decodeURIComponent(location.hash.slice(1));
    } catch (e) {
      /* A malformed escape in the fragment: treat it as no code. */
      return "";
    }
  }

  function render() {
    var code = readCode();
    // croc rejects shorter codes (crocmobile minCodeLength); a stray
    // fragment such as "#top" must not read as one.
    var valid = code.length >= 6 && !/\s/.test(code);
    document.getElementById("has-code").hidden = !valid;
    document.getElementById("no-code").hidden = valid;
    if (!valid) return;
    var encoded = encodeURIComponent(code);
    document.getElementById("code").textContent = code;
    document.getElementById("open-app").href = "crocapp://receive?code=" + encoded;
    document.getElementById("open-browser").href = "https://getcroc.com/?code=" + encoded;
  }

  render();
  addEventListener("hashchange", render);
})();
