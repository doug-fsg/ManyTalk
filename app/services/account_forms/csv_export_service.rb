# frozen_string_literal: true

require 'csv'

module AccountForms
  class CsvExportService
    def initialize(account_form, submissions)
      @account_form = account_form
      @submissions = submissions
    end

    def call
      fields = @account_form.definition.fetch('fields', [])
      native_keys = fields.select { |f| f['type'] == 'native' }.map { |f| f['field'] || f['key'] }
      custom_keys = fields.select { |f| f['type'] == 'custom_attribute' }.map { |f| f['key'] }

      all_payload_keys = (native_keys + custom_keys).uniq
      field_labels = fields.each_with_object({}) do |f, h|
        key = f['field'] || f['key']
        h[key] = f['label'] || key
      end

      CSV.generate(headers: true, encoding: 'UTF-8') do |csv|
        headers = ['ID', 'Data'] + all_payload_keys.map { |k| field_labels[k] || k } +
                  ['UTM Source', 'UTM Medium', 'UTM Campaign', 'Contato ID']
        csv << headers

        @submissions.each do |sub|
          row = [sub.id, sub.created_at.strftime('%Y-%m-%d %H:%M:%S')]
          all_payload_keys.each do |key|
            row << (sub.payload&.dig(key) || '')
          end
          utm = sub.utm || {}
          row += [utm['utm_source'], utm['utm_medium'], utm['utm_campaign']]
          row << (sub.contact_id || '')
          csv << row
        end
      end
    end
  end
end
