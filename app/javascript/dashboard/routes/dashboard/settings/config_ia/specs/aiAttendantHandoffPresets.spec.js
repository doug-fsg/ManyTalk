import {
  parseHandoffConditions,
  serializeHandoffConditions,
} from '../aiAttendantHandoffPresets';

const labels = {
  ask_human: 'Cliente pediu para falar com um humano',
  complaint: 'Cliente está insatisfeito ou reclamando',
};

describe('aiAttendantHandoffPresets', () => {
  it('serializes selected presets and extra lines', () => {
    expect(
      serializeHandoffConditions(['ask_human'], 'Outro motivo', labels)
    ).toBe(
      'Cliente pediu para falar com um humano\nOutro motivo'
    );
  });

  it('parses stored conditions back into presets and leftover text', () => {
    expect(
      parseHandoffConditions(
        'Cliente pediu para falar com um humano\nTexto livre',
        labels
      )
    ).toEqual({
      selected: ['ask_human'],
      extra: 'Texto livre',
    });
  });
});
