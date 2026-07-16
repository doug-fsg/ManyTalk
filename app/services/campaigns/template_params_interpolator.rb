# frozen_string_literal: true

class Campaigns::TemplateParamsInterpolator
  pattr_initialize [:campaign!, :conversation!, :contact_data!, :sender!]

  def perform
    params = campaign.trigger_rules['template_params']&.deep_dup
    return if params.blank?

    params = substitute_placeholders(params)
    interpolate_processed_params(params)
  end

  private

  def substitute_placeholders(value)
    case value
    when Hash
      value.transform_values { |entry| substitute_placeholders(entry) }
    when Array
      value.map { |entry| substitute_placeholders(entry) }
    when String
      substitute_campaign_variables(value)
    else
      value
    end
  end

  def substitute_campaign_variables(text)
    nome = contact_data['nome'].presence || contact_data['name'].presence || conversation.contact&.name.presence || ''
    variavel = contact_data['variavel'].presence || ''

    text.gsub(/@nome/i, nome.to_s).gsub(/@variavel/i, variavel.to_s)
  end

  def interpolate_processed_params(params)
    return params if params['processed_params'].blank?

    interpolator = Messages::LiquidInterpolatorService.new(
      conversation: conversation,
      sender: sender
    )
    params['processed_params'] = interpolator.interpolate_value(params['processed_params'])
    params
  end
end
