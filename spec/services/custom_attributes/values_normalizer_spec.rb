# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CustomAttributes::ValuesNormalizer do
  describe '.labels' do
    it 'returns string array as-is' do
      expect(described_class.labels(%w[Básico Premium])).to eq(%w[Básico Premium])
    end

    it 'extracts name from object array' do
      values = [
        { 'name' => 'Básico', 'color' => '#111' },
        { 'name' => 'Premium', 'color' => '#222' }
      ]
      expect(described_class.labels(values)).to eq(%w[Básico Premium])
    end

    it 'extracts labels from nested stages array' do
      values = {
        'stages' => [
          { 'name' => 'Estágio 1', 'color' => '#aaa' },
          { 'name' => 'Estágio 2', 'color' => '#bbb' }
        ]
      }
      expect(described_class.labels(values)).to eq(['Estágio 1', 'Estágio 2'])
    end

    it 'ignores empty objects saved by strong params' do
      expect(described_class.labels([{}])).to eq([])
    end
  end

  describe '.for_api' do
    it 'returns array values unchanged' do
      values = [{ name: 'A', color: '#fff' }]
      expect(described_class.for_api(values)).to eq(values)
    end

    it 'returns nested stages array unchanged' do
      values = { stages: %w[A B] }
      expect(described_class.for_api(values)).to eq(%w[A B])
    end

    it 'maps nested stages hash to api objects' do
      values = {
        stages: {
          'Estágio 1' => { 'color' => '#aaa' },
          'Estágio 2' => { 'color' => '#bbb' }
        }
      }
      expect(described_class.for_api(values)).to eq(
        [
          { name: 'Estágio 1', color: '#aaa' },
          { name: 'Estágio 2', color: '#bbb' }
        ]
      )
    end

    it 'respects stage_order when mapping nested stages hash' do
      values = {
        'stages' => {
          'Estágio 1' => { 'color' => '#aaa' },
          'Estágio 2' => { 'color' => '#bbb' },
          'Estágio 3' => { 'color' => '#ccc' }
        },
        'stage_order' => ['Estágio 3', 'Estágio 1', 'Estágio 2']
      }

      expect(described_class.for_api(values)).to eq(
        [
          { name: 'Estágio 3', color: '#ccc' },
          { name: 'Estágio 1', color: '#aaa' },
          { name: 'Estágio 2', color: '#bbb' }
        ]
      )
    end
  end
end
