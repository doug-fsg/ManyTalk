import * as XLSX from 'xlsx';

export const downloadCsvAsExcel = (fileName, csvContent) => {
  const workbook = XLSX.read(csvContent, { type: 'string' });
  const normalizedName = fileName.endsWith('.xlsx')
    ? fileName
    : `${fileName}.xlsx`;
  XLSX.writeFile(workbook, normalizedName);
};

export const parseExportBlobResponse = async response => {
  const contentType = response?.headers?.['content-type'] || '';
  const data = response?.data;

  if (contentType.includes('text/csv') || contentType.includes('application/csv')) {
    const csvContent =
      typeof data === 'string' ? data : await data.text();
    return { mode: 'direct', csvContent };
  }

  if (data instanceof Blob || (data && typeof data.text === 'function')) {
    const text = await data.text();
    try {
      const payload = JSON.parse(text);
      return {
        mode: payload.export_mode || 'email',
        message: payload.message,
      };
    } catch {
      return { mode: 'direct', csvContent: text };
    }
  }

  if (typeof data === 'object' && data !== null) {
    return {
      mode: data.export_mode || 'email',
      message: data.message,
    };
  }

  return { mode: 'email' };
};
