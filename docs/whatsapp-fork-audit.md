# WhatsApp Fork Audit (F0)

> Fork Chatwoot ~3.9.0 · Referência: `chatwoot-develop` ~4.9.1 (read-only)

## Customizações preservadas

| Área | Fork | Ação |
|------|------|------|
| Grupos `@g.us` | `IncomingMessageWhatsappCloudService` | **Não alterado** — echo usa service isolado |
| Assinatura agente | `WhatsappCloudService#format_content` | Mantido |
| Workflows | `WorkflowListener` custom | Guard `external_echo` adicionado |
| `unoapi` | Provider ativo | Mantido; fora de regressão coexistência |
| `send_template` | `(message, phone, info)` | Assinatura preservada |

## Delta implementado

### Coexistência (`whatsapp_coexistence`)

- `IncomingMessageEchoService` — handler dedicado para `smb_message_echoes`
- `WhatsappEventsJob` — mutex por contato, roteamento echo, fallback canal sem metadata
- `MessageDedupLock` — dedup atômico Redis SET NX
- Listeners — ignoram `content_attributes.external_echo`
- Rake `whatsapp:resubscribe_webhooks`

### Templates (`whatsapp_enhanced_templates`)

- `TemplateProcessorService` + converter + populate
- `SendOnWhatsappService` — legacy flat quando flag off; enhanced quando flag on
- `WhatsappCloudService#template_body_parameters` — componentes header/body/button
- Frontend `templateHelper.js` + `TemplateParser.vue` evoluído (Vue 2)

## Payloads Meta

Golden master: `spec/fixtures/whatsapp/echo_payload.json`

## Verificação

```bash
bundle exec rspec spec/services/whatsapp/incoming_message_echo_service_spec.rb \
  spec/jobs/webhooks/whatsapp_events_job_coexistence_spec.rb \
  spec/listeners/workflow_listener_echo_spec.rb \
  spec/services/whatsapp/template_processor_service_spec.rb
```
