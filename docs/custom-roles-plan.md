# Plano de Custom Roles — Níveis de Acesso

> Fork Manytalks ~3.9.0 · Referência read-only: `chatwoot-develop` ~4.9.1

Documento guia para implementação de funções personalizadas (custom roles) e permissões granulares. **Não é um plano de merge** — o develop serve apenas como referência de padrões; o cenário real do Manytalks diverge em vários pontos.

---

## Objetivo

Permitir que administradores criem **funções personalizadas** com permissões granulares, atribuídas a agentes, sem quebrar o modelo atual de `administrator` / `agent` nem as customizações do fork (WhatsApp, workflows, Kanban, etc.).

### Princípios

1. **Conservador** — feature flag off por padrão; rollout por conta
2. **Sem merge** — portar comportamento, não diff do upstream
3. **Backward compatible** — agente sem custom role = comportamento atual
4. **Administrator imutável** — admin continua com acesso total; custom role só se aplica a `agent`
5. **Backend é fonte da verdade** — frontend esconde menus, mas API deve bloquear

---

## Estado atual do fork

| Item | Status | Observação |
|------|--------|------------|
| Tabela `custom_roles` | ✅ Existe | `name`, `description`, `account_id`, `permissions[]` |
| Coluna `account_users.custom_role_id` | ✅ Existe | FK opcional |
| Model `CustomRole` | ❌ Ausente | Só schema |
| `AccountUser#permissions` | ⚠️ Parcial | Retorna só `['administrator']` ou `['agent']` |
| API CRUD custom roles | ❌ Ausente | — |
| UI de gestão de roles | ❌ Ausente | — |
| `Policy.vue` + `permissionsHelper.js` | ✅ Prontos | Infra frontend existe |
| Rotas com `report_manage` | ✅ Parcial | `reports.routes.js` já referencia; backend não honra |
| `ReportPolicy#view?` | ❌ Só admin | Bypass em `ReportsController` também |
| Feature flag `custom_roles` | ❌ Ausente | — |
| Padrão Enterprise (`include_mod_with`) | ✅ Ativo | Usado em Account, User, Conversation, etc. |

### Lacuna crítica hoje

O frontend de reports já declara `permissions: ['administrator', 'report_manage']`, mas:

- `AccountUser#permissions` nunca retorna `report_manage`
- `ReportPolicy` e `Api::V2::Accounts::ReportsController` checam só `administrator?`

Resultado: a permissão existe no contrato do frontend, mas não funciona de ponta a ponta.

---

## Relação com o `chatwoot-develop`

O develop **não é spec** — é referência para entender intenção e padrões. Divergências importantes:

### O que usar como referência

| Padrão upstream | Aplicável ao fork |
|-----------------|-------------------|
| Custom role como permissões sobre agente (não novo enum `role`) | ✅ Sim |
| `AccountUser#permissions` retorna permissões da role + `'custom_role'` | ✅ Sim |
| Extensão via `enterprise/` + `include_mod_with` / `prepend_mod_with` | ✅ Sim |
| CRUD de custom roles (admin only) | ✅ Sim |
| 6 permissões base (conversas, contatos, reports, KB) | ✅ Sim, como v1 |
| Feature flag `custom_roles` | ✅ Sim |

### O que **não** portar do develop

| Item upstream | Motivo para não portar |
|---------------|------------------------|
| UI Vue 3 / `components-next` | Fork usa Vue 2 + Options API |
| `FilteredCountInvalidator` / unread counts por permissão | Complexidade desnecessária na v1; fork 3.9 não tem equivalente |
| SAML role mappings | Não é cenário atual |
| Captain / Copilot conversation access | Feature não presente no fork |
| `AssignmentPolicy` / capacity policies | Não existe no fork |
| Store Pinia / composables Vue 3 | Incompatível com stack atual |
| i18n de 40+ locales | Só `pt_BR` + `en` na v1 |
| Policies de contato restritivas (CRUD) | Fork já trata contatos de forma mais aberta; restringir só o que já é admin |

### O que o Manytalks tem e o develop **não** cobre

