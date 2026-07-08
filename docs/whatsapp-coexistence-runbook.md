# Runbook: Coexistência WhatsApp + Templates

## Pré-requisitos

- Feature flags em `config/features.yml` (default `false`)
- Canal `whatsapp_cloud` com webhook Meta configurado
- `FRONTEND_URL` apontando para instância de produção/staging

## Rollout (F6)

### 1. Re-subscribe webhooks (obrigatório antes do canary)

```bash
bundle exec rake whatsapp:resubscribe_webhooks
```

Confirma inscrição em `messages` + `smb_message_echoes` via `FacebookApiClient`.

### 2. Habilitar coexistência (canary)

No Super Admin ou console:

```ruby
account = Account.find(ID)
account.enable_features!('whatsapp_coexistence')
```

**Teste:** envie mensagem pelo app WhatsApp Business → deve aparecer no Chatwoot como `outgoing` com `external_echo: true`, sem reenvio.

### 3. Habilitar templates enhanced

```ruby
account.enable_features!('whatsapp_enhanced_templates')
```

**Teste:** template com header IMAGE/DOCUMENT + botão URL nos 3 fluxos (ReplyBox modal, ConversationForm).

### 4. Rollback

```ruby
account.disable_features!('whatsapp_coexistence')
account.disable_features!('whatsapp_enhanced_templates')
```

Echo deixa de ser processado; UI volta ao payload flat legado.

## Monitoramento

- Logs: `[WhatsappEventsJob] Failed to acquire lock` — webhook concorrente; job faz retry
- Mensagens echo duplicadas — verificar `MessageDedupLock` / `source_id` presente no create
- Workflows disparando em echo — verificar `external_echo` em `content_attributes`

## Ordem fixa

1. Deploy código
2. `rake whatsapp:resubscribe_webhooks`
3. Canary 48h (`whatsapp_coexistence`)
4. Templates (`whatsapp_enhanced_templates`)
5. Rollout gradual por account
