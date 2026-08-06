import { describe, expect, it } from 'vitest';
import {
  actionDetailsTextForItem,
  actionDetailsTooltipForItem,
  buildActionDetailsTooltip,
  formatActionDetailsText,
} from '../reguaTimelineHelpers';

describe('reguaTimelineHelpers', () => {
  describe('formatActionDetailsText', () => {
    it('joins multiple action details with newlines', () => {
      expect(
        formatActionDetailsText([
          'Enviar uma mensagem: Oi',
          'Adicionar uma etiqueta: vip',
        ])
      ).toBe('Enviar uma mensagem: Oi\nAdicionar uma etiqueta: vip');
    });

    it('returns empty string for missing or empty details', () => {
      expect(formatActionDetailsText(null)).toBe('');
      expect(formatActionDetailsText([])).toBe('');
    });
  });

  describe('buildActionDetailsTooltip', () => {
    it('returns tooltip config with multiline content and css class', () => {
      expect(
        buildActionDetailsTooltip(['Enviar uma mensagem: Oi', 'Adicionar uma etiqueta: vip'])
      ).toEqual({
        content: 'Enviar uma mensagem: Oi\nAdicionar uma etiqueta: vip',
        classes: ['regua-action-tooltip'],
      });
    });

    it('returns null when there is no content', () => {
      expect(buildActionDetailsTooltip([])).toBeNull();
    });
  });

  describe('actionDetailsTextForItem', () => {
    it('reads action_details from timeline item', () => {
      expect(
        actionDetailsTextForItem({
          action_details: ['Enviar uma mensagem: Olá'],
        })
      ).toBe('Enviar uma mensagem: Olá');
    });
  });

  describe('actionDetailsTooltipForItem', () => {
    it('builds tooltip from timeline item', () => {
      expect(
        actionDetailsTooltipForItem({
          action_details: ['Resolver conversa'],
        })
      ).toEqual({
        content: 'Resolver conversa',
        classes: ['regua-action-tooltip'],
      });
    });
  });
});
