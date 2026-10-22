// Line drawings from Hairline (MIT, vendored at a pinned version). Each one is
// decoration beside text that already says the same thing.
import * as figures from "./vendor/hairline/index.js";

// The library keeps every figure running until destroy(), so a host dropped by a
// re-render must be stopped here: a plain Map, swept on every mount.
const live = new Map();
const touch = matchMedia("(hover: none)");

export function mountArt(host, name, { label, play } = {}) {
  for (const old of live.keys()) if (!old.isConnected && old !== host) unmountArt(old);
  if (live.get(host)?.name === name) return;
  unmountArt(host);
  host.classList.add("art");
  if (label) host.removeAttribute("aria-hidden");
  else host.setAttribute("aria-hidden", "true");
  try {
    live.set(host, { name, figure: figures[name](host, { label, play: play ?? touch.matches, theme: "auto" }) });
  } catch (e) {
    console.error(e);
  }
}

export function unmountArt(host) {
  live.get(host)?.figure.destroy();
  live.delete(host);
}
