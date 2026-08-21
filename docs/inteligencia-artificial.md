# Inteligência Artificial — Fluxo de Atendimento

## Nós de IA disponíveis

| Tipo | Descrição |
|------|-----------|
| `ai_outreach` | Envia mensagem gerada pela IA para o cliente |
| `ai_conversation_analysis` | Analisa as últimas mensagens e grava resultado em nota privada ou WhatsApp |
| `ai_wait_for_intent` | Aguarda o cliente expressar uma intenção do catálogo antes de avançar |

## Feature flag

Todos os nós de IA requerem a feature `inteligencia_artificial` habilitada na conta.

## Webhook único

```
WORKFLOW_AI_URL=https://seu-servidor/webhook/ai
```

As três opções de IA usam a mesma URL. O receptor distingue pelo campo `event`:

| `event` | Nó | Modo |
|---------|-----|------|
| `workflow.ai_outreach` | Chamar cliente | Assíncrono |
| `workflow.ai_conversation_analysis` | Avaliar conversa (nota privada) | Assíncrono |
| `workflow.ai_wait_for_intent` | Aguardar intenção | Síncrono (≤5s, responde `{ "matched": true\|false }`) |

Destino WhatsApp na análise **não** usa essa URL.

---

## `ai_wait_for_intent` — Aguardar intenção

### Contrato síncrono

O endpoint deve:
- Aceitar `POST` com `Content-Type: application/json`
- Responder em **≤ 5 segundos** (timeout configurável via `WEBHOOKS_TRIGGER_TIMEOUT`)
- Retornar HTTP 200 com corpo `{ "matched": true }` ou `{ "matched": false }`

Timeout, erro HTTP ou JSON inválido → tratado como `matched: false` (enrollment permanece aguardando).

Sem `WORKFLOW_AI_URL`, a classificação é ignorada (`no_webhook_url`).

### Evento webhook

```json
{
  "event": "workflow.ai_wait_for_intent",
  "intent_key": "menu_request",
  "intent": {
    "key": "menu_request",
    "label": "Cardápio",
    "description": "Cliente quer ver o menu ou cardápio",
    "examples": ["quero o cardápio", "manda o menu"]
  },
  "workflow_id": 1,
  "workflow_node_id": "intent_1",
  "enrollment_id": 42,
  "deadline_at": "2026-06-20T15:00:00Z",
  "message": {
    "id": 456,
    "content": "quero ver o cardápio",
    "message_type": "incoming",
    "created_at": "2026-06-20T14:30:00Z"
  },
  "context": {
    "recent_messages": [
      { "content": "oi", "message_type": "incoming" },
      { "content": "Olá! Como posso ajudar?", "message_type": "outgoing" },
      { "content": "quero ver o cardápio", "message_type": "incoming" }
    ]
  }
}
```

### Catálogo de intenções

Catálogo horizontal com busca no editor — não amarrado a um nicho. Exemplos:

| `intent_key` | Label |
|--------------|-------|
| `schedule_visit` | Agendar visita |
| `quote_request` | Pedido de orçamento |
| `technical_support` | Suporte técnico |
| `cancellation` | Cancelamento |
| `payment_confirmed` | Pagamento confirmado |
| `product_info` | Informações do produto |
| `order_status` | Status do pedido |
| `human_agent` | Falar com atendente |
| … | Ver `Workflows::Constants::AI_INTENT_CATALOG` |

Campo opcional no nó: `intent_description` — refinamento enviado à IA (máx. 500 caracteres).

### Ramos

- `intent_detected` — intenção detectada antes do prazo
- `timeout` — prazo expirou sem match

### Pré-filtro (camada 1)

Mensagens estruturalmente triviais são ignoradas sem chamar a IA:
- Vazia ou só espaço
- Só emoji
- Só pontuação repetida (`???`, `!!!`, `...`)
- Repetição idêntica (mesmo conteúdo normalizado já visto neste watch)

O primeiro "oi" **sempre** vai ao classificador — apenas repetições são bloqueadas.

### Instrumentação

Logs estruturados emitidos por `AiWaitForIntentService` e `IntentClassificationJob`:

- `intent_classify.result` = `matched | not_matched | skipped | error`
- `intent_classify.duration_ms`
- `intent_classify.skip_reason`
- `intent_classify.prefilter_saved` = `true | false`
