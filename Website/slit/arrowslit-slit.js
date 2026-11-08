/* ============================================================================
   Arrowslit slit — 1:1 web replica of the Arrowslit notch, built from the
   app's own source of truth (Sources/ArrowslitKit) and the owner's screen
   recording of the app touring every nook page. Arrowslit is this site
   owner's GPL-3.0 app; the module re-hosts its notch behavior on the web.

   Geometry (IslandMetrics + measured): notch 187.5×32; ears 47; compact
   281.5×32 top / 269.5 bottom, flare 6, radius 12; nook 560×178; player 390;
   clockRunning 360×124; alert panels radius 12; expanded radius 30, flare 10.
   Theme: panel #090909, raised #161616, amber #FF9F0A, bone #fff, muted 55%,
   faint 38%, hairline 10%, green #30D158, red #FF453A, blue #0A84FF,
   yellow #FFD60A. Motion: open spring .48/.8, close smooth .42, press
   scale .9 + opacity .7, hover .15.

   The showcase: Arrowslit's live services rest in the strip (call, music,
   agents) while a quiet-gated tour opens the nook on each page — Home,
   Calendar, Sports, AI Agents, Clipboard, Grid, Stats, Keep Awake,
   Scratchpad, Reminders, Files — and the app's own alert cycle fires between
   tours. The Timer/Stopwatch page is reachable by hand but skipped by the
   automated tour.
   ========================================================================== */

const SVG_NS = "http://www.w3.org/2000/svg";
const T_AMBER = "#FF9F0A", T_BLUE = "#0A84FF", T_GREEN = "#30D158", T_RED = "#FF453A", T_YELLOW = "#FFD60A";

/* ----------------------------------------------------- exact app metrics */
const NOTCH = { w: 187.5, h: 32 };
const APPEARANCE = { width: 200, height: 32 };
const SLOT = Math.round(APPEARANCE.height * 1.15);
const EAR = Math.max(Math.round(SLOT * 0.8), Math.round(SLOT + (APPEARANCE.width - 180) / 2)); // 47
const COMPACT_W = NOTCH.w + 2 * EAR;                                            // 281.5
const FLARE_COMPACT = 6, FLARE_EXPANDED = 10;
const R_COMPACT = 12, R_ALERT = 12, R_EXPANDED = 30;
const NOOK = { w: 560, h: 178, body: 120, topInset: 10, bottomPad: 14 };
const PLAYER = { w: 390, h: 218, content: 140 };
const ALERT_EAR = 128, NAMED_ALERT_EAR = 156;
const HOVER_GROWTH = { w: 3, h: 2 };
const CLOCKRUN = { w: 360, h: 124 };

/* ------------------------------------------------------------ ArrowTheme */
const C = {
  panel: "#090909", raised: "#161616", amber: T_AMBER, amberSoft: "rgba(255,159,10,.16)",
  bone: "#fff", muted: "rgba(255,255,255,.55)", faint: "rgba(255,255,255,.38)",
  hairline: "rgba(255,255,255,.1)", green: T_GREEN, red: T_RED, blue: T_BLUE, yellow: T_YELLOW,
};

