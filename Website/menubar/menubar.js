/* ============================================================================
   macOS-style menubar for the Arrowslit landing page (no third-party notch).

   Apple / app / status menus with hover-switching and keyboard navigation,
   a language menu that re-renders the bar in 8 locales, and a working
   Control Center whose Dark Mode tile drives this page's theme.
   ========================================================================== */

import { SITE } from "./site-strings.js?v=0.12.10";
import { shellText } from "./shell-strings.js?v=0.12.10";

const REF_W = 1440;
const SVG_NS = "http://www.w3.org/2000/svg";const LANGUAGES = [
  { code: "en-US", name: "English (US)", short: "EN", locale: "en_US", flag: "🇺🇸" },
  { code: "pt-BR", name: "Português (Brasil)", short: "PT", locale: "pt_BR", flag: "🇧🇷" },
  { code: "es", name: "Español", short: "ES", locale: "es_ES", flag: "🇪🇸" },
  { code: "de", name: "Deutsch", short: "DE", locale: "de_DE", flag: "🇩🇪" },
  { code: "fr", name: "Français", short: "FR", locale: "fr_FR", flag: "🇫🇷" },
  { code: "it", name: "Italiano", short: "IT", locale: "it_IT", flag: "🇮🇹" },
  { code: "ja", name: "日本語", short: "JA", locale: "ja_JP", flag: "🇯🇵" },
  { code: "zh-Hans", name: "简体中文", short: "中文", locale: "zh_CN", flag: "🇨🇳" },
];

let LANG = "en-US";
let L = null;                              // app strings (S.*) for menus
const T = () => SITE[LANG] || SITE["en-US"];
const S = () => (L && L.S) || {};
const isDark = () => document.documentElement.dataset.mode !== "light";

let keepAwake = { active: false, timer: null };
const ccToggles = { wifi: true, bluetooth: true, airdrop: true, focus: false };
const levels = { brightness: 0.72, volume: 0.65 };

let host = null, root = null, bar = null, left = null, statusArea = null;
let langButton = null, clockButton = null, ccButton = null;
let activeMenuButton = null;

/* ------------------------------------------------------------- dom helper */
function h(spec, props = null, ...children) {
  if (props != null && (typeof props !== "object" || props.nodeType)) { children.unshift(props); props = null; }
  const [tag, ...cls] = spec.split(".");
  const el = tag === "svg" ? document.createElementNS(SVG_NS, tag) : document.createElement(tag);
  if (cls.length) el.classList.add(...cls);
  if (props) for (const [k, v] of Object.entries(props)) {
    if (v == null) continue;
    if (k === "on") { for (const [ev, fn] of Object.entries(v)) el.addEventListener(ev, fn); }
    else if (k === "style" && typeof v === "object") for (const [pk, pv] of Object.entries(v)) { if (pk.startsWith("--")) el.style.setProperty(pk, pv); else el.style[pk] = pv; }
    else if (k === "class") { const list = (Array.isArray(v) ? v : [v]).filter(Boolean); if (list.length) el.classList.add(...list); }
    else el.setAttribute(k, v);
  }
  for (const child of children.flat(Infinity)) {
    if (child == null || child === false) continue;
    el.append(child.nodeType ? child : document.createTextNode(child));
  }
  return el;
}

/* ------------------------------------------------------------ SF Symbols */
let SYMBOLS = null;
const sfPending = new Set();
async function loadSymbols() {
  try { SYMBOLS = await (await fetch(new URL("./symbols.json?v=0.12.10", import.meta.url))).json(); }
  catch { SYMBOLS = {}; }
  for (const svg of sfPending) paintSym(svg);
  sfPending.clear();
}
function paintSym(svg) {
  const e = SYMBOLS[svg.dataset.sf];
  if (!e) return;
  const [w, ht, shift, d] = e;
  svg.setAttribute("viewBox", `0 0 ${w} ${ht}`);
  svg.style.setProperty("--sf-w", w / 20 + "em");
  svg.style.setProperty("--sf-h", ht / 20 + "em");
  svg.style.setProperty("--sf-b", -shift / 20 + "em");
  const path = document.createElementNS(SVG_NS, "path");
  path.setAttribute("d", d);
  svg.replaceChildren(path);
}
function sf(name, options = {}) {
  const { size, weight } = options;
  const svg = document.createElementNS(SVG_NS, "svg");
  svg.setAttribute("class", ["sf", weight && weight !== "regular" ? "sf-" + weight : null, options.class].filter(Boolean).join(" "));
  svg.dataset.sf = name;
  if (size) svg.style.fontSize = typeof size === "number" ? size + "px" : size;
  svg.setAttribute("aria-hidden", "true");
  if (SYMBOLS) paintSym(svg); else sfPending.add(svg);
  return svg;
}
function setSymbol(svg, name) {
  if (!svg || svg.dataset.sf === name) return;
  svg.dataset.sf = name;
  if (SYMBOLS) paintSym(svg);
}

/* ------------------------------------- menu engine (port of menus.js) ---- */
let currentMenu = null;
const isMenuOpen = () => !!currentMenu;
function closeMenus() {
  if (!currentMenu) return;
  const menu = currentMenu;
  currentMenu = null;
  menu.close();
}
function openMenu(anchor, items, options = {}) {
  closeMenus();
  const menu = new Menu(items, options);
  currentMenu = menu;
  menu.show(anchor);
  return menu;
}
class Menu {
  constructor(items, options, parent = null) {
    this.items = items;
    this.options = options;
    this.parent = parent;
    this.child = null;
    this.active = -1;
    this.rows = [];
    this.el = h("div.menu", { role: "menu", class: options.className, style: { minWidth: options.minWidth ? options.minWidth + "px" : null } });
    this.build();
    this.onKey = this.onKey.bind(this);
    this.onDown = this.onDown.bind(this);
  }
  build() {
    for (const item of this.items) {
      if (!item) continue;
      if (item.separator) { this.el.append(h("div.menu-sep", { role: "separator" })); continue; }
      if (item.header) { this.el.append(h("div.menu-header", item.header)); continue; }
      const row = h("div.menu-item", {
        role: item.checked !== undefined ? "menuitemcheckbox" : "menuitem",
        "aria-checked": item.checked !== undefined ? String(!!item.checked) : null,
        "aria-disabled": item.disabled ? "true" : null,
        class: [item.disabled && "is-disabled", item.danger && "is-danger", item.submenu && "has-submenu"],
      },
      h("span.menu-check", item.checked ? sf("checkmark", { size: 11, weight: "bold" }) : null),
      item.icon ? h("span.menu-icon", typeof item.icon === "string" ? sf(item.icon, { size: 13 }) : item.icon) : null,
      h("span.menu-label", item.label),
      item.shortcut ? h("span.menu-shortcut", item.shortcut) : null,
      item.submenu ? h("span.menu-arrow", sf("chevron.right", { size: 10, weight: "semibold" })) : null);
      const index = this.rows.length;
      row.addEventListener("pointerenter", () => this.setActive(index, true));
      row.addEventListener("pointerup", event => { event.stopPropagation(); this.choose(index); });
      row.addEventListener("click", event => event.stopPropagation());
      this.rows.push({ row, item });
      this.el.append(row);
    }
  }
  show(anchor) {
    this.options.overlay.append(this.el);
    const rect = anchor instanceof Element ? anchor.getBoundingClientRect() : { left: anchor.x, right: anchor.x, top: anchor.y, bottom: anchor.y, width: 0, height: 0 };
    const width = Math.max(this.el.offsetWidth, this.options.align === "selected" ? rect.width + 18 : 0);
    if (this.options.align === "selected") this.el.style.minWidth = width + "px";
    const height = this.el.offsetHeight;
    let x, y;
    if (this.parent) {
      x = rect.right - 4;
      y = rect.top - 5;
      if (x + width > innerWidth - 6) x = rect.left - width + 4;
    } else if (this.options.align === "end") {
      x = rect.right - width;
      y = rect.bottom + (this.options.gap ?? 4);
    } else {
      x = rect.left;
      y = rect.bottom + (this.options.gap ?? 4);
    }
    x = Math.min(Math.max(x, 6), innerWidth - width - 6);
    y = Math.min(Math.max(y, 6), Math.max(6, innerHeight - height - 6));
    this.el.style.left = Math.round(x) + "px";
    this.el.style.top = Math.round(y) + "px";
    this.el.classList.add("is-open");
    if (!this.parent) {
      document.addEventListener("keydown", this.onKey, true);
      setTimeout(() => document.addEventListener("pointerdown", this.onDown, true));
    }
  }
  setActive(index, fromPointer) {
    if (this.active === index) return;
    this.rows[this.active]?.row.classList.remove("is-active");
    this.active = index;
    const entry = this.rows[index];
    if (!entry) return;
    if (!entry.item.disabled) entry.row.classList.add("is-active");
    if (this.child && this.child.anchorIndex !== index) { this.child.close(); this.child = null; }
    if (entry.item.submenu && !entry.item.disabled && !this.child) {
      clearTimeout(this.submenuTimer);
      this.submenuTimer = setTimeout(() => this.openSubmenu(index), fromPointer ? 140 : 0);
    }
  }
  openSubmenu(index) {
    if (this.active !== index || this.child) return;
    const entry = this.rows[index];
    this.child = new Menu(entry.item.submenu, this.options, this);
    this.child.anchorIndex = index;
    this.child.show(entry.row);
  }
  choose(index) {
    const entry = this.rows[index];
    if (!entry || entry.item.disabled) return;
    if (entry.item.submenu) { this.openSubmenu(index); return; }
    const rootMenu = this.root();
    if (rootMenu.chosen) return;
    rootMenu.chosen = true;
    entry.row.classList.remove("is-active");
    setTimeout(() => entry.row.classList.add("is-active"), 60);
    setTimeout(() => {
      if (currentMenu === rootMenu) closeMenus(); else rootMenu.close();
      entry.item.action?.(entry.item);
    }, 120);
  }
  root() { let menu = this; while (menu.parent) menu = menu.parent; return menu; }
  onDown(event) {
    let menu = this;
    while (menu) {
      if (event.composedPath().includes(menu.el)) return;
      menu = menu.child;
    }
    if (this.options.ignore && this.options.ignore.some(el => el && event.composedPath().includes(el))) return;
    closeMenus();
  }
  onKey(event) {
    let menu = this;
    while (menu.child) menu = menu.child;
    const enabled = menu.rows.map((r, i) => (r.item.disabled ? -1 : i)).filter(i => i >= 0);
    switch (event.key) {
      case "Escape":
        event.preventDefault(); event.stopPropagation();
        if (menu.parent) { menu.parent.child = null; menu.close(); } else closeMenus();
        break;
      case "ArrowDown": case "ArrowUp": {
        event.preventDefault();
        if (!enabled.length) break;
        const pos = enabled.indexOf(menu.active);
        const next = event.key === "ArrowDown" ? enabled[(pos + 1) % enabled.length] : enabled[(pos - 1 + enabled.length) % enabled.length];
        menu.setActive(next ?? enabled[0], false);
        break;
      }
      case "ArrowRight":
        if (menu.rows[menu.active]?.item.submenu) { event.preventDefault(); menu.openSubmenu(menu.active); menu.child?.setActive(0, false); }
        else this.options.onArrow?.(1);
        break;
      case "ArrowLeft":
        if (menu.parent) { event.preventDefault(); menu.parent.child = null; menu.close(); }
        else this.options.onArrow?.(-1);
        break;
      case "Enter": case " ":
        event.preventDefault();
        if (menu.active >= 0) menu.choose(menu.active);
        break;
    }
  }
  close() {
    clearTimeout(this.submenuTimer);
    this.child?.close();
    this.child = null;
    document.removeEventListener("keydown", this.onKey, true);
    document.removeEventListener("pointerdown", this.onDown, true);
    const el = this.el;
    el.classList.remove("is-open");
    el.classList.add("is-closing");
    setTimeout(() => el.remove(), 140);
    if (!this.parent) this.options.onClose?.();
  }
}

/* ------------------------------------------- menubar (port of menubar.js) */
function menuButton(content, items, extraClass) {
  const button = h("button.mb-item.mb-menu" + (extraClass ? "." + extraClass : ""), {
    on: {
      pointerdown: event => {
        if (event.button !== 0) return;
        event.preventDefault();
        event.stopPropagation();
        if (activeMenuButton === button) { closeMenus(); return; }
        showMenuFor(button, items);
      },
      pointerenter: () => { if (activeMenuButton && activeMenuButton !== button && isMenuOpen()) showMenuFor(button, items); },
      keydown: event => { if (event.key === "Enter" || event.key === " ") { event.preventDefault(); showMenuFor(button, items); } },
    },
  }, content);
  return button;
}
function showMenuFor(button, items) {
  activeMenuButton?.classList.remove("is-active");
  activeMenuButton = button;
  button.classList.add("is-active");
  openMenu(button, typeof items === "function" ? items() : items, {
    gap: 2,
    className: "menu-from-bar",
    overlay: root,
    ignore: [bar],
    onClose: () => {
      if (activeMenuButton === button) activeMenuButton = null;
      button.classList.remove("is-active");
    },
    onArrow: direction => {
      const buttons = [...left.querySelectorAll(".mb-menu")];
      const index = buttons.indexOf(button);
      const next = buttons[(index + direction + buttons.length) % buttons.length];
      next?.dispatchEvent(new PointerEvent("pointerdown", { bubbles: true, button: 0 }));
    },
  });
}
function renderLeft() {
  if (!left) return;
  left.replaceChildren();
  left.append(menuButton(sf("apple.logo", { size: 15 }), appleMenuItems, "mb-apple"));
  left.append(menuButton(h("strong", T().finder || "Finder"), () => finderMenus()[0].items, "mb-appname"));
  for (const menu of finderMenus().slice(1)) {
    left.append(menuButton(menu.title, () => menu.items));
  }
}
function renderLanguage() {
  const lang = LANGUAGES.find(l => l.code === LANG) || LANGUAGES[0];
  langButton.replaceChildren(sf("globe", { size: 14 }), h("span", lang.short));
  langButton.setAttribute("aria-label", (T().language || "Language") + ": " + lang.name);
}
function tick() {
  const now = new Date();
  const day = now.toLocaleDateString(LANG, { weekday: "short", day: "numeric", month: "short" }).replace(/\./g, "").replace(/,/g, "");
  const time = now.toLocaleTimeString(LANG, { hour: "2-digit", minute: "2-digit" });
  clockButton.replaceChildren(h("span.mb-date", day), h("span.mb-time", time));
  clockButton.setAttribute("aria-label", now.toLocaleString(LANG, { dateStyle: "full", timeStyle: "short" }));
}

