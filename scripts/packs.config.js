/**
 * Webpack pack definitions for verify-pack / verify-fase3 gates.
 * specs: Vitest directories (empty = build-only gate).
 */
module.exports = {
  v3app: {
    entry: './app/javascript/packs/v3app.js',
    specs: ['app/javascript/v3'],
    mode: 3,
  },
  survey: {
    entry: './app/javascript/packs/survey.js',
    specs: [],
    mode: 2,
  },
  superadmin_pages: {
    entry: './app/javascript/packs/superadmin_pages.js',
    specs: [],
    mode: 2,
  },
  widget: {
    entry: './app/javascript/packs/widget.js',
    specs: [],
    mode: 2,
  },
  portal: {
    entry: './app/javascript/packs/portal.js',
    specs: [],
    mode: 2,
  },
  application: {
    entry: './app/javascript/packs/application.js',
    specs: [],
    mode: 2,
  },
};

/** Default order for verify:fase3 (smallest / least risky first). */
module.exports.fase3Order = [
  'v3app',
  'survey',
  'superadmin_pages',
  'widget',
  'portal',
  'application',
];

/** Packs safe to build in parallel (low RAM footprint). */
module.exports.parallelBuildGroup = ['survey', 'superadmin_pages'];