/* ------------------------------------------------------------- SF icons */
const S = (d) => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${d}</svg>`;
const F = (d) => `<svg viewBox="0 0 24 24" fill="currentColor">${d}</svg>`;
const ICONS = {
  timer: S('<circle cx="12" cy="13.5" r="7.5"/><path d="M12 13.5V9.5M9.5 2.5h5"/>'),
  "pause.circle": S('<circle cx="12" cy="12" r="8.6"/><rect x="9.4" y="8.6" width="1.9" height="6.8" rx=".8" fill="currentColor" stroke="none"/><rect x="12.7" y="8.6" width="1.9" height="6.8" rx=".8" fill="currentColor" stroke="none"/>'),
  "checkmark.circle": S('<circle cx="12" cy="12" r="8.6"/><path d="m8.4 12.3 2.5 2.5 4.9-5.2"/>'),
  stopwatch: S('<circle cx="12" cy="13.5" r="7.3"/><path d="M12 13.5V10M10 2.6h4"/>'),
  "cup.and.saucer.fill": F('<path d="M4.5 8h12v5a5.4 5.4 0 0 1-5.4 5.4H9.9A5.4 5.4 0 0 1 4.5 13zM16.5 9.5h1.6a2.9 2.9 0 0 1 0 5.8h-1.4M4 20.4h13" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>'),
  infinity: S('<path d="M6.4 8.2c-2.1 0-3.7 1.7-3.7 3.8s1.6 3.8 3.7 3.8c3.4 0 5.8-7.6 11.2-7.6 2.1 0 3.7 1.7 3.7 3.8s-1.6 3.8-3.7 3.8c-3.4 0-5.8-7.6-11.2-7.6z" fill="none" stroke-width="1.8"/>'),
  "arrow.down.circle.fill": F('<path d="M12 1.8a10.2 10.2 0 1 0 0 20.4 10.2 10.2 0 0 0 0-20.4zm.9 5v6.5l2.7-2.7 1.2 1.2-4.3 4.3-4.3-4.3 1.2-1.2 2.7 2.7V6.8z"/>'),
  "battery.100percent.bolt": '<svg viewBox="0 0 30 14" fill="none"><rect x="1" y="1.5" width="22" height="11" rx="3.4" stroke="currentColor" stroke-width="1.6"/><path d="M12.6 3.2 9 8h2.6l-.9 4 4-5.4h-2.6z" fill="currentColor"/><path d="M25.2 5v4" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/></svg>',
  gauge: S('<circle cx="12" cy="13" r="8.4"/><path d="M12 13 8.6 9.6"/><circle cx="12" cy="13" r="1.4" fill="currentColor" stroke="none"/>'),
  eye: S('<path d="M2.4 12s3.6-6.4 9.6-6.4S21.6 12 21.6 12s-3.6 6.4-9.6 6.4S2.4 12 2.4 12z"/><circle cx="12" cy="12" r="2.8" fill="currentColor" stroke="none"/>'),
  "phone.fill": F('<path d="M6.4 3.2h3l1.5 3.8-2 1.5a10.6 10.6 0 0 0 4.9 4.9l1.5-2 3.8 1.5v3a1.9 1.9 0 0 1-2.1 1.9A15.6 15.6 0 0 1 4.5 5.3a1.9 1.9 0 0 1 1.9-2.1z"/>'),
  "speaker.wave.2.fill": F('<path d="M4.9 14.6h2.9l4.4 4c.5.4 1.2.1 1.2-.6V6c0-.7-.7-1-1.2-.6l-4.4 4H4.9c-.9 0-1.6.7-1.6 1.6v2c0 .9.7 1.6 1.6 1.6z"/><path d="M16.8 8.6a5 5 0 0 1 0 6.8M19.3 6.2a8.4 8.4 0 0 1 0 11.6" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/>'),
  "pause.fill": F('<rect x="6.5" y="5" width="3.6" height="14" rx="1"/><rect x="13.9" y="5" width="3.6" height="14" rx="1"/>'),
  "play.fill": F('<path d="M7.5 5.2v13.6L19 12z"/>'),
  "arrow.up.left.and.arrow.down.right": S('<path d="M4 10V4h6M4 4l6 6M20 14v6h-6M20 20l-6-6"/>'),
  house: S('<path d="M4 11 12 4l8 7"/><path d="M6 10v9h12v-9"/>'),
  tray: S('<path d="M4 5h16v10H4z"/><path d="M4 15l3-4 3 3 4-5 6 6"/>'),
  clip: S('<rect x="6" y="4" width="12" height="17" rx="2"/><path d="M9 4.5V3h6v1.5"/>'),
  grid: S('<rect x="4" y="4" width="6.5" height="6.5" rx="1.6"/><rect x="13.5" y="4" width="6.5" height="6.5" rx="1.6"/><rect x="4" y="13.5" width="6.5" height="6.5" rx="1.6"/><rect x="13.5" y="13.5" width="6.5" height="6.5" rx="1.6"/>'),
  gear: S('<circle cx="12" cy="12" r="3.2"/><path d="M12 2.8v2.7M12 18.5v2.7M2.8 12h2.7M18.5 12h2.7M5.5 5.5l1.9 1.9M16.6 16.6l1.9 1.9M5.5 18.5l1.9-1.9M16.6 7.4l1.9-1.9"/>'),
  cal: S('<rect x="4" y="5.5" width="16" height="15" rx="2.5"/><path d="M4 10h16M8.5 3.5v3M15.5 3.5v3"/>'),
  vol: F('<path d="M4.9 14.6h2.9l4.4 4c.5.4 1.2.1 1.2-.6V6c0-.7-.7-1-1.2-.6l-4.4 4H4.9c-.9 0-1.6.7-1.6 1.6v2c0 .9.7 1.6 1.6 1.6z"/><path d="M16.8 8.6a5 5 0 0 1 0 6.8M19.3 6.2a8.4 8.4 0 0 1 0 11.6" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/>'),
  sun: S('<circle cx="12" cy="12" r="4.4" fill="currentColor" stroke="none"/><path d="M12 2.6v2.4M12 19v2.4M2.6 12h2.4M19 12h2.4M5.3 5.3l1.7 1.7M17 17l1.7 1.7M5.3 18.7 7 17M17 7l1.7-1.7"/>'),
  bell: F('<path d="M12 2.6a1.6 1.6 0 0 1 1.6 1.6v.7a6.6 6.6 0 0 1 5 6.4v4l1.8 2.3v1H3.6v-1l1.8-2.3v-4a6.6 6.6 0 0 1 5-6.4v-.7A1.6 1.6 0 0 1 12 2.6zM9.4 19.6h5.2a2.6 2.6 0 0 1-5.2 0z"/>'),
  "arrow.down": S('<path d="M12 4v11m0 0-4.2-4.2M12 15l4.2-4.2M5 19.4h14"/>'),
  bolt: F('<path d="M13.4 2 4.6 13.4h6.3l-.9 8.4L19.4 10h-6.2z"/>'),
  xmark: S('<path d="m6.5 6.5 11 11M17.5 6.5l-11 11"/>'),
  doc: S('<path d="M6.5 2.8h7l4.5 4.5v14h-11.5z"/><path d="M13.5 2.8v4.7h4.5"/>'),
  phones: S('<path d="M4 14v-2a8 8 0 0 1 16 0v2"/><rect x="3" y="14" width="4.4" height="6.4" rx="1.8" fill="currentColor" stroke="none"/><rect x="16.6" y="14" width="4.4" height="6.4" rx="1.8" fill="currentColor" stroke="none"/>'),
  "chevron.left": S('<path d="m14.5 5.5-6.5 6.5 6.5 6.5"/>'),
  "chevron.right": S('<path d="m9.5 5.5 6.5 6.5-6.5 6.5"/>'),
  prev: F('<path d="M18.5 6v12l-9-6zM7 6h-2v12h2z"/>'),
  next: F('<path d="M5.5 6v12l9-6zM17 6h2v12h-2z"/>'),
  "play.fill": F('<path d="M7.5 5.2v13.6L19 12z"/>'),
  "pause.fill": F('<rect x="6.5" y="5" width="3.6" height="14" rx="1"/><rect x="13.9" y="5" width="3.6" height="14" rx="1"/>'),
  aperture: S('<circle cx="12" cy="12" r="9"/><path d="M12 3v6.2M20.8 9.2l-5.9 1.9M17.5 19.6l-3.6-5.1M6.5 19.6l3.6-5.1M3.2 9.2l5.9 1.9"/>'),
  football: F('<path d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm0 2.2 3 2-.5 3.3-2.5 1.6-2.5-1.6L9 6.2zM5.3 6.8l2 .1 2 2.6-1 2.6-2.6.6-1.9-1.6a8 8 0 0 1 1.5-4.3zm13.4 0a8 8 0 0 1 1.5 4.3l-1.9 1.6-2.6-.6-1-2.6 2-2.6zM8.6 15.4l2.6.7 1 2.5-.7 2.5a8 8 0 0 1-4.4-2.4zm6.8 0 1.5 3.3a8 8 0 0 1-4.4 2.4l-.7-2.5 1-2.5z"/>'),
  note: F('<path d="M9.4 18.6a2.9 2.9 0 1 1-1.7-2.6V5.9l10-2v10.2a2.9 2.9 0 1 1-1.7-2.6V6.4l-6.6 1.3z"/>'),
  check: S('<circle cx="5" cy="6.5" r="2.2"/><circle cx="5" cy="12" r="2.2"/><circle cx="5" cy="17.5" r="2.2"/><path d="M10.4 6.5h9.6M10.4 12h9.6M10.4 17.5h9.6"/>'),
  notes: S('<rect x="4.5" y="3.5" width="15" height="17" rx="2.5"/><path d="M8.5 8.5h7M8.5 12h7M8.5 15.5h4"/>'),
  cam: S('<rect x="3.5" y="7" width="12" height="10" rx="2.5"/><path d="M15.5 11l5-2.8v7.6l-5-2.8"/>'),
  disk: S('<rect x="3" y="7" width="18" height="10" rx="2.5"/><circle cx="16.5" cy="12" r="1.4" fill="currentColor" stroke="none"/><path d="M6.5 12h5"/>'),
  net: S('<circle cx="12" cy="12" r="8.6"/><path d="M3.4 12h17.2M12 3.4c2.6 2.6 3.8 5.6 3.8 8.6s-1.2 6-3.8 8.6c-2.6-2.6-3.8-5.6-3.8-8.6S9.4 6 12 3.4z"/>'),
  memory: S('<rect x="3" y="7" width="18" height="10" rx="1.6"/><path d="M7 10.5v3M10.3 10.5v3M13.7 10.5v3M17 10.5v3M6 17v2.5M10 17v2.5M14 17v2.5M18 17v2.5"/>'),
};

/* ----------------------------------------------------------------- state */
const music = {
  i: 0, playing: true, t: 174,
  tracks: [
    { title: "Starboy (feat. Daft Punk)", artist: "The Weeknd", len: 230, art: "radial-gradient(circle at 32% 18%, #ff4d5e 0%, #b3122d 38%, #3d0a14 70%, #17060a 100%)", accent: "#e11d48", lyric: "Switch up my style, I take any lane" },
    { title: "Midnight City", artist: "M83", len: 243, art: "linear-gradient(135deg,#ff7ad5,#7a3cff 55%,#172554)", accent: "#e879f9", lyric: "Waiting in the car, a quarter past two" },
    { title: "Glass Harbour", artist: "Tide & Timber", len: 187, art: "linear-gradient(135deg,#07c7ed,#0a84ff 55%,#0b2545)", accent: T_BLUE, lyric: "Every window burning low" },
  ],
};
const timer = { total: 0, left: 0, running: false, justFinished: false, mode: "timer", minutes: 25 };
const stopwatch = { active: false, elapsed: 0, base: 0, anchor: 0 };
function swNow() { return stopwatch.active ? stopwatch.base + (Date.now() - stopwatch.anchor) / 1000 : stopwatch.elapsed; }
const call = { active: true, muted: false, start: Date.now() - 8 * 60 * 1000 - 20_000 };
const meeting = { title: "Design review", at: "10:30", inMin: 5 };
const keepAwake = { on: false };
const agents = { live: [{ name: "Claude", tint: "#d97857", started: Date.now() - 37_000 }, { name: "Codex", tint: T_BLUE, started: Date.now() - 125_000 }] };
const download = { name: "Arrowslit-0.12.10.dmg", fraction: 0.64 };
const agentReq = { name: "Claude Code", cmd: "run the test suite" };
const levels = { volume: 0.45, brightness: 0.68 };
const cpu = 18;

/* --------------------------------------- the app's own settings (live) */
const settings = {
  width: 200, height: 32, size: 1, theme: "black", glassTint: 0.5, pitchBlack: true,
  openWith: "click", hoverDelay: 250, showWhenIdle: false, collapse: true, elongated: false,
  alerts: { charging: true, lowBattery: true, headphones: true, level: true, download: true, update: true, upcomingEvent: true, agentRequest: true },
  activities: { nowPlaying: true, call: true, timer: true, agents: true },
};
function earWidth() { const slot = Math.round(settings.height * 1.15); return Math.max(Math.round(slot * 0.8), Math.round(slot + (settings.width - 180) / 2)); }
function compactW() { return NOTCH.w + 2 * earWidth(); }
function compactH() { return Math.max(settings.height, 32); }
function applyAppearance() {
  const glass = settings.theme === "glass";
  slit.style.setProperty("--panel", glass ? `rgba(30,30,34,${(0.5 + settings.glassTint * 0.3).toFixed(2)})` : "#090909");
  slit.classList.toggle("glass", glass);
  slit.classList.toggle("pitch", settings.pitchBlack);
  slit.classList.toggle("elongated", settings.elongated);
}
const clips = [
  { text: "lightweight, free and open source", app: "Notes" },
  { text: "https://github.com/vinzdl/codenotch", app: "Chrome" },
  { text: "Don't pay $29.99 for Tangerine I built", app: "X (Twitter)" },
];
const reminders = [{ text: "Nurokind Tab", done: false, at: "10:00 PM" }];
const scratch = "Ship the notch film.\nCut the 78s launch.\nSend it to Jay.";
const match = { league: "La Liga", home: "Málaga", away: "Racing Santander", time: "6:30 PM - 8:30 PM", score: "0 : 0", minute: "Now" };
const CAL_EVENTS = [
  { home: "Málaga", away: "Racing Santander", score: "(0-0)", when: "Now · until 8:30 PM", live: true },
  { home: "Español", away: "Deportivo A Coruña", when: "8:45 PM – 10:45 PM" },
  { home: "Osasuna", away: "Athletic Club", when: "11:00 PM – 1:00 AM" },
];
const notifications = [];
const downloads = [
  { id: "d1", name: "Arrowslit-0.12.10.dmg", fraction: 0.12, active: true, done: false },
  { id: "d2", name: "Quarterly-Report-Q3.pdf", fraction: 1, active: false, done: true },
  { id: "d3", name: "IMG_4821.HEIC", fraction: 1, active: false, done: true },
];
call.endAt = Date.now() + 4 * 60 * 1000;
const LYRICS = ["Switch up my style, I take any lane", "I switch up my cup, I kill any pain", "Look what you done", "I'm a motherf— star boy"];
const quota = { used: 1000, total: 250 };

/* ------------------------------------------------------ presentation ---- */
const PRIORITY = { call: 0, timer: 1, stopwatch: 2, agents: 3, calendar: 4, keepAwake: 5, watch: 6, sports: 7, nowPlaying: 8, download: 9, charging: 10, stats: 11 };
const ALERT_DURATION = {
  upcomingEvent: 8, timerFinished: 600, charging: 3, lowBattery: 4, headphones: 3,
  download: 5, update: 10, welcome: 4, sportsGoal: 7, shortcut: 2.5, agentRequest: 125,
  level: 1.6, clipboard: 2.5, track: 3, microphone: 1.6, inputSource: 1.6,
  agentEvent: 5, systemNotification: 3, capture: 12, watch: 6,
};
const URGENT = new Set(["timerFinished", "agentRequest"]);
const COMPACT_HUD = new Set(["charging", "lowBattery", "headphones", "level", "clipboard", "microphone", "inputSource", "agentEvent", "systemNotification", "capture", "watch"]);
const COMPACT_ALERT_ROW = new Set(["upcomingEvent", "download", "update", "welcome", "shortcut", "track"]);

let alert = null;
let expanded = false, expandedTab = "home";
function liveActivities() {
  const a = new Set(["nowPlaying"]);
  if (call.active) a.add("call");
  if (timer.running || timer.left > 0) a.add("timer");
  if (stopwatch.active || stopwatch.elapsed > 0) a.add("stopwatch");
  if (agents.live.length) a.add("agents");
  return a;
}
let hovering = false, peek = false;

function presentation() {
  if (alert && (!expanded || URGENT.has(alert.kind))) {
    if (COMPACT_HUD.has(alert.kind) && !expanded) return { t: "hud", alert };
    return { t: "alert", alert };
  }
  if (expanded) return { t: "expanded", tab: expandedTab };
  const live = [...liveActivities()].filter(a => settings.activities[a] !== false).sort((a, b) => PRIORITY[a] - PRIORITY[b]);
  if (live.length) return { t: "compact", primary: live[0] };
  if (settings.showWhenIdle) return { t: "idle" };
  return { t: peek ? "hidden-peek" : "hidden" };
}

/* ------------------------------------------------------------------- dom */
let host = null, root = null, slit = null, nook = null, stripEl = null, bodyEl = null, cardEl = null;
let earL = null, earR = null, ctx = null, toastEl = null;
let curKey = "";

const h = (spec, props = null, ...children) => {
  if (props != null && (typeof props !== "object" || props.nodeType)) { children.unshift(props); props = null; }
  const [tag, ...cls] = spec.split(".");
  const el = tag === "svg" ? document.createElementNS(SVG_NS, tag) : document.createElement(tag);
  if (cls.length) el.classList.add(...cls);
  if (props) for (const [k, v] of Object.entries(props)) {
    if (v == null) continue;
    if (k === "on") { for (const [ev, fn] of Object.entries(v)) el.addEventListener(ev, fn); }
    else if (k === "style" && typeof v === "object") for (const [pk, pv] of Object.entries(v)) { if (pk.startsWith("--")) el.style.setProperty(pk, pv); else el.style[pk] = pv; }
    else el.setAttribute(k, v);
  }
  for (const child of children.flat(Infinity)) {
    if (child == null || child === false) continue;
    el.append(child.nodeType ? child : document.createTextNode(child));
  }
  return el;
};
const icon = (name, size = 14, cls = "") => {
  const w = h(`span.ai${cls ? "." + cls : ""}`, { style: { width: size + "px", height: size + "px" } });
  w.innerHTML = ICONS[name] || "";
  return w;
};
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
const SLIT_MARK = `<svg width="12" height="13.5" viewBox="0 0 16 18" fill="currentColor" aria-hidden="true"><rect x="6.5" y=".5" width="3" height="14" rx="1.5"/><rect x="2.5" y="14.5" width="11" height="3" rx="1.5"/></svg>`;
const fmtStopwatch = (s) => {
  s = Math.max(0, s); const m = Math.floor(s / 60), sec = Math.floor(s % 60), t = Math.floor((s * 10) % 10);
  return `${m}:${String(sec).padStart(2, "0")}.${t}`;
};
const fmtClock = (s) => {
  s = Math.max(0, Math.round(s)); const hh = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), ss = s % 60;
  return hh ? `${hh}:${String(m).padStart(2, "0")}:${String(ss).padStart(2, "0")}` : `${m}:${String(ss).padStart(2, "0")}`;
};

/* -------------------------------------------------------------- geometry */
function box(w, hgt, radius, flare) {
  slit.style.setProperty("--nook-scale", Math.min(1, (innerWidth - 16) / w));
  slit.style.setProperty("--w", w + "px");
  slit.style.setProperty("--h", hgt + "px");
  slit.style.setProperty("--r", radius + "px");
  slit.style.setProperty("--flare", flare + "px");
}

/* -------------------------------------------------- compact ear content */
function battHTML(level, charging, color) {
  return `<span class="mono" style="font-size:13px;font-weight:500;color:${color}">${level}%</span><span class="batt" style="color:${color}">${ICONS["battery.100percent.bolt"]}</span>`;
}
function earContent(activity) {
  const t = music.tracks[music.i];
  switch (activity) {
    case "nowPlaying": return {
      l: `<span class="art" style="background:${t.art}"></span>`,
      r: music.playing
        ? `<span class="bars" style="--tint:${t.accent}"><i></i><i></i><i></i><i></i></span>`
        : `<span class="ai" style="color:${t.accent}">${ICONS[music.playing ? "speaker.wave.2.fill" : "pause.fill"]}</span>`,
    };
    case "call": return {
      l: `<span class="appicon">${ICONS["phone.fill"]}</span>`,
      r: `<span class="mono big">${fmtClock((Date.now() - call.start) / 1000)}</span>`,
    };
    case "timer": return {
      l: icon(timer.justFinished ? "checkmark.circle" : timer.running ? "timer" : "pause.circle", 20, "c-orange").outerHTML,
      r: `<span class="mono big c-orange">${fmtClock(timer.left)}</span>`,
    };
    case "stopwatch": return {
      l: icon("stopwatch", 20, "c-orange").outerHTML,
      r: `<span class="mono big c-orange">${fmtStopwatch(swNow())}</span>`,
    };
    case "calendar": return {
      l: `<span class="dot"></span><span class="st">${esc(meeting.title)}</span>`,
      r: `<span class="mono big">${meeting.inMin} min</span><span class="mono dim sm">${meeting.at}</span>`,
    };
    case "keepAwake": return { l: icon("cup.and.saucer.fill", 20, "c-yellow").outerHTML, r: `<span class="ai c-yellow" style="width:24px">${ICONS.infinity}</span>` };
    case "download": return {
      l: `${icon("arrow.down.circle.fill", 17).outerHTML}<span class="st" style="font-weight:500">${esc(download.name)}</span>`,
      r: `<span class="meter"><b style="width:${Math.round(download.fraction * 100)}%"></b></span><span class="mono sm" style="width:30px;text-align:right">${Math.round(download.fraction * 100)}%</span>`,
    };
    case "agents": {
      const a = agents.live[0];
      return { l: `<span class="mark" style="color:${a.tint}">${ICONS.bolt}</span>`, r: `<span class="mono big" style="color:${a.tint}">${fmtClock((Date.now() - a.started) / 1000)}</span>` };
    }
    case "charging": return { l: icon("battery.100percent.bolt", 22).outerHTML, r: `<span class="mono big c-green">82%</span>` };
    case "stats": return { l: icon("gauge", 20).outerHTML, r: `<span class="mono sm">CPU ${cpu}%</span>` };
    default: return { l: "", r: "" };
  }
}

/* ---------------------------------------------------- alert renderings */
function alertContent(a) {
  switch (a.kind) {
    case "upcomingEvent": return { l: `${icon("cal", 14, "c-red").outerHTML}<span class="st c-red">${esc(meeting.title)}</span>`, r: `<span class="st c-red">In ${meeting.inMin} min</span>`, tap: "join" };
    case "timerFinished": return { l: icon("bell", 15, "c-orange ring").outerHTML + `<span class="st">Timer</span>`, r: `<span class="st c-orange">Done</span>`, tap: "timer" };
    case "charging": return { l: `<span class="st">Charging</span>`, r: battHTML(82, true, T_GREEN) };
    case "lowBattery": return { l: `<span class="st">Low Battery</span>`, r: battHTML(20, false, T_RED) };
    case "headphones": return { l: icon("phones", 15, "c-blue").outerHTML + `<span class="st">AirPods Pro</span>`, r: `<span class="st c-green">Connected · 92%</span>` };
    case "download": return { l: icon("doc", 14).outerHTML + `<span class="st">${esc(download.name)}</span>`, r: `<span class="st c-blue">Show in Finder</span>`, tap: "finder" };
    case "update": return { l: icon("arrow.down", 14, "c-blue").outerHTML + `<span class="st">Arrowslit 0.12.10</span>`, r: `<span class="st c-blue">Download &amp; Open</span>`, tap: "update" };
    case "welcome": return { l: `<span class="ai" style="color:${C.amber}">${ICONS.aperture}</span><span class="st">Welcome back, Jay</span>`, r: `<span class="st dim">Slit ready</span>` };
    case "track": return { l: `<span class="art" style="background:${music.tracks[music.i].art}"></span><span class="st">${esc(music.tracks[music.i].title)}</span>`, r: `<span class="st dim">${esc(music.tracks[music.i].artist)}</span>`, tap: "player" };
    case "microphone": return { l: `<span class="ai c-red">${ICONS.xmark}</span><span class="st">Microphone ${a.muted ? "off" : "on"}</span>`, r: "" };
    case "level": return { l: icon(a.kind2 === "brightness" ? "sun" : "vol", 15).outerHTML, r: `<span class="lvl"><b style="--v:${Math.round(a.value * 100)}%"></b></span>` };
    case "shortcut": return { l: `<span class="ai c-blue">${ICONS.bolt}</span><span class="st">${esc(a.name)}</span>`, r: `<span class="st ${a.ok ? "c-green" : "c-red"}">${a.ok ? "Done" : "Failed"}</span>` };
    case "sportsGoal": return { l: `<span class="ai c-green" style="width:16px">${ICONS.football}</span><span class="st">${esc(match.home)} scored!</span>`, r: `<span class="st c-green">${match.score}</span>` };
    case "systemNotification": return { l: `<span class="ai c-blue">${ICONS.bell}</span><span class="st">${esc(a.title)}</span>`, r: `<span class="st dim">${esc(a.app)}</span>` };
  }
  return { l: "", r: "" };
}

/* --------------------------------------------- presentation application */
function refreshActivityEars(activity) {
  if (!earL) return;
  if (activity === "call") { const el = earR.querySelector(".big"); if (el) el.textContent = fmtClock((Date.now() - call.start) / 1000); }
  if (activity === "timer") { const el = earR.querySelector(".big"); if (el) el.textContent = fmtClock(timer.left); }
  if (activity === "stopwatch") { const el = earR.querySelector(".big"); if (el) el.textContent = fmtStopwatch(swNow()); }
  if (activity === "agents") { const el = earR.querySelector(".big"); if (el) el.textContent = fmtClock((Date.now() - agents.live[0].started) / 1000); }
}

/* ---------------------------------------------------------- the nook pages */
const PAGE_H = { home: 178, files: 178, clipboard: 178, grid: 240, timer: 200, stopwatch: 200,
  calendar: 216, sports: 236, reminders: 160, agents: 400, scratchpad: 210, mirror: 196,
  keepawake: 156, stats: 208, downloads: 190, notifications: 190, nowplaying: 218 };
const LAUNCHER_PAGES = new Set(["timer", "stopwatch", "calendar", "sports", "reminders", "agents", "scratchpad", "mirror", "keepawake", "stats", "downloads", "notifications"]);
const PAGE_TITLE = { timer: "Timer", stopwatch: "Stopwatch", calendar: "Calendar", sports: "Sports", reminders: "Reminders", agents: "Today", scratchpad: "Scratchpad", mirror: "Camera Mirror", keepawake: "Keep Awake", stats: "Stats", downloads: "Downloads", notifications: "Notifications" };

function tabPill(active) {
  const wrap = h("div.slit-tabs-pill");
  for (const [id, icon] of [["home", "house"], ["files", "tray"], ["clipboard", "clip"]]) {
    wrap.append(h("button.slit-ticon" + (active === id ? ".is-on" : ""), {
      title: id === "home" ? "Home" : id === "files" ? "Files" : "Clipboard", "aria-label": id,
      on: { click: (e) => { e.stopPropagation(); expandedTab = id; apply(); } },
    }, (() => { const w = h("span.ico"); w.innerHTML = ICONS[icon]; return w; })()));
  }
  return wrap;
}
function pageBar(p) {
  const bar = h("div.slit-pagebar");
  bar.append(
    h("button.slit-back", { "aria-label": "Back to Home", on: { click: (e) => { e.stopPropagation(); expandedTab = "home"; apply(); } } }, (() => { const w = h("span.ico"); w.innerHTML = ICONS["chevron.left"]; return w; })()),
    h("b.slit-pagetitle", PAGE_TITLE[p] || "Arrowslit"),
    h("span.pgap"),
    h("button.slit-chip", { title: "Everything", on: { click: (e) => { e.stopPropagation(); gridPage = 0; expandedTab = "grid"; apply(); } } }, (() => { const w = h("span.ico"); w.innerHTML = ICONS.grid; return w; })()),
    h("button.slit-chip", { title: "Settings", on: { click: (e) => { e.stopPropagation(); openSettings(); } } }, (() => { const w = h("span.ico"); w.innerHTML = ICONS.gear; return w; })()));
  return bar;
}
function renderNook() {
  stripEl.innerHTML = "";
  if (LAUNCHER_PAGES.has(expandedTab)) stripEl.append(pageBar(expandedTab));
  else {
    stripEl.append(tabPill(expandedTab === "home" ? "home" : expandedTab === "files" ? "files" : "clipboard"));
    const right = h("div.slit-chips");
    const g = h("button.slit-chip", { title: "Everything", on: { click: (e) => { e.stopPropagation(); gridPage = 0; expandedTab = "grid"; apply(); } } }, (() => { const w = h("span.ico"); w.innerHTML = ICONS.grid; return w; })());
    const st = h("button.slit-chip", { title: "Settings", on: { click: (e) => { e.stopPropagation(); openSettings(); } } }, (() => { const w = h("span.ico"); w.innerHTML = ICONS.gear; return w; })());
    right.append(g, st);
    stripEl.append(right);
  }
  const P = {
    home: renderHomeBody, nowplaying: renderPlayerBody, timer: renderTimerBody,
    calendar: renderCalendarBody, sports: renderSportsBody, agents: renderAgentsBody,
    clipboard: renderClipboardBody, files: renderFilesBody, stats: renderStatsBody,
    keepawake: renderKeepAwakeBody, scratchpad: renderScratchBody, reminders: renderRemindersBody,
    mirror: renderMirrorBody, grid: renderGridBody, downloads: renderDownloadsBody, notifications: renderNotificationsBody,
  };
  (P[expandedTab] || renderGridBody)();
}
function renderHomeBody() {
  const t = music.tracks[music.i];
  bodyEl.innerHTML = `
    <div class="homenew">
      <div class="musiccard2">
        <div class="artline" data-act="expandplayer" title="Open the player"><span class="art78" style="background:${t.art}"></span>
          <span class="mtxt"><b>${esc(t.title)}</b><span>${esc(t.artist)}</span></span></div>
        <div class="hlyric">${esc(t.lyric || LYRICS[0])}</div>
        <div class="hscrub"><i style="width:${Math.min(100, music.t / t.len * 100)}%"></i><b style="left:${Math.min(100, music.t / t.len * 100)}%"></b></div>
        <div class="hctl">
          <button data-m="prev">${ICONS.prev}</button>
          <button data-m="play" class="hplay">${music.playing ? ICONS["pause.fill"] : ICONS["play.fill"]}</button>
          <button data-m="next">${ICONS.next}</button>
        </div>
      </div>
      <div class="homesecs">
        <div class="hsec">
          <header><span class="ai c-red" style="width:16px">${ICONS.cal}</span><b>Calendar</b><span class="chev">${ICONS["chevron.right"]}</span></header>
          <div class="hev"><span class="ai c-green" style="width:18px">${ICONS.football}</span><b>${esc(match.home)} -<br>${esc(match.away)}</b></div>
          <div class="hevsub">Today 6:30 PM</div>
        </div>
        <div class="vdiv"></div>
        <div class="hsec hsec--timer">
          <header><span class="ai c-orange" style="width:16px">${ICONS.timer}</span><b>Timer</b><span class="chev">${ICONS["chevron.right"]}</span></header>
          ${timer.running || timer.left ? `<div class="hpills"><span class="mono c-orange" style="font-size:20px;font-weight:600">${fmtClock(timer.left)}</span></div>
          <div class="hpills"><button class="hpill" data-tc="pause">Pause</button><button class="hpill" data-tc="cancel">Cancel</button></div>` : `<div class="hpills">${[5, 10, 15].map(m => `<button class="hpill" data-min="${m}">${m}m</button>`).join("")}</div>
          <button class="hpill hpill--focus" data-min="25"><span class="ai c-orange" style="width:15px">${ICONS.timer}</span>Focus 25m</button>`}
        </div>
      </div>
    </div>`;
}
function renderPlayerBody() {
  const t = music.tracks[music.i];
  const next = music.tracks[(music.i + 1) % music.tracks.length];
  const lyric = LYRICS[Math.floor(music.t / 9) % LYRICS.length];
  bodyEl.innerHTML = `
    <div class="playernew">
      <div class="prownew"><span class="art64" style="background:${t.art}"></span>
        <span class="mtxt"><b>${esc(t.title)}</b><span>${esc(t.artist)}</span></span>
        <span class="pdots"><i></i><i></i><i></i><i></i></span></div>
      <div class="plyrnew">${esc(lyric)}</div>
      <div class="pscrubnew"><span class="mono dim">${fmtClock(music.t)}</span>
        <div class="scrub"><i style="width:${Math.min(100, music.t / t.len * 100)}%"></i></div>
        <span class="mono dim">-${fmtClock(t.len - music.t)}</span></div>
      <div class="pctlnew">
        <button data-m="prev">${ICONS.prev}</button>
        <button data-m="play" class="pbig">${music.playing ? ICONS["pause.fill"] : ICONS["play.fill"]}</button>
        <button data-m="next">${ICONS.next}</button></div>
      <div class="pup">Up next · ${esc(next.title)} — ${esc(next.artist)}</div>
    </div>`;
}
function renderTimerBody() {
  const isSw = timer.mode === "stopwatch";
  const running = isSw ? stopwatch.active : timer.running;
  const minutes = timer.minutes || 25;
  const maxMin = isSw ? 12 : 36;
  const shown = isSw ? swNow() : (timer.running || timer.left ? timer.left : minutes * 60);
  const label = isSw ? fmtStopwatch(shown) : fmtClock(shown);
  const ticks = Array.from({ length: maxMin + 1 }, (_, i) => {
    const active = isSw ? i <= 0 : i <= minutes;
    const lbl = i % 5 === 0 ? `<small>${i}</small>` : "";
    return `<span class="tick${active ? " on" : ""}${(!isSw && i === minutes) ? " cur" : ""}" style="left:${(i / maxMin) * 100}%">${lbl}</span>`;
  }).join("");
  bodyEl.innerHTML = `
    <div class="timernew">
      <div class="ttop">
        <div class="modesnew">${[["timer", "Timer"], ["focus", "Pomodoro"], ["stopwatch", "Stopwatch"]].map(([m, n]) => `<button class="mode${timer.mode === m ? " is-on" : ""}" data-mode="${m}">${n}</button>`).join("")}</div>
        <div class="tctrl">${(isSw ? stopwatch.active || stopwatch.elapsed > 0 : timer.running || timer.left > 0) ? `<button class="tghost" data-do="cancel">${isSw ? "Reset" : "Cancel"}</button>` : ""}<button class="startnew${running ? " is-running" : ""}" data-do="start">${running ? "Pause" : (isSw ? (stopwatch.elapsed > 0 ? "Resume" : "Start") : (timer.left > 0 ? "Resume" : "Start"))}</button></div>
      </div>
      <div class="trrow"><div class="rulernew" data-ruler><div class="ticksnew">${ticks}</div><span class="cursornew" style="left:${(isSw ? 0 : minutes / maxMin) * 100}%"></span></div>
      <div class="bigread mono">${label}</div></div>
    </div>`;
  const refreshPane = () => { apply(); if (expanded && expandedTab === "timer") renderTimerBody(); };
  for (const b of bodyEl.querySelectorAll(".mode")) b.addEventListener("click", () => { timer.mode = b.dataset.mode; refreshPane(); });
  bodyEl.querySelector("[data-do=cancel]")?.addEventListener("click", () => {
    if (timer.mode === "stopwatch" || isSw) { stopwatch.active = false; stopwatch.elapsed = 0; stopwatch.base = 0; stopwatch.anchor = 0; }
    else { timer.running = false; timer.left = 0; timer.total = 0; timer.justFinished = false; }
    refreshPane();
  });
  bodyEl.querySelector("[data-do=start]").addEventListener("click", () => {
    const min = timer.minutes || 25;
    if (timer.mode === "stopwatch") {
      if (stopwatch.active) { stopwatch.elapsed = swNow(); stopwatch.active = false; refreshPane(); return; }
      const resuming = stopwatch.elapsed > 0;
      stopwatch.base = stopwatch.elapsed; stopwatch.anchor = Date.now(); stopwatch.active = true;
      call.active = false;
      if (!resuming) expanded = false;
      refreshPane(); return;
    }
    if (timer.running) { timer.running = false; refreshPane(); return; }
    if (timer.left > 0 && timer.left < (timer.total || 0)) { timer.running = true; refreshPane(); return; }
    timer.total = timer.left = min * 60; timer.running = true; timer.justFinished = false;
    call.active = false;
    expanded = false;
    refreshPane();
  });
  const ruler = bodyEl.querySelector("[data-ruler]");
  if (ruler && !isSw && !timer.running && !timer.left) {
    const drag = (e) => {
      const r = ruler.getBoundingClientRect();
      const frac = Math.max(0, Math.min(1, (e.clientX - r.left) / r.width));
      timer.minutes = Math.max(1, Math.round(frac * 36));
      renderTimerBody();
    };
    ruler.addEventListener("pointerdown", (e) => {
      ruler.setPointerCapture(e.pointerId); drag(e);
      const mv = (ev) => drag(ev);
      const up = () => { ruler.removeEventListener("pointermove", mv); ruler.removeEventListener("pointerup", up); };
      ruler.addEventListener("pointermove", mv); ruler.addEventListener("pointerup", up); ruler.addEventListener("pointercancel", up);
    });
  }
}
function renderCalendarBody() {
  const days = Array.from({ length: 35 }, (_, i) => {
    const day = i + 1;
    return `<span class="${day === 7 ? "today" : ""}">${day > 0 && day <= 30 ? day : ""}</span>`;
  }).join("");
  bodyEl.innerHTML = `
    <div class="calnew">
      <div class="calleft">
        <div class="monname">NOVEMBER</div>
        <div class="calgridnew">${["S", "M", "T", "W", "T", "F", "S"].map(d => `<small>${d}</small>`).join("")}${days}</div>
      </div>
      <div class="calright">
        <div class="tlabelnew">TODAY</div>
        ${CAL_EVENTS.map(ev => `
          <div class="evnew">
            <span class="evbar" style="background:${ev.live ? "#FF453A" : "rgba(255,69,58,.55)"}"></span>
            <span class="aisteam c-green" style="width:17px">${ICONS.football}</span>
            <div class="evtxt"><b>${esc(ev.home)} - ${esc(ev.away)}${ev.score ? " " + ev.score : ""}</b>
              <span class="${ev.live ? "c-green" : "dim"}">${esc(ev.when)}</span></div>
          </div>`).join("")}
      </div>
    </div>`;
}
function renderSportsBody() {
  bodyEl.innerHTML = `
    <div class="sportsnew">
      <div class="stoprow">
        <span class="ai c-green" style="width:18px">${ICONS.football}</span><b>Football</b>
        <div class="schips">${["All", "EPL", "La Liga", "UCL"].map((c, i) => `<button class="schip${i === 0 ? " is-on" : ""}">${c}</button>`).join("")}</div>
        <span class="livebadge"><i></i>2 live</span>
        <span class="ai dim" style="width:14px">${ICONS.gear}</span>
      </div>
      <div class="smatchrow">
        <div class="smatchcard"><div class="smhead"><small>EPL</small><span class="livebadge"><i></i>LIVE</span></div>
          <div class="smteam"><span class="badge" style="background:#5b2a4e">LE</span><b>LEE</b><span class="smscore">0</span></div>
          <div class="smteam"><span class="badge" style="background:#4a3a5c">TO</span><b>TOT</b><span class="smscore">0</span></div>
          <div class="smlive">LIVE</div></div>
        <div class="smatchcard"><div class="smhead"><small>LA LIGA</small><span class="livebadge"><i></i>LIVE</span></div>
          <div class="smteam"><span class="badge" style="background:#2a3a5c">MC</span><b>MCF</b><span class="smscore">1</span></div>
          <div class="smteam"><span class="badge" style="background:#2a5c3a">SA</span><b>SAN</b><span class="smscore">0</span></div>
          <div class="smlive">LIVE</div></div>
      </div>
    </div>`;
  for (const c of bodyEl.querySelectorAll(".schip")) c.addEventListener("click", () => { bodyEl.querySelectorAll(".schip").forEach(x => x.classList.remove("is-on")); c.classList.add("is-on"); });
}
function renderAgentsBody() {
  const bars = [30, 6, 2, 1, 1, 4, 5, 7, 14, 2, 1, 1];
  bodyEl.innerHTML = `
    <div class="agentsnew">
      <div class="agcard agcodex">
        <div class="aghead"><span class="agmark" style="background:#4b5bd8">${ICONS.bolt}</span><b>Codex</b><span class="agplan">Go</span><span class="agreset">30d ⟳ 24d 4h</span><span class="agpct">86% left</span></div>
        <div class="agbar"><b style="width:86%"></b><i style="left:86%"></i></div>
      </div>
      <div class="agcard">
        <div class="aghead"><span class="agmark" style="background:#2b2b31">${ICONS.aperture}</span><b>OpenCode</b><span class="agdot"></span><span class="agright">$23.91</span></div>
        <div class="agsub"><span>Today</span><span class="dim">567M · 97% from cache</span></div>
      </div>
      <div class="aggrid2">
        <div class="agcard"><div class="aglabel">${ICONS.gauge} Spending</div><div class="agbig">$23.91 <small>API value</small></div><div class="agsub"><span class="dim">567M tokens · 97% from cache</span></div><div class="agbar green"><b style="width:100%"></b></div></div>
        <div class="agcard"><div class="aglabel">${ICONS.bolt} Now <span class="agdot" style="margin-left:auto"></span></div><div class="agsub"><b>jaygopal</b><span class="agright mono" style="color:#30D158">16:07</span></div><div class="agsub"><span class="dim">deepseek-v4p1-flash-1017 · 15K written · $0.08</span></div></div>
      </div>
      <div class="agcard">
        <div class="aglabel">${ICONS.gauge} Trend <span class="agright dim">Today · $23.91</span></div>
        <div class="agtrend">${bars.map(v => `<i style="height:${Math.min(38, Math.max(4, v * 1.25))}px"></i>`).join("")}</div>
        <div class="agaxis"><span>12 AM</span><span>12 PM</span><span>11 PM</span></div>
      </div>
      <div class="aggrid2">
        <div class="agcard"><div class="aglabel">${ICONS.grid} Models</div>
          <div class="agmodel"><span>jay20gopal-….modal.direct</span><span class="agbar sm"><b style="width:74%"></b></span><span class="mono">$17.92</span></div>
          <div class="agmodel"><span>deepseek-v4p1-flash-1017</span><span class="agbar sm"><b style="width:32%"></b></span><span class="mono">$6.00</span></div></div>
        <div class="agcard"><div class="aglabel">${ICONS.tray} Projects</div>
          <div class="agmodel"><span>jaygopal</span><span class="agbar sm"><b style="width:100%"></b></span><span class="mono">$23.91</span></div></div>
      </div>
      <div class="agcard">
        <div class="aglabel">${ICONS.grid} Activity <span class="agright">🔥 23</span></div>
        <div class="agact">
          <div class="agheat">${Array.from({ length: 91 }, (_, i) => `<i style="opacity:${i > 78 ? 0.9 : i > 60 ? 0.45 : 0.16}"></i>`).join("")}</div>
          <div class="agactstats"><span class="agactbig">8B <small class="dim">13 weeks</small></span>
            <span class="agsub"><span class="dim">Active days</span><span class="agright">23</span></span>
            <span class="agsub"><span class="dim">Busiest day</span><span class="agright">2 Nov · 1.3B</span></span></div>
        </div>
      </div>
      <div class="agcard"><div class="aglabel">${ICONS.aperture} Resets</div><div class="agsub"><span class="dim">Check the account</span><span class="agright c-blue">Check</span></div></div>
    </div>`;
}
function renderClipboardBody() {
  if (!clips.length) { bodyEl.innerHTML = `<div class="emptynew">${ICONS.clip}<div><b>Copy something</b><span>Text you copy appears here; passwords are skipped. Pin a clip to keep it after quitting.</span></div></div>`; return; }
  bodyEl.innerHTML = `
    <div class="clipnew">
      <div class="clipcardnew"><b>Screenshot 2026-11-07 at<br>6.55.34 PM</b><span>Finder · Just now</span></div>
      <div class="clipside">
        <button class="clipcircle" title="Search">${ICONS.clip ? '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><circle cx="10.5" cy="10.5" r="6.3"/><path d="m15.4 15.4 5.1 5.1"/></svg>' : ""}</button>
        <button class="clipcircle" title="Clear">${ICONS.tray}</button>
      </div>
    </div>`;
}
function renderFilesBody() {
  bodyEl.innerHTML = `<div class="traynew"><div class="dashtray">${ICONS.tray}<b>Drag files onto the notch to keep them here</b><span>They stay until you quit, or pin one to keep it. Your originals aren't touched.</span></div></div>`;
}
function renderStatsBody() {
  bodyEl.innerHTML = `<div class="statsnew">
    <div class="statnew"><div class="aglabel">${ICONS.memory} Memory</div><div class="statbig">81%</div><div class="agsub dim">12.91 GB of 16 GB</div><div class="agbar"><b style="width:81%"></b></div></div>
    <div class="statnew"><div class="aglabel">${ICONS.cpu} CPU</div><div class="statbig">21%</div><div class="agsub dim">8 cores</div><div class="agbar green"><b style="width:21%"></b></div></div>
    <div class="statnew"><div class="aglabel">${ICONS.disk} Disk</div><div class="statbig">24.58 GB</div><div class="agsub dim">free of 228.27 GB</div><div class="agbar"><b style="width:24%"></b></div></div>
    <div class="statnew"><div class="aglabel">${ICONS.net} Network</div><div class="agsub"><span class="c-blue">↓ 1 KB/s</span></div><div class="agsub"><span class="c-orange">↑ 23 KB/s</span></div></div>
  </div>`;
}
function renderKeepAwakeBody() {
  bodyEl.innerHTML = `<div class="kacnew">
    <span class="ai c-yellow" style="width:30px;height:30px">${ICONS["cup.and.saucer.fill"]}</span>
    <div class="katxt"><b>Keep this Mac awake.</b><span>Display sleep is still allowed.</span></div>
    <button class="startnew" data-ka="${keepAwake.on ? "off" : "on"}">${keepAwake.on ? "Turn Off" : "Turn On"}</button>
  </div>`;
}
function renderScratchBody() {
  bodyEl.innerHTML = `<div class="scratchnew">
    <textarea spellcheck="false">${esc(scratch)}</textarea>
    <div class="scratchbar"><span class="scdot"></span><span class="pgap"></span><span class="saved">Saved</span><button class="fmt">A</button><button class="fmt"><b>B</b></button><button class="fmt"><i>I</i></button><button class="fmt"><u>U</u></button></div>
  </div>`;
}
function renderRemindersBody() {
  bodyEl.innerHTML = `<div class="remsnew">${reminders.map((r, i) => `
    <label class="remnew"><span class="remradio${r.done ? " is-done" : ""}"></span><b>${esc(r.text)}</b><span class="mono dim sm">${esc(r.at || "")}</span></label>`).join("")}</div>`;
  for (const c of bodyEl.querySelectorAll(".remnew")) c.addEventListener("click", () => { reminders[0].done = !reminders[0].done; renderRemindersBody(); });
}
function renderMirrorBody() {
  bodyEl.innerHTML = `<div class="mirrornew">
    <div class="mprevnew" data-cam></div>
    <div class="mbodnew"><b>Camera preview is off.</b><button class="startnew" data-do="cam">Turn On Camera</button></div>
  </div>`;
  bodyEl.querySelector("[data-do=cam]").addEventListener("click", async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ video: true });
      const v = document.createElement("video");
      v.srcObject = stream; v.autoplay = true; v.muted = true; v.playsInline = true;
      const box = bodyEl.querySelector("[data-cam]");
      box.innerHTML = ""; box.append(v);
      bodyEl.querySelector(".mbodnew b").textContent = "Camera preview is on.";
    } catch { toast("Camera needs permission"); }
  });
}
let gridPage = 0;
function renderGridBody() {
  const tiles = [
    ["Now Playing", "note", "⌃⌥M", "#e11d48"], ["Timer", "timer", "⌃⌥R", "#FF9F0A"], ["Stopwatch", "stopwatch", "⌃⌥S", "#FF9F0A"], ["Calendar", "cal", "⌃⌥A", "#FF453A"], ["Sports", "football", "⌃⌥F", "#30D158"],
    ["Reminders", "check", "⌃⌥O", "#0A84FF"], ["AI Agents", "bolt", "⌃⌥G", "#fff"], ["Clipboard", "clip", "⌃⌥B", "#fff"], ["Files", "tray", "⌃⌥L", "#fff"], ["Scratchpad", "notes", "⌃⌥N", "#9a9aa0"],
    ["Camera Mirror", "cam", "⌃⌥W", "#fff"], ["Keep Awake", "cup.and.saucer.fill", "⌃⌥Z", "#FFD60A"], ["Stats", "gauge", "⌃⌥P", "#30D158"],
  ];
  const pageOf = { "now playing": "nowplaying", timer: "timer", stopwatch: "timer", calendar: "calendar", sports: "sports", reminders: "reminders", "ai agents": "agents", clipboard: "clipboard", files: "files", scratchpad: "scratchpad", "camera mirror": "mirror", "keep awake": "keepawake", stats: "stats", downloads: "downloads", notifications: "notifications" };
  const perPage = 10;
  const pages = Math.ceil(tiles.length / perPage);
  const slice = tiles.slice(gridPage * perPage, gridPage * perPage + perPage);
  bodyEl.innerHTML = `<div class="lgridnew">${slice.map(([label, ic, key, tint]) => `
    <button class="ltilenew" data-page="${label.toLowerCase()}"><span class="lticon" style="color:${tint}">${ICONS[ic]}</span><b>${label}</b><small>${key}</small>${label === "Sports" ? '<i class="ldot"></i>' : ""}</button>`).join("")}</div>
    <div class="pagedots">${Array.from({ length: pages }, (_, i) => `<button class="pdot${i === gridPage ? " is-on" : ""}" data-gp="${i}" aria-label="Page ${i + 1}"></button>`).join("")}</div>`;
  for (const b of bodyEl.querySelectorAll(".ltilenew")) b.addEventListener("click", () => { expandedTab = pageOf[b.dataset.page] || "grid"; apply(); });
  for (const d of bodyEl.querySelectorAll(".pdot")) d.addEventListener("click", () => { gridPage = Number(d.dataset.gp); renderGridBody(); });
}
function renderNotificationsBody() {
  if (!notifications.length) { bodyEl.innerHTML = `<div class="emptynew">${ICONS.bell}<div><b>No notifications yet</b><span>New system notifications show up here, the way they do in the notch.</span></div></div>`; return; }
  bodyEl.innerHTML = `<div class="notifpage">${notifications.map(n => `
    <div class="nrow"><span class="nicon">${ICONS.bell}</span><div class="nbody"><b>${esc(n.title)}</b><span>${esc(n.body)}</span></div><span class="mono dim sm">${esc(n.app)}</span></div>`).join("")}</div>`;
}
function renderDownloadsBody() {
  bodyEl.innerHTML = `<div class="dlpage">${downloads.map(d => `
    <div class="dlrow"><span class="ai" style="width:15px">${ICONS.doc}</span><span class="st">${esc(d.name)}</span>
      ${d.done ? `<span class="mono sm dim" style="margin-left:auto">Done</span>` : `<span class="meter" style="margin-left:auto;width:90px"><b style="width:${Math.round(d.fraction * 100)}%"></b></span><span class="mono sm" style="width:34px;text-align:right">${Math.round(d.fraction * 100)}%</span>`}</div>`).join("")}</div>`;
}
function renderClockRun() {
  bodyEl.innerHTML = `<div class="clockrun">
    <button class="ghost" data-cr="back">${ICONS["chevron.left"]}</button>
    <span class="st">${timer.running || timer.left ? "Timer" : "Stopwatch"}</span>
    <span style="flex:1"></span>
    <button class="ghost" data-cr="pause">${timer.running ? ICONS["pause.fill"] : ICONS["play.fill"]}</button>
    <button class="ghost" data-cr="close">${ICONS.xmark}</button>
  </div>`;
  bodyEl.querySelector("[data-cr=back]").addEventListener("click", () => { expanded = true; expandedTab = "timer"; apply(); });
  bodyEl.querySelector("[data-cr=pause]").addEventListener("click", () => { timer.running = !timer.running; apply(); });
  bodyEl.querySelector("[data-cr=close]").addEventListener("click", () => { timer.running = false; timer.left = 0; expanded = false; apply(); });
}
function renderAgentCard() {
  cardEl.innerHTML = `<div class="agentcard" style="padding:14px 16px">
    <div class="ahead"><span class="ai c-orange" style="width:16px">${ICONS.bolt}</span><b>${esc(agentReq.name)}</b><span class="dim">wants to ${esc(agentReq.cmd)}</span></div>
    <div class="agentcmd">$ npm test -- --run</div>
    <div class="abtns"><button class="deny" data-r="Deny">Deny</button><button class="allow" data-r="Allow">Allow</button></div>
  </div>`;
  for (const b of cardEl.querySelectorAll(".abtns button")) b.addEventListener("click", (e) => {
    e.stopPropagation();
    toast(`${agentReq.name}: ${b.dataset.r}ed`);
    notify({ app: agentReq.name, title: b.dataset.r === "Allow" ? "Request allowed" : "Request denied", body: agentReq.cmd, icon: "bolt" });
    alert = null; apply();
  });
}

