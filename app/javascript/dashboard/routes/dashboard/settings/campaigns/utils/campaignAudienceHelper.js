export const AUDIENCE_SOURCES = {
  LABELS: 'labels',
  SPREADSHEET: 'spreadsheet',
};

export const defaultAudienceState = () => ({
  source: AUDIENCE_SOURCES.LABELS,
  selectedLabels: [],
  contactList: [],
  contactCount: 0,
  fileUploadError: '',
  validationMessages: [],
  hasMoreInvalidNumbers: false,
  totalInvalidNumbers: 0,
});

export const buildAudiencePayload = audienceState => {
  if (audienceState.source === AUDIENCE_SOURCES.SPREADSHEET) {
    return audienceState.contactList.map(contact => ({
      id: contact.numero,
      type: 'Contact',
      nome: contact.nome,
      variavel: contact.variavel,
    }));
  }

  return audienceState.selectedLabels.map(item => ({
    id: item.id,
    type: 'Label',
  }));
};

export const parseAudienceToState = (audience, labelOptions = []) => {
  const state = defaultAudienceState();
  if (!audience?.length) return state;

  if (audience[0].type === 'Contact') {
    state.source = AUDIENCE_SOURCES.SPREADSHEET;
    state.contactList = audience.map(contact => ({
      numero: contact.id,
      nome: contact.nome || '',
      variavel: contact.variavel || '',
    }));
    state.contactCount = state.contactList.length;
    return state;
  }

  state.source = AUDIENCE_SOURCES.LABELS;
  state.selectedLabels = audience.map(item =>
    labelOptions.find(label => label.id === item.id) || item
  );
  return state;
};

export const audienceStateIsComplete = audienceState => {
  if (!audienceState?.source) return false;
  if (audienceState.source === AUDIENCE_SOURCES.SPREADSHEET) {
    return audienceState.contactList.length > 0;
  }
  return audienceState.selectedLabels.length > 0;
};
