function makeWindow(events, start, end, bucketMs, cost = null) {
  const bins = Array.from({ length: Math.ceil((end - start) / bucketMs) }, (_, i) => ({
    t: start + i * bucketMs,
    models: {},
  }));
  let tokens = 0;
  for (const event of events) {
    if (event.timestamp < start || event.timestamp >= end) continue;
    const bin = bins[Math.floor((event.timestamp - start) / bucketMs)];
    bin.models[event.model] = (bin.models[event.model] || 0) + event.tokens;
    tokens += event.tokens;
  }
  return { start, end, bucketMs, cost, tokens, bins };
}

function buildUsageWindows(events, now, starts, costs = {}) {
  const hour = 60 * 60 * 1000;
  return {
    today: makeWindow(events, starts.today, now, 30 * 60 * 1000, costs.today ?? null),
    sevenDay: makeWindow(events, starts.sevenDay, now, 4 * hour, costs.sevenDay ?? null),
    month: makeWindow(events, starts.month, now, 24 * hour, costs.month ?? null),
  };
}

function usageScanStart(starts) {
  return Math.min(starts.sevenDay, starts.month);
}

function claudeTotals(report) {
  const totals = { totalCost: 0, totalTokens: 0 };
  let found = false;
  for (const day of report.daily || []) {
    for (const agent of day.agents || []) {
      if (agent.agent !== 'claude') continue;
      found = true;
      totals.totalCost += agent.totalCost || 0;
      totals.totalTokens += agent.totalTokens || 0;
    }
  }
  return found ? totals : null;
}

function splitDailyTotals(report) {
  return { legacy: report.totals || null, window: claudeTotals(report) };
}

module.exports = { buildUsageWindows, claudeTotals, splitDailyTotals, usageScanStart };
