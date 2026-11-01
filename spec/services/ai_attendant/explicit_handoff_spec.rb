# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiAttendant::ExplicitHandoff do
  describe '.match?' do
    it 'matches a direct request for a human' do
      expect(described_class.match?('quero falar com um atendente')).to be(true)
      expect(described_class.match?('me transfere para uma pessoa')).to be(true)
    end

    it 'ignores a negated request' do
      expect(described_class.match?('não quero falar com um humano')).to be(false)
    end

    it 'ignores ordinary questions' do
      expect(described_class.match?('qual o horário de atendimento?')).to be(false)
    end
  end
end
