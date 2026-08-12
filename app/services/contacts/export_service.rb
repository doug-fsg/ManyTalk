# frozen_string_literal: true

require 'csv'

class Contacts::ExportService
  UTF8_BOM = "\uFEFF"
  DIRECT_DOWNLOAD_LIMIT = 500
  DEFAULT_COLUMNS = %w[id name email phone_number].freeze

  def initialize(account:, account_user:, params: {}, column_names: nil)
    @account = account
    @account_user = account_user
    @params = (params || {}).with_indifferent_access
    @column_names = column_names
  end

  def count
    contacts.count
  end

  def direct_download?
    count <= DIRECT_DOWNLOAD_LIMIT
  end

  def export_mode
    direct_download? ? 'direct' : 'email'
  end

  def to_csv
    UTF8_BOM + CSV.generate(headers: true, encoding: 'UTF-8') do |csv|
      csv << csv_headers
      exportable_contacts.find_each do |contact|
        csv << build_row(contact)
      end
    end
  end

  def contacts
    @contacts ||= scoped_contacts
  end

  private

  # Pluck IDs first to avoid DISTINCT + find_each incompatibility with form joins.
  def exportable_contacts
    Contact.where(id: contacts.pluck(:id))
  end

  def scoped_contacts
    relation = if payload_present?
                 filter_result = ::Contacts::FilterService.new(@account, @account_user.user, @params).perform
                 filter_result[:contacts]
               elsif @params[:label].present?
                 @account.contacts.resolved_contacts.tagged_with(@params[:label], any: true)
               else
                 @account.contacts.resolved_contacts
               end

    apply_account_form_filter(relation)
  end

  def apply_account_form_filter(relation)
    form_id = @params[:account_form_id].to_i
    return relation if form_id.zero?

    relation
      .joins(:form_submissions)
      .where(form_submissions: { account_form_id: form_id })
      .distinct
  end

  def payload_present?
    @params[:payload].present? && @params[:payload].any?
  end

  def standard_headers
    @standard_headers ||= (Array(@column_names).presence || DEFAULT_COLUMNS) & Contact.column_names
  end

  def attribute_definitions
    @attribute_definitions ||= @account.custom_attribute_definitions
                                       .contact_attribute
                                       .non_kanban_attributes
                                       .order(:attribute_display_name, :id)
                                       .to_a
  end

  def attribute_headers
    @attribute_headers ||= begin
      used = standard_headers.to_set
      attribute_definitions.map do |definition|
        header = definition.attribute_display_name.presence || definition.attribute_key
        header = "#{header} (#{definition.attribute_key})" if used.include?(header)
        used << header
        header
      end
    end
  end

  def csv_headers
    standard_headers + attribute_headers
  end

  def build_row(contact)
    standard_values = standard_headers.map { |header| contact.public_send(header) }
    attribute_values = attribute_definitions.map do |definition|
      format_attribute_value(
        contact.custom_attributes&.dig(definition.attribute_key),
        definition
      )
    end
    standard_values + attribute_values
  end

  def format_attribute_value(value, definition)
    return '' if value.nil? || value == ''

    case definition.attribute_display_type
    when 'checkbox'
      ActiveModel::Type::Boolean.new.cast(value) ? 'true' : 'false'
    when 'list'
      Array(value).join(', ')
    when 'file'
      format_file_value(value)
    else
      value.is_a?(Array) ? value.join(', ') : value.to_s
    end
  end

  def format_file_value(value)
    case value
    when Hash
      value['filename'].presence || value['name'].presence || value['url'].presence || ''
    when Array
      value.map { |item| format_file_value(item) }.reject(&:blank?).join(', ')
    else
      value.to_s
    end
  end
end