/* --------------------------------------------- presentation application */
function apply() {
  const p = presentation();
  const live = p.t === "compact" && ["call", "timer", "stopwatch", "agents"].includes(p.primary);
  const nowMs = Date.now();
  const secs = live ? Math.floor(
    p.primary === "call" ? (nowMs - call.start) / 1000
    : p.primary === "timer" ? timer.left
    : p.primary === "stopwatch" ? swNow()
    : (nowMs - agents.live[0].started) / 1000
  ) : 0;
  const keySecs = p.t === "compact" && p.primary === "stopwatch" ? swNow() : secs;
  const key = JSON.stringify(p) + "|" + hovering + "|" + keySecs;
  if (key === curKey) return;
  curKey = key;
  if (cardEl) cardEl.hidden = p.t !== "alert" || p.alert.kind !== "agentRequest";

  if (p.t === "hud") {
    const c = alertContent(p.alert);
    hideNook();
    earL.innerHTML = c.l; earR.innerHTML = c.r;
    box(compactW(), compactH(), R_COMPACT, FLARE_COMPACT);
    return;
  }
  if (p.t === "alert") {
    hideNook();
    if (p.alert.kind === "agentRequest") {
      earL.innerHTML = ""; earR.innerHTML = "";
      slit.setAttribute("data-open", "");
      cardEl.hidden = false;
      box(500, 32 + 2 + 112 + 14, R_ALERT, FLARE_COMPACT);
      renderAgentCard();
      return;
    }
    cardEl.hidden = true;
    const c = alertContent(p.alert);
    earL.innerHTML = c.l; earR.innerHTML = c.r;
    const wide = (COMPACT_ALERT_ROW.has(p.alert.kind) ? NAMED_ALERT_EAR : ALERT_EAR) * 2 + NOTCH.w;
    box(Math.max(compactW(), wide), 40, R_ALERT, FLARE_COMPACT);
    return;
  }
  if (p.t === "expanded") {
    earL.innerHTML = ""; earR.innerHTML = "";
    slit.setAttribute("data-open", "");
    if (p.tab === "nowplaying") box(PLAYER.w, PLAYER.h, R_EXPANDED, FLARE_EXPANDED);
    else box(NOOK.w, PAGE_H[p.tab] || NOOK.h, R_EXPANDED, FLARE_EXPANDED);
    nook.hidden = false;
    requestAnimationFrame(() => requestAnimationFrame(() => nook.classList.add("is-open")));
    renderNook();
    return;
  }
  if (p.t === "clockRunning") {
    hideNook();
    earL.innerHTML = icon("chevron.left", 13, "dim").outerHTML + `<span class="st">${p.mode === "timer" ? "Timer" : "Stopwatch"}</span>`;
    earR.innerHTML = `<span class="mono big c-orange">${fmtClock(p.mode === "timer" ? timer.left : stopwatch.elapsed)}</span><span class="ai">${ICONS["pause.fill"]}</span>`;
    box(CLOCKRUN.w, CLOCKRUN.h, R_COMPACT, FLARE_COMPACT);
    return;
  }
  hideNook();
  if (p.t === "idle") {
    earL.innerHTML = `<span class="ai" style="width:13px;color:rgba(255,255,255,.55)">${ICONS.aperture}</span><span class="st dim">Arrowslit</span>`;
    earR.innerHTML = "";
    box(compactW(), compactH(), R_COMPACT, FLARE_COMPACT);
    return;
  }
  if (p.t === "compact") {
    const c = earContent(p.primary);
    earL.innerHTML = c.l; earR.innerHTML = c.r;
    const grow = hovering ? HOVER_GROWTH : { w: 0, h: 0 };
    box(compactW() + 2 * grow.w, compactH() + grow.h, R_COMPACT, FLARE_COMPACT);
  } else if (p.t === "hidden-peek") {
    earL.innerHTML = ""; earR.innerHTML = "";
    box(NOTCH.w + 2 * HOVER_GROWTH.w, NOTCH.h + HOVER_GROWTH.h, R_COMPACT, FLARE_COMPACT);
  } else {
    earL.innerHTML = ""; earR.innerHTML = "";
    box(NOTCH.w, NOTCH.h, R_COMPACT, FLARE_COMPACT);
  }
}
function hideNook() {
  slit.removeAttribute("data-open");
  nook.classList.remove("is-open");
  nook.hidden = true;
  if (cardEl) cardEl.hidden = true;
}

