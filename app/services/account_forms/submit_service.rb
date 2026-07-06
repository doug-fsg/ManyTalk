# frozen_string_literal: true

module AccountForms
  class SubmitService
    pattr_initialize [:account_form!, :params!, { request_meta: {} }]

    def perform
      return failure('form_unavailable') unless account_form.published?

      validated = validate_payload
      return failure(validated[:error]) if validated[:error].present?
      return failure('empty_submission') if validated[:data].blank?

      contact = upsert_contact(validated[:data])
      return failure(contact[:error]) if contact[:error].present?

      submission = create_submission(contact[:record], validated[:data])
      return failure(submission[:error]) if submission[:error].present?

      dispatch_form_submitted_event(submission[:record], contact[:record])

      Rails.logger.info(
        "[AccountForms] submitted form_id=#{account_form.id} submission_id=#{submission[:record].id} " \
        "contact_id=#{contact[:record].id}"
      )

      { success: true, submission: submission[:record], contact: contact[:record] }
    rescue ActiveRecord::RecordInvalid => e
      log_record_invalid(e)
      failure(map_record_invalid_error(e))
    end

    private

    def validate_payload
      data = {}
      account_form.definition.fetch('fields', []).each do |field|
        # For native fields the param key is the field name; for custom attrs it's the definition key
        param_key = field['type'] == 'custom_attribute' ? field['key'] : (field['field'] || field['key'])
        native_key = field['field'] || field['key']
        value = params[param_key]&.to_s&.strip || params[native_key]&.to_s&.strip
        required = field['required'] == true

        if required && value.blank?
          return { error: "missing_#{native_key}" }
        end

        next if value.blank?

        if native_key == 'email' && value !~ Devise.email_regexp
          return { error: 'invalid_email' }
        end

        if native_key == 'phone_number'
          normalized = Workflows::PhoneNormalizer.normalize(value)
          return { error: 'invalid_phone_number' } if normalized.blank?

          value = normalized
        end

        # Store by the field definition key for custom attrs, native key for native fields
        store_key = field['type'] == 'custom_attribute' ? field['key'] : native_key
        data[store_key] = value
      end

      { data: data }
    end

    def upsert_contact(data)
      account = account_form.account
      native_attrs = data.slice('name', 'email', 'phone_number').compact_blank
      policy = account_form.settings['dedup_policy'].presence || 'update_existing'

      contact = find_contact_for_submission(account, data)

      if contact.blank?
        created = create_contact(account, native_attrs)
        return created if created[:error].present?

        contact = created[:record]
      elsif policy == 'update_existing'
        updated = update_contact_attrs(contact, native_attrs, account)
        return updated if updated[:error].present?

        contact = updated[:record]
      end

      apply_custom_attributes(contact, data)
      { record: contact }
    end

    def find_contact_for_submission(account, data)
      dedup_key = account_form.settings['dedup_key'].presence || 'email'

      contact = find_existing_contact(account, dedup_key, data[dedup_key]) if data[dedup_key].present?
      contact ||= find_existing_contact(account, 'email', data['email']) if data['email'].present?
      contact ||= find_existing_contact(account, 'phone_number', data['phone_number']) if data['phone_number'].present?
      contact
    end

    def create_contact(account, native_attrs)
      { record: account.contacts.create!(**native_attrs) }
    rescue ActiveRecord::RecordInvalid => e
      recovered = recover_contact_from_duplicate(account, native_attrs, e.record)
      return recovered if recovered.present?

      { error: map_record_invalid_error(e) }
    end

    def recover_contact_from_duplicate(account, native_attrs, invalid_record)
      contact = nil
      if invalid_record.errors.of_kind?(:email, :taken) && native_attrs['email'].present?
        contact = find_existing_contact(account, 'email', native_attrs['email'])
      elsif invalid_record.errors.of_kind?(:phone_number, :taken) && native_attrs['phone_number'].present?
        contact = find_existing_contact(account, 'phone_number', native_attrs['phone_number'])
      end
      return nil if contact.blank?

      apply_recovered_contact_policy(contact, native_attrs, account)
    end

    def apply_recovered_contact_policy(contact, native_attrs, account)
      policy = account_form.settings['dedup_policy'].presence || 'update_existing'
      return { record: contact } unless policy == 'update_existing'

      updated = update_contact_attrs(contact, native_attrs, account)
      return updated if updated[:error].present?

      { record: updated[:record] }
    end

    def update_contact_attrs(contact, native_attrs, account)
      attrs = {}
      attrs[:name] = native_attrs['name'] if native_attrs['name'].present?
      attrs[:email] = native_attrs['email'] if native_attrs['email'].present? && !email_taken_by_other?(account, contact, native_attrs['email'])
      if native_attrs['phone_number'].present? && !phone_taken_by_other?(account, contact, native_attrs['phone_number'])
        attrs[:phone_number] = native_attrs['phone_number']
      end

      return { record: contact } if attrs.empty?

      unless contact.update(attrs)
        return { error: map_contact_errors(contact) }
      end

      { record: contact }
    end

    def email_taken_by_other?(account, contact, email)
      account.contacts.where.not(id: contact.id).exists?(['lower(email) = ?', email.downcase])
    end

    def phone_taken_by_other?(account, contact, phone_number)
      account.contacts.where.not(id: contact.id).exists?(phone_number: phone_number)
    end

    def create_submission(contact, data)
      submission = account_form.form_submissions.create!(
        account: account_form.account,
        contact: contact,
        payload: data,
        utm: extract_utm,
        ip_address: request_meta[:ip_address],
        user_agent: request_meta[:user_agent]
      )
      { record: submission }
    rescue ActiveRecord::RecordInvalid => e
      log_record_invalid(e)
      { error: 'submission_failed' }
    end

    def apply_custom_attributes(contact, data)
      custom_fields = account_form.definition.fetch('fields', []).select { |f| f['type'] == 'custom_attribute' }
      return if custom_fields.empty?

      attrs = {}
      custom_fields.each do |field|
        key = field['attribute_key']
        value = data[field['key']]
        attrs[key] = value if key.present? && value.present?
      end
      return if attrs.empty?

      contact.update!(custom_attributes: (contact.custom_attributes || {}).merge(attrs))
    end

    def find_existing_contact(account, dedup_key, identifier)
      case dedup_key
      when 'email'
        account.contacts.find_by('lower(email) = ?', identifier.downcase)
      when 'phone_number'
        account.contacts.find_by(phone_number: identifier)
      end
    end

    def extract_utm
      %w[utm_source utm_medium utm_campaign utm_term utm_content].index_with do |key|
        params[key].presence
      end.compact
    end

    def dispatch_form_submitted_event(submission, contact)
      Rails.configuration.dispatcher.dispatch(
        Events::Types::FORM_SUBMITTED,
        Time.current,
        account_form: account_form,
        submission: submission,
        contact: contact
      )
    rescue StandardError => e
      Rails.logger.error "[AccountForms] dispatch form_submitted failed: #{e.message}"
    end

    def map_contact_errors(contact)
      return 'invalid_email' if contact.errors.of_kind?(:email, :invalid)
      return 'invalid_phone_number' if contact.errors.of_kind?(:phone_number, :invalid)
      return 'email_already_used' if contact.errors.of_kind?(:email, :taken)
      return 'phone_already_used' if contact.errors.of_kind?(:phone_number, :taken)

      'submission_failed'
    end

    def map_record_invalid_error(exception)
      record = exception.record
      return map_contact_errors(record) if record.is_a?(Contact)

      'submission_failed'
    end

    def log_record_invalid(exception)
      record = exception.record
      details = record.errors.full_messages.join(', ')
      Rails.logger.error(
        "[AccountForms] submit failed form_id=#{account_form.id} " \
        "#{record.class.name} errors=#{details}"
      )
    end

    def failure(error)
      { success: false, error: error }
    end
  end
end
