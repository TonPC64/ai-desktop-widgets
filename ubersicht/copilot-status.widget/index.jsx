// Copilot CLI usage — Übersicht desktop widget.
// 24-hour token activity (48 half-hour bars, stacked per model) and
// today/7-day totals, read straight from ~/.copilot/session-store.db by
// scripts/copilot-data.sh (SQLite, no network calls, no external CLI).
//
// Sibling of claude-status.widget: same visual language (bars, palette)
// but its own widget folder so re-installing this project
// (which only manages claude-status.widget) never touches this one.
//
// Moving, hiding, and restricting to one screen are handled natively by
// Übersicht (right-click its menu-bar icon → this widget's ▸ submenu).

export const command =
  "$HOME/.local/share/ai-desktop-widgets/scripts/copilot-data.sh";
export const refreshFrequency = 30 * 1000;

// Position lives in the DOM, not in widget state: Übersicht evaluates
// `className` exactly once when it creates the widget element and never
// re-applies it, so a state-driven className can't move anything. Dragging
// therefore writes inline top/left straight onto the .widget container.
const POS_KEY = "copilot-status-pos-v2";
const BASE_LEFT = 384;
const BASE_TOP = 36;
const GRID = 12;

const loadPos = () => {
  try {
    const p = JSON.parse(localStorage.getItem(POS_KEY));
    if (!p || !isFinite(p.x) || !isFinite(p.y)) return { x: 0, y: 0 };
    return p;
  } catch (e) {
    return { x: 0, y: 0 };
  }
};

// Keep at least a corner of the card on screen, and snap to a GRID-sized
// grid so cards line up with each other instead of landing a few px off.
const clamp = (left, top) => ({
  left: Math.min(
    Math.max(Math.round(left / GRID) * GRID, 0),
    Math.max(0, window.innerWidth - 80)
  ),
  top: Math.min(
    Math.max(Math.round(top / GRID) * GRID, 0),
    Math.max(0, window.innerHeight - 40)
  ),
});

export const initialState = { output: "" };

export const updateState = (event, prev) => {
  switch (event.type) {
    case "UB/COMMAND_RAN":
      return Object.assign({}, prev, { output: event.output });
    default:
      return prev;
  }
};

// Restore the saved position once, on the first render after mount.
const restorePos = (node) => {
  if (!node) return;
  const el = node.closest(".widget");
  if (!el || el.dataset.posRestored) return;
  el.dataset.posRestored = "1";
  const p = loadPos();
  const c = clamp(BASE_LEFT + p.x, BASE_TOP + p.y);
  el.style.left = c.left + "px";
  el.style.top = c.top + "px";
};

const startDrag = (e) => {
  const el = e.currentTarget.closest(".widget");
  if (!el) return;
  e.preventDefault();
  const startX = e.screenX;
  const startY = e.screenY;
  const origLeft = parseFloat(el.style.left) || BASE_LEFT;
  const origTop = parseFloat(el.style.top) || BASE_TOP;
  el.style.cursor = "grabbing";

  const onMove = (ev) => {
    const c = clamp(origLeft + (ev.screenX - startX), origTop + (ev.screenY - startY));
    el.style.left = c.left + "px";
    el.style.top = c.top + "px";
  };
  const onUp = () => {
    window.removeEventListener("mousemove", onMove);
    window.removeEventListener("mouseup", onUp);
    el.style.cursor = "";
    localStorage.setItem(
      POS_KEY,
      JSON.stringify({
        x: (parseFloat(el.style.left) || BASE_LEFT) - BASE_LEFT,
        y: (parseFloat(el.style.top) || BASE_TOP) - BASE_TOP,
      })
    );
  };
  window.addEventListener("mousemove", onMove);
  window.addEventListener("mouseup", onUp);
};

const INK = "#ffffff";
const INK_SECONDARY = "rgba(255,255,255,0.75)";
const INK_MUTED = "rgba(255,255,255,0.45)";
const HAIRLINE = "rgba(255,255,255,0.18)";

