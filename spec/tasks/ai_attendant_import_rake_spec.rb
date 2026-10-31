# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'ai_attendant:import' do
  let(:account) { create(:account) }
  let(:json_path) { Rails.root.join('tmp/ai_attendant_import_spec.json') }
  let(:payload_one) do
    {
      'id' => 'many-ia-cfg-1',
      'inboxId' => 101,
      'nomeAtendenteDigital' => 'Lia'
    }
  end
  let(:payload_two) do
    {
      'id' => 'many-ia-cfg-2',
      'inboxId' => 102,
      'nomeAtendenteDigital' => 'Nina'
    }
  end
  let(:imported_config) do
    instance_double(AiAttendantConfig, id: 55, inbox_id: 101, many_ia_config_id: 'many-ia-cfg-1')
  end

  def invoke_import
    Rake::Task['ai_attendant:import'].reenable
    Rake::Task['ai_attendant:import'].invoke(account.id.to_s, json_path.to_s)
  end

  before(:all) do
    Rake.application.rake_require('tasks/ai_attendant_import', [Rails.root.join('lib').to_s])
    Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)
  end

  before do
    FileUtils.mkdir_p(File.dirname(json_path))
    allow(AiAttendant::ImportFromManyIa).to receive(:call).and_return(imported_config)
  end

  after do
    FileUtils.rm_f(json_path)
  end

  it 'calls ImportFromManyIa with the account and each payload from a JSON array' do
    File.write(json_path, JSON.generate([payload_one, payload_two]))

    expect { invoke_import }.not_to raise_error

    expect(AiAttendant::ImportFromManyIa).to have_received(:call).with(
      account: account,
      payload: payload_one
    )
    expect(AiAttendant::ImportFromManyIa).to have_received(:call).with(
      account: account,
      payload: payload_two
    )
  end

  it 'imports a single JSON object as one payload' do
    File.write(json_path, JSON.generate(payload_one))

    invoke_import

    expect(AiAttendant::ImportFromManyIa).to have_received(:call).once.with(
      account: account,
      payload: payload_one
    )
  end

  it 'continues remaining inboxes when one ImportFromManyIa call fails' do
    File.write(json_path, JSON.generate([payload_one, payload_two]))
    allow(AiAttendant::ImportFromManyIa).to receive(:call) do |account:, payload:|
      raise AiAttendant::ImportFromManyIa::Error, 'inboxId must belong to the account' if payload['id'] == 'many-ia-cfg-1'

      imported_config
    end

    expect { invoke_import }.to raise_error(SystemExit)

    expect(AiAttendant::ImportFromManyIa).to have_received(:call).with(
      account: account,
      payload: payload_one
    )
    expect(AiAttendant::ImportFromManyIa).to have_received(:call).with(
      account: account,
      payload: payload_two
    )
  end

end
