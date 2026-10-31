# frozen_string_literal: true

namespace :ai_attendant do
  desc 'Import many-ia JSON configs into AiAttendantConfig. Usage: rake ai_attendant:import[account_id,path.json]'
  task :import, [:account_id, :json_path] => :environment do |_task, args|
    abort 'account_id is required' if args[:account_id].blank?
    abort 'json_path is required' if args[:json_path].blank?

    path = Pathname.new(args[:json_path])
    path = Rails.root.join(path) unless path.absolute?
    abort "JSON file not found: #{path}" unless File.file?(path)

    account = Account.find_by(id: args[:account_id])
    abort "Account not found: #{args[:account_id]}" if account.blank?

    data = JSON.parse(File.read(path))
    payloads =
      case data
      when Array
        data
      when Hash
        data['configs'].is_a?(Array) ? data['configs'] : [data]
      else
        []
      end
    abort 'JSON must be an object or array of many-ia configs' if payloads.blank?

    failures = 0
    payloads.each do |payload|
      inbox_id = payload['inboxId']
      config = AiAttendant::ImportFromManyIa.call(account: account, payload: payload)
      puts "ok inbox_ids=#{config.inbox_ids.join(',')} many_ia_config_id=#{config.many_ia_config_id} config_id=#{config.id}"
    rescue AiAttendant::ImportFromManyIa::Error, ActiveRecord::RecordInvalid => e
      failures += 1
      puts "error inbox_id=#{inbox_id} #{e.message}"
    end

    abort "import finished with #{failures} failure(s)" if failures.positive?
    puts "import finished with #{payloads.size} success(es)"
  end
end
