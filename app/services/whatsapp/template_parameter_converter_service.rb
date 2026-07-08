# Service to convert legacy WhatsApp template parameter formats to enhanced format
class Whatsapp::TemplateParameterConverterService
  def initialize(template_params, template)
    @template_params = template_params
    @template = template
  end

  def normalize_to_enhanced
    processed_params = @template_params['processed_params']

    return @template_params if enhanced_format?(processed_params)

    @template_params['format_version'] = 'legacy'
    enhanced_params = convert_legacy_to_enhanced(processed_params, @template)
    @template_params['processed_params'] = enhanced_params

    @template_params
  end

  private

  def enhanced_format?(processed_params)
    return false unless processed_params.is_a?(Hash)

    component_keys = %w[body header footer buttons]
    has_component_structure = processed_params.keys.any? { |k| component_keys.include?(k) }

    if has_component_structure
      validate_enhanced_structure(processed_params)
    else
      false
    end
  end

  def validate_enhanced_structure(params)
    valid_body?(params['body']) &&
      valid_header?(params['header']) &&
      valid_buttons?(params['buttons'])
  end

  def valid_body?(body)
    body.nil? || body.is_a?(Hash)
  end

  def valid_header?(header)
    header.nil? || header.is_a?(Hash)
  end

  def valid_buttons?(buttons)
    return true if buttons.nil?
    return false unless buttons.is_a?(Array)

    buttons.all? { |b| b.is_a?(Hash) && b['type'] }
  end

  def convert_legacy_to_enhanced(legacy_params, _template)
    enhanced = {}

    case legacy_params
    when Array
      body_params = convert_array_to_body_params(legacy_params)
      enhanced['body'] = body_params unless body_params.empty?
    when Hash
      body_params = convert_hash_to_body_params(legacy_params)
      enhanced['body'] = body_params unless body_params.empty?
    when NilClass
      # Templates without parameters
    else
      raise ArgumentError, "Unknown legacy format: #{legacy_params.class}"
    end

    enhanced
  end

  def convert_array_to_body_params(params_array)
    return {} if params_array.empty?

    body_params = {}
    params_array.each_with_index do |value, index|
      body_params[(index + 1).to_s] = value.to_s
    end

    body_params
  end

  def convert_hash_to_body_params(params_hash)
    return {} if params_hash.empty?

    body_params = {}
    params_hash.each do |key, value|
      body_params[key.to_s] = value.to_s
    end

    body_params
  end
end
