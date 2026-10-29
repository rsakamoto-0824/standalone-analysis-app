"use strict";

const TOP_BUTTON_SCROLL_THRESHOLD_PX = 480;
const MOBILE_LAYOUT_MAX_WIDTH_PX = 900;
const COPY_SUCCESS_DISPLAY_MS = 1600;
const ACTIVE_SECTION_OFFSET_PX = 120;

const body = document.body;
const sidebar = document.getElementById("sidebar");
const sidebarOverlay = document.getElementById("sidebar-overlay");
const tocToggle = document.getElementById("toc-toggle");
const backToTopButton = document.getElementById("back-to-top");
const tocLinks = Array.from(document.querySelectorAll(".toc-list a"));
const observedSections = Array.from(document.querySelectorAll("main section[id]"));
const copyButtons = Array.from(document.querySelectorAll(".copy-button"));

function isMobileLayout() {
  return window.innerWidth <= MOBILE_LAYOUT_MAX_WIDTH_PX;
}

function setSidebarOpen(isOpen) {
  body.classList.toggle("sidebar-open", isOpen);
  tocToggle.setAttribute("aria-expanded", String(isOpen));
  sidebarOverlay.setAttribute("aria-hidden", String(!isOpen));
}

function closeMobileSidebar() {
  if (isMobileLayout()) {
    setSidebarOpen(false);
  }
}

function updateBackToTopVisibility() {
  backToTopButton.classList.toggle(
    "visible",
    window.scrollY >= TOP_BUTTON_SCROLL_THRESHOLD_PX,
  );
}

function setActiveTocLink(sectionId) {
  tocLinks.forEach((link) => {
    const isActive = link.getAttribute("href") === `#${sectionId}`;
    link.classList.toggle("active", isActive);
    if (isActive) {
      link.setAttribute("aria-current", "location");
    } else {
      link.removeAttribute("aria-current");
    }
  });
}

function updatePageNavigation() {
  updateBackToTopVisibility();
  let currentSection = observedSections[0];
  // 長い章は画面に入る面積の割合が小さいため、章の開始位置で判定する。
  for (const section of observedSections) {
    if (section.getBoundingClientRect().top > ACTIVE_SECTION_OFFSET_PX) break;
    currentSection = section;
  }
  setActiveTocLink(currentSection?.id ?? "overview");
}

function copyTextWithLegacyFallback(text) {
  const temporaryTextArea = document.createElement("textarea");
  temporaryTextArea.value = text;
  temporaryTextArea.setAttribute("readonly", "");
  temporaryTextArea.style.position = "fixed";
  temporaryTextArea.style.opacity = "0";
  document.body.appendChild(temporaryTextArea);
  temporaryTextArea.select();
  const copied = document.execCommand("copy");
  temporaryTextArea.remove();
  return copied;
}

async function copyCode(button) {
  const code = button.closest(".code-block")?.querySelector("code");
  if (!code) {
    return;
  }

  const originalLabel = button.textContent;
  let copied = false;
  try {
    if (navigator.clipboard) {
      await navigator.clipboard.writeText(code.textContent);
      copied = true;
    }
  } catch {
    copied = false;
  }
  if (!copied) {
    copied = copyTextWithLegacyFallback(code.textContent);
  }
  button.textContent = copied
    ? "コピーしました"
    : "コピーできません";

  window.setTimeout(() => {
    button.textContent = originalLabel;
  }, COPY_SUCCESS_DISPLAY_MS);
}

tocToggle.addEventListener("click", () => {
  setSidebarOpen(!body.classList.contains("sidebar-open"));
});

sidebarOverlay.addEventListener("click", () => setSidebarOpen(false));

tocLinks.forEach((link) => {
  link.addEventListener("click", closeMobileSidebar);
});

copyButtons.forEach((button) => {
  button.addEventListener("click", () => copyCode(button));
});

backToTopButton.addEventListener("click", () => {
  window.scrollTo({ top: 0, behavior: "smooth" });
});

window.addEventListener("scroll", updatePageNavigation, { passive: true });
window.addEventListener("load", updatePageNavigation);
window.addEventListener("resize", () => {
  if (!isMobileLayout()) {
    setSidebarOpen(false);
  }
  updatePageNavigation();
});

document.addEventListener("keydown", (event) => {
  if (event.key === "Escape" && body.classList.contains("sidebar-open")) {
    setSidebarOpen(false);
    tocToggle.focus();
  }
});

updatePageNavigation();
