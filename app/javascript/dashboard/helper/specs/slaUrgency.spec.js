import { getSlaUrgencyScore } from '../slaUrgency';

describe('getSlaUrgencyScore', () => {
  const now = Math.floor(Date.now() / 1000);

  it('returns Infinity when conversation has no applied SLA', () => {
    expect(getSlaUrgencyScore({ id: 1 })).toBe(Number.POSITIVE_INFINITY);
  });

  it('returns lower score for conversation closer to VAR breach', () => {
    const urgent = {
      status: 'open',
      first_reply_created_at: 0,
      waiting_since: 0,
      applied_sla: {
        created_at: now - 100,
        sla_first_response_time_threshold: 120,
        sla_next_response_time_threshold: null,
        sla_resolution_time_threshold: null,
      },
    };
    const relaxed = {
      status: 'open',
      first_reply_created_at: 0,
      waiting_since: 0,
      applied_sla: {
        created_at: now - 100,
        sla_first_response_time_threshold: 3600,
        sla_next_response_time_threshold: null,
        sla_resolution_time_threshold: null,
      },
    };

    expect(getSlaUrgencyScore(urgent)).toBeLessThan(
      getSlaUrgencyScore(relaxed)
    );
  });
});
