# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Account do
  it 'enables atendimento_ia_nativo' do
    account = create(:account)
    account.enable_features!('atendimento_ia_nativo')
    expect(account.feature_enabled?('atendimento_ia_nativo')).to be true
  end
end
