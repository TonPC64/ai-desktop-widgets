#!/usr/bin/env node
"use strict";

// This mirrors the bounded local-session-log approach used by
// binlabongbom/codex-status-touch-bar. Only turn_context and token_count
// records are inspected. The result is cached because Übersicht polls often.
const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawn } = require("child_process");

const NOW = Date.now();
const DAY = 24 * 60 * 60 * 1000;
const SLOT = 30 * 60 * 1000;
const MAX_TAIL = 8 * 1024 * 1024;
const CACHE_TTL = 30 * 1000;
// Standard-processing API rates per 1M tokens, verified from OpenAI's official
// pricing page on 2026-08-04. Codex subscription charges may differ.
const PRICE_PER_MILLION = {
  sol: { input: 2.5, cachedInput: 0.25, cacheWrite: 3.125, output: 15 },
  terra: { input: 1, cachedInput: 0.1, cacheWrite: 1.25, output: 6 },
  luna: { input: 0.1, cachedInput: 0.01, cacheWrite: 0.125, output: 0.6 },
};
const codexRoot = path.join(os.homedir(), ".codex");
const cacheDir = path.join(os.homedir(), ".cache", "codex-touchbar");
const cacheFile = path.join(cacheDir, "data.json");

const empty = (error) => ({
  bins: [], quota: [], current: null, todayTokens: 0, monthTokens: 0,
  todayCost: 0, monthCost: 0, todayUnpricedTokens: 0, monthUnpricedTokens: 0,
  usageWindows: {},
  observedAt: new Date(NOW).toISOString(), error: error || null,
});

try {
  const stat = fs.statSync(cacheFile);
  if (NOW - stat.mtimeMs < CACHE_TTL) {
    process.stdout.write(fs.readFileSync(cacheFile, "utf8"));
    process.exit(0);
  }
} catch (_) {}

function collectFiles(root, out) {
  let entries;
  try { entries = fs.readdirSync(root, { withFileTypes: true }); } catch (_) { return; }
  for (const entry of entries) {
    const file = path.join(root, entry.name);
    // Never follow symlinks out of ~/.codex.
    let stat;
    try { stat = fs.lstatSync(file); } catch (_) { continue; }
    if (stat.isSymbolicLink()) continue;
    if (stat.isDirectory()) collectFiles(file, out);
    else if (stat.isFile() && file.endsWith(".jsonl")) out.push({ file, mtime: stat.mtimeMs });
  }
}

function readTail(file) {
  const fd = fs.openSync(file, "r");
  try {
    const size = fs.fstatSync(fd).size;
    const start = Math.max(0, size - MAX_TAIL);
    const buf = Buffer.alloc(size - start);
    fs.readSync(fd, buf, 0, buf.length, start);
    let text = buf.toString("utf8");
    if (start > 0) {
      const newline = text.indexOf("\n");
      text = newline < 0 ? "" : text.slice(newline + 1);
    }
    return text;
  } finally { fs.closeSync(fd); }
}

function modelGroup(model) {
  const value = String(model || "other").toLowerCase();
  if (value.includes("sol")) return "sol";
  if (value.includes("terra")) return "terra";
  if (value.includes("luna")) return "luna";
  return "other";
}

function estimatedCost(model, usage) {
  const rates = PRICE_PER_MILLION[modelGroup(model)];
  if (!rates) return null;
  const input = Number(usage.input_tokens) || 0;
  const cachedInput = Number(usage.cached_input_tokens) || 0;
  const cacheWrite = Number(usage.cache_write_input_tokens) || 0;
  const output = Number(usage.output_tokens) || 0;
  const uncachedInput = Math.max(0, input - cachedInput - cacheWrite);
  return (
    uncachedInput * rates.input
    + cachedInput * rates.cachedInput
    + cacheWrite * rates.cacheWrite
    + output * rates.output
  ) / 1e6;
}

function labelFor(minutes) {
  if (minutes === 300) return "5H";
  if (minutes === 10080) return "7D";
  if (minutes > 0 && minutes % 1440 === 0) return `${minutes / 1440}D`;
  if (minutes > 0 && minutes % 60 === 0) return `${minutes / 60}H`;
  return "LIMIT";
}

function rateWindow(raw) {
  const usedValue = raw && (raw.used_percent !== undefined ? raw.used_percent : raw.usedPercent);
  if (!raw || !Number.isFinite(Number(usedValue))) return null;
  const minutes = Number(raw.window_minutes !== undefined ? raw.window_minutes
    : raw.windowDurationMins !== undefined ? raw.windowDurationMins : raw.windowMinutes) || 0;
  const used = Math.min(100, Math.max(0, Number(usedValue)));
  return {
    label: labelFor(minutes),
    usedPercent: used,
    remainingPercent: Math.round(100 - used),
    windowMinutes: minutes,
    resetsAt: Number(raw.resets_at !== undefined ? raw.resets_at : raw.resetsAt) > 0
      ? Number(raw.resets_at !== undefined ? raw.resets_at : raw.resetsAt) * 1000 : null,
  };
}

