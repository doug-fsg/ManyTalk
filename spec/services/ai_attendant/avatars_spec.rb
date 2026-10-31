# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiAttendant::Avatars do
  it 'exposes six catalog ids' do
    expect(described_class::IDS).to eq(
      %w[avatar_1 avatar_2 avatar_3 avatar_4 avatar_5 avatar_6]
    )
  end

  it 'points to a public png for each catalog id' do
    described_class::IDS.each do |id|
      path = described_class.path_for(id)
      expect(path).to be_exist
      expect(described_class.url_for(id)).to eq("/ai_attendant/avatars/#{id}.png")
    end
  end
end
