---
id: "crm-unified-contact-hub-2026-07-20"
status: "backlog"
priority: "critical"
assignee: null
dueDate: null
created: "2026-07-20T21:34:00.000Z"
modified: "2026-07-20T21:34:00.000Z"
completedAt: null
labels: ["crm", "ux", "contacts"]
order: "a0"
---

# Hub unificado no perfil do contato

## Problema

`ContactManageView` só tem aba Notas. Links do Kanban e das atividades levam para página sem CRM.

## Aceite

- [ ] Abas: Resumo CRM, Atividades, Notas, Conversas
- [ ] Resumo mostra pipeline, estágio, valor, responsável
- [ ] Links externos abrem perfil na aba correta via query (`?tab=activities`)
- [ ] Botão voltar retorna ao Kanban quando `returnUrl` presente

## Referência

`specs/general/UI-IMPROVEMENTS.md` — Critical: Perfil de contato desconectado
