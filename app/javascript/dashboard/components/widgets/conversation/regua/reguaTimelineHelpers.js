export const formatActionDetailsText = actionDetails => {
  if (!Array.isArray(actionDetails) || !actionDetails.length) return '';
  return actionDetails.join('\n');
};

export const buildActionDetailsTooltip = actionDetails => {
  const content = formatActionDetailsText(actionDetails);
  if (!content) return null;
  return {
    content,
    classes: ['regua-action-tooltip'],
  };
};

export const actionDetailsTextForItem = item =>
  formatActionDetailsText(item && item.action_details);

export const actionDetailsTooltipForItem = item =>
  buildActionDetailsTooltip(item && item.action_details);