/* ------------------------------------------------------- notifications */
function notify({ app = "Arrowslit", title = "", body = "", icon = "bell", onClick = null }) {
  const entry = { app, title, body, at: Date.now() };
  notifications.unshift(entry);
  if (notifications.length > 12) notifications.pop();
  const el = h("div.slit-notif");
  el.innerHTML = `
    <span class="nicon">${ICONS[icon] || ICONS.bell}</span>
    <div class="nbody"><b>${esc(title)}</b><span>${esc(body)}</span></div>
    <button class="nclose" aria-label="Close">×</button>`;
  notifStack.append(el);
  requestAnimationFrame(() => requestAnimationFrame(() => el.classList.add("is-on")));
  const dismiss = () => { el.classList.remove("is-on"); setTimeout(() => el.remove(), 300); };
  el.querySelector(".nclose").addEventListener("click", (e) => { e.stopPropagation(); dismiss(); });
  el.addEventListener("click", () => { onClick?.(); dismiss(); });
  setTimeout(dismiss, 6500);
  fire({ kind: "systemNotification", title, app });
  return entry;
}
function tickDownloads() {
  const active = downloads.find(d => d.active && !d.done);
  if (!active) {
    if (Date.now() > (tickDownloads.nextAt || 0)) {
      const name = ["Arrowslit-0.12.10.zip", "Assets-Pack.dmg", "Recording-2026-11-07.mov"][Math.floor(Math.random() * 3)];
      downloads.unshift({ id: "dl-" + Date.now(), name, fraction: 0, active: true, done: false });
      tickDownloads.nextAt = Date.now() + 90_000;
    }
    return;
  }
  active.fraction = Math.min(1, active.fraction + 0.011);
  if (active.fraction >= 1) {
    active.done = true; active.active = false;
    notify({ app: "Downloads", title: active.name, body: "Downloaded — open the notch to see it.", icon: "arrow.down" });
    fire({ kind: "download" });
    tickDownloads.nextAt = Date.now() + 45_000;
  }
}

/* ------------------------------------------------------------- services */
function fire(a) { alert = a; apply(); setTimeout(() => { if (alert === a) { alert = null; apply(); } }, (ALERT_DURATION[a.kind] || 3) * 1000); }
function toast(msg) { toastEl.textContent = msg; toastEl.classList.add("is-on"); clearTimeout(toast._t); toast._t = setTimeout(() => toastEl.classList.remove("is-on"), 2200); }
function tick() {
  if (music.playing) { music.t += 1; if (music.t >= music.tracks[music.i].len) { music.i = (music.i + 1) % music.tracks.length; music.t = 0; } }
  if (timer.running) { timer.left -= 1; if (timer.left <= 0) { timer.left = 0; timer.running = false; timer.justFinished = true; fire({ kind: "timerFinished" }); } }
  if (expanded && expandedTab === "timer" && timer.mode !== "stopwatch" && (timer.running || timer.left)) {
    const el = bodyEl.querySelector(".bigread"); if (el) el.textContent = fmtClock(timer.left);
  }
  if (expanded && expandedTab === "home" && (timer.running || timer.left)) {
    const el = bodyEl.querySelector(".hsec--timer .mono"); if (el) el.textContent = fmtClock(timer.left);
  }
  if (call.active && Date.now() > call.endAt) {
    call.active = false;
    notify({ app: "FaceTime", title: "Call ended", body: "Chrome · " + fmtClock((Date.now() - call.start) / 1000), icon: "phone.fill" });
  }
  tickDownloads();
  apply();
  if (expanded && (expandedTab === "downloads" || expandedTab === "notifications")) renderNook();
}

/* --------------------------------------------------- the showcase tour */
// Showcase tour: when the page is quiet, the nook opens itself on each page so
// visitors see everything Arrowslit does. Any interaction pauses the tour.
const TOUR = ["home", "calendar", "sports", "agents", "clipboard", "grid", "stats", "keepawake", "scratchpad", "reminders", "files"];
const QUIET = new URLSearchParams(location.search).has("notour");
const TOUR_GAP = 5000; // ms between one feature closing and the next opening
let tourIdx = 0, tourT = 0, tourPauseUntil = 0, lastInteract = 0;
function tourStep() {
  if (QUIET) return;
  if (hovering || expanded || document.hidden || Date.now() < tourPauseUntil || document.querySelector("html.intro")) return scheduleTour(TOUR_GAP);
  expanded = true; expandedTab = TOUR[tourIdx++ % TOUR.length]; apply();
  tourT = setTimeout(() => { expanded = false; apply(); scheduleTour(TOUR_GAP); }, 4200);
}
function scheduleTour(ms) { clearTimeout(tourT); tourT = setTimeout(tourStep, ms); }
function poke() { lastInteract = Date.now(); tourPauseUntil = Date.now() + 30000; clearTimeout(tourT); scheduleTour(12000); }

/* --------------------------------------------------- the alert cycle ---- */
const LOOP_ALERTS = ["charging", "headphones", "level", "track", "lowBattery", "upcomingEvent", "download", "microphone", "update", "sportsGoal"];
let li = 0, loopT = 0;
function loopNext() {
  if (QUIET) return;
  const kind = LOOP_ALERTS[li++ % LOOP_ALERTS.length];
  if (kind === "level") fire({ kind: "level", kind2: li % 4 < 2 ? "volume" : "brightness", value: 0.3 + Math.random() * 0.55 });
  else if (kind === "microphone") fire({ kind: "microphone", muted: !call.muted });
  else fire({ kind });
  scheduleLoop();
}
function scheduleLoop() {
  clearTimeout(loopT);
  if (matchMedia("(prefers-reduced-motion: reduce)").matches) return;
  loopT = setTimeout(() => { if (quiet()) return scheduleLoop(); loopNext(); }, 9500);
}
function quiet() { return expanded || hovering || document.hidden || document.querySelector("html.intro"); }

/* ---------------------------------------------------------- context menu */
let slitQuit = false;
function showMenuAt(x, y, items) {
  ctx.innerHTML = "";
  ctx.style.setProperty("--mx", x + "px");
  ctx.style.setProperty("--my", y + "px");
  ctx.classList.add("anchored");
  for (const it of items) {
    if (it.sep) { ctx.append(h("div.sep")); continue; }
    ctx.append(h("button.item", { on: { click: () => { closeCtx(); it.fn?.(); } } }, it.label));
  }
  ctx.classList.add("is-on");
}
function showCtx() {
  ctx.innerHTML = "";
  const items = [
    { label: music.playing ? "Pause" : "Play", fn: () => { music.playing = !music.playing; apply(); } },
    { label: "Next Track", fn: () => { music.i = (music.i + 1) % music.tracks.length; music.t = 0; apply(); } },
    { label: call.muted ? "Unmute Microphone" : "Mute Microphone", fn: () => { call.muted = !call.muted; } },
    { label: "Start Stopwatch", fn: () => { stopwatch.elapsed = 0; stopwatch.base = 0; stopwatch.anchor = Date.now(); stopwatch.active = true; expanded = true; expandedTab = "timer"; apply(); } },
    { label: keepAwake.on ? "Keep Awake: On" : "Keep Awake: Off", fn: () => { keepAwake.on = !keepAwake.on; } },
    { sep: true },
    { label: "Close", fn: () => {} },
  ];
  for (const it of items) {
    if (it.sep) { ctx.append(h("div.sep")); continue; }
    ctx.append(h("button.item", { on: { click: () => { closeCtx(); it.fn?.(); } } }, it.label));
  }
  ctx.classList.add("is-on");
}
function closeCtx() { ctx.classList.remove("is-on"); ctx.classList.remove("anchored"); }

