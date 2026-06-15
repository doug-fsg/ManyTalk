import { describe, it, expect, vi } from 'vitest';
import { humanizeValidationError } from 'dashboard/helper/workflowValidationMessages';

const t = vi.fn(key => key);

describe('workflowValidationMessages', () => {
  it('maps unreachable node errors to friendly copy', () => {
    expect(
      humanizeValidationError(
        'Node node_1781207045220_kgvop is not reachable from trigger',
        t
      )
    ).toBe('WORKFLOW.VALIDATION.NOT_REACHABLE');
  });

  it('maps outbound connection errors to friendly copy', () => {
    expect(
      humanizeValidationError(
        'Node wait_1 must have at least one outbound connection',
        t
      )
    ).toBe('WORKFLOW.VALIDATION.NO_OUTBOUND');
  });

  it('falls back to generic message for unknown errors', () => {
    expect(humanizeValidationError('Something unexpected happened', t)).toBe(
      'WORKFLOW.VALIDATION.GENERIC'
    );
  });
});
