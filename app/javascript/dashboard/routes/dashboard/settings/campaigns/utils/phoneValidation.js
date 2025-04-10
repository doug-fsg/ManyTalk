// Função para limpar o número de telefone, removendo todos os caracteres não numéricos
export const cleanPhoneNumber = phone => {
  if (!phone) return '';
  return phone.toString().replace(/\D/g, '');
};

// Função para validar o formato do número de telefone
export const validatePhoneNumber = phone => {
  if (!phone) {
    return { 
      isValid: false, 
      messageKey: 'CAMPAIGN.ADD.FORM.CONTACT_LIST.ERROR_EMPTY_NUMBER'
    };
  }

  const cleanedNumber = cleanPhoneNumber(phone);
  
  // Verifica se é um número internacional (começa com +)
  if (phone.toString().startsWith('+')) {
    return { 
      isValid: true, 
      messageKey: 'CAMPAIGN.ADD.FORM.CONTACT_LIST.INFO_INTERNATIONAL'
    };
  }

  // Verifica se tem apenas 8 ou 9 dígitos (sem DDD)
  if (cleanedNumber.length === 8 || cleanedNumber.length === 9) {
    return { 
      isValid: false, 
      messageKey: 'CAMPAIGN.ADD.FORM.CONTACT_LIST.ERROR_MISSING_DDD'
    };
  }

  // Verifica se tem 10 ou 11 dígitos (padrão brasileiro)
  if (cleanedNumber.length === 10 || cleanedNumber.length === 11) {
    return { isValid: true, messageKey: 'CAMPAIGN.ADD.FORM.CONTACT_LIST.ERROR_VALID' };
  }

  // Se tiver mais de 11 dígitos, não está no padrão brasileiro
  return { 
    isValid: false, 
    //messageKey: 'CAMPAIGN.ADD.FORM.CONTACT_LIST.ERROR_MISSING_DDD'
    messageKey: 'CAMPAIGN.ADD.FORM.CONTACT_LIST.ERROR_BRAZILIAN_FORMAT'
  };
};

// Função para validar uma lista de números de telefone
export const validatePhoneList = (contacts, i18n) => {
  const validationResults = contacts.map(contact => {
    const validation = validatePhoneNumber(contact.numero);
    return {
      ...contact,
      isValid: validation.isValid,
      messageKey: validation.messageKey
    };
  });

  const invalidNumbers = validationResults.filter(contact => !contact.isValid);
  const validNumbers = validationResults.filter(contact => contact.isValid);

  // Limitar a quantidade de números inválidos exibidos para 10
  const MAX_INVALID_DISPLAY = 10;
  const hasMoreInvalid = invalidNumbers.length > MAX_INVALID_DISPLAY;
  const limitedInvalidNumbers = hasMoreInvalid 
    ? invalidNumbers.slice(0, MAX_INVALID_DISPLAY) 
    : invalidNumbers;

  // Agrupar números inválidos por tipo de erro
  const errorGroups = {};
  invalidNumbers.forEach(contact => {
    if (!errorGroups[contact.messageKey]) {
      errorGroups[contact.messageKey] = [];
    }
    errorGroups[contact.messageKey].push(contact);
  });

  return {
    validNumbers,
    invalidNumbers,
    limitedInvalidNumbers,
    errorGroups,
    hasErrors: invalidNumbers.length > 0,
    hasMoreInvalid,
    totalInvalid: invalidNumbers.length,
    MAX_INVALID_DISPLAY
  };
}; 