/** Maps API display type names to numeric ids used in AddAttribute forms. */
export const ATTRIBUTE_DISPLAY_TYPE_IDS = {
  text: 0,
  number: 1,
  currency: 2,
  percent: 3,
  link: 4,
  date: 5,
  list: 6,
  checkbox: 7,
  file: 8,
  textarea: 9,
};

export const ATTRIBUTE_MODELS = [
  {
    id: 0,
    option: 'Conversation',
  },
  {
    id: 1,
    option: 'Contact',
  },
];

export const ATTRIBUTE_TYPES = [
  { id: 0, i18nKey: 'ATTRIBUTES_MGMT.ADD.FORM.TYPE.OPTIONS.TEXT' },
  { id: 9, i18nKey: 'ATTRIBUTES_MGMT.ADD.FORM.TYPE.OPTIONS.TEXTAREA' },
  { id: 1, i18nKey: 'ATTRIBUTES_MGMT.ADD.FORM.TYPE.OPTIONS.NUMBER' },
  { id: 4, i18nKey: 'ATTRIBUTES_MGMT.ADD.FORM.TYPE.OPTIONS.LINK' },
  { id: 5, i18nKey: 'ATTRIBUTES_MGMT.ADD.FORM.TYPE.OPTIONS.DATE' },
  { id: 6, i18nKey: 'ATTRIBUTES_MGMT.ADD.FORM.TYPE.OPTIONS.LIST' },
  { id: 7, i18nKey: 'ATTRIBUTES_MGMT.ADD.FORM.TYPE.OPTIONS.CHECKBOX' },
];

/** Contact attribute types allowed on public forms (excludes file). */
export const FORM_CONTACT_ATTRIBUTE_TYPES = [
  { id: 0, i18nKey: 'ATTRIBUTES_MGMT.ADD.FORM.TYPE.OPTIONS.TEXT' },
  { id: 9, i18nKey: 'ATTRIBUTES_MGMT.ADD.FORM.TYPE.OPTIONS.TEXTAREA' },
  { id: 1, i18nKey: 'ATTRIBUTES_MGMT.ADD.FORM.TYPE.OPTIONS.NUMBER' },
  { id: 2, i18nKey: 'ATTRIBUTES_MGMT.ADD.FORM.TYPE.OPTIONS.CURRENCY' },
  { id: 3, i18nKey: 'ATTRIBUTES_MGMT.ADD.FORM.TYPE.OPTIONS.PERCENT' },
  { id: 4, i18nKey: 'ATTRIBUTES_MGMT.ADD.FORM.TYPE.OPTIONS.LINK' },
  { id: 5, i18nKey: 'ATTRIBUTES_MGMT.ADD.FORM.TYPE.OPTIONS.DATE' },
  { id: 6, i18nKey: 'ATTRIBUTES_MGMT.ADD.FORM.TYPE.OPTIONS.LIST' },
  { id: 7, i18nKey: 'ATTRIBUTES_MGMT.ADD.FORM.TYPE.OPTIONS.CHECKBOX' },
];
