import { describe, expect, it } from 'vitest';
import {
  displayTimelineStatus,
  displayWorkflowStepLabel,
} from '../workflowDisplayLabels';

const t = key => {
  const labels = {
    'WORKFLOW.EDITOR.NODE_ACTION': 'Action',
    'WORKFLOW.EDITOR.NODE_WAIT': 'Wait',
    'WORKFLOW.REGUA.TIMELINE.COMPLETED': 'Completed',
    'WORKFLOW.REGUA.TIMELINE.RUNNING': 'Running',
  };
  return labels[key] || key;
};

describe('workflowDisplayLabels', () => {
  describe('displayWorkflowStepLabel', () => {
    it('prefers human-readable API label', () => {
      expect(
        displayWorkflowStepLabel(
          { label: 'Boas-vindas', type: 'action' },
          t
        )
      ).toBe('Boas-vindas');
    });

    it('falls back to node type i18n for technical keys', () => {
      expect(
        displayWorkflowStepLabel({ label: 'action', type: 'action' }, t)
      ).toBe('Action');
    });

    it('returns em dash when item is missing', () => {
      expect(displayWorkflowStepLabel(null, t)).toBe('—');
    });
  });

  describe('displayTimelineStatus', () => {
    it('translates known statuses', () => {
      expect(displayTimelineStatus('completed', t)).toBe('Completed');
      expect(displayTimelineStatus('running', t)).toBe('Running');
    });

    it('returns raw status when translation is missing', () => {
      expect(displayTimelineStatus('custom', t)).toBe('custom');
    });
  });
});
