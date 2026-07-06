# Workflow graph schema (Fluxo de trabalho)

## Structure

```json
{
  "nodes": [
    {
      "id": "trigger_1",
      "type": "trigger",
      "position": { "x": 0, "y": 0 },
      "data": {
        "event_name": "conversation_created",
        "conditions": []
      }
    },
    {
      "id": "wait_1",
      "type": "wait",
      "data": { "duration": 24, "unit": "hours", "label": "Espera 24h" }
    },
    {
      "id": "wait_reply_1",
      "type": "wait_for_reply",
      "data": { "duration": 6, "unit": "hours", "label": "Aguardar resposta" }
    },
    {
      "id": "action_1",
      "type": "action",
      "data": {
        "action_name": "send_message",
        "action_params": ["Hello"]
      }
    },
    {
      "id": "condition_1",
      "type": "condition",
      "data": { "conditions": [] }
    },
    {
      "id": "ai_1",
      "type": "ai_outreach",
      "data": {
        "objective_preset": "reengagement",
        "tone_preset": "friendly",
        "language": "client",
        "prompt": "Retome o contato com o cliente de forma amigável.",
        "prompt_customized": false,
        "include_last_messages": true
      }
    }
  ],
  "edges": [
    { "id": "e1", "source": "trigger_1", "target": "wait_1" },
    { "id": "e2", "source": "condition_1", "target": "action_1", "sourceHandle": "true" },
    { "id": "e3", "source": "wait_reply_1", "target": "action_1", "sourceHandle": "replied" },
    { "id": "e4", "source": "wait_reply_1", "target": "action_2", "sourceHandle": "timeout" }
  ],
  "settings": {
    "cancel_on_contact_reply": false,
    "pause_on_contact_reply": true,
    "cancel_on_conversation_resolved": true,
    "allow_manual_start_only": false,
    "enroll_latest_conversation_only": true
  }
}
```

## Node types

| type | data fields |
|------|-------------|
| `trigger` | `event_name`, `conditions`, optional `inbox_id` (when `event_name` is `form_submitted`) |
| `wait` | `duration` (integer), `unit` (`minutes`, `hours`, `days`), optional `label` |
| `wait_for_reply` | `duration`, `unit`, optional `label` — waits for contact reply or timeout |
| `condition` | `conditions` (same format as automation rules) |
| `action` | `action_name`, `action_params` |
| `ai_outreach` | `objective_preset`, `tone_preset`, `language`, `prompt`, `prompt_customized`, `include_last_messages` |

### `ai_outreach` webhook payload

When the node executes on an API inbox with `webhook_url` configured, the server POSTs to that URL with:

- `event`: `"workflow.ai_outreach"`
- `prompt`: composed phrase (tone prefix + objective prompt, interpolated)
- `ai_config`: preset metadata (`objective_preset`, `tone_preset`, `language`, etc.)
- `workflow_id`, `workflow_node_id`, `enrollment_id`
- Standard `conversation.webhook_data` fields

Optional `context.last_messages` (last 5 public messages) is always included in the webhook payload.

### Trigger event: `form_submitted`

Starts the workflow when a published account form is submitted (public form page).

**Trigger `data` fields:**

| field | type | required | description |
|-------|------|----------|-------------|
| `event_name` | string | yes | Must be `form_submitted` |
| `inbox_id` | string/integer | yes | Inbox used to create a conversation when the contact has no open conversation |
| `conditions` | array | yes | Must include one `account_form_id` condition with `equal_to` and one or more published form IDs |

**Form filter condition:**

```json
{
  "attribute_key": "account_form_id",
  "filter_operator": "equal_to",
  "values": ["12", "34"]
}
```

Only **published** forms may appear in `values`. Multiple IDs mean any of those forms can trigger the workflow.

**Enrollment behavior:**

1. If the contact already has an **open conversation**, that conversation is used (most recently updated). `inbox_id` is ignored.
2. If there is **no open conversation**, a new open conversation is created in `inbox_id`.
3. If the submitted form ID is not in `conditions[].values`, no enrollment is created.

Example trigger node:

```json
{
  "id": "trigger_1",
  "type": "trigger",
  "data": {
    "event_name": "form_submitted",
    "inbox_id": "42",
    "conditions": [
      {
        "attribute_key": "account_form_id",
        "filter_operator": "equal_to",
        "values": ["12", "34"]
      }
    ]
  }
}
```

## Edge `sourceHandle` values

| Source node type | Allowed `sourceHandle` | Meaning |
|------------------|------------------------|---------|
| `condition` | `true`, `false` | Then / Else branch |
| `wait_for_reply` | `replied`, `timeout` | Customer replied / deadline expired |

