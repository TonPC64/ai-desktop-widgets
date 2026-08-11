const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

test('rebuilds a fresh cache that predates rolling usage windows', () => {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-cache-schema-'));
  const cache = path.join(home, '.cache', 'codex-touchbar');
  const sessions = path.join(home, '.codex', 'sessions');
  fs.mkdirSync(cache, { recursive: true });
  fs.mkdirSync(sessions, { recursive: true });
  fs.writeFileSync(path.join(cache, 'data.json'), JSON.stringify({ bins: [], monthCost: 9, monthTokens: 100 }));
  fs.writeFileSync(path.join(sessions, 'session.jsonl'), JSON.stringify({
    timestamp: new Date().toISOString(),
    type: 'event_msg',
    payload: { type: 'token_count', info: { last_token_usage: { input_tokens: 100, total_tokens: 100 } } },
  }) + '\n');

  try {
    const payload = JSON.parse(execFileSync(process.execPath, [path.join(__dirname, 'codex-data.js')], {
      encoding: 'utf8', env: { ...process.env, HOME: home },
    }));
    assert.ok(payload.usageWindows.month);
    assert.equal(payload.usageWindows.month.tokens, 100);
  } finally {
    fs.rmSync(home, { recursive: true, force: true });
  }
});