/* ------------------------------------------------------------------ CSS */
const CSS = `
:host { display: block; position: fixed; top: 0; left: 0; right: 0; height: 240px; z-index: 320; pointer-events: none;
  font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", Roboto, sans-serif;
  -webkit-font-smoothing: antialiased; }
.slit { position: absolute; top: 0; left: 50%; transform: translateX(-50%);
  width: var(--w, 281.5px); height: var(--h, 32px); border-radius: 0 0 var(--r, 12px) var(--r, 12px);
  background: #090909; color: #fff; overflow: visible;
  box-shadow: 0 10px 28px rgba(0, 0, 0, .28);
  transition: width .48s cubic-bezier(.32,.72,0,1), height .48s cubic-bezier(.32,.72,0,1), border-radius .48s cubic-bezier(.32,.72,0,1); }
.slit::before, .slit::after { content: ""; position: absolute; top: 0; width: var(--flare, 6px); height: var(--flare, 6px); pointer-events: none; }
.slit::before { left: calc(var(--flare, 6px) * -1); background: radial-gradient(circle at 0% 100%, transparent 0 calc(var(--flare, 6px) - .7px), #090909 var(--flare, 6px)); }
.slit::after  { right: calc(var(--flare, 6px) * -1); background: radial-gradient(circle at 100% 100%, transparent 0 calc(var(--flare, 6px) - .7px), #090909 var(--flare, 6px)); }
.slit__face { position: absolute; inset: 0; display: flex; align-items: center; justify-content: center;
  background: none; border: 0; padding: 0; color: inherit; font: inherit; cursor: default; pointer-events: auto;
  transition: opacity .15s ease-out, transform .2s cubic-bezier(.34,1.4,.44,1); }
.slit__face:active { opacity: .7; transform: scale(.9); }
.slit[data-open] .slit__face { opacity: 0; pointer-events: none; }
.slit__ear { flex: 1 1 0; min-width: 0; display: flex; align-items: center; gap: 8px; padding: 0 11px;
  font-size: 12px; font-weight: 600; line-height: 1; white-space: nowrap; overflow: hidden; }
.slit__ear--r { justify-content: flex-end; gap: 4px; }
.slit__cam { flex: 0 0 auto; width: 7px; height: 7px; border-radius: 50%; background: #101014;
  box-shadow: inset 0 0 2px 1px rgba(70, 90, 140, .55), 0 0 0 2.5px #050507; }
.ai { display: inline-flex; width: 15px; height: 15px; flex: 0 0 auto; }
.ai svg { width: 100%; height: 100%; }
.c-orange { color: #FF9F0A; } .c-red { color: #FF453A; } .c-green { color: #30D158; }
.c-blue { color: #0A84FF; } .c-yellow { color: #FFD60A; } .dim { color: rgba(255,255,255,.55); }
.mono { font-variant-numeric: tabular-nums; }
.big { font-size: 16px; font-weight: 500; } .sm { font-size: 11px; font-weight: 500; }
.st { font-size: 12px; font-weight: 600; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.art { display: inline-block; width: 20px; height: 20px; border-radius: 5px; flex: 0 0 auto; box-shadow: inset 0 0 0 .5px rgba(255,255,255,.22); }
.bars { display: inline-flex; align-items: flex-end; gap: 2px; height: 14px; flex: 0 0 auto; }
.bars i { width: 3px; height: 5px; border-radius: 1.5px; background: var(--tint, #FF9F0A); animation: aslit-eq .9s ease-in-out infinite; }
.bars i:nth-child(2) { animation-delay: .15s; } .bars i:nth-child(3) { animation-delay: .3s; } .bars i:nth-child(4) { animation-delay: .45s; }
@keyframes aslit-eq { 0%,100% { height: 5px; } 50% { height: 14px; } }
.appicon { width: 18px; height: 18px; border-radius: 4.5px; background: #1e1e23; display: inline-flex; align-items: center; justify-content: center; color: #fff; }
.appicon svg { width: 12px; height: 12px; }
.dot { width: 6px; height: 6px; border-radius: 50%; background: #FF9F0A; box-shadow: inset 0 0 0 .5px rgba(255,255,255,.5); flex: 0 0 auto; }
.batt { display: inline-flex; width: 27px; height: 13px; } .batt svg { width: 100%; height: 100%; }
.meter { display: inline-block; width: 56px; height: 4px; border-radius: 2px; background: rgba(255,255,255,.2); overflow: hidden; }
.meter b { display: block; height: 100%; border-radius: inherit; background: #fff; }
.lvl { display: inline-block; width: 64px; height: 5px; border-radius: 3px; background: rgba(255,255,255,.22); overflow: hidden; }
.lvl b { display: block; height: 100%; width: var(--v, 50%); border-radius: inherit; background: #fff; transition: width .35s ease; }
.ring { animation: aslit-ring 1.6s ease-in-out infinite; }
@keyframes aslit-ring { 0%,100% { transform: rotate(-8deg); } 50% { transform: rotate(8deg); } }
.mark { display: inline-flex; width: 13px; height: 13px; animation: aslit-breathe 1.8s ease-in-out infinite; }
.mark svg { width: 100%; height: 100%; }
@keyframes aslit-breathe { 0%,100% { opacity: .55; transform: scale(.9); } 50% { opacity: 1; transform: scale(1.05); } }

.slit__nook { position: absolute; top: 0; left: 0; width: 100%; height: 100%; display: flex; flex-direction: column;
  opacity: 0; transform: translateY(-6px) scale(.99); transform-origin: top; pointer-events: none;
  transition: opacity .38s cubic-bezier(.25,.1,.25,1) .05s, transform .38s cubic-bezier(.25,.1,.25,1) .05s; }
.slit__nook.is-open { opacity: 1; transform: none; pointer-events: auto; }
.slit__nook[hidden] { display: none; }
.slit__strip { flex: 0 0 32px; display: flex; align-items: center; padding: 0 11px; }
.slit-tabs { display: flex; align-items: center; gap: 2px; flex: 1 1 0; }
.slit-tab { border: 0; background: none; color: rgba(255,255,255,.55); font: 600 12px/1 inherit; padding: 5px 8px; border-radius: 7px; cursor: pointer; transition: background .15s ease-out, color .15s ease-out; }
.slit-tab:hover { color: #fff; background: rgba(255,255,255,.08); }
.slit-tab.is-on { color: #fff; background: rgba(255,255,255,.14); }
.slit-cam { flex: 0 0 auto; width: 187.5px; display: flex; justify-content: center; }
.slit-cam::before { content: ""; width: 7px; height: 7px; border-radius: 50%; background: #101014; box-shadow: inset 0 0 2px 1px rgba(70,90,140,.55), 0 0 0 2.5px #050507; }
.slit-chips { display: flex; align-items: center; gap: 4px; flex: 1 1 0; justify-content: flex-end; }
.slit-chip { display: inline-flex; align-items: center; justify-content: center; width: 24px; height: 24px; border: 0; border-radius: 7px; background: none; color: rgba(255,255,255,.55); cursor: pointer; transition: background .15s ease-out, color .15s ease-out; }
.slit-chip:hover { background: rgba(255,255,255,.08); color: #fff; }
.slit-chip svg { width: 14px; height: 14px; }
.slit__body { flex: 1 1 auto; min-height: 0; display: flex; gap: 10px; padding: 10px 12px 14px; }

.mediacard { flex: 0 0 210px; display: flex; flex-direction: column; gap: 8px; background: #161616; border-radius: 12px; padding: 10px 11px; }
.homecol { flex: 1 1 auto; min-width: 0; display: flex; flex-direction: column; gap: 8px; }
.mrow { display: flex; align-items: center; gap: 8px; min-width: 0; }
.mrow .art { width: 34px; height: 34px; border-radius: 8px; }
.mtxt { min-width: 0; flex: 1; display: flex; flex-direction: column; gap: 2px; }
.mtxt b { font-size: 12px; font-weight: 600; color: #fff; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.mtxt span { font-size: 11px; color: rgba(255,255,255,.55); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.ghost { border: 0; background: none; color: rgba(255,255,255,.55); cursor: pointer; padding: 2px; border-radius: 6px; display: inline-flex; transition: color .15s ease-out, opacity .15s ease-out, transform .2s cubic-bezier(.34,1.4,.44,1); }
.ghost:hover { color: #fff; } .ghost:active { transform: scale(.9); opacity: .7; }
.ghost svg { width: 12px; height: 12px; }
.mrow2 { display: flex; align-items: center; gap: 8px; }
.mrow2 .mono { font-size: 10px; font-weight: 500; font-variant-numeric: tabular-nums; }
.hairline { border-top: 1px solid rgba(255,255,255,.1); }
.sechead { display: flex; align-items: center; gap: 6px; font-size: 11px; color: rgba(255,255,255,.55); }
.sechead b { color: #fff; font-size: 11px; font-weight: 600; } .sechead .chev { width: 10px; height: 10px; margin-left: auto; color: rgba(255,255,255,.38); } .sechead .chev svg { width: 100%; height: 100%; }
.calrow, .timerrow { display: flex; align-items: center; gap: 8px; height: 30px; }
.calrow .st { color: #fff; }
.timerrow .mono { font-size: 12px; }
.tbtns { display: flex; gap: 5px; margin-left: auto; }
.min { border: 0; border-radius: 8px; padding: 5px 9px; font: 600 11px/1 inherit; color: rgba(255,255,255,.55); background: #1e1e23; cursor: pointer; transition: background .15s ease-out, color .15s ease-out, transform .2s cubic-bezier(.34,1.4,.44,1); }
.min:hover { color: #fff; background: #26262c; } .min:active { transform: scale(.9); opacity: .7; }
.empty { margin: auto; text-align: center; color: rgba(255,255,255,.55); font-size: 12px; line-height: 1.5; max-width: 340px; }
.empty svg { width: 20px; height: 20px; display: block; margin: 0 auto 7px; opacity: .7; }
.empty b { display: block; color: #fff; font-size: 12.5px; margin-bottom: 2px; }

.timerpane { flex: 1 1 auto; display: flex; flex-direction: column; gap: 4px; }
.trow { display: flex; align-items: center; justify-content: space-between; }
.modes { display: flex; gap: 14px; }
.mode { border: 0; background: none; color: rgba(255,255,255,.55); font: 600 13px/1 inherit; padding: 4px 0 7px; cursor: pointer; border-bottom: 2px solid transparent; }
.mode.is-on { color: #fff; border-bottom-color: #FF9F0A; }
.start { border: 0; border-radius: 999px; padding: 8px 22px; font: 600 13px/1 inherit; color: #000; background: #FF9F0A; cursor: pointer; transition: opacity .15s ease-out, transform .2s cubic-bezier(.34,1.4,.44,1); }
.start:hover { opacity: .85; } .start:active { transform: scale(.94); opacity: .7; }
.ruler { position: relative; height: 34px; margin-top: 6px; cursor: ew-resize; touch-action: none; }
.ticks { position: absolute; inset: 0; }
.tick { position: absolute; bottom: 6px; width: 2.5px; height: 16px; border-radius: 1px; background: rgba(255,159,10,.22); }
.tick.on { background: #FF9F0A; }
.tick.cur { height: 22px; background: #FFD60A; }
.tick small { position: absolute; top: -13px; left: 50%; transform: translateX(-50%); font: 500 9px/1 inherit; color: rgba(255,255,255,.4); font-variant-numeric: tabular-nums; }
.cursor { position: absolute; bottom: 0; width: 0; height: 0; border: 4.5px solid transparent; border-bottom-color: #FF9F0A; transform: translateX(-50%); }
.timerpane .big { font-size: 34px; font-weight: 600; }

.calpane { flex: 1 1 auto; display: flex; flex-direction: column; gap: 6px; }
.calgrid { display: grid; grid-template-columns: repeat(7, 1fr); gap: 2px 4px; text-align: center; }
.calgrid small { font: 600 8.5px/1 inherit; color: rgba(255,255,255,.38); }
.calgrid span { font: 500 10.5px/1.5 inherit; color: rgba(255,255,255,.85); border-radius: 6px; }
.calgrid span.today { background: #FF453A; color: #fff; font-weight: 600; }
.tlabel { font: 600 9.5px/1 inherit; letter-spacing: .08em; color: rgba(255,255,255,.4); }
.evrow { display: flex; align-items: center; gap: 7px; background: #161616; border-radius: 9px; padding: 6px 9px; }
.evrow .st { color: #fff; }

.sportspane { flex: 1 1 auto; display: flex; flex-direction: column; gap: 7px; }
.chips { display: flex; align-items: center; gap: 5px; }
.chip { border: 0; border-radius: 999px; padding: 4px 11px; font: 600 10.5px/1 inherit; color: rgba(255,255,255,.6); background: #1e1e23; cursor: pointer; }
.chip.is-on { background: rgba(255,159,10,.18); color: #FF9F0A; }
.quota { white-space: nowrap; }
.matchrow { display: flex; align-items: center; gap: 8px; background: #161616; border-radius: 10px; padding: 7px 10px; }
.matchrow .st { color: #fff; }

.agentspane { flex: 1 1 auto; display: flex; flex-direction: column; gap: 7px; overflow-y: auto; }
.agentcard { background: #161616; border-radius: 12px; padding: 8px 11px; display: flex; flex-direction: column; gap: 5px; }
.ahead { display: flex; align-items: center; gap: 8px; font-size: 12px; color: #fff; }
.ahead b { font-size: 12.5px; font-weight: 600; } .ahead .dim { color: rgba(255,255,255,.55); }
.ameter { height: 4px; border-radius: 2px; background: rgba(255,255,255,.14); overflow: hidden; }
.ameter b { display: block; height: 100%; background: var(--tint, #FF9F0A); }
.asub { display: flex; justify-content: space-between; font-size: 10.5px; color: rgba(255,255,255,.55); }

.clips { flex: 1 1 auto; display: flex; gap: 8px; overflow-x: auto; }
.clipcard { flex: 0 0 150px; display: flex; flex-direction: column; justify-content: space-between; gap: 6px; background: #161616; border: 1px solid rgba(255,255,255,.1); border-radius: 12px; padding: 9px 10px; text-align: left; cursor: pointer; transition: background .15s ease-out, transform .2s cubic-bezier(.34,1.4,.44,1); }
.clipcard:hover { background: #1e1e23; } .clipcard:active { transform: scale(.96); opacity: .7; }
.ctext { font: 500 11px/1.4 inherit; color: #fff; display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden; }
.capp { font: 500 10px/1 inherit; color: rgba(255,255,255,.4); }

.statgrid { flex: 1 1 auto; display: grid; grid-template-columns: repeat(2, 1fr); gap: 7px; }
.statcard { display: flex; align-items: center; gap: 7px; background: #161616; border-radius: 10px; padding: 8px 11px; }
.statcard .st { color: rgba(255,255,255,.6); font-weight: 500; }

.katiles { flex: 1 1 auto; display: flex; gap: 8px; align-items: center; }
.katile { display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 6px; width: 96px; height: 76px; border: 1px solid rgba(255,255,255,.1); border-radius: 12px; background: #161616; color: #fff; font: 600 11px/1 inherit; cursor: pointer; transition: background .15s ease-out, transform .2s cubic-bezier(.34,1.4,.44,1); }
.katile.is-on { border-color: rgba(48,209,88,.5); }
.katile.is-on .ai { color: #30D158; }
.katile:active { transform: scale(.94); opacity: .7; }
.kanote { flex: 1; font-size: 11.5px; line-height: 1.5; color: rgba(255,255,255,.55); }

.scratch { flex: 1 1 auto; }
.scratch textarea { width: 100%; height: 100%; resize: none; border: 0; outline: none; background: #161616; border-radius: 12px; padding: 10px 12px; color: #fff; font: 400 12px/1.6 inherit; box-sizing: border-box; }
.rems { flex: 1 1 auto; display: flex; flex-direction: column; gap: 7px; justify-content: center; }
.rem { display: flex; align-items: center; gap: 9px; background: #161616; border-radius: 10px; padding: 8px 11px; cursor: pointer; }
.rem input { accent-color: #FF9F0A; }
.mirror { flex: 1 1 auto; display: flex; gap: 12px; align-items: center; }
.mpreview { flex: 0 0 180px; height: 100%; border-radius: 12px; background: #161616; display: grid; place-items: center; overflow: hidden; }
.mpreview video { width: 100%; height: 100%; object-fit: cover; border-radius: 12px; }
.mtext { display: flex; flex-direction: column; gap: 8px; }
.mtext small { font-size: 12px; line-height: 1.5; color: rgba(255,255,255,.55); }

.lgrid { flex: 1 1 auto; display: grid; grid-template-columns: repeat(4, 1fr); gap: 8px; overflow-y: auto; align-content: start; }
.lgrid.real { grid-template-columns: repeat(4, 1fr); }
.ltile { display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 4px; height: 76px; border-radius: 12px; background: #161616; border: 1px solid rgba(255,255,255,.06); color: #fff; cursor: pointer; transition: background .15s ease-out, transform .2s cubic-bezier(.34,1.4,.44,1), opacity .15s ease-out; }
.ltile:hover { background: #1e1e23; } .ltile:active { transform: scale(.9); opacity: .7; }
.ltile b { font: 600 11.5px/1 inherit; } .ltile small { font: 500 9.5px/1 inherit; color: rgba(255,255,255,.38); letter-spacing: .04em; }
.ltico { display: inline-flex; width: 20px; height: 20px; } .ltico svg { width: 100%; height: 100%; }

.clockrun { width: 100%; display: flex; align-items: center; gap: 9px; padding: 0 4px; }
.clockrun .st { color: #fff; }
.slit-toast { position: absolute; left: 50%; bottom: 10px; transform: translate(-50%, 6px); background: rgba(40,40,46,.96); border: 1px solid rgba(255,255,255,.1); color: #fff; font-size: 11px; line-height: 1; padding: 6px 12px; border-radius: 999px; opacity: 0; pointer-events: none; white-space: nowrap; transition: opacity .2s ease, transform .2s ease; z-index: 3; }
.slit-toast.is-on { opacity: 1; transform: translate(-50%, 0); }

.slit-ctx { position: fixed; top: 40px; left: 50%; transform: translateX(-50%) scale(.96); transform-origin: top center; z-index: 330;
  min-width: 200px; background: rgba(28,28,32,.97); border: 1px solid rgba(255,255,255,.1); border-radius: 12px; padding: 5px;
  box-shadow: 0 18px 44px rgba(0,0,0,.45); opacity: 0; pointer-events: none; transition: opacity .15s ease-out, transform .15s cubic-bezier(.34,1.4,.44,1); }
.slit-ctx.is-on { opacity: 1; transform: translateX(-50%) scale(1); pointer-events: auto; }
.slit-ctx .item { display: block; width: 100%; border: 0; background: none; color: #fff; font: 500 12.5px/1 inherit; text-align: left; padding: 8px 10px; border-radius: 9px; cursor: pointer; }
.slit-ctx .item:hover { background: rgba(255,255,255,.09); } .slit-ctx .item:active { opacity: .7; }
.slit-ctx .sep { border-top: 1px solid rgba(255,255,255,.1); margin: 4px 6px; }

/* focus rings off inside the notch (matches the app) */
.slit button:focus, .slit button:focus-visible, .slit input:focus, .slit textarea:focus { outline: none; }
.trrow { display: flex; align-items: center; gap: 18px; }
.trrow .rulernew { flex: 1 1 auto; min-width: 0; }
.trrow .bigread { flex: 0 0 auto; margin: 0; }
.bigread { font-size: 34px; font-weight: 600; color: #FF9F0A; }

/* glass theme + pitch black */
.slit { background: var(--panel, #090909); }
.slit.glass { -webkit-backdrop-filter: blur(26px) saturate(1.3); backdrop-filter: blur(26px) saturate(1.3); box-shadow: 0 10px 34px rgba(0,0,0,.35), inset 0 0 0 .5px rgba(255,255,255,.14); }
.slit.pitch { box-shadow: none; }
.slit.pitch::before, .slit.pitch::after { background: none; }
.slit.glass::before { background: radial-gradient(circle at 0% 100%, transparent 0 calc(var(--flare, 6px) - .7px), var(--panel, #090909) var(--flare, 6px)); }
.slit.glass::after { background: radial-gradient(circle at 100% 100%, transparent 0 calc(var(--flare, 6px) - .7px), var(--panel, #090909) var(--flare, 6px)); }
.slit.elongated { --elongate: 1; }

/* settings window */
.slit-settings { position: fixed; top: 196px; left: 50%; transform: translateX(-50%) translateY(10px) scale(.98); width: min(392px, calc(100vw - 16px));
  background: rgba(22,22,24,.98); border: 1px solid rgba(255,255,255,.1); border-radius: 16px; z-index: 340;
  box-shadow: 0 24px 64px rgba(0,0,0,.5); opacity: 0; pointer-events: none; transition: opacity .2s ease-out, transform .25s cubic-bezier(.34,1.4,.44,1);
  font-size: 12px; color: #fff; overflow: hidden; }
.slit-settings.is-on { opacity: 1; transform: translateX(-50%); pointer-events: auto; }
.shead { display: flex; align-items: center; justify-content: space-between; padding: 8px 10px; border-bottom: 1px solid rgba(255,255,255,.1); }
.stabs { display: flex; flex-wrap: wrap; gap: 2px; min-width: 0; }
.stab { flex: 0 0 auto; border: 0; background: none; color: rgba(255,255,255,.55); font: 600 11.5px/1 inherit; padding: 6px 9px; border-radius: 7px; cursor: pointer; }
.stab.is-on { background: rgba(255,255,255,.12); color: #fff; }
.sx { border: 0; background: none; color: rgba(255,255,255,.5); font: 500 16px/1 inherit; cursor: pointer; padding: 2px 6px; border-radius: 6px; }
.sx:hover { color: #fff; background: rgba(255,255,255,.08); }
.sbody { padding: 8px 12px 12px; max-height: 356px; overflow-y: auto; }
.sgroup { font: 600 10px/1 inherit; letter-spacing: .08em; text-transform: uppercase; color: rgba(255,255,255,.4); margin: 10px 2px 4px; }
.srow { display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 7px 2px; border-bottom: 1px solid rgba(255,255,255,.06); }
.srow:last-child { border-bottom: 0; }
.stext { display: flex; flex-direction: column; gap: 2px; min-width: 0; }
.stext b { font: 600 12px/1.2 inherit; color: #fff; }
.stext small { font: 500 10.5px/1.35 inherit; color: rgba(255,255,255,.5); }
.sval { font: 500 10.5px/1 inherit; color: #FF9F0A !important; }
.stoggle { width: 34px; height: 20px; border-radius: 999px; border: 0; background: rgba(255,255,255,.16); position: relative; cursor: pointer; flex: 0 0 auto; transition: background .15s ease-out; }
.stoggle i { position: absolute; top: 2px; left: 2px; width: 16px; height: 16px; border-radius: 50%; background: #fff; transition: left .18s cubic-bezier(.34,1.4,.44,1); }
.stoggle.is-on { background: #FF9F0A; }
.stoggle.is-on i { left: 16px; }
.sseg { display: flex; background: rgba(255,255,255,.08); border-radius: 8px; padding: 2px; gap: 2px; }
.sseg-btn { border: 0; background: none; color: rgba(255,255,255,.55); font: 600 10.5px/1 inherit; padding: 5px 9px; border-radius: 6px; cursor: pointer; }
.sseg-btn.is-on { background: rgba(255,255,255,.16); color: #fff; }
.srow.slider { flex-wrap: wrap; }
.strack { width: 100%; accent-color: #FF9F0A; margin: 4px 0 0; }

/* live-demo coach */
.slit-coach { position: fixed; top: 12px; right: 14px; z-index: 345; max-width: 300px; display: flex; gap: 10px; align-items: flex-start;
  background: rgba(24,24,28,.97); border: 1px solid rgba(255,255,255,.1); border-radius: 16px; padding: 11px 12px; color: #fff;
  box-shadow: 0 16px 40px rgba(0,0,0,.4); opacity: 0; transform: translateY(-8px); pointer-events: none;
  transition: opacity .3s ease-out, transform .35s cubic-bezier(.34,1.4,.44,1); }
.slit-coach.is-on { opacity: 1; transform: none; pointer-events: auto; }
.slit-coach img { width: 34px; height: 34px; border-radius: 9px; background: #161616; padding: 6px; box-sizing: border-box; }
.coach-text { min-width: 0; display: flex; flex-direction: column; gap: 3px; }
.coach-text b { font-size: 12.5px; font-weight: 600; }
.coach-text span { font-size: 11.5px; line-height: 1.45; color: rgba(255,255,255,.55); }
.slit-coach kbd { font: 600 10px/1 inherit; background: rgba(255,255,255,.1); border-radius: 4px; padding: 1.5px 4px; }
.coach-btn { border: 0; border-radius: 999px; background: rgba(255,255,255,.12); color: #fff; font: 600 10.5px/1 inherit; padding: 5px 10px; cursor: pointer; align-self: flex-start; }
.coach-btn:hover { background: rgba(255,255,255,.2); }
.coach-x { border: 0; background: none; color: rgba(255,255,255,.5); font: 400 16px/1 inherit; cursor: pointer; padding: 0 2px; align-self: flex-start; }

/* the Arrowslit mark in the menu bar */
.aislit-mark { display: inline-flex; width: 12px; height: 16px; color: currentColor; }
.aislit-mark svg { width: 100%; height: 100%; }

/* notifications */
.slit-notifstack { position: fixed; top: 12px; right: 14px; z-index: 346; display: flex; flex-direction: column; gap: 8px; pointer-events: none; }
.slit-notif { display: flex; gap: 10px; align-items: flex-start; width: 300px; background: rgba(32,32,36,.97); border: 1px solid rgba(255,255,255,.1);
  border-radius: 16px; padding: 10px 12px; box-shadow: 0 16px 40px rgba(0,0,0,.45); opacity: 0; transform: translateX(12px); pointer-events: auto;
  transition: opacity .25s ease-out, transform .3s cubic-bezier(.34,1.4,.44,1); cursor: default; }
.slit-notif.is-on { opacity: 1; transform: none; }
.nicon { flex: 0 0 30px; width: 30px; height: 30px; border-radius: 8px; background: #1e1e23; display: inline-flex; align-items: center; justify-content: center; color: #FF9F0A; }
.nicon svg { width: 15px; height: 15px; }
.nbody { min-width: 0; flex: 1; display: flex; flex-direction: column; gap: 2px; }
.nbody b { font-size: 12px; font-weight: 600; color: #fff; }
.nbody span { font-size: 11.5px; line-height: 1.4; color: rgba(255,255,255,.6); }
.nclose { border: 0; background: none; color: rgba(255,255,255,.4); font: 400 15px/1 inherit; cursor: pointer; padding: 0 2px; }
.nclose:hover { color: #fff; }
.notifpage { flex: 1 1 auto; display: flex; flex-direction: column; gap: 6px; overflow-y: auto; }
.nrow { display: flex; gap: 8px; align-items: center; background: #161616; border-radius: 10px; padding: 7px 10px; }
.nrow .nicon { flex-basis: 24px; width: 24px; height: 24px; border-radius: 6px; }
.nrow .nicon svg { width: 12px; height: 12px; }
.nrow .nbody b { font-size: 11.5px; } .nrow .nbody span { font-size: 10.5px; }

/* downloads page */
.dlpage { flex: 1 1 auto; display: flex; flex-direction: column; gap: 6px; overflow-y: auto; }
.dlrow { display: flex; align-items: center; gap: 8px; background: #161616; border-radius: 10px; padding: 7px 10px; }

/* call card */
.callcard { flex: 0 0 210px; display: flex; flex-direction: column; gap: 10px; background: #161616; border-radius: 12px; padding: 10px 11px; }
.callcard .appicon.big { width: 34px; height: 34px; border-radius: 8px; }
.callcard .appicon.big svg { width: 18px; height: 18px; }
.callctl { display: flex; gap: 6px; margin-top: auto; }
.cbtn { flex: 1; border: 0; border-radius: 8px; padding: 6px 0; font: 600 11px/1 inherit; color: #fff; background: #26262c; cursor: pointer; }
.cbtn:hover { background: #303038; } .cbtn:active { transform: scale(.96); opacity: .7; }
.cbtn.end { background: rgba(255,69,58,.2); color: #FF453A; }
.plyr { font-size: 11.5px; color: rgba(255,255,255,.55); text-align: center; min-height: 14px; }
.pup { font-size: 10.5px; color: rgba(255,255,255,.4); text-align: center; }

/* agent request code line */
.agentcmd { font: 500 11px/1.5 ui-monospace, SFMono-Regular, Menlo, monospace; background: #101014; border-radius: 8px; padding: 7px 10px; color: rgba(255,255,255,.75); }

/* about */
.aboutbox { display: flex; flex-direction: column; align-items: center; gap: 6px; padding: 14px 10px 8px; text-align: center; }
.aboutbox img { width: 44px; height: 44px; border-radius: 11px; background: #161616; padding: 8px; box-sizing: border-box; }
.aboutbox b { font-size: 13px; font-weight: 600; color: #fff; }
.aboutbox span { font-size: 11.5px; color: rgba(255,255,255,.55); }
.aboutbox small { font-size: 10.5px; color: rgba(255,255,255,.4); }
.aboutbtns { display: flex; gap: 8px; margin-top: 6px; align-items: center; }
.slit-ctx.anchored { left: var(--mx, 50%); top: var(--my, 40px); transform: scale(.96); transform-origin: top center; }
.slit-ctx.anchored.is-on { transform: scale(1); }


/* ================= the app's current interface (v0.12.10) ================= */
.slit-tabs-pill { display: inline-flex; align-items: center; gap: 2px; background: rgba(255,255,255,.07); border-radius: 999px; padding: 3px; }
.slit-ticon { display: inline-flex; align-items: center; justify-content: center; width: 26px; height: 24px; border: 0; border-radius: 999px; background: none; color: rgba(255,255,255,.55); cursor: pointer; }
.slit-ticon .ico, .slit-chip .ico, .slit-back .ico { display: inline-flex; width: 15px; height: 15px; }
.slit-ticon .ico svg, .slit-chip .ico svg, .slit-back .ico svg { width: 100%; height: 100%; }
.slit-ticon.is-on { background: rgba(255,255,255,.16); color: #fff; }
.slit-pagebar { display: flex; align-items: center; gap: 10px; width: 100%; }
.slit-back { display: inline-flex; align-items: center; justify-content: center; width: 24px; height: 24px; border: 0; border-radius: 6px; background: none; color: rgba(255,255,255,.7); cursor: pointer; }
.slit-back:hover { color: #fff; background: rgba(255,255,255,.08); }
.slit-pagetitle { font-size: 17px; font-weight: 700; color: #fff; }
.pgap { flex: 1; }
.slit-chip { width: 26px; height: 26px; }

/* home v2 */
.homenew { flex: 1 1 auto; display: flex; gap: 14px; min-width: 0; }
.musiccard2 { flex: 0 0 210px; display: flex; flex-direction: column; gap: 7px; background: #191919; border-radius: 18px; padding: 12px 13px; }
.artline { cursor: pointer; display: flex; gap: 11px; align-items: center; min-width: 0; }
.art78 { width: 62px; height: 62px; border-radius: 10px; flex: 0 0 auto; box-shadow: inset 0 0 0 .5px rgba(255,255,255,.2); }
.hlyric { font-size: 11px; color: rgba(255,255,255,.75); font-weight: 500; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.hscrub { position: relative; height: 3px; border-radius: 2px; background: rgba(255,255,255,.2); }
.hscrub i { position: absolute; inset: 0 auto 0 0; border-radius: 2px; background: #fff; }
.hscrub b { position: absolute; top: 50%; width: 6px; height: 6px; border-radius: 50%; background: #fff; transform: translate(-50%,-50%); }
.hctl { display: flex; align-items: center; justify-content: center; gap: 26px; padding-top: 2px; }
.hctl button { border: 0; background: none; color: #fff; cursor: pointer; padding: 2px; display: inline-flex; }
.hctl button:active { opacity: .6; transform: scale(.92); }
.hctl svg { width: 15px; height: 15px; }
.hctl .hplay svg { width: 22px; height: 22px; }
.homesecs { flex: 1 1 auto; display: flex; gap: 14px; min-width: 0; }
.hsec { flex: 1 1 0; display: flex; flex-direction: column; gap: 8px; min-width: 0; }
.hsec header { display: flex; align-items: center; gap: 7px; font-size: 15px; }
.hsec header b { font-weight: 700; font-size: 15px; color: #fff; }
.hsec header .chev { margin-left: auto; width: 12px; height: 12px; color: rgba(255,255,255,.35); }
.hsec header .chev svg { width: 100%; height: 100%; }
.hev { display: flex; align-items: center; gap: 8px; }
.hev b { font-size: 14.5px; line-height: 1.25; font-weight: 700; color: #fff; }
.hevsub { font-size: 12.5px; color: rgba(255,255,255,.5); }
.vdiv { width: 1px; background: rgba(255,255,255,.12); align-self: stretch; }
.hsec--timer { gap: 10px; }
.hpills { display: flex; gap: 7px; }
.hpill { border: 0; border-radius: 999px; padding: 7px 13px; font: 600 13px/1 inherit; color: #FF9F0A; background: #2a2419; cursor: pointer; display: inline-flex; align-items: center; gap: 6px; }
.hpill:hover { background: #332b1d; } .hpill:active { transform: scale(.94); opacity: .7; }
.hpill--focus { align-self: flex-start; }

/* player v2 */
.playernew { flex: 1 1 auto; display: flex; flex-direction: column; gap: 9px; padding: 0 6px; }
.prownew { display: flex; align-items: center; gap: 12px; }
.art64 { width: 64px; height: 64px; border-radius: 12px; flex: 0 0 auto; box-shadow: inset 0 0 0 .5px rgba(255,255,255,.2); }
.pdots { margin-left: auto; display: inline-flex; gap: 3px; align-self: flex-start; padding-top: 4px; }
.pdots i { width: 5px; height: 5px; border-radius: 50%; background: #ff5964; opacity: .85; }
.pdots i:nth-child(2) { background: #ff8a5c; } .pdots i:nth-child(3) { background: #ff5c87; } .pdots i:nth-child(4) { background: #c45cff; }
.plyrnew { text-align: center; font-size: 13.5px; font-weight: 600; color: #fff; }
.pscrubnew { display: flex; align-items: center; gap: 10px; }
.pscrubnew .mono { font-size: 11px; }
.pctlnew { display: flex; align-items: center; justify-content: center; gap: 40px; }
.pctlnew button { border: 0; background: none; color: #fff; cursor: pointer; padding: 2px; display: inline-flex; }
.pctlnew svg { width: 18px; height: 18px; }
.pctlnew .pbig svg { width: 24px; height: 24px; }
.pup { text-align: center; font-size: 10.5px; color: rgba(255,255,255,.4); }

/* timer v2 */
.timernew { flex: 1 1 auto; display: flex; flex-direction: column; gap: 4px; padding: 0 4px; }
.ttop { display: flex; align-items: center; }
.modesnew { display: flex; gap: 18px; flex: 1; }
.mode { border: 0; background: none; color: rgba(255,255,255,.5); font: 700 15px/1 inherit; padding: 4px 0 8px; cursor: pointer; border-bottom: 2.5px solid transparent; }
.mode.is-on { color: #fff; border-bottom-color: #FF9F0A; }
.startnew { border: 0; border-radius: 999px; padding: 9px 22px; font: 700 14px/1 inherit; color: #000; background: #FF9F0A; cursor: pointer; }
.startnew:hover { opacity: .9; } .startnew:active { transform: scale(.95); opacity: .75; }
.rulernew { position: relative; height: 46px; margin-top: 8px; cursor: ew-resize; touch-action: none; }
.ticksnew { position: absolute; inset: 0; }
.tick { position: absolute; bottom: 8px; width: 2.5px; height: 20px; border-radius: 1.5px; background: rgba(255,159,10,.22); transform: translateX(-50%); }
.tick.on { background: #FF9F0A; }
.tick.cur { background: #FFD60A; height: 26px; }
.tick small { position: absolute; top: -14px; left: 50%; transform: translateX(-50%); font: 600 11px/1 inherit; color: rgba(255,255,255,.55); }
.cursornew { position: absolute; bottom: 1px; width: 0; height: 0; border: 5px solid transparent; border-bottom-color: #FF9F0A; transform: translateX(-50%); }
.bigread { font-size: 32px; font-weight: 600; color: #FF9F0A; text-align: right; margin-top: -34px; }

/* calendar v2 */
.calnew { flex: 1 1 auto; display: flex; gap: 18px; min-width: 0; padding: 2px 4px; }
.calleft { flex: 0 0 210px; }
.monname { font: 700 11px/1 inherit; letter-spacing: .1em; color: #FF453A; margin-bottom: 6px; }
.calgridnew { display: grid; grid-template-columns: repeat(7, 1fr); gap: 1px 2px; text-align: center; }
.calgridnew small { font: 600 9px/1.6 inherit; color: rgba(255,255,255,.4); }
.calgridnew span { font: 500 11px/1.7 inherit; color: rgba(255,255,255,.85); border-radius: 50%; width: 20px; height: 20px; line-height: 20px; margin: 0 auto; }
.calgridnew span.today { background: #FF453A; color: #fff; font-weight: 700; }
.calright { flex: 1 1 auto; display: flex; flex-direction: column; gap: 7px; border-left: 1px solid rgba(255,255,255,.12); padding-left: 16px; }
.tlabelnew { font: 700 10px/1 inherit; letter-spacing: .09em; color: rgba(255,255,255,.45); }
.evnew { display: flex; gap: 8px; align-items: flex-start; }
.evbar { flex: 0 0 3px; border-radius: 2px; align-self: stretch; min-height: 26px; }
.evtxt { display: flex; flex-direction: column; gap: 1px; min-width: 0; }
.evtxt b { font-size: 13px; font-weight: 700; color: #fff; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.evtxt span { font-size: 11.5px; }

/* sports v2 */
.sportsnew { flex: 1 1 auto; display: flex; flex-direction: column; gap: 10px; padding: 2px 4px; }
.stoprow { display: flex; align-items: center; gap: 9px; }
.stoprow b { font-size: 15px; font-weight: 700; }
.schips { display: flex; gap: 5px; margin-left: 6px; }
.schip { border: 0; border-radius: 8px; padding: 5px 10px; font: 600 12px/1 inherit; color: rgba(255,255,255,.6); background: rgba(255,255,255,.08); cursor: pointer; }
.schip.is-on { background: rgba(255,255,255,.16); color: #fff; }
.livebadge { display: inline-flex; align-items: center; gap: 5px; font: 600 11px/1 inherit; color: #30D158; margin-left: auto; }
.livebadge i { width: 5px; height: 5px; border-radius: 50%; background: #30D158; }
.smatchrow { display: flex; gap: 10px; }
.smatchcard { flex: 0 0 200px; background: #161616; border: 1px solid rgba(255,255,255,.07); border-radius: 12px; padding: 9px 11px; display: flex; flex-direction: column; gap: 6px; }
.smhead { display: flex; align-items: center; justify-content: space-between; }
.smhead small { font: 700 9.5px/1 inherit; letter-spacing: .08em; color: rgba(255,255,255,.45); }
.smhead .livebadge { margin-left: 0; font-size: 9.5px; }
.smteam { display: flex; align-items: center; gap: 7px; }
.badge { width: 18px; height: 18px; border-radius: 50%; display: inline-flex; align-items: center; justify-content: center; font: 700 8px/1 inherit; color: #fff; }
.smteam b { font-size: 13px; font-weight: 700; }
.smscore { margin-left: auto; font: 700 15px/1 inherit; }
.smlive { font: 600 9.5px/1 inherit; color: #30D158; }

/* agents v2 */
.agentsnew { flex: 1 1 auto; display: flex; flex-direction: column; gap: 8px; overflow-y: auto; padding: 2px 4px 2px; }
.agcard { background: #161616; border-radius: 13px; padding: 10px 12px; display: flex; flex-direction: column; gap: 6px; }
.aghead { display: flex; align-items: center; gap: 8px; }
.aghead b { font-size: 13.5px; font-weight: 700; }
.agmark { width: 20px; height: 20px; border-radius: 50%; display: inline-flex; align-items: center; justify-content: center; color: #fff; }
.agmark svg { width: 11px; height: 11px; }
.agplan { margin-left: auto; font: 600 10px/1 inherit; color: #8ea0ff; background: #232741; border-radius: 6px; padding: 3px 7px; }
.agreset { font: 500 10.5px/1 inherit; color: rgba(255,255,255,.45); }
.agpct { margin-left: auto; font: 700 12px/1 inherit; }
.agright { margin-left: auto; }
.agdot { width: 6px; height: 6px; border-radius: 50%; background: #30D158; }
.agbar { height: 5px; border-radius: 3px; background: rgba(255,255,255,.13); position: relative; overflow: hidden; }
.agbar b { display: block; height: 100%; border-radius: 3px; background: #8b7bf7; }
.agbar.green b, .agbar.sm.green b { background: #30D158; }
.agbar.sm { height: 4px; width: 64px; }
.agbar.green b { background: #30D158; }
.agsub { display: flex; align-items: center; gap: 8px; font: 500 11px/1.3 inherit; color: rgba(255,255,255,.7); }
.agsub .dim { color: rgba(255,255,255,.45); }
.aggrid2 { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
.aglabel { display: flex; align-items: center; gap: 6px; font: 600 10.5px/1 inherit; letter-spacing: .04em; color: rgba(255,255,255,.45); }
.aglabel svg { width: 11px; height: 11px; }
.agbig { font-size: 22px; font-weight: 700; }
.agbig small { font-size: 10px; font-weight: 500; color: rgba(255,255,255,.45); margin-left: 4px; }
.agtrend { display: flex; align-items: flex-end; gap: 4px; height: 52px; padding-top: 4px; }
.agtrend i { flex: 1; min-width: 4px; border-radius: 2px; background: #3f9d6f; opacity: .9; }
.agaxis { display: flex; justify-content: space-between; font: 500 9px/1 inherit; color: rgba(255,255,255,.35); }
.agmodel { display: flex; align-items: center; gap: 8px; font: 500 11px/1.5 inherit; }
.agmodel span:first-child { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.agheat { display: grid; grid-template-columns: repeat(13, 1fr); gap: 2.5px; }
.agheat i { aspect-ratio: 1; border-radius: 2.5px; background: #cfcfd4; }
.agactrow { display: flex; align-items: baseline; gap: 8px; }
.agactrow b { font-size: 20px; font-weight: 700; }

/* clipboard v2 */
.clipnew { flex: 1 1 auto; display: flex; gap: 10px; padding: 2px 4px; }
.clipcardnew { flex: 0 0 220px; height: 100%; background: #191919; border-radius: 16px; padding: 13px 13px; display: flex; flex-direction: column; justify-content: space-between; }
.clipcardnew b { font-size: 13px; line-height: 1.35; font-weight: 700; }
.clipcardnew span { font: 500 11px/1 inherit; color: rgba(255,255,255,.4); }
.clipside { margin-left: auto; display: flex; flex-direction: column; gap: 8px; justify-content: center; }
.clipcircle { width: 30px; height: 30px; border-radius: 50%; border: 0; background: rgba(255,255,255,.1); color: rgba(255,255,255,.75); display: inline-flex; align-items: center; justify-content: center; cursor: pointer; }
.clipcircle svg { width: 13px; height: 13px; }
.emptynew { margin: auto; display: flex; gap: 12px; align-items: center; color: rgba(255,255,255,.55); max-width: 460px; padding: 0 30px; }
.emptynew svg { width: 26px; height: 26px; flex: 0 0 auto; }
.emptynew b { display: block; color: #fff; font-size: 14px; font-weight: 700; margin-bottom: 2px; }
.emptynew span { font-size: 12px; line-height: 1.5; }

/* tray v2 */
.traynew { flex: 1 1 auto; display: flex; padding: 2px 4px; }
.dashtray { flex: 1; border: 1.5px dashed rgba(255,255,255,.22); border-radius: 14px; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 6px; color: rgba(255,255,255,.55); }
.dashtray svg { width: 24px; height: 24px; color: rgba(255,255,255,.5); }
.dashtray b { font-size: 13px; font-weight: 700; color: #fff; }
.dashtray span { font-size: 11.5px; }

/* stats v2 */
.statsnew { flex: 1 1 auto; display: grid; grid-template-columns: repeat(4, 1fr); gap: 8px; padding: 2px 4px; align-content: start; }
.statnew { background: #161616; border-radius: 13px; padding: 11px 12px; display: flex; flex-direction: column; gap: 5px; }
.statbig { font-size: 22px; font-weight: 700; }

/* keep awake v2 */
.kacnew { flex: 1 1 auto; display: flex; align-items: center; gap: 12px; padding: 0 10px; }
.katxt { display: flex; flex-direction: column; gap: 3px; }
.katxt b { font-size: 15px; font-weight: 700; }
.katxt span { font-size: 12px; color: rgba(255,255,255,.5); }
.kacnew .startnew { margin-left: auto; }

/* scratch v2 */
.scratchnew { flex: 1 1 auto; display: flex; flex-direction: column; gap: 8px; padding: 2px 4px; }
.scratchnew textarea { flex: 1; resize: none; border: 0; outline: none; background: #191919; border-radius: 14px; padding: 12px 14px; color: #fff; font: 500 13px/1.6 inherit; box-sizing: border-box; }
.scratchbar { display: flex; align-items: center; gap: 10px; padding: 0 4px; }
.scdot { width: 18px; height: 18px; border-radius: 50%; background: #3b82f6; }
.saved { font: 600 11px/1 inherit; color: #30D158; }
.fmt { border: 0; background: none; color: rgba(255,255,255,.75); font: 700 12px/1 inherit; cursor: pointer; padding: 2px 4px; }

/* reminders v2 */
.remsnew { flex: 1 1 auto; display: flex; flex-direction: column; gap: 7px; padding: 2px 4px; }
.remnew { display: flex; align-items: center; gap: 10px; background: #161616; border-radius: 12px; padding: 10px 12px; cursor: pointer; }
.remradio { width: 16px; height: 16px; border-radius: 50%; border: 1.5px solid #0A84FF; background: none; }
.remradio.is-done { background: #0A84FF; }
.remnew b { font-size: 13px; font-weight: 700; }
.remnew .sm { margin-left: auto; }

/* mirror v2 */
.mirrornew { flex: 1 1 auto; display: flex; gap: 14px; padding: 2px 4px; }
.mprevnew { flex: 0 0 190px; background: #101010; border-radius: 12px; overflow: hidden; }
.mprevnew video { width: 100%; height: 100%; object-fit: cover; }
.mbodnew { display: flex; flex-direction: column; align-items: flex-start; justify-content: center; gap: 10px; }
.mbodnew b { font-size: 14px; font-weight: 700; }

/* launcher v2 */
.lgridnew { flex: 1 1 auto; display: grid; grid-template-columns: repeat(5, 1fr); gap: 8px; align-content: start; overflow-y: auto; padding: 2px 2px; }
.ltilenew { position: relative; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 3px; height: 74px; border-radius: 15px; border: 0; background: rgba(255,255,255,.07); color: #fff; cursor: pointer; transition: background .15s ease-out, transform .2s cubic-bezier(.34,1.4,.44,1); }
.ltilenew:hover { background: rgba(255,255,255,.11); } .ltilenew:active { transform: scale(.94); opacity: .7; }
.lticon { display: inline-flex; width: 20px; height: 20px; margin-bottom: 1px; } .lticon svg { width: 100%; height: 100%; }
.ltilenew b { font: 700 12.5px/1.1 inherit; }
.ltilenew small { font: 500 9.5px/1 inherit; color: rgba(255,255,255,.38); letter-spacing: .03em; }
.ldot { position: absolute; top: 7px; right: 8px; width: 5px; height: 5px; border-radius: 50%; background: #30D158; }
.pagedots { position: absolute; right: 8px; top: 50%; transform: translateY(-50%); display: flex; flex-direction: column; gap: 5px; }
.pagedots i { width: 5px; height: 5px; border-radius: 50%; background: rgba(255,255,255,.25); }
.pagedots i.is-on { background: #fff; }


/* ================= 1:1 repair pass (match the app's geometry) ================= */
/* clip everything to the notch shape so nothing bleeds past the rounded bottom */
.slit__nook { border-radius: 0 0 var(--r, 12px) var(--r, 12px); overflow: hidden; }
.slit__body { overflow: hidden; }

/* Home: exact three-column proportions (200 + calendar + 170) */
.homenew { gap: 10px; }
.musiccard2 { gap: 3px; }
.hlyric { line-height: 1.1; }
.musiccard2 { flex: 0 0 200px; padding: 10px 12px; gap: 4px; }
.art78 { width: 48px; height: 48px; border-radius: 9px; }
.artline { gap: 10px; }
.mtxt b { font-size: 12px; }
.mtxt span { font-size: 10.5px; }
.hlyric { font-size: 10.5px; }
.hscrub { height: 4px; background: rgba(255,255,255,.32); }
.hctl { gap: 20px; padding-top: 0; }
.hctl svg { width: 13px; height: 13px; }
.hctl .hplay svg { width: 20px; height: 20px; }
.homesecs { gap: 10px; }
.hsec--timer { flex: 0 0 164px; gap: 8px; }
.hsec header { font-size: 14px; gap: 6px; }
.hsec header b { font-size: 14px; }
.hev b { font-size: 13px; line-height: 1.25; }
.hevsub { font-size: 11.5px; }
.hpills { gap: 6px; }
.hpill { padding: 6px 11px; font-size: 12px; }
.hpill--focus { font-size: 12px; padding: 6px 12px; }

/* Calendar: aligned 7-column grid, compact TODAY column */
.calnew { gap: 14px; padding: 0; }
.calleft { flex: 0 0 196px; }
.monname { font-size: 10.5px; letter-spacing: .09em; }
.calgridnew { gap: 0; }
.calgridnew small { font-size: 8.5px; line-height: 1.7; }
.calgridnew span { width: 18px; height: 18px; line-height: 18px; font-size: 10.5px; }
.calright { padding-left: 14px; gap: 6px; }
.evtxt b { font-size: 12.5px; }
.evtxt span { font-size: 11px; }

/* Launcher: two fixed rows, paged (10 + 3), clickable dots */
.lgridnew { grid-template-rows: repeat(2, 76px); gap: 8px; align-content: start; overflow: hidden; padding: 0; }
.ltilenew { height: 76px; }
.ltile b { font-size: 12.5px; }
.pagedots { right: 6px; }
.pdot { width: 5px; height: 5px; border-radius: 50%; border: 0; padding: 0; background: rgba(255,255,255,.25); cursor: pointer; }
.pdot.is-on { background: #fff; }

/* Agents: compact type + inline activity (9px heat cells + stats column) */
.agentsnew { padding: 6px 8px 2px; gap: 7px; }
.agcard { padding: 9px 11px; gap: 5px; }
.aghead b { font-size: 12.5px; }
.agplan { font-size: 9.5px; padding: 3px 6px; }
.agreset { font-size: 10px; }
.agpct { font-size: 11.5px; }
.agsub { font-size: 10.5px; }
.aglabel { font-size: 10px; }
.agbig { font-size: 20px; }
.agtrend { height: 46px; }
.agmodel { font-size: 10.5px; }
.agact { display: flex; gap: 12px; align-items: flex-start; }
.agheat { display: grid; grid-template-columns: repeat(13, 9px); grid-auto-rows: 9px; gap: 2.5px; flex: 0 0 auto; }
.agheat i { border-radius: 2px; }
.agactstats { display: flex; flex-direction: column; gap: 3px; flex: 1; min-width: 0; }
.agactbig { font-size: 15px; font-weight: 700; }

/* Clipboard/Files: stretch inside the body, never past the edge */
.clipnew { height: auto; align-items: stretch; }
.clipcardnew { height: auto; flex: 0 0 210px; }
.traynew { height: 100%; box-sizing: border-box; }

/* Timer: no focus ring, tighter row */
.slit .mode:focus, .slit .mode:focus-visible, .slit .startnew:focus, .slit .startnew:focus-visible, .slit .tghost:focus, .slit .tghost:focus-visible { outline: none; }
.tctrl { display: flex; align-items: center; gap: 7px; }
.tghost { appearance: none; border: 0; background: rgba(255,255,255,.08); color: rgba(255,255,255,.72); font: inherit; font-size: 12px; font-weight: 600; padding: 6px 12px; border-radius: 999px; cursor: pointer; }
.tghost:hover { background: rgba(255,255,255,.13); color: #fff; }
.trrow { gap: 14px; }
.bigread { font-size: 30px; }

@media (max-width: 700px) {
  .slit[data-open] { zoom: var(--nook-scale, 1); }
}
@media (max-width: 340px) {
  .slit:not([data-open]) { zoom: 0.915; }
}
@media (prefers-reduced-motion: reduce) {
  .slit, .slit__nook, .slit-ctx, .slit-settings, .slit-coach { transition: none; }
  .bars i, .ring, .mark { animation: none !important; }
}
`;

