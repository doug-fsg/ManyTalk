const MESSAGES = {
  pt_BR: {
    NATIVE: {
      NAME: 'Nome',
      EMAIL: 'E-mail',
      PHONE: 'Telefone',
    },
    UNAVAILABLE: 'Formulário indisponível.',
    SUBMIT: 'Enviar',
    SUBMIT_SUCCESS: 'Enviado com sucesso!',
    SUBMIT_ERROR: 'Não foi possível enviar. Tente novamente.',
    EMPTY_SUBMISSION: 'Preencha pelo menos um campo antes de enviar.',
    SELECT_REQUIRED: 'Selecione uma opção…',
    SELECT_OPTIONAL: 'Opcional',
    NO_LIST_OPTIONS: 'Nenhuma opção configurada para este campo.',
    PLACEHOLDER_PHONE: '(11) 99999-9999',
    PLACEHOLDER_EMAIL: 'seu@email.com',
    PLACEHOLDER_NAME: 'Seu nome completo',
    PLACEHOLDER_LINK: 'https://exemplo.com',
    PLACEHOLDER_CURRENCY: '0,00',
    PLACEHOLDER_PERCENT: '0',
    PLACEHOLDER_NUMBER: '0',
    PLACEHOLDER_TEXTAREA: 'Escreva sua mensagem…',
    TEXTAREA_HINT: 'Enter cria uma nova linha.',
  },
  en: {
    NATIVE: {
      NAME: 'Name',
      EMAIL: 'Email',
      PHONE: 'Phone',
    },
    UNAVAILABLE: 'Form unavailable.',
    SUBMIT: 'Submit',
    SUBMIT_SUCCESS: 'Submitted successfully!',
    SUBMIT_ERROR: 'Could not submit. Please try again.',
    EMPTY_SUBMISSION: 'Fill in at least one field before submitting.',
    SELECT_REQUIRED: 'Select an option…',
    SELECT_OPTIONAL: 'Optional',
    NO_LIST_OPTIONS: 'No options configured for this field.',
    PLACEHOLDER_PHONE: '(555) 123-4567',
    PLACEHOLDER_EMAIL: 'you@email.com',
    PLACEHOLDER_NAME: 'Your full name',
    PLACEHOLDER_LINK: 'https://example.com',
    PLACEHOLDER_CURRENCY: '0.00',
    PLACEHOLDER_PERCENT: '0',
    PLACEHOLDER_NUMBER: '0',
    PLACEHOLDER_TEXTAREA: 'Write your message…',
    TEXTAREA_HINT: 'Press Enter to start a new line.',
  },
};

const normalizeLocale = locale => {
  if (!locale) return 'pt_BR';
  if (MESSAGES[locale]) return locale;
  const base = locale.split(/[-_]/)[0];
  if (base === 'pt') return 'pt_BR';
  return MESSAGES[base] ? base : 'pt_BR';
};

export const resolvePublicFormLocale = config =>
  normalizeLocale(config?.locale || config?.globalConfig?.locale);

export const publicFormMessages = locale => MESSAGES[normalizeLocale(locale)] || MESSAGES.pt_BR;

export const publicFormFieldLabels = locale => {
  const m = publicFormMessages(locale);
  return {
    selectRequired: m.SELECT_REQUIRED,
    selectOptional: m.SELECT_OPTIONAL,
    noListOptions: m.NO_LIST_OPTIONS,
    placeholders: {
      phone: m.PLACEHOLDER_PHONE,
      email: m.PLACEHOLDER_EMAIL,
      name: m.PLACEHOLDER_NAME,
      link: m.PLACEHOLDER_LINK,
      currency: m.PLACEHOLDER_CURRENCY,
      percent: m.PLACEHOLDER_PERCENT,
      number: m.PLACEHOLDER_NUMBER,
      textarea: m.PLACEHOLDER_TEXTAREA,
    },
    textareaHint: m.TEXTAREA_HINT,
  };
};
