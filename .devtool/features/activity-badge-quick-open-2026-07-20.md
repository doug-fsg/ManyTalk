---
id: "activity-badge-quick-open-2026-07-20"
status: "backlog"
priority: "critical"
assignee: null
dueDate: null
created: "2026-07-20T21:34:00.000Z"
modified: "2026-07-20T21:34:00.000Z"
completedAt: null
labels: ["kanban", "activities", "ux"]
order: "a1"
---

# Badge de atividades abre modal na aba correta

## Problema

Badge em `KanbanCard.vue` usa `@click.stop` sem ação.

## Aceite

- [ ] Clique no badge abre `KanbanCardModal` com `initialTab: 'activities'`
- [ ] Destaque visual para próxima atividade pendente ou vencida
- [ ] CTA "Nova atividade" visível no topo da aba

## Referência

`KanbanCard.vue` L231-241 · `KanbanCardModal.vue` activeTab default
