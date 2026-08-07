// Antigravity CLI usage — Übersicht desktop widget.
// Shows 24h prompt activity bars, per-group quota % with progress bar, and session stats.
// Data comes from ~/.gemini/antigravity-cli local files + agy /quota (5-min cache).

export const command =
  "$HOME/.local/share/ai-desktop-widgets/scripts/agy-data.sh";

export const refreshFrequency = 5 * 1000;

const POS_KEY   = "agy-status-pos-v1";
const BASE_LEFT = 24;
const BASE_TOP  = 420;
const GRID      = 12;

const INK      = "#ffffff";
const MUTED    = "rgba(255,255,255,0.45)";
const HAIRLINE = "rgba(255,255,255,0.18)";
const AGY_BAR  = "linear-gradient(180deg, #4f9eff 0%, #a78bfa 60%, #34d399 100%)";
const AGY_GLOW = "rgba(99,102,241,0.08)";

export const className = `
  top: ${BASE_TOP}px;
  left: ${BASE_LEFT}px;
  width: 340px;
  font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
  color: ${INK};
  background:
    linear-gradient(135deg, rgba(255,255,255,0.13) 0%, rgba(255,255,255,0.04) 60%, rgba(99,102,241,0.08) 100%),
    rgba(14, 14, 22, 0.55);
  border: 1px solid rgba(255,255,255,0.22);
  border-bottom-color: rgba(255,255,255,0.10);
  border-right-color:  rgba(255,255,255,0.10);
  border-radius: 20px;
  padding: 16px 18px;
  -webkit-backdrop-filter: blur(48px) saturate(180%) brightness(1.08);
  backdrop-filter: blur(48px) saturate(180%) brightness(1.08);
  box-shadow:
    0 0 0 0.5px rgba(255,255,255,0.12) inset,
    0 1.5px 0 0 rgba(255,255,255,0.18) inset,
    0 8px 32px rgba(0,0,0,0.45),
    0 2px 8px rgba(0,0,0,0.28),
    0 0 60px ${AGY_GLOW};
  z-index: 1;
`;

const loadPos = () => {
  try {
    const p = JSON.parse(localStorage.getItem(POS_KEY));
    return p && isFinite(p.x) && isFinite(p.y) ? p : { x: 0, y: 0 };
  } catch { return { x: 0, y: 0 }; }
};
const clamp = (left, top) => ({
  left: Math.min(Math.max(Math.round(left / GRID) * GRID, 0), Math.max(0, window.innerWidth - 80)),
  top:  Math.min(Math.max(Math.round(top  / GRID) * GRID, 0), Math.max(0, window.innerHeight - 40)),
});
const restorePos = (node) => {
  if (!node) return;
  const el = node.closest(".widget");
  if (!el || el.dataset.posRestored) return;
  el.dataset.posRestored = "1";
  const p = loadPos();
  const c = clamp(BASE_LEFT + p.x, BASE_TOP + p.y);
  el.style.left = c.left + "px";
  el.style.top  = c.top  + "px";
};
const startDrag = (e) => {
  const el = e.currentTarget.closest(".widget");
  if (!el) return;
  e.preventDefault();
  const startX = e.screenX, startY = e.screenY;
  const origLeft = parseFloat(el.style.left) || BASE_LEFT;
  const origTop  = parseFloat(el.style.top)  || BASE_TOP;
  el.style.cursor = "grabbing";
  const onMove = (ev) => {
    const c = clamp(origLeft + ev.screenX - startX, origTop + ev.screenY - startY);
    el.style.left = c.left + "px";
    el.style.top  = c.top  + "px";
  };
  const onUp = () => {
    window.removeEventListener("mousemove", onMove);
    window.removeEventListener("mouseup",   onUp);
    el.style.cursor = "";
    localStorage.setItem(POS_KEY, JSON.stringify({
      x: (parseFloat(el.style.left) || BASE_LEFT) - BASE_LEFT,
      y: (parseFloat(el.style.top)  || BASE_TOP)  - BASE_TOP,
    }));
  };
  window.addEventListener("mousemove", onMove);
  window.addEventListener("mouseup",   onUp);
};