| Área Manytalks | Permissão candidata (fase futura) | Situação atual |
|----------------|-----------------------------------|----------------|
| Workflows | `workflow_manage` | Qualquer membro da conta edita (`WorkflowPolicy`) |
| Automações + Forms hub | `automation_manage` | Rotas liberadas para `administrator` + `agent` |
| Kanban / CRM | `crm_manage` | Permissões por funil em `custom_attribute_definition`; admin-only para criar pipeline |
| WhatsApp (templates, coexistência) | `channel_whatsapp_manage` | Admin-only em vários pontos |
| Inteligência artificial | `ia_manage` | Feature flag própria |
| Audit logs | `audit_logs_view` | Premium, admin-only |
| Configurações de conta | `settings_manage` | Admin-only |
| Integrações / webhooks | `integration_manage` | Admin-only |
| Agentes / teams | `agent_manage` | Admin-only (correto manter) |

---

## Modelo de autorização

### Hierarquia

```
administrator          → acesso total (ignora custom_role_id)
agent                  → comportamento atual de agente
agent + custom_role    → permissões granulares da role
```

### Regras de negócio

- `custom_role_id` só é válido quando `role == 'agent'`
- Ao promover agente para `administrator`, limpar `custom_role_id`
- Destroy de custom role → `nullify` em `account_users.custom_role_id`
- Feature flag off → API rejeita operações; comportamento idêntico ao atual
- Permissões desconhecidas são rejeitadas na validação do model

### Fluxo de permissões no login

```
AccountUser#permissions
  ├── administrator? → ['administrator']
  ├── agent? + custom_role → custom_role.permissions + ['custom_role']
  └── agent? sem custom_role → ['agent']
```

Serializado em `app/views/api/v1/models/_user.json.jbuilder` → consumido pelo frontend via `user.permissions`.

---

## Vocabulário de permissões

### Fase 1 — Permissões base (referência upstream)

Alinhadas com `CustomRole::PERMISSIONS` do develop. São o **MVP** — já cobrem a maioria dos casos de supervisor/gerente.

| Permissão | Escopo | Policies / rotas afetadas |
|-----------|--------|---------------------------|
| `conversation_manage` | Todas as conversas da conta | `ConversationPolicy`, `ConversationFinder` |
| `conversation_unassigned_manage` | Não atribuídas + próprias | idem |
| `conversation_participating_manage` | Atribuídas a si + participante | idem |
| `contact_manage` | Import, export, destroy de contatos | `ContactPolicy` |
| `report_manage` | Relatórios, CSAT, métricas | `ReportPolicy`, `CsatSurveyResponsePolicy`, `ReportsController` |
| `knowledge_base_manage` | Portals, articles, categories | `PortalPolicy`, `ArticlePolicy`, `CategoryPolicy` |

### Fase 2+ — Permissões Manytalks (não existem no develop)

Definir conforme necessidade de negócio. **Não implementar no MVP** — documentar aqui para evolução controlada.

| Permissão | Escopo sugerido | Prioridade | Notas |
|-----------|-----------------|------------|-------|
| `workflow_manage` | CRUD workflows, dry-run, templates | Alta | Hoje qualquer agente edita; risco operacional |
| `automation_manage` | Regras de automação legacy | Média | Separar de workflows se fizer sentido |
| `form_manage` | Formulários no hub de automação | Média | Pode unificar com `automation_manage` |
| `crm_manage` | Pipelines Kanban globais | Média | Complementa permissões por funil (ver abaixo) |
| `channel_whatsapp_manage` | Templates enhanced, config canal | Baixa | Manter admin-only até demanda clara |
| `ia_manage` | Config IA / response bot | Baixa | Já tem feature flag `inteligencia_artificial` |
| `audit_logs_view` | Visualizar audit logs | Baixa | Premium |
| `settings_manage` | Config geral da conta | Baixa | Equivalente parcial a admin |
| `integration_manage` | Webhooks, apps, OAuth | Baixa | Manter admin-only na v1 |
| `campaign_manage` | Campanhas | Média | Hoje agente acessa algumas rotas |
| `macro_manage` | Macros globais | Baixa | MacroPolicy já tem lógica de autor |

### Permissões já existentes fora do sistema de roles

**Kanban por funil** — `custom_attribute_definition.attribute_values['permissions']` define editor/viewer por pipeline. Isso é **complementar**, não substituível por custom role global. Um agente pode ter `crm_manage` (criar pipelines) mas ser `viewer` em funil específico.

---

## Arquitetura técnica

### Backend (Rails conventions)