// Positioned side-by-side (not stacked) with the Claude Code card, so a
// taller/shorter Claude card (collapsed vs. expanded quota chart, pet
// visible or not) never causes vertical overlap between the two.
export const className = `
  top: ${BASE_TOP}px;
  left: ${BASE_LEFT}px;
  width: 340px;
  font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
  color: ${INK};
  background:
    linear-gradient(135deg, rgba(255,255,255,0.13) 0%, rgba(255,255,255,0.04) 60%, rgba(100,200,160,0.06) 100%),
    rgba(18, 18, 24, 0.55);
  border: 1px solid rgba(255,255,255,0.22);
  border-bottom-color: rgba(255,255,255,0.10);
  border-right-color: rgba(255,255,255,0.10);
  border-radius: 20px;
  padding: 16px 18px;
  -webkit-backdrop-filter: blur(48px) saturate(180%) brightness(1.08);
  backdrop-filter: blur(48px) saturate(180%) brightness(1.08);
  box-shadow:
    0 0 0 0.5px rgba(255,255,255,0.12) inset,
    0 1.5px 0 0 rgba(255,255,255,0.18) inset,
    0 8px 32px rgba(0,0,0,0.40),
    0 2px 8px rgba(0,0,0,0.25),
    0 0 60px rgba(60,200,140,0.05);
  z-index: 1;
`;

// Models vary a lot more here (any Copilot CLI model, not just Claude
// families), so hash each unique model name to a stable hue instead of a
// fixed lookup table.
const PALETTE = ["#3987e5", "#199e70", "#c98500", "#e66767", "#9b6bd6", "#4bb3a8"];
const hueFor = (model) => {
  let h = 0;
  for (let i = 0; i < model.length; i++) h = (h * 31 + model.charCodeAt(i)) >>> 0;
  return PALETTE[h % PALETTE.length];
};

const fmtTok = (n) =>
  n >= 1e9 ? (n / 1e9).toFixed(1) + "B"
  : n >= 1e6 ? (n / 1e6).toFixed(1) + "M"
  : n >= 1e3 ? (n / 1e3).toFixed(1) + "K"
  : String(n || 0);

// 1 AIU = $0.01 (126K AIU limit = $1,260 plan)
const AIU_RATE = 0.01;
const fmtAiu = (n) =>
  !n ? "0"
  : n >= 1e3 ? (n / 1e3).toFixed(1) + "K"
  : n >= 10 ? n.toFixed(0)
  : n.toFixed(1);
const fmtAiuCost = (n) => "$" + ((n || 0) * AIU_RATE).toFixed(0);

const hhmm = (t) => {
  const d = new Date(t);
  return (
    String(d.getHours()).padStart(2, "0") +
    ":" +
    String(d.getMinutes()).padStart(2, "0")
  );
};

