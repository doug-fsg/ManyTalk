# UI/UX Improvements — CRM integrado (Funil · Atividades · Formulários · Automação · Relatórios)

## Summary

Revisão ampliada do ecossistema que o operador usa **em conjunto**: funil (Kanban), calendário de atividades, formulários, workflows/automação e relatórios. O sistema é **funcional e arquiteturalmente sólido** (`KanbanCardModal` como hub, deep links parciais, triggers `form_submitted`), porém a **experiência percebida é complexa** porque cada módulo vive em contexto de navegação, nomenclatura e feedback diferentes.

**Diagnóstico central:** não falta feature — falta **continuidade de jornada**. O usuário alterna entre “operar deals”, “agendar tarefas”, “capturar leads”, “automatizar” e “medir resultados” como se fossem cinco produtos.

**Já implementado (crítico original):** hub no modal (Opção A no funil), badge clicável, link no `KanbanStageIndicator`, detalhe de atividade → funil.

**Revertido por feedback:** faixa `CrmContextBar` (“Funil: X / Atividades / N atrasadas”) — poluição visual; preferir cross-links **discretos nos headers** ou agrupamento no menu, não barra extra.

**Complexidade UX (score qualitativo):**

| Dimensão | Situação |
|----------|----------|
| Navegação entre módulos | 🔴 Crítico — silos Settings vs menu primário |
| Nomenclatura | 🔴 Crítico — mesmo rótulo, significados diferentes |
| CRUD de atividades | 🟠 Alto — 3 superfícies com payloads distintos |
| Formulários ↔ CRM | 🔴 Crítico — submissões não aparecem no funil/calendário |
| Relatórios ↔ operação | 🟠 Alto — métricas de workflow ≠ métricas de pipeline |
| Feedback (toasts/confirmações) | 🟡 Médio — inconsistente entre calendário e modal |

---

## Mapa mental do usuário (como deveria ser vs hoje)

```
                    ┌─────────────────────────────────────┐
                    │         OPERAR (menu primário)       │
                    │  Funil ←→ Calendário ←→ Contatos     │
                    └──────────────┬──────────────────────┘
                                   │ contexto compartilhado
         ┌─────────────────────────┼─────────────────────────┐
         ▼                         ▼                         ▼
   Lead entra via            Tarefa no deal            Conversa ativa
   Formulário público        no card modal             + etapa no funil
         │                         │                         │
         └──────────── Automação (workflow) ────────────────┘
                                   │
                                   ▼
                         Relatórios (medir tudo)
```

**Hoje:** cada caixa acima abre em rota, layout e vocabulário diferentes; links de retorno são raros ou unidirecionais.

---

## Propostas estratégicas (avaliação UX — jul/2026)

Duas ideias alinhadas com reduzir complexidade **sem** multiplicar telas administrativas. Avaliação: **ambas recomendadas**, com ressalvas técnicas e de escopo.

### Proposta A: Filtro “Formulário” na lista de contatos (`/contacts`)

**Ideia:** remover (ou reduzir) a lista de submissões dentro do `FormDetail`; na sidebar secundária de Contatos, **acima de “Marcado com”** (`TAGGED_WITH` em `Secondary.vue`), adicionar seção **Formulários** — ao clicar, filtra contatos que enviaram aquele form.

**Current State**
- Submissões só em Settings → `FormDetail.vue` (aba isolada).
- Sidebar de contatos já filtra por label via `contacts_labels_dashboard` + `contactLabelSection` — **padrão reutilizável**.
- `Contact` já tem `has_many :form_submissions`; API de contatos expõe filtro por `account_form_id` (✅ implementado).

**Por que funciona (heurísticas)**
| Heurística | Benefício |
|---|---|
| #2 Mundo real | Operador pensa “leads deste formulário”, não “linhas da tabela de submissões” |
| #6 Reconhecimento | Mesmo padrão visual de labels — aprendizado zero |
| #8 Minimalismo | Tira captura de leads do buraco de Settings |
| Integração | Contatos vira hub entre Form → Funil → Conversa |

**Ressalvas**
- Filtro lista **contatos**, não submissões individuais (1 contato pode ter N envios).
- Sidebar com muitos forms precisa de scroll/colapso (como labels).
- **Não eliminar** totalmente a aba Submissões no form: manter export CSV, UTM, payload completo e contagem — ou link “Ver contatos filtrados” que leva a `/contacts?form_id=X`.

**Recommendation**
1. Nova rota espelhando labels: `contacts_forms_dashboard` ou query `?account_form_id=`.
2. Seção `contactFormSection` em `Secondary.vue` acima de `contactLabelSection`.
3. Badge no form: “142 contatos” → link para lista filtrada.
4. Em `FormDetail`, submissões viram **modo auditoria** (detalhe de payload), não operação diária.

**Impact:** leads deixam de ser config-only; operador trabalha no mesmo `/contacts` que já conhece.

**Implementation Notes:** filtro no `ContactsController#index`; contador por form; i18n `SIDEBAR.FORMS` / `SUBMITTED_VIA`.

**Critérios de aceite**
- [x] Sidebar Contatos → Formulário X → lista só contatos com submissão naquele form
- [x] FormDetail → “Ver contatos” abre mesmo filtro
- [x] Submissão individual ainda acessível para auditoria (aba Submissões no FormDetail)

---

### Proposta B: Enriquecer perfil do contato (`/contacts/:id`) com timeline unificada