```
enterprise/
├── app/
│   ├── models/
│   │   ├── custom_role.rb
│   │   └── enterprise/
│   │       ├── account_user.rb              # override #permissions
│   │       └── concerns/
│   │           ├── account_user.rb          # belongs_to :custom_role
│   │           └── account.rb               # has_many :custom_roles
│   ├── controllers/api/v1/accounts/
│   │   └── custom_roles_controller.rb
│   ├── policies/
│   │   ├── custom_role_policy.rb
│   │   └── enterprise/
│   │       ├── report_policy.rb             # prepend_mod_with
│   │       ├── contact_policy.rb
│   │       ├── portal_policy.rb
│   │       ├── article_policy.rb
│   │       ├── category_policy.rb
│   │       └── conversation_policy.rb       # fase 4
│   └── views/api/v1/
│       ├── models/_custom_role.json.jbuilder
│       └── accounts/custom_roles/
```

Registros nos arquivos base:

```ruby
# app/models/account_user.rb
AccountUser.include_mod_with('Concerns::AccountUser')
AccountUser.include_mod_with('AccountUser')

# app/policies/report_policy.rb
ReportPolicy.prepend_mod_with('ReportPolicy')
```

### Frontend (Vue 2)

```
app/javascript/dashboard/
├── constants/permissions.js       # novo
├── api/customRole.js              # novo
├── store/modules/customRoles.js   # novo
├── routes/dashboard/settings/customRoles/
│   ├── customRoles.routes.js
│   ├── Index.vue
│   └── CustomRoleForm.vue
└── i18n/locale/{pt_BR,en}/customRole.json
```

Adaptar (não reescrever):

- `settings/agents/EditAgent.vue` — dropdown custom role
- `settings/agents/AddAgent.vue` — idem
- `components/layout/config/sidebarItems/settings.js` — item "Funções"
- `featureFlags.js` — `CUSTOM_ROLES: 'custom_roles'`

---

## Inventário de bypasses (autorização fora do Pundit)

Pontos que checam `administrator?` diretamente e precisam revisão nas fases 2+:

| Arquivo | Linha / contexto | Ação sugerida |
|---------|------------------|---------------|
| `app/controllers/api/v2/accounts/reports_controller.rb` | `check_authorization` | Fase 2.1 — usar `authorize :report, :view?` |
| `app/controllers/api/base_controller.rb` | helper admin | Manter admin-only (settings críticos) |
| `app/controllers/api/v1/accounts/google/authorizations_controller.rb` | OAuth | Manter admin-only |
| `app/controllers/api/v1/accounts/microsoft/authorizations_controller.rb` | OAuth | Manter admin-only |
| `app/controllers/api/v1/accounts/twitter/authorizations_controller.rb` | OAuth | Manter admin-only |
| `app/controllers/api/v1/accounts/contacts/pipeline_positions_controller.rb` | Kanban | Fase futura — `crm_manage` |
| `app/controllers/api/v1/accounts/custom_attribute_definitions_controller.rb` | Kanban create | Fase futura — `crm_manage` |
| `app/models/message.rb` | delete message | Avaliar se vira permissão ou mantém admin |

---

## Fases de implementação

### Visão geral

```
Fase 0 ──► Fase 1 ──► Fase 2 ──► Fase 3 ──► Fase 4 (opcional)
Contrato    Backend     Policies    Frontend    Conversas
1–2 dias    3–5 dias    5–7 dias    5–7 dias    7–10 dias
```

---

### Fase 0 — Contrato e preparação

**Objetivo:** definir vocabulário, feature flag e inventário — sem alterar comportamento.

#### Tarefas

- [ ] Adicionar `custom_roles` em `config/features.yml` (`enabled: false`, **no final do arquivo** — nunca reordenar features existentes)
- [ ] Adicionar `CUSTOM_ROLES: 'custom_roles'` em `app/javascript/dashboard/featureFlags.js`
- [ ] Criar concern `PermissionCheckable` em `enterprise/app/models/concerns/permission_checkable.rb`
- [ ] Validar schema existente (`custom_roles`, `custom_role_id`) — migration idempotente só se faltar algo
- [ ] Confirmar inventário de bypasses (seção acima)

#### Critérios de aceite

- [ ] Flag desligada não altera nenhum fluxo
- [ ] Vocabulário de permissões acordado (base + backlog Manytalks)
- [ ] Equipe alinhada: develop = referência, não spec

