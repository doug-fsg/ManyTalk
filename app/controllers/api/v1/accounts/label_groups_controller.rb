class Api::V1::Accounts::LabelGroupsController < Api::V1::Accounts::BaseController
  before_action :current_account
  before_action :fetch_label_group, except: [:index, :create]
  before_action :check_authorization

  def index
    @label_groups = policy_scope(Current.account.label_groups)
  end

  def show; end

  def create
    @label_group = Current.account.label_groups.create!(permitted_params)
  end

  def update
    @label_group.update!(permitted_params)
  end

  def destroy
    @label_group.destroy!
    head :ok
  end

  private

  def fetch_label_group
    @label_group = Current.account.label_groups.find(params[:id])
  end

  def permitted_params
    params.require(:label_group).permit(:name, :position)
  end
end
