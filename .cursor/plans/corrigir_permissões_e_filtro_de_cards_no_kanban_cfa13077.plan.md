---
name: Corrigir permissões e filtro de cards no Kanban
overview: "Corrigir dois problemas: 1) Erro 403 ao arrastar cards (agentes sem permissão), 2) Agentes vendo todos os cards. Implementar filtro por dono e permissões corretas."
todos: []
---

# Corrigir Permissões e Filtro de Cards no Kanban

## Problemas Identificados

1. **Erro 403 ao arrastar**: Agentes sem permissão de edição não podem mover cards
2. **Ver todos os cards**: Agentes estão vendo cards que não são deles

## Regras Definidas

- **VIEWER**: Apenas visualizar (não pode mover, editar, nada)
- **EDITOR**: Mover e editar apenas cards deles + cards sem dono
- **VISIBILIDADE**: Ver apenas cards que são dele + cards sem dono
- **MOVER CARD PRÓPRIO**: Editor sempre pode mover seus próprios cards

## Implementação

### 1. Backend: Filtrar Cards por Dono

**Arquivo**: `app/controllers/api/v1/accounts/contacts_controller.rb`

- No método `fetch_contacts`, adicionar filtro por assignee
- Se não for admin, filtrar: `assignee_id = Current.user.id OR assignee_id IS NULL`
- Usar JOIN com `contact_pipeline_positions` e filtrar por `assignee_id`

**Implementação**:

```ruby
def fetch_contacts(contacts)
  contacts_with_avatar = filtrate(contacts)
                         .includes([{ avatar_attachment: [:blob] }])
                         .page(@current_page).per(RESULTS_PER_PAGE)

  contacts_with_avatar = contacts_with_avatar.includes(:contact_pipeline_positions)
  
  # Filtrar por assignee se não for admin
  unless Current.user.administrator?
    contacts_with_avatar = contacts_with_avatar
      .joins("LEFT JOIN contact_pipeline_positions ON contact_pipeline_positions.contact_id = contacts.id")
      .where("contact_pipeline_positions.assignee_id = ? OR contact_pipeline_positions.assignee_id IS NULL", Current.user.id)
      .distinct
  end
  
  return contacts_with_avatar.includes([{ contact_inboxes: [:inbox] }]) if @include_contact_inboxes

  contacts_with_avatar
end
```

### 2. Backend: Permitir Editor Mover Cards Próprios ou Sem Dono

**Arquivo**: `app/controllers/api/v1/accounts/contacts/pipeline_positions_controller.rb`

- Modificar `check_pipeline_edit_permission` para permitir editor mover cards próprios
- Se for editor, verificar se o card é dele ou não tem dono antes de bloquear

**Implementação**:

```ruby
def check_pipeline_edit_permission
  pipeline = Current.account.custom_attribute_definitions.find_by(
    id: params[:pipeline_id],
    is_kanban: true
  )
  
  return unless pipeline
  
  # Admin sempre pode
  return if Current.user.administrator?
  
  # Verificar permissão do pipeline
  permission = pipeline.user_permission(Current.user)
  
  # Viewer não pode editar
  if permission == :viewer
    render json: { 
      error: 'Você não tem permissão para editar este pipeline' 
    }, status: :forbidden
    return
  end
  
  # Editor pode editar, mas verificar se o card é dele ou sem dono
  if permission == :editor
    position = @contact.contact_pipeline_positions.find_by(
      pipeline_id: params[:pipeline_id]
    )
    
    # Se card tem dono e não é o editor, bloquear
    if position&.assignee_id.present? && position.assignee_id != Current.user.id
      render json: { 
        error: 'Você só pode editar cards que são seus ou que não têm dono' 
      }, status: :forbidden
      return
    end
  end
end
```

### 3. Backend: Garantir Assignee na Resposta

**Arquivo**: `app/controllers/api/v1/accounts/contacts/pipeline_positions_controller.rb`

- Garantir que `.includes(:assignee)` seja usado ao buscar position
- Sempre retornar assignee no JSON

**Mudança no método `update`**:

```ruby
def update
  position = @contact.contact_pipeline_positions
    .includes(:assignee)
    .find_or_initialize_by(pipeline_id: params[:pipeline_id])
  # ... resto do código
end
```

### 4. Frontend: Simplificar Atualização de Assignee

**Arquivo**: `app/javascript/dashboard/routes/dashboard/crm/components/KanbanAttributes.vue`

- Remover toda lógica complexa de preservação
- Usar apenas `response.data.assignee || null` em todos os lugares
- Se vier null da API, card fica sem dono (correto)

**Mudanças**:

- `onItemMoved`: usar `response.data.assignee || null`
- `updateCardPosition`: usar `response.data.assignee || null`
- `handleDealValueUpdate`: usar `response.data.assignee || null`
- Todos os outros métodos: mesma coisa

### 5. Frontend: Garantir Assignee no Backend Response

**Arquivo**: `app/controllers/api/v1/accounts/contacts/pipeline_positions_controller.rb`

- Adicionar `.includes(:assignee)` em todas as queries de position
- Garantir que assignee sempre venha carregado

## Ordem de Implementação

1. Backend: Filtrar cards por dono no `fetch_contacts`
2. Backend: Ajustar permissões para permitir editor mover cards próprios
3. Backend: Garantir assignee sempre carregado (includes)
4. Frontend: Simplificar uso de assignee (usar apenas response.data.assignee)

## Resultado Esperado

- Agentes veem apenas seus cards + cards sem dono
- Editor pode mover cards próprios + cards sem dono
- Viewer não pode mover nenhum card
- Assignee sempre aparece corretamente
- Não desaparece ao arrastar