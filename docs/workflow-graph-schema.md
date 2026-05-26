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
      "data": { "duration": 24, "unit": "hours" }
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
    }
  ],
  "edges": [
    { "id": "e1", "source": "trigger_1", "target": "wait_1" },
    { "id": "e2", "source": "condition_1", "target": "action_1", "sourceHandle": "true" }
  ],
  "settings": {
    "cancel_on_contact_reply": true,
    "cancel_on_conversation_resolved": true
  }
}
```

## Node types

| type | data fields |
|------|-------------|
| `trigger` | `event_name`, `conditions` |
| `wait` | `duration` (integer), `unit` (`minutes`, `hours`, `days`) |
| `condition` | `conditions` (same format as automation rules) |
| `action` | `action_name`, `action_params` |

## Validation rules

- Exactly one `trigger` node
- Graph must be acyclic
- All nodes except trigger reachable from trigger
- `condition` edges use `sourceHandle`: `true` or `false`
- `action_name` must be in server allowlist