#### Testes

```ruby
account.enable_features('custom_roles')
account.feature_enabled?('custom_roles') # => true
```

---

### Fase 1 — Backend mínimo

**Objetivo:** CRUD de custom roles + ligação com agentes, atrás de feature flag.

#### Referência develop (adaptar, não copiar cegamente)

| Upstream | Destino |
|----------|---------|
| `enterprise/app/models/custom_role.rb` | Copiar; remover callbacks de unread count |
| `enterprise/app/models/enterprise/concerns/account_user.rb` | Copiar |
| `enterprise/app/models/enterprise/account_user.rb` | Copiar |
| `enterprise/app/models/enterprise/concerns/account.rb` | Copiar |
| `enterprise/app/controllers/.../custom_roles_controller.rb` | Copiar |
| `enterprise/app/policies/custom_role_policy.rb` | Copiar |
| Views jbuilder | Copiar |
| Specs | Copiar e adaptar |

#### Tarefas

- [ ] Model `CustomRole` com `PERMISSIONS` (6 base) e validações
- [ ] Extensões Enterprise em `AccountUser` e `Account`
- [ ] Override `AccountUser#permissions`
- [ ] Rota `resources :custom_roles` em `config/routes.rb`
- [ ] Controller com `ensure_custom_roles_feature_enabled`
- [ ] Expor `custom_role_id` nos jbuilders de agents (`index`, `create`, `update`)
- [ ] Extensão enterprise em `AgentsController` para aceitar `custom_role_id`
- [ ] Factory `:custom_role` e specs

#### Regras de atribuição

```ruby
# custom_role_id permitido apenas se:
# - feature flag ON
# - role == 'agent'
# - custom_role pertence à mesma account

# Ao mudar role para administrator:
# - custom_role_id = nil
```

#### Critérios de aceite

- [ ] Flag off: 401/403 na API; zero mudança de comportamento
- [ ] Flag on + admin: CRUD completo
- [ ] Agente com role atribuída: login retorna permissions corretas
- [ ] Destroy role: agentes ficam com `custom_role_id` null
- [ ] Permissão inválida rejeitada na validação

#### Specs

```
spec/enterprise/models/custom_role_spec.rb
spec/enterprise/models/account_user_permissions_spec.rb
spec/enterprise/controllers/api/v1/accounts/custom_roles_controller_spec.rb
spec/enterprise/controllers/enterprise/api/v1/accounts/agents_controller_spec.rb
```

#### PR sugerido

**PR-1:** Fase 0 + Fase 1

---

### Fase 2 — Policies e autorização backend

**Objetivo:** API respeitar permissões granulares. Priorizar o que o frontend já espera.

#### Ordem de implementação

##### 2.1 — Reports (prioridade máxima)

Frontend já declara `report_manage` — é o primeiro gap a fechar.

| Arquivo | Mudança |
|---------|---------|
| `enterprise/app/policies/enterprise/report_policy.rb` | `view?` com `report_manage \|\| super` |
| `enterprise/app/policies/enterprise/csat_survey_response_policy.rb` | idem |
| `app/policies/report_policy.rb` | `ReportPolicy.prepend_mod_with('ReportPolicy')` |
| `app/controllers/api/v2/accounts/reports_controller.rb` | Trocar `administrator?` por Pundit |

##### 2.2 — Contacts (conservador)

Upstream só estende `import?` e `export?`. No fork, incluir `destroy?` (já é admin-only).

**Não restringir** `update?`, `create?`, `show?` — fork trata contatos de forma mais aberta que o develop.

##### 2.3 — Help Center

`knowledge_base_manage` em Portal, Article, Category policies.

Rotas helpcenter hoje misturam `administrator` e `agent` — revisar quais páginas exigem a permissão vs. manter acesso de leitura para agentes.

##### 2.4 — Bypasses restantes

Atacar inventário conforme prioridade de negócio. Manter admin-only: OAuth, integrações, settings críticos.

#### Padrão de policy extension

```ruby
# enterprise/app/policies/enterprise/report_policy.rb
module Enterprise::ReportPolicy
  def view?
    return super unless @account.feature_enabled?('custom_roles')
    @account_user.permission?('report_manage') || super
  end
end
```

Guard de feature flag dentro da policy evita efeito colateral quando flag off.

#### Critérios de aceite

