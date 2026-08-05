// Codex usage — Übersicht desktop widget.
// Reads aggregate token activity, current context, and quota windows from
// local ~/.codex session logs via scripts/codex-data.{sh,js}.

export const command =
  "$HOME/.local/share/ai-desktop-widgets/scripts/codex-data.sh";
export const refreshFrequency = 30 * 1000;

const POS_KEY = "codex-status-pos-v1";
const BASE_LEFT = 744;
const BASE_TOP = 36;
const GRID = 12;
const INK = "#ffffff";
const SECONDARY = "rgba(255,255,255,0.75)";
const MUTED = "rgba(255,255,255,0.45)";
const HAIRLINE = "rgba(255,255,255,0.18)";
const TRACK = "rgba(255,255,255,0.10)";
const COLORS = { sol: "#a86bff", terra: "#3987e5", luna: "#30b77a", other: "#c3c2b7" };

export const className = `
  top: ${BASE_TOP}px;
  left: ${BASE_LEFT}px;
  width: 340px;
  font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
  color: ${INK};
  background:
    linear-gradient(135deg, rgba(255,255,255,0.13) 0%, rgba(255,255,255,0.04) 60%, rgba(168,107,255,0.07) 100%),
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
    0 0 60px rgba(168,107,255,0.07);
  z-index: 1;
`;

export const initialState = { output: "" };
export const updateState = (event, prev) =>
  event.type === "UB/COMMAND_RAN"
    ? Object.assign({}, prev, { output: event.output })
    : prev;

const loadPos = () => {
  try {
    const p = JSON.parse(localStorage.getItem(POS_KEY));
    return p && isFinite(p.x) && isFinite(p.y) ? p : { x: 0, y: 0 };
  } catch (e) { return { x: 0, y: 0 }; }
};
const clamp = (left, top) => ({
  left: Math.min(Math.max(Math.round(left / GRID) * GRID, 0), Math.max(0, window.innerWidth - 80)),
  top: Math.min(Math.max(Math.round(top / GRID) * GRID, 0), Math.max(0, window.innerHeight - 40)),
});
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
  const startX = e.screenX, startY = e.screenY;
  const origLeft = parseFloat(el.style.left) || BASE_LEFT;
  const origTop = parseFloat(el.style.top) || BASE_TOP;
  el.style.cursor = "grabbing";
  const onMove = (ev) => {
    const c = clamp(origLeft + ev.screenX - startX, origTop + ev.screenY - startY);
    el.style.left = c.left + "px";
    el.style.top = c.top + "px";
  };
  const onUp = () => {
    window.removeEventListener("mousemove", onMove);
    window.removeEventListener("mouseup", onUp);
    el.style.cursor = "";
    localStorage.setItem(POS_KEY, JSON.stringify({
      x: (parseFloat(el.style.left) || BASE_LEFT) - BASE_LEFT,
      y: (parseFloat(el.style.top) || BASE_TOP) - BASE_TOP,
    }));
  };
  window.addEventListener("mousemove", onMove);
  window.addEventListener("mouseup", onUp);
};

const fmtTok = (n) => n >= 1e9 ? (n / 1e9).toFixed(1) + "B"
  : n >= 1e6 ? (n / 1e6).toFixed(1) + "M"
  : n >= 1e3 ? (n / 1e3).toFixed(1) + "K" : String(n || 0);
