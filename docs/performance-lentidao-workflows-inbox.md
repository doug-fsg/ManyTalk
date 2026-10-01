# Lentidão no app (inbox) — causa raiz e plano de correção

**Data da análise:** 2026-09-25  
**Ambiente:** produção — https://app.manytalks.com.br/  
**Escopo:** Chatwoot ManyTalks (feature custom de Workflows / Régua)  
**Status:** correção estrutural aplicada no código (frontend + endpoint de lista leve) — validar tráfego nginx em produção no deploy

---

## Resumo executivo

A lentidão relatada pelos clientes **não é falta de CPU/RAM da VPS**.  
A causa raiz é a **feature custom de Workflows**: a lista de conversas dispara um volume enorme de requests HTTP de summary de enrollment, saturando o Puma. Com a fila cheia, **toda a aplicação** fica lenta (login, inbox, envio de mensagem, etc.).

| Item | Veredito |
|------|----------|
| Causa raiz | **Código** (acoplamento errado frontend ↔ API de workflows) |
| Amplificador | Puma com pouca concorrência (`WEB_CONCURRENCY`) |
| VPS (CPU/RAM/disco) | Folgada no momento da análise — **não é o problema** |
| Paliativo aplicado | `WEB_CONCURRENCY` 2 → 3 (somente capacidade Puma) |
| Correção definitiva | Refatorar fetch de badge/summary na inbox + endpoint leve |

> Subir worker/thread **sozinho** não resolve o problema de fundo: apenas atrasa o colapso. O tráfego inútil (~40% do total) continua.

---

## Sintomas

- Vários clientes reclamando de lentidão geral no sistema
- Sensação de “travamento” sob uso normal da inbox (vários agentes online)
- HTML/login sozinho responde rápido quando não há contenção; sob carga paralela o TTFB sobe forte

---

## Evidências (produção, 2026-09-25)

### Infra no momento da coleta

- CPU ociosa ~87–97%, ~77 GB RAM livres, iowait ~0%
- DB `chatwoot_production` ~11 GB; tabela `messages` ~7 GB / ~5,2M linhas
- Sidekiq: filas ativas vazias (não era backlog de jobs)
- Puma (antes do paliativo): `WEB_CONCURRENCY=2`, `RAILS_MAX_THREADS=5` → **10 requests concorrentes**
- Máquina: 20 CPUs / 94 GB RAM

### Contenção no Puma (teste local no servidor)

| Carga paralela em `/app/login` | TTFB p50 | max |
|--------------------------------|----------|-----|
| 1 request | ~50–80 ms | — |
| 20 paralelos | ~288 ms | ~470 ms |
| 30 paralelos | ~558 ms | ~907 ms |

Conclusão: com poucas threads, qualquer pico vira fila e o cliente sente lentidão global.

### Tráfego HTTP (nginx) — smoking gun

Amostra ~20k–30k linhas de access log de `app.manytalks.com.br`:

| Endpoint | Participação aprox. |
|----------|---------------------|
| `GET /api/v1/accounts/:id/workflow_enrollment_summaries` | **~40% de todo o tráfego** |
| `GET .../conversations/:id/workflow_enrollments/active` | ~12% |
| Soma relacionada a workflows | **~50%+** |

Ritmo de `workflow_enrollment_summaries`: **~200–500 requests/minuto** (picos ~8/s), com dezenas de agentes/IPs ativos.

Concentração por conta (exemplo no log do dia): a conta `88` sozinha gerou dezenas de milhares de calls desse endpoint.

### O que a VPS NÃO era

- Não havia saturação de CPU, RAM ou disco
- Não havia lock storm prolongado no Postgres no momento da coleta
- Filas Sidekiq não estavam acumulando trabalho ativo

Itens secundários observados (não priorizar como “a” lentidão da inbox):

- Alertas nginx: cache SSL `le_nginx_SSL` cheio (`ssl_session_cache shared:le_nginx_SSL:10m`)
- Sidekiq `dead` = 9999 (falhas SMTP / limite Gmail) — problema paralelo de e-mail
- Postgres com `shared_buffers=128MB` / `effective_cache_size=4GB` (conservador demais para o hardware; risco médio conforme o banco cresce)