/* --------------------------------------------------------- menu contents */
const openSite = (path = "") => window.open("https://github.com/j4yop/arrowslit" + path, "_blank", "noopener");
function toggleAppearance() {
  // The page's own night switch drives the whole scene (and persists).
  document.querySelector(".key .night")?.click();
}
function appleMenuItems() {
  return [
    { label: "About Arrowslit", action: () => window.dispatchEvent(new CustomEvent("arrowslit:about")) },
    { label: "Arrowslit User Guide", action: () => window.open("https://github.com/j4yop/arrowslit/blob/main/Docs/User-Guide.md", "_blank", "noopener") },
    { separator: true },
    { label: "Open Arrowslit Settings…", shortcut: "⌘,", action: () => window.dispatchEvent(new CustomEvent("arrowslit:settings")) },
    { label: "Download Arrowslit", action: () => window.open("https://github.com/j4yop/arrowslit/releases/latest", "_blank", "noopener") },
    { separator: true },
    { label: T().viewAppearance, checked: isDark(), action: toggleAppearance },
    { label: T().language, submenu: LANGUAGES.map(lang => ({ label: lang.name, checked: lang.code === LANG, action: () => changeLanguage(lang.code) })) },
    { separator: true },
    { label: T().resetDemo, action: () => location.reload() },
  ];
}
function finderMenus() {
  const trim = (items) => {
    const copy = [...items];
    while (copy.length && copy[copy.length - 1].separator) copy.pop();
    return copy;
  };
  return [
    { title: T().finder || "Finder", items: [{ label: "About Arrowslit", disabled: true }] },
    { title: T().menuFile, items: [{ label: S().newFolder || "New Folder", shortcut: "⇧⌘N", disabled: true }, { separator: true }, { label: S().closeWindow || "Close Window", shortcut: "⌘W", disabled: true }] },
    { title: T().menuEdit, items: [{ label: S().menuUndo || "Undo", shortcut: "⌘Z", disabled: true }, { label: S().menuRedo || "Redo", shortcut: "⇧⌘Z", disabled: true }] },
    { title: T().menuView, items: [] },
    { title: T().menuGo, items: [] },
    { title: T().menuWindow, items: trim([{ label: S().minimizeWindow || "Minimize", shortcut: "⌘M", disabled: true }, { separator: true }]) },
    { title: T().menuHelp, items: [] },
  ];
}
function toggleLanguageMenu() {
  if (activeMenuButton === langButton) { closeMenus(); return; }
  activeMenuButton?.classList.remove("is-active");
  activeMenuButton = langButton;
  langButton.classList.add("is-active");
  openMenu(langButton, LANGUAGES.map(lang => ({
    label: lang.name,
    icon: h("span.menu-flag", lang.flag),
    checked: lang.code === LANG,
    action: () => changeLanguage(lang.code),
  })), {
    gap: 2, align: "end", className: "menu-from-bar", overlay: root, ignore: [bar],
    onClose: () => { langButton.classList.remove("is-active"); if (activeMenuButton === langButton) activeMenuButton = null; },
  });
}
async function changeLanguage(code) {
  LANG = (LANGUAGES.find(l => l.code === code) ? code : "en-US");
  try { L = await (await fetch(new URL("strings/" + LANG + ".json?v=0.12.10", import.meta.url))).json(); }
  catch { L = null; }
  renderLeft();
  renderLanguage();
  tick();
  ccButton.setAttribute("aria-label", shellText(LANG).controlCenter);
  if (ccPanel) ccRender();
}

/* ------------------------------------- status item (port of statusbar.js) */
function setKeepAwake(active, minutes) {
  keepAwake.active = active;
  clearTimeout(keepAwake.timer);
  if (active && minutes > 0) keepAwake.timer = setTimeout(() => { keepAwake.active = false; }, minutes * 60000);
}
function showContextMenu(button) {
  const s = S();
  const items = [];
  items.push({ label: keepAwake.active ? (s.menuDisableAwake || "Disable keep awake") : (s.menuEnableAwake || "Enable keep awake"), action: () => setKeepAwake(!keepAwake.active, 0) });
  if (!keepAwake.active) {
    items.push({
      label: s.menuActivateFor || "Activate for…",
      submenu: [["minutes15", 15], ["minutes30", 30], ["hour1", 60], ["hours2", 120], ["hours4", 240], ["hours8", 480], ["indefinitely", 0]]
        .map(([key, minutes]) => ({ label: s[key] || key, action: () => setKeepAwake(true, minutes) })),
    });
  }
  items.push({ separator: true });
  items.push({ label: s.menuSettings || "Settings…", shortcut: "⌘,", action: () => window.dispatchEvent(new CustomEvent("arrowslit:settings")) });
  items.push({ label: s.menuAbout || "About Arrowslit", action: () => window.dispatchEvent(new CustomEvent("arrowslit:about")) });
  items.push({ label: s.menuCheckUpdates || "Check for updates…", action: () => window.open("https://github.com/j4yop/arrowslit/releases/latest", "_blank", "noopener") });
  items.push({ separator: true });
  items.push({ label: s.menuQuit || "Quit Arrowslit", shortcut: "⌘Q", action: () => {} });
  button.classList.add("is-active");
  openMenu(button, items, {
    gap: 2, className: "menu-from-bar", overlay: root,
    onClose: () => button.classList.remove("is-active"),
  });
}

/* ------------------------------- control center (port of control-center) */
let ccPanel = null;
const STEP = 1 / 16;
function toggleControlCenter(anchor) {
  if (ccPanel) closeControlCenter(); else openControlCenter(anchor);
}
function closeControlCenter() {
  if (!ccPanel) return;
  const { el, anchor, offs } = ccPanel;
  ccPanel = null;
  offs.splice(0).forEach(off => off());
  anchor?.classList.remove("is-active");
  anchor?.setAttribute("aria-expanded", "false");
  el.classList.remove("is-open");
  el.classList.add("is-closing");
  setTimeout(() => el.remove(), 200);
}
function openControlCenter(anchor) {
  const el = h("div.cc", { role: "dialog" });
  ccPanel = { el, anchor, offs: [], parts: {} };
  ccRender();
  root.append(el);
  anchor?.classList.add("is-active");
  anchor?.setAttribute("aria-expanded", "true");
  requestAnimationFrame(() => requestAnimationFrame(() => el.classList.add("is-open")));
  const onKey = event => {
    if (event.key !== "Escape") return;
    event.preventDefault();
    event.stopPropagation();
    closeControlCenter();
  };
  const onDown = event => {
    const path = event.composedPath();
    if (path.includes(el) || path.includes(anchor)) return;
    closeControlCenter();
  };
  document.addEventListener("keydown", onKey, true);
  setTimeout(() => document.addEventListener("pointerdown", onDown, true));
  ccPanel.offs.push(
    () => document.removeEventListener("keydown", onKey, true),
    () => document.removeEventListener("pointerdown", onDown, true),
  );
}
function ccGlyph(kind) {
  if (kind === "wifi") return sf("wifi", { size: 13, weight: "semibold" });
  const svg = h("svg.cc-glyph", { viewBox: "0 0 24 24", "aria-hidden": "true" });
  if (kind === "bluetooth") {
    svg.innerHTML = '<path d="M6.6 7.4 17 16.8 12 21.6V2.4l5 4.8L6.6 16.6" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round"/>';
  } else {
    svg.innerHTML = '<path d="M9.74 14.26A3.2 3.2 0 1 1 14.26 14.26M7.62 16.38A6.2 6.2 0 1 1 16.38 16.38M5.49 18.51A9.2 9.2 0 1 1 18.51 18.51" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/><circle cx="12" cy="12" r="1.5" fill="currentColor"/>';
  }
  return svg;
}
function ccRender() {
  if (!ccPanel) return;
  const text = shellText(LANG);
  ccPanel.parts = {};
  const connectRow = (id, label) => {
    const status = h("span.cc-row-status");
    const row = h("button.cc-row", {
      type: "button",
      on: { click: () => { ccToggles[id] = !ccToggles[id]; ccSync(); } },
    }, h("span.cc-circle", ccGlyph(id)), h("span.cc-row-text", h("span.cc-row-label", label), status));
    ccPanel.parts[id] = { row, status };
    return row;
  };
  const tileModule = (id, icon, action) => {
    const label = h("span.cc-row-label");
    const status = h("span.cc-row-status");
    const row = h("button.cc-module.cc-tile.cc-" + id, { type: "button", on: { click: action } },
      h("span.cc-circle", icon), h("span.cc-row-text", label, status));
    ccPanel.parts[id] = { row, label, status };
    return row;
  };
  const sliderModule = (kind, title) => {
    const icon = sf(kind === "brightness" ? "sun.min.fill" : "speaker.wave.2.fill", { size: 11, class: "cc-slider-icon" });
    const track = h("div.cc-slider", {
      role: "slider", tabindex: "0", "aria-label": title,
      "aria-valuemin": "0", "aria-valuemax": "100",
    }, h("span.cc-slider-fill"), icon, h("span.cc-slider-knob"));
    const set = value => {
      levels[kind] = Math.min(Math.max(value, 0), 1);
      ccSync();
    };
    const fromPointer = event => {
      const rect = track.getBoundingClientRect();
      const knob = rect.height;
      set((event.clientX - rect.left - knob / 2) / Math.max(1, rect.width - knob));
    };
    track.addEventListener("pointerdown", event => {
      if (event.button !== 0) return;
      event.preventDefault();
      track.setPointerCapture(event.pointerId);
      track.classList.add("is-dragging");
      track.focus({ preventScroll: true });
      fromPointer(event);
      const move = ev => fromPointer(ev);
      const up = () => {
        track.classList.remove("is-dragging");
        track.removeEventListener("pointermove", move);
        track.removeEventListener("pointerup", up);
        track.removeEventListener("pointercancel", up);
      };
      track.addEventListener("pointermove", move);
      track.addEventListener("pointerup", up);
      track.addEventListener("pointercancel", up);
    });
    track.addEventListener("keydown", event => {
      const delta = { ArrowRight: STEP, ArrowUp: STEP, ArrowLeft: -STEP, ArrowDown: -STEP }[event.key];
      if (delta === undefined) return;
      event.preventDefault();
      set(levels[kind] + delta);
    });
    ccPanel.parts[kind] = { track, icon };
    return h("div.cc-module.cc-slider-module", h("div.cc-module-title", title), track);
  };
  const mediaModule = () => {
    // No island / music service here, so the card sits in its "nothing playing"
    // state exactly as when the notch is not loaded.
    const art = h("span.cc-art", sf("music.note", { size: 16 }));
    const title = h("span.cc-media-title", T().nothingPlaying || "Nothing Playing");
    const artist = h("span.cc-media-artist");
    artist.hidden = true;
    const play = h("button.cc-play", { type: "button", disabled: "true", "aria-label": S().actionPlay || "Play" }, sf("play.fill", { size: 16 }));
    const skip = h("button.cc-play.cc-skip", { type: "button", hidden: "true" }, sf("forward.fill", { size: 15 }));
    ccPanel.parts.media = { art, title, artist, play, icon: play.querySelector(".sf") };
    return h("div.cc-module.cc-media", art, h("span.cc-media-text", title, artist), play, skip);
  };
  ccPanel.el.setAttribute("aria-label", text.controlCenter);
  ccPanel.el.replaceChildren(h("div.cc-grid",
    h("div.cc-module.cc-connect",
      connectRow("wifi", text.wifi),
      connectRow("bluetooth", text.bluetooth),
      connectRow("airdrop", text.airdrop)),
    tileModule("focus", sf("moon.fill", { size: 13 }), () => { ccToggles.focus = !ccToggles.focus; ccSync(); }),
    tileModule("appearance", sf("circle.lefthalf.filled", { size: 14 }), toggleAppearance),
    sliderModule("brightness", text.display),
    sliderModule("volume", text.sound),
    mediaModule()));
  ccSync();
}
function ccSync() {
  if (!ccPanel) return;
  const text = shellText(LANG);
  const parts = ccPanel.parts;
  const statusOf = {
    wifi: ccToggles.wifi ? (text.wifiNetwork || "Home") : (text.off || "Off"),
    bluetooth: ccToggles.bluetooth ? (text.on || "On") : (text.off || "Off"),
    airdrop: ccToggles.airdrop ? (text.airdropContacts || "Contacts Only") : (text.off || "Off"),
  };
  for (const id of ["wifi", "bluetooth", "airdrop"]) {
    const { row, status } = parts[id];
    row.classList.toggle("is-on", ccToggles[id]);
    row.setAttribute("aria-pressed", String(ccToggles[id]));
    status.textContent = statusOf[id];
  }
  const focus = parts.focus;
  focus.row.classList.toggle("is-on", ccToggles.focus);
  focus.row.setAttribute("aria-pressed", String(ccToggles.focus));
  focus.label.textContent = ccToggles.focus ? (text.doNotDisturb || "Do Not Disturb") : (text.focus || "Focus");
  focus.status.textContent = ccToggles.focus ? (text.on || "On") : "";
  const dark = isDark();
  const appearance = parts.appearance;
  appearance.row.classList.toggle("is-on", dark);
  appearance.row.setAttribute("aria-pressed", String(dark));
  appearance.label.textContent = text.darkMode || "Dark Mode";
  appearance.status.textContent = dark ? (text.on || "On") : (text.off || "Off");
  for (const kind of ["brightness", "volume"]) {
    const { track } = parts[kind];
    track.style.setProperty("--p", levels[kind].toFixed(4));
    track.setAttribute("aria-valuenow", String(Math.round(levels[kind] * 100)));
  }
  parts.media.play.disabled = true;
}

