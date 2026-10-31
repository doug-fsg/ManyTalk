# frozen_string_literal: true

class Api::V1::Accounts::AiUsageController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?

  def show
    render json: usage_payload
  end

  private

  def usage_payload
    limit = Current.account.ai_credit_limit
    used = Current.account.ai_credits_used.to_d
    remaining = limit.nil? ? nil : [limit.to_d - used, 0].max

    {
      limit: numeric_value(limit),
      used: numeric_value(used),
      remaining: numeric_value(remaining),
      paused: !PlatformAi::QuotaGuard.allow?(account: Current.account)
    }
  end

  def numeric_value(value)
    return if value.nil?

    decimal = value.to_d
    decimal == decimal.to_i ? decimal.to_i : decimal.to_f
  end
end