**Ideia:** em vez de perfil pobre (só **Notas** em `ContactManageView.vue`), timeline cronológica com: entrada via formulário, entrada no pipeline, mudança de etapa, ganho/perdido, tarefas, etc. — estilo RD Station, complementando (não substituindo) o `KanbanCardModal`.

**Current State**
- `ContactManageView`: 25% `ContactInfoPanel` + 75% uma aba Notas.
- `TimelineCard.vue` existe mas estilo legado (ícones Ionic), pouco usado no perfil CRM.
- Backend: `form_submissions` com `created_at`; `contact_pipeline_positions` com `entered_at`, `stage_id`, `metadata.win_lost`; histórico de etapas em **`contact_pipeline_events`** (✅ Fase 2).

**Por que funciona**
| Heurística | Benefício |
|---|---|
| #1 Visibilidade | História completa do lead num lugar |
| #4 Consistência | Perfil deixa de contradizer o modal rico do funil |
| Jornada | Form → perfil → funil deixa de ser dead end |
| Diferenciação | Modal = **operar** deal; perfil = **entender** história + admin |

**Ressalvas técnicas importantes**
- **Mudanças de etapa intermediárias** não estão persistidas hoje — timeline mostra “entrou na etapa atual em {entered_at}” e ganho/perdido, mas **não** cada movimento A→B→C sem novo model (`contact_pipeline_events` ou log via webhook).
- Fase 1 realista: form submit + entrada pipeline + etapa atual + win/lost + notas + atividades (`Activity` model) + conversas.
- Fase 2: audit log de stage changes (job ao `dispatch_kanban_stage_changed`).

**Recommendation (Opção B refinada — híbrido com Opção A)**
Abas no perfil (75%):
1. **Linha do tempo** (default) — eventos agregados, filtros por tipo
2. **Negócio** — reutilizar bloco do modal: etapa (botões), valor, responsável, link “Abrir no funil”
3. **Notas** — conteúdo atual
4. *(opcional)* **Atividades** — `ContactActivities` embutido

Header fixo: nome + pipeline atual + badge tarefas + origem do form (“via Formulário X”).

**O que NÃO fazer**
- Duplicar 100% do `KanbanCardModal` no perfil — manter modal como surface de **ação rápida** no funil; perfil como **memória e contexto**.

**Impact:** resolve Issue 1 de forma sustentável; alinha com modelo mental RD/Pipedrive.

**Arquivos:** `ContactManageView.vue`, novo `ContactTimeline.vue`, API `GET /contacts/:id/timeline` (ou composable agregador).

**Critérios de aceite**
- [x] Timeline mostra submissão de form com data/hora e link para form
- [x] Mostra pipeline + etapa atual + data de entrada
- [x] Mostra ganho/perdido com data quando existir
- [x] CTA primário “Abrir no funil” quando contato estiver em pipeline
- [x] Timeline também no `KanbanCardModal` (aba dedicada)
- [x] Fase 2: histórico completo de mudanças de etapa (`contact_pipeline_events`)

---

### Síntese: as duas ideias juntas

```
Form público → Contato criado
                    │
        ┌───────────┴───────────┐
        ▼                       ▼
/contacts?form=X          /contacts/:id
(filtro sidebar)          (timeline + negócio)
        │                       │
        └───────────┬───────────┘
                    ▼
            Funil (modal operacional)
```

**Veredicto:** **A + B** reduzem complexidade percebida melhor que mais links entre Settings e CRM. Prioridade sugerida: **A primeiro** (menor backend, padrão labels já existe), **B em seguida** (maior valor, exige API timeline).

---

## Critical Issues

### Issue 1: Perfil de contato desconectado do CRM *(resolvido — Fase 1 + 2)*

**Current State**
- ✅ Funil: `openContact()` abre `KanbanCardModal`.
- ❌ **Formulários:** `FormDetail.vue` → `contact_profile_dashboard` (perfil com **só Notas**).
- ❌ `KanbanCardModal.openContactProfile()` ainda abre `/contacts/:id` em **nova aba** (terceiro contexto).
- `ContactManageView.vue` permanece pobre para operação CRM.

**Problem**
| Heurística | Violação |
|---|---|
| #4 Consistência | Mesmo contato: hub rico no funil, perfil vazio em formulários |
| #3 Controle | Submissão → contato → dead end; perde submissão e funil |

**Recommendation**
- Formulários: filtro em `/contacts` (Proposta A) + timeline no perfil (Proposta B).
- Funil: manter modal como hub de ação; perfil como histórico.
- Unificar `openContact` em helper compartilhado (`crmNavigationHelper.js`).

**Critérios de aceite**
- [x] Funil → ver contato abre modal
- [x] Form → contatos filtrados (Proposta A)
- [x] Perfil com timeline CRM + CTA funil + histórico de etapas

---

### Issue 2: Badge de atividades no card *(resolvido)*

**Status:** ✅ Implementado — badge clicável, aba Atividades, highlight da próxima tarefa.

---

### Issue 3: Funil e Calendário como silos *(parcial — barra removida)*

**Current State**
- Menu primário: ícones separados (`primaryMenu.js` — `kanban` + `activities`).
- Headers **sem** link cruzado (`Header.vue`, `ActivitiesCalendar.vue`).
- `buildActivitiesDeepLink()` e `readLastPipelineId()` existem em `crmNavigationHelper.js` mas **não são usados** na UI.
- Filtro de responsável: funil usa `kanbanFilters.assignees[]`; calendário usa `filters.assigneeId` — **sem sync**.
- Deep link calendário → funil via `ActivityDetailModal` ✅; funil → calendário ❌.

