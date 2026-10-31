import {
  applyVariableToken,
  openVariableQuery,
} from '../aiAttendantVariableQuery';

describe('aiAttendantVariableQuery', () => {
  it('opens after a single { and keeps the search text', () => {
    expect(openVariableQuery('envie {cat', 10)).toEqual({
      start: 6,
      search: 'cat',
    });
  });

  it('replaces the open brace with the file variable', () => {
    expect(applyVariableToken('envie {', '{{anexo:catalogo}}', 7)).toEqual({
      value: 'envie {{anexo:catalogo}}',
      cursor: 24,
    });
  });
});
