# frozen_string_literal: true

module AccountForms
  class SubmitService
    pattr_initialize [:account_form!, :params!, { request_meta: {} }]

    def perform
      return failure('form_unavailable') unless account_form.published?

      validated = validate_payload
      return failure(validated[:error]) if validated[:error].present?

      contact = upsert_contact(validated[:data])
      return failure(contact[:error]) if contact[:error].present?

      submission = account_form.form_submissions.create!(
        account: account_form.account,
        contact: contact[:record],
        payload: validated[:data],
        utm: extract_utm,
        ip_address: request_meta[:ip_address],
        user_agent: request_meta[:user_agent]
      )

      dispatch_form_submitted_event(submission, contact[:record])

      Rails.logger.info(
        "[AccountForms] submitted form_id=#{account_form.id} submission_id=#{submission.id} " \
        "contact_id=#{contact[:record].id}"
      )

      { success: true, submission: submission, contact: contact[:record] }
    rescue ActiveRecord::RecordInvalid
      failure('submission_failed')
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
      dedup_key = account_form.settings['dedup_key'].presence || 'email'
      identifier = data[dedup_key]
      native_attrs = data.slice('name', 'email', 'phone_number').compact_blank

      if identifier.blank?
        contact = account.contacts.create!(**native_attrs)
        apply_custom_attributes(contact, data)
        return { record: contact }
      end

      contact = find_existing_contact(account, dedup_key, identifier)

      if contact.present?
        policy = account_form.settings['dedup_policy'].presence || 'update_existing'
        if policy == 'update_existing'
          contact.update!(
            name: native_attrs['name'].presence || contact.name,
            email: native_attrs['email'].presence || contact.email,
            phone_number: native_attrs['phone_number'].presence || contact.phone_number
          )
          apply_custom_attributes(contact, data)
        end
        return { record: contact }
      end

      contact = account.contacts.create!(**native_attrs)
      apply_custom_attributes(contact, data)
      { record: contact }
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

    def failure(error)
      { success: false, error: error }
    end
  end
end
