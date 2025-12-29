export const validateActions = actions => {
  if (!actions || !Array.isArray(actions) || actions.length === 0) {
    return false;
  }
  return actions.every(action => {
    if (!action.action_name) {
      return false;
    }
    return true;
  });
};

