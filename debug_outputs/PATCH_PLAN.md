# Patch plan — Filtros Kanban (data)

**Modo:** safe-debug — **não aplicar** sem aprovação explícita  
**Diagnóstico:** `debug_outputs/DIAGNOSIS.md`

---

## Prioridade

| Pri | ID | Ação | Risco | Savepoint? |
|-----|-----|------|-------|------------|
| 1 | C1 | Finalizar / revisar / commit do WIP já presente (payload `_pipeline_*` + FilterService + refetch) | médio | branch recomendada |
| 2 | C2 | Garantir bound de dia no mesmo fuso que o usuário (ex. `America/Sao_Paulo` ou timezone da conta) | baixo-médio | opcional |
| 3 | C3 | Já no WIP (promover open→all com data); só revisar copy/UX se necessário | baixo | não |

---

## P1 — Entregar WIP de filtro server-side (C1)

**Já existe no working tree (não commitado):**

- `app/services/contacts/filter_service.rb` — `_pipeline_created_at|deal_value|assignee_id|win_lost`
- `app/javascript/.../kanbanFilterQueryHelper.js` (+ spec)
- `KanbanAttributes.vue` — `buildKanbanQueryPayload` + `reloadContactsForActiveFilters`
- `KanbanFilters.vue` — normalize range + promote winLost
- Specs Ruby/Vitest

**Menor fix adicional se algo faltar na review:** nenhum refactor — só validar que `loadContactsPage` (lista) e `loadAllContacts` (kanban) usam o mesmo payload.

**Testes mínimos antes do merge:**

1. Spec Ruby: range inclusivo `2026-10-06` com `Time.zone = America/Sao_Paulo` (já no WT)
2. Vitest: `normalizeKanbanDateRange` + `matchesKanbanDateRange` (já no WT)
3. Manual: funil > página; filtrar um dia conhecido; card fora do dia some; card no dia aparece; ganho no dia aparece após auto-`all`

**Não fazer:** refatorar FilterService genérico, renomear operadores, migrar timezone de toda a app sem necessidade.

---

## P2 — Alinhar fuso do bound (C2) — só se C1 mergeado e runtime for UTC

**Opções (escolher a menor):**

A. `config.time_zone = 'America/Sao_Paulo'` (se produto for BR-only) — impacto global; precisa de buy-in.  
B. Em `parse_pipeline_day_bound`, usar zona fixa do produto / `ActiveSupport::TimeZone['America/Sao_Paulo']` só para kanban.  
C. Passar offset/timezone do browser no payload e interpretar no backend — mais correto multi-região, maior escopo.

**Recomendação conservadora:** confirmar `Time.zone.name` no processo Rails em runtime. Se já for `America/Sao_Paulo` (initializer/ENV), **P2 dispensável**. Se for `UTC`, preferir **B** localizado ao kanban.

---

## P3 — Sem patch obrigatório

- C4/C5/C6: OK ou já tratado.
- Não alterar label i18n sem pedido de produto.

---

## Aprovação necessária

- [ ] Aprovar merge/commit do WIP (P1)  
- [ ] Aprovar ou dispensar P2 após checagem de `Time.zone` em runtime  

Nenhuma mutação de código feita nesta sessão de diagnóstico.
