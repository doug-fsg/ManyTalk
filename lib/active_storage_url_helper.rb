# frozen_string_literal: true

module ActiveStorageUrlHelper
  module_function

  def assign_url_options_from_request!(request)
    return if request.blank?

    ActiveStorage::Current.url_options = {
      protocol: request.protocol,
      host: request.host,
      port: request.optional_port
    }
  end

  def assign_default_url_options!
    return if ActiveStorage::Current.url_options.present?

    frontend = ENV['FRONTEND_URL'].to_s.strip
    if frontend.present?
      uri = URI.parse(frontend)
      ActiveStorage::Current.url_options = {
        protocol: uri.scheme,
        host: uri.host,
        port: uri.port == uri.default_port ? nil : uri.port
      }.compact
      return
    end

    defaults = Rails.application.routes.default_url_options
    return if defaults.blank?

    ActiveStorage::Current.url_options = defaults.dup
  end

  def url_for_attachment(attachment, only_path: false)
    assign_default_url_options!
    if only_path
      routes.polymorphic_path(attachment, only_path: true)
    else
      routes.polymorphic_url(attachment)
    end
  end

  def routes
    Rails.application.routes.url_helpers
  end
end
