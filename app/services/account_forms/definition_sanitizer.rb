# frozen_string_literal: true

module AccountForms
  class DefinitionSanitizer
    STRIPPED_FIELD_KEYS = %w[attribute_values].freeze

    def self.call(definition)
      new(definition).call
    end

    def initialize(definition)
      @definition = definition
    end

    def call
      return @definition unless @definition.is_a?(Hash)

      definition = @definition.deep_dup
      fields = definition['fields'] || definition[:fields]
      return definition unless fields.is_a?(Array)

      definition['fields'] = fields.map { |field| sanitize_field(field) }
      definition
    end

    private

    def sanitize_field(field)
      return field unless field.is_a?(Hash)

      normalized = field.stringify_keys.except(*STRIPPED_FIELD_KEYS)
      normalized['required'] = ActiveModel::Type::Boolean.new.cast(normalized['required'])
      normalized
    end
  end
end
