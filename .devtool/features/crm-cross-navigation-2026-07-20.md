---
id: "crm-cross-navigation-2026-07-20"
status: "backlog"
priority: "critical"
assignee: null
dueDate: null
created: "2026-07-20T21:34:00.000Z"
modified: "2026-07-20T21:34:00.000Z"
completedAt: null
labels: ["crm", "navigation", "activities", "kanban"]
order: "a2"
---

# Navegação cruzada Kanban ↔ Atividades

## Problema

Kanban e Calendário são itens de menu separados sem atalhos contextuais.

## Aceite

- [ ] Header do Kanban: link "Atividades" + badge de vencidas hoje
- [ ] Header do calendário: link "Funil" preservando filtros de responsável
- [ ] `ActivityDetailModal`: botão "Abrir no funil" com deep link
- [ ] Estado compartilhado de filtro (query ou Vuex `crmContext`)

## Referência

`Header.vue` · `ActivitiesCalendar.vue` · `ActivityDetailModal.vue`
