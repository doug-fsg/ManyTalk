class CampaignPolicy < ApplicationPolicy
  def index?
    true  # Permite listar todas as campanhas para qualquer usuário autenticado
  end

  def show?
    true  # Permite visualizar qualquer campanha
  end

  def create?
    true  # Permite criar campanhas
  end

  def update?
    true  # Permite editar campanhas
  end

  def destroy?
    true  # Permite excluir campanhas
  end
end