// The app server is the reference project's preferred quota source. Session
// logs remain the fallback because some Codex versions omit rate limits there.
function appServerQuota() {
  const override = process.env.CODEX_WIDGET_CODEX_PATH;
  const candidates = [
    override && path.isAbsolute(override) ? override : null,
    path.join(os.homedir(), ".local", "bin", "codex"),
    "/opt/homebrew/bin/codex",
    "/usr/local/bin/codex",
  ].filter(Boolean);
  const executable = candidates.find((file) => {
    try { fs.accessSync(file, fs.constants.X_OK); return fs.statSync(file).isFile(); } catch (_) { return false; }
  });
  if (!executable) return Promise.resolve(null);

  return new Promise((resolve) => {
    let settled = false;
    let buffer = "";
    let child;
    const finish = (value) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      if (child && !child.killed) child.kill();
      resolve(value);
    };
    const timer = setTimeout(() => finish(null), 5000);
    try {
      child = spawn(executable, ["app-server", "--stdio"], { stdio: ["pipe", "pipe", "ignore"] });
    } catch (_) { finish(null); return; }
    child.on("error", () => finish(null));
    child.on("exit", () => finish(null));
    child.stdout.setEncoding("utf8");
    child.stdout.on("data", (chunk) => {
      buffer += chunk;
      let newline;
      while ((newline = buffer.indexOf("\n")) >= 0) {
        const line = buffer.slice(0, newline);
        buffer = buffer.slice(newline + 1);
        let response;
        try { response = JSON.parse(line); } catch (_) { continue; }
        if (response.id === 1 && response.result) {
          child.stdin.write('{"method":"initialized","params":{}}\n');
          child.stdin.write('{"id":2,"method":"account/rateLimits/read","params":{}}\n');
        } else if (response.id === 2) {
          const limits = response.result && response.result.rateLimits;
          if (!limits) { finish(null); return; }
          const windows = [rateWindow(limits.primary), rateWindow(limits.secondary)].filter(Boolean);
          const budget = limits.individualLimit;
          if (!windows.length && budget && Number.isFinite(Number(budget.remainingPercent))) {
            const remaining = Math.min(100, Math.max(0, Number(budget.remainingPercent)));
            windows.push({
              label: "BUDGET", usedPercent: 100 - remaining, remainingPercent: Math.round(remaining),
              windowMinutes: 0,
              resetsAt: Number(budget.resetsAt) > 0 ? Number(budget.resetsAt) * 1000 : null,
              limit: budget.limit || null, used: budget.used || null,
            });
          }
          finish(windows);
          return;
        }
      }
    });
    child.stdin.write('{"id":1,"method":"initialize","params":{"clientInfo":{"name":"codex-ubersicht-widget","version":"1.0.0"}}}\n');
  });
}

