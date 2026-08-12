import { downloadCsvAsExcel } from '../../contacts/utils/contactsExportHelper';

export const parseApiBlobError = async error => {
  const data = error?.response?.data;
  if (!data || typeof data.text !== 'function') return null;

  try {
    const payload = JSON.parse(await data.text());
    return payload.error || payload.message || null;
  } catch {
    return null;
  }
};

export const downloadSubmissionsAsExcel = (fileName, csvContent) =>
  downloadCsvAsExcel(fileName, csvContent);
