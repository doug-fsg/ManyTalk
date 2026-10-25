import {
  sanitizeDiagnosticContext,
  isOperationDiagnosticsEnabled,
  withOperationDiagnostics,
} from '../sentryDiagnostics';

describe('sentryDiagnostics', () => {
  const originalErrorLoggingConfig = window.errorLoggingConfig;
  const originalChatwootConfig = window.chatwootConfig;

  beforeEach(() => {
    window.errorLoggingConfig = 'https://example@sentry.io/1';
    window.chatwootConfig = {};
    vi.clearAllMocks();
  });

  afterEach(() => {
    window.errorLoggingConfig = originalErrorLoggingConfig;
    window.chatwootConfig = originalChatwootConfig;
  });

  describe('sanitizeDiagnosticContext', () => {
    it('keeps safe primitive fields and drops sensitive keys', () => {
      expect(
        sanitizeDiagnosticContext({
          conversation_id: 12,
          before: 99,
          message_content: 'secret',
          token: 'x',
        })
      ).toEqual({
        conversation_id: 12,
        before: 99,
      });
    });
  });

  describe('isOperationDiagnosticsEnabled', () => {
    it('is disabled when Sentry DSN is missing', () => {
      window.errorLoggingConfig = '';
      expect(isOperationDiagnosticsEnabled()).toBe(false);
    });

    it('can be disabled explicitly via chatwootConfig', () => {
      window.chatwootConfig = { enableSentryOperationDiagnostics: false };
      expect(isOperationDiagnosticsEnabled()).toBe(false);
    });
  });

  describe('withOperationDiagnostics', () => {
    it('returns the async result when diagnostics are disabled', async () => {
      window.chatwootConfig = { enableSentryOperationDiagnostics: false };
      const result = await withOperationDiagnostics(
        'test.op',
        { id: 1 },
        async () => 'ok'
      );
      expect(result).toBe('ok');
    });

    it('re-throws errors without changing caller control flow', async () => {
      await expect(
        withOperationDiagnostics(
          'test.op',
          { id: 1 },
          async () => {
            throw new Error('boom');
          },
          { enabled: true }
        )
      ).rejects.toThrow('boom');
    });

    it('passes through successful results', async () => {
      const result = await withOperationDiagnostics(
        'test.op',
        { id: 1 },
        async () => 'ok',
        { enabled: true }
      );
      expect(result).toBe('ok');
    });
  });
});
