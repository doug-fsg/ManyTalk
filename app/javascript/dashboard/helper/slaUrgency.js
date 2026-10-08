/**
 * Mirrors @chatwoot/utils SLA urgency: smallest |seconds to breach| among active FRT/NRT/RT.
 * Lower score = more urgent. No applicable SLA → +Infinity (sorts last).
 */
export function getSlaUrgencyScore(conversation) {
  const appliedSla = conversation?.applied_sla;
  if (!appliedSla || !conversation) return Number.POSITIVE_INFINITY;

  const now = Math.floor(Date.now() / 1000);
  const {
    sla_first_response_time_threshold: frtThreshold,
    sla_next_response_time_threshold: nrtThreshold,
    sla_resolution_time_threshold: rtThreshold,
    created_at: appliedSlaCreatedAt,
  } = appliedSla;

  const {
    first_reply_created_at: firstReplyCreatedAt,
    waiting_since: waitingSince,
    status,
  } = conversation;

  const thresholds = [];

  if (
    frtThreshold != null &&
    (!firstReplyCreatedAt || firstReplyCreatedAt === 0)
  ) {
    thresholds.push(
      Math.abs(appliedSlaCreatedAt + frtThreshold - now)
    );
  }
  if (nrtThreshold != null && firstReplyCreatedAt && waitingSince) {
    thresholds.push(Math.abs(waitingSince + nrtThreshold - now));
  }
  if (status === 'open' && rtThreshold != null) {
    thresholds.push(Math.abs(appliedSlaCreatedAt + rtThreshold - now));
  }

  if (thresholds.length === 0) return Number.POSITIVE_INFINITY;
  return Math.min(...thresholds);
}