export const initialState = { output: "" };
export const updateState = (event, prev) =>
  event.type === "UB/COMMAND_RAN"
    ? Object.assign({}, prev, { output: event.output })
    : prev;

const hhmm = (ts) => {
  const d = new Date(ts);
  return String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0");
};
const timeAgo = (ts) => {
  const diff = Date.now() - ts;
  if (diff < 60000)    return "just now";
  if (diff < 3600000)  return Math.floor(diff / 60000) + "m ago";
  if (diff < 86400000) return Math.floor(diff / 3600000) + "h ago";
  return Math.floor(diff / 86400000) + "d ago";
};
const timeUntil = (ts) => {
  const diff = ts - Date.now();
  if (diff <= 0)       return "now";
  if (diff < 3600000)  return Math.ceil(diff / 60000) + "m";
  if (diff < 86400000) return Math.ceil(diff / 3600000) + "h";
  const d = Math.floor(diff / 86400000);
  const h = Math.ceil((diff % 86400000) / 3600000);
  return h > 0 ? `${d}d ${h}h` : `${d}d`;
};
const shortModel = (m) => {
  if (!m) return "unknown";
  return m
    .replace(/^Claude\s+/i, "")
    .replace(/\s*\(Thinking\)/i, " ✦")
    .replace(/\s*\(Preview\)/i, " ⌁");
};

const AgyrLogo = () => (
  <svg width="28" height="28" viewBox="0 0 28 28" aria-label="Antigravity">
    <defs>
      <linearGradient id="agygr" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0%"   stopColor="#4f9eff" />
        <stop offset="50%"  stopColor="#a78bfa" />
        <stop offset="100%" stopColor="#34d399" />
      </linearGradient>
    </defs>
    <polygon points="14,3 26,25 2,25" fill="url(#agygr)" opacity="0.95" />
    <polygon points="14,10 20,22 8,22" fill="rgba(0,0,0,0.35)" />
  </svg>
);

// pct: number 0-100 or null (unknown)
const QuotaRow = ({ label, pct, resetTs }) => {
  const known    = pct !== null && pct !== undefined;
  const ok       = !known || pct > 0;
  const barColor = pct >= 50 ? "#34d399" : pct >= 20 ? "#fbbf24" : "#f87171";
  const textColor = ok ? (pct >= 50 ? "#6ee7b7" : pct >= 20 ? "#fde68a" : "#fca5a5") : "#fca5a5";

  return (
    <div style={{
      padding: "5px 8px",
      borderRadius: 7,
      background: ok ? "rgba(255,255,255,0.05)" : "rgba(239,68,68,0.12)",
      border: `1px solid ${ok ? HAIRLINE : "rgba(239,68,68,0.30)"}`,
    }}>
      {/* label row */}
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", marginBottom: 4 }}>
        <div style={{ fontSize: 10, color: textColor, fontWeight: 600 }}>
          {!ok && "⚠ "}{label}
        </div>
        <div style={{ fontSize: 10, color: textColor, fontWeight: 700 }}>
          {known ? `${pct}%` : "—"}
          {!ok && resetTs > 0 && (
            <span style={{ fontWeight: 400, fontSize: 9, marginLeft: 5 }}>
              resets {timeUntil(resetTs)} · {hhmm(resetTs)}
            </span>
          )}
        </div>
      </div>
      {/* progress bar */}
      <div style={{
        height: 4,
        borderRadius: 2,
        background: "rgba(255,255,255,0.10)",
        overflow: "hidden",
      }}>
        <div style={{
          height: "100%",
          width: `${known ? pct : 0}%`,
          background: known ? barColor : "transparent",
          borderRadius: 2,
          transition: "width 0.4s ease",
        }} />
      </div>
    </div>
  );
};