---

## Causa raiz (código)

### Frontend — acoplamento destrutivo

Arquivo: `app/javascript/dashboard/components/ChatList.vue`

```js
conversationList: {
  handler() {
    this.debouncedFetchEnrollmentSummaries();
  },
  deep: true,
},
// debounce de 300ms
```

**Problema:** `deep: true` faz com que **qualquer mutação** em qualquer conversa da lista dispare o fetch de summaries (até 50 IDs).

O Chatwoot core muta essa lista o tempo todo via ActionCable / Vuex, de forma legítima:

- nova mensagem (`ADD_MESSAGE`)
- update de conversa (`UPDATE_CONVERSATION`)
- unread / last_seen
- assignee, status, etc.

Essas mutações são normais. O bug é **reatir API de workflow nelas**.

Já existe o evento ActionCable `workflow_enrollment.updated` (e listener no próprio `ChatList.vue`), mas a lista **não usa isso como fonte principal** — ela refetch em massa a cada ripple da store.

Há ainda o painel da régua:

- `app/javascript/dashboard/composables/useWorkflowEnrollment.js` → `getActive` no `onMounted` / `watch(conversationId)`
- Isso explica o volume alto de `/workflow_enrollments/.../active`

### Backend — endpoint pesado demais para badge de lista

Arquivos:

- `app/controllers/api/v1/accounts/workflow_enrollment_summaries_controller.rb`
- `app/services/workflows/enrollment_summary_service.rb`
- `app/services/workflows/timeline_builder.rb`

Para montar o badge da lista, o service:

1. Resolve conversations com `id OR display_id`
2. Busca enrollments `in_progress` com `includes(:workflow, :workflow_step_executions)`
3. Para cada enrollment chama `TimelineBuilder#step_counts`, que internamente faz `build` (timeline/grafo completo)

Isso é aceitável sob demanda no painel da conversa.  
É **inaceitável** na frequência atual da inbox (centenas de vezes por minuto × N agentes).

### Cadeia do problema

```
mensagem / typing / last_seen / webhook WhatsApp
        ↓
Vuex muta objeto na conversationList
        ↓
watcher deep:true → GET workflow_enrollment_summaries (até 50 IDs)
        ↓
EnrollmentSummaryService (+ TimelineBuilder completo)
        ↓
Puma com poucas threads satura
        ↓
fila → login, inbox, envio, tudo lento para todos os clientes
```

---

## Paliativo já aplicado (produção)

**Somente capacidade do Puma — sem correção de código.**

| Antes | Depois |
|-------|--------|
| `WEB_CONCURRENCY=2` (10 req concorrentes) | `WEB_CONCURRENCY=3` (15 req concorrentes) |

- Arquivo: `.env` (`WEB_CONCURRENCY=3`)
- Serviço reiniciado: `chatwoot-web.1.service`
- Sidekiq **não** foi alterado
- Confirmado no boot: `Workers: 3`, login HTTP 200

**Importante para o time:** isso é **temporário**. O storm de `workflow_enrollment_summaries` continua. Se a base de agentes/contas crescer, a lentidão volta.

---

## O que o time de dev deve fazer (correção definitiva)

### 1. Frontend — prioridade máxima

Arquivo principal: `app/javascript/dashboard/components/ChatList.vue`

Objetivos:

1. **Remover `deep: true`** do watcher de `conversationList`
2. Só refetch quando o **conjunto de IDs visíveis** mudar (comparar set de IDs, não deep equality de objetos)
3. Em `workflow_enrollment.updated`:
   - atualizar **somente** o summary da conversa afetada no estado local, **ou**
   - refetch pontual daquele ID — **não** refetch de até 50 conversas a cada evento irrelevante
4. Ideal: o payload do ActionCable `workflow_enrollment.updated` já trazer os campos do badge, eliminando round-trip HTTP na maior parte dos casos
5. Revisar `useWorkflowEnrollment` / `ReguaPanel` para não spamar `/active` (cache local + invalidação pelo mesmo evento de cable)

### 2. Backend — endpoint de lista leve

Arquivos: `EnrollmentSummaryService`, `TimelineBuilder`

