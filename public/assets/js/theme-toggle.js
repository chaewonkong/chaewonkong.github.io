(() => {
  // <stdin>
  var themeToggleBtn = document.getElementById("theme-toggle-btn");
  var currentTheme = document.documentElement.getAttribute("data-theme");
  themeToggleBtn.textContent = currentTheme === "dark" ? " \u2600\uFE0F" : "\u{1F319}";
  themeToggleBtn.addEventListener("click", () => {
    const isDark = document.documentElement.getAttribute("data-theme") === "dark";
    if (isDark) {
      document.documentElement.setAttribute("data-theme", "light");
      themeToggleBtn.textContent = "\u{1F319}";
      localStorage.setItem("theme", "light");
    } else {
      document.documentElement.setAttribute("data-theme", "dark");
      themeToggleBtn.textContent = " \u2600\uFE0F";
      localStorage.setItem("theme", "dark");
    }
  });
})();
