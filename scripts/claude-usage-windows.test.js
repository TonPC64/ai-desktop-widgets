const assert = require('node:assert/strict');
const test = require('node:test');
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {
  buildUsageWindows,
  claudeTotals,
  estimateRollingCost,
  splitDailyTotals,
  usageScanStart,
} = require('./claude-usage-windows');

const hour = 60 * 60 * 1000;
const day = 24 * hour;

test('sums only Claude totals from mixed-agent daily reports', () => {
  const report = {
    daily: [
      {
        date: '2026-08-10',
        agents: [
          { agent: 'claude', totalCost: 1.25, totalTokens: 100 },
          { agent: 'codex', totalCost: 9, totalTokens: 900 },
        ],
      },
      {
        date: '2026-08-11',
        agents: [{ agent: 'claude', totalCost: 2.75, totalTokens: 200 }],
      },
    ],
  };

  assert.deepEqual(claudeTotals(report), { totalCost: 4, totalTokens: 300 });
});

test('returns null for Codex-only daily reports', () => {
  const report = {
    daily: [{
      date: '2026-08-11',
      agents: [{ agent: 'codex', totalCost: 9, totalTokens: 900 }],
    }],
  };

  assert.equal(claudeTotals(report), null);
});

test('separates all-agent legacy totals from Claude window totals', () => {
  const report = {
    totals: { totalCost: 13, totalTokens: 1200, totalInputTokens: 1000 },
    daily: [{
      date: '2026-08-11',
      agents: [
        { agent: 'claude', totalCost: 4, totalTokens: 300 },
        { agent: 'codex', totalCost: 9, totalTokens: 900 },
      ],
    }],
  };

  assert.deepEqual(splitDailyTotals(report), {
    legacy: { totalCost: 13, totalTokens: 1200, totalInputTokens: 1000 },
    window: { totalCost: 4, totalTokens: 300 },
  });
});

test('estimates a rolling cost from the matching portions of daily totals', () => {
  const start = Date.UTC(2026, 7, 10, 12);
  const end = Date.UTC(2026, 7, 11, 12);
  const events = [
    { timestamp: start, tokens: 100 },
    { timestamp: end - hour, tokens: 200 },
  ];
  const daily = {
    '2026-08-10': { cost: 10, tokens: 400 },
    '2026-08-11': { cost: 6, tokens: 300 },
  };

  assert.equal(estimateRollingCost(events, start, end, daily), 6.5);
});

test('builds Today, 7D, and month with matching calendar costs', () => {
  const now = Date.UTC(2026, 7, 10, 12);
  const starts = {
    today: Date.UTC(2026, 7, 10),
    sevenDay: Date.UTC(2026, 7, 4),
    month: Date.UTC(2026, 7, 1),
  };
  const windows = buildUsageWindows([
    { timestamp: now - hour, model: 'today', tokens: 10 },
    { timestamp: starts.today - hour, model: 'week', tokens: 20 },
    { timestamp: starts.sevenDay - hour, model: 'month', tokens: 30 },
  ], now, starts, { today: 1.25, sevenDay: 12.5, month: 25 });

  assert.equal(windows.today.tokens, 10);
  assert.equal(windows.sevenDay.tokens, 30);
  assert.equal(windows.month.tokens, 60);
  assert.deepEqual(
    [windows.today.cost, windows.sevenDay.cost, windows.month.cost],
    [1.25, 12.5, 25]
  );
  assert.equal(windows.fiveHour, undefined);
  assert.equal(usageScanStart(starts), starts.month);
});

test('derives aggregate tokens from the exact bin start and end domains', () => {
  const now = Date.UTC(2026, 7, 10, 12);
  const starts = {
    today: Date.UTC(2026, 7, 10),
    sevenDay: Date.UTC(2026, 7, 4),
    month: Date.UTC(2026, 7, 1),
  };
  const windows = buildUsageWindows([
    { timestamp: now - hour, model: 'recent', tokens: 100 },
    { timestamp: starts.today, model: 'today-start', tokens: 10 },
    { timestamp: starts.today - 1, model: 'before-today', tokens: 20 },
    { timestamp: starts.sevenDay, model: 'seven-start', tokens: 30 },
    { timestamp: starts.sevenDay - 1, model: 'before-seven', tokens: 40 },
    { timestamp: starts.month, model: 'month-start', tokens: 50 },
    { timestamp: starts.month - 1, model: 'before-month', tokens: 60 },
    { timestamp: now, model: 'at-end', tokens: 70 },
  ], now, starts);
  const binTokens = (window) => window.bins
    .flatMap((bin) => Object.values(bin.models))
    .reduce((sum, tokens) => sum + tokens, 0);

  assert.deepEqual(
    [windows.today.tokens, windows.sevenDay.tokens, windows.month.tokens],
    [110, 160, 250]
  );
  for (const window of Object.values(windows)) {
    assert.equal(window.tokens, binTokens(window));
    assert.equal(window.cost, null);
  }
});

