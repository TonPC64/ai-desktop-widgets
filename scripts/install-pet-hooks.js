#!/usr/bin/env node
// Install the Claude Code hooks that feed the desktop widget's pet state
// (~/.cache/claude-touchbar/pet-state.json). Idempotent: replaces its own
// earlier entries, leaves every other hook untouched, and backs up
// ~/.claude/settings.json first. Takes effect in new Claude Code sessions.
'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');

const RUNTIME =
  process.env.CLAUDE_TOUCH_RUNTIME ||
  path.join(os.homedir(), '.local', 'share', 'ai-desktop-widgets');
const SETTINGS = path.join(os.homedir(), '.claude', 'settings.json');
const HOOK = path.join(RUNTIME, 'scripts', 'pet-hook.sh');
const MARK = 'ai-desktop-widgets/scripts/pet-hook.sh';
const uninstall = process.argv[2] === '--uninstall';

// Tool-matcher events get a matcher; lifecycle events must not.
const EVENTS = [
  ['SessionStart', false],
  ['UserPromptSubmit', false],
  ['PreToolUse', true],
  ['Notification', false],
  ['Stop', false],
  ['SessionEnd', false],
];

let settings = {};
try {
  settings = JSON.parse(fs.readFileSync(SETTINGS, 'utf8'));
  if (!uninstall) fs.copyFileSync(SETTINGS, SETTINGS + '.bak-pet-hooks');
} catch {
  if (uninstall) process.exit(0);
}

if (uninstall) {
  for (const event of Object.keys(settings.hooks || {})) {
    const hooks = settings.hooks[event];
    if (!Array.isArray(hooks)) continue;
    settings.hooks[event] = hooks.filter((entry) => !JSON.stringify(entry).includes(MARK));
    if (!settings.hooks[event].length) delete settings.hooks[event];
  }
  fs.writeFileSync(SETTINGS, JSON.stringify(settings, null, 2) + '\n');
  console.log('pet hooks removed from ' + SETTINGS);
  process.exit(0);
}

settings.hooks = settings.hooks || {};
for (const [event, withMatcher] of EVENTS) {
  const entries = (Array.isArray(settings.hooks[event]) ? settings.hooks[event] : [])
    .filter((e) => !JSON.stringify(e).includes(MARK));
  const entry = {
    hooks: [
      {
        type: 'command',
        command: `/bin/bash "${HOOK}" ${event}`,
        timeout: 5,
      },
    ],
  };
  if (withMatcher) entry.matcher = '*';
  entries.push(entry);
  settings.hooks[event] = entries;
}

fs.writeFileSync(SETTINGS, JSON.stringify(settings, null, 2) + '\n');
console.log('pet hooks installed in ' + SETTINGS);