Objetivos:

1. Badge da lista **não** deve chamar `TimelineBuilder#build` completo
2. Resposta mínima sugerida para a lista:
   - `enrollment_id`, `workflow_id`, `workflow_name`, `status`
   - `current_node_label` / `current_node_type` (barato)
   - `step_index` / `total_steps` só se puder ser calculado sem walk pesado do grafo (ou omitir na lista)
3. Timeline completa permanece no endpoint `/workflow_enrollments/active` (painel da régua), sob demanda

### 3. Só depois — capacidade / infra (não confundir com bugfix)

Após o tráfego de workflows cair para níveis saudáveis:

1. Reavaliar `WEB_CONCURRENCY` / `RAILS_MAX_THREADS` + `DB_POOL`
2. Ajustar Postgres ao hardware (`shared_buffers`, `effective_cache_size`)
3. Aumentar `ssl_session_cache` do nginx (alertas atuais de cache cheio)
4. Tratar dead queue / SMTP (problema paralelo)

Ordem correta: **código (1 → 2) → infra (3)**.  
Fazer (3) antes de (1)/(2) é paliativo.

---

## Critérios de aceite (como validar a correção)

1. Em access log de produção, `workflow_enrollment_summaries` deixa de ser ~40% do tráfego (meta: ordem de magnitude menor; tipicamente só quando a lista de IDs muda ou enrollment realmente muda)
2. Abrir inbox com vários agentes + tráfego WhatsApp **não** gera burst contínuo de summaries a cada mensagem/typing
3. Badge na lista continua correto ao receber `workflow_enrollment.updated`
4. Painel da régua (`/active` + timeline) continua funcional ao abrir a conversa
5. Sob carga real, TTFB de endpoints core (login, conversations, messages) não degrada por fila no Puma causada por workflows

### Como medir (ops / QA)

```bash
# Participação do endpoint (amostra do access.log)
tail -n 20000 /var/log/nginx/access.log | grep -c workflow_enrollment_summaries
tail -n 20000 /var/log/nginx/access.log | grep -c 'app.manytalks.com.br'

# Ritmo por minuto
grep workflow_enrollment_summaries /var/log/nginx/access.log | \
  awk '{print $4}' | cut -d: -f1-3 | uniq -c | tail
```

---

## Arquivos-chave para o PR

| Área | Arquivo |
|------|---------|
| Watcher / fetch lista | `app/javascript/dashboard/components/ChatList.vue` |
| API client summaries | `app/javascript/dashboard/api/workflowEnrollmentSummaries.js` |
| Badge no card | `ConversationItem.vue`, `ConversationCard.vue`, `regua/*` |
| Painel / active | `useWorkflowEnrollment.js`, `ReguaPanel.vue` |
| Cable | `app/javascript/dashboard/helper/actionCable.js` |
| Controller | `app/controllers/api/v1/accounts/workflow_enrollment_summaries_controller.rb` |
| Service | `app/services/workflows/enrollment_summary_service.rb` |
| Timeline pesada | `app/services/workflows/timeline_builder.rb` |

---

## Mensagem curta para colar no chat/ticket

> A lentidão em produção não é a VPS. A feature de Workflows/Régua está gerando ~40% de todo o tráfego HTTP via `workflow_enrollment_summaries`, porque o `ChatList.vue` faz watcher `deep: true` na `conversationList` e refetch a cada mutação da store (mensagem, unread, etc.). Isso satura o Puma e deixa o app inteiro lento. Já subimos `WEB_CONCURRENCY` 2→3 como paliativo. Correção real: parar o deep-watch, atualizar badge só por mudança de IDs / evento `workflow_enrollment.updated`, e deixar o endpoint de lista leve (sem `TimelineBuilder` completo).

---

## Histórico

| Data | Ação |
|------|------|
| 2026-09-25 | Análise read-only; causa raiz identificada no código de workflows |
| 2026-09-25 | Paliativo: `WEB_CONCURRENCY=3` + restart `chatwoot-web.1` |
| 2026-10-01 | Correção: watcher por set de IDs + badge via cable; summary de lista sem TimelineBuilder |