export const render = ({ output }) => {
  let d = null;
  try { d = JSON.parse(output); } catch {}
  if (!d) return (
    <div style={{ fontSize: 12, color: MUTED }}>
      Antigravity — waiting for data…
    </div>
  );

  const bins     = d.bins || [];
  const maxCount = Math.max(1, ...bins.map(b => b.count));
  const BAR_H    = 48;

  return (
    <div ref={restorePos}>

      {/* ── header / drag handle ── */}
      <div
        onMouseDown={startDrag}
        style={{ display: "flex", justifyContent: "space-between", alignItems: "center", cursor: "grab" }}
      >
        <div style={{ fontSize: 11, letterSpacing: "0.08em", color: MUTED }}>
          ANTIGRAVITY CLI
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
          <div style={{ fontSize: 11, color: MUTED }}>last 24h</div>
          <AgyrLogo />
        </div>
      </div>

      {/* ── hero: model ── */}
      <div style={{ fontSize: 22, fontWeight: 700, letterSpacing: "-0.02em", marginTop: 8 }}>
        {shortModel(d.model)}
      </div>

      {/* ── per-group quota rows ── */}
      <div style={{ display: "flex", flexDirection: "column", gap: 5, marginTop: 8 }}>
        <QuotaRow label="Gemini"        pct={d.geminiPct}    resetTs={d.geminiResetTs}    />
        <QuotaRow label="Claude & GPT"  pct={d.claudeGptPct} resetTs={d.claudeGptResetTs} />
      </div>

      {/* ── stat pills row ── */}
      <div style={{ display: "flex", gap: 10, marginTop: 8, flexWrap: "wrap" }}>
        {[
          { label: "24h prompts", value: d.prompts24h },
          { label: "7d prompts",  value: d.prompts7d  },
          { label: "sessions",    value: d.totalConvs  },
          { label: "steps",       value: d.totalSteps  },
        ].map(({ label, value }) => (
          <div key={label} style={{
            background: "rgba(255,255,255,0.07)",
            border: "1px solid rgba(255,255,255,0.12)",
            borderRadius: 8,
            padding: "3px 9px",
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            minWidth: 52,
          }}>
            <div style={{ fontSize: 15, fontWeight: 600, lineHeight: 1.2 }}>{value}</div>
            <div style={{ fontSize: 8, color: MUTED, marginTop: 1, whiteSpace: "nowrap" }}>{label}</div>
          </div>
        ))}
      </div>

      {/* ── 24h activity bar chart ── */}
      <div style={{ position: "relative", marginTop: 14 }}>
        <div style={{
          display: "flex",
          alignItems: "flex-end",
          gap: 2,
          height: BAR_H,
          borderBottom: `1px solid ${HAIRLINE}`,
        }}>
          {bins.map((b) => {
            const h = b.count ? Math.max(3, Math.round((b.count / maxCount) * BAR_H)) : 0;
            return (
              <div
                key={b.t}
                title={`${hhmm(b.t)} — ${b.count} prompt${b.count !== 1 ? "s" : ""}`}
                style={{ flex: 1, height: BAR_H, display: "flex", flexDirection: "column", justifyContent: "flex-end" }}
              >
                {h > 0 && (
                  <div style={{
                    height: h,
                    background: AGY_BAR,
                    borderRadius: "2px 2px 0 0",
                    opacity: 0.85 + (b.count / maxCount) * 0.15,
                  }} />
                )}
              </div>
            );
          })}
        </div>
        <div style={{ position: "relative", height: 13 }}>
          {bins.map((b, i) => {
            const dt = new Date(b.t);
            if (dt.getMinutes() !== 0 || dt.getHours() % 6 !== 0) return null;
            return (
              <div key={b.t} style={{
                position: "absolute",
                left: `${((i + 0.5) / bins.length) * 100}%`,
                transform: "translateX(-50%)",
                fontSize: 9,
                color: MUTED,
              }}>
                {String(dt.getHours()).padStart(2, "0")}
              </div>
            );
          })}
        </div>
      </div>

      {/* ── footer: last activity ── */}
      <div style={{
        marginTop: 8,
        paddingTop: 8,
        borderTop: `1px solid ${HAIRLINE}`,
        display: "flex",
        justifyContent: "flex-end",
        fontSize: 9,
        color: MUTED,
      }}>
        <span>{d.lastTs ? timeAgo(d.lastTs) : "no activity"}</span>
      </div>

    </div>
  );
};