**Problem**
| Heurística | Violação |
|---|---|
| #7 Flexibilidade | Manhã no calendário, tarde no funil — reconfigura filtros toda vez |
| #8 Minimalismo | Dois headers quase idênticos (busca + dropdown filtros) |

**Recommendation (sem barra contextual — feedback do usuário)**
1. **Ícone/link discreto** no header do funil → calendário (minhas atrasadas); no calendário → último funil.
2. **Query sync:** `?assignee_id=&pipeline_id=` lido/gravado em ambas as rotas.
3. **Opcional:** submenu lateral “CRM” colapsável (Funil + Atividades) em vez de dois ícones soltos.

**O que NÃO refazer**
- Faixa `CrmContextBar` com texto “Funil: X / N atrasadas” — rejeitada por poluição visual.

**Critérios de aceite**
- [ ] 1 clique funil → calendário (filtro atrasadas + responsável preservado)
- [ ] 1 clique calendário → funil (último pipeline)
- [ ] Sem barra extra abaixo do header

---

### Issue 4: Formulários enterrados e desconectados do CRM operacional

**Current State**
- Formulários só em **Settings → Automação → aba Formulários** (`AutomationHub.vue`). **Não** no menu primário nem no sidebar de settings (só `REPORTS_WORKFLOWS` aponta para workflows).
- Lista de submissões (`FormDetail.vue`): colunas fixas (data, nome, e-mail, telefone). API envia `payload` completo + `utm` — **UI ignora campos customizados**.
- Única ponte visual: submissão → ícone “Ver contato” → perfil pobre.
- **Zero** referência a formulários/submissões em Kanban, calendário ou card modal.
- `FormWorkflowLinkageCell` e CTA “Conectar” existem **só na lista**; detalhe do formulário não mostra workflow vinculado.
- `FormEmbedPopover.vue` existe mas **não está wired** na UI.
- Backend associa `conversation_id` à submissão via workflow — **não exposto** na API/UI de submissões.

**Problem**
| Heurística | Violação |
|---|---|
| #1 Visibilidade | Lead capturado no form é invisível no funil até alguém procurar em Settings |
| #6 Reconhecimento | Operador não sabe que formulário gerou o deal |
| Carga cognitiva | Builder em 3 colunas; palette/preview somem em `< lg` |

**Recommendation**
1. **Card modal / funil:** badge ou linha “Formulário: {nome} · {data}” quando contato tiver submissão recente.
2. **FormDetail:** aba Submissões com colunas dinâmicas do `payload`; link “Abrir no funil” + “Ver conversa” quando existir.
3. **Detalhe do form:** repetir linkage de workflow (badge + editar fluxo) — hoje só na lista.
4. **Expor embed** via `FormEmbedPopover` ou botão “Compartilhar” no header.
5. Considerar entrada “Formulários” no menu primário CRM quando houver form publicado (não só Settings).

**Impact:** lead capture deixa de ser ilha administrativa; operador vê origem do deal no mesmo hub do funil.

**Arquivos:** `FormDetail.vue`, `FormsIndex.vue`, `FormWorkflowLinkageCell.vue`, `submissions.json.jbuilder`, `KanbanCardModal.vue`

---

### Issue 5: Colisão de nomenclatura — três “Fluxos” diferentes

**Current State**
Mesma chave i18n `REPORTS_WORKFLOWS` (“Fluxo de Atendimento”) usada em:
- **Settings sidebar** → configurar workflows (`settings.js`)
- **Reports sidebar** → analytics de workflows (`reports.js`)
- **AutomationHub** → tab operacional de workflows + forms

Paralelamente no menu primário: **Funil** (Kanban), **Atividades**, **Relatórios** — sem relação visual com “Fluxo de Atendimento”.

**Problem**
| Heurística | Violação |
|---|---|
| #4 Consistência | Mesmo nome, três destinos (configurar / medir / capturar leads) |
| #2 Mundo real | Usuário não distingue workflow de pipeline de funil |

**Recommendation**
Renomear explicitamente (exemplo pt_BR):
| Contexto | Rótulo sugerido |
|----------|-----------------|
| Settings | **Automatizar fluxos** |
| Reports | **Desempenho dos fluxos** |
| Menu primário Kanban | **Funil de vendas** (ou manter Funil) |
| Menu Atividades | **Agenda** ou **Tarefas** |
| Formulários (hub) | **Formulários de captura** |

**Impact:** reduz erro de “estou no lugar certo?” ao cruzar módulos.

---

### Issue 6: Dois sistemas de automação no mesmo hub

**Current State**
`AutomationHub.vue`: tabs **Fluxos de Atendimento | Formulários**; link discreto no canto para **Automação clássica** (`automation_list`).
- Classic automation ainda tem ações CRM (`change_kanban_stage` em `automation/constants.js`).
- Workflows usam triggers visuais (`form_submitted`, etc.) em `WorkflowEditor.vue`.
- “Conectar formulário” via `WorkflowCreateModal`: caminho **em branco** passa `connectFormId`; **template da galeria não** — trigger `form_submitted` não é seedado.

**Problem**
| Heurística | Violação |
|---|---|
| #8 Minimalismo | Dois paradigmas de automação + forms no mesmo hub |
| #3 Controle | CTA “Conectar” pode falhar silenciosamente com template |