function build() {
  const files = [];
  collectFiles(path.join(codexRoot, "sessions"), files);
  collectFiles(path.join(codexRoot, "archived_sessions"), files);
  files.sort((a, b) => b.mtime - a.mtime);

  const monthStart = new Date();
  monthStart.setDate(1);
  monthStart.setHours(0, 0, 0, 0);
  // Current-month files build month-to-date usage; a few older candidates are
  // retained so a temporarily absent quota record can still be shown.
  const candidates = files.filter((item, i) => item.mtime >= monthStart.getTime() || i < 20);
  const binMap = new Map();
  const usageEvents = [];
  let latestCurrent = null;
  let latestQuota = null;
  let todayTokens = 0;
  let monthTokens = 0;
  let todayCost = 0;
  let monthCost = 0;
  let todayUnpricedTokens = 0;
  let monthUnpricedTokens = 0;
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  for (const candidate of candidates) {
    let lines;
    try { lines = readTail(candidate.file).split("\n"); } catch (_) { continue; }
    let model = "other";
    let effort = null;
    for (const line of lines) {
      if (!line) continue;
      let event;
      try { event = JSON.parse(line); } catch (_) { continue; }
      const timestamp = Date.parse(event.timestamp);
      if (!Number.isFinite(timestamp)) continue;
      if (event.type === "turn_context") {
        model = event.payload && event.payload.model || model;
        effort = event.payload && (event.payload.effort
          || event.payload.collaboration_mode && event.payload.collaboration_mode.settings
          && event.payload.collaboration_mode.settings.reasoning_effort) || effort;
        continue;
      }
      const payload = event.payload || {};
      if (event.type !== "event_msg" || payload.type !== "token_count") continue;
      const info = payload.info || {};
      const lastUsage = info.last_token_usage || {};
      const last = Number(lastUsage.total_tokens) || 0;
      const cost = estimatedCost(model, lastUsage);
      const contextWindow = Number(info.model_context_window) || 0;

      if (last > 0 && timestamp >= monthStart.getTime() && timestamp <= NOW + 60000) {
        usageEvents.push({ timestamp, model: modelGroup(model), tokens: last, cost });
      }

      if (last > 0 && timestamp >= NOW - DAY && timestamp <= NOW + 60000) {
        const bucket = Math.floor(timestamp / SLOT) * SLOT;
        const group = modelGroup(model);
        const key = `${bucket}:${group}`;
        binMap.set(key, (binMap.get(key) || 0) + last);
      }
      if (last > 0 && timestamp >= today.getTime() && timestamp <= NOW + 60000) {
        todayTokens += last;
        if (cost === null) todayUnpricedTokens += last;
        else todayCost += cost;
      }
      if (last > 0 && timestamp >= monthStart.getTime() && timestamp <= NOW + 60000) {
        monthTokens += last;
        if (cost === null) monthUnpricedTokens += last;
        else monthCost += cost;
      }
      if (!latestCurrent || timestamp > latestCurrent.timestamp) {
        latestCurrent = { timestamp, model, effort, tokens: last, contextWindow };
      }

      const limits = payload.rate_limits || {};
      const quota = [rateWindow(limits.primary), rateWindow(limits.secondary)].filter(Boolean);
      if (quota.length && (!latestQuota || timestamp > latestQuota.timestamp)) {
        latestQuota = { timestamp, quota };
      }
    }
  }

  const bins = Array.from(binMap, ([key, tokens]) => {
    const split = key.lastIndexOf(":");
    return { bucket: Number(key.slice(0, split)), model: key.slice(split + 1), tokens };
  }).sort((a, b) => a.bucket - b.bucket || a.model.localeCompare(b.model));

  function usageWindow(start, bucketMs) {
    const binMap = new Map();
    let tokens = 0;
    let cost = 0;
    for (const event of usageEvents) {
      if (event.timestamp < start) continue;
      const bucket = start + Math.floor((event.timestamp - start) / bucketMs) * bucketMs;
      const key = `${bucket}:${event.model}`;
      binMap.set(key, (binMap.get(key) || 0) + event.tokens);
      tokens += event.tokens;
      if (event.cost !== null) cost += event.cost;
    }
    const windowBins = Array.from({ length: Math.ceil((NOW - start) / bucketMs) }, (_, i) => ({
      t: start + i * bucketMs, models: {},
    }));
    for (const [key, value] of binMap) {
      const split = key.lastIndexOf(":");
      const bucket = Number(key.slice(0, split));
      const bin = windowBins[Math.floor((bucket - start) / bucketMs)];
      bin.models[key.slice(split + 1)] = value;
    }
    return { start, bucketMs, cost, tokens, bins: windowBins };
  }
  const usageWindows = {
    today: usageWindow(NOW - DAY, SLOT),
    sevenDay: usageWindow(NOW - 7 * DAY, 4 * 60 * 60 * 1000),
    month: usageWindow(monthStart.getTime(), DAY),
  };

  return {
    bins,
    usageWindows,
    quota: latestQuota ? latestQuota.quota : [],
    quotaObservedAt: latestQuota ? new Date(latestQuota.timestamp).toISOString() : null,
    current: latestCurrent && NOW - latestCurrent.timestamp <= 15 * 60 * 1000 ? {
      model: latestCurrent.model,
      effort: latestCurrent.effort,
      tokens: latestCurrent.tokens,
      contextWindow: latestCurrent.contextWindow,
      updatedAt: new Date(latestCurrent.timestamp).toISOString(),
    } : null,
    todayTokens,
    monthTokens,
    todayCost,
    monthCost,
    todayUnpricedTokens,
    monthUnpricedTokens,
    pricingBasis: "OpenAI API standard processing rates (2026-08-04)",
    observedAt: new Date(NOW).toISOString(),
    error: files.length ? null : "no Codex sessions found",
  };
}

async function main() {
  let result;
  try { result = build(); } catch (error) { result = empty(error.message); }
  try {
    const quota = await appServerQuota();
    if (quota && quota.length) {
      result.quota = quota;
      result.quotaObservedAt = new Date().toISOString();
    }
  } catch (_) {}
  const json = JSON.stringify(result);
  try {
    fs.mkdirSync(cacheDir, { recursive: true });
    const temp = `${cacheFile}.${process.pid}.tmp`;
    fs.writeFileSync(temp, json);
    fs.renameSync(temp, cacheFile);
  } catch (_) {}
  process.stdout.write(json);
}

main();
