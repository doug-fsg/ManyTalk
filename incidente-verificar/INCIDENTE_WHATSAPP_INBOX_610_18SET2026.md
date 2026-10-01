# Incidente — WhatsApp Cloud API — Inbox 610 (AGTU)

**Data do incidente:** 2026-09-18  
**Plataforma:** ManyTalks (Chatwoot self-hosted)  
**Host:** `173.249.22.227` (`vmi1313120.contaboserver.net`)  
**Escopo:** somente **account 88 (AGTU)** / **inbox 610** — canal nativo **WhatsApp Cloud API** (não QuePasa/n8n)  
**Documento irmão (logs brutos):** `INCIDENTE_WHATSAPP_INBOX_610_LOGS_18SET2026.md`

---

## 1. Resumo executivo (para outra IA ou operador)

Um cliente AGTU reportou falha ao enviar mensagem no WhatsApp com erro:

```text
133010: (#133010) Account not registered
```

**Conclusão:** o erro vem da **Meta Graph API** no job `SendReplyJob` do Chatwoot. O token OAuth gravado no **channel_whatsapp id=18** continua **válido**, mas **não tem mais permissão sobre o WABA** configurado no inbox (`1432484038007576`) nem sobre o `phone_number_id` (`832656013256861`). Outros inboxes WhatsApp Cloud da mesma conta AGTU e **todas as demais contas** no app ManyWP **não foram alterados** no servidor.

**Correção necessária:** reconexão **Embedded Signup / Reauthorize** no inbox 610 **ou** readicionar o WABA ao system user/app ManyWP no Meta Business Manager, depois reconectar o inbox se o token do canal não voltar a enxergar o WABA.

---

## 2. Identificação do recurso

| Campo | Valor |
|--------|--------|
| Account ID | **88** |
| Account name | **AGTU** |
| Inbox ID | **610** |
| Inbox name | **001 - WhatsApp Comercial API** |
| `channel_whatsapp.id` | **18** |
| Provider | `whatsapp_cloud` |
| Source | `embedded_signup` |
| Telefone | **+554187814116** |
| Phone Number ID (Meta) | **832656013256861** |
| WABA ID (`business_account_id`) | **1432484038007576** |
| Meta Business ID (`meta_business_id`) | **9774056182620615** |
| `channel_whatsapp.updated_at` | 2026-08-10 12:32:48 UTC (sem mudança de token desde ago/2025) |

**Unicidade:** consulta no Postgres — **único** canal/inbox em todo o Chatwoot usando WABA `1432484038007576`.

---

## 3. O que NÃO é este incidente

| Camada | Relação |
|--------|---------|
| QuePasa / whatsmeow | **Não** — inbox 610 é Cloud API direto no Chatwoot |
| n8n `from-chatwoot` / `to-chatwoot` | **Não** — envio via `Whatsapp::Providers::WhatsappCloudService` |
| Rate limit nginx n8n (503) | **Não** |
| App ManyWP global quebrado | **Não** — outros WABAs no mesmo token pattern funcionam; problema isolado ao WABA do 610 |

---

## 4. Significado do erro Meta 133010

Referência oficial (resumo): código **133010** = *Phone number not registered on the WhatsApp Business Platform* / mensagem UI *Account not registered*.

Na prática, na Cloud API, isso aparece quando:

- o número não completou registro Cloud API (`POST /{phone-number-id}/register`), **ou**
- o número foi **desregistrado** / desconectado, **ou**
- o token usado **não tem acesso** ao `phone_number_id` / WABA (caso observado aqui após escalada para erro **100**).

---

## 5. Linha do tempo (2026-09-18)

**Fusos:**

- Timestamps **Postgres `messages.created_at`** → tratados como **UTC**
- **`journalctl` no host** → **UTC-3** (BRT), ~3h atrás do UTC do banco

| UTC (banco) | BRT (journal) | Evento |
|-------------|---------------|--------|
| ~18:58:38 | ~15:58:38 | Último outbound **entregue** (status 1/2) no inbox 610 |
| ~18:59:31 | ~15:59:31 | Primeiros `133010` no `chatwoot-worker` (`SendReplyJob`) |
| 18:59–19:28 | 15:59–16:28 | Rajada de 133010; **11** mensagens com `external_error` 133010 |
| ~19:00+ | ~16:00+ | Erros **Graph 100** (objeto `832656013256861` inexistente ou sem permissão) |
| Após ~19:28 UTC | — | **Nenhum** envio bem-sucedido (status 1/2) no inbox 610 |
| ~17:00 BRT investigação | — | Tentativa conservadora `register_phone!` canal 18 → falha (100) |
| ~17:00 BRT | — | `prompt_reauthorization!` **somente** canal 18; Redis flag + e-mail admins AGTU |

---

## 6. Evidências — banco de dados

