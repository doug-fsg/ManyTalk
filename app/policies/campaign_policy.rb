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

  def progress?
    true  # Permite ver relatório de progresso
  end

  def retry_failed?
    true  # Permite reenviar contatos com falha
  end

  def pause?
    true  # Permite pausar campanha
  end

  def stop?
    true  # Permite parar campanha
  end

  def resume?
    true  # Permite retomar campanha pausada
  end

  def resend?
    true  # Permite reenviar campanha completa
  end
end