**Recommendation**
1. Depreciar visualmente classic ou mover para “Avançado (legado)”.
2. Wizard único: “Quando [form enviado] → então [mover funil / criar tarefa / abrir conversa]”.
3. Corrigir `WorkflowCreateModal` para templates também receberem `connectFormId`.

---

### Issue 7: Store Vuex `activities` único — colisão Funil ↔ Calendário

**Current State**
`store/modules/activities.js` — array `records[]` compartilhado:
- Funil: `KanbanAttributes.loadAllActivities()` — `merge: true` por `contact_ids`
- Calendário: `ActivitiesCalendar.loadActivities()` — `merge: false` por intervalo de datas
- Modal: `ContactActivities` — `merge: false` por `contact_id`

Alternar rota **substitui** dados. Badges nos cards (`KanbanCard.vue` → `getPendingCountByContactId`) ficam **stale** após visitar calendário.

**Problem**
| Heurística | Violação |
|---|---|
| #1 Visibilidade | Contador de tarefas no card mente após navegação |
| Confiabilidade | Mesma entidade, três loaders conflitantes |

**Recommendation**
1. **Curto prazo:** recarregar atividades do funil ao `activated` de `KanbanAttributes`.
2. **Médio prazo:** getters derivados por contexto (`kanbanPendingByContact`, `calendarRangeRecords`) ou namespaces no store.
3. Documentar contrato: quem pode fazer `merge: false`.

---

### Issue 8: Atividade criada no calendário global sem vínculo ao funil

**Current State**
- `activities/Index.vue` **não passa** `pipeline-id` ao calendário.
- `ActivitiesCalendar.handleActivitySubmit()` envia payload **sem** `contact_pipeline_position_id`.
- `ContactActivities.handleSubmit()` **envia** vínculo ao pipeline — comportamentos divergentes.
- Resultado: tarefa existe no calendário mas **“Abrir no funil”** no detalhe falha ou mostra seção vazia.

**Problem**
| Heurística | Violação |
|---|---|
| #4 Consistência | Mesmo formulário de atividade, resultados diferentes |
| Jornada | Operador cria tarefa pensando no deal; deal não enxerga a tarefa |

**Recommendation**
1. Calendário global: ao selecionar contato, resolver `contact_pipeline_position_id` (último funil ou picker de pipeline).
2. Default: associar ao pipeline ativo em `localStorage` (`kanban_selected_pipeline`).
3. Feedback visual no form: “Vinculada ao funil X · etapa Y” (já existe parcialmente em `ActivityFormModal` no modal do card).

---

### Issue 9: Relatórios não fecham o loop CRM

**Current State**
- `WorkflowReports.vue`: métricas por workflow (reply rate, steps) — link **de** workflow card ✅; link **para** editor ❌.
- `KanbanDashboard.vue`: win rate, cards abertos/ganhos — **dentro** do funil, sem link para reports.
- **Não existem** relatórios de: submissões por formulário, conversão form→funil, SLA de atividades, performance por pipeline/etapa.

**Problem**
| Heurística | Violação |
|---|---|
| #7 Flexibilidade | Gestor alterna dashboard do funil e reports de workflow sem saber qual é “oficial” |
| #1 Visibilidade | ROI de formulários e tarefas atrasadas invisível |

**Recommendation**
1. Link bidirecional WorkflowReports ↔ editor.
2. Seção “CRM” em Relatórios: pipeline (win rate), atividades (atrasadas/concluídas), formulários (submissões/conversão).
3. Ou: card no `KanbanDashboard` “Ver relatório completo” → nova rota `/reports/crm`.

---

### Issue 10: Complexidade de UI — controles e feedback duplicados

**Current State**

| Padrão duplicado | Onde |
|------------------|------|
| Header busca + filtros | `Header.vue` + `ActivitiesCalendar.vue` |
| Busca **duas vezes** no calendário | Header + dentro do dropdown de filtros |
| “Nova atividade” 3 estilos | Calendário, `ContactActivities`, `KanbanCardModal` |
| “Lista” ambíguo | Lista de **deals** (funil) vs lista de **tarefas** (calendário) |
| i18n calendário usa chaves **KANBAN.*** | `ActivitiesCalendar.vue` — terminologia errada |
| Strings PT hardcoded | Calendário, `ContactActivities`, paginação funil |
| Toast save/complete | Calendário ✅ parcial; modal `ContactActivities` ❌ |
| Delete/complete inline | Calendário sem confirmação; funil com modais |
| Tooltip etapa | Mostra `stage_id` cru, não nome legível |

**Problem**
| Heurística | Violação |
|---|---|
| #8 Minimalismo | Mesma ação aprendida 3 vezes |
| #4 Consistência | Cores pending yellow vs amber; feedback assimétrico |

**Recommendation (reduzir complexidade sem remover power)**
1. Extrair `CrmFilterBar.vue` compartilhado (busca + filtros) — props para escopo funil vs atividades.
2. Unificar botão “Nova atividade” (mesmo `color-scheme`, ícone, label i18n).
3. Renomear views: funil “Lista de negócios”; calendário “Lista de tarefas”.
4. Padronizar feedback em composable `useActivityActions`.
5. Remover busca duplicada no dropdown do calendário.

---

## High Priority Improvements

