require 'rails_helper'

RSpec.describe SupportWidgetScriptBuilder do
  describe '.build' do
    it 'returns nil when token is missing' do
      expect(described_class.build(website_token: nil)).to be_nil
    end

    it 'returns widget script when token and FRONTEND_URL are present' do
      allow(ENV).to receive(:fetch).with('FRONTEND_URL', '').and_return('https://app.example.com')

      script = described_class.build(website_token: 'abc123')

      expect(script).to include('hideMessageBubble: true')
      expect(script).to include('websiteToken: \'abc123\'')
      expect(script).to include('https://app.example.com/packs/js/sdk.js')
    end
  end
end
