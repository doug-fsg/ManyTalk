# Diagnóstico — WhatsApp Cloud (ManyTalks)

**Data:** 2026-10-21  
**Modo:** safe-debug (somente leitura do código + relatórios existentes em `docs/reports/`)  
**Escopo:** problemas **verificáveis** no código; sem patch aplicado.

---

## Resumo

Além do bug já documentado (destino na **saída** sem alinhar variantes BR do `contact_inbox.source_id`), há **outros defeitos reais**, mas **nenhum** equivale a “plataforma inteira fora do ar”. O que mais degrada operação em produção continua sendo **limites e qualidade Meta** (ex.: 131049), não regressão única no core.

Classificação usada:

| Nível | Significado |
|-------|-------------|
| **Crítico** | Perda silenciosa massiva, segurança grave explotável com baixo esforço, ou canal inutilizável para todos os clientes por bug de código |
| **Grave** | Falhas frequentes de envio/recebimento, métricas falsas em campanha, ou risco de segurança relevante |
| **Médio** | Impacto limitado a subset de contatos/fluxos ou inconsistência de status/UI |
| **Baixo** | Edge case, observabilidade, débito técnico |

---

## Achados confirmados (ordenados por severidade)

### 1. Webhook POST sem validação `X-Hub-Signature-256` — **Grave (segurança)**

**Evidência:** não há referência a `Hub-Signature` / `X-Hub` no repositório. O controller aceita qualquer corpo e enfileira o job:

- `app/controllers/webhooks/whatsapp_controller.rb` → `perform_later(params.to_unsafe_hash)` + `head :ok`
- Rota: `POST webhooks/whatsapp/:phone_number` (`config/routes.rb`)

**O que pode ocasionar:** quem conhece ou descobre o número E.164 na URL pode **injetar eventos falsos** (mensagens/status), poluir conversas, disparar automações ou confundir atendentes. A verificação GET (`hub.verify_token`) **não protege** POSTs.

**Nota:** padrão herdado do Chatwoot upstream; ainda assim é **verdadeiro** no fork.

**Crítico?** Não automaticamente — depende de exposição da URL e camadas externas (WAF, secret na URL). Para SaaS multi-tenant, tratar como **grave** até haver assinatura com App Secret.

---

### 2. Assimetria entrada/saída do destino BR (9º dígito) — **Grave (entrega), baixa frequência global**

**Evidência:**

- Entrada: `Contacts::BrazilPhoneNormalizer` em `ContactInboxWithContactBuilder` / `processed_waid`
- Saída template: sempre `contact_inbox.source_id` (`send_on_whatsapp_service.rb:35`)
- Saída sessão: `source_id` cru, fallback só para UUID (`send_on_whatsapp_service.rb:115-121`)

**O que pode ocasionar:** POST rejeitado pela Meta (ex. **131000**), mensagem `failed`, campanhas/follow-ups perdidos para contatos com mismatch (286 na inbox 610 no relatório AGTU).

**Crítico?** **Não** — ~0,12% dos 131000 em 30 dias no caso AGTU; **grave** para contatos afetados e para confiança em BR.

---

### 3. Campanha WhatsApp marca sucesso com `sleep(2)` — **Grave (dados operacionais)**

**Evidência:** `app/jobs/campaigns/send_contact_job.rb` cria mensagem (assíncrono `SendReplyJob`) e após **2 segundos** considera sucesso se `message.failed?` for falso.

**O que pode ocasionar:** fila lenta ou falha após 2s → campanha **conta envio OK** enquanto a mensagem falha depois (131049, 131000, token, etc.). Relatório de campanha **mentiroso**; decisões comerciais erradas.

**Crítico?** Não para entrega individual (mensagem ainda pode falhar na UI), mas **grave** para governança de disparos em massa.

---

### 4. `can_reply?` ≠ janela real da Meta — **Grave (entrega), médio em volume**

**Evidência:** `Conversation#can_reply?` usa só **última mensagem incoming** + 24h (`conversation.rb:124-163`). Não consulta estado da Graph API nem janelas abertas por template utility/auth.

**O que pode ocasionar:**

- Fora da janela Meta mas `can_reply?` true → `send_session_message` → **131047** (re-engagement) ou outro erro.
- Dentro de janela aberta por template, mas sem incoming recente → força template (`template_params` ou `!can_reply?`) → mais **marketing** e **131049**.

