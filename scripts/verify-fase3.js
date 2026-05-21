#!/usr/bin/env node
/**
 * Fase 3 gate: all Vue packs (MODE 2 production target + v3app MODE 3 pilot).
 * Fail-fast sequential verification.
 */
const { spawnSync } = require('child_process');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const { fase3Order, parallelBuildGroup } = require('./packs.config');

function runNodeScript(script, scriptArgs = []) {
  const result = spawnSync(process.execPath, [script, ...scriptArgs], {
    cwd: ROOT,
    stdio: 'inherit',
    env: process.env,
  });
  if (result.status !== 0) {
    process.exit(result.status || 1);
  }
}

console.log('═══════════════════════════════════════════');
console.log(' Fase 3 verification — all Vue packs');
console.log(' MODE 2: application, widget, survey, portal');
console.log(' MODE 3: v3app (pilot)');
console.log('═══════════════════════════════════════════');

// v3app: build + specs (full gate)
runNodeScript(path.join(__dirname, 'verify-pack.js'), ['v3app']);

// Parallel build for small packs
const parallelPacks = parallelBuildGroup.filter(p => fase3Order.includes(p));
if (parallelPacks.length) {
  runNodeScript(path.join(__dirname, 'verify-pack.js'), [
    '--parallel',
    ...parallelPacks,
  ]);
}

// Remaining packs sequentially (build-only except v3app already done)
const remaining = fase3Order.filter(
  p => p !== 'v3app' && !parallelPacks.includes(p)
);

remaining.forEach(pack => {
  runNodeScript(path.join(__dirname, 'verify-pack.js'), [pack, '--build-only']);
});

console.log('\n═══════════════════════════════════════════');
console.log(' ✅ Fase 3 passed: all Vue pack builds (+ v3 specs)');
console.log(' Next: run smoke checklist (scripts/smoke-checklist.md)');
console.log('═══════════════════════════════════════════\n');