| Item | Status | Notas |
|------|--------|-------|
| Hub modal no funil | ✅ Feito | Opção A |
| Badge → aba Atividades | ✅ Feito | + highlight |
| Detalhe atividade → funil | ✅ Feito | Seção pipeline no calendário |
| Wizard formulário atividade | ✅ Feito | 2 passos + atalhos |
| Cross-nav headers (discreto) | ⏳ Pendente | Substituto da barra removida |
| **Proposta A:** filtro Formulário em `/contacts` | ✅ Feito | Sidebar + rota + API + FormDetail + lista forms |
| **Proposta B (Fase 2):** audit log mudanças de etapa | ✅ Feito | `contact_pipeline_events` + backfill job |
| Sync store activities | ⏳ Pendente | Issue 7 |
| Calendário → pipeline link | ⏳ Pendente | Issue 8 |
| Renomear “Fluxo de Atendimento” | ⏳ Pendente | Issue 5 |

---

## Medium Priority Enhancements

### Toggle Kanban/Dashboard/Lista oculto no mobile
`Header.vue` — `hidden md:flex`. Bottom bar ou menu compacto.

### Accordions todos abertos no modal
Colapsar labels/atributos/conversas; manter responsável + valor abertos.

### FormDetail layout vs FormsIndex
Detalhe full-bleed; lista usa `SettingsLayout` — inconsistência visual.

### KanbanAttributes god component (~3.500 linhas)
Extrair modais, filtros e loaders para reduzir regressões UX.

### Feature flags fragmentadas
`WOOFED` (kanban+atividades), `WORKFLOWS` (forms+hub), `CRM` (contatos), `REPORTS` — combinações parciais quebram jornadas esperadas.

---

## Low Priority Suggestions

- Atalho `A` no modal para nova atividade
- Badge global no menu (atrasadas) — sutil, não barra
- Empty state unificado: “Adicionar ao funil + 1ª tarefa”
- Export CSV de submissões com UX de paginação melhor
- Breadcrumb FormDetail → Automação → Settings

---

## Positive Observations

- **KanbanCardModal** como hub operacional — decisão arquitetural correta; base para unificar formulários e atividades.
- **Deep links** (`crmNavigationHelper.js`) — infra pronta; falta wiring nos headers.
- **ActivityFormModal** wizard + atalhos de data — bom equilíbrio simplicidade/poder.
- **Form ↔ Workflow linkage** na lista — padrão reutilizável no detalhe do form.
- **WorkflowCard → Relatório** — exemplo de cross-link que deveria ser replicado everywhere.
- **KanbanStageIndicator** clicável — ponte conversa ↔ funil.
- **Triggers backend** (`WorkflowTriggerService`, `contact_pipeline_position` em activities) — integração real existe; gap é mostly UI.

---

## Plano de implementação (ordem por impacto × esforço)

| # | Item | Esforço | Impacto | Módulos |
|---|------|---------|---------|---------|
| 1 | **Proposta A:** filtro Formulário em `/contacts` sidebar | ✅ Feito | Alto | Forms, Contatos |
| 2 | **Proposta B (Fase 1):** timeline + abas no perfil | ✅ Feito | Alto | Contatos, CRM |
| 3 | Link discreto funil ↔ calendário nos headers + query sync | Baixo | Alto | Funil, Calendário |
| 4 | Calendário global envia `contact_pipeline_position_id` | Médio | Alto | Calendário, Funil |
| 5 | Recarregar/isolar store `activities` | Médio | Alto | Funil, Calendário |
| 6 | Renomear i18n Settings vs Reports | Baixo | Médio | Automação, Reports |
| 7 | FormDetail: modo auditoria + link “Ver contatos” | ✅ Feito | Médio | Forms |
| 8 | Relatório CRM (pipeline + forms + atividades) | Alto | Alto | Reports |
| 9 | `CrmFilterBar` compartilhado | Médio | Médio | Funil, Calendário |
| 10 | Audit log de mudanças de etapa (fase 2 timeline) | ✅ Feito | Médio | Backend, Contatos |

---

## Roadmap kanban-markdown

| Feature file | Status |
|--------------|--------|
| `activity-badge-quick-open` | ✅ Feito |
| `crm-unified-contact-hub` | ✅ Feito — funil + forms/contacts + timeline perfil/modal |
| `crm-cross-navigation` | ⏳ Helpers prontos; UI nos headers pendente |
| `form-submission-crm-bridge` | ⏳ Novo — submissão → funil + conversa |
| `crm-reports-unified` | ⏳ Novo — pipeline + forms + atividades |
| `activities-store-isolation` | ⏳ Novo — badges confiáveis |

---

## Referência de arquivos (cross-module)

```
# Navegação
app/javascript/dashboard/components/layout/config/sidebarItems/primaryMenu.js
app/javascript/dashboard/components/layout/config/sidebarItems/settings.js
app/javascript/dashboard/components/layout/config/sidebarItems/reports.js

# CRM operacional
app/javascript/dashboard/routes/dashboard/crm/components/KanbanAttributes.vue
app/javascript/dashboard/routes/dashboard/crm/components/Header.vue
app/javascript/dashboard/routes/dashboard/crm/components/ActivitiesCalendar.vue
app/javascript/dashboard/routes/dashboard/crm/components/KanbanCardModal.vue
app/javascript/dashboard/routes/dashboard/crm/utils/crmNavigationHelper.js
app/javascript/dashboard/store/modules/activities.js

# Formulários
app/javascript/dashboard/routes/dashboard/settings/forms/FormDetail.vue
app/javascript/dashboard/routes/dashboard/settings/forms/FormsIndex.vue
app/javascript/dashboard/routes/dashboard/settings/automation/AutomationHub.vue

# Automação & Relatórios
app/javascript/dashboard/routes/dashboard/settings/workflows/WorkflowEditor.vue
app/javascript/dashboard/routes/dashboard/settings/workflows/WorkflowCreateModal.vue
app/javascript/dashboard/routes/dashboard/settings/reports/WorkflowReports.vue
app/javascript/dashboard/routes/dashboard/crm/components/KanbanDashboard.vue
```

