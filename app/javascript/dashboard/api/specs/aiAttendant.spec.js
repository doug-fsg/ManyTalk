import aiAttendant from '../aiAttendant';
import ApiClient from '../ApiClient';

describe('#AiAttendantAPI', () => {
  it('creates correct instance', () => {
    expect(aiAttendant).toBeInstanceOf(ApiClient);
    expect(aiAttendant).toHaveProperty('get');
    expect(aiAttendant).toHaveProperty('show');
    expect(aiAttendant).toHaveProperty('create');
    expect(aiAttendant).toHaveProperty('update');
    expect(aiAttendant).toHaveProperty('delete');
    expect(aiAttendant).toHaveProperty('test');
    expect(aiAttendant).toHaveProperty('getUsage');
    expect(aiAttendant.url).toBe('/api/v1/ai_attendant_configs');
  });

  describe('API calls', () => {
    const originalAxios = window.axios;
    const axiosMock = {
      post: vi.fn(() => Promise.resolve()),
      get: vi.fn(() => Promise.resolve()),
      patch: vi.fn(() => Promise.resolve()),
      delete: vi.fn(() => Promise.resolve()),
    };

    beforeEach(() => {
      window.axios = axiosMock;
    });

    afterEach(() => {
      window.axios = originalAxios;
    });

    it('#test', () => {
      aiAttendant.test(42, 'Olá');
      expect(axiosMock.post).toHaveBeenCalledWith(
        '/api/v1/ai_attendant_configs/42/test',
        { message: 'Olá', history: [] }
      );
    });

    it('#test with history', () => {
      const history = [{ role: 'user', content: 'Oi' }];
      aiAttendant.test(42, 'Tudo bem?', history);
      expect(axiosMock.post).toHaveBeenCalledWith(
        '/api/v1/ai_attendant_configs/42/test',
        { message: 'Tudo bem?', history }
      );
    });

    it('#getUsage', () => {
      aiAttendant.getUsage();
      expect(axiosMock.get).toHaveBeenCalledWith('/api/v1/ai_usage');
    });
  });
});
