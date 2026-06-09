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
| `trigger` | `event_name`, `conditions` |
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

## Validation rules

- Exactly one `trigger` node
- Graph must be acyclic
- All nodes except trigger reachable from trigger
- `condition` edges use `sourceHandle`: `true` or `false`
- `wait_for_reply` edges use `sourceHandle`: `replied` or `timeout`
- `action_name` must be in server allowlist
- Combined count of `wait` and `wait_for_reply` nodes ≤ 10

## Settings

| key | default | description |
|-----|---------|-------------|
| `cancel_on_contact_reply` | `false` | Cancel enrollment when the contact sends a message |
| `pause_on_contact_reply` | `true` | Pause enrollment when the contact sends a message (does not apply during `wait_for_reply`) |
| `cancel_on_conversation_resolved` | `true` | Cancel enrollment when the conversation is resolved |
| `allow_manual_start_only` | `false` | Only allow starting via the conversation sidebar (no automatic triggers) |
| `enroll_latest_conversation_only` | `true` | When the contact has multiple open conversations, only enroll the most recently updated one |