### 6.1 Mensagens com erro 133010 (inbox 610, 18/09/2026)

11 registros com:

```json
{"external_error":"133010: (#133010) Account not registered"}
```

IDs e horários (UTC):

| message_id | created_at (UTC) |
|------------|------------------|
| 11500245 | 2026-09-18 18:59:31 |
| 11500271 | 2026-09-18 19:00:25 |
| 11500281 | 2026-09-18 19:00:54 |
| 11500287 | 2026-09-18 19:01:01 |
| 11500338 | 2026-09-18 19:02:46 |
| 11500438 | 2026-09-18 19:07:59 |
| 11500690 | 2026-09-18 19:19:27 |
| 11500697 | 2026-09-18 19:19:41 |
| 11500710 | 2026-09-18 19:19:56 |
| 11500763 | 2026-09-18 19:21:39 |
| 11500893 | 2026-09-18 19:28:08 |

**Último envio OK (UTC):** `2026-09-18 18:58:38.627265` (message outbound status 1 ou 2).

### 6.2 Outras falhas no mesmo inbox no mesmo dia (contexto)

Falhas outbound status=3 em **2026-09-18** (inbox 610), por categoria:

| Categoria | Quantidade |
|-----------|------------|
| Meta marketing limit (24h) | 57 |
| **133010 Account not registered** | **11** |
| 130472 User experiment | 7 |
| 131026 Message undeliverable | 7 |
| Graph 100 permission/object | 5 |
| Template invalid/missing | 2 |

Ou seja: mesmo após corrigir o 133010, parte do volume comercial pode continuar falhando por **limite de marketing** e **templates** — problemas **distintos** do registro/permissão WABA.

### 6.3 Histórico 133010 em outros inboxes

Mensagens com 133010 no banco (30 dias): inbox **610** (11) e inbox **625** (10, pico 2026-09-11). Inbox 625 é outro cliente/canal — **fora do escopo** desta intervenção.

---

## 7. Evidências — token Meta (canal 18, sem expor segredo)

Via `Whatsapp::FacebookApiClient#debug_token` (Rails runner, produção):

```text
TOKEN_VALID=true
EXPIRES=0                    # token de system user (sem expiração curta)
SCOPES=whatsapp_business_management,whatsapp_business_messaging,public_profile
CONFIGURED_WABA=1432484038007576
WABA_IN_TOKEN=false          # WABA do inbox 610 NÃO está nos target_ids do token
ALL_WABA_IDS=1056474917082964,968174166323197,2218904355400478,1404250911843898,1244561064435764,1504143044123314
```

**Interpretação:** o Chatwoot ainda guarda `business_account_id=1432484038007576`, mas o **token do canal 18 não lista esse WABA** nos escopos granulares. O token autentica como **ManyWP System User** (`GET /me`), porém **não autoriza** operações no phone number configurado.

Comparação canal **19** (inbox 611, AGTU): mesmo conjunto de WABAs no token; `CONFIGURED_WABA=1504143044123314` → **`WABA_IN_TOKEN=true`**.

---

## 8. Evidências — Graph API (probe read-only)

Estado na verificação (2026-09-18, pós-incidente):

| channel_id | inbox | phone_number_id | GET status |
|------------|-------|-----------------|------------|
| **18** | **610** | 832656013256861 | **Erro 100** — unsupported get / missing permissions |
| 19 | 611 | 874756775724666 | **CONNECTED** |
| 20 | 612 | 1078712815318935 | **CONNECTED** |
| 27 | 676 | 1246597248548179 | **CONNECTED** |

Exemplo resposta canal 18 (POST `/messages`, probe):

```json
{
  "error": {
    "message": "Unsupported post request. Object with ID '832656013256861' does not exist, cannot be loaded due to missing permissions, or does not support this operation.",
    "code": 100,
    "type": "GraphMethodException",
    "error_subcode": 33
  }
}
```

`Whatsapp::HealthService` no canal 18 — mesma falha 400/100 no `phone_number_id`.

---

## 9. Logs capturados (referência)

Logs completos colados em **`INCIDENTE_WHATSAPP_INBOX_610_LOGS_18SET2026.md`**.

Resumo quantitativo:

- **`journalctl -u chatwoot-worker.1`**, 30 dias: **91** linhas contendo `133010`
- **2026-09-18** (janela 15:55–16:30 BRT): **17** eventos `SendReplyJob` com 133010 (amostra no anexo)

Job responsável:

```text
[ActiveJob] [SendReplyJob] ... {"error":{"message":"(#133010) Account not registered","code":133010,"type":"OAuthException","fbtrace_id":"..."}}
```

---

## 10. Ações executadas no servidor (conservadoras)

**Restrição solicitada:** mexer **somente** no inbox 610 / canal 18; **não** alterar app ManyWP global nem outros canais.

