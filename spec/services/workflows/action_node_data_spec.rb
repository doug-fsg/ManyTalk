# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::ActionNodeData do
  describe '.items' do
    it 'returns legacy single action as a one-item list' do
      expect(described_class.items(
               'action_name' => 'add_label',
               'action_params' => ['vip']
             )).to eq([{ 'action_name' => 'add_label', 'action_params' => ['vip'] }])
    end

    it 'prefers actions array when present' do
      data = {
        'action_name' => 'send_message',
        'action_params' => ['ignored'],
        'actions' => [
          { 'action_name' => 'add_label', 'action_params' => ['a'] },
          { 'action_name' => 'resolve_conversation', 'action_params' => [] }
        ]
      }

      expect(described_class.items(data)).to eq([
                                                  { 'action_name' => 'add_label', 'action_params' => ['a'] },
                                                  { 'action_name' => 'resolve_conversation', 'action_params' => [] }
                                                ])
    end

    it 'returns empty list when no action is configured' do
      expect(described_class.items({})).to eq([])
    end
  end
end
