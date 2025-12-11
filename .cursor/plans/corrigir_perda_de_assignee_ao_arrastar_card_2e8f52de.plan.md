---
name: Corrigir perda de assignee ao arrastar card
overview: "Ao arrastar um card, o código está enviando assignee_id: null, fazendo o backend tentar remover o assignee. Precisamos preservar o assigneeId atual ao mover o card, passando o valor atual em vez de null."
todos: []
---

# Corrigir perda de assignee ao arrastar card

## Problema

Quando um agente (não-admin) arrasta e solta um card, o assignee (dono) é perdido porque:

1. `onItemMoved` passa `null` como `assigneeId` ao chamar a API
2. A API envia `assignee_id: null` para o backend
3. O backend tenta remover o assignee (permitido apenas para admin)
4. O resultado é que o card fica sem dono
5. 



[Kanban Move] API Error: {status: 403, error: 'Sem permissão para trocar dono', contactId: 3, pipelineId: 17, cardAssigneeId: 2, …}cardAssigneeId: 2contactId: 3currentUserId: 2error: "Sem permissão para trocar dono"pipelineId: 17status: 403[[Prototype]]: Object

KanbanAttributes.vue:1696 [Kanban Move] Pre-request check: {contactId: 3, pipelineId: 17, cardAssigneeId: 2, currentUserId: 2, isAdmin: false, …}cardAssigneeId: 2contactId: 3currentUserId: 2isAdmin: falseisViewerMode: falsepipelineId: 17sendingAssigneeId: null[[Prototype]]: Object



## Solução

**Arquivo**: `app/javascript/dashboard/routes/dashboard/crm/components/KanbanAttributes.vue`

No método `onItemMoved`, linha 1717:

- Obter o `currentAssigneeId` do `currentPosition` (já está sendo obtido nas linhas 1683-1687)
- Passar `currentAssigneeId` ao invés de `null` para preservar o dono atual ao mover
- Isso garantirá que o assignee seja preservado tanto para admin quanto para agente

## Mudança necessária

```javascript
// Linha ~1686-1687: já obtém currentPosition, adicionar:
const currentAssigneeId = currentPosition?.assignee?.id || null;

// Linha ~1717: mudar de:
null // Não enviar assignee_id

// Para:
currentAssigneeId // Preservar assignee atual ao mover
```

## Resultado esperado

- Agente arrasta card → assignee é preservado
- Admin arrasta card → assignee é preservado
- Só remove assignee quando explicitamente selecionado "None" no modal (admin apenas)