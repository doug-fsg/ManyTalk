# frozen_string_literal: true

class Public::FormsController < ActionController::Base
  def show
    @account = Account.find(params[:account_id])
    @account_form = @account.account_forms.find_by!(slug: params[:slug])
    unless @account_form.published? || @account_form.paused?
      render plain: I18n.t('account_forms.public.not_found', default: 'Formulário não encontrado.'), status: :not_found
      return
    end
    @global_config = GlobalConfig.get('LOGO_THUMBNAIL', 'BRAND_NAME', 'WIDGET_BRAND_URL', 'INSTALLATION_NAME')
  rescue ActiveRecord::RecordNotFound
    render plain: I18n.t('account_forms.public.not_found', default: 'Formulário não encontrado.'), status: :not_found
  end
end
