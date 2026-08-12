# frozen_string_literal: true

require 'csv'

module AccountForms
  class CsvExportService
    UTF8_BOM = "\uFEFF".freeze

    def initialize(account_form, submissions)
      @account_form = account_form
      @submissions = submissions
    end

    def call
      UTF8_BOM + CSV.generate(headers: true, encoding: 'UTF-8') do |csv|
        csv << headers

        @submissions.each do |submission|
          csv << build_row(submission)
        end
      end
    end

    private

    def headers
      ['ID', 'Data'] + payload_keys.map { |key| field_labels[key] || key } +
        ['UTM Source', 'UTM Medium', 'UTM Campaign', 'Contato ID']
    end

    def build_row(submission)
      row = [submission.id, formatted_submission_time(submission)]
      payload_keys.each do |key|
        row << (submission.payload&.dig(key) || '')
      end
      utm = submission.utm || {}
      row + [utm['utm_source'], utm['utm_medium'], utm['utm_campaign'], submission.contact_id || '']
    end

    def formatted_submission_time(submission)
      submission.created_at.in_time_zone(account_timezone).strftime('%Y-%m-%d %H:%M:%S')
    end

    def account_timezone
      @account_form.account.custom_attributes&.dig('timezone').presence || 'UTC'
    end

    def payload_keys
      @payload_keys ||= begin
        fields = @account_form.definition.fetch('fields', [])
        native_keys = fields.select { |field| field['type'] == 'native' }.map { |field| field['field'] || field['key'] }
        custom_keys = fields.select { |field| field['type'] == 'custom_attribute' }.map { |field| field['key'] }
        (native_keys + custom_keys).uniq
      end
    end

    def field_labels
      @field_labels ||= @account_form.definition.fetch('fields', []).each_with_object({}) do |field, labels|
        key = field['field'] || field['key']
        labels[key] = field['label'] || key
      end
    end
  end
end
