#!/usr/bin/env node
/**
 * Fase 2 gate: v3app (login/signup pilot) only.
 *
 * 1. Webpack build of v3app.js (MODE 3 compat)
 * 2. Vitest specs under app/javascript/v3/
 *
 * Does NOT run the full test suite — that is Fase 3+.
 */
const { spawnSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const NODE_OPTIONS = '--max-old-space-size=2048 --openssl-legacy-provider';
const V3APP_ENTRY = './app/javascript/packs/v3app.js';
const V3_SPECS = 'app/javascript/v3';

function bin(name) {
  return path.join(ROOT, 'node_modules', '.bin', name);
}

function run(label, executable, args, { capture = false } = {}) {
  console.log(`\n▶ ${label}`);

  const result = spawnSync(executable, args, {
    cwd: ROOT,
    env: { ...process.env, NODE_OPTIONS, TZ: 'UTC' },
    stdio: capture ? 'pipe' : 'inherit',
    encoding: 'utf8',
  });

  if (result.status !== 0) {
    if (capture) {
      if (result.stdout) process.stdout.write(result.stdout);
      if (result.stderr) process.stderr.write(result.stderr);
    }
    console.error(`\n✗ ${label} failed (exit ${result.status ?? 1})`);
    process.exit(result.status || 1);
  }

  console.log(`✓ ${label}`);
  return result;
}

function stepBuildV3App() {
  const outDir = fs.mkdtempSync(path.join(os.tmpdir(), 'chatwoot-v3app-'));

  const result = run(
    `Webpack build: ${V3APP_ENTRY}`,
    bin('webpack'),
    [
      '--config',
      'config/webpack/development.js',
      '--entry',
      V3APP_ENTRY,
      '--output-path',
      outDir,
    ],
    { capture: true }
  );

  const output = `${result.stdout || ''}${result.stderr || ''}`;
  const compatWarnings = output.match(/\[Vue warn\].*deprecation/gi) || [];

  if (compatWarnings.length) {
    console.log(
      `\n⚠  ${compatWarnings.length} compat deprecation warning(s) in v3app build`
    );
    [...new Set(compatWarnings)].slice(0, 10).forEach(w => console.log(`   ${w}`));
    if (compatWarnings.length > 10) {
      console.log(`   … and ${compatWarnings.length - 10} more`);
    }
  }

  fs.rmSync(outDir, { recursive: true, force: true });
}

function stepV3Specs() {
  run(`Vitest: ${V3_SPECS}`, bin('vitest'), [
    'run',
    '--no-cache',
    '--no-coverage',
    '--reporter=verbose',
    V3_SPECS,
  ]);
}

console.log('═══════════════════════════════════════════');
console.log(' Fase 2 verification — v3app pilot gate');
console.log('═══════════════════════════════════════════');

stepBuildV3App();
stepV3Specs();

console.log('\n═══════════════════════════════════════════');
console.log(' ✅ Fase 2 passed: v3app build + v3 specs');
console.log('═══════════════════════════════════════════\n');