---

## Workflow — Modal "Configurações do fluxo" (ago/2026)

### Summary

Revisão do modal global de settings no editor de fluxo (`WorkflowFlowSettingsPanel.vue`). Problema: lista longa de toggles com labels encurtados demais; operadores não entendiam escopo, pausa vs cancelamento e re-entrada.

### Implementado

- **Abas no topo** (`woot-tabs`, padrão Canais de Entrada): Cliente · Inscrição · Equipe · Re-entrada
- **Cards de radio** para escolhas mutuamente exclusivas (resposta do cliente; vínculo por conversa/contato)
- **Label + uma linha de contexto** por controle (`*_DESC`), sem tooltips nem parágrafos
- **Subtítulo único** no header do modal (`FLOW_SETTINGS_HINT`)
- Modal `max-w-xl`, corpo scrollável, botão **Concluído**

### Positive Observations

- Chips de etiqueta com estado selecionado claro
- `woot-switch` alinhado ao restante do dashboard
- Separação por domínio mental (cliente vs inscrição vs equipe) reduz carga cognitiva (Miller/Hick)

### Medium Priority (futuro)

- Badge nas abas quando há configuração não-padrão (ex.: re-entrada ativa)
- Link discreto "Gerenciar etiquetas" na aba Equipe quando lista vazia

---

## WhatsApp — Sincronização de templates (ago/2026)

### Summary