const fmtMoney = (n) => "$" + (Number(n) || 0).toFixed(2);
const hhmm = (value) => {
  const d = new Date(value);
  return String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0");
};
const resetLabel = (value) => {
  if (!value) return "reset unavailable";
  const d = new Date(value);
  const now = new Date();
  const sameDay = d.toDateString() === now.toDateString();
  return "resets " + (sameDay ? hhmm(value) : d.toLocaleDateString(undefined, { weekday: "short" }) + " " + hhmm(value));
};
export const render = ({ output }) => {
  let d = null;
  try { d = JSON.parse(output); } catch (e) {}
  if (!d) return <div style={{ fontSize: 12, color: MUTED }}>Codex — waiting for data…</div>;

  const rows = d.bins || [];
  const byBucket = new Map();
  rows.forEach((r) => {
    if (!byBucket.has(r.bucket)) byBucket.set(r.bucket, {});
    byBucket.get(r.bucket)[r.model] = (byBucket.get(r.bucket)[r.model] || 0) + r.tokens;
  });
  const now = Date.now();
  const start = Math.floor((now - 24 * 3600 * 1000) / 1800000) * 1800000;
  const bins = [];
  for (let t = start; t <= now; t += 1800000) {
    const perModel = byBucket.get(t) || {};
    bins.push({ t, perModel, total: Object.values(perModel).reduce((a, b) => a + b, 0) });
  }
  const maxTotal = Math.max(1, ...bins.map((b) => b.total));
  const models = ["sol", "terra", "luna", "other"].filter((m) => rows.some((r) => r.model === m));
  const current = d.current || {};
  const contextPct = current.contextWindow > 0 ? Math.min(100, current.tokens / current.contextWindow * 100) : 0;
  const monthLabel = new Date().toLocaleString(undefined, { month: "long" });
  const BAR_H = 58;

  return (
    <div ref={restorePos}>
      <div onMouseDown={startDrag} style={{ display: "flex", justifyContent: "space-between", alignItems: "center", cursor: "grab" }}>
        <div style={{ fontSize: 11, letterSpacing: "0.08em", color: MUTED }}>CODEX</div>
        <div style={{ fontSize: 11, color: MUTED }}>last 24h</div>
      </div>

      <div style={{ marginTop: 12 }}>
        <div style={{ fontSize: 10, color: MUTED, letterSpacing: "0.08em" }}>{monthLabel.toUpperCase()} USAGE</div>
        <div style={{ display: "flex", alignItems: "baseline", gap: 10, marginTop: 3 }}>
          <div style={{ fontSize: 26, fontWeight: 600 }}>{fmtMoney(d.monthCost)}</div>
          <div style={{ fontSize: 12, color: SECONDARY }}>{fmtTok(d.monthTokens)} tokens</div>
        </div>
      </div>

      <div style={{ position: "relative", marginTop: 14 }}>
        <div style={{ display: "flex", alignItems: "flex-end", gap: 2, height: BAR_H, borderBottom: `1px solid ${HAIRLINE}` }}>
          {bins.map((b) => {
            const h = b.total ? Math.max(2, Math.round(b.total / maxTotal * BAR_H)) : 0;
            return (
              <div key={b.t} title={`${hhmm(b.t)} — ${fmtTok(b.total)}`} style={{ flex: 1, height: BAR_H, display: "flex", flexDirection: "column", justifyContent: "flex-end", background: "rgba(255,255,255,0.035)", borderRadius: 2 }}>
                <div style={{ height: h, display: "flex", flexDirection: "column-reverse", overflow: "hidden", borderRadius: 2 }}>
                  {Object.entries(b.perModel).map(([model, tokens]) => (
                    <div key={model} style={{ height: Math.max(1, tokens / (b.total || 1) * h), background: COLORS[model] || COLORS.other }} />
                  ))}
                </div>
              </div>
            );
          })}
        </div>
        <div style={{ position: "relative", height: 13 }}>
          {bins.map((b, i) => {
            const dt = new Date(b.t);
            if (dt.getMinutes() || dt.getHours() % 6) return null;
            return <div key={b.t} style={{ position: "absolute", left: `${(i + 0.5) / bins.length * 100}%`, transform: "translateX(-50%)", fontSize: 9, color: MUTED }}>{String(dt.getHours()).padStart(2, "0")}</div>;
          })}
        </div>
      </div>

      <div style={{ display: "flex", flexWrap: "wrap", gap: "4px 12px", marginTop: 5 }}>
        {models.map((m) => <div key={m} style={{ display: "flex", alignItems: "center", gap: 5 }}>
          <div style={{ width: 7, height: 7, borderRadius: "50%", background: COLORS[m] }} />
          <div style={{ fontSize: 10, color: SECONDARY }}>{m[0].toUpperCase() + m.slice(1)}</div>
        </div>)}
        {!models.length && <div style={{ fontSize: 10, color: MUTED }}>no activity in the last 24h</div>}
      </div>

      <div style={{ marginTop: 12, paddingTop: 11, borderTop: `1px solid ${HAIRLINE}`, fontSize: 10, color: MUTED, lineHeight: 1.45 }}>
        {current.contextWindow > 0 && (
          <div style={{ marginBottom: 8 }}>
            <div style={{ display: "flex", justifyContent: "space-between", color: SECONDARY }}>
              <span>current context</span><span>{fmtTok(current.tokens)} / {fmtTok(current.contextWindow)}</span>
            </div>
            <div style={{ height: 3, borderRadius: 2, background: TRACK, marginTop: 4 }}>
              <div style={{ height: "100%", width: `${contextPct}%`, background: "#a86bff", borderRadius: 2 }} />
            </div>
          </div>
        )}
        <div>Today {fmtTok(d.todayTokens)} · est. {fmtMoney(d.todayCost)}</div>
        <div style={{ color: "rgba(255,255,255,0.38)" }}>
          API-rate estimate{d.monthUnpricedTokens ? ` · ${fmtTok(d.monthUnpricedTokens)} unpriced` : ""}
          {d.error ? ` · ${d.error}` : ""}
        </div>
      </div>
    </div>
  );
};
