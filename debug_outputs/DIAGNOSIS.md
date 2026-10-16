# Diagnóstico — Filtros do Kanban (foco em data)

**Modo:** safe-debug (somente leitura; sem mutação de código)  
**Data:** 2026-10-16  
**Escopo:** filtros do CRM/Kanban, principalmente intervalo de datas (`dateFrom` / `dateTo`)

---

## 1. Escopo da análise

| Camada | Arquivos |
|--------|----------|
| UI | `KanbanFilters.vue`, `Header.vue`, `KanbanAttributes.vue` |
| Helpers FE | `kanbanDateFilterHelper.js`, `kanbanFilterQueryHelper.js` (WIP), `pipelinePositionsHelper.js` |
| API/Backend | `Contacts::FilterService` (`_pipeline_created_at` etc.) |
| Specs | `kanbanDateFilterHelper.spec.js`, `kanbanFilterQueryHelper.spec.js`, `filter_service_spec.rb` |

Há **duas bases** a considerar:

1. **HEAD (commitado)** — o que o repositório considera “oficial” hoje  
2. **Working tree (WIP não commitado)** — correção em andamento nos mesmos arquivos

---

## 2. Veredicto

**Não está OK no HEAD.** O filtro por data (e demais filtros de deal/assignee/labels/win-lost no payload) **não vai para a API**; só filtra no cliente o que já foi carregado.

**O WIP corrige o buraco crítico** (payload + backend + refetch). Parse de `YYYY-MM-DD` no browser já está correto no HEAD (commit `5b0beb54`).

**Risco residual no WIP (médio, não bloqueante se Time.zone = BRT):** backend usa `Time.zone` da app; `config.time_zone` **não está setado** em `config/application.rb` → Rails default **UTC**. Cliente usa fuso do browser. Em bordas de dia (meia-noite BRT) pode haver divergência servidor vs UI.

---

## 3. Achados ranqueados

### C1 — Crítico (HEAD): filtros kanban só no cliente

**Evidência:** em HEAD, `loadAllContacts` / `loadContactsPage` montam payload só com `is_present` do funil (+ busca). Datas/deal/assignee/labels/win-lost **não entram** no `contacts/filter`.

`handleFiltersChanged` só faz re-filtro local (`handleSearch`), **sem refetch**.

**Efeito:**

- Pipeline grande (limite `maxContactsToLoad: 5000`) → cards fora do lote carregado **nunca aparecem** mesmo batendo a data.
- Contagens / colunas podem ficar erradas sob filtro de data.
- Modo lista pagina no backend **sem** os filtros de data → página “filtrada” incompleta.

**WIP:** `buildKanbanFilterPayloadItems` + `_pipeline_*` no `FilterService` + `reloadContactsForActiveFilters()` → resolve C1 se mergeado/deployado.

---

### C2 — Médio (WIP): dia civil no backend vs browser

**Backend (WIP):**

```ruby
# parse_pipeline_day_bound → Time.zone.parse → beginning_of_day / end_of_day
# comparators inclusivos: >= início, <= fim
```

**Frontend:** `parseLocalDateString` / `matchesKanbanDateRange` no **fuso local do browser**.

**App:** sem `config.time_zone` → tipicamente **UTC**.

**Efeito (ex. usuário em America/Sao_Paulo):** card criado 06/10 22:00 BRT (= 07/10 01:00 UTC) pode ser **excluído no SQL** ao filtrar “06/10–06/10”, e nunca chegar ao cliente. O re-filtro FE não recupera o que a API não devolveu.

**Nota:** o comentário no WIP diz “fuso da conta/app”, mas Account **não** aplica timezone no FilterService; é só `Time.zone` global.

---

### C3 — Baixo/médio (HEAD, parcialmente coberto no WIP): default win/lost + data

Default UI = `open`. Filtrar por data com status `open` **esconde** ganhos/perdidos do período.

**WIP:** promove `open` → `all` ao escolher data, se o usuário não tocou status (`winLostTouchedByUser`). Comportamento sensato.

HEAD também fazia `winLostFilter = filters.winLost || 'all'` no handler (inconsistente com default `open` do componente).

---

### C4 — Baixo: intervalo invertido / valor 0

**WIP:** `normalizeKanbanDateRange` troca from/to; deal `0` preservado com `??` (antes `||` zerava). OK.

---

### C5 — Baixo / produto: `created_at` vs `entered_at`

Filtro usa `contact_pipeline_positions.created_at` (criação do card no funil).  
i18n PT: “Data de entrada no funil”; EN: “Created in pipeline”.  
`entered_at` muda ao trocar estágio — **não** é o campo filtrado. Semântica alinhada com “entrada no funil”, desde que ninguém espere “entrada na etapa atual”.

---

### C6 — Já corrigido (HEAD): parse UTC de `YYYY-MM-DD`

Commit `5b0beb54` + testes Vitest com `America/Sao_Paulo` — evita o clássico “dia anterior” com `new Date("YYYY-MM-DD")`. **Não reabrir.**

---

## 4. Categoria da causa

| Item | Categoria |
|------|-----------|
| C1 | Incomplete filter pipeline (client-only) |
| C2 | Timezone bound mismatch (server UTC vs browser local) |
| C3 | Default filter interaction (UX) |
| C6 | Fixed timezone parse (historical) |

---

## 5. O que NÃO é bug

- Operadores nomeados `is_greater_than` / `is_less_than` com SQL `>=` / `<=` no WIP: intencional (dia inteiro inclusivo).
- Re-filtro client-side **depois** do fetch: defesa em profundidade; só vira problema se C2 estiver ativo.
- Labels assignee derivados dos contatos carregados: limitação UX, não quebra o filtro de data.

---

## 6. Confiança

| Afirmação | Confiança |
|-----------|-----------|
| C1 existe no HEAD | **alta** (diff + leitura direta do payload) |
| WIP fecha C1 | **alta** (código + specs Ruby/Vitest no WT) |
| C2 é real em produção se Time.zone=UTC | **média-alta** (código + ausência de `config.time_zone`; falta confirmar `Time.zone` no runtime) |
| Parse FE de data OK | **alta** (testes + commit) |

---

## 7. Próximo passo (sem mutação até aprovação)

Ver `debug_outputs/PATCH_PLAN.md`. Prioridade: **entregar WIP (C1)**; em seguida alinhar fuso do bound de data (C2) se o runtime for UTC.
