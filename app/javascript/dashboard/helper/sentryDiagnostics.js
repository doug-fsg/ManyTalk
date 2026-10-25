import * as Sentry from '@sentry/browser';

/** Default threshold for reporting a still-running async operation. */
export const SENTRY_SLOW_OPERATION_MS = 45000;

const SENSITIVE_KEY_PATTERN =
  /(content|password|token|secret|body|attachment|email|phone)/i;

/**
 * Passive Sentry helpers for long-running or failed UI operations.
 * Use `withOperationDiagnostics` around any async flow you need to observe in production.
 * Does not change application behavior beyond reporting when Sentry is configured.
 */

export function isFrontendSentryEnabled() {
  return Boolean(window.errorLoggingConfig);
}

/**
 * Opt-out via `window.chatwootConfig.enableSentryOperationDiagnostics = false`.
 */
export function isOperationDiagnosticsEnabled() {
  if (!isFrontendSentryEnabled()) return false;
  const flag = window.chatwootConfig?.enableSentryOperationDiagnostics;
  return flag !== false;
}

export function sanitizeDiagnosticContext(context = {}) {
  if (!context || typeof context !== 'object') return {};

  return Object.fromEntries(
    Object.entries(context)
      .filter(([key, value]) => {
        if (SENSITIVE_KEY_PATTERN.test(key)) return false;
        const valueType = typeof value;
        return (
          valueType === 'string' ||
          valueType === 'number' ||
          valueType === 'boolean' ||
          value === null ||
          value === undefined
        );
      })
      .map(([key, value]) => [key, value === undefined ? null : value])
      .slice(0, 25)
  );
}

export function getHttpErrorContext(error) {
  const response = error?.response;
  return sanitizeDiagnosticContext({
    http_status: response?.status ?? null,
    http_status_text: response?.statusText ?? null,
  });
}

export function syncSentryUserContext({ user, accountId } = {}) {
  if (!isFrontendSentryEnabled() || !user?.id) return;

  Sentry.setUser({
    id: String(user.id),
    email: user.email ? String(user.email) : undefined,
  });

  if (accountId) {
    Sentry.setTag('account_id', String(accountId));
  }
}

function reportOperationFailure(operationName, context, error) {
  Sentry.withScope(scope => {
    scope.setTag('operation', operationName);
    scope.setContext('operation', {
      name: operationName,
      ...sanitizeDiagnosticContext(context),
      ...getHttpErrorContext(error),
    });
    scope.setFingerprint(['operation-failure', operationName]);
    Sentry.captureException(error);
  });
}

export function captureOperationFailure(operationName, context, error) {
  if (!isOperationDiagnosticsEnabled()) return;
  reportOperationFailure(operationName, context, error);
}

function reportSlowOperation(operationName, context, durationMs) {
  Sentry.withScope(scope => {
    scope.setLevel('warning');
    scope.setTag('operation', operationName);
    scope.setContext('operation', {
      name: operationName,
      duration_ms: durationMs,
      ...sanitizeDiagnosticContext(context),
    });
    scope.setFingerprint(['operation-slow', operationName]);
    Sentry.captureMessage(`Slow operation: ${operationName}`, 'warning');
  });
}

function addOperationBreadcrumb(operationName, phase, data = {}) {
  Sentry.addBreadcrumb({
    category: 'operation',
    message: `${operationName}:${phase}`,
    level: 'info',
    data: sanitizeDiagnosticContext(data),
  });
}

/**
 * Wraps an async function with breadcrumbs, slow-operation reporting, and error capture.
 * Re-throws errors after reporting so callers keep their existing control flow.
 *
 * @example
 * await withOperationDiagnostics(
 *   'crm.sync_board',
 *   { board_id: id },
 *   () => api.sync(id),
 *   { slowThresholdMs: 60000 }
 * );
 */
export async function withOperationDiagnostics(
  operationName,
  context,
  asyncFn,
  options = {}
) {
  const { slowThresholdMs = SENTRY_SLOW_OPERATION_MS, enabled } = options;
  const safeContext = sanitizeDiagnosticContext(context);
  const diagnosticsEnabled = enabled ?? isOperationDiagnosticsEnabled();

  if (!diagnosticsEnabled) {
    return asyncFn();
  }

  const startedAt = Date.now();
  addOperationBreadcrumb(operationName, 'start', safeContext);

  const slowTimer = setTimeout(() => {
    reportSlowOperation(operationName, safeContext, Date.now() - startedAt);
  }, slowThresholdMs);

  try {
    return await asyncFn();
  } catch (error) {
    reportOperationFailure(operationName, safeContext, error);
    throw error;
  } finally {
    clearTimeout(slowTimer);
    addOperationBreadcrumb(operationName, 'end', {
      duration_ms: Date.now() - startedAt,
    });
  }
}
