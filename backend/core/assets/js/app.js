import "phoenix_html";
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  ?.getAttribute("content");

let Hooks = {};

Hooks.ScrollHint = {
  mounted() {
    this.container =
      this.el.querySelector("[data-scroll-container]") || this.el;
    this.hint = this.el.querySelector("[data-scroll-hint]");
    if (!this.container || !this.hint) return;

    this.update = () => {
      const canScroll = this.container.scrollWidth > this.container.clientWidth;
      const scrolled = this.container.scrollLeft > 8;
      this.hint.style.opacity = canScroll && !scrolled ? "1" : "0";
    };

    this.container.addEventListener("scroll", this.update, { passive: true });
    this.update();
  },
  destroyed() {
    if (this.container && this.update) {
      this.container.removeEventListener("scroll", this.update);
    }
  },
};

Hooks.StatsFallback = {
  mounted() {
    this.content = this.el.querySelector("[data-stats-content]");
    this.fallback = this.el.querySelector("[data-stats-fallback]");
    this.img = this.el.querySelector("img");

    if (!this.img || !this.content || !this.fallback) return;

    this.showFallback = () => {
      this.content.classList.add("hidden");
      this.fallback.classList.remove("hidden");
    };

    this.img.addEventListener("error", this.showFallback, { once: true });
  },
  destroyed() {
    if (this.img && this.showFallback) {
      this.img.removeEventListener("error", this.showFallback);
    }
  },
};

Hooks.StackPreview = {
  mounted() {
    this.setup();
  },
  updated() {
    this.setup();
  },
  destroyed() {
    this.teardown();
  },
  setup() {
    this.teardown();

    this.badges = Array.from(this.el.querySelectorAll("[data-stack-slug]"));
    this.preview = this.el.querySelector("[data-stack-preview]");
    this.titleEl = this.el.querySelector("[data-stack-preview-title]");
    this.contextEl = this.el.querySelector("[data-stack-preview-context]");
    this.hintEl = this.el.querySelector("[data-stack-preview-hint]");
    this.hoverCapable = window.matchMedia("(hover: hover)").matches;

    if (
      !this.badges.length ||
      !this.preview ||
      !this.titleEl ||
      !this.contextEl ||
      !this.hintEl
    ) {
      return;
    }

    this.activate = (badge) => {
      this.badges.forEach((node) => {
        node.classList.toggle("fx-stack-badge-active", node === badge);
      });

      this.el.classList.add("fx-stack-card-expanded");
      this.preview.classList.add("fx-stack-shared-preview-open");
      this.titleEl.textContent = badge.dataset.stackTitle || "";
      this.contextEl.textContent = badge.dataset.stackContext || "";
      this.titleEl.classList.remove("hidden");
      this.contextEl.classList.remove("hidden");
      this.hintEl.classList.add("hidden");
    };

    this.clear = () => {
      this.badges.forEach((node) => {
        node.classList.remove("fx-stack-badge-active");
      });

      this.el.classList.remove("fx-stack-card-expanded");
      this.preview.classList.remove("fx-stack-shared-preview-open");
      this.titleEl.textContent = "";
      this.contextEl.textContent = "";
      this.titleEl.classList.add("hidden");
      this.contextEl.classList.add("hidden");
      this.hintEl.classList.remove("hidden");
    };

    this.badgeRemovers = this.badges.map((badge) => {
      const onEnter = () => this.activate(badge);
      const onFocus = () => this.activate(badge);
      const onClick = (event) => {
        event.preventDefault();
        this.activate(badge);
      };

      badge.addEventListener("mouseenter", onEnter);
      badge.addEventListener("focus", onFocus);
      badge.addEventListener("click", onClick);

      return () => {
        badge.removeEventListener("mouseenter", onEnter);
        badge.removeEventListener("focus", onFocus);
        badge.removeEventListener("click", onClick);
      };
    });

    this.onMouseLeave = () => {
      if (this.hoverCapable) {
        this.clear();
      }
    };

    this.onDocumentClick = (event) => {
      if (!this.el.contains(event.target)) {
        this.clear();
      }
    };

    this.el.addEventListener("mouseleave", this.onMouseLeave);
    document.addEventListener("click", this.onDocumentClick);
  },
  teardown() {
    if (this.badgeRemovers) {
      this.badgeRemovers.forEach((remove) => remove());
      this.badgeRemovers = null;
    }

    if (this.onMouseLeave) {
      this.el.removeEventListener("mouseleave", this.onMouseLeave);
      this.onMouseLeave = null;
    }

    if (this.onDocumentClick) {
      document.removeEventListener("click", this.onDocumentClick);
      this.onDocumentClick = null;
    }
  },
};

let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
});

liveSocket.connect();
window.liveSocket = liveSocket;
