# Diagnóstico — Lentidão inbox / workflow_enrollment_summaries

**Sintoma (produção):** app lento globalmente; ~40% do tráfego HTTP em `workflow_enrollment_summaries` (doc `docs/performance-lentidao-workflows-inbox.md`, 2026-09-25).

**Pergunta desta rodada:** existe comprovação **concreta** de bug no código (dev), não só narrativa de ops?

**Veredito:** **Sim — comprovação estrutural e reproduzível.** Comprovação de **impacto em produção** (40%, fila Puma) permanece evidência histórica de log; não foi re-coletada neste ambiente dev.

---

## Loop de feedback (red-capable)

Comando único (determinístico, ~1s, exit code 1 = bug presente):

```bash
node debug_outputs/performance-workflows-inbox/verify-structural-bug.mjs
```

Saída esperada quando o bug ainda existe: `BUG STRUCTURAL: 8/8 claims still true` e exit `1`.

Harness complementar (mecanismo Vue 2 + getter com sort):

```bash
node debug_outputs/performance-workflows-inbox/verify-getter-coupling.mjs
```

---

## Comprovação concreta (níveis)

### Nível A — Código estático (100% verificável no repo)

| # | Afirmação | Evidência |
|---|-----------|-----------|
| A1 | Watcher `conversationList` com `deep: true` chama refetch de summaries | `app/javascript/dashboard/components/ChatList.vue` L531–536 |
| A2 | Refetch envia até **50** IDs, sem comparar set de IDs visíveis | `ChatList.vue` L612–615 |
| A3 | `workflow_enrollment.updated` refetch **lista inteira**, não 1 ID | `ChatList.vue` L598–610 |
| A4 | Badge de lista usa `TimelineBuilder#step_counts` → `#build` (grafo) | `enrollment_summary_service.rb` L70–72; `timeline_builder.rb` L29–31 |
| A5 | Painel régua: `/active` no mount + `watch(conversationId)` | `useWorkflowEnrollment.js` L119–120 |

Isso prova **design defeituoso / acoplamento errado**, independente de carga.

### Nível B — Comportamento reproduzido (harness local, 2026-10-01)

Mini-app Vue 2 espelha: computed lista filtrada + sort por `last_activity_at` + `[...]` (como `getMineChats` + `ChatList.conversationList`) e watcher igual ao prod.

| Evento simulado | IDs visíveis mudam? | Watcher `deep: true` | Watcher raso |
|-----------------|---------------------|----------------------|--------------|
| `unread_count++` in-place | Não (101,102) | **1× handler** | 0× |
| `last_activity_at` (mensagem / cable) | Não | **1×** | **1×** |
| `Vue.set` linha (como `UPDATE_CONVERSATION`) | Não | **1×** | **1×** |

**Conclusão B:** mutações normais da inbox **disparam** refetch de summaries mesmo quando o conjunto de conversas visíveis não muda. Remover só `deep: true` **não** elimina o storm de mensagens (`last_activity_at` + array novo no computed).

Cadeia no prod (ActionCable → store → lista):

- `actionCable.js` `onMessageCreated`: `addMessage` + `updateConversationLastActivity` (L101–113)
- `ADD_MESSAGE` muta `chat.messages`, `unread_count`, `timestamp` (`conversations/index.js` L188–208)
- `UPDATE_CONVERSATION_LAST_ACTIVITY` muta `last_activity_at` (L108–115)

### Nível C — Produção (doc / ops, não reexecutado aqui)

| Evidência | Fonte |
|-----------|--------|
| ~40% requests = `workflow_enrollment_summaries` | nginx access log, amostra 20k–30k linhas |
| ~200–500 req/min, picos ~8/s | mesmo doc |
| TTFB login sobe com paralelismo (10 threads Puma) | teste no servidor, doc |
| CPU/RAM folgados | descarta “VPS fraca” como causa raiz |

**Isso prova magnitude e sintoma global**, não substituível por leitura de código sozinha — mas é **consistente** com A+B.

---

## O que **não** temos como comprovação neste dev

- Contagem de requests/min no nginx deste ambiente
- Profiler APM / fila Puma sob N agentes reais
- Teste Vitest/RSpect **no repo** que falhe hoje por este bug (gap de regressão)

---

## Categoria da causa

**Performance / arquitetura de frontend + endpoint incompatível com frequência de chamada** (não race, não corrupção de dados).

## Hipótese principal (falsificável)

> Se refetch só ocorrer quando o **set de IDs visíveis** mudar ou quando `workflow_enrollment.updated` atualizar **um** summary, então mutações `ADD_MESSAGE` / `last_activity_at` **não** devem gerar `GET workflow_enrollment_summaries`.

Predição do harness pós-fix: após mutação `unread_count` e `last_activity_at` com IDs fixos, `fetchCount === 0`.

---

## Aprovação

Nenhum patch aplicado nesta fase (safe-debug). Ver `PATCH_PLAN.md`.
