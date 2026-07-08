# Plano: Coexistência WhatsApp + Templates

> Fork 3.9.0 · prod · develop = referência read-only  
> **ADD > PATCH > REPLACE** · `unoapi` fora de escopo

---

## Objetivo

| # | Escopo | Rollback |
|---|--------|----------|
| 1 | **Coexistência** — echo do app Business → Chatwoot (`outgoing`, `external_echo`) | flag `whatsapp_coexistence` |
| 2 | **Templates** — header mídia, body nomeado, botões URL | flag `whatsapp_enhanced_templates` |

---

## Armadilhas backend (antes de codar)

| Risco | Mitigação |
|-------|-----------|
| Workflows/automações reagem a echo outgoing | listeners ignoram `external_echo` |
| Echo sem `source_id` → reenvio ao cliente | `source_id = wamid` no create |
| Echo sem `metadata` → canal nil | fallback URL / `message_echoes.from` |
| Echo via CloudService (grupos) | **só** `IncomingMessageEchoService` |
| `is_present?` | trocar por `present?` |
| Flag no meio de `features.yml` | **append no final** |

---

## Armadilhas frontend (F5)

| Risco | Mitigação |
|-------|-----------|
| Payload flat quebra backend enhanced | helper gera `{ body, header, buttons }` |
| Só BODY no parser hoje | ler HEADER/BUTTONS de `template.components` |
| 3 pontos de entrada desalinhados | mesmo payload nos 3 fluxos |
| Portar `components-next` | **proibido** — evoluir Vue 2 existente |
| Flag on sem UI | header/botão só após F5; body legado continua flat |

**Entradas (todas usam `TemplateParser.vue`):**
- `ReplyBox` → `WhatsappTemplates/Modal.vue` (conversa aberta)
- `ConversationForm.vue` → `WhatsappTemplates.vue` (nova conversa)
- Spec: `shared/mixins/specs/whatsappTemplates/whatsappTemplates.spec.js`

**Contrato hoje → alvo:**

```js
// hoje (flat — OK com flag off + converter backend)
processed_params: { "1": "João", "2": "123" }

// flag on + F5 (enhanced)
processed_params: {
  body: { "1": "João" },
  header: { media_url, media_type, media_name? },
  buttons: [{ type: "url", parameter: "..." }]
}
```

**UI:** manter `woot-input`, `woot-button`, Vuelidate, i18n `whatsappTemplates.json` (pt_BR/en/es). Sem shadcn/Radix.

---

## Flags

```yaml
# append only — final do features.yml
- name: whatsapp_coexistence
  enabled: false
- name: whatsapp_enhanced_templates
  enabled: false
```

---

## Fases

```
F0 Audit ─► F1 Flags ─► F2 Coexist ─► F3 Harden ─► F6 Rollout
                └──► F4 Templates BE ─► F5 Templates FE ──┘
```

| Fase | Entregas-chave | Verify |
|------|----------------|--------|
| **F0** | audit doc · payloads Meta · branch | T0.5 confirma metadata echo |
| **F1** | 2 flags append | default false |
| **F2** | `IncomingMessageEchoService` · job route · listeners · fallback canal · `present?` | workflow OK · sem reenvio |
| **F3** | golden master · dedup lock · mutex · rake re-subscribe | dup webhook = 1 msg |
| **F4** | 3 services novos · wire send_on/cloud · manter assinatura `send_template` | specs BE |
| **F5** | `templateHelper.js` · `TemplateParser.vue` · i18n · spec JS | 3 fluxos UI · staging |
| **F6** | E2E → **re-subscribe** → canary 48h → ondas → runbook | ordem fixa |

**F5 detalhe (PR-6):**
| ID | O quê |
|----|-------|
| T5.0 | Inventariar template Meta real (IMAGE/DOC/URL) no inbox piloto |
| T5.1 | `dashboard/helper/templateHelper.js` — parse components, build enhanced payload |
| T5.2 | `TemplateParser.vue` — campos header mídia + botões; preview body; validação |
| T5.3 | i18n pt_BR + regressão spec existente |
| T5.4 | Smoke: ReplyBox modal + ConversationForm + flag off = payload flat intacto |

Coexistência pode ir a canary **antes** de F4/F5.

---

## PRs (≤400 linhas)

| PR | Escopo |
|----|--------|
| 0 | F0 docs/payloads |
| 1 | flags |
| 2 | F2 coexist |
| 3 | F3 hardening |
| 4–5 | F4 templates BE |
| 6 | F5 frontend |
| 7 | F6 canary/runbook |

---

## Done

**Coexistência:** echo visível · `source_id` no create · workflows OK · re-subscribe antes canary

**Templates:** flag off = body flat OK · flag on = header/botão nos 3 fluxos · failed gracioso

```bash
# BE
bundle exec rspec spec/services/whatsapp/incoming_message_echo_service_spec.rb \
  spec/jobs/webhooks/whatsapp_events_job_coexistence_spec.rb \
  spec/listeners/workflow_listener_echo_spec.rb \
  spec/services/whatsapp/template_processor_service_spec.rb

# FE
pnpm test shared/mixins/specs/whatsappTemplates/whatsappTemplates.spec.js
```

---

## Checklist PR

**BE:** audit diff · echo ≠ CloudService · `external_echo` listeners · flags no final  
**FE:** 3 entry points · payload contract · spec JS verde · flag off = regressão visual  
**Geral:** flags false · PR < 400 linhas

---

## Decisões pendentes

1. Inbox piloto canary?  
2. BSUID? (após T0.5)  
3. Templates enhanced por account?  
4. Staging existe?

---

## Próximo passo

**T0.1 + T0.5** → **PR-1** → **PR-2** (coexist) · **PR-6** só após **PR-5**

**Refs BE:** `whatsapp_events_job.rb` · `workflow_listener.rb` · `send_on_whatsapp_service.rb`  
**Refs FE:** `WhatsappTemplates/TemplateParser.vue` · `ReplyBox.vue` · `ConversationForm.vue`
