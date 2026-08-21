# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::AiWebhook do
  before { allow(ENV).to receive(:[]).and_call_original }

  describe '.url' do
    it 'returns WORKFLOW_AI_URL when set' do
      allow(ENV).to receive(:[]).with('WORKFLOW_AI_URL').and_return('https://ai.example/hook')
      expect(described_class.url).to eq('https://ai.example/hook')
    end

    it 'returns nil when blank' do
      allow(ENV).to receive(:[]).with('WORKFLOW_AI_URL').and_return('  ')
      expect(described_class.url).to be_nil
    end
  end

  describe '.configured?' do
    it 'is true when url is present' do
      allow(ENV).to receive(:[]).with('WORKFLOW_AI_URL').and_return('https://ai.example/hook')
      expect(described_class).to be_configured
    end

    it 'is false when url is missing' do
      allow(ENV).to receive(:[]).with('WORKFLOW_AI_URL').and_return(nil)
      expect(described_class).not_to be_configured
    end
  end
end