/* ------------------------------------------------ the settings window */
let settingsEl = null, coachEl = null, notifStack = null, settingsTab = "general";
function openSettings() { settingsEl.classList.add("is-on"); renderSettings(); }
function closeSettings() { settingsEl.classList.remove("is-on"); }
function showCoach() {
  if (document.documentElement.classList.contains("intro")) { setTimeout(showCoach, 1200); return; }
  coachEl.innerHTML = `
    <img alt="" src="data:image/svg+xml;utf8,${svgURI()}" />
    <div class="coach-text"><b>Arrowslit is running</b><span>This Mac is a live demo. Hover the notch, click it, right-click it, or press <kbd>⌃⌥R</kbd> for the timer.</span></div>
    <button class="coach-btn" data-coach="settings">Settings</button>
    <button class="coach-x" data-coach="close" aria-label="Dismiss">×</button>`;
  coachEl.classList.add("is-on");
  coachEl.addEventListener("click", (e) => {
    const b = e.target.closest("[data-coach]");
    if (!b) return;
    if (b.dataset.coach === "settings") { openSettings(); coachEl.classList.remove("is-on"); }
    else coachEl.classList.remove("is-on");
  });
  setTimeout(() => coachEl.classList.remove("is-on"), 16000);
}
function svgURI() {
  const s = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="%23FF9F0A" stroke-width="2.2" stroke-linecap="round"><circle cx="12" cy="12" r="9"/><path d="M12 3v6.2M20.8 9.2l-5.9 1.9M17.5 19.6l-3.6-5.1M6.5 19.6l3.6-5.1M3.2 9.2l5.9 1.9"/></svg>';
  return encodeURIComponent(s);
}
function toggleRow(key, label, sub, get, set) {
  const on = get();
  const row = h("div.srow");
  row.append(h("div.stext", h("b", label), sub ? h("small", sub) : null));
  const t = h("button.stoggle" + (on ? ".is-on" : ""), { role: "switch", "aria-checked": String(on), on: { click: () => { set(!get()); renderSettings(); forceApply(); } } }, h("i"));
  row.append(t);
  return row;
}
function segRow(label, options, current, onPick) {
  const row = h("div.srow");
  row.append(h("div.stext", h("b", label)));
  const seg = h("div.sseg");
  for (const [val, name] of options) {
    seg.append(h("button.sseg-btn" + (String(val) === String(current) ? ".is-on" : ""), { on: { click: () => { onPick(val); renderSettings(); forceApply(); } } }, name));
  }
  row.append(seg);
  return row;
}
function sliderRow(label, value, min, max, step, fmt, onInput) {
  const row = h("div.srow.slider");
  const val = h("small.sval", fmt(value));
  const input = h("input.strack", { type: "range", min, max, step, value });
  input.addEventListener("input", () => { onInput(Number(input.value)); val.textContent = fmt(Number(input.value)); forceApply(); });
  row.append(h("div.stext", h("b", label), val), input);
  return row;
}
function forceApply() { applyAppearance(); curKey = ""; apply(); }
function renderSettings() {
  settingsEl.innerHTML = "";
  const head = h("div.shead");
  const tabs = h("div.stabs");
  for (const [id, name] of [["general", "General"], ["appearance", "Appearance"], ["activities", "Activities"], ["notch", "Notch"], ["about", "About"]]) {
    tabs.append(h("button.stab" + (settingsTab === id ? ".is-on" : ""), { on: { click: () => { settingsTab = id; renderSettings(); } } }, name));
  }
  const close = h("button.sx", { on: { click: closeSettings } }, "×");
  head.append(tabs, close);
  const body = h("div.sbody");
  if (settingsTab === "general") {
    body.append(
      segRow("Open notch with", [["click", "Click"], ["hover", "Hover"]], settings.openWith, (v) => { settings.openWith = v; }),
      sliderRow("Hover delay", settings.hoverDelay, 100, 500, 10, (v) => (v / 1000).toFixed(2) + "s", (v) => { settings.hoverDelay = v; }),
      toggleRow("collapse", "Collapse when pointer leaves", "Move away and the nook tucks back in.", () => settings.collapse, (v) => { settings.collapse = v; }),
      toggleRow("idle", "Show when idle", "Keep a small pill on the notch when nothing is live.", () => settings.showWhenIdle, (v) => { settings.showWhenIdle = v; }),
    );
  } else if (settingsTab === "appearance") {
    body.append(
      segRow("Size", [[0.8, "Small"], [0.9, "Medium"], [1, "Large"]], settings.size, (v) => { settings.size = Number(v); }),
      sliderRow("Width", settings.width, 120, 420, 4, (v) => v + " pt", (v) => { settings.width = v; }),
      sliderRow("Thickness", settings.height, 24, 52, 1, (v) => v + " pt", (v) => { settings.height = v; }),
      segRow("Theme", [["black", "Black"], ["glass", "Glass"]], settings.theme, (v) => { settings.theme = v; }),
      sliderRow("Glass tint", settings.glassTint, 0, 1, 0.05, (v) => Math.round(v * 100) + "%", (v) => { settings.glassTint = v; }),
      toggleRow("pitch", "Pitch black", "No shadow or outline, so the shape fuses into the notch.", () => settings.pitchBlack, (v) => { settings.pitchBlack = v; }),
    );
  } else if (settingsTab === "activities") {
    const A = settings.alerts;
    body.append(
      h("div.sgroup", "Live feedback"),
      toggleRow("charging", "Charging", "Shows the level in the notch when you plug in.", () => A.charging, (v) => { A.charging = v; }),
      toggleRow("lowBattery", "Low battery", "At 20% and 10%.", () => A.lowBattery, (v) => { A.lowBattery = v; }),
      toggleRow("headphones", "Headphones", "AirPods and other accessories connecting.", () => A.headphones, (v) => { A.headphones = v; }),
      toggleRow("level", "Volume & brightness", "The icon-and-level HUD beside the camera.", () => A.level, (v) => { A.level = v; }),
      toggleRow("download", "Downloads", "Show a download's progress and the finished file.", () => A.download, (v) => { A.download = v; }),
      toggleRow("update", "Updates", "A heads-up when a new Arrowslit release is out.", () => A.update, (v) => { A.update = v; }),
      toggleRow("upcomingEvent", "Calendar", "A heads-up five minutes before your next meeting.", () => A.upcomingEvent, (v) => { A.upcomingEvent = v; }),
      toggleRow("agentRequest", "Agent requests", "Let Claude Code, Codex and the rest ask in the notch.", () => A.agentRequest, (v) => { A.agentRequest = v; }),
    );
  } else if (settingsTab === "about") {
    body.innerHTML = `
      <div class="aboutbox">
        <img alt="" src="data:image/svg+xml;utf8,${svgURI()}" />
        <b>Arrowslit 0.12.10</b>
        <span>A quiet control surface for your MacBook's notch.</span>
        <small>Free and open source · GPL-3.0 · macOS 14 or later</small>
        <div class="aboutbtns">
          <button class="start" data-about="download">Download for Mac</button>
          <button class="sseg-btn" data-about="github">GitHub</button>
        </div>
      </div>`;
    body.querySelector("[data-about=download]").addEventListener("click", () => window.open("https://github.com/j4yop/arrowslit/releases/latest", "_blank", "noopener"));
    body.querySelector("[data-about=github]").addEventListener("click", () => window.open("https://github.com/j4yop/arrowslit", "_blank", "noopener"));
  } else {
    body.append(
      segRow("Layout", [["standard", "Standard"], ["elongated", "Elongated"]], settings.elongated ? "elongated" : "standard", (v) => { settings.elongated = v === "elongated"; }),
      toggleRow("nowPlaying", "Now Playing", "Music from any app, with artwork and bars.", () => settings.activities.nowPlaying, (v) => { settings.activities.nowPlaying = v; }),
      toggleRow("call", "Calls", "Show the call and its duration beside the camera.", () => settings.activities.call, (v) => { settings.activities.call = v; }),
      toggleRow("timer", "Timer", "Countdown beside the camera, in orange.", () => settings.activities.timer, (v) => { settings.activities.timer = v; }),
      toggleRow("agents", "AI agents", "Breathing marks for whatever is working.", () => settings.activities.agents, (v) => { settings.activities.agents = v; }),
    );
  }
  settingsEl.append(head, body);
}

