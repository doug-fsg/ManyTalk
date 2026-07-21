# frozen_string_literal: true

class Api::V1::Accounts::Contacts::TimelineController < Api::V1::Accounts::Contacts::BaseController
  def index
    authorize @contact, :show?

    @result = Contacts::TimelineBuilder.new(
      contact: @contact,
      params: timeline_params
    ).perform
  end

  private

  def timeline_params
    params.permit(:page, :per_page, types: [])
  end
end
