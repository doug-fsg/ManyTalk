require 'rails_helper'

describe AiAttendant::MessageBuffer do
  let(:account_id) { 41 }
  let(:inbox_id) { 42 }
  let(:conversation_id) { 43 }
  let(:buffer) do
    described_class.new(
      account_id: account_id,
      inbox_id: inbox_id,
      conversation_id: conversation_id
    )
  end

  after { buffer.clear! }

  describe '#push' do
    it 'returns :leader only for the first of two rapid pushes and concatenates contents in order' do
      first = buffer.push(message_id: 101, content: 'Oi, preciso de ajuda', debounce_seconds: 5)
      second = buffer.push(message_id: 102, content: 'sobre o pedido 123', debounce_seconds: 5)

      expect(first).to eq(:leader)
      expect(second).to eq(:follower)

      # Duas incoming em ~2s: o buffer ainda guarda ambos para um único turno LLM.
      sleep 2

      expect(buffer.combined_content).to eq("Oi, preciso de ajuda\nsobre o pedido 123")
    end
  end

  describe '#clear!' do
    it 'empties the buffer so the next push is leader again' do
      buffer.push(message_id: 1, content: 'primeira', debounce_seconds: 5)
      buffer.clear!

      expect(buffer.combined_content).to eq('')
      expect(buffer.push(message_id: 2, content: 'nova', debounce_seconds: 5)).to eq(:leader)
    end
  end
end