/* ------------------------------------------------------------------ boot */
let collapseT = 0, hoverTimer = 0;
function boot() {
  host = document.createElement("div");
  host.id = "arrowslit-slit";
  root = host.attachShadow({ mode: "open" });

  slit = h("div.slit");
  stripEl = h("div.slit__strip");
  bodyEl = h("div.slit__body");
  nook = h("div.slit__nook", { hidden: "true" }, stripEl, bodyEl);
  cardEl = h("div.slit__card", { hidden: "true" });
  const face = h("button.slit__face", {
    type: "button", "aria-expanded": "false", "aria-label": "Arrowslit",
    on: {
      pointerenter: () => {
        hovering = true; poke(); apply();
        if (settings.openWith === "hover" && !expanded) {
          clearTimeout(hoverTimer);
          hoverTimer = setTimeout(() => { if (!expanded && hovering) { expanded = true; expandedTab = "home"; apply(); } }, settings.hoverDelay);
        }
      },
      pointerleave: () => { hovering = false; clearTimeout(hoverTimer); apply(); },
      click: (e) => { e.stopPropagation(); poke(); expanded = !expanded; expandedTab = expanded ? "home" : expandedTab; apply(); },
      contextmenu: (e) => { e.preventDefault(); showCtx(); },
    },
  }, h("span.slit__ear.slit__ear--l"), h("span.slit__cam"), h("span.slit__ear.slit__ear--r"));
  earL = face.querySelector(".slit__ear--l");
  earR = face.querySelector(".slit__ear--r");
  slit.append(face, nook, cardEl);

  ctx = h("div.slit-ctx", { role: "menu" });
  toastEl = h("span.slit-toast");
  settingsEl = h("div.slit-settings");
  coachEl = h("div.slit-coach");
  notifStack = h("div.slit-notifstack");

  root.append(h("style", null, CSS), slit, ctx, toastEl, settingsEl, coachEl, notifStack);
  document.body.appendChild(host);

  nook.addEventListener("click", (e) => {
    poke();
    const act = e.target.closest("[data-act], [data-m], [data-min], [data-tc], [data-tile], [data-page], [data-ka], [data-cr]");
    if (!act) return;
    if (act.dataset.act === "expandplayer") { expandedTab = "nowplaying"; apply(); }
    else if (act.dataset.act === "settings") toast("Settings live in the Arrowslit app");
    else if (act.dataset.m === "play") { music.playing = !music.playing; if (!music.playing) music.pausedAt = Date.now(); apply(); renderNook(); }
    else if (act.dataset.m === "next") { music.i = (music.i + 1) % music.tracks.length; music.t = 0; apply(); renderNook(); }
    else if (act.dataset.m === "prev") { music.i = (music.i - 1 + music.tracks.length) % music.tracks.length; music.t = 0; apply(); renderNook(); }
    else if (act.dataset.tc === "pause") { timer.running = !timer.running; renderNook(); apply(); }
    else if (act.dataset.tc === "cancel") { timer.running = false; timer.left = 0; timer.total = 0; renderNook(); apply(); }
    else if (act.dataset.min) {
      const v = Number(act.dataset.min);
      if (timer.running && timer.total === v * 60) { timer.running = false; toast("Timer paused"); }
      else if (!timer.running && timer.left && timer.total === v * 60) timer.running = true;
      else { timer.total = timer.left = v * 60; timer.running = true; timer.justFinished = false; call.active = false; expanded = false; }
      renderNook(); apply();
    } else if (act.dataset.call === "mute") { call.muted = !call.muted; renderNook(); toast(call.muted ? "Microphone muted" : "Microphone on"); }
    else if (act.dataset.call === "end") { call.active = false; renderNook(); apply(); toast("Call ended"); }
    else if (act.dataset.tile) toast(`${act.dataset.tile} opens in the Arrowslit app`);
    else if (act.dataset.ka) { keepAwake.on = !keepAwake.on; renderNook(); toast("Keep awake " + (keepAwake.on ? "on" : "off")); }
    else if (act.dataset.cr === "pause") { timer.running = !timer.running; apply(); }
    else if (act.dataset.cr === "close") { timer.running = false; timer.left = 0; expanded = false; apply(); }
    else if (act.dataset.cr === "back") { expandedTab = "timer"; apply(); }
  });
  bodyEl.addEventListener("click", (e) => {
    const scrub = e.target.closest(".scrub");
    if (scrub) {
      const r = scrub.getBoundingClientRect();
      music.t = Math.max(0, Math.min(1, (e.clientX - r.left) / r.width)) * music.tracks[music.i].len;
      renderNook();
    }
  });
  nook.addEventListener("wheel", (e) => {
    if (expandedTab !== "grid") return;
    e.preventDefault();
    e.stopPropagation();
    const now = Date.now();
    if (now - (nook.__wheelAt || 0) < 350) return;
    nook.__wheelAt = now;
    if (e.deltaY > 0 && gridPage < 1) { gridPage = 1; renderGridBody(); }
    else if (e.deltaY < 0 && gridPage > 0) { gridPage = 0; renderGridBody(); }
  }, { passive: false });
  slit.addEventListener("wheel", (e) => {
    if (expanded) {
      if (e.deltaY < -18 && !e.target.closest(".agentsnew, .dlpage, .notifpage")) { expanded = false; apply(); }
      return;
    }
    if (e.deltaY > 18) { expanded = true; expandedTab = "home"; apply(); }
  }, { passive: true });
  document.addEventListener("pointerdown", (e) => {
    poke();
    const path = e.composedPath();
    if (!path.includes(slit)) { if (expanded) { expanded = false; apply(); } closeCtx(); }
  });
  document.addEventListener("keydown", (e) => { if (e.key === "Escape" && (expanded || ctx.classList.contains("is-on"))) { expanded = false; apply(); closeCtx(); } });
  slit.addEventListener("pointerenter", () => { hovering = true; clearTimeout(collapseT); apply(); });
  slit.addEventListener("pointerleave", () => {
    hovering = false;
    clearTimeout(hoverTimer);
    if (expanded && settings.collapse) collapseT = setTimeout(() => { if (!slit.matches(":hover")) { expanded = false; apply(); } }, 600);
  });
  slit.addEventListener("pointermove", () => {
    if (settings.openWith !== "hover" || expanded) return;
    clearTimeout(hoverTimer);
    hoverTimer = setTimeout(() => {
      if (!expanded && hovering) { expanded = true; expandedTab = "home"; apply(); }
    }, settings.hoverDelay);
  });
  document.addEventListener("keydown", (e) => {
    if (e.ctrlKey && e.altKey && (e.key === "r" || e.key === "R")) {
      e.preventDefault();
      timer.total = timer.left = 5 * 60; timer.running = true; timer.justFinished = false; call.active = false;
      expanded = true; expandedTab = "timer"; apply();
    }
  });

  // the page's menubar gets a notch gap so the slit sits inside it, centered
  const gap = h("div.mb-notch-gap");
  gap.style.width = "min(282px, calc(100vw - 62px))";
  const tryGap = () => {
    const mb = document.getElementById("arrowslit-menubar-host")?.shadowRoot?.querySelector(".menubar") || document.querySelector(".menubar");
    if (!mb) return false;
    if (!mb.querySelector(":scope > .mb-notch-gap")) {
      const l = mb.querySelector(".mb-left");
      (l && l.nextSibling) ? l.after(gap) : mb.append(gap);
    }
    return true;
  };
  if (!tryGap()) { const t = setInterval(() => tryGap() && clearInterval(t), 300); setTimeout(() => clearInterval(t), 8000); }

  // Arrowslit's menu bar accessory: the slit mark replaces the generic menu-bar glyph
  const installItem = () => {
    const mb = document.getElementById("arrowslit-menubar-host")?.shadowRoot;
    if (!mb) return false;
    const status = mb.querySelector(".arrowslit-status");
    if (!status) return false;
    if (mb.querySelector(".arrowslit-status[data-arrowslit]")) return true;
    const b = status.cloneNode(false);
    b.setAttribute("data-arrowslit", "1");
    b.classList.add("arrowslit-status");
    b.title = "Arrowslit";
    b.setAttribute("aria-label", "Arrowslit");
    b.innerHTML = `<span style="display:inline-flex;width:12px;height:14px">${SLIT_MARK}</span>`;
    b.addEventListener("click", (e) => {
      e.stopPropagation();
      if (slitQuit) { slitQuit = false; slit.hidden = false; toast("Arrowslit is running"); return; }
      const r = b.getBoundingClientRect();
      showMenuAt(r.left + r.width / 2 - 100, r.bottom + 4, [
        { label: "About Arrowslit", fn: () => { settingsTab = "about"; openSettings(); } },
        { label: "Settings…", fn: () => { settingsTab = "general"; openSettings(); } },
        { label: "Check for Updates…", fn: () => fire({ kind: "update" }) },
        { sep: true },
        { label: "Quit Arrowslit", fn: () => { slitQuit = true; slit.hidden = true; } },
      ]);
    });
    status.replaceWith(b);
    return true;
  };
  if (!installItem()) { const t = setInterval(() => installItem() && clearInterval(t), 400); setTimeout(() => clearInterval(t), 9000); }

  // the Apple menu's Arrowslit items open the app's own settings
  window.addEventListener("arrowslit:about", () => { settingsTab = "about"; openSettings(); });
  window.addEventListener("arrowslit:settings", () => { settingsTab = "general"; openSettings(); });

  // ambient notifications — the Mac writing to the notch now and then
  setInterval(() => {
    if (QUIET) return;
    if (document.hidden) return;
    if (Math.random() < 0.45) return;
    const samples = [
      { app: "Messages", title: "Mia Chen", body: "Landing at 6:40 — want to grab dinner?", icon: "bell" },
      { app: "Mail", title: "Northwind Travel", body: "Flight NW 214 · Gate B12 · Boarding 7:55 PM", icon: "bell" },
      { app: "Reminders", title: "Buy house", body: "Due today", icon: "bell" },
      { app: "Calendar", title: "Design review", body: "Starts in 5 minutes", icon: "cal" },
    ];
    notify(samples[Math.floor(Math.random() * samples.length)]);
  }, 26000);

  // the showcase: welcome → resting services → the tour + the alert cycle
  if (!QUIET) fire({ kind: "welcome" });
  setInterval(tick, 1000);
  setInterval(() => {
    if (!stopwatch.active) return;
    const now = swNow();
    if (expanded && expandedTab === "timer" && timer.mode === "stopwatch") {
      const el = bodyEl.querySelector(".bigread"); if (el) el.textContent = fmtStopwatch(now);
    }
    if (!expanded) apply();
  }, 100);
  if (!QUIET) setTimeout(() => scheduleTour(TOUR_GAP), 4500);
  if (!QUIET) setTimeout(scheduleLoop, 7000);
  if (!QUIET) setTimeout(showCoach, 2200);
}

const pageStyle = document.createElement("style");
pageStyle.textContent = `
  #arrowslit-slit { position: fixed; top: 0; left: 0; right: 0; height: 240px; z-index: 320; pointer-events: none; }
`;
document.head.appendChild(pageStyle);

addEventListener("resize", () => { if (expanded) apply(); });
if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", boot);
else boot();