| Ação | Resultado |
|------|-----------|
| `Whatsapp::WebhookSetupService#register_phone!` em `Channel::Whatsapp.find(18)` | **Falhou** — Graph 100; **não** gravou `verification_pin` |
| `channel.prompt_reauthorization!` (canal 18) | **OK** — Redis `alfred:REAUTHORIZATION_REQUIRED:channel_whatsapp:18` = `true`; enfileirou e-mail `whatsapp_disconnect` para admins da account 88 |
| Alteração de `api_key` / tokens de outros canais | **Não feito** |
| Alteração QuePasa / n8n | **Não feito** |

**Estado do `provider_config` canal 18:** inalterado (sem PIN novo; `updated_at` continua 2026-08-10).

---

## 11. Hipótese de causa raiz (para IA continuar investigação)

1. O WABA **`1432484038007576`** foi **removido** dos ativos do **ManyWP System User** ou desvinculado do app no Meta Business Manager (intencional ou acidental durante outro onboarding/reauth na AGTU).
2. O número **`+554187814116`** pode ter sido **desregistrado** na Cloud API do lado Meta — sintoma inicial 133010, depois 100 quando o token também perdeu visibilidade do objeto.
3. **Correlação temporal (hipótese):** canal 19 (inbox 611) teve `channel_whatsapp.updated_at` em **2026-09-18 ~18:32 UTC** — possível reauth de outro inbox AGTU no mesmo dia do outage; **não provado** que tenha causado a remoção do WABA 610.

**O que descartamos:**

- Token “expirado” no sentido OAuth curto — `is_valid=true`, `expires=0`
- Falha generalizada do app — outros WABAs no mesmo padrão de token respondem CONNECTED
- Pipeline QuePasa

---

## 12. Procedimento de correção recomendado

### Opção A — Chatwoot (preferida, escopo mínimo)

1. Admin **AGTU** → **Settings → Inboxes → 610**
2. Fluxo **Reconnect / Reauthorize WhatsApp** (embedded signup)
3. Selecionar **mesmo número** +554187814116 e WABA comercial correto
4. Chatwoot executa `Whatsapp::ReauthorizationService` → atualiza **só** canal 18 (`api_key`, `phone_number_id`, etc.)
5. Validar: Graph `status=CONNECTED` + envio teste + mensagem de saúde no inbox

### Opção B — Meta Business Manager

1. Business Settings → System users → **ManyWP** → Assets → WhatsApp accounts  
2. Readicionar WABA **`1432484038007576`**
3. Se necessário, registrar número na Cloud API (PIN two-step) conforme doc Meta  
4. Revalidar token canal 18 (`WABA_IN_TOKEN=true`) ou reconectar inbox 610

### Pós-correção (operacional)

- Reenviar mensagens falhas se política AGTU permitir (muitas são marketing / template)
- Monitorar `external_error` marketing limit (57 falhas no dia) — cap comercial separado do 133010

---

## 13. Comandos de revalidação (somente leitura)

```bash
# Erros 133010 recentes no worker
journalctl -u chatwoot-worker.1 --since '24 hours ago' --no-pager | grep -c '133010'

# Metadados inbox 610
sudo -u postgres psql chatwoot_production -c "
  SELECT i.id, i.account_id, cw.id AS channel_id, cw.phone_number,
         cw.provider_config->>'phone_number_id' AS pnid,
         cw.provider_config->>'business_account_id' AS waba
  FROM inboxes i
  JOIN channel_whatsapp cw ON cw.id = i.channel_id
  WHERE i.id = 610;"

# Flag reauth Redis
redis-cli GET "alfred:REAUTHORIZATION_REQUIRED:channel_whatsapp:18"

# Debug token canal 18 (Rails - não imprimir api_key)
cd /home/chatwoot/chatwoot && sudo -u chatwoot bash -lc '
  cd /home/chatwoot/chatwoot && RAILS_ENV=production bundle exec rails runner "
    ch = Channel::Whatsapp.find(18)
    data = Whatsapp::FacebookApiClient.new.debug_token(ch.provider_config[\"api_key\"])[\"data\"]
    waba = ch.provider_config[\"business_account_id\"]
    ids = data[\"granular_scopes\"]&.flat_map { |g| g[\"target_ids\"] || [] }&.uniq || []
    puts \"WABA_IN_TOKEN=\#{ids.include?(waba.to_s)}\"
  "
'
```

---

## 14. Segurança / privacidade deste documento

- **Não** inclui `api_key`, app secret, webhook verify tokens ou conteúdo completo de mensagens de clientes.
- IDs Meta (WABA, phone_number_id, fbtrace_id) incluídos para suporte Meta.

---

## 15. Changelog deste documento

| Versão | Data | Notas |
|--------|------|--------|
| 1.0 | 2026-09-18 | Investigação read-only + tentativa conservadora + flag reauth |
