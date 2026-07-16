# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Contacts::KanbanLegacyCleanup do
  let(:account) { create(:account) }
  let(:pipeline) do
    create(
      :custom_attribute_definition,
      :kanban,
      account: account,
      attribute_key: 'sales_pipeline'
    )
  end

  describe '.cleanup!' do
    it 'removes kanban data from custom_attributes and additional_attributes' do
      contact = create(
        :contact,
        account: account,
        custom_attributes: { 'sales_pipeline' => 'Lead' },
        additional_attributes: {
          'kanban' => {
            pipeline.id.to_s => {
              'deal' => { 'value' => 100 },
              'stage_tracking' => { 'current' => { 'entered_at' => Time.current.iso8601 } }
            }
          }
        }
      )

      described_class.cleanup!(contact, pipeline)
      contact.reload

      expect(contact.custom_attributes).not_to have_key('sales_pipeline')
      expect(contact.additional_attributes.dig('kanban', pipeline.id.to_s)).to be_nil
    end
  end

  describe '.import_from_json!' do
    it 'creates pipeline position from legacy json and cleans json fields' do
      contact = create(
        :contact,
        account: account,
        custom_attributes: { 'sales_pipeline' => 'Lead' },
        additional_attributes: {
          'kanban' => {
            pipeline.id.to_s => {
              'deal' => { 'value' => 250 },
              'stage_tracking' => { 'current' => { 'entered_at' => '2024-01-01T10:00:00Z' } }
            }
          }
        }
      )

      position = described_class.import_from_json!(contact, pipeline)

      expect(position).to be_persisted
      expect(position.stage_id).to eq('Lead')
      expect(position.deal_value).to eq(250)

      contact.reload
      expect(contact.custom_attributes).not_to have_key('sales_pipeline')
      expect(contact.contact_pipeline_positions.find_by(pipeline_id: pipeline.id)).to eq(position)
    end

    it 'only cleans json when pipeline position already exists' do
      contact = create(
        :contact,
        account: account,
        custom_attributes: { 'sales_pipeline' => 'Legacy Stage' },
        additional_attributes: {
          'kanban' => { pipeline.id.to_s => { 'deal' => { 'value' => 10 } } }
        }
      )
      existing = create(
        :contact_pipeline_position,
        contact: contact,
        pipeline: pipeline,
        stage_id: 'Qualified'
      )

      result = described_class.import_from_json!(contact, pipeline)

      expect(result).to eq(existing)
      expect(existing.reload.stage_id).to eq('Qualified')
      expect(contact.reload.custom_attributes).not_to have_key('sales_pipeline')
    end
  end
end
