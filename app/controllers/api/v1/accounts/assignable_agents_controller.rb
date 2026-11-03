class Api::V1::Accounts::AssignableAgentsController < Api::V1::Accounts::BaseController
  before_action :fetch_inboxes

  def index
    agent_ids = @inboxes.map do |inbox|
      authorize inbox, :show?
      member_ids = inbox.members.pluck(:user_id)
      member_ids
    end
    agent_ids = agent_ids.inject(:&)
    agent_preloads = [:account_users, { avatar_attachment: [:blob] }]
    agents = Current.account.users.where(id: agent_ids).includes(*agent_preloads)
    administrators = Current.account.administrators.includes(*agent_preloads)
    @assignable_agents = (agents + administrators).uniq
  end

  private

  def fetch_inboxes
    @inboxes = Current.account.inboxes.find(permitted_params[:inbox_ids])
  end

  def permitted_params
    params.permit(inbox_ids: [])
  end
end
