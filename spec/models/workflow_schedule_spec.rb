# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkflowSchedule do
  let(:account) { create(:account) }
  let(:workflow) { create(:workflow, account: account, active: true) }
  let(:pipeline) { create(:custom_attribute_definition, :kanban, account: account) }

  def build_schedule(**attrs)
    build(
      :workflow_schedule,
      account: account,
      workflow: workflow,
      pipeline: pipeline,
      **attrs
    )
  end

  describe 'validations' do
    it 'is valid with weekly CRM targeting defaults' do
      expect(build_schedule).to be_valid
    end

    it 'requires a name' do
      schedule = build_schedule(name: '')
      expect(schedule).not_to be_valid
      expect(schedule.errors[:name]).to be_present
    end

    it 'rejects a weekday outside 0-6' do
      schedule = build_schedule(weekday: 7)
      expect(schedule).not_to be_valid
      expect(schedule.errors[:weekday]).to be_present
    end

    it 'rejects an hour outside 0-23' do
      schedule = build_schedule(hour: 24)
      expect(schedule).not_to be_valid
    end

    it 'rejects a pipeline from another account' do
      other = create(:custom_attribute_definition, :kanban)
      schedule = build_schedule(pipeline: other)
      expect(schedule).not_to be_valid
      expect(schedule.errors[:pipeline_id]).to be_present
    end

    it 'rejects a stage that is not in the pipeline' do
      schedule = build_schedule(stage_id: 'Inexistente')
      expect(schedule).not_to be_valid
      expect(schedule.errors[:stage_id]).to be_present
    end

    it 'accepts a stage from nested kanban pipeline values' do
      pipeline.update!(
        attribute_values: {
          'stages' => {
            'Novo' => { 'color' => '#6554C0' },
            'Proposta' => { 'color' => '#0442C2' }
          },
          'permissions' => {},
          'stage_order' => %w[Novo Proposta]
        }
      )
      schedule = build_schedule(stage_id: 'Proposta')
      expect(schedule).to be_valid
    end

    it 'rejects activating when the workflow is inactive' do
      workflow.update!(active: false)
      schedule = build_schedule(active: true)
      expect(schedule).not_to be_valid
      expect(schedule.errors[:workflow_id]).to be_present
    end

    it 'caps the number of schedules per account' do
      stub_const('WorkflowSchedule::MAX_PER_ACCOUNT', 1)
      create(:workflow_schedule, account: account, workflow: workflow, pipeline: pipeline)
      schedule = build_schedule
      expect(schedule).not_to be_valid
      expect(schedule.errors[:account_id]).to be_present
    end
  end

  describe '#compute_next_run_at' do
    it 'returns the next Wednesday 09:00 in the schedule timezone' do
      travel_to Time.utc(2026, 10, 5, 12, 0, 0) do
        schedule = build_schedule(weekday: 3, hour: 9, minute: 0, time_zone: 'America/Sao_Paulo')
        next_run = schedule.compute_next_run_at(from: Time.current)
        local = next_run.in_time_zone('America/Sao_Paulo')

        expect(local.wday).to eq(3)
        expect(local.hour).to eq(9)
        expect(local.min).to eq(0)
        expect(local.to_date).to eq(Date.new(2026, 10, 7))
      end
    end

    it 'skips the current slot when it already started' do
      travel_to Time.find_zone('America/Sao_Paulo').local(2026, 10, 7, 9, 1, 0) do
        schedule = build_schedule(weekday: 3, hour: 9, minute: 0, time_zone: 'America/Sao_Paulo')
        next_run = schedule.compute_next_run_at(from: Time.current)
        expect(next_run.in_time_zone('America/Sao_Paulo').to_date).to eq(Date.new(2026, 10, 14))
      end
    end
  end

  describe '.claim_due!' do
    it 'claims due active schedules and advances next_run_at' do
      due = create(
        :workflow_schedule,
        account: account,
        workflow: workflow,
        pipeline: pipeline,
        active: true,
        next_run_at: 1.minute.ago,
        run_token: 1
      )
      create(
        :workflow_schedule,
        account: account,
        workflow: workflow,
        pipeline: pipeline,
        active: true,
        next_run_at: 1.hour.from_now
      )

      claimed = described_class.claim_due!(now: Time.current, limit: 10)

      expect(claimed.map(&:id)).to eq([due.id])
      due.reload
      expect(due.run_token).to eq(2)
      expect(due.last_run_status).to eq('running')
      expect(due.next_run_at).to be > Time.current
    end

    it 'deactivates a one-off schedule after claiming it' do
      due = create(
        :workflow_schedule,
        account: account,
        workflow: workflow,
        pipeline: pipeline,
        recurring: false,
        weekday: nil,
        active: true,
        next_run_at: 1.minute.ago
      )

      described_class.claim_due!(now: Time.current, limit: 10)
      due.reload
      expect(due.active).to be(false)
      expect(due.last_run_status).to eq('running')
    end

    it 'does not claim inactive schedules' do
      create(
        :workflow_schedule,
        account: account,
        workflow: workflow,
        pipeline: pipeline,
        active: false,
        next_run_at: 1.minute.ago
      )

      expect(described_class.claim_due!(now: Time.current)).to be_empty
    end
  end
end
