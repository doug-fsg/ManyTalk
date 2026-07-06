export const DEFAULT_FORM_BRANDING = {
  primary_color: '#1f93ff',
  background_color: '#ffffff',
  page_background_color: '#f8fafc',
  text_color: '#0f172a',
  logo_url: '',
  logo_alignment: 'center',
  logo_expand: false,
  header_title: '',
  header_description: '',
};

const LOGO_ALIGNMENTS = ['left', 'center', 'right'];

const JUSTIFY_CLASS = {
  left: 'justify-start',
  center: 'justify-center',
  right: 'justify-end',
};

const HEX_COLOR = /^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/;

const expandHex = hex => {
  if (hex.length === 4) {
    return `#${hex[1]}${hex[1]}${hex[2]}${hex[2]}${hex[3]}${hex[3]}`;
  }
  return hex;
};

const parseHex = value => {
  const hex = String(value || '').trim();
  if (!HEX_COLOR.test(hex)) return null;
  return expandHex(hex.toLowerCase());
};

/** Relative luminance (0–1). */
export const isDarkBackground = hex => {
  const parsed = parseHex(hex) || DEFAULT_FORM_BRANDING.background_color;
  const r = parseInt(parsed.slice(1, 3), 16) / 255;
  const g = parseInt(parsed.slice(3, 5), 16) / 255;
  const b = parseInt(parsed.slice(5, 7), 16) / 255;
  const toLinear = c =>
    c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
  const luminance =
    0.2126 * toLinear(r) + 0.7152 * toLinear(g) + 0.0722 * toLinear(b);
  return luminance < 0.45;
};

export const resolveFormBranding = (branding = {}) => {
  const source = branding || {};
  const primaryColor =
    parseHex(source.primary_color) || DEFAULT_FORM_BRANDING.primary_color;
  const backgroundColor =
    parseHex(source.background_color) || DEFAULT_FORM_BRANDING.background_color;
  const pageBackgroundColor =
    parseHex(source.page_background_color) ||
    DEFAULT_FORM_BRANDING.page_background_color;
  const textColor =
    parseHex(source.text_color) || DEFAULT_FORM_BRANDING.text_color;
  const logoUrl = typeof source.logo_url === 'string' ? source.logo_url : '';
  const logoExpand = source.logo_expand === true || source.logo_expand === 'true';
  const alignment = LOGO_ALIGNMENTS.includes(source.logo_alignment)
    ? source.logo_alignment
    : 'center';
  const isDark = isDarkBackground(backgroundColor);

  return {
    primaryColor,
    backgroundColor,
    pageBackgroundColor,
    pageStyle: { backgroundColor: pageBackgroundColor },
    textColor,
    logoUrl,
    logoExpand,
    logoAlignment: logoExpand ? 'center' : alignment,
    logoJustifyClass: logoExpand
      ? 'justify-center'
      : JUSTIFY_CLASS[alignment] || JUSTIFY_CLASS.center,
    isDark,
    titleStyle: { color: textColor },
    descriptionStyle: { color: textColor, opacity: 0.7 },
    labelStyle: { color: textColor, opacity: 0.85 },
    cardStyle: {
      backgroundColor,
      borderColor: isDark ? 'rgba(255,255,255,0.08)' : '#e2e8f0',
    },
    headerBorderStyle: {
      borderBottom: isDark
        ? '1px solid rgba(255,255,255,0.08)'
        : '1px solid #f1f5f9',
    },
    inputClass: isDark
      ? 'w-full px-3 py-2 border rounded-lg bg-white text-slate-900 border-white/20 focus:outline-none focus:ring-2 focus:ring-offset-0 transition-shadow'
      : 'w-full px-3 py-2 border rounded-lg border-slate-200 bg-slate-50 text-slate-900 focus:outline-none focus:ring-2 focus:ring-offset-0 transition-shadow',
    selectClass: isDark
      ? 'w-full px-3 py-2 border rounded-lg bg-white text-slate-900 border-white/20 focus:outline-none focus:ring-2 focus:ring-offset-0 transition-shadow'
      : 'w-full px-3 py-2 border rounded-lg border-slate-200 bg-white text-slate-900 focus:outline-none focus:ring-2 focus:ring-offset-0 transition-shadow',
    buttonStyle: { backgroundColor: primaryColor },
    focusRingStyle: { '--tw-ring-color': primaryColor },
  };
};