- [ ] Agente com `report_manage`: API de reports responde 200
- [ ] Agente sem permissão: 403 mesmo acessando URL direta
- [ ] Administrator: acesso total inalterado
- [ ] Flag off: comportamento idêntico ao atual

#### Specs

```
spec/enterprise/policies/report_policy_spec.rb
spec/enterprise/policies/contact_policy_spec.rb
spec/enterprise/policies/portal_policy_spec.rb
spec/controllers/api/v2/accounts/reports_controller_spec.rb
```

#### PRs sugeridos

- **PR-2:** Fase 2.1 Reports
- **PR-3:** Fase 2.2 Contacts + 2.3 Help Center

---

### Fase 3 — Frontend Vue 2

**Objetivo:** UI para administradores gerenciarem roles e atribuírem a agentes.

#### Stack

- Vue 2 + Options API (não portar Composition API do develop)
- Vuex module (não Pinia)
- `<Policy>` + `hasPermissions()` já existentes

#### Tarefas

- [ ] `constants/permissions.js` — lista de permissões + helpers
- [ ] `api/customRole.js` — client REST
- [ ] `store/modules/customRoles.js` — state, actions, mutations
- [ ] Rotas `settings/customRoles/` — CRUD
- [ ] Item sidebar Settings — "Funções" (flag + admin)
- [ ] `EditAgent.vue` / `AddAgent.vue` — dropdown custom role quando flag on
- [ ] i18n `pt_BR` + `en`
- [ ] Verificar sidebar de reports usa `report_manage`

#### Comportamento UI

| Estado | Comportamento |
|--------|---------------|
| Flag off | Seção Custom Roles invisível; agents sem dropdown |
| Flag on + admin | CRUD de roles + atribuição em agents |
| Agente com `report_manage` | Menu Relatórios visível |
| Agente sem permissão | Menu oculto via `<Policy>` |

#### Critérios de aceite

- [ ] Fluxo completo: criar role → atribuir agente → login → menu correto
- [ ] Reload mantém permissões (via profile API)
- [ ] Nenhum componente Vue 3 introduzido

#### Specs frontend

```
app/javascript/dashboard/store/modules/specs/customRoles/
app/javascript/dashboard/helper/specs/permissionsHelper.spec.js  # estender
```

#### PR sugerido

**PR-4:** Fase 3 (depende de PR-1 e PR-2)

---

### Fase 4 — Conversas (opcional, alto risco)

**Objetivo:** Filtrar conversas visíveis por permissão de custom role.

**Adiar se:** regressões em WhatsApp, workflows ou contadores de inbox.

#### Subfases

##### 4a — Policy individual (menor risco)

Estender `show?`, `update?`, `destroy?` por conversa — bloqueia acesso direto por ID sem alterar listagem.

Referência: `enterprise/app/policies/enterprise/conversation_policy.rb`

##### 4b — ConversationFinder (maior risco)

Prepend `PermissionFilterService` no finder — afeta listagem, tabs (Me/Unassigned/All) e contadores.

Referência: `enterprise/app/services/enterprise/conversations/permission_filter_service.rb`

**Atenção Manytalks:**

- Customizações WhatsApp (`@g.us`, echo, coexistência)
- `WorkflowListener` e atribuição automática
- `ConversationFinder` do fork já diverge do develop

##### 4c — Frontend tabs

Portar lógica de `ASSIGNEE_TYPE_TAB_PERMISSIONS` (adaptar para Vue 2).

#### Kill criterion

Se 4b quebrar specs de WhatsApp/workflows → shipar só 4a e adiar listagem.

#### Specs de regressão obrigatórios

```bash
bundle exec rspec spec/enterprise/policies/conversation_policy_spec.rb
bundle exec rspec spec/services/whatsapp/incoming_message_echo_service_spec.rb
bundle exec rspec spec/jobs/webhooks/whatsapp_events_job_coexistence_spec.rb
bundle exec rspec spec/listeners/workflow_listener_echo_spec.rb
```

#### PRs sugeridos

- **PR-5:** Fase 4a
- **PR-6:** Fase 4b (opcional, após validação)

---

## Fase 5+ — Permissões Manytalks (backlog)

Implementar **uma permissão por PR**, após MVP estável.

### `workflow_manage`

