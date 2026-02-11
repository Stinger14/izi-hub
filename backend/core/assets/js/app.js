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

let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
});

liveSocket.connect();
window.liveSocket = liveSocket;