export const render = ({ output }) => {
  let d = null;
  try { d = JSON.parse(output); } catch (e) {}
  if (!d) {
    return (
      <div style={{ fontSize: 12, color: INK_MUTED }}>
        Copilot CLI — waiting for data…
      </div>
    );
  }

  // Bucket-fill the last 24h into 48 half-hour slots, stacked per model.
  const rows = d.bins || [];
  const byBucket = new Map();
  for (const r of rows) {
    if (!byBucket.has(r.bucket)) byBucket.set(r.bucket, {});
    byBucket.get(r.bucket)[r.model] = (byBucket.get(r.bucket)[r.model] || 0) + r.tok;
  }
  const now = Date.now();
  const start = Math.floor((now - 24 * 3600 * 1000) / 1800000) * 1800000;
  const bins = [];
  for (let t = start; t <= now; t += 1800000) {
    const perModel = byBucket.get(Math.floor(t / 1000)) || {};
    const total = Object.values(perModel).reduce((a, b) => a + b, 0);
    bins.push({ t, perModel, total });
  }
  const maxTotal = Math.max(1, ...bins.map((b) => b.total));
  const models = Array.from(new Set(rows.map((r) => r.model)));

  const today = (d.todayArr && d.todayArr[0]) || { requests: 0, tokens: 0, aiu: 0 };
  const month = (d.monthArr && d.monthArr[0]) || { requests: 0, tokens: 0, aiu: 0 };
  const limitAiu = Number(d.limitAiu) || 0;
  const usagePct = limitAiu > 0 ? (month.aiu / limitAiu) * 100 : 0;
  const usagePctLabel = limitAiu > 0 ? `${Math.round(usagePct)}%` : "--";
  const monthLabel = new Date().toLocaleString(undefined, { month: "long" });

  const BAR_H = 44;

  return (
    <div ref={restorePos}>
      <div
        onMouseDown={startDrag}
        style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          cursor: "grab",
        }}
      >
        <div style={{ fontSize: 11, letterSpacing: "0.08em", color: INK_MUTED }}>
          COPILOT CLI
        </div>
        <div style={{ fontSize: 11, color: INK_MUTED }}>last 24h</div>
      </div>

      {/* hero: month usage percentage */}
      <div style={{ display: "flex", alignItems: "baseline", gap: 8, marginTop: 6 }}>
        <div style={{ fontSize: 26, fontWeight: 600 }}>{usagePctLabel}</div>
        <div style={{ fontSize: 12, color: INK_SECONDARY }}>
          {monthLabel} usage · {fmtAiu(month.aiu)} / {fmtAiu(limitAiu)} AIU ({fmtAiuCost(month.aiu)} / {fmtAiuCost(limitAiu)})
        </div>
      </div>

      {/* usage progress bar */}
      {limitAiu > 0 && (
        <div style={{ marginTop: 8, height: 4, borderRadius: 2, background: "rgba(255,255,255,0.12)" }}>
          <div style={{
            height: "100%",
            width: `${Math.min(100, usagePct)}%`,
            borderRadius: 2,
            background: usagePct >= 90 ? "#e66767" : usagePct >= 70 ? "#c98500" : "#3987e5",
          }} />
        </div>
      )}

      {/* 24h stacked bar graph */}
      <div style={{ position: "relative", marginTop: 12 }}>
        <div
          style={{
            display: "flex",
            alignItems: "flex-end",
            gap: 2,
            height: BAR_H,
            borderBottom: `1px solid ${HAIRLINE}`,
          }}
        >
          {bins.map((b, i) => {
            const h = Math.max(1, Math.round((b.total / maxTotal) * BAR_H));
            const segs = Object.entries(b.perModel);
            return (
              <div
                key={b.t}
                style={{
                  flex: 1,
                  height: BAR_H,
                  display: "flex",
                  flexDirection: "column",
                  justifyContent: "flex-end",
                }}
                title={`${hhmm(b.t)} — ${fmtTok(b.total)}`}
              >
                <div
                  style={{
                    height: h,
                    display: "flex",
                    flexDirection: "column-reverse",
                    borderRadius: 1,
                    overflow: "hidden",
                  }}
                >
                  {segs.map(([model, tok]) => (
                    <div
                      key={model}
                      style={{ height: Math.max(1, (tok / (b.total || 1)) * h), background: hueFor(model) }}
                    />
                  ))}
                </div>
              </div>
            );
          })}
        </div>
        {/* local-time markers at 00/06/12/18 */}
        <div style={{ position: "relative", height: 12 }}>
          {bins.map((b, i) => {
            const dt = new Date(b.t);
            if (dt.getMinutes() !== 0 || dt.getHours() % 6 !== 0) return null;
            return (
              <div
                key={b.t}
                style={{
                  position: "absolute",
                  left: `${((i + 0.5) / bins.length) * 100}%`,
                  transform: "translateX(-50%)",
                  fontSize: 9,
                  color: INK_MUTED,
                }}
              >
                {String(dt.getHours()).padStart(2, "0")}
              </div>
            );
          })}
        </div>
      </div>

      {/* model legend */}
      <div style={{ display: "flex", flexWrap: "wrap", gap: "4px 12px", marginTop: 8 }}>
        {models.map((m) => (
          <div key={m} style={{ display: "flex", alignItems: "center", gap: 5 }}>
            <div style={{ width: 8, height: 8, borderRadius: 2, background: hueFor(m) }} />
            <div style={{ fontSize: 10, color: INK_SECONDARY }}>{m}</div>
          </div>
        ))}
        {models.length === 0 && (
          <div style={{ fontSize: 10, color: INK_MUTED }}>no activity in the last 24h</div>
        )}
      </div>

      {/* footer: line 1 = today AIU, line 2 = month usage */}
      <div style={{ marginTop: 10, paddingTop: 10, borderTop: `1px solid ${HAIRLINE}`, fontSize: 11, color: INK_SECONDARY }}>
        <div>
          Today: {fmtAiu(today.aiu)} AIU · {fmtTok(today.tokens)} tokens · {today.requests || 0} req
        </div>
        <div style={{ marginTop: 2 }}>
          {monthLabel}: {fmtAiu(month.aiu)} AIU ({fmtAiuCost(month.aiu)}) / {fmtAiu(limitAiu)} AIU ({fmtAiuCost(limitAiu)})
          {limitAiu > 0 && (
            <span style={{ color: INK_MUTED }}>
              {" "}
              ({Math.round(usagePct)}%)
            </span>
          )}
        </div>
      </div>
    </div>
  );
};
