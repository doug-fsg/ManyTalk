# Fluxo de Atendimento (ManyTalks)

## Visão geral

**Fluxo de Atendimento** é a v2 das automações: sequências com **espera**, **condições** e **ações** em diagrama (LogicFlow).

**Automações clássicas (v1)** permanecem na aba ao lado; apenas administradores editam v1. Qualquer agente pode criar/editar fluxos.

## Limites atuais

- Editar **diagrama** exige fluxo **inativo** (use **Duplicar** ou desative para alterar nós)
- Editar **configurações** (cancelamento, re-enrollment, labels) funciona com fluxo **ativo**
- Máx. **15** ações `send_message` por fluxo
- Máx. **10** nós `wait` (combinado `wait` + `wait_for_reply`) por fluxo
- Cancelamento: resposta do cliente e conversa resolvida (configurável por fluxo)
- ⚠️ v1 e v2 com o mesmo gatilho podem executar simultaneamente — o sistema alerta **antes de ativar**

## Guia operacional — Fluxo + Automações v1 + IA

### Tríade (não competir)

| Camada | Quando usar |
|--------|-------------|
| **Automações v1** | Regra instantânea (assign, label, mensagem imediata) |
| **Fluxo v2** | Cadência ao longo de dias (espera, IF, follow-up) |
| **IA (n8n)** | Decisão por mensagem recebida |

### Checklist antes de ativar um fluxo

1. **Simular** no editor (botão play) — validar ramificações sem enviar mensagens
2. **Revisar conflitos** — se houver Automação v1 com o mesmo gatilho, desative a v1 ou ajuste condições
3. **Configurar cancelamentos** (engrenagem → Configurações):
   - `Cancelar quando atendente responder` — **ligado** em follow-up e vendas
   - `Cancelar por labels` — ex.: `humano-ativo`, `ia-ativo` (n8n aplica a label ao assumir)
   - `Pausar quando cliente responder` — padrão ligado
4. **Re-enrollment** — ligar em fluxos de reativação/recompra (template “Reativação 30d”)

### Padrão IA (n8n) + fluxo

```
Fluxo envia cadência → n8n responde mensagens → label ia-ativo cancela/pausa fluxo
Agente assume → cancel_on_agent_reply ou label humano-ativo
Retomar cadência → iniciar enrollment manual na Régua ou via API
```

Ver também: [`inteligencia-artificial.md`](./inteligencia-artificial.md), [`fluxo-de-atendimento-melhorias.md`](./fluxo-de-atendimento-melhorias.md).

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
