class Api::V1::Accounts::Actions::ContactMergesController < Api::V1::Accounts::BaseController
  before_action :set_base_contact, only: [:create]
  before_action :set_mergee_contact, only: [:create]

  rescue_from CustomExceptions::ContactMerge::InvalidMerge, with: :render_invalid_merge_error

  def create
    @base_contact = ContactMergeAction.new(
      account: Current.account,
      base_contact: @base_contact,
      mergee_contact: @mergee_contact
    ).perform
  end

  private

  def set_base_contact
    @base_contact = contacts.find(params[:base_contact_id])
  end

  def set_mergee_contact
    @mergee_contact = contacts.find(params[:mergee_contact_id])
  end

  def contacts
    @contacts ||= Current.account.contacts
  end

  def render_invalid_merge_error(exception)
    render json: { error: exception.message }, status: :unprocessable_entity
  end
end
