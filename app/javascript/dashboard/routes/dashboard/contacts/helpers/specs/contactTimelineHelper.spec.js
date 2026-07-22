import {
  buildTimelineSummary,
  formatTimelineRelativeTime,
  getFilterCounts,
  groupEventsByDate,
  matchesTimelineFilter,
  getEventPresentation,
  normalizeLocaleCode,
} from '../contactTimelineHelper';

const t = key => key;

describe('contactTimelineHelper', () => {
  const events = [
    {
      id: '1',
      type: 'form_submission',
      occurred_at: '2026-07-22T10:00:00.000Z',
      meta: { account_form_name: 'Lead Form' },
    },
    {
      id: '2',
      type: 'pipeline_entered',
      occurred_at: '2026-07-21T10:00:00.000Z',
      meta: { pipeline_name: 'Sales', pipeline_id: 1 },
    },
    {
      id: '3',
      type: 'activity',
      occurred_at: '2026-07-20T10:00:00.000Z',
      meta: {
        title: 'Call',
        status: 'pending',
        scheduled_at: '2026-07-23T10:00:00.000Z',
      },
    },
  ];

  it('groups events by date in descending order', () => {
    const groups = groupEventsByDate(events, 'en', t);

    expect(groups).toHaveLength(3);
    expect(groups[0].events[0].id).toBe('1');
    expect(groups[1].events[0].id).toBe('2');
  });

  it('counts filters from loaded events', () => {
    const counts = getFilterCounts(events, ['all', 'pipeline', 'activity'], 'all');

    expect(counts.all).toBe(3);
    expect(counts.pipeline).toBe(1);
    expect(counts.activity).toBe(1);
  });

  it('matches pipeline filter types', () => {
    expect(
      matchesTimelineFilter(events[1], 'pipeline', 'all')
    ).toBe(true);
    expect(
      matchesTimelineFilter(events[0], 'pipeline', 'all')
    ).toBe(false);
  });

  it('builds timeline summary', () => {
    const summary = buildTimelineSummary(events, t);

    expect(summary.firstContactLabel).toContain('CONTACT_PROFILE');
    expect(summary.pipelineLabel).toContain('CONTACT_PROFILE');
    expect(summary.nextActivityLabel).toContain('CONTACT_PROFILE');
  });

  it('formats relative time in portuguese', () => {
    const twoDaysAgo = Math.floor(
      (Date.now() - 2 * 24 * 60 * 60 * 1000) / 1000
    );

    const label = formatTimelineRelativeTime(twoDaysAgo, 'pt_BR');

    expect(label).toMatch(/dia/);
    expect(label).not.toMatch(/day/i);
  });

  it('normalizes locale codes for portuguese accounts', () => {
    expect(normalizeLocaleCode('pt')).toBe('pt_BR');
    expect(normalizeLocaleCode('pt-BR')).toBe('pt_BR');
  });
});
