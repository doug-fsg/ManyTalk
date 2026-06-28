# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountForms::DefinitionValidator do
  let(:account) { create(:account) }

  def validator(fields)
    described_class.new({ 'fields' => fields }, account)
  end

  describe '#valid?' do
    it 'returns false for empty fields' do
      expect(validator([]).valid?).to be false
    end

    it 'returns true for valid native fields' do
      fields = [
        { 'key' => 'email', 'type' => 'native', 'field' => 'email', 'label' => 'E-mail' }
      ]
      expect(validator(fields).valid?).to be true
    end

    it 'returns false for unknown native field' do
      fields = [
        { 'key' => 'bad', 'type' => 'native', 'field' => 'unknown', 'label' => 'Bad' }
      ]
      v = validator(fields)
      expect(v.valid?).to be false
      expect(v.errors).to include(a_string_matching(/unknown native field/))
    end

    it 'returns false for duplicate keys' do
      fields = [
        { 'key' => 'email', 'type' => 'native', 'field' => 'email', 'label' => 'E-mail' },
        { 'key' => 'email', 'type' => 'native', 'field' => 'email', 'label' => 'Email 2' }
      ]
      v = validator(fields)
      expect(v.valid?).to be false
      expect(v.errors).to include(a_string_matching(/duplicate key/))
    end

    it 'returns false for too many fields' do
      fields = (1..21).map do |i|
        { 'key' => "field_#{i}", 'type' => 'native', 'field' => 'name', 'label' => "Field #{i}" }
      end
      expect(validator(fields).valid?).to be false
    end

    it 'returns false for custom_attribute without attribute_key' do
      fields = [
        { 'key' => 'cf_test', 'type' => 'custom_attribute', 'attribute_model' => 'contact_attribute' }
      ]
      v = validator(fields)
      expect(v.valid?).to be false
      expect(v.errors).to include(a_string_matching(/attribute_key is required/))
    end

    it 'returns false for custom_attribute with invalid attribute_model' do
      fields = [
        {
          'key' => 'cf_test', 'type' => 'custom_attribute',
          'attribute_key' => 'test', 'attribute_model' => 'invalid_model'
        }
      ]
      v = validator(fields)
      expect(v.valid?).to be false
    end
  end
end
