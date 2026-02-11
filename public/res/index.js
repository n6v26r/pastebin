const themes = ["mocha", "macchiato", "frappe", "latte"];

const btnContainer = document.getElementById("theme-buttons");
const toggleBtn = document.getElementById("menu-toggle");

var isMenuVisible = false;

updateButtons();

function setTheme(theme) {
  if (!themes.includes(theme)) return;

  localStorage.setItem("theme", theme);
  document.documentElement.setAttribute("data-theme", theme);
  savedTheme = theme;
  updateButtons();
}

function updateButtons() {
  document.querySelectorAll(".theme-btn").forEach(btn => {
    btn.textContent = btn.dataset.theme === savedTheme ? "[x]" : "[ ]";
  });
}

function menuToggle() {
  btnContainer.style.display =
    isMenuVisible ? "none" : "flex";

  isMenuVisible = !isMenuVisible;
}

toggleBtn.addEventListener("click", () => {
  menuToggle();
});

document.querySelectorAll(".theme-btn").forEach(btn => {
  btn.addEventListener("click", () => setTheme(btn.dataset.theme));

  btn.addEventListener("mouseenter", () => {
    if (btn.dataset.theme != savedTheme)
      btn.textContent = "[*]";
  });

  btn.addEventListener("mouseleave", () => {
    updateButtons();
  });
});
