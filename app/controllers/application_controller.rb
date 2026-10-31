class ApplicationController < ActionController::Base
  include DeviseTokenAuth::Concerns::SetUserByToken
  include RequestExceptionHandler
  include Pundit::Authorization
  include SwitchLocale

  skip_before_action :verify_authenticity_token

  before_action :set_current_user, unless: :devise_controller?
  before_action :set_active_storage_url_options
  around_action :switch_locale
  around_action :handle_with_exception, unless: :devise_controller?

  private

  def set_current_user
    @user ||= current_user
    Current.user = @user
  end

  def set_active_storage_url_options
    ActiveStorageUrlHelper.assign_url_options_from_request!(request)
  end

  def pundit_user
    {
      user: Current.user,
      account: Current.account,
      account_user: Current.account_user
    }
  end
end
ApplicationController.include_mod_with('Concerns::ApplicationControllerConcern')
