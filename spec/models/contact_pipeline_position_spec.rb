# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContactPipelinePosition, type: :model do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:pipeline) { create(:custom_attribute_definition, :kanban, account: account) }

  describe 'kanban stage changed webhook dispatch' do
    it 'dispatches contact.kanban_stage_changed when stage_id changes' do
      position = create(:contact_pipeline_position, contact: contact, pipeline: pipeline, stage_id: 'Estágio 1')

      expect(Rails.configuration.dispatcher).to receive(:dispatch).with(
        Events::Types::CONTACT_KANBAN_STAGE_CHANGED,
        kind_of(ActiveSupport::TimeWithZone),
        hash_including(
          contact: contact,
          pipeline_id: pipeline.id,
          stage_id: 'Estágio 2',
          previous_stage_id: 'Estágio 1'
        )
      ).once

      position.update!(stage_id: 'Estágio 2')
    end

    it 'does not dispatch when only position changes' do
      position = create(:contact_pipeline_position, contact: contact, pipeline: pipeline, stage_id: 'Estágio 1', position: 0)

      expect(Rails.configuration.dispatcher).not_to receive(:dispatch).with(
        Events::Types::CONTACT_KANBAN_STAGE_CHANGED,
        anything,
        anything
      )

      position.update!(position: 1)
    end

    it 'dispatches on create with nil previous_stage_id' do
      expect(Rails.configuration.dispatcher).to receive(:dispatch).with(
        Events::Types::CONTACT_KANBAN_STAGE_CHANGED,
        kind_of(ActiveSupport::TimeWithZone),
        hash_including(
          contact: contact,
          stage_id: 'Estágio 1',
          previous_stage_id: nil
        )
      ).once

      create(:contact_pipeline_position, contact: contact, pipeline: pipeline, stage_id: 'Estágio 1')
    end
  end
end
