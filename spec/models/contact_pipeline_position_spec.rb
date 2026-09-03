# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContactPipelinePosition, type: :model do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:pipeline) { create(:custom_attribute_definition, :kanban, account: account) }

  describe 'kanban stage changed webhook dispatch' do
    it 'dispatches contact.kanban_stage_changed when stage_id changes' do
      position = create(:contact_pipeline_position, contact: contact, pipeline: pipeline, stage_id: 'Estágio 1')
      allow(Rails.configuration.dispatcher).to receive(:dispatch).and_call_original

      position.update!(stage_id: 'Estágio 2')

      expect(Rails.configuration.dispatcher).to have_received(:dispatch).with(
        Events::Types::CONTACT_KANBAN_STAGE_CHANGED,
        kind_of(ActiveSupport::TimeWithZone),
        hash_including(
          contact: contact,
          pipeline_id: pipeline.id,
          stage_id: 'Estágio 2',
          previous_stage_id: 'Estágio 1'
        )
      ).once
    end

    it 'does not dispatch when only position changes' do
      position = create(:contact_pipeline_position, contact: contact, pipeline: pipeline, stage_id: 'Estágio 1', position: 0)
      allow(Rails.configuration.dispatcher).to receive(:dispatch).and_call_original

      position.update!(position: 1)

      expect(Rails.configuration.dispatcher).not_to have_received(:dispatch).with(
        Events::Types::CONTACT_KANBAN_STAGE_CHANGED,
        anything,
        anything
      )
    end

    it 'dispatches on create with nil previous_stage_id' do
      allow(Rails.configuration.dispatcher).to receive(:dispatch).and_call_original

      create(:contact_pipeline_position, contact: contact, pipeline: pipeline, stage_id: 'Estágio 1')

      expect(Rails.configuration.dispatcher).to have_received(:dispatch).with(
        Events::Types::CONTACT_KANBAN_STAGE_CHANGED,
        kind_of(ActiveSupport::TimeWithZone),
        hash_including(
          contact: contact,
          stage_id: 'Estágio 1',
          previous_stage_id: nil
        )
      ).once
    end

    it 'enqueues WebhookJob when the account webhook is subscribed' do
      webhook = create(:webhook, account: account, inbox: nil, subscriptions: ['contact_kanban_stage_changed'])
      position = create(:contact_pipeline_position, contact: contact, pipeline: pipeline, stage_id: 'Estágio 1')
      clear_enqueued_jobs

      expect do
        perform_enqueued_jobs(only: EventDispatcherJob) do
          position.update!(stage_id: 'Estágio 2')
        end
      end.to have_enqueued_job(WebhookJob).with(
        webhook.url,
        hash_including(
          event: 'contact_kanban_stage_changed',
          pipeline: hash_including(id: pipeline.id, name: pipeline.attribute_display_name),
          pipeline_position: hash_including(stage_id: 'Estágio 2', previous_stage_id: 'Estágio 1')
        )
      )
    end
  end
end
