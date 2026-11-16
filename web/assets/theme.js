/* Light/dark theme. Loaded synchronously in <head> so the stored choice is on <html> before first paint.
   Without a stored choice nothing is set and the CSS follows prefers-color-scheme. The only storage is localStorage
   (no cookies), always inside try/catch because it can be blocked. The toggle button is hidden until this runs. */
(function () {
  var KEY = "theme";
  var root = document.documentElement;
  var media = window.matchMedia ? window.matchMedia("(prefers-color-scheme: dark)") : null;

  function read() {
    try {
      var value = window.localStorage.getItem(KEY);
      return value === "light" || value === "dark" ? value : null;
    } catch (e) {
      return null;
    }
  }
  function write(value) {
    try {
      window.localStorage.setItem(KEY, value);
    } catch (e) { /* storage blocked: the choice still applies to this page */ }
  }
  function apply(value) {
    if (value) root.setAttribute("data-theme", value);
    else root.removeAttribute("data-theme");
  }
  function effective() {
    return root.getAttribute("data-theme") || (media && media.matches ? "dark" : "light");
  }

  apply(read());

  function init() {
    var button = document.querySelector("[data-theme-toggle]");
    if (!button) return;
    function sync() {
      button.setAttribute("aria-pressed", effective() === "dark" ? "true" : "false");
    }
    button.hidden = false;
    sync();
    button.addEventListener("click", function () {
      var next = effective() === "dark" ? "light" : "dark";
      apply(next);
      write(next);
      sync();
    });
    if (media) {
      if (media.addEventListener) media.addEventListener("change", sync);
      else if (media.addListener) media.addListener(sync);
    }
    window.addEventListener("storage", function (event) {
      if (event.key === KEY) { apply(read()); sync(); }
    });
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();
