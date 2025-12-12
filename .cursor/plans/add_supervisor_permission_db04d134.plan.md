---
name: Add Supervisor Permission
overview: Adicionar uma nova permissão "supervisor" no modal de edição de pipeline que permite que agentes tenham permissões de admin mesmo sendo agent.
todos: []
---

# Adicionar Filtro por Usuário no Kanban

## Objetivo

Adicionar um filtro por usuário (assignee) no Kanban que permite filtrar cards por responsável. O filtro será visível apenas para administradores e supervisores, aparecerá em um botão separado ao lado do botão de filtros existente, e permitirá selecionar múltiplos usuários incluindo a opção "Sem responsável".

## Arquivos a Modificar

### 1. Componente de Filtro por Usuário

**Arquivo**: [`app/javascript/dashboard/routes/dashboard/crm/components/KanbanAssigneeFilter.vue`](app/javascript/dashboard/routes/dashboard/crm/components/KanbanAssigneeFilter.vue) (NOVO)

- Criar novo componente que será um botão dropdown similar ao `KanbanFilters.vue`
- Usar `vue-multiselect` para permitir seleção múltipla de usuários
- Incluir opção especial "Sem responsável" (id: null ou 0)
- Mostrar badge com contador de usuários selecionados quando houver filtros ativos
- Usar `agents/getVerifiedAgents` do Vuex store para obter lista de agentes
- Estilização com Tailwind seguindo padrão do sistema

### 2. Componente Principal KanbanAttributes

**Arquivo**: [`app/javascript/dashboard/routes/dashboard/crm/components/KanbanAttributes.vue`](app/javascript/dashboard/routes/dashboard/crm/components/KanbanAttributes.vue)

- Importar e adicionar componente `KanbanAssigneeFilter` no template
- Adicionar prop `assigneeFilter` no data para armazenar IDs dos usuários selecionados
- Adicionar computed `showAssigneeFilter` que retorna `true` apenas se usuário for admin ou supervisor
- Adicionar método `handleAssigneeFilterChanged` para receber mudanças do filtro
- Modificar `filteredColumns` computed para incluir filtro por assignee:
  - Verificar se `assigneeFilter` tem valores
  - Para cada card, verificar se o `assignee.id` do `pipeline_positions` está na lista selecionada
  - Se "Sem responsável" estiver selecionado (null ou 0), incluir cards sem assignee
- Modificar `filteredContacts` computed para aplicar o mesmo filtro por assignee
- Garantir que o filtro funcione em conjunto com os outros filtros existentes (AND logic)

### 3. Traduções i18n

**Arquivos**:

- [`app/javascript/dashboard/i18n/locale/pt_BR/kanban.json`](app/javascript/dashboard/i18n/locale/pt_BR/kanban.json)
- [`app/javascript/dashboard/i18n/locale/en/kanban.json`](app/javascript/dashboard/i18n/locale/en/kanban.json)
- [`app/javascript/dashboard/i18n/locale/pt/kanban.json`](app/javascript/dashboard/i18n/locale/pt/kanban.json)
- [`app/javascript/dashboard/i18n/locale/es/kanban.json`](app/javascript/dashboard/i18n/locale/es/kanban.json)

- Adicionar chaves de tradução:
  - `KANBAN.ASSIGNEE_FILTER.TITLE`: "Filtrar por Responsável"
  - `KANBAN.ASSIGNEE_FILTER.PLACEHOLDER`: "Selecione responsáveis"
  - `KANBAN.ASSIGNEE_FILTER.NO_ASSIGNEE`: "Sem responsável"
  - `KANBAN.ASSIGNEE_FILTER.CLEAR`: "Limpar"

## Fluxo de Dados

```
KanbanAssigneeFilter (componente)
  ↓ (emite evento)
handleAssigneeFilterChanged (KanbanAttributes)
  ↓ (atualiza assigneeFilter)
filteredColumns / filteredContacts (computed)
  ↓ (aplica filtro)
Cards filtrados exibidos no Kanban
```

## Lógica de Filtro

O filtro deve verificar o `assignee.id` do `pipeline_positions` de cada contato:

1. Se nenhum usuário selecionado: mostrar todos os cards
2. Se usuários selecionados: mostrar apenas cards onde `position.assignee?.id` está na lista selecionada
3. Se "Sem responsável" selecionado: incluir cards onde `position.assignee` é `null` ou `undefined`
4. Combinar com outros filtros usando lógica AND

## Verificação de Permissão

- Usar computed `isAdmin` existente que já verifica admin global e supervisor do pipeline
- Componente `KanbanAssigneeFilter` só será renderizado se `showAssigneeFilter === true`

## UX Considerations

- Botão com ícone de usuário/pessoa ao lado do botão de filtros
- Badge com número de usuários selecionados quando filtro está ativo
- Dropdown com multiselect para fácil seleção múltipla
- Opção "Sem responsável" claramente identificada
- Botão "Limpar" para remover filtro rapidamente
- Filtro aplica em tempo real (sem necessidade de botão "Aplicar")
- Visual consistente com outros componentes do sistema