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
    # Check if any filter is for a kanban attribute
    # If yes, LEFT JOIN with contact_pipeline_positions for better performance
    kanban_pipeline_ids = get_kanban_pipeline_ids_from_filters
    
    if kanban_pipeline_ids.any?
      # Construir FROM com JOINs usando SQL direto
      # Rails não aceita SQL string diretamente no joins, então usamos from
      joins_parts = kanban_pipeline_ids.each_with_index.map do |pipeline_id, index|
        alias_name = "cpp_#{index}"
        "LEFT OUTER JOIN contact_pipeline_positions AS #{alias_name} ON #{alias_name}.contact_id = contacts.id AND #{alias_name}.pipeline_id = #{pipeline_id}"
      end
      
      joins_clause = joins_parts.join(' ')
      
      # Usar from com SQL completo incluindo os JOINs
      @account.contacts.from("contacts #{joins_clause}")
    else
      @account.contacts
    end
  end

  def filter_config
    {
      entity: 'Contact',
      table_name: 'contacts'
    }
  end

  # Sobrescrever para usar contact_pipeline_positions quando for atributo kanban
  def build_custom_attr_query(query_hash, current_index)
    # Verificar se é um atributo kanban
    is_kanban = @custom_attribute&.is_kanban || false

    if is_kanban
      build_kanban_query(query_hash, current_index)
    else
      # Usar comportamento padrão (JSON) para atributos não-kanban
      super
    end
  end

  private

  # Constrói query usando a tabela contact_pipeline_positions para atributos kanban
  def build_kanban_query(query_hash, current_index)
    query_operator = query_hash[:query_operator] || ''
    pipeline_id = @custom_attribute.id
    
    # Encontrar o índice do LEFT JOIN para este pipeline
    kanban_pipeline_ids = get_kanban_pipeline_ids_from_filters
    join_index = kanban_pipeline_ids.index(pipeline_id)
    alias_name = "cpp_#{join_index}"

    # Usar apenas a tabela contact_pipeline_positions - sem fallback para JSON
    if query_hash[:filter_operator] == 'is_present'
      operator_suffix = query_operator.present? ? " #{query_operator} " : ' '
      # Contato está no pipeline apenas se existe registro na tabela
      return "(#{alias_name}.id IS NOT NULL)#{operator_suffix}"
    elsif query_hash[:filter_operator] == 'is_not_present'
      operator_suffix = query_operator.present? ? " #{query_operator} " : ' '
      # Contato NÃO está no pipeline apenas se não existe na tabela
      return "(#{alias_name}.id IS NULL)#{operator_suffix}"
    end

    # Para outros operadores (equal_to, not_equal_to, etc), usar stage_id da tabela
    filter_operator_value = filter_operation(query_hash, current_index)
    
    # Usar apenas dados da tabela - sem fallback
    "#{alias_name}.stage_id #{filter_operator_value} #{query_operator} "
  end

  # Retorna os IDs dos pipelines kanban que estão nos filtros
  def get_kanban_pipeline_ids_from_filters
    return [] unless @params[:payload]

    pipeline_ids = []
    @params[:payload].each do |query_hash|
      attribute_key = query_hash[:attribute_key]
      next if attribute_key.blank? || attribute_key == '_any_list'

      # Verificar se é um atributo kanban
      custom_attr = @account.custom_attribute_definitions
        .where(attribute_model: 'contact_attribute', attribute_key: attribute_key, is_kanban: true)
        .first

      pipeline_ids << custom_attr.id if custom_attr
    end

    pipeline_ids.uniq
  end

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
