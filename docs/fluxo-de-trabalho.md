# Fluxo de trabalho (ManyTalks)

## Visão geral

**Fluxo de trabalho** é a v2 das automações: sequências com **espera**, **condições** e **ações** em diagrama (LogicFlow).

**Automações clássicas (v1)** permanecem na aba ao lado; apenas administradores editam v1. Qualquer agente pode criar/editar fluxos.

## Limitações MVP

- Editar diagrama exige fluxo **inativo**
- Máx. 5 ações `send_message` e 3 nós `wait` por fluxo
- Cancelamento: resposta do cliente e conversa resolvida (configurável)
- v1 e v2 no mesmo gatilho podem executar ambos

## API

`GET/POST /api/v1/accounts/:account_id/workflows`

Ver `docs/workflow-graph-schema.md` para o JSON do grafo.

## Filas Sidekiq

- `Workflows::ProcessEventJob` — fila `medium`
- `Workflows::StepJob` — fila `medium` (após waits)