test('includes an early-month prior-month event only in the seven-day window', () => {
  const now = Date.UTC(2026, 8, 3, 12);
  const starts = {
    today: Date.UTC(2026, 8, 3),
    sevenDay: Date.UTC(2026, 7, 28),
    month: Date.UTC(2026, 8, 1),
  };
  const priorMonth = now - 4 * day;
  const windows = buildUsageWindows([
    { timestamp: priorMonth, model: 'prior-month', tokens: 100 },
    { timestamp: now - day, model: 'current-month', tokens: 200 },
  ], now, starts);
  const models = (window) => window.bins.flatMap((bin) => Object.keys(bin.models));

  assert.equal(usageScanStart(starts), starts.sevenDay);
  assert.equal(models(windows.sevenDay).includes('prior-month'), true);
  assert.equal(models(windows.month).includes('prior-month'), false);
  assert.equal(models(windows.month).includes('current-month'), true);
});

test('native graph cache ignores and preserves the Übersicht graph cache', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'claude-graph-bundle-'));
  const scripts = path.join(root, 'Resources', 'scripts');
  const home = path.join(root, 'home');
  const cache = path.join(home, '.cache', 'claude-touchbar');
  fs.mkdirSync(path.join(home, '.claude', 'projects', 'fixture'), { recursive: true });
  fs.mkdirSync(cache, { recursive: true });
  fs.mkdirSync(scripts, { recursive: true });
  fs.copyFileSync(path.join(__dirname, 'claude-status.sh'), path.join(scripts, 'claude-status.sh'));
  fs.copyFileSync(path.join(__dirname, 'status.js'), path.join(scripts, 'status.js'));
  fs.copyFileSync(path.join(__dirname, 'claude-usage-windows.js'), path.join(scripts, 'claude-usage-windows.js'));
  const legacy = '{"legacy":true}\n';
  const legacyCache = path.join(cache, 'graph.txt');
  fs.writeFileSync(legacyCache, legacy);
  fs.writeFileSync(
    path.join(home, '.claude', 'projects', 'fixture', 'session.jsonl'),
    JSON.stringify({
      timestamp: new Date(Date.now() - hour).toISOString(),
      requestId: 'request',
      message: { id: 'message', model: 'claude-sonnet-4-6', usage: { input_tokens: 42 } },
    }) + '\n'
  );

  try {
    const payload = JSON.parse(execFileSync('/bin/bash', [
      path.join(scripts, 'claude-status.sh'),
      'graph',
      'native-graph',
    ], {
      encoding: 'utf8',
      env: { ...process.env, HOME: home },
    }));
    assert.ok(payload.usageWindows.today);
    assert.ok(payload.usageWindows.sevenDay);
    assert.ok(payload.usageWindows.month);
    assert.equal(fs.readFileSync(legacyCache, 'utf8'), legacy);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test('native graph uses the same rolling 24-hour range for totals and bins', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'claude-rolling-window-'));
  const scripts = path.join(root, 'Resources', 'scripts');
  const home = path.join(root, 'home');
  fs.mkdirSync(path.join(home, '.claude', 'projects', 'fixture'), { recursive: true });
  fs.mkdirSync(scripts, { recursive: true });
  for (const file of ['claude-status.sh', 'status.js', 'claude-usage-windows.js']) {
    fs.copyFileSync(path.join(__dirname, file), path.join(scripts, file));
  }
  const now = Date.now();
  const events = [
    { age: 23 * hour, id: 'inside', tokens: 100 },
    { age: 25 * hour, id: 'outside', tokens: 200 },
  ].map(({ age, id, tokens }) => JSON.stringify({
    timestamp: new Date(now - age).toISOString(),
    requestId: id,
    message: { id, model: 'claude-sonnet-4-6', usage: { input_tokens: tokens } },
  })).join('\n');
  fs.writeFileSync(path.join(home, '.claude', 'projects', 'fixture', 'session.jsonl'), `${events}\n`);

  try {
    const payload = JSON.parse(execFileSync('/bin/bash', [
      path.join(scripts, 'claude-status.sh'), 'graph', 'native-graph',
    ], { encoding: 'utf8', env: { ...process.env, HOME: home } }));
    assert.equal(payload.usageWindows.today.tokens, 100);
    assert.equal(payload.usageWindows.today.bins.length, 48);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});
