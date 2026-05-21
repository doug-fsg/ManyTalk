#!/usr/bin/env node
/**
 * Per-pack verification gate: webpack build (+ optional scoped Vitest).
 *
 * Usage:
 *   node scripts/verify-pack.js v3app
 *   node scripts/verify-pack.js --build-only --all
 *   node scripts/verify-pack.js --parallel survey superadmin_pages
 */
const { spawnSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const NODE_OPTIONS = '--max-old-space-size=2048 --openssl-legacy-provider';
const packs = require('./packs.config');
const fase3Order = packs.fase3Order;

function bin(name) {
  return path.join(ROOT, 'node_modules', '.bin', name);
}

function run(label, executable, args, { capture = false, env = {} } = {}) {
  console.log(`\n▶ ${label}`);

  const result = spawnSync(executable, args, {
    cwd: ROOT,
    env: { ...process.env, NODE_OPTIONS, TZ: 'UTC', ...env },
    stdio: capture ? 'pipe' : 'inherit',
    encoding: 'utf8',
  });

  if (result.status !== 0) {
    if (capture) {
      if (result.stdout) process.stdout.write(result.stdout);
      if (result.stderr) process.stderr.write(result.stderr);
    }
    console.error(`\n✗ ${label} failed (exit ${result.status ?? 1})`);
    return { ok: false, result };
  }

  console.log(`✓ ${label}`);
  return { ok: true, result };
}

function buildPack(packName) {
  const config = packs[packName];
  if (!config) {
    console.error(`Unknown pack: ${packName}`);
    process.exit(1);
  }

  const outDir = fs.mkdtempSync(
    path.join(os.tmpdir(), `chatwoot-${packName}-`)
  );

  const { ok, result } = run(
    `Webpack build: ${config.entry}`,
    bin('webpack'),
    [
      '--config',
      'config/webpack/development.js',
      '--entry',
      config.entry,
      '--output-path',
      outDir,
    ],
    { capture: true }
  );

  if (!ok) {
    process.exit(result?.status || 1);
  }

  const output = `${result.stdout || ''}${result.stderr || ''}`;
  const compatWarnings =
    output.match(/\[Vue warn\][^\n]*(?:deprecation|compat)/gi) || [];

  if (compatWarnings.length) {
    const label =
      config.mode === 3 ? 'compat deprecation' : 'compat notice (MODE 2)';
    console.log(`\n⚠  ${compatWarnings.length} ${label} warning(s) in ${packName}`);
    [...new Set(compatWarnings)].slice(0, 5).forEach(w => console.log(`   ${w}`));
    if (compatWarnings.length > 5) {
      console.log(`   … and ${compatWarnings.length - 5} more`);
    }
  }

  fs.rmSync(outDir, { recursive: true, force: true });
}

function testPack(packName) {
  const config = packs[packName];
  if (!config.specs || config.specs.length === 0) {
    return;
  }

  const { ok } = run(
    `Vitest: ${config.specs.join(', ')}`,
    bin('vitest'),
    [
      'run',
      '--no-cache',
      '--no-coverage',
      '--reporter=verbose',
      ...config.specs,
    ]
  );

  if (!ok) {
    process.exit(1);
  }
}

function verifyPack(packName, { buildOnly = false } = {}) {
  console.log(`\n── Pack: ${packName} (MODE ${packs[packName].mode}) ──`);
  buildPack(packName);
  if (!buildOnly) {
    testPack(packName);
  }
}

function parseArgs(argv) {
  const args = { buildOnly: false, parallel: false, packs: [] };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--build-only') {
      args.buildOnly = true;
    } else if (arg === '--all') {
      args.packs = [...fase3Order];
    } else if (arg === '--parallel') {
      args.parallel = true;
    } else if (!arg.startsWith('-')) {
      args.packs.push(arg);
    }
  }

  return args;
}

function main() {
  const args = parseArgs(process.argv.slice(2));

  if (args.packs.length === 0) {
    console.error(
      'Usage: node scripts/verify-pack.js <pack> [--build-only] | --all [--build-only] | --parallel <pack> <pack>'
    );
    process.exit(1);
  }

  if (args.parallel && args.packs.length > 1) {
    const children = args.packs.map(packName => {
      const child = spawnSync(
        process.execPath,
        [path.join(__dirname, 'verify-pack.js'), packName, '--build-only'],
        { cwd: ROOT, env: { ...process.env, NODE_OPTIONS, TZ: 'UTC' } }
      );
      return { packName, status: child.status };
    });

    const failed = children.filter(c => c.status !== 0);
    if (failed.length) {
      failed.forEach(c => console.error(`✗ ${c.packName} failed`));
      process.exit(1);
    }
    children.forEach(c => console.log(`✓ ${c.packName} build ok`));
    return;
  }

  args.packs.forEach(packName => {
    verifyPack(packName, { buildOnly: args.buildOnly });
  });
}

main();