Branch nodes (`condition`, `wait_for_reply`) must have at least one outbound edge.

## Enrollment runtime context

When an enrollment enters `wait_for_reply`, the server stores:

```json
{
  "reply_watch": {
    "node_id": "wait_reply_1",
    "baseline_at": "2026-06-02T12:00:00Z",
    "deadline_at": "2026-06-03T12:00:00Z"
  }
}
```

- Incoming contact messages after `baseline_at` (excluding workflow-generated messages) trigger the `replied` branch instead of pausing the enrollment.
- When the deadline passes without a reply, the `timeout` branch runs.

## Node type: `ai_wait_for_intent`

Waits for the customer to express a specific pre-defined intent. Two branches: `intent_detected` (match) and `timeout` (deadline expired without match).

### Node data

| field | type | required | description |
|-------|------|----------|-------------|
| `intent_key` | string | yes | One of the catalog keys: `menu_request`, `schedule_visit`, `payment_confirmed` |
| `duration` | integer | yes | Number of time units |
| `unit` | string | yes | `minutes`, `hours`, or `days` |

### Edges

- `sourceHandle: "intent_detected"` — customer message matched the intent
- `sourceHandle: "timeout"` — deadline passed without a match

### `intent_watch` context

While waiting, `context.intent_watch` holds:

```json
{
  "intent_watch": {
    "node_id": "intent_1",
    "intent_key": "menu_request",
    "baseline_at": "...",
    "deadline_at": "...",
    "classification_in_flight": false,
    "seen_normalized": ["oi"],
    "last_classification": {
      "message_id": 456,
      "matched": false,
      "skipped": true,
      "reason": "emoji_only",
      "at": "..."
    }
  }
}
```

### AI webhook contract

**Request** (POST to `WORKFLOW_AI_INTENT_WEBHOOK_URL`, timeout 5s):

```json
{
  "event": "workflow.ai_wait_for_intent",
  "intent_key": "menu_request",
  "intent": { "key": "...", "label": "...", "description": "...", "examples": ["..."] },
  "workflow_id": 1,
  "workflow_node_id": "intent_1",
  "enrollment_id": 42,
  "deadline_at": "...",
  "message": { "id": 456, "content": "...", "message_type": "incoming", "created_at": "..." },
  "context": { "recent_messages": [{ "content": "...", "message_type": "incoming" }] }
}
```

**Response** (HTTP 200):

```json
{ "matched": true }
```

Timeout, HTTP error, or missing `matched` → treated as `{ "matched": false }` (enrollment keeps waiting).

### Environment variable

```
WORKFLOW_AI_INTENT_WEBHOOK_URL=https://your-server/webhook/intent
```

Required. Nodes with this type will silently skip classification if the variable is not set.

### Pre-filter (layer 1 — structural signals only)

Messages matching any of the following are skipped without calling the AI:
- Empty or whitespace-only
- Emoji-only
- Punctuation only (`???`, `!!!`, `...`)
- Identical repetition (same normalized content already classified in this watch)

First occurrence of any message (including short ones like "oi") always reaches the classifier.

## Validation rules

- Exactly one `trigger` node
- Graph must be acyclic
- All nodes except trigger reachable from trigger
- `condition` edges use `sourceHandle`: `true` or `false`
- `wait_for_reply` edges use `sourceHandle`: `replied` or `timeout`
- `ai_wait_for_intent` edges use `sourceHandle`: `intent_detected` or `timeout`
- `action_name` must be in server allowlist
- `event_name` on trigger must be in server allowlist (includes `form_submitted`)
- `form_submitted` trigger requires `inbox_id` and at least one published form in `account_form_id` conditions
- Combined count of `wait`, `wait_for_reply`, and `ai_wait_for_intent` nodes ≤ 10
- `ai_wait_for_intent` requires `inteligencia_artificial` feature flag

## Settings

| key | default | description |
|-----|---------|-------------|
| `cancel_on_contact_reply` | `false` | Cancel enrollment when the contact sends a message |
| `pause_on_contact_reply` | `true` | Pause enrollment when the contact sends a message (does not apply during `wait_for_reply`) |
| `cancel_on_conversation_resolved` | `true` | Cancel enrollment when the conversation is resolved |
| `allow_manual_start_only` | `false` | Only allow starting via the conversation sidebar (no automatic triggers) |
| `enroll_latest_conversation_only` | `true` | When the contact has multiple open conversations, only enroll the most recently updated one |
