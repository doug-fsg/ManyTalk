class Contacts::FilterService < FilterService
  ATTRIBUTE_MODEL = 'contact_attribute'.freeze

  def initialize(account, user, params)
    @account = account
    # TODO: Change the order of arguments in FilterService maybe?
    # account, user, params makes more sense
    super(params, user)
  end

  def perform
    @contacts = query_builder(@filters['contacts'])

    {
      contacts: @contacts,
      count: @contacts.count
    }
  end

  def query_builder(model_filters)
    @params[:payload].each_with_index do |query_hash, current_index|
      if query_hash[:attribute_key] == '_any_list'
        @query_string += " #{build_any_list_query(query_hash, current_index).strip}"
      else
        @query_string += " #{build_condition_query(model_filters, query_hash, current_index).strip}"
      end
    end
    # This removes a dangling AND/OR at the end of the query string.
    @query_string.strip!.gsub!(/\s+(AND|OR)$/i, '')

    # Filtrar @filter_values para incluir apenas valores que são referenciados no SQL
    # Isso evita erros quando retornamos SQL direto (sem bind variables) para alguns filtros
    used_values = @filter_values.select do |key, _value|
      @query_string.include?(":#{key}")
    end

    # Se não há bind variables, passar query diretamente sem hash de valores
    # Isso evita que o ActiveRecord tente fazer bind de jsonb_exists (operador PostgreSQL)
    if used_values.empty?
      base_relation.where(@query_string)
    else
      base_relation.where(@query_string, used_values.with_indifferent_access)
    end
  end

  def filter_values(query_hash)
    current_val = query_hash['values'][0]
    if query_hash['attribute_key'] == 'phone_number'
      "+#{current_val}"
    elsif query_hash['attribute_key'] == 'country_code'
      current_val.downcase
    else
      current_val.is_a?(String) ? current_val.downcase : current_val
    end
  end

  # TODO: @account.contacts.resolved_contacts ? to stay consistant with the behavior in ui
  def base_relation
    @account.contacts
  end

  def filter_config
    {
      entity: 'Contact',
      table_name: 'contacts'
    }
  end

  private

  def equals_to_filter_string(filter_operator, current_index)
    return "= :value_#{current_index}" if filter_operator == 'equal_to'

    "!= :value_#{current_index}"
  end

  def build_any_list_query(query_hash, _current_index)
    list_attribute_keys = @account.custom_attribute_definitions.where(
      attribute_model: 'contact_attribute',
      attribute_display_type: 'list'
    ).pluck(:attribute_key)

    return '1=0' if list_attribute_keys.empty?

    operator = query_hash[:filter_operator]
    query_operator = query_hash[:query_operator] || 'AND'

    query_fragment = if operator == 'is_present'
                       # Otimização: usar jsonb_exists() para melhor performance com índice GIN
                       # jsonb_exists() é equivalente ao operador ? mas evita conflitos com bind variables
                       key_conditions = list_attribute_keys.map do |key|
                         escaped_key = ActiveRecord::Base.connection.quote_string(key)
                         "(jsonb_exists(contacts.custom_attributes, '#{escaped_key}') AND contacts.custom_attributes->>'#{escaped_key}' != '')"
                       end
                       " (#{key_conditions.join(' OR ')}) "
                     elsif operator == 'is_not_present'
                       # Otimização: usar jsonb_exists() para melhor performance
                       key_conditions = list_attribute_keys.map do |key|
                         escaped_key = ActiveRecord::Base.connection.quote_string(key)
                         "(NOT jsonb_exists(contacts.custom_attributes, '#{escaped_key}') OR contacts.custom_attributes->>'#{escaped_key}' = '' OR contacts.custom_attributes->>'#{escaped_key}' IS NULL)"
                       end
                       " (#{key_conditions.join(' AND ')}) "
                     else
                       raise CustomExceptions::CustomFilter::InvalidOperator, "Operator '#{operator}' not supported for _any_list"
                     end

    "#{query_fragment} #{query_operator}"
  end
end