| Onde | Mudança |
|------|---------|
| `WorkflowPolicy` | `create?`, `update?`, `destroy?` exigem permissão ou admin |
| `automation.routes.js` | Rotas de workflow exigem `workflow_manage` |
| Leitura / execução | Manter acessível a agentes (só edição restrita) |

### `automation_manage` / `form_manage`

| Onde | Mudança |
|------|---------|
| `AutomationRulePolicy` | CRUD restrito |
| `automation.routes.js` | Separar rotas de automação legacy vs workflows |

### `crm_manage`

| Onde | Mudança |
|------|---------|
| `custom_attribute_definitions_controller.rb` | Criar pipeline Kanban |
| `pipeline_positions_controller.rb` | Operações admin-only → permissão |
| Complementar | Permissões por funil continuam valendo |

### Outras

Implementar conforme demanda de negócio. Sempre: model validation → policy → controller → rota frontend → spec.

---

## Rollout

### Deploy

```
1. Deploy com custom_roles flag OFF
2. Habilitar em 1 conta piloto
3. Criar role "Supervisor" (report_manage + contact_manage)
4. Atribuir a 1 agente de teste
5. Validar: menu, API, agente normal inalterado
6. Expandir contas
7. Avaliar Fase 4 (conversas)
```

### Habilitar por conta

```ruby
account = Account.find(id)
account.enable_features('custom_roles')
account.save!
```

### Monitoramento

- `Pundit::NotAuthorizedError` — não deve aumentar para admins
- 403 em reports para agentes sem permissão — esperado
- Feedback de contas piloto

### Rollback

Desabilitar feature flag. Dados permanecem; sem efeito colateral.

---

## Checklist de PRs

| PR | Escopo | Depende de |
|----|--------|------------|
| PR-1 | Fase 0 + 1 — contrato, model, API | — |
| PR-2 | Fase 2.1 — reports | PR-1 |
| PR-3 | Fase 2.2 + 2.3 — contacts, KB | PR-1 |
| PR-4 | Fase 3 — frontend Vue 2 | PR-1, PR-2 |
| PR-5 | Fase 4a — conversation policy | PR-1 |
| PR-6 | Fase 4b — finder (opcional) | PR-5 + regressão |
| PR-N | Permissões Manytalks (uma por vez) | MVP completo |

---

## Roles pré-definidas sugeridas (contas piloto)

Exemplos para facilitar onboarding — **não são seed automático**; admin cria manualmente.

| Nome | Permissões | Perfil |
|------|------------|--------|
| Supervisor | `report_manage`, `contact_manage` | Vê relatórios, importa/exporta contatos |
| Atendente sênior | `conversation_unassigned_manage`, `conversation_participating_manage` | Pega fila + próprias |
| Editor KB | `knowledge_base_manage` | Mantém help center |
| Operador CRM | `crm_manage`, `contact_manage` | Pipelines + contatos |

---

## Decisões em aberto

Registrar aqui conforme forem tomadas:

| # | Decisão | Opções | Status |
|---|---------|--------|--------|
| 1 | Restringir CRUD de contatos além de import/export/destroy? | Sim (como develop) / Não (conservador) | **Pendente** — MVP: não |
| 2 | Help Center: agente pode ler sem `knowledge_base_manage`? | Sim / Não | **Pendente** — provável: sim para leitura |
| 3 | Unificar `automation_manage` + `form_manage`? | Sim / Não | **Pendente** |
| 4 | Fase 4 (conversas) entra no MVP? | Sim / Não | **Pendente** — provável: não |
| 5 | Seed de roles pré-definidas? | Sim / Não | **Pendente** — provável: não |

---

## Referências

- Upstream custom roles: `chatwoot-develop/chatwoot/enterprise/app/models/custom_role.rb`
- Fork audit WhatsApp: `docs/whatsapp-fork-audit.md`
- Feature flags: `config/features.yml`, `app/javascript/dashboard/featureFlags.js`
- Infra frontend: `app/javascript/dashboard/components/policy.vue`, `helper/permissionsHelper.js`
- Padrão Enterprise: `config/initializers/01_inject_enterprise_edition_module.rb`

---

## Changelog deste documento

| Data | Alteração |
|------|-----------|
| 2026-09-10 | Criação inicial — plano completo fases 0–4 + backlog Manytalks |
| 2026-09-10 | Implementação do MVP: model, API, policies, UI Vue 2, filtro de conversas |
