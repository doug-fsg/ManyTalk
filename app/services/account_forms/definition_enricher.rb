# frozen_string_literal: true

module AccountForms
  class DefinitionEnricher
    def self.call(account_form)
      new(account_form).call
    end

    def initialize(account_form)
      @account_form = account_form
    end

    def call
      definition = (@account_form.definition || {}).deep_dup
      fields = definition['fields'] || []
      return definition if fields.blank?

      attributes_by_key = @account_form.account.custom_attribute_definitions
                                       .where(attribute_model: :contact_attribute, is_kanban: false)
                                       .index_by(&:attribute_key)

      definition['fields'] = fields.map do |field|
        enrich_field(field, attributes_by_key)
      end

      definition
    end

    private

    def enrich_field(field, attributes_by_key)
      return field unless field['type'] == 'custom_attribute'

      attribute_key = field['attribute_key'].to_s
      return field if attribute_key.blank?

      attribute = attributes_by_key[attribute_key]
      return field unless attribute

      db_values = CustomAttributes::ValuesNormalizer.labels(attribute.attribute_values)
      saved_values = CustomAttributes::ValuesNormalizer.labels(field['attribute_values'])

      field.merge(
        'attribute_display_type' => attribute.attribute_display_type,
        'attribute_values' => db_values.presence || saved_values
      )
    end
  end
end
