# Fluxo de Atendimento (ManyTalks)

## Visão geral

**Fluxo de Atendimento** é a v2 das automações: sequências com **espera**, **condições** e **ações** em diagrama (LogicFlow).

**Automações clássicas (v1)** permanecem na aba ao lado; apenas administradores editam v1. Qualquer agente pode criar/editar fluxos.

## Limites atuais

- Editar diagrama exige fluxo **inativo**
- Máx. **15** ações `send_message` por fluxo
- Máx. **10** nós `wait` (combinado `wait` + `wait_for_reply`) por fluxo
- Cancelamento: resposta do cliente e conversa resolvida (configurável por fluxo)
- ⚠️ v1 e v2 com o mesmo gatilho podem executar simultaneamente — revise suas Automações clássicas para evitar duplicidades

## API

`GET/POST /api/v1/accounts/:account_id/workflows`

Ver `docs/workflow-graph-schema.md` para o JSON do grafo.

### Ativação com validação

Tanto `toggle_active` quanto `update` com `active: true` **validam o grafo** antes de ativar. Um fluxo inválido não pode ser ativado.

## Filas Sidekiq

- `Workflows::ProcessEventJob` — fila `medium`
- `Workflows::StepJob` — fila `medium` (após waits)

## Gatilhos disponíveis

| Gatilho | Descrição |
|---------|-----------|
| `conversation_created` | Nova conversa criada |
| `conversation_updated` | Conversa atualizada |
| `conversation_opened` | Conversa reaberta |
| `conversation_resolved` | Conversa resolvida |
| `message_created` | Mensagem criada |
| `manual` | Início manual via painel da conversa |
| `contact_kanban_stage_changed` | Estágio do CRM alterado |
| `contact_kanban_stage_idle` | Contato parado no mesmo estágio do CRM |
