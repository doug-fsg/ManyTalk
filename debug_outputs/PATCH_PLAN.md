# Plano de patch (propostas — **não aplicadas**)

Requer aprovação explícita antes de qualquer mudança no repositório (safe-debug).

---

## Prioridade P0 — Segurança

### P0.1 Validar assinatura Meta nos POSTs de webhook

- Implementar verificação `X-Hub-Signature-256` com App Secret (config por app ou `GlobalConfig`).
- Rejeitar com `401` se assinatura inválida; manter GET `verify` como está.
- Testes: payload válido/inválido, body raw preservado (middleware ou `request.raw_post`).

**Risco:** médio (pode bloquear webhooks se secret errado). **Mitigação:** feature flag + log de falhas de assinatura antes de enforce.

---

## Prioridade P1 — Entrega BR e campanhas

### P1.1 Destino canônico na saída

- Extrair helper (ex. `Whatsapp::OutboundRecipient`) que:
  - Parte de `contact_inbox.source_id` e `contact.phone_number`
  - Usa `BrazilPhoneNormalizer.lookup_variants` / preferência pelo `wa_id` mais longo válido
  - Usar em `send_template_message` e `send_session_message`
- Specs cobrindo 12 vs 13 dígitos (casos AGTU).

**Risco:** baixo-médio (mudança de `to` para contatos legados). **Mitigação:** log estruturado quando `to` normalizado ≠ `source_id`.

### P1.2 Saneamento dados inbox 610 (one-off ops)

- Relatório dos `contact_inboxes` com mismatch; corrigir `source_id` onde Meta `wa_id` conhecido (script aprovado, não commit automático).

### P1.3 Campanha: sucesso atrelado ao envio real

- Substituir `sleep(2)` por: aguardar `message.source_id` ou `message.failed?` com timeout (ex. 30–60s) via polling ou callback após `SendReplyJob`.
- Contar falha se timeout sem `source_id`.

**Risco:** médio (jobs mais longos). **Mitigação:** timeout configurável.

---

## Prioridade P2 — Janela e templates

### P2.1 `can_reply?` / modo de envio

- Opções (escolher uma com produto):
  - UI bloqueia sessão quando `can_reply?` false (já parcial)
  - Ou: fora da janela, falhar cedo com mensagem clara em vez de POST que gera 131047
  - Avaliar não forçar template quando `template_params` presente mas intenção é sessão (`send_mode` explícito)

### P2.2 Persistir erro Meta completo

- Em `process_response`, merge em `content_attributes` (`meta_error_code`, `fbtrace_id`, `error_data`).

---

## Prioridade P3 — Resiliência

### P3.1 Status webhook atrasado

- Fila de retry ou `find_message_by_source_id` com backoff quando status chega antes do `source_id`.

### P3.2 Unificar versão Graph API

- Usar `api_version` também em `phone_id_path` / `media_url`; testar em staging.

---

## O que **não** entra em patch de código (cliente AGTU)

- Reduzir marketing / melhorar qualidade WABA / ticket Meta para 131000 com número correto — ações **Meta + operação**.

---

## Aprovação sugerida por etapa

1. P0.1 (segurança) — branch dedicado + deploy com flag  
2. P1.1 + specs — menor diff, alto valor BR  
3. P1.3 — campanhas  
4. P2/P3 — conforme capacidade
