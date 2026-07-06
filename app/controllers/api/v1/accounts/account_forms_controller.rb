# frozen_string_literal: true

class Api::V1::Accounts::AccountFormsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_account_form, only: [:show, :update, :destroy, :update_status, :submissions, :export_submissions]

  def index
    @account_forms = Current.account.account_forms.ordered
    assign_linked_workflows(@account_forms.map(&:id))
  end

  def show
    assign_linked_workflows([@account_form.id])
  end

  def create
    @account_form = Current.account.account_forms.new(account_form_params)
    @account_form.created_by = current_user
    @account_form.updated_by = current_user
    @account_form.save!
  end

  def update
    @account_form.assign_attributes(account_form_params)
    @account_form.updated_by = current_user
    @account_form.save!
  end

  def destroy
    @account_form.destroy!
    head :ok
  end

  def update_status
    new_status = params.require(:status)
    unless AccountForm.statuses.key?(new_status)
      return render json: { error: 'invalid_status' }, status: :unprocessable_entity
    end

    @account_form.update!(status: new_status, updated_by: current_user)
    assign_linked_workflows([@account_form.id])
    render :show
  end

  def submissions
    @submissions = @account_form.form_submissions
                                .includes(:contact)
                                .order(created_at: :desc)
                                .page(submission_page)
                                .per(submission_per_page)
  end

  def export_submissions
    submissions = @account_form.form_submissions
                               .includes(:contact)
                               .order(created_at: :desc)

    csv_data = AccountForms::CsvExportService.new(@account_form, submissions).call
    send_data csv_data,
              filename: "form_#{@account_form.slug}_submissions_#{Date.today}.csv",
              type: 'text/csv; charset=utf-8',
              disposition: 'attachment'
  end

  private

  def fetch_account_form
    @account_form = Current.account.account_forms.find(params[:id])
  end

  def account_form_params
    permitted = params.permit(
      :name, :slug,
      branding: {},
      settings: {},
      definition: {
        fields: [:key, :type, :field, :label, :required, :attribute_key, :attribute_model, :attribute_display_type]
      }
    )

    if permitted[:definition].present?
      permitted[:definition] = AccountForms::DefinitionSanitizer.call(permitted[:definition])
    end

    if permitted[:branding].present?
      permitted[:branding] = sanitize_branding_params(permitted[:branding])
    end

    permitted
  end

  def sanitize_branding_params(incoming)
    base = @account_form&.branding.is_a?(Hash) ? @account_form.branding.stringify_keys : {}
    incoming_hash = if incoming.respond_to?(:to_unsafe_h)
                      incoming.to_unsafe_h
                    else
                      incoming.to_h
                    end
    merged = AccountForm::DEFAULT_BRANDING.merge(base).merge(incoming_hash.stringify_keys)
    AccountForms::BrandingSanitizer.call(merged)
  end

  def submission_page
    params[:page].presence || 1
  end

  def submission_per_page
    per = params[:per_page].to_i
    per = 25 if per <= 0
    [per, 100].min
  end

  def assign_linked_workflows(form_ids)
    @linked_workflows_by_form_id = AccountForms::LinkedWorkflowsResolver.build(
      account: Current.account,
      form_ids: form_ids
    )
  end
end
