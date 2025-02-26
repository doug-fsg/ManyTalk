class Api::V1::Accounts::CampaignsController < Api::V1::Accounts::BaseController
  before_action :campaign, except: [:index, :create]
  before_action :check_authorization

  def index
    @campaigns = Current.account.campaigns
  end

  def show; end

  def create
    @campaign = Current.account.campaigns.create!(campaign_params)
  end

  def update
    @campaign = Current.account.campaigns.find_by(display_id: params[:id])
    
    # Separe os parâmetros de audience
    filtered_params = campaign_params.except(:audience)
    
    # Tente atualizar sem audience primeiro
    if @campaign.update(filtered_params)
      # Se audience estiver presente, atualize separadamente
      if campaign_params[:audience].present?
        # Converte para o formato correto
        formatted_audience = campaign_params[:audience].map do |item|
          {
            id: item[:id],
            type: item[:type]
          }
        end
        
        # Use JSON.parse e JSON.generate para garantir o formato correto
        parsed_audience = JSON.parse(JSON.generate(formatted_audience))
        @campaign.update_column(:audience, parsed_audience)
      end
      
      render json: @campaign
    else
      render json: { errors: @campaign.errors }, status: :unprocessable_entity
    end
  rescue => e
    render json: { errors: e.message }, status: :unprocessable_entity
  end

  def destroy
    @campaign.destroy!
    head :ok
  end

  private

  def campaign
    @campaign ||= Current.account.campaigns.find_by(display_id: params[:id])
  end

  def campaign_params
    params.require(:campaign).permit(:title, :description, :message, :enabled, :trigger_only_during_business_hours, :inbox_id, :sender_id,
                                     :scheduled_at, :campaign_status, audience: [:type, :id, :nome, :variavel], trigger_rules: {})
  end
end