/* ------------------------------------------------ theme + boot ---------- */
function syncAppearance() {
  host.dataset.appearance = isDark() ? "dark" : "light";
  if (ccPanel) ccSync();
}
function boot() {
  // The page bar is replaced by the macOS-style menubar.
  document.querySelector("body > header.dock")?.remove();
  const tryBtn = document.getElementById("try-edit");
  if (tryBtn) tryBtn.hidden = true;

  host = document.createElement("div");
  host.id = "arrowslit-menubar-host";
  root = host.attachShadow({ mode: "open" });
  root.innerHTML = `<style>/* Tokens e base do Mac simulado. As cores seguem as cores semânticas do
   AppKit para a aparência escura e clara, e os tamanhos seguem os estilos de
   texto do macOS (body 13, callout 12, subheadline 11, caption 10). */

:host, .force-dark, :host[data-app-appearance="dark"] [data-app-surface] {
  color-scheme: dark;
  --font: -apple-system, BlinkMacSystemFont, "SF Pro Text", "SF Pro", "Inter", system-ui, "Segoe UI", Roboto, "Helvetica Neue", sans-serif;
  --font-display: -apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro", "Inter", system-ui, "Segoe UI", sans-serif;
  --font-mono: ui-monospace, "SF Mono", SFMono-Regular, Menlo, Consolas, monospace;
  --font-rounded: ui-rounded, "SF Pro Rounded", -apple-system, BlinkMacSystemFont, system-ui, sans-serif;

  /* Rótulos */
  --label: rgba(255, 255, 255, 0.86);
  --label-strong: #fff;
  --secondary: rgba(255, 255, 255, 0.55);
  --tertiary: rgba(255, 255, 255, 0.26);
  --quaternary: rgba(255, 255, 255, 0.1);
  --quinary: rgba(255, 255, 255, 0.05);
  --separator: rgba(255, 255, 255, 0.1);
  --grid: rgba(255, 255, 255, 0.07);

  /* Cores do sistema (escuro) */
  --accent: #0a84ff;
  --accent-rgb: 10, 132, 255;
  --accent-text: #3d9bff;
  --blue: #0a84ff;
  --green: #30d158;
  --green-rgb: 48, 209, 88;
  --orange: #ff9f0a;
  --orange-rgb: 255, 159, 10;
  --red: #ff453a;
  --red-rgb: 255, 69, 58;
  --yellow: #ffd60a;
  --purple: #bf5af2;
  --pink: #ff375f;
  --teal: #40c8e0;
  --indigo: #5e5ce6;
  --mint: #63e6e2;
  --cyan: #64d2ff;
  --brown: #ac8e68;
  --gray: #8e8e93;

  /* Superfícies */
  --window-bg: #1f1f21;
  --window-bg-rgb: 31, 31, 33;
  --sidebar-bg: rgba(44, 44, 48, 0.72);
  --sidebar-solid: #2a2a2d;
  --content-bg: #1c1c1e;
  --card-bg: rgba(255, 255, 255, 0.045);
  --control-bg: rgba(255, 255, 255, 0.11);
  --control-bg-hover: rgba(255, 255, 255, 0.16);
  --control-bg-active: rgba(255, 255, 255, 0.22);
  --control-border: rgba(255, 255, 255, 0.07);
  --field-bg: rgba(255, 255, 255, 0.06);
  --menu-bg: rgba(40, 40, 44, 0.78);
  --popover-bg: rgba(42, 42, 46, 0.86);
  --glass: rgba(30, 30, 34, 0.52);
  --glass-strong: rgba(28, 28, 32, 0.74);
  --glass-border: rgba(255, 255, 255, 0.12);
  --glass-highlight: rgba(255, 255, 255, 0.16);
  --hover: rgba(255, 255, 255, 0.06);
  --selection: rgba(var(--accent-rgb), 0.9);
  --selection-inactive: rgba(255, 255, 255, 0.12);
  --switch-off: rgba(255, 255, 255, 0.16);
  --switch-knob: #f4f4f6;
  --shadow-window: 0 0 0 0.5px rgba(0, 0, 0, 0.9), 0 30px 80px rgba(0, 0, 0, 0.55), 0 10px 26px rgba(0, 0, 0, 0.35);
  --shadow-window-inactive: 0 0 0 0.5px rgba(0, 0, 0, 0.8), 0 18px 46px rgba(0, 0, 0, 0.4);
  --shadow-menu: 0 0 0 0.5px rgba(0, 0, 0, 0.7), 0 14px 38px rgba(0, 0, 0, 0.45);
  --inner-stroke: inset 0 0 0 0.5px rgba(255, 255, 255, 0.14);
  --search-bg: rgba(255, 255, 255, 0.07);
  --search-stroke: inset 0 0 0 0.5px rgba(255, 255, 255, 0.05);
  --segment-thumb: rgba(255, 255, 255, 0.24);
  --segment-thumb-shadow: 0 1px 3px rgba(0, 0, 0, 0.25), inset 0 0 0 0.5px rgba(255, 255, 255, 0.12);
  --tl-inactive: rgba(255, 255, 255, 0.16);

  /* Geometria */
  --menubar-h: 32px;
  --radius-window: 16px;
  --radius-card: 16px;
  --radius-control: 6px;
  --radius-menu: 10px;
  --dock-size: 58px;

  /* Movimento */
  --spring: cubic-bezier(0.32, 1.4, 0.48, 1);
  --spring-soft: cubic-bezier(0.25, 1.15, 0.4, 1);
  --ease-out: cubic-bezier(0.2, 0.8, 0.2, 1);
  --ease-in-out: cubic-bezier(0.65, 0, 0.35, 1);
}

:host[data-appearance="light"], .force-light, :host[data-app-appearance="light"] [data-app-surface] {
  color-scheme: light;
  --label: rgba(0, 0, 0, 0.86);
  --label-strong: #000;
  --secondary: rgba(0, 0, 0, 0.5);
  --tertiary: rgba(0, 0, 0, 0.26);
  --quaternary: rgba(0, 0, 0, 0.1);
  --quinary: rgba(0, 0, 0, 0.05);
  --separator: rgba(0, 0, 0, 0.1);
  --grid: rgba(0, 0, 0, 0.06);

  --accent: #007aff;
  --accent-rgb: 0, 122, 255;
  --accent-text: #0068da;
  --blue: #007aff;
  --green: #28cd41;
  --green-rgb: 40, 205, 65;
  --orange: #ff9500;
  --orange-rgb: 255, 149, 0;
  --red: #ff3b30;
  --red-rgb: 255, 59, 48;
  --yellow: #ffcc00;
  --purple: #af52de;
  --pink: #ff2d55;
  --teal: #30b0c7;
  --indigo: #5856d6;
  --mint: #00c7be;
  --cyan: #32ade6;
  --brown: #a2845e;
  --gray: #8e8e93;

  --window-bg: #f4f4f5;
  --window-bg-rgb: 244, 244, 245;
  --sidebar-bg: rgba(232, 232, 236, 0.74);
  --sidebar-solid: #e9e9ec;
  --content-bg: #fafafa;
  --card-bg: rgba(0, 0, 0, 0.035);
  --control-bg: #fff;
  --control-bg-hover: #f6f6f7;
  --control-bg-active: #ececee;
  --control-border: rgba(0, 0, 0, 0.12);
  --field-bg: #fff;
  --menu-bg: rgba(246, 246, 248, 0.82);
  --popover-bg: rgba(250, 250, 252, 0.9);
  --glass: rgba(255, 255, 255, 0.5);
  --glass-strong: rgba(250, 250, 252, 0.78);
  --glass-border: rgba(0, 0, 0, 0.08);
  --glass-highlight: rgba(255, 255, 255, 0.7);
  --hover: rgba(0, 0, 0, 0.05);
  --selection-inactive: rgba(0, 0, 0, 0.08);
  --switch-off: rgba(0, 0, 0, 0.1);
  --switch-knob: #fff;
  --shadow-window: 0 0 0 0.5px rgba(0, 0, 0, 0.22), 0 26px 70px rgba(0, 0, 0, 0.26), 0 8px 22px rgba(0, 0, 0, 0.14);
  --shadow-window-inactive: 0 0 0 0.5px rgba(0, 0, 0, 0.18), 0 14px 36px rgba(0, 0, 0, 0.16);
  --shadow-menu: 0 0 0 0.5px rgba(0, 0, 0, 0.18), 0 12px 32px rgba(0, 0, 0, 0.2);
  --inner-stroke: inset 0 0 0 0.5px rgba(255, 255, 255, 0.6);
  --search-bg: rgba(0, 0, 0, 0.06);
  --search-stroke: none;
  --segment-thumb: #fff;
  --segment-thumb-shadow: 0 1px 2px rgba(0, 0, 0, 0.18), 0 0 0 0.5px rgba(0, 0, 0, 0.06);
  --tl-inactive: rgba(0, 0, 0, 0.12);
}

*, *::before, *::after { box-sizing: border-box; }

html, body {
  margin: 0;
  height: 100%;
  overflow: hidden;
  background: #07070c;
  -webkit-text-size-adjust: 100%;
}

.force-dark, .force-light, [data-app-surface] { color: var(--label); }

body {
  font: 13px/1.38 var(--font);
  color: var(--label);
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  user-select: none;
  -webkit-user-select: none;
  -webkit-tap-highlight-color: transparent;
  touch-action: manipulation;
}

button, input, select, textarea { font: inherit; color: inherit; }
button { cursor: default; background: none; border: 0; padding: 0; margin: 0; }
a { color: inherit; text-decoration: none; cursor: default; }
img { display: block; max-width: 100%; }
input, textarea { user-select: text; -webkit-user-select: text; }
[hidden] { display: none !important; }

:focus { outline: none; }
:focus-visible { outline: 3px solid rgba(var(--accent-rgb), 0.5); outline-offset: 1px; border-radius: 5px; }

/* Resumo do app que toda página traz para leitores e crawlers que nunca
   rodam o desktop. */
.seo {
  position: absolute !important; width: 1px; height: 1px; padding: 0; margin: -1px; overflow: hidden;
  clip: rect(0, 0, 0, 0); border: 0;
}

/* Se o desktop não sobe, o resumo aparece no lugar de uma tela vazia. */
.no-desktop .seo {
  position: static !important; width: auto; height: auto; margin: 0 auto; overflow: visible; clip: auto;
  max-width: 720px; padding: 32px 20px; color: #f5f5f7;
}
.no-desktop .screen { display: none; }
.no-desktop, .no-desktop body { overflow: auto !important; height: auto !important; }

.sr-only {
  position: absolute !important; width: 1px; height: 1px; padding: 0; margin: -1px; overflow: hidden;
  clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0;
}

/* SF Symbols */
.sf {
  display: inline-block;
  width: var(--sf-w, 1em);
  height: var(--sf-h, 1em);
  flex: none;
  fill: currentColor;
  overflow: visible;
  vertical-align: var(--sf-b, -0.15em);
}
.sf-medium path { stroke: currentColor; stroke-width: 0.25px; stroke-linejoin: round; paint-order: stroke; }
.sf-semibold path { stroke: currentColor; stroke-width: 0.5px; stroke-linejoin: round; paint-order: stroke; }
.sf-bold path { stroke: currentColor; stroke-width: 0.8px; stroke-linejoin: round; paint-order: stroke; }
.sf-heavy path { stroke: currentColor; stroke-width: 1.15px; stroke-linejoin: round; paint-order: stroke; }

/* Estilos de texto */
.t-large { font: 700 26px/1.2 var(--font-display); letter-spacing: -0.02em; }
.t-title { font: 700 22px/1.2 var(--font-display); letter-spacing: -0.015em; }
.t-title2 { font: 700 17px/1.25 var(--font-display); letter-spacing: -0.01em; }
.t-title3 { font: 600 15px/1.3 var(--font-display); }
.t-headline { font-weight: 600; font-size: 13px; }
.t-body { font-size: 13px; }
.t-callout { font-size: 12px; }
.t-subhead { font-size: 11px; }
.t-caption { font-size: 10.5px; line-height: 1.35; }
.t-mono { font-family: var(--font-mono); font-variant-numeric: tabular-nums; }
.tnum { font-variant-numeric: tabular-nums; }
.c-secondary { color: var(--secondary); }
.c-tertiary { color: var(--tertiary); }
.c-accent { color: var(--accent); }

/* Durante o boot nada anima até o desktop ficar pronto, menos a própria tela de carregamento. */
body.booting *:not(#boot, #boot *) { transition: none !important; animation: none !important; }

@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after { animation-duration: 0.01ms !important; animation-iteration-count: 1 !important; transition-duration: 0.01ms !important; }
}

/* O desktop em volta do app, com papel de parede, barra de menus, Dock,
   ícones do desktop, janelas, menus e notificações. */

.screen {
  position: fixed;
  inset: 0;
  overflow: hidden;
  isolation: isolate;
  background: #0b0b14;
}

/* ---------- Papel de parede ---------- */

.wallpaper {
  position: absolute;
  inset: 0;
  z-index: 0;
  overflow: hidden;
  background: radial-gradient(120% 90% at 50% 110%, #1b1542 0%, #0d0b22 45%, #06060f 100%);
  transition: background 0.8s var(--ease-out);
}
.wp-layer {
  position: absolute;
  inset: -20%;
  filter: blur(70px) saturate(130%);
  opacity: 0.9;
  transition: background 1s var(--ease-out), opacity 1s var(--ease-out);
  will-change: transform;
}
.wp-a {
  background:
    radial-gradient(38% 34% at 24% 30%, rgba(123, 92, 255, 0.85), transparent 70%),
    radial-gradient(30% 30% at 76% 22%, rgba(40, 120, 255, 0.7), transparent 70%);
  animation: wp-drift-a 38s ease-in-out infinite alternate;
}
.wp-b {
  background:
    radial-gradient(34% 30% at 64% 70%, rgba(214, 60, 196, 0.55), transparent 70%),
    radial-gradient(26% 24% at 30% 78%, rgba(30, 200, 210, 0.45), transparent 70%);
  animation: wp-drift-b 46s ease-in-out infinite alternate;
}
.wp-c {
  inset: 0;
  filter: none;
  opacity: 0.55;
  background:
    linear-gradient(170deg, transparent 55%, rgba(255, 255, 255, 0.05) 56%, transparent 62%),
    linear-gradient(160deg, transparent 63%, rgba(160, 140, 255, 0.08) 64%, transparent 72%),
    radial-gradient(70% 50% at 50% -10%, rgba(255, 255, 255, 0.08), transparent 70%);
}
.wp-grain {
  position: absolute;
  inset: 0;
  opacity: 0.06;
  mix-blend-mode: overlay;
  background-image: url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='160' height='160'><filter id='n'><feTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='2' stitchTiles='stitch'/></filter><rect width='100%' height='100%' filter='url(%23n)'/></svg>");
}
@keyframes wp-drift-a { to { transform: translate3d(4%, 3%, 0) rotate(6deg) scale(1.06); } }
@keyframes wp-drift-b { to { transform: translate3d(-5%, -4%, 0) rotate(-8deg) scale(1.08); } }

.wallpaper[data-wallpaper="dusk"] { background: radial-gradient(120% 90% at 50% 110%, #3a1630 0%, #1a0d1c 45%, #0b0610 100%); }
.wallpaper[data-wallpaper="dusk"] .wp-a { background: radial-gradient(38% 34% at 24% 30%, rgba(255, 120, 80, 0.75), transparent 70%), radial-gradient(30% 30% at 76% 22%, rgba(255, 70, 140, 0.6), transparent 70%); }
.wallpaper[data-wallpaper="dusk"] .wp-b { background: radial-gradient(34% 30% at 64% 70%, rgba(150, 60, 255, 0.55), transparent 70%), radial-gradient(26% 24% at 30% 78%, rgba(255, 190, 90, 0.4), transparent 70%); }
.wallpaper[data-wallpaper="ocean"] { background: radial-gradient(120% 90% at 50% 110%, #06324a 0%, #031a2b 45%, #020b14 100%); }
.wallpaper[data-wallpaper="ocean"] .wp-a { background: radial-gradient(38% 34% at 24% 30%, rgba(0, 170, 255, 0.7), transparent 70%), radial-gradient(30% 30% at 76% 22%, rgba(40, 230, 200, 0.55), transparent 70%); }
.wallpaper[data-wallpaper="ocean"] .wp-b { background: radial-gradient(34% 30% at 64% 70%, rgba(30, 90, 255, 0.55), transparent 70%), radial-gradient(26% 24% at 30% 78%, rgba(120, 255, 220, 0.35), transparent 70%); }
.wallpaper[data-wallpaper="graphite"] { background: radial-gradient(120% 90% at 50% 110%, #2a2a30 0%, #151518 45%, #0a0a0c 100%); }
.wallpaper[data-wallpaper="graphite"] .wp-a { background: radial-gradient(38% 34% at 24% 30%, rgba(150, 150, 170, 0.35), transparent 70%), radial-gradient(30% 30% at 76% 22%, rgba(120, 130, 160, 0.3), transparent 70%); }
.wallpaper[data-wallpaper="graphite"] .wp-b { background: radial-gradient(34% 30% at 64% 70%, rgba(90, 90, 110, 0.4), transparent 70%), radial-gradient(26% 24% at 30% 78%, rgba(160, 160, 180, 0.2), transparent 70%); }

:host[data-appearance="light"] .wallpaper { background: radial-gradient(120% 90% at 50% 110%, #c9c3ff 0%, #e4e0ff 45%, #f3f1ff 100%); }
:host[data-appearance="light"] .wp-a { opacity: 0.75; background: radial-gradient(38% 34% at 24% 30%, rgba(150, 120, 255, 0.75), transparent 70%), radial-gradient(30% 30% at 76% 22%, rgba(90, 170, 255, 0.65), transparent 70%); }
:host[data-appearance="light"] .wp-b { opacity: 0.7; background: radial-gradient(34% 30% at 64% 70%, rgba(255, 130, 210, 0.5), transparent 70%), radial-gradient(26% 24% at 30% 78%, rgba(80, 220, 220, 0.45), transparent 70%); }
:host[data-appearance="light"] .wp-c { opacity: 0.4; }
:host[data-appearance="light"] .wallpaper[data-wallpaper="dusk"] { background: radial-gradient(120% 90% at 50% 110%, #ffc2b0 0%, #ffe0d6 45%, #fff2ec 100%); }
:host[data-appearance="light"] .wallpaper[data-wallpaper="ocean"] { background: radial-gradient(120% 90% at 50% 110%, #a8dcff 0%, #d4efff 45%, #eef8ff 100%); }
:host[data-appearance="light"] .wallpaper[data-wallpaper="graphite"] { background: radial-gradient(120% 90% at 50% 110%, #c8c8cf 0%, #e2e2e6 45%, #f2f2f4 100%); }

/* ---------- Barra de menus ---------- */

.menubar {
  position: absolute;
  inset: 0 0 auto 0;
  z-index: 9000;
  height: var(--menubar-h);
  display: flex;
  align-items: center;
  padding: 0 8px;
  color: #fff;
  font-size: 13px;
  font-weight: 500;
  text-shadow: 0 0.5px 1.5px rgba(0, 0, 0, 0.35);
  background: linear-gradient(to bottom, rgba(0, 0, 0, 0.22), rgba(0, 0, 0, 0.06));
  -webkit-backdrop-filter: blur(18px) saturate(140%);
  backdrop-filter: blur(18px) saturate(140%);
}
:host[data-appearance="light"] .menubar {
  color: rgba(0, 0, 0, 0.88);
  text-shadow: 0 0 6px rgba(255, 255, 255, 0.25);
  background: linear-gradient(to bottom, rgba(255, 255, 255, 0.42), rgba(255, 255, 255, 0.22));
}
.mb-left, .mb-right { display: flex; align-items: center; height: 100%; min-width: 0; }
.mb-left { flex: 1 1 0; overflow: hidden; }
.mb-right { flex: 1 1 0; justify-content: flex-end; gap: 1px; }
.mb-notch-gap { flex: none; width: var(--notch-gap, 0px); }
.mb-status-area { display: flex; align-items: center; height: 100%; gap: 1px; }
.mb-item {
  height: calc(var(--menubar-h) - 7px);
  display: inline-flex;
  align-items: center;
  gap: 5px;
  padding: 0 9px;
  border-radius: 7px;
  color: inherit;
  white-space: nowrap;
  transition: background-color 0.12s, opacity 0.2s, transform 0.25s var(--spring-soft), width 0.25s;
}
.mb-item:hover { background: transparent; }
.mb-item.is-active, .mb-item:active { background: rgba(255, 255, 255, 0.2); }
:host[data-appearance="light"] .mb-item.is-active, :host[data-appearance="light"] .mb-item:active { background: rgba(0, 0, 0, 0.1); }
.mb-apple { padding: 0 11px 0 10px; }
.mb-apple .sf { font-size: 16px; }
.mb-appname strong { font-weight: 700; }
.mb-lang span { font-size: 12px; font-weight: 600; letter-spacing: 0.02em; }
.mb-clock { font-variant-numeric: tabular-nums; padding-right: 8px; gap: 7px; }
.mb-status.is-entering { opacity: 0; transform: scale(0.6); }
.mb-status.is-leaving { opacity: 0; transform: scale(0.6); }

/* ---------- Ícones do desktop ---------- */

.desk-area { position: absolute; inset: var(--menubar-h) 0 0 0; z-index: 1; }
.desk-band {
  position: fixed;
  display: none;
  z-index: 2;
  border: 1px solid rgba(255, 255, 255, 0.5);
  background: rgba(255, 255, 255, 0.12);
  border-radius: 3px;
  pointer-events: none;
}
.desk-icons {
  position: absolute;
  top: calc(var(--menubar-h) + 14px);
  right: 14px;
  z-index: 2;
  display: grid;
  grid-auto-flow: row;
  gap: 10px;
  justify-items: center;
}
.desk-icon {
  width: 92px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 5px;
  padding: 6px 4px 5px;
  border-radius: 8px;
  color: #fff;
}
.desk-icon-img {
  width: 64px;
  height: 64px;
  display: grid;
  place-items: center;
  border-radius: 8px;
  padding: 3px;
  transition: background-color 0.12s;
}
.desk-icon-img img { width: 100%; height: 100%; object-fit: contain; filter: drop-shadow(0 4px 8px rgba(0, 0, 0, 0.35)); }
.desk-label {
  max-width: 100%;
  padding: 1px 6px;
  border-radius: 4px;
  font-size: 12px;
  font-weight: 500;
  line-height: 1.25;
  text-align: center;
  text-shadow: 0 1px 2px rgba(0, 0, 0, 0.75), 0 0 6px rgba(0, 0, 0, 0.35);
  overflow-wrap: anywhere;
}
.desk-icon.is-selected .desk-icon-img { background: rgba(255, 255, 255, 0.16); }
.desk-icon.is-selected .desk-label { background: var(--accent); text-shadow: none; }
:host[data-appearance="light"] .desk-icon { color: #111; }
:host[data-appearance="light"] .desk-label { text-shadow: 0 0 4px rgba(255, 255, 255, 0.9); }
:host[data-appearance="light"] .desk-icon.is-selected .desk-label { color: #fff; }

/* Ícones de arquivo desenhados em CSS */
.file-icon {
  position: relative;
  width: 46px;
  height: 58px;
  border-radius: 4px 12px 4px 4px;
  background: linear-gradient(180deg, #fbfbfd, #e7e7ec);
  box-shadow: 0 0 0 0.5px rgba(0, 0, 0, 0.25), 0 3px 8px rgba(0, 0, 0, 0.3);
}
.file-icon::before {
  content: "";
  position: absolute;
  top: 0;
  right: 0;
  width: 13px;
  height: 13px;
  border-radius: 0 0 0 3px;
  background: linear-gradient(225deg, transparent 50%, #d4d4dc 50%);
}
.file-icon .file-badge {
  position: absolute;
  left: 50%;
  bottom: 9px;
  transform: translateX(-50%);
  padding: 1px 5px;
  border-radius: 3px;
  font: 700 7.5px/1.3 var(--font);
  letter-spacing: 0.03em;
  color: #fff;
  background: #6b6b76;
}
.file-icon .file-glyph { position: absolute; left: 50%; top: 15px; transform: translateX(-50%); width: 24px; height: 24px; }

/* ---------- Dock ---------- */

.dock {
  position: absolute;
  left: 50%;
  bottom: 8px;
  z-index: 8000;
  transform: translateX(-50%);
  pointer-events: none;
}
.dock-shelf {
  pointer-events: auto;
  display: flex;
  align-items: flex-end;
  gap: 6px;
  padding: 6px 8px;
  border-radius: 24px;
  background: var(--glass);
  box-shadow: inset 0 0 0 0.5px var(--glass-highlight), 0 0 0 0.5px rgba(0, 0, 0, 0.35), 0 10px 30px rgba(0, 0, 0, 0.3);
  -webkit-backdrop-filter: blur(24px) saturate(180%);
  backdrop-filter: blur(24px) saturate(180%);
}
.dock-item {
  --mag: 1;
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  width: calc(var(--dock-size) * var(--mag));
  transition: width 0.18s var(--ease-out);
}
.dock-shelf.is-magnifying .dock-item { transition: width 0.06s linear; }
.dock-tile {
  width: calc(var(--dock-size) * var(--mag));
  height: calc(var(--dock-size) * var(--mag));
  display: grid;
  place-items: center;
  transition: width 0.18s var(--ease-out), height 0.18s var(--ease-out);
}
.dock-shelf.is-magnifying .dock-tile { transition: width 0.06s linear, height 0.06s linear; }
.dock-tile > img { width: 100%; height: 100%; filter: drop-shadow(0 3px 5px rgba(0, 0, 0, 0.3)); }
.dock-app {
  width: 84%;
  height: 84%;
  display: grid;
  place-items: center;
  border-radius: 23%;
  color: #fff;
  box-shadow: inset 0 0 0 0.5px rgba(255, 255, 255, 0.25), 0 3px 8px rgba(0, 0, 0, 0.3);
}
.dock-app svg { width: 52%; height: 52%; }
.dock-app .sf { font-size: calc(var(--dock-size) * var(--mag) * 0.42); }
.dock-app.is-download { background: linear-gradient(180deg, #4fa8ff, #0a6cf0); }
.dock-app.is-github { background: linear-gradient(180deg, #45454d, #18181b); }
.dock-app.is-x { background: linear-gradient(180deg, #2a2a2e, #000); }
.dock-app.is-coffee { background: linear-gradient(180deg, #ffe34d, #ffcc00); color: #2a1a05; }
/* Os Ajustes: engrenagem prateada sobre grafite, como o app de ajustes do Mac. */
.dock-app.is-settings { background: linear-gradient(180deg, #9a9aa3, #4b4b53); color: #f2f2f5; }
.dock-app.is-settings svg { width: 66%; height: 66%; filter: drop-shadow(0 1px 1px rgba(0, 0, 0, 0.35)); }
.dock-sep {
  align-self: stretch;
  width: 1px;
  margin: 6px 3px;
  background: rgba(255, 255, 255, 0.22);
}
:host[data-appearance="light"] .dock-sep { background: rgba(0, 0, 0, 0.16); }
.dock-dot {
  position: absolute;
  bottom: -4px;
  width: 4px;
  height: 4px;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.85);
  opacity: 0;
  transition: opacity 0.3s;
}
:host[data-appearance="light"] .dock-dot { background: rgba(0, 0, 0, 0.7); }
.dock-item.is-running .dock-dot { opacity: 1; }
.dock-label {
  position: absolute;
  bottom: calc(100% + 14px);
  left: 50%;
  transform: translate(-50%, 4px);
  padding: 4px 10px;
  border-radius: 8px;
  font-size: 13px;
  font-weight: 500;
  white-space: nowrap;
  color: var(--label);
  background: var(--popover-bg);
  box-shadow: var(--shadow-menu);
  -webkit-backdrop-filter: blur(20px);
  backdrop-filter: blur(20px);
  opacity: 0;
  pointer-events: none;
  transition: opacity 0.12s, transform 0.12s;
}
.dock-item:hover .dock-label, .dock-item:focus-visible .dock-label { opacity: 1; transform: translate(-50%, 0); }

/* ---------- Janelas ---------- */

.windows-layer { position: absolute; inset: 0; z-index: 100; pointer-events: none; }
.window {
  position: absolute;
  display: flex;
  flex-direction: column;
  min-width: 0;
  pointer-events: auto;
  border-radius: var(--radius-window);
  background: var(--window-bg);
  color: var(--label);
  box-shadow: var(--shadow-window-inactive);
  transition: box-shadow 0.2s;
  contain: layout;
}
.window.is-focused { box-shadow: var(--shadow-window); }
.window::after {
  content: "";
  position: absolute;
  inset: 0;
  border-radius: inherit;
  box-shadow: var(--inner-stroke);
  pointer-events: none;
  z-index: 50;
}
.window.is-opening { animation: win-open 0.42s var(--spring-soft); }
.window.is-closing { animation: win-close 0.2s var(--ease-in-out) forwards; pointer-events: none; }
@keyframes win-open { from { opacity: 0; transform: scale(0.9) translateY(8px); } }
@keyframes win-close { to { opacity: 0; transform: scale(0.94); } }
.win-titlebar {
  position: relative;
  flex: none;
  height: 52px;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0 80px;
  border-bottom: 0.5px solid var(--separator);
}
.win-title { font-weight: 600; font-size: 13px; color: var(--label); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.window:not(.is-focused) .win-title { color: var(--secondary); }
.win-body { position: relative; flex: 1; min-height: 0; display: flex; flex-direction: column; border-radius: inherit; overflow: hidden; }
.win-titlebar + .win-body { border-top-left-radius: 0; border-top-right-radius: 0; }

.traffic {
  position: absolute;
  top: 19px;
  left: 20px;
  z-index: 60;
  display: flex;
  gap: 9px;
}
.win-titlebar .traffic { top: 50%; transform: translateY(-50%); }
.tl {
  position: relative;
  width: 13px;
  height: 13px;
  border-radius: 50%;
  background: var(--tl-color);
  box-shadow: inset 0 0 0 0.5px rgba(0, 0, 0, 0.18);
}
.tl-close { --tl-color: #ff5f57; }
.tl-min { --tl-color: #febc2e; }
.tl-zoom { --tl-color: #28c840; }
.window:not(.is-focused) .tl { --tl-color: var(--tl-inactive); }
.traffic:hover .tl { --tl-color: initial; }
.traffic:hover .tl-close { --tl-color: #ff5f57; }
.traffic:hover .tl-min { --tl-color: #febc2e; }
.traffic:hover .tl-zoom { --tl-color: #28c840; }
.tl::after {
  content: "";
  position: absolute;
  inset: 0;
  opacity: 0;
  background: center / 7px 7px no-repeat;
}
.traffic:hover .tl::after { opacity: 0.7; }
.tl-close::after { background-image: url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 8 8'><path d='M1 1l6 6M7 1L1 7' stroke='%234d0000' stroke-width='1.4' stroke-linecap='round'/></svg>"); }
.tl-min::after { background-image: url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 8 8'><path d='M0.8 4h6.4' stroke='%23995700' stroke-width='1.5' stroke-linecap='round'/></svg>"); }
.tl-zoom::after { background-image: url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 8 8'><path d='M1.2 2.6v4.2h4.2zM6.8 5.4V1.2H2.6z' fill='%23006500'/></svg>"); }

.win-resize { position: absolute; z-index: 70; }
.r-n, .r-s { left: 10px; right: 10px; height: 8px; cursor: ns-resize; }
.r-n { top: -4px; } .r-s { bottom: -4px; }
.r-e, .r-w { top: 10px; bottom: 10px; width: 8px; cursor: ew-resize; }
.r-e { right: -4px; } .r-w { left: -4px; }
.r-ne, .r-nw, .r-se, .r-sw { width: 14px; height: 14px; }
.r-ne { top: -4px; right: -4px; cursor: nesw-resize; }
.r-sw { bottom: -4px; left: -4px; cursor: nesw-resize; }
.r-nw { top: -4px; left: -4px; cursor: nwse-resize; }
.r-se { bottom: -4px; right: -4px; cursor: nwse-resize; }
body.is-dragging-window, body.is-dragging-window * { cursor: default !important; }
body.is-resizing-window .window { transition: none; }

/* ---------- Menus ---------- */

.overlay-layer { position: absolute; inset: 0; z-index: 9500; pointer-events: none; }
.overlay-layer > * { pointer-events: auto; }
.menu {
  position: fixed;
  z-index: 9600;
  min-width: 180px;
  max-width: 360px;
  max-height: calc(100vh - 12px);
  overflow-y: auto;
  padding: 5px;
  border-radius: 12px;
  color: var(--label);
  background: var(--menu-bg);
  box-shadow: var(--shadow-menu), inset 0 0 0 0.5px var(--glass-highlight);
  -webkit-backdrop-filter: blur(30px) saturate(180%);
  backdrop-filter: blur(30px) saturate(180%);
  font-size: 13px;
  opacity: 0;
  transform-origin: top;
}
.menu.is-open { opacity: 1; transition: opacity 0.08s; }
.menu.is-closing { opacity: 0; transition: opacity 0.14s; pointer-events: none; }
.menu-item {
  display: flex;
  align-items: center;
  gap: 6px;
  height: 24px;
  padding: 0 10px 0 4px;
  border-radius: 6px;
  white-space: nowrap;
}
.menu-item.is-active { background: var(--accent); color: #fff; }
.menu-item.is-active .menu-shortcut, .menu-item.is-active .menu-arrow { color: rgba(255, 255, 255, 0.85); }
.menu-item.is-disabled { color: var(--tertiary); }
.menu-item.is-danger:not(.is-active) { color: var(--red); }
.menu-check { width: 14px; display: inline-grid; place-items: center; flex: none; }
.menu-icon { width: 18px; display: inline-grid; place-items: center; flex: none; color: inherit; }
.menu-flag { font-size: 14px; }
.menu-label { flex: 1; overflow: hidden; text-overflow: ellipsis; }
.menu-shortcut { margin-left: 18px; color: var(--secondary); letter-spacing: 0.06em; }
.menu-arrow { margin-left: 12px; color: var(--secondary); }
.menu-sep { height: 1px; margin: 5px 9px; background: var(--separator); }
.menu-header { padding: 4px 10px 2px 22px; font-size: 11px; font-weight: 600; color: var(--secondary); }

/* ---------- Notificações ---------- */

.notif-stack {
  position: absolute;
  top: calc(var(--menubar-h) + 8px);
  right: 10px;
  z-index: 9400;
  width: min(356px, calc(100vw - 20px));
  display: flex;
  flex-direction: column;
  gap: 8px;
  pointer-events: none;
}
.notif {
  position: relative;
  pointer-events: auto;
  display: flex;
  align-items: flex-start;
  gap: 11px;
  padding: 11px 14px 12px 11px;
  border-radius: 20px;
  background: var(--glass-strong);
  box-shadow: inset 0 0 0 0.5px var(--glass-highlight), 0 0 0 0.5px rgba(0, 0, 0, 0.3), 0 10px 30px rgba(0, 0, 0, 0.3);
  -webkit-backdrop-filter: blur(30px) saturate(180%);
  backdrop-filter: blur(30px) saturate(180%);
  transform: translateX(calc(100% + 24px));
  transition: transform 0.5s var(--spring-soft), opacity 0.3s;
}
.notif.is-in { transform: none; }
.notif.is-out { transform: translateX(calc(100% + 24px)); opacity: 0; transition: transform 0.32s var(--ease-in-out), opacity 0.32s; }
.notif-icon { width: 36px; height: 36px; flex: none; border-radius: 8px; }
.notif-icon.is-symbol { display: grid; place-items: center; background: var(--accent); color: #fff; }
.notif-text { flex: 1; min-width: 0; }
.notif-app { font-size: 11px; color: var(--secondary); margin-bottom: 1px; }
.notif-title { font-weight: 600; font-size: 13px; }
.notif-body { font-size: 12.5px; color: var(--label); opacity: 0.85; line-height: 1.32; margin-top: 1px; }
.notif-actions { align-self: center; display: flex; flex-direction: column; gap: 5px; }
.notif-action {
  padding: 4px 11px;
  border-radius: 999px;
  font-size: 12px;
  font-weight: 500;
  background: var(--control-bg);
  white-space: nowrap;
}
.notif-action:hover { background: var(--control-bg-hover); }
.notif-close {
  position: absolute;
  top: -6px;
  left: -6px;
  width: 18px;
  height: 18px;
  display: grid;
  place-items: center;
  border-radius: 50%;
  color: var(--label);
  background: var(--popover-bg);
  box-shadow: var(--shadow-menu);
  opacity: 0;
  transition: opacity 0.15s;
}
.notif:hover .notif-close { opacity: 1; }

/* ---------- Layout compacto (celulares) ---------- */

@media (max-width: 760px) {
  :host { --dock-size: 46px; --menubar-h: 34px; }
  .mb-left .mb-menu:not(.mb-apple):not(.mb-appname) { display: none; }
  .mb-lang span { display: none; }
  .desk-icons { top: calc(var(--menubar-h) + 70px); right: 8px; }
  .desk-icon { width: 78px; }
  .desk-icon-img { width: 54px; height: 54px; }
  .window.is-compact {
    left: 0 !important;
    top: var(--menubar-h) !important;
    width: 100% !important;
    height: calc(100% - var(--menubar-h)) !important;
    border-radius: 18px 18px 0 0;
  }
  .window.is-compact .win-resize { display: none; }
  .window.is-opening.is-compact { animation: win-sheet 0.45s var(--spring-soft); }
  @keyframes win-sheet { from { transform: translateY(40%); opacity: 0; } }
  .dock { bottom: 6px; }
  .dock-label { display: none; }
}

/* Glifo do app na barra de menus, com a marca desenhada como template image. */
.arrowslit-status-mark { display: grid; place-items: center; }
.arrowslit-status-mark svg { display: block; }
.desk-tile { width: 54px !important; height: 54px !important; border-radius: 14px; }
.desk-tile svg { width: 30px; height: 30px; }
.desk-tile.is-settings svg { width: 36px; height: 36px; }

/* No celular, uma janela aberta é tela cheia e o Dock se recolhe. */
@media (max-width: 760px) {
  .dock { transition: transform 0.4s var(--spring-soft), opacity 0.3s; }
  body.has-compact-window .dock { transform: translate(-50%, 140%); opacity: 0; pointer-events: none; }
}

/* No celular só cabem o ícone do Arrowslit, a Central de Controle e a hora,
   como numa barra de menus apertada ao lado do notch. */
@media (max-width: 760px) {
  .menubar { padding: 0 6px; }
  .mb-left { flex: 0 1 auto; }
  .mb-right { min-width: 0; overflow: hidden; }
  .mb-status-area .mb-status:not([data-status="arrowslit"]), .mb-status .arrowslit-status-title { display: none; }
  .mb-lang, .mb-date, .mb-cc { display: none; }
  .mb-item { padding: 0 6px; }
}
@media (max-width: 520px) {
  .mb-appname { display: none; }
}

/* Shell do desktop: fitas no papel de parede, véu de brilho, HUD clássico,
   balão da barra de menus, boas-vindas, novidades e Central de Controle. */

:host {
  /* Theme.spaceGradient: #1A1A1A → #0A0A0A → #000, do canto superior esquerdo ao inferior direito. */
  --space-gradient: linear-gradient(to bottom right, #1a1a1a 0%, #0a0a0a 50%, #000 100%);
}

/* ---------- Fitas de luz no papel de parede ---------- */

.wp-ribbons {
  --rib-edge: #7e86ff;
  --rib-mid: #aab2ff;
  --rib-core: #d6dcff;
  position: absolute;
  inset: -4%;
  pointer-events: none;
  opacity: 0.85;
  will-change: transform;
  animation: rib-drift 52s ease-in-out infinite alternate;
  transition: opacity 1s var(--ease-out);
}
.wp-ribbons-svg { display: block; width: 100%; height: 100%; overflow: visible; }
@keyframes rib-drift {
  from { transform: translate3d(-1.4%, 0.9%, 0) rotate(-0.7deg); }
  to { transform: translate3d(1.4%, -1.1%, 0) rotate(0.7deg); }
}

.wallpaper[data-wallpaper="dusk"] .wp-ribbons { --rib-edge: #ff8f7a; --rib-mid: #ffb59c; --rib-core: #ffe2d2; }
.wallpaper[data-wallpaper="ocean"] .wp-ribbons { --rib-edge: #3fc8ff; --rib-mid: #8be6ff; --rib-core: #d8f7ff; }
.wallpaper[data-wallpaper="graphite"] .wp-ribbons { --rib-edge: #8c8c98; --rib-mid: #c2c2cc; --rib-core: #ededf2; opacity: 0.6; }
:host[data-appearance="light"] .wp-ribbons { --rib-edge: #ffffff; --rib-mid: #ffffff; --rib-core: #ffffff; opacity: 0.95; }

/* ---------- Véu do brilho da tela ---------- */

.shell-dim {
  position: absolute;
  inset: 0;
  z-index: 99990;
  background: #000;
  opacity: 0;
  pointer-events: none;
  transition: opacity 0.12s linear;
}

/* ---------- HUD clássico (volume e brilho) ---------- */

.shell-hud {
  position: fixed;
  left: 50%;
  bottom: max(13%, 104px);
  z-index: 9700;
  width: 200px;
  height: 200px;
  margin-left: -100px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: flex-end;
  gap: 26px;
  padding-bottom: 24px;
  border-radius: 22px;
  color: rgba(255, 255, 255, 0.82);
  background: rgba(34, 34, 40, 0.42);
  box-shadow: inset 0 0 0 0.5px rgba(255, 255, 255, 0.16), 0 0 0 0.5px rgba(0, 0, 0, 0.3), 0 16px 40px rgba(0, 0, 0, 0.25);
  -webkit-backdrop-filter: blur(30px) saturate(170%);
  backdrop-filter: blur(30px) saturate(170%);
  opacity: 0;
  transform: scale(0.96);
  transition: opacity 0.5s ease, transform 0.5s var(--ease-out);
  pointer-events: none;
}
.shell-hud.is-visible { opacity: 1; transform: none; transition: opacity 0.1s ease-out, transform 0.3s var(--spring-soft); }
.shell-hud-symbol { flex: 1; display: grid; place-items: center; padding-top: 18px; }
.shell-hud-symbol .sf { font-size: 76px; }
.shell-hud-level {
  display: flex;
  gap: 1px;
  padding: 1px;
  border-radius: 2px;
  background: rgba(0, 0, 0, 0.42);
}
.shell-hud-level i { width: 8px; height: 6px; background: transparent; transition: background-color 0.08s; }
.shell-hud-level i.is-on { background: rgba(255, 255, 255, 0.92); }
:host[data-appearance="light"] .shell-hud { color: rgba(0, 0, 0, 0.66); background: rgba(236, 236, 240, 0.58); box-shadow: inset 0 0 0 0.5px rgba(255, 255, 255, 0.6), 0 0 0 0.5px rgba(0, 0, 0, 0.12), 0 16px 40px rgba(0, 0, 0, 0.16); }
:host[data-appearance="light"] .shell-hud-level { background: rgba(0, 0, 0, 0.22); }
:host[data-appearance="light"] .shell-hud-level i.is-on { background: rgba(0, 0, 0, 0.72); }

/* ---------- Balão que aponta para a barra de menus ---------- */

.mb-status.shell-pulse { position: relative; animation: shell-glow 1.25s ease-in-out 3; }
.mb-status.shell-pulse::after {
  content: "";
  position: absolute;
  inset: -1px;
  border-radius: 8px;
  pointer-events: none;
  animation: shell-ring 1.25s ease-out 3;
}
@keyframes shell-ring {
  from { box-shadow: 0 0 0 0 rgba(var(--accent-rgb), 0.8); }
  to { box-shadow: 0 0 0 11px rgba(var(--accent-rgb), 0); }
}
@keyframes shell-glow { 50% { background: rgba(255, 255, 255, 0.24); } }
:host[data-appearance="light"] .mb-status.shell-pulse { animation-name: shell-glow-light; }
@keyframes shell-glow-light { 50% { background: rgba(0, 0, 0, 0.12); } }

.shell-callout {
  position: fixed;
  z-index: 9560;
  width: max-content;
  max-width: min(270px, calc(100vw - 16px));
  padding: 10px 13px 11px;
  border-radius: 13px;
  color: var(--label);
  background: var(--popover-bg);
  box-shadow: var(--shadow-menu), inset 0 0 0 0.5px var(--glass-highlight);
  -webkit-backdrop-filter: blur(30px) saturate(180%);
  backdrop-filter: blur(30px) saturate(180%);
  opacity: 0;
  transform: translateY(-6px) scale(0.97);
  transform-origin: top center;
  transition: opacity 0.18s ease-out, transform 0.18s ease-out;
}
.shell-callout.is-visible { opacity: 1; transform: none; transition: opacity 0.2s ease-out, transform 0.45s var(--spring-soft); }
.shell-callout-arrow {
  position: absolute;
  top: -5px;
  width: 11px;
  height: 11px;
  margin-left: -5.5px;
  transform: rotate(45deg);
  border-radius: 2px 0 0 0;
  background: var(--popover-bg);
  box-shadow: -0.5px -0.5px 0 0 var(--glass-highlight);
}
.shell-callout-title { position: relative; font-size: 13px; font-weight: 600; }
.shell-callout-body { position: relative; margin-top: 2px; font-size: 12px; line-height: 1.35; color: var(--secondary); }

/* ---------- Janelas de introdução (boas-vindas e novidades) ---------- */

.intro-window .win-body { background: var(--window-bg); }
.intro-window .tl:disabled,
.intro-window .traffic:hover .tl:disabled { --tl-color: var(--tl-inactive); }
.intro-window .traffic:hover .tl:disabled::after { opacity: 0; }
/* Sobre o herói escuro os botões desativados precisam de contraste próprio. */
.welcome-window:is([data-step="welcome"], [data-step="done"]) .tl:disabled { --tl-color: rgba(255, 255, 255, 0.2); }
.welcome-window:is([data-step="welcome"], [data-step="done"]):not(.is-focused) .traffic:not(:hover) .tl { --tl-color: rgba(255, 255, 255, 0.2); }
/* NSPanel flutuante: as novidades ficam acima das janelas comuns. */
.window.highlights-window { z-index: 4000 !important; }

/* ---------- Boas-vindas (OnboardingView) ---------- */

.wl-root { flex: 1; min-height: 0; display: flex; flex-direction: column; }
.wl-scroll, .hl-scroll {
  flex: 1;
  min-height: 0;
  overflow-x: hidden;
  overflow-y: auto;
  overscroll-behavior: contain;
  scrollbar-width: thin;
  scrollbar-color: color-mix(in srgb, var(--label-strong) 26%, transparent) transparent;
}
.wl-divider { flex: none; height: 1px; background: var(--separator); }
.wl-nav { flex: none; display: flex; align-items: center; gap: 8px; padding: 16px; }
.wl-nav .spacer { flex: 1; }
.wl-nav .btn { min-width: 74px; }
.wl-nav .btn-large { min-width: 96px; }
.wl-dots { display: flex; align-items: center; gap: 6px; }
.wl-dot {
  width: 7px;
  height: 7px;
  border-radius: 999px;
  background: color-mix(in srgb, var(--label-strong) 15%, transparent);
  transition: width 0.32s cubic-bezier(0.3, 1.25, 0.45, 1), background-color 0.25s;
}
.wl-dot.is-current { width: 18px; background: var(--accent); }

.wl-step { display: flex; flex-direction: column; }

.wl-hero {
  position: relative;
  height: 220px;
  flex: none;
  display: grid;
  place-items: center;
  color: #fff;
  background: var(--space-gradient);
  overflow: hidden;
}
.wl-hero.is-tall { height: 300px; }
.wl-hero-stack { display: flex; flex-direction: column; align-items: center; gap: 10px; padding-top: 12px; text-align: center; }
.wl-hero.is-tall .wl-hero-stack { gap: 14px; padding-top: 0; }
.wl-mark { height: auto; user-select: none; -webkit-user-drag: none; pointer-events: none; }
.wl-hero-title { font: 700 26px/1.15 var(--font-display); letter-spacing: -0.01em; color: #fff; }
.wl-hero-body { margin: 0; padding: 0 40px; font-size: 12px; line-height: 1.4; color: rgba(255, 255, 255, 0.85); text-wrap: pretty; }
.wl-hero.is-tall .wl-hero-body { font-size: 12.5px; }

.wl-tile {
  position: relative;
  width: 30px;
  height: 30px;
  flex: none;
  display: grid;
  place-items: center;
  border-radius: 8px;
  color: #fff;
  background: var(--space-gradient);
  box-shadow: inset 0 0 0 0.5px rgba(255, 255, 255, 0.08);
}
.wl-tile.is-large { width: 56px; height: 56px; border-radius: 14px; }
.wl-stack-glyph { font-size: 25px; }

.wl-welcome-body { display: flex; flex-direction: column; gap: 16px; padding: 24px; }
.wl-language { display: flex; align-items: center; gap: 8px; font-size: 13px; }
.wl-language .popup { max-width: 240px; }
.wl-bullet { display: flex; align-items: flex-start; gap: 12px; }
.wl-bullet-text { min-width: 0; display: flex; flex-direction: column; gap: 2px; }
.wl-bullet-title { font-size: 13px; font-weight: 600; color: var(--label); }
.wl-bullet-body { font-size: 11.5px; line-height: 1.38; color: var(--secondary); }

.wl-step-header { display: flex; flex-direction: column; align-items: center; gap: 10px; padding-top: 30px; text-align: center; }
.wl-step-title { margin: 0; font: 700 19px/1.2 var(--font-display); color: var(--label); }
.wl-step-subtitle { margin: 0; padding: 0 48px; font-size: 12px; line-height: 1.4; color: var(--secondary); }

.wl-step-purpose { gap: 16px; }
.wl-step-permissions { gap: 18px; padding-bottom: 6px; }

.wl-presets { display: flex; flex-direction: column; gap: 8px; padding: 0 28px; }
.wl-preset {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px 14px;
  border-radius: 10px;
  text-align: left;
  background: color-mix(in srgb, var(--label-strong) 5%, transparent);
  box-shadow: inset 0 0 0 1px transparent;
  transition: background-color 0.15s ease-out, box-shadow 0.15s ease-out;
}
.wl-preset:hover { background: color-mix(in srgb, var(--label-strong) 7.5%, transparent); }
.wl-preset.is-selected { background: rgba(var(--accent-rgb), 0.12); box-shadow: inset 0 0 0 1px rgba(var(--accent-rgb), 0.45); }
.wl-preset-symbol { width: 26px; flex: none; display: grid; place-items: center; color: var(--accent); }
.wl-preset-text { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 2px; }
.wl-preset-name { font-size: 13px; font-weight: 600; color: var(--label); }
.wl-preset-desc { font-size: 11px; line-height: 1.35; color: var(--secondary); }
.wl-preset-check { flex: none; display: grid; color: var(--accent); opacity: 0; transform: scale(0.5); transition: opacity 0.15s ease-out, transform 0.3s var(--spring); }
.wl-preset.is-selected .wl-preset-check { opacity: 1; transform: none; }

.wl-catalog-header { display: flex; align-items: baseline; gap: 8px; padding: 0 28px; }
.wl-catalog-header .spacer { flex: 1; }
.wl-catalog-title { font-size: 11px; font-weight: 700; letter-spacing: 1px; text-transform: uppercase; color: var(--secondary); }
.wl-count { font-size: 10px; color: var(--tertiary); }

.wl-catalog { display: flex; flex-direction: column; gap: 14px; padding: 0 28px; }
.wl-group { display: flex; flex-direction: column; gap: 7px; }
.wl-group-title { margin: 0; font-size: 10px; font-weight: 600; color: var(--secondary); }
.wl-feature {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px 11px;
  border-radius: 10px;
  text-align: left;
  background: color-mix(in srgb, var(--label-strong) 3.5%, transparent);
  transition: background-color 0.15s ease-out;
}
.wl-feature:hover { background: color-mix(in srgb, var(--label-strong) 6%, transparent); }
.wl-feature.is-selected { background: rgba(var(--accent-rgb), 0.09); }
.wl-feature.is-selected:hover { background: rgba(var(--accent-rgb), 0.13); }
.wl-feature-tile {
  position: relative;
  width: 32px;
  height: 32px;
  flex: none;
  display: grid;
  place-items: center;
  border-radius: 8px;
  color: var(--secondary);
  background: color-mix(in srgb, var(--secondary) 16%, transparent);
  transition: color 0.15s ease-out;
}
.wl-feature-tile::before {
  content: "";
  position: absolute;
  inset: 0;
  border-radius: inherit;
  background: var(--space-gradient);
  box-shadow: inset 0 0 0 0.5px rgba(255, 255, 255, 0.08);
  opacity: 0;
  transition: opacity 0.15s ease-out;
}
.wl-feature-tile .sf { position: relative; }
.wl-feature.is-selected .wl-feature-tile { color: #fff; }
.wl-feature.is-selected .wl-feature-tile::before { opacity: 1; }
.wl-feature-text { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 2px; }
.wl-feature-title { font-size: 12.5px; font-weight: 600; color: var(--label); }
.wl-feature-desc {
  display: -webkit-box;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
  overflow: hidden;
  font-size: 10px;
  line-height: 1.35;
  color: var(--secondary);
}
.wl-feature-check { flex: none; display: grid; margin-left: 8px; }
.wl-feature-check .sf { grid-area: 1 / 1; transition: opacity 0.15s ease-out, transform 0.3s var(--spring); }
.wl-feature-check .is-on { color: var(--accent); opacity: 0; transform: scale(0.6); }
.wl-feature-check .is-off { color: color-mix(in srgb, var(--secondary) 45%, transparent); }
.wl-feature.is-selected .wl-feature-check .is-on { opacity: 1; transform: none; }
.wl-feature.is-selected .wl-feature-check .is-off { opacity: 0; }

.wl-skip { margin: 0; padding: 0 36px 12px; font-size: 10px; line-height: 1.4; text-align: center; color: var(--secondary); }

.wl-card {
  display: flex;
  flex-direction: column;
  gap: 12px;
  margin: 0 28px;
  padding: 16px;
  border-radius: 12px;
  background: color-mix(in srgb, var(--label-strong) 5%, transparent);
}
.wl-card-title { margin: 0; font-size: 13px; font-weight: 700; color: var(--label); }
.wl-perm-none { display: flex; align-items: center; gap: 6px; font-size: 13px; color: var(--secondary); }
.wl-perm-divider { height: 1px; margin: 12px 0; background: var(--separator); }
.wl-perm { display: flex; flex-direction: column; gap: 8px; }
.wl-perm-head { display: flex; align-items: center; gap: 8px; font-size: 13px; color: var(--label); }
.wl-perm-head .spacer { flex: 1; }
.wl-perm-status { font-size: 10px; }
.wl-perm-head.is-granted .wl-perm-icon, .wl-perm-head.is-granted .wl-perm-status { color: var(--green); }
.wl-perm-head.is-missing .wl-perm-icon, .wl-perm-head.is-missing .wl-perm-status { color: var(--orange); }
.wl-perm-head.just-granted .wl-perm-icon { animation: wl-pop 0.45s var(--spring); }
@keyframes wl-pop { from { transform: scale(0.4); } }
.wl-perm-actions { display: flex; flex-wrap: wrap; gap: 8px; }
.wl-perm-explain, .wl-perm-used { margin: 0; font-size: 10px; line-height: 1.4; }
.wl-perm-explain { color: var(--secondary); }
.wl-perm-used { color: var(--tertiary); }

.wl-other .disclosure-head { align-items: flex-start; gap: 10px; }
.wl-other .disclosure-chevron { margin-top: 3px; }
.wl-other-head { display: flex; flex-direction: column; gap: 3px; min-width: 0; }
.wl-other-caption { font-size: 10px; font-weight: 400; line-height: 1.35; color: var(--secondary); }
.wl-other .disclosure-body { padding-top: 14px; }
.wl-portal { display: flex; flex-direction: column; }

.wl-footnote { margin: 0; padding: 0 36px 10px; font-size: 10px; line-height: 1.4; text-align: center; color: var(--tertiary); }

.wl-done-hints { display: flex; flex-direction: column; align-items: center; gap: 22px; padding: 36px 60px 18px; }
.wl-done-hint { display: flex; flex-direction: column; align-items: center; gap: 10px; color: var(--secondary); text-align: center; }
.wl-done-hint p { margin: 0; font-size: 12px; line-height: 1.4; }

/* ---------- Novidades (UpdateHighlightsView) ---------- */

.hl-root {
  flex: 1;
  min-height: 0;
  width: 100%;
  max-width: 548px;
  margin: 0 auto;
  padding: 24px;
  display: flex;
  flex-direction: column;
  gap: 16px;
}
.hl-header { flex: none; height: 42px; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 4px; }
.hl-title { margin: 0; font: 600 17px/1.2 var(--font-display); color: var(--label); }
.hl-version { font-size: 10px; color: var(--secondary); }
.hl-scroll { display: flex; flex-direction: column; gap: 16px; }
/* A arte ocupa até 451×400 (o tamanho do GIF no app) e encolhe junto com o painel. */
.hl-art { position: relative; flex: 0 1 auto; width: 100%; aspect-ratio: 451 / 400; min-height: 80px; max-height: 400px; }
.hl-caption { flex: none; margin: 0; font-size: 12px; line-height: 1.4; text-align: center; color: var(--secondary); }
.hl-footer { flex: none; height: 32px; display: flex; align-items: center; gap: 8px; }
.hl-footer .spacer { flex: 1; }

/* ---------- A ilha animada das novidades (cena de 451×400) ---------- */

.it-frame { position: absolute; inset: 0; overflow: hidden; }
.it-scene {
  --ease-island: cubic-bezier(0.3, 1.18, 0.42, 1);
  position: absolute;
  left: 50%;
  top: 50%;
  width: 451px;
  height: 400px;
  overflow: hidden;
  border-radius: 12px;
  transform: translate(-50%, -50%) scale(var(--k, 1));
  background: linear-gradient(180deg, #5d79b3 0%, #8e94c4 24%, #c6a7c0 42%, #f0b48a 58%, #f6c58f 63%);
  box-shadow: 0 0 0 0.5px var(--separator);
  font-family: var(--font);
  contain: strict;
}
.it-land { position: absolute; inset: 0; width: 100%; height: 100%; }
.it-menubar {
  position: absolute;
  inset: 0 0 auto;
  height: 15px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 10px;
  background: rgba(255, 255, 255, 0.14);
}
.it-menubar span { display: flex; gap: 6px; }
.it-menubar i { width: 14px; height: 3px; border-radius: 2px; background: rgba(0, 0, 0, 0.32); }
.it-menubar-left i:first-child { width: 6px; }

.it-island {
  position: absolute;
  top: 0;
  left: 50%;
  width: 96px;
  height: 19px;
  overflow: hidden;
  color: #fff;
  background: #000;
  border-radius: 0 0 9px 9px;
  box-shadow: 0 4px 14px rgba(0, 0, 0, 0);
  transform: translateX(-50%);
  transition: width 0.5s var(--ease-island), height 0.5s var(--ease-island), border-radius 0.4s ease, box-shadow 0.4s ease;
}
.it-scene[data-stage="hover"] .it-island { width: 106px; height: 23px; }
.it-scene:is([data-stage="open"], [data-stage="aim"], [data-stage="press"]) .it-island {
  width: 318px;
  height: 212px;
  border-radius: 0 0 20px 20px;
  box-shadow: 0 10px 28px rgba(0, 0, 0, 0.35);
}
.it-scene:is([data-stage="timer"], [data-stage="aim-start"], [data-stage="start"]) .it-island {
  width: 318px;
  height: 118px;
  border-radius: 0 0 20px 20px;
  box-shadow: 0 10px 28px rgba(0, 0, 0, 0.35);
}
.it-scene[data-stage="activity"] .it-island { width: 174px; height: 19px; }

.it-page {
  position: absolute;
  top: 0;
  left: 50%;
  width: 318px;
  opacity: 0;
  transform: translateX(-50%) scale(0.96);
  transform-origin: top center;
  transition: opacity 0.16s ease, transform 0.3s ease;
}
.it-scene:is([data-stage="open"], [data-stage="aim"], [data-stage="press"]) .it-grid-page,
.it-scene:is([data-stage="timer"], [data-stage="aim-start"], [data-stage="start"]) .it-timer-page {
  opacity: 1;
  transform: translateX(-50%);
  transition: opacity 0.25s ease 0.14s, transform 0.4s var(--ease-island) 0.1s;
}
.it-head { height: 24px; display: flex; align-items: center; justify-content: space-between; padding: 0 12px; color: rgba(255, 255, 255, 0.55); }
.it-head span { display: flex; align-items: center; gap: 8px; }
.it-head-right { gap: 2px !important; }
.it-grid { display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); gap: 5px; padding: 2px 8px 8px; }
.it-tile {
  position: relative;
  height: 52px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 2px;
  padding: 0 2px;
  border-radius: 9px;
  background: rgba(255, 255, 255, 0.07);
  box-shadow: inset 0 0 0 0.5px rgba(255, 255, 255, 0.09);
  transition: background-color 0.2s, box-shadow 0.2s, transform 0.2s;
}
.it-tile .sf { color: #fff; margin-bottom: 1px; }
.it-tile.tone-pink .sf { color: #ff375f; }
.it-tile.tone-red .sf { color: #ff453a; }
.it-tile.tone-orange .sf { color: #ff9f0a; }
.it-tile-label {
  max-width: 100%;
  display: -webkit-box;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
  overflow: hidden;
  font-size: 6.6px;
  font-weight: 600;
  line-height: 1.1;
  text-align: center;
}
.it-tile-key { font-size: 5.4px; font-weight: 500; letter-spacing: 0.02em; color: rgba(255, 255, 255, 0.42); }
.it-tile-check {
  position: absolute;
  top: 4px;
  right: 4px;
  width: 8px;
  height: 8px;
  display: grid;
  place-items: center;
  border-radius: 50%;
  color: #000;
  background: rgba(255, 255, 255, 0.7);
  opacity: 0;
  transition: opacity 0.2s;
}
.it-scene:is([data-stage="aim"], [data-stage="press"]) .it-tile.is-hot { background: rgba(255, 255, 255, 0.15); }
.it-scene[data-stage="press"] .it-tile.is-hot { box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.55); transform: scale(0.96); }
.it-scene[data-stage="press"] .it-tile.is-hot .it-tile-check { opacity: 1; }

.it-timer-page .it-head { color: #fff; }
.it-title { font-size: 10px; font-weight: 700; }
.it-timer-page .it-head-right { color: rgba(255, 255, 255, 0.55); }
.it-tabs { position: relative; height: 22px; display: flex; align-items: center; gap: 12px; padding: 0 14px; }
.it-tab { position: relative; font-size: 7.4px; font-weight: 600; color: rgba(255, 255, 255, 0.48); }
.it-tab.is-current { color: #fff; }
.it-tab.is-current::after { content: ""; position: absolute; left: 0; right: 0; bottom: -4px; height: 1.5px; border-radius: 1px; background: #ff9f0a; }
.it-start {
  position: absolute;
  right: 12px;
  top: 2px;
  padding: 4px 11px;
  border-radius: 999px;
  font-size: 8px;
  font-weight: 700;
  color: #ff9f0a;
  background: rgba(255, 159, 10, 0.22);
  transition: transform 0.15s ease, background-color 0.15s;
}
.it-scene[data-stage="start"] .it-start { transform: scale(0.9); background: rgba(255, 159, 10, 0.4); }
.it-ruler { position: absolute; left: 16px; top: 52px; width: 216px; height: 50px; }
.it-ruler-numbers { position: relative; height: 11px; }
.it-ruler-numbers span { position: absolute; top: 0; transform: translateX(-50%); font-size: 6.6px; font-weight: 600; color: #ff9f0a; opacity: 0.9; }
.it-ruler-ticks { display: flex; justify-content: space-between; height: 24px; margin-top: 3px; }
.it-ruler-ticks i { width: 2px; border-radius: 1px; background: rgba(255, 255, 255, 0.28); }
.it-ruler-ticks i.is-on { background: rgba(255, 159, 10, 0.85); }
.it-ruler-marker {
  position: absolute;
  left: calc(14 / 26 * 100%);
  top: 41px;
  width: 0;
  height: 0;
  margin-left: -3px;
  border: 3.5px solid transparent;
  border-bottom: 5px solid #ff9f0a;
  border-top-width: 0;
}
.it-clock { position: absolute; right: 16px; top: 66px; font-size: 19px; font-weight: 300; font-variant-numeric: tabular-nums; color: #ff9f0a; }

.it-wings {
  position: absolute;
  top: 0;
  left: 50%;
  width: 174px;
  height: 19px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 10px;
  color: #ff9f0a;
  font-size: 8px;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
  opacity: 0;
  transform: translateX(-50%);
  transition: opacity 0.2s ease;
}
.it-scene[data-stage="activity"] .it-wings { opacity: 1; transition: opacity 0.3s ease 0.3s; }

.it-float {
  position: absolute;
  top: 18px;
  width: 22px;
  height: 22px;
  display: grid;
  place-items: center;
  border-radius: 50%;
  color: #fff;
  background: #000;
  box-shadow: 0 3px 8px rgba(0, 0, 0, 0.3);
  opacity: 0;
  transform: scale(0.3);
  transition: opacity 0.18s ease, transform 0.25s ease, top 0.5s var(--ease-island);
}
.it-float.is-left { left: calc(50% - 159px - 30px); }
.it-float.is-right { left: calc(50% + 159px + 8px); }
.it-float.n2 { top: 46px; }
.it-float.n3 { top: 74px; }
.it-float.is-bottom { left: calc(50% - 11px); top: 222px; }
.it-scene:is([data-stage="timer"], [data-stage="aim-start"], [data-stage="start"]) .it-float.is-bottom { top: 128px; }
.it-scene:is([data-stage="open"], [data-stage="aim"], [data-stage="press"], [data-stage="timer"], [data-stage="aim-start"], [data-stage="start"]) .it-float {
  opacity: 1;
  transform: none;
  transition: opacity 0.25s ease 0.18s, transform 0.45s var(--spring) 0.18s, top 0.5s var(--ease-island);
}
.it-scene:is([data-stage="open"]) .it-float.n2 { transition-delay: 0.24s; }
.it-scene:is([data-stage="open"]) .it-float.n3 { transition-delay: 0.3s; }

.it-pointer {
  position: absolute;
  left: 0;
  top: 0;
  width: 13px;
  height: 19px;
  transform: translate(300px, 262px);
  transition: transform 0.75s cubic-bezier(0.45, 0, 0.2, 1);
  filter: drop-shadow(0 1px 1.5px rgba(0, 0, 0, 0.35));
}
.it-pointer-glyph { display: block; width: 13px; height: 19px; transition: transform 0.12s ease; transform-origin: 2px 2px; }
.it-scene[data-stage="hover"] .it-pointer { transform: translate(232px, 8px); }
.it-scene[data-stage="open"] .it-pointer { transform: translate(250px, 96px); }
.it-scene:is([data-stage="aim"], [data-stage="press"]) .it-pointer { transform: translate(288px, 112px); }
.it-scene[data-stage="timer"] .it-pointer { transform: translate(300px, 72px); }
.it-scene:is([data-stage="aim-start"], [data-stage="start"]) .it-pointer { transform: translate(350px, 34px); }
.it-scene[data-stage="activity"] .it-pointer { transform: translate(318px, 196px); transition-duration: 1.1s; }
.it-scene:is([data-stage="press"], [data-stage="start"]) .it-pointer-glyph { transform: scale(0.82); }

/* ---------- Central de Controle ---------- */

.cc {
  --cc-module: rgba(255, 255, 255, 0.075);
  --cc-stroke: rgba(255, 255, 255, 0.09);
  --cc-circle: rgba(255, 255, 255, 0.14);
  --cc-track: rgba(255, 255, 255, 0.13);
  --cc-fill: rgba(255, 255, 255, 0.94);
  --cc-icon: rgba(0, 0, 0, 0.5);
  position: fixed;
  top: calc(var(--menubar-h) + 6px);
  right: 10px;
  z-index: 9550;
  width: 326px;
  max-height: calc(100vh - var(--menubar-h) - 16px);
  overflow-y: auto;
  padding: 12px;
  border-radius: 26px;
  color: var(--label);
  background: rgba(36, 36, 42, 0.46);
  box-shadow: inset 0 0 0 0.5px rgba(255, 255, 255, 0.16), 0 0 0 0.5px rgba(0, 0, 0, 0.45), 0 22px 60px rgba(0, 0, 0, 0.38);
  -webkit-backdrop-filter: blur(40px) saturate(180%);
  backdrop-filter: blur(40px) saturate(180%);
  opacity: 0;
  transform: translateY(-8px) scale(0.96);
  transform-origin: top right;
  transition: opacity 0.16s ease-out, transform 0.16s ease-out;
  scrollbar-width: none;
}
.cc::-webkit-scrollbar { display: none; }
.cc.is-open { opacity: 1; transform: none; transition: opacity 0.2s ease-out, transform 0.5s var(--spring-soft); }
.cc.is-closing { opacity: 0; transform: scale(0.97); pointer-events: none; transition: opacity 0.16s ease-in, transform 0.16s ease-in; }
:host[data-appearance="light"] .cc {
  --cc-module: rgba(255, 255, 255, 0.55);
  --cc-stroke: rgba(0, 0, 0, 0.05);
  --cc-circle: rgba(0, 0, 0, 0.08);
  --cc-track: rgba(0, 0, 0, 0.17);
  --cc-fill: #fff;
  --cc-icon: rgba(0, 0, 0, 0.45);
  background: rgba(242, 242, 247, 0.55);
  box-shadow: inset 0 0 0 0.5px rgba(255, 255, 255, 0.7), 0 0 0 0.5px rgba(0, 0, 0, 0.14), 0 22px 60px rgba(0, 0, 0, 0.2);
}

.cc-grid { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 10px; }
.cc-module {
  min-width: 0;
  padding: 10px;
  border-radius: 18px;
  text-align: left;
  background: var(--cc-module);
  box-shadow: inset 0 0 0 0.5px var(--cc-stroke);
}
.cc-connect { grid-column: span 2; grid-row: span 2; display: flex; flex-direction: column; justify-content: space-around; gap: 6px; }
.cc-tile { grid-column: span 2; display: flex; align-items: center; gap: 8px; transition: background-color 0.15s; }
.cc-tile:hover { background: color-mix(in srgb, var(--cc-module), var(--label-strong) 5%); }
.cc-slider-module, .cc-media { grid-column: span 4; }

.cc-row { width: 100%; display: flex; align-items: center; gap: 8px; text-align: left; border-radius: 10px; }
.cc-circle {
  width: 28px;
  height: 28px;
  flex: none;
  display: grid;
  place-items: center;
  border-radius: 50%;
  color: var(--label);
  background: var(--cc-circle);
  transition: background-color 0.2s ease, color 0.2s ease, transform 0.25s var(--spring);
}
.cc-row:active .cc-circle, .cc-tile:active .cc-circle { transform: scale(0.9); }
.is-on > .cc-circle { color: #fff; background: var(--accent); }
.cc-focus.is-on > .cc-circle { background: var(--indigo); }
.cc-glyph { width: 15px; height: 15px; display: block; }
.cc-row-text { min-width: 0; display: flex; flex-direction: column; }
.cc-row-label, .cc-row-status { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.cc-row-label { font-size: 12px; font-weight: 600; line-height: 1.25; color: var(--label); }
.cc-row-status { font-size: 10.5px; line-height: 1.25; color: var(--secondary); }
.cc-row-status:empty { display: none; }

.cc-module-title { margin: 0 0 7px 3px; font-size: 12px; font-weight: 600; color: var(--label); }
.cc-slider {
  --p: 0.5;
  position: relative;
  height: 24px;
  border-radius: 999px;
  background: var(--cc-track);
  touch-action: none;
}
.cc-slider:focus-visible { outline: none; box-shadow: 0 0 0 3px rgba(var(--accent-rgb), 0.45); }
.cc-slider-fill {
  position: absolute;
  inset: 0 auto 0 0;
  width: calc(12px + var(--p) * (100% - 24px));
  min-width: 24px;
  border-radius: 999px;
  background: var(--cc-fill);
}
.cc-slider-knob {
  position: absolute;
  top: 0;
  left: calc(var(--p) * (100% - 24px));
  width: 24px;
  height: 24px;
  border-radius: 50%;
  background: #fff;
  box-shadow: 0 0 0 0.5px rgba(0, 0, 0, 0.14), 0 1px 4px rgba(0, 0, 0, 0.32);
  transition: transform 0.15s ease;
}
.cc-slider.is-dragging .cc-slider-knob { transform: scale(1.06); }
.cc-slider-icon { position: absolute; left: 7px; top: 50%; z-index: 1; transform: translateY(-50%); color: var(--cc-icon); pointer-events: none; }

.cc-media { display: flex; align-items: center; gap: 10px; }
.cc-art {
  width: 40px;
  height: 40px;
  flex: none;
  display: grid;
  place-items: center;
  overflow: hidden;
  border-radius: 9px;
  color: #fff;
  background: linear-gradient(135deg, #fc5c7d, #6a82fb);
}
.cc-art.has-artwork { background: var(--cc-circle); }
.cc-art img { width: 100%; height: 100%; object-fit: cover; }
.cc-media-text { flex: 1; min-width: 0; display: flex; flex-direction: column; }
.cc-media-title, .cc-media-artist { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.cc-media-title { font-size: 12.5px; font-weight: 600; color: var(--label); }
.cc-media-artist { font-size: 11px; color: var(--secondary); }
.cc-play {
  width: 34px;
  height: 34px;
  flex: none;
  display: grid;
  place-items: center;
  border-radius: 50%;
  color: var(--label);
  transition: background-color 0.15s, transform 0.2s var(--spring);
}
.cc-play:hover:not(:disabled) { background: var(--hover); }
.cc-play:active:not(:disabled) { transform: scale(0.9); }
.cc-play:disabled { color: var(--tertiary); }
.cc-skip { width: 30px; margin-left: -6px; }

/* ---------- Telas pequenas ---------- */

@media (max-width: 760px) {
  /* As folhas de introdução ocupam a tela; o Dock sai do caminho dos botões. */
  body.has-intro-sheet .dock {
    opacity: 0;
    visibility: hidden;
    transform: translate(-50%, 24px);
    transition: opacity 0.2s, transform 0.3s var(--ease-out), visibility 0s 0.3s;
  }
  body.has-intro-sheet .dock-shelf { pointer-events: none; }
  .wl-hero { height: 200px; }
  .wl-hero.is-tall { height: 260px; }
  .wl-step-subtitle { padding: 0 28px; }
  .wl-presets, .wl-catalog, .wl-catalog-header { padding-left: 16px; padding-right: 16px; }
  .wl-card { margin: 0 16px; }
  .wl-done-hints { padding: 30px 32px 18px; }
  .wl-nav { padding: 14px 16px calc(14px + env(safe-area-inset-bottom)); }
  .wl-nav .btn { min-width: 0; }
  .hl-root { padding: 18px 16px calc(16px + env(safe-area-inset-bottom)); }
  .hl-scroll > :first-child { margin-top: auto; }
  .hl-scroll > :last-child { margin-bottom: auto; }

  .cc { left: 8px; right: 8px; width: auto; border-radius: 24px; }
  .shell-hud { width: 160px; height: 160px; margin-left: -80px; bottom: 18%; gap: 20px; padding-bottom: 20px; }
  .shell-hud-symbol .sf { font-size: 60px; }
  .shell-hud-level i { width: 6.5px; height: 5px; }
}

@media (prefers-reduced-motion: reduce) {
  .wp-ribbons { animation: none; }
}

/* --- transplant patches (shadow-scoped) --- */
:host { display: block; font-family: var(--font, -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif); }
.menubar { pointer-events: auto; }
.menu, .menu *, .cc, .cc * { pointer-events: auto; }
</style>`;
  document.body.appendChild(host);

  bar = h("header.menubar", { role: "menubar" });
  root.append(bar);

  statusArea = h("div.mb-status-area");
  langButton = h("button.mb-item.mb-lang", { on: { click: event => { event.stopPropagation(); toggleLanguageMenu(); } } });
  clockButton = h("button.mb-item.mb-clock", { "aria-live": "off" });
  ccButton = h("button.mb-item.mb-cc", {
    "aria-label": shellText(LANG).controlCenter,
    on: { click: event => { event.stopPropagation(); toggleControlCenter(ccButton); } },
  }, sf("switch.2", { size: 15 }));
  const right = h("div.mb-right", statusArea, langButton, ccButton, clockButton);
  left = h("div.mb-left");
  bar.replaceChildren(left, right);

  const statusButton = h("button.mb-item.mb-status.arrowslit-status.arrowslit-status-main", {
    "data-status": "arrowslit",
    title: "Arrowslit",
    on: {
      pointerdown: event => { if (event.button === 0) event.stopPropagation(); },
      click: event => { event.stopPropagation(); showContextMenu(statusButton); },
      contextmenu: event => { event.preventDefault(); showContextMenu(statusButton); },
    },
  }, h("span.arrowslit-status-item", (() => { const g = h("span.arrowslit-status-mark"); g.innerHTML = '<svg viewBox="0 0 16 18" width="13" height="15" fill="currentColor" aria-hidden="true"><rect x="6.5" y=".5" width="3" height="14" rx="1.5"/><rect x="2.5" y="14.5" width="11" height="3" rx="1.5"/></svg>'; return g; })()));
  statusArea.append(statusButton);

  renderLeft();
  renderLanguage();
  tick();
  setInterval(tick, 1000);
  loadSymbols();

  syncAppearance();
  new MutationObserver(syncAppearance).observe(document.documentElement, { attributes: true, attributeFilter: ["data-mode"] });
}

const pageStyle = document.createElement("style");
pageStyle.textContent = `
  #arrowslit-menubar-host { position: fixed; top: 0; left: 0; right: 0; height: 32px; z-index: 300; pointer-events: none; transition: opacity .35s ease; }
`;
document.head.appendChild(pageStyle);

if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", boot);
else boot();
