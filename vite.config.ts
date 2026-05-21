import path from 'path';
import { defineConfig } from 'vitest/config';
import Vue from '@vitejs/plugin-vue';

export default defineConfig({
  plugins: [
    Vue({
      template: {
        compilerOptions: {
          compatConfig: { MODE: 2 },
        },
      },
    }),
  ],
  test: {
    environment: 'jsdom',
    include: ['app/**/*.{test,spec}.?(c|m)[jt]s?(x)'],
    coverage: {
      reporter: ['lcov', 'text'],
      include: ['app/**/*.js', 'app/**/*.vue'],
      exclude: [
        'app/**/*.@(spec|stories|routes).js',
        '**/specs/**/*',
        '**/i18n/**/*',
      ],
    },
    globals: true,
    outputFile: 'coverage/sonar-report.xml',
    server: {
      deps: {
        inline: ['tinykeys', '@material/mwc-icon', '@vue/compat'],
      },
    },
    setupFiles: [
      'fake-indexeddb/auto',
      './app/javascript/shared/vitest.setup.js',
    ],
    mockReset: true,
    clearMocks: true,
  },
  resolve: {
    alias: {
      // Redirect all vue imports to @vue/compat in tests
      vue: path.resolve(
        './node_modules/@vue/compat/dist/vue.cjs.js'
      ),
      dashboard: path.resolve('./app/javascript/dashboard'),
      widget: path.resolve('./app/javascript/widget'),
      survey: path.resolve('./app/javascript/survey'),
      assets: path.resolve('./app/javascript/dashboard/assets'),
      components: path.resolve('./app/javascript/dashboard/components'),
      helpers: path.resolve('./app/javascript/shared/helpers'),
      v3: path.resolve('./app/javascript/v3'),
      shared: path.resolve('./app/javascript/shared'),
    },
  },
});