**Crítico?** Não; **grave** em contas com muito follow-up (caso AGTU).

---

### 5. `template_params` presente força template mesmo dentro de 24h — **Médio/Grave (custo e 131049)**

**Evidência:** `should_send_template_message = template_params.present? || !message.conversation.can_reply?` (`send_on_whatsapp_service.rb:19-21`).

**O que pode ocasionar:** automações/macros/campanhas com `template_params` sempre pagam categoria template e contam limite de marketing, mesmo quando texto livre seria permitido na sessão.

**Crítico?** Não; alinha com dor **131049** do relatório AGTU.

---

### 6. Status webhook ignorado se mensagem ainda não tem `source_id` — **Médio**

**Evidência:** `process_statuses` faz `return unless find_message_by_source_id(...)` (`incoming_message_base_service.rb:46-48`). `source_id` só é gravado após resposta HTTP em `process_response`.

**O que pode ocasionar:** corrida entre webhook `delivered`/`read`/`failed` e `SendReplyJob` → status **não atualiza**; UI pode ficar desatualizada (permanece `sent`). Falha tardia via webhook pode não refletir se o lookup falhar.

**Crítico?** Não.

---

### 7. Webhooks descartados com canal em `reauthorization_required` — **Médio (perda enquanto dura)**

**Evidência:** `Webhooks::WhatsappEventsJob#channel_is_inactive?` retorna true se `reauthorization_required?` (`whatsapp_events_job.rb:81-86`).

**O que pode ocasionar:** durante token inválido/expirado, **mensagens recebidas não entram** até reconectar (Meta não reenvia indefinidamente).

**Crítico?** Não — comportamento defensivo; impacto **grave** só se reconexão demorar.

---

### 8. Resolução de canal por payload Meta frágil — **Médio**

**Evidência:** `get_channel_from_wb_payload` exige `phone_number` **e** `phone_number_id` iguais ao DB; senão tenta eco (`whatsapp_events_job.rb:101-113`).

**O que pode ocasionar:** `provider_config['phone_number_id']` desatualizado → canal `nil` → webhook **logado e ignorado** (`Inactive WhatsApp channel`).

**Crítico?** Não; configuração/ops.

---

### 9. Versão Graph `v13.0` no envio vs `v22.0` em templates — **Baixo (débito técnico)**

**Evidência:** `phone_id_path` fixo em v13.0; `api_version` default v22.0 (`whatsapp_cloud_service.rb:102-117`, TODO no arquivo).

**O que pode ocasionar:** em teoria, comportamento divergente ou depreciação futura; **não há prova** de ser causa dos 131000 (maioria dos envios funciona).

**Crítico?** Não.

---

### 10. Corpo completo do erro Meta não persistido — **Baixo (observabilidade)**

**Evidência:** `process_response` grava só `external_error` humanizado (`whatsapp_cloud_service.rb:251-260`).

**O que pode ocasionar:** suporte sem `fbtrace_id` no banco; diagnóstico mais lento (já citado nos relatórios AGTU).

---

## O que **não** classificamos como bug crítico de código

| Sintoma relatório AGTU | Causa principal verificada |
|------------------------|----------------------------|
| 79,5% falhas 131049 | Limite marketing Meta + qualidade YELLOW + volume |
| 131000 com destino “correto” | Meta / throttling / genérico — maioria dos casos |
| Token OK em health check | Canal não “desconectado” no sentido de credencial |

---

## Referências de código

| Arquivo | Tema |
|---------|------|
| `app/services/whatsapp/send_on_whatsapp_service.rb` | Destino saída, template vs sessão |
| `app/controllers/webhooks/whatsapp_controller.rb` | Webhook POST |
| `app/jobs/webhooks/whatsapp_events_job.rb` | Canal inativo, roteamento |
| `app/jobs/campaigns/send_contact_job.rb` | `sleep(2)` sucesso campanha |
| `app/models/conversation.rb` | `can_reply?` |
| `app/services/whatsapp/incoming_message_base_service.rb` | Status webhook |
| `app/services/whatsapp/providers/whatsapp_cloud_service.rb` | Envio, erros, versão API |
