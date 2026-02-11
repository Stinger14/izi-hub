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

let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
});

liveSocket.connect();
window.liveSocket = liveSocket;
