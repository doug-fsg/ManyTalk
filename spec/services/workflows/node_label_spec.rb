# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::NodeLabel do
  describe '.for_node' do
    it 'prefers custom label' do
      node = { 'type' => 'action', 'data' => { 'label' => 'Boas-vindas', 'action_name' => 'send_message' } }
      expect(described_class.for_node(node)).to eq('Boas-vindas')
    end

    it 'translates action nodes without custom label' do
      node = { 'type' => 'action', 'data' => { 'action_name' => 'send_message', 'action_params' => ['Oi'] } }
      expect(described_class.for_node(node)).to eq('Enviar uma mensagem')
    end

    it 'summarizes multi-action nodes' do
      node = {
        'type' => 'action',
        'data' => {
          'actions' => [
            { 'action_name' => 'send_message', 'action_params' => ['Oi'] },
            { 'action_name' => 'add_label', 'action_params' => ['vip'] }
          ]
        }
      }
      expect(described_class.for_node(node)).to eq('Enviar uma mensagem +1')
    end

    it 'translates trigger events' do
      node = { 'type' => 'trigger', 'data' => { 'event_name' => 'conversation_created' } }
      expect(described_class.for_node(node)).to eq('Conversa criada')
    end

    it 'translates wait nodes with duration' do
      node = { 'type' => 'wait', 'data' => { 'duration' => 2, 'unit' => 'hours' } }
      expect(described_class.for_node(node)).to eq('Espera · 2 hora(s)')
    end
  end

  describe '.action_details' do
    it 'returns empty for non-action nodes' do
      node = { 'type' => 'wait', 'data' => { 'duration' => 1, 'unit' => 'hours' } }
      expect(described_class.action_details(node)).to eq([])
    end

    it 'includes message preview for send_message' do
      node = {
        'type' => 'action',
        'data' => { 'action_name' => 'send_message', 'action_params' => ['Olá, tudo bem?'] }
      }
      expect(described_class.action_details(node)).to eq(['Enviar uma mensagem: Olá, tudo bem?'])
    end

    it 'lists each action in multi-action nodes' do
      node = {
        'type' => 'action',
        'data' => {
          'actions' => [
            { 'action_name' => 'send_message', 'action_params' => ['Oi'] },
            { 'action_name' => 'add_label', 'action_params' => ['vip'] }
          ]
        }
      }
      expect(described_class.action_details(node)).to eq(
        ['Enviar uma mensagem: Oi', 'Adicionar uma etiqueta: vip']
      )
    end
  end
end
