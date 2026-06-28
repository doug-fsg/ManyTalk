# frozen_string_literal: true

module AccountForms
  class DefinitionValidator
    NATIVE_FIELDS = %w[name email phone_number].freeze
    MAX_FIELDS = 20

    attr_reader :errors

    def initialize(definition, account)
      @definition = definition || {}
      @account = account
      @errors = []
    end

    def valid?
      @errors = []
      fields = @definition.fetch('fields', [])

      if fields.blank?
        @errors << 'definition must have at least one field'
        return false
      end

      if fields.size > MAX_FIELDS
        @errors << "definition cannot have more than #{MAX_FIELDS} fields"
        return false
      end

      keys = []
      fields.each_with_index do |field, idx|
        prefix = "field[#{idx}]"
        key = field['key'].to_s.strip
        type = field['type'].to_s

        @errors << "#{prefix}: key is required" if key.blank?
        @errors << "#{prefix}: duplicate key '#{key}'" if keys.include?(key)
        keys << key

        case type
        when 'native'
          native_field = field['field'].to_s
          unless NATIVE_FIELDS.include?(native_field)
            @errors << "#{prefix}: unknown native field '#{native_field}'"
          end
        when 'custom_attribute'
          validate_custom_attribute(field, prefix)
        else
          @errors << "#{prefix}: unknown type '#{type}'" unless type.blank?
        end
      end

      @errors.empty?
    end

    private

    def validate_custom_attribute(field, prefix)
      attribute_key = field['attribute_key'].to_s.strip
      attribute_model = field['attribute_model'].to_s

      @errors << "#{prefix}: attribute_key is required for custom_attribute" if attribute_key.blank?
      return unless attribute_key.present?

      unless %w[contact_attribute conversation_attribute].include?(attribute_model)
        @errors << "#{prefix}: attribute_model must be contact_attribute or conversation_attribute"
        return
      end

      exists = @account.custom_attribute_definitions
                       .where(attribute_key: attribute_key, attribute_model: CustomAttributeDefinition.attribute_models[attribute_model])
                       .exists?

      @errors << "#{prefix}: custom attribute '#{attribute_key}' not found in account" unless exists
    end
  end
end
