// Regenerate tokens.json from a running Teams.
//
//   teams-for-linux --remote-debugging-port=9333 --remote-debugging-address=127.0.0.1
//   node capture-tokens.mjs > tokens.json
//
// (From inside another Electron app, unset ELECTRON_RUN_AS_NODE first, or
// teams-for-linux starts as plain node and dies on require("electron").)
//
// Teams defines its colours as custom properties on the FluentProvider:
// Fluent UI 9's tokens plus its own (colorNeutralBackground7,
// colorDefaultBackground*, --theme*). This reads every one that holds a
// colour and assigns it a base16 slot, so default.nix can render them in
// whatever stylix scheme is active. Greys map by lightness, Teams' brand
// purples to the accent; status hues (red, green, yellow, ...) are left to
// Teams because they carry meaning. Capture it with the stylesheet
// disabled, or overridden tokens read back as stylix colours.
const targets = await (await fetch("http://127.0.0.1:9333/json")).json();
const page = targets.find((t) => t.type === "page" && t.url.startsWith("https://teams"));
const ws = new WebSocket(page.webSocketDebuggerUrl);
await new Promise((r) => (ws.onopen = r));
const result = new Promise((r) => (ws.onmessage = (e) => r(JSON.parse(e.data))));
ws.send(JSON.stringify({
  id: 1,
  method: "Runtime.evaluate",
  params: {
    returnByValue: true,
    expression: `(() => {
      const names = new Set();
      const walk = (list) => { for (const r of list) { if (r.cssRules) walk(r.cssRules); if (r.style) for (let i = 0; i < r.style.length; i++) if (r.style[i].startsWith("--")) names.add(r.style[i]); } };
      for (const s of document.styleSheets) { try { walk(s.cssRules); } catch {} }
      const cs = getComputedStyle(document.querySelector(".fui-FluentProvider") || document.documentElement);
      const root = getComputedStyle(document.documentElement);
      const out = {};
      for (const n of names) out[n] = cs.getPropertyValue(n).trim() || root.getPropertyValue(n).trim();
      return JSON.stringify(out);
    })()`,
  },
}));
const vals = JSON.parse((await result).result.result.value);
ws.close();

const parse = (v) => {
  let m = v.match(/^#([0-9a-f]{6})([0-9a-f]{2})?$/i);
  if (m) return { r: parseInt(m[1].slice(0, 2), 16), g: parseInt(m[1].slice(2, 4), 16), b: parseInt(m[1].slice(4, 6), 16), a: m[2] ? parseInt(m[2], 16) / 255 : 1 };
  m = v.match(/^#([0-9a-f]{3})$/i);
  if (m) return { r: parseInt(m[1][0].repeat(2), 16), g: parseInt(m[1][1].repeat(2), 16), b: parseInt(m[1][2].repeat(2), 16), a: 1 };
  m = v.match(/^rgba?\(\s*([\d.]+)[,\s]+([\d.]+)[,\s]+([\d.]+)(?:[,\s/]+([\d.]+))?\s*\)$/i);
  if (m) return { r: +m[1], g: +m[2], b: +m[3], a: m[4] === undefined ? 1 : +m[4] };
  return null;
};
const hsl = ({ r, g, b }) => {
  const [R, G, B] = [r, g, b].map((x) => x / 255);
  const max = Math.max(R, G, B), min = Math.min(R, G, B), l = (max + min) / 2, d = max - min;
  const s = d === 0 ? 0 : d / (1 - Math.abs(2 * l - 1));
  let h = 0;
  if (d) h = max === R ? ((G - B) / d) % 6 : max === G ? (B - R) / d + 2 : (R - G) / d + 4;
  return { h: (h * 60 + 360) % 360, s, l };
};
// Dark-theme grey ramp onto base16. Teams' greys run #0a0a0a..#ffffff.
// Its canvas (#0a0a0a..#1f1f1f) goes to base00 and the message pane
// (#292929, #2e2e2e) to base01, so the large areas stay on the darkest
// two slots; raised surfaces go to base02, dividers and disabled text to
// base03. Cutting by plain lightness put #292929 on base02, which is too
// light for the biggest area on screen.
const grey = (l) => l < 0.13 ? "base00" : l < 0.19 ? "base01" : l < 0.3 ? "base02" : l < 0.45 ? "base03" : l < 0.65 ? "base04" : "base05";

const out = {};
for (const [name, value] of Object.entries(vals).sort()) {
  if (!/^--(color|theme)/.test(name)) continue;
  const c = parse(value);
  if (!c) continue;
  const { h, s, l } = hsl(c);
  let slot = null;
  if (c.a === 0) continue; // transparent stays transparent
  if (s < 0.12 || l > 0.97 || l < 0.03) slot = c.a < 1 && l > 0.5 ? "base05" : grey(l);
  else if (h >= 225 && h <= 265) slot = l < 0.3 ? "base02" : "base0D"; // Teams brand purple
  if (!slot) continue;
  out[name] = c.a < 1 ? { slot, alpha: Math.round(c.a * 1000) / 1000 } : slot;
}
console.log(JSON.stringify(out, null, 2));
