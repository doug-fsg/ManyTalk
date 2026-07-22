# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Contacts::TimelineBuilder do
  subject(:result) { described_class.new(contact: contact, params: params).perform }

  let(:account) { create(:account) }
  let(:contact) { create(:contact, :with_email, account: account, name: 'Lead CRM') }
  let(:params) { {} }

  it 'includes contact creation event' do
    events = result[:events]
    created = events.find { |event| event[:type] == 'contact_created' }

    expect(created).to be_present
    expect(created[:meta][:contact_id]).to eq(contact.id)
  end

  it 'includes form submission events' do
    account_form = create(:account_form, :published, account: account, name: 'Landing Page')
    FormSubmission.create!(
      account: account,
      account_form: account_form,
      contact: contact,
      payload: { name: 'Lead' }
    )

    events = result[:events]
    submission = events.find { |event| event[:type] == 'form_submission' }

    expect(submission).to be_present
    expect(submission[:meta][:account_form_name]).to eq('Landing Page')
  end

  it 'includes pipeline and win/lost events' do
    position = create(:contact_pipeline_position, contact: contact, stage_id: 'Proposta')
    position.update!(
      metadata: {
        'win_lost' => {
          'status' => 'won',
          'date' => 1.day.ago.iso8601,
          'notes' => 'Fechou contrato'
        }
      },
      deal_value: 1500
    )

    events = result[:events]
    expect(events.any? { |event| event[:type] == 'pipeline_entered' }).to be(true)

    won = events.find { |event| event[:type] == 'deal_won' }
    expect(won).to be_present
    expect(won[:meta][:win_lost_notes]).to eq('Fechou contrato')
  end

  it 'includes persisted stage change history' do
    position = create(:contact_pipeline_position, contact: contact, stage_id: 'Proposta')
    position.update!(stage_id: 'Negociação', entered_at: Time.current)
    position.update!(stage_id: 'Fechado', entered_at: Time.current)

    events = result[:events]
    stage_changes = events.select { |event| event[:type] == 'pipeline_stage_changed' }

    expect(stage_changes.size).to eq(2)
    expect(stage_changes.map { |event| event[:meta][:to_stage_id] }).to include('Negociação', 'Fechado')
  end

  it 'includes notes and activities' do
    user = create(:user, account: account)
    create(:note, contact: contact, account: account, user: user, content: 'Cliente interessado')
    create(
      :activity,
      account: account,
      user: user,
      contact: contact,
      title: 'Ligar amanhã',
      scheduled_at: 1.hour.from_now
    )

    types = result[:events].pluck(:type)
    expect(types).to include('note', 'activity')
  end

  it 'uses completed_at for completed activities on the timeline' do
    user = create(:user, account: account)
    completed_at = 10.minutes.ago.change(usec: 0)
    activity = create(
      :activity,
      account: account,
      user: user,
      contact: contact,
      title: 'Follow up',
      scheduled_at: 2.days.from_now,
      status: 'completed',
      completed_at: completed_at
    )

    event = result[:events].find { |item| item[:id] == "activity_completed-#{activity.id}" }

    expect(event).to be_present
    expect(Time.zone.parse(event[:occurred_at])).to eq(completed_at)
    expect(event[:meta][:timeline_moment]).to eq('completed')
  end

  it 'includes activities linked only via pipeline position' do
    user = create(:user, account: account)
    position = create(:contact_pipeline_position, contact: contact)
    activity = create(
      :activity,
      account: account,
      user: user,
      contact: nil,
      contact_pipeline_position: position,
      title: 'Retornar ligação',
      scheduled_at: 1.hour.from_now
    )

    event = result[:events].find { |item| item[:id] == "activity-#{activity.id}" }

    expect(event).to be_present
    expect(event[:meta][:activity_id]).to eq(activity.id)
  end

  it 'filters by event type' do
    account_form = create(:account_form, :published, account: account)
    FormSubmission.create!(
      account: account,
      account_form: account_form,
      contact: contact,
      payload: { name: 'Lead' }
    )

    filtered = described_class.new(
      contact: contact,
      params: { types: ['form_submission'] }
    ).perform

    expect(filtered[:events].pluck(:type).uniq).to eq(['form_submission'])
  end

  it 'sorts events by occurred_at descending' do
    account_form = create(:account_form, :published, account: account)
    FormSubmission.create!(
      account: account,
      account_form: account_form,
      contact: contact,
      payload: { name: 'Old' },
      created_at: 2.days.ago
    )
    FormSubmission.create!(
      account: account,
      account_form: account_form,
      contact: contact,
      payload: { name: 'New' },
      created_at: 1.hour.ago
    )

    timestamps = result[:events].map { |event| Time.zone.parse(event[:occurred_at]) }
    expect(timestamps).to eq(timestamps.sort.reverse)
  end
end
