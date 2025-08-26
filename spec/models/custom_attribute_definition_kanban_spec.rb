# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CustomAttributeDefinition, type: :model do
  describe 'Kanban functionality' do
    let(:account) { create(:account) }

    describe 'scopes' do
      before do
        create(:custom_attribute_definition, :kanban, account: account)
        create(:custom_attribute_definition, account: account, is_kanban: false)
        create(:custom_attribute_definition, account: account, is_kanban: false)
      end

      it 'filters kanban attributes correctly' do
        expect(CustomAttributeDefinition.kanban_attributes.count).to eq(1)
        expect(CustomAttributeDefinition.non_kanban_attributes.count).to eq(2)
      end

      it 'returns correct kanban attributes' do
        kanban_attr = CustomAttributeDefinition.kanban_attributes.first
        expect(kanban_attr.is_kanban).to be true
        expect(kanban_attr.attribute_display_type).to eq('list')
        expect(kanban_attr.attribute_model).to eq('contact_attribute')
      end
    end

    describe 'default values' do
      it 'sets is_kanban to false by default' do
        attr = create(:custom_attribute_definition, account: account)
        expect(attr.is_kanban).to be false
      end

      it 'allows setting is_kanban to true' do
        attr = create(:custom_attribute_definition, :kanban, account: account)
        expect(attr.is_kanban).to be true
      end
    end

    describe 'backward compatibility' do
      context 'when is_kanban column does not exist (simulating old data)' do
        it 'handles missing column gracefully' do
          # Este teste simula a situação onde dados antigos não têm a coluna is_kanban
          attr = create(:custom_attribute_definition, account: account)
          
          # Remove o valor da coluna para simular dados antigos
          CustomAttributeDefinition.where(id: attr.id).update_all(is_kanban: nil)
          attr.reload
          
          # O modelo deve ainda funcionar
          expect(attr.attribute_display_name).to be_present
          expect(attr.attribute_key).to be_present
        end
      end
    end

    describe 'kanban trait factory' do
      it 'creates proper kanban attributes' do
        kanban_attr = create(:custom_attribute_definition, :kanban, account: account)
        
        expect(kanban_attr.is_kanban).to be true
        expect(kanban_attr.attribute_display_type).to eq('list')
        expect(kanban_attr.attribute_model).to eq('contact_attribute')
        expect(kanban_attr.attribute_values).to include('Estágio 1', 'Estágio 2', 'Estágio 3')
      end
    end
  end
end
