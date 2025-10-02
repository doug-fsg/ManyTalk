/* global axios */
import ApiClient from './ApiClient';

class ContactAttributeFilesAPI extends ApiClient {
  constructor() {
    super('', { accountScoped: true });
  }

  upload(contactId, attributeKey, files) {
    const formData = new FormData();
    formData.append('attribute_key', attributeKey);

    if (Array.isArray(files)) {
      files.forEach(file => {
        formData.append('files[]', file);
      });
    } else {
      formData.append('file', files);
    }

    return axios.post(
      `${this.baseUrl()}/contacts/${contactId}/contact_attribute_files`,
      formData,
      {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      }
    ).catch(error => {
      console.error('Upload error:', error.response || error);
      throw error;
    });
  }

  delete(contactId, attributeKey, blobKey) {
    return axios.delete(
      `${this.baseUrl()}/contacts/${contactId}/contact_attribute_files`,
      {
        params: {
          attribute_key: attributeKey,
          blob_key: blobKey,
        },
      }
    ).catch(error => {
      console.error('Delete error:', error.response || error);
      throw error;
    });
  }
}

export default new ContactAttributeFilesAPI();