Revisão da aba **Templates** em Configurações do inbox WhatsApp Cloud (`TemplatesPage.vue`). Após correção do sync backend, a contagem passou a refletir templates aprovados, mas o botão **Sincronizar** exibia "Falha ao sincronizar." mesmo com dados corretos — erro de confiança (heurística #9: reconhecer, diagnosticar e recuperar de erros).

### Critical Issues

#### Issue: Falso erro após sync bem-sucedido
**Current State**: Toast genérico "Falha ao sincronizar." ao clicar em Sincronizar, embora a contagem mostre templates corretos.
**Problem**: O usuário não sabe se os dados estão atualizados; tende a clicar repetidamente ou desconfiar da integração Meta.
**Recommendation**: Corrigir falha técnica (`update!` revalidava credenciais contra a Meta após fetch) e exibir mensagem de sucesso com contagem + erro específico da API quando falhar.
**Impact**: Feedback confiável; menos cliques redundantes e menos suporte.
**Implementation Notes**: Backend usa `update_columns` no sync; frontend usa `parseAPIErrorResponse` no toast.

### High Priority Improvements

#### Issue: Mensagens de feedback genéricas
**Current State**: Sucesso = "Templates sincronizados."; erro = "Falha ao sincronizar."
**Problem**: Não confirma quantos templates foram importados nem orienta correção (token, WABA, permissão).
**Recommendation**: Sucesso: `N template(s) sincronizado(s).`; erro: mensagem retornada pela API quando disponível.
**Impact**: Usuário entende resultado imediato da ação.

#### Issue: Falta de contexto temporal
**Current State**: Contagem estática sem "última sincronização".
**Problem**: Dificulta saber se precisa sincronizar de novo.
**Recommendation**: Exibir `Última sincronização: há X min` abaixo da contagem, usando `message_templates_last_updated`.
**Impact**: Reduz syncs desnecessários (heurística #8 — minimalismo).

### Medium Priority Enhancements

- Desabilitar botão Sincronizar quando sync recente (< 1 min) com tooltip "Aguarde antes de sincronizar novamente"
- Estado inline no botão: loading → sucesso breve (check) antes de voltar ao normal
- Link "Abrir no Gerenciador da Meta" com ícone externo mais evidente ao lado de "Criar Templates"

### Positive Observations

- Separação clara entre **Criar** (Meta) e **Sincronizar** (Chatwoot)
- Contagem `N template(s) aprovado(s)` dá visibilidade imediata do estado do inbox
- Botão com `is-loading` durante sync — boa prevenção de double-submit

---

## WhatsApp — Saúde da conta / Cobrança BSP (ago/2026)

### Summary

Revisão da aba **Saúde da conta** (`AccountHealth.vue` + `WhatsappPricingSummary.vue`) para contas **Embedded Signup / Tech Provider**. Logs repetiam erro da Meta sobre custo indisponível para BSP; a UI tratava como falha genérica em vez de estado esperado.

### Critical Issues

#### Issue: Erros de log para cenário BSP esperado
**Current State**: Backend logava `[WHATSAPP PRICING] Error` e `[INBOX PRICING] Error` a cada abertura da aba.
**Problem**: Polui logs de produção e sugere incidente quando o comportamento é normal para Tech Provider.
**Recommendation**: Detectar BSP/Embedded Signup cedo; não logar como erro; exibir card informativo na UI.
**Impact**: Operação mais limpa; admins entendem que cobrança fica na Meta/BSP.
**Implementation Notes**: `cost_unavailable_error?` ampliado; skip de API para `source: embedded_signup`.

### High Priority Improvements

#### Issue: Mensagem de erro genérica "Não foi possível carregar os gastos"
**Current State**: Falha de detecção do erro Meta → sem `error_code: partner_billing`.
**Problem**: Usuário pensa que integração quebrou.
**Recommendation**: Card neutro "Cobrança via parceiro Meta" + CTA para Business Suite (implementado).
**Impact**: Confiança e orientação clara.

### Medium Priority Enhancements

- Carregar pricing só ao abrir aba Saúde (lazy), não em todo `watch` do inbox
- Exibir badge "Via parceiro Meta" no título da seção Cobrança quando Embedded Signup

### Positive Observations

- `WhatsappPricingSummary` já tinha layout dedicado para BSP — faltava só acionar corretamente
- Botão "Abrir faturamento na Meta" é a ação certa para este perfil de conta

---

## Workflow Editor — Usabilidade do fluxo de atendimento (ago/2026)

### Summary

Revisão do editor em `/settings/automation/workflows/:id/edit` (`WorkflowEditor` + `WorkflowCanvas` + `WorkflowPropertiesPanel`), com foco **100% na usabilidade do operador** — não em visual cosmético.

**Como o fluxo funciona hoje (modelo mental real):**
1. Gatilho (evento) → nós no canvas (espera / condição / ação / IA)
2. Configuração no painel direito ao clicar no nó
3. Salvar (rascunho) ou Salvar e ativar; fluxo **ativo trava o diagrama** até desativar
4. Simular em modal separado; settings globais em outro modal

**Benchmark usado:** Zapier (step-first + test), Make (draft/publish), n8n (canvas + inspector persistente), ManyChat / Typebot (fluxo conversacional legível), Intercom Workflows (linguagem humana + erros no passo).

**Diagnóstico central:** o editor é **poderoso e visualmente competente**, mas pede mentalidade de “engenheiro de grafo”. Grandes players escondem o grafo atrás de **próximo passo óbvio**, **erro no passo**, **publicar sem medo** e **testar sem sair do contexto**.

**Design system (ui-ux-pro-max):** estilo Flat / AI-native leve, tipografia Plus Jakarta Sans, anti-patterns = chrome pesado + feedback lento. Priorizar progressive disclosure, error recovery e feedback de loading (UX guidelines).

---

### Critical Issues

#### Issue: Ativo = canvas bloqueado (ciclo desativar → editar → reativar)
**Status**: ✅ Mitigado (ago/2026) — CTA **Desativar para Editar** com confirmação one-click; badge readonly duplicado no canvas removido. Draft/publish completo continua no roadmap.
**Current State**: Banner único + botão primário desativa e destrava o diagrama; settings seguem editáveis.
**Problem**: Operador tem medo de mexer em fluxo em produção.
**Recommendation (próximo)**: Modelo **Rascunho / Publicado** com versão.
**Impact**: Sai do readonly em 1 confirmação, sem caçar o toggle.
**Implementation Notes**: `deactivateToEdit` + `ConfirmationModal` em `WorkflowEditor.vue`.

#### Issue: Erros de validação são “há N erros”, não “o que fazer”
**Status**: ✅ Implementado (ago/2026)
**Current State**: Banner com lista clicável, prev/next, foco no nó + painel.
**Problem**: Contagem sem lista não ensina o próximo clique.
**Recommendation**: Mantido — lista humanizada + navegação.
**Impact**: Erro → diagnóstico → recuperação no passo.
**Implementation Notes**: `WorkflowValidationBanner.vue` + `@focus-error`.

#### Issue: Inserir nó na aresta sempre cria “Ação”
**Status**: ✅ Implementado (ago/2026)
**Current State**: `+` abre picker de tipo (exceto gatilho); clique na aresta também mostra toolbar (touch-friendly).
**Problem**: Forçar ação quebrava o fluxo mental.
**Recommendation**: Mantido — popover no `+`.
**Impact**: Construção linear do fluxo.
**Implementation Notes**: `openEdgeInsertPicker` / `insertNodeOnEdge` em `WorkflowCanvas.vue`.

---

### High Priority Improvements

#### Issue: Painel de propriedades some ao desmarcar nó
**Current State**: `v-if="selectedNode"` — sem seleção, só canvas.
**Problem**: Perde âncora de contexto. n8n/Make mantêm inspector com empty state (“Selecione um passo” + atalhos).
**Recommendation**: Painel sempre visível; empty state com: último nó editado, checklist do fluxo (gatilho? ramos conectados?), atalho “Adicionar passo”.
**Impact**: Menos “sumiu tudo, e agora?”.

#### Issue: Catálogo de ações é `<select>` plano
**Current State**: `WORKFLOW_ACTION_TYPES` num select longo; labels mistos PT hardcoded vs i18n.
**Problem**: Hick’s Law — muitas opções sem busca/agrupamento. Zapier: search + categorias (Mensagem, CRM, Equipe…).
**Recommendation**: Combobox com busca + grupos (Mensagens · Atribuição · CRM · Integrações · IA). Remover strings hardcoded do panel (`Atendente`, `Pipeline e Estágio`, etc.) → i18n.
**Impact**: Achados de ação 3–5× mais rápidos; menos erro de escolha.

#### Issue: Dualidade Salvar / Salvar e ativar / Toggle Active
**Current State**: Três controles de “estado de vida” do fluxo na toolbar.
**Problem**: Modelo mental confuso: “salvei mas não está ativo?”, “ativei sem salvar o grafo?”.
**Recommendation** (se draft/publish ainda não vier):
- Um primário: **Salvar**
- Um secundário claro: **Ativar** / **Desativar** (não misturar com save)
- Remover “Salvar e ativar” **ou** torná-lo o único caminho de go-live
**Impact**: Menos estados inconsistentes na cabeça do usuário.

#### Issue: Simulação desconectada do canvas
**Current State**: `WorkflowSimulateModal` — timeline em modal; canvas não destaca o passo atual.
**Problem**: Operador não “vê” o caminho no diagrama. n8n/Typebot highlightam nós durante o teste.
**Recommendation**: Painel lateral de simulação; highlight + scroll-to-node a cada step; decisões de branch inline no nó (não só no modal).
**Impact**: Confiança antes de ativar (“eu entendi o que vai acontecer”).

#### Issue: Toolbar da aresta só no hover
**Status**: ✅ Parcial (ago/2026) — clique na aresta mostra toolbar; botões compactos no midpoint; âncoras idle ocultas; `+`/lixeira no hover do nó (estilo ManyChat/n8n).
**Current State**: `hideAnchors: true` + chrome de nó (`+` próximo passo, lixeira); toolbar de aresta 20px no meio da linha.
**Problem**: Bolinhas de porta confundiam operadores de atendimento.
**Impact**: Conectar = “próximo passo”, não “arrastar fio entre dots”.

#### Issue: Clique na paleta joga nó em posição aleatória
**Status**: ✅ Implementado (ago/2026)
**Current State**: Clique insere à direita do selecionado (ou folha com saída livre / centro da viewport) com auto-conexão; drop usa `clientToCanvasPoint` corretamente.
**Problem**: Antes: coords absolutas `(300±random)` + drop com `getPointByClient` errado → nó longe da área de trabalho.
**Impact**: Construir atendimento vira “adicionar próximo passo”.
**Implementation Notes**: `workflowNodePlacement.js` + `WorkflowCanvas.addNode` / `onCanvasDrop`.

---

### Medium Priority Enhancements

| # | Melhoria | Por quê (benchmark) |
|---|----------|---------------------|
| 1 | Undo/Redo visível na toolbar (+ tooltip Ctrl/Cmd+Z) | LogicFlow pode ter history; hoje é invisível |
| 2 | Outline / lista de passos (minimap leve) | Fluxos longos de atendimento; Make tem overview |
| 3 | Testar passo (não só WhatsApp externo) | Zapier “Test step” reduz medo de publicar |
| 4 | Linguagem humana na paleta: “Se (IF)” → “Se… então” | ManyChat evita jargão de programador |
| 5 | Empty state do canvas novo: 3 CTAs (gatilho WhatsApp / form / CRM) | Onboarding sem tour forçado |
| 6 | Banner readonly duplicado (faixa + pill no canvas) → um só + CTA “Desativar para editar” | Menos chrome (anti-pattern do design system) |
| 7 | Descrição do fluxo editável (hoje quase só nome na toolbar) | Operador nomeia mal; descrição ajuda equipe |
| 8 | Atalho Cmd/Ctrl+S documentado + feedback “Salvo” mais forte | Expectativa de apps modernos |
| 9 | Condições: modo simples (1–2 filtros) + “Avançado” | Progressive disclosure; FilterInput assusta |
| 10 | Deep link `?nodeId=` para abrir nó com erro/share | Deep linking guideline (Medium) |

---

### Low Priority Suggestions

- Agrupar nós de IA sob um único “Assistente” com subtipo (reduz paleta)
- Preview da mensagem no card do nó (ManyChat mostra 1ª linha no bubble)
- Contador “N passos · M ramos” no header
- Preferência “encaixar ao adicionar” (auto-layout leve, sem forçar)

---

### Positive Observations (preservar)

- Status Salvo / Não salvo / Salvando na toolbar — bom feedback de dirty state
- Highlight de nós inválidos + focus no primeiro erro ao salvar
- Confirmação de ativação com conflito de automações legadas (`WorkflowActivateConfirmModal`)
- Settings do fluxo já melhorados (abas Cliente · Inscrição · Equipe · Re-entrada)
- `prefers-reduced-motion` respeitado nas transitions do editor
- Inserir/`+` na aresta e zoom/fit — base certa de canvas moderno
- Teste de WhatsApp externo no painel — padrão “test step” a expandir

---

### Priorização sugerida (ROI usabilidade)

| Ordem | Item | Esforço | Ganho usuário |
|------:|------|---------|---------------|
| 1 | Lista clicável de erros de validação | P | Alto |
| 2 | Picker de tipo no `+` da aresta | P | Alto |
| 3 | ~~Inserir próximo ao selecionado + auto-conectar~~ ✅ | — | — |
| 4 | Simplificar Salvar vs Ativar (ou draft/publish) | M–G | Crítico |
| 5 | Combobox de ações com busca/grupos | M | Alto |
| 6 | Simulação ligada ao canvas | M | Alto |
| 7 | Inspector persistente (empty state) | P | Médio |
| 8 | Edge toolbar por click (não só hover) | P | Médio |

### Arquivos principais

```
app/javascript/dashboard/routes/dashboard/settings/workflows/WorkflowEditor.vue
app/javascript/dashboard/routes/dashboard/settings/workflows/WorkflowCanvas.vue
app/javascript/dashboard/routes/dashboard/settings/workflows/WorkflowPropertiesPanel.vue
app/javascript/dashboard/routes/dashboard/settings/workflows/WorkflowValidationBanner.vue
app/javascript/dashboard/routes/dashboard/settings/workflows/WorkflowSimulateModal.vue
app/javascript/dashboard/routes/dashboard/settings/workflows/constants.js
```

