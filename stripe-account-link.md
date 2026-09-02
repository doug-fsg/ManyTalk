# Stripe Account Link (produção conservadora)

## Overview

Accounts Chatwoot e customers Stripe já existem e **não** estão ligados. O código Enterprise atual é **perigoso em produção** para este cenário: cria cobrança nova, apaga `custom_attributes` e recria assinatura em cancelamento.

Este plano **só vincula** (`cus_`) no Super Admin, puxa o estado atual e sincroniza via webhook. **Não** cria recursos no Stripe. **Não** há tela no dashboard do cliente no MUST.

**Decisões travadas:** chave = só `cus_` · cancelamento = status canceled + features do plano default · mapeamento = só Super Admin.

---

## Bugs confirmados (auditoria — não implementar sem ler)

| ID | Severidade | Onde | O que acontece | Ativo quando |
|---|---|---|---|---|
| **B1** | 🔴 Crítico | `AccountsController#subscription` L9 | `update(custom_attributes: { is_creating_customer: true })` **apaga** todo o jsonb | Admin abre Billing **ou** `POST .../subscription` |
| **B2** | 🔴 Crítico | `CreateStripeCustomerService` L8–12 | **Sempre** chama `Stripe::Subscription.create`, mesmo com `cus_` já setado | Job após B1, webhook `deleted`, ou service direto |
| **B3** | 🔴 Crítico | `HandleStripeEventService#process_subscription_deleted` L47 | Cancelamento no Stripe **recria** assinatura via B2 | Webhook cadastrado no Dashboard |
| **B4** | 🟠 Alto | `CreateStripeCustomerService` L14–21, `HandleStripeEventService` L30–39 | Sucesso de billing **substitui** `custom_attributes` inteiro | Qualquer sync/write de billing |

**Evidência B1:** spec espera `custom_attributes == { is_creating_customer: true }` apenas (`accounts_controller_spec.rb:35`).

**Evidência B2:** spec com `stripe_customer_id` presente ainda espera `Subscription.create` (`create_stripe_customer_service_spec.rb:35–37`).

**Gatilho automático B1:** `billing/Index.vue` dispara `accounts/subscription` no `mounted()` se não houver `plan_name`. Menu Billing só aparece com `DEPLOYMENT_ENV=cloud`; o endpoint **continua exposto** via API.

**Mitigação imediata (antes de qualquer deploy de código):**
- [ ] Comunicar admins: **não abrir** Settings → Billing.
- [ ] Confirmar no Stripe Dashboard se webhook `/webhooks/stripe` já existe → se sim, **desativar** até Onda 3.
- [ ] Não colar `cus_` manualmente em `custom_attributes` até Onda 2 (B2 pode disparar depois).

---

## Project Type

**BACKEND** (Rails Enterprise + Super Admin ERB). Vue Billing: SHOULD (T9), não bloqueia vínculo no Super Admin.

---

## Postura de produção

1. **Hotfix primeiro** (Onda 0): parar dano — sem feature nova.
2. **Ondas pequenas**, cada uma revertível. Um PR por onda quando possível.
3. **Sem migration** nas ondas 0–3. Dados em `accounts.custom_attributes` (jsonb).
4. **Merge obrigatório** em **todos** os writers de `custom_attributes` (inclui `AccountsController#subscription`).
5. **Flag** `STRIPE_AUTO_PROVISION_CUSTOMERS` default **false**. Rollback operacional = virar flag.
6. **Webhook no Stripe Dashboard só após** deploy da Onda 3 (fix B3).
7. **Canário:** 1 account → 24h estável → resto manual.
8. Staging: Stripe **test mode**. Não usar `STRIPE_SECRET_KEY` live com código que ainda cria recursos.

---

## Success Criteria

- [ ] B1–B4 corrigidos com specs de regressão.
- [ ] `POST .../subscription` e Billing **não** apagam nem criam nada (flag off).
- [ ] Super Admin vincula `cus_` válido e único; recusa ambíguo/inválido.
- [ ] Após vínculo: plano, quantity, status vêm do Stripe (pull único).
- [ ] `subscription.updated` sincroniza; `deleted` → default plan, **sem** recreate.
- [ ] Zero customers/subs novos no Stripe durante o épico (exceto os que já existiam).
- [ ] Canário 1 account OK antes do mapeamento em massa.

---

## Tech Stack

| Peça | Uso |
|---|---|
| Stripe Ruby (já no Gemfile) | Retrieve only no vínculo |
| `Account.custom_attributes` | Persistência billing (sem migration) |
| `InstallationConfig` | Flag autoprovimento + `CHATWOOT_CLOUD_PLANS` |
| Super Admin member action | `POST link_stripe` (padrão `seed` / `reset_cache`) |
| Webhook `POST /webhooks/stripe` | Sync pós-Onda 3 |

---

## File Structure

```
enterprise/app/services/enterprise/billing/
  billing_custom_attributes.rb          # NOVO: helper merge (único ponto DRY)
  create_stripe_customer_service.rb     # guardrail B2 + merge B4
  handle_stripe_event_service.rb        # fix B3 + merge B4
  link_stripe_customer_service.rb       # NOVO: retrieve + persist (sem create)
enterprise/app/controllers/enterprise/api/v1/accounts_controller.rb  # fix B1
enterprise/app/jobs/enterprise/create_stripe_customer_job.rb
app/controllers/super_admin/accounts_controller.rb
app/views/super_admin/accounts/_stripe_link.html.erb
config/routes.rb
config/installation_config.yml
spec/enterprise/services/enterprise/billing/...
spec/enterprise/controllers/enterprise/api/v1/accounts_controller_spec.rb
spec/controllers/super_admin/accounts_controller_spec.rb
```

**Opcional SHOULD:** `app/javascript/dashboard/routes/dashboard/settings/billing/Index.vue` (T9).

---

## Ondas de deploy

```
Onda 0  HOTFIX   B1+B2+B4 writers + flag off     → deploy IMEDIATO
Onda 1  LINK     T3 LinkStripeCustomerService
Onda 2  UI       T4 Super Admin form + status
Onda 3  WEBHOOK  T5 deleted/updated fix (B3)     → SÓ ENTÃO webhook no Stripe
Onda 4  OPS      planos + canário + massa
Onda 5  UX       T9 Billing Vue (não dispara subscription)
```

```
Onda 0 (T0a+T0b+T0c) ──► deploy-0 ──► GO/NO-GO
                                      │
Onda 1 (T3) ──────────► deploy-1 ──► GO/NO-GO
                                      │
Onda 2 (T4) ──────────► deploy-2 ──► GO/NO-GO
                                      │
Onda 3 (T5) ──────────► deploy-3 ──► T6 webhook ──► GO/NO-GO
                                      │
Onda 4 (T7+T8) ───────► concluído
```

**Regra de ouro:** nunca ter webhook Stripe ativo com código que ainda executa B3.

---

## GO / NO-GO gates (entre ondas)

### Antes de deploy-0
- [ ] Webhook Stripe desativado (se existir).
- [ ] Admins avisados: não abrir Billing.

### Após deploy-0 (obrigatório para seguir)
- [ ] `STRIPE_AUTO_PROVISION_CUSTOMERS` = false na UI.
- [ ] Spec B1: account com `{ foo: 'bar' }` + POST subscription → `foo` preservado.
- [ ] Spec B2: flag off → zero chamadas Stripe API.
- [ ] Abrir Billing em staging (cloud): nenhum customer novo no Stripe Dashboard.
- [ ] Sidekiq: nenhum job `CreateStripeCustomerJob` com erro de cobrança.

**NO-GO:** qualquer wipe de `custom_attributes` ou `Subscription.create` com flag off.

### Após deploy-2 (antes do primeiro `cus_` real)
- [ ] `CHATWOOT_CLOUD_PLANS` preenchido com `product_id` e `price_ids` **live**.
- [ ] `CHATWOOT_CLOUD_PLAN_FEATURES` alinhado.
- [ ] `STRIPE_SECRET_KEY` live no servidor (não no git).
- [ ] Super Admin: form renderiza; submit com `cus_` inválido falha sem persistir.

### Após deploy-3 + webhook (antes do canário)
- [ ] Test event `subscription.updated` com `cus_` órfão → 200, account inalterada.
- [ ] Test `subscription.deleted` em account de staging vinculada → default plan, **sem** `Subscription.create` no Stripe.

---

## Task Breakdown

### T0a — Flag + guardrail total (B2)

- **Agent:** `agent-backend-specialist` · **Skill:** `rails-expert`
- **Priority:** P0 · **Deps:** none
- **Corrige:** B2 (e impede B3 de causar dano via create)

**Mudanças:**
- `InstallationConfig` `STRIPE_AUTO_PROVISION_CUSTOMERS` default `false`.
- `CreateStripeCustomerService#perform`: early return se flag off.
- `CreateStripeCustomerJob`: no-op se flag off.
- `AccountsController#subscription`: se flag off → `head :no_content` **sem** update, **sem** enqueue.

**VERIFY:**
```bash
bundle exec rspec spec/enterprise/services/enterprise/billing/create_stripe_customer_service_spec.rb \
  spec/enterprise/jobs/enterprise/create_stripe_customer_job_spec.rb \
  spec/enterprise/controllers/enterprise/api/v1/accounts_controller_spec.rb
```
Novo: flag off → `Stripe::Customer` e `Stripe::Subscription` **never** called. Specs legados de create rodam só com flag on.

**Rollback:** flag `true` (emergência cloud original).

---

### T0b — Merge `custom_attributes` em todos os writers (B1 + B4)

- **Agent:** `agent-backend-specialist` · **Skill:** `rails-expert`
- **Priority:** P0 · **Deps:** serial com T0a (mesmos arquivos)
- **Corrige:** B1, B4

**Mudanças:**
- Extrair `Enterprise::Billing::BillingCustomAttributes.merge(account, attrs)` (ou concern mínimo).
- Aplicar em:
  - `AccountsController#subscription` → `merge(account, { is_creating_customer: true })` (só se flag on; com flag off nem chega aqui).
  - `CreateStripeCustomerService#perform`
  - `HandleStripeEventService#update_account_attributes`
  - (futuro) `LinkStripeCustomerService`

**VERIFY:** spec account com `{ onboarding_step: 'x', foo: 1 }`:
- POST subscription (flag on) → chaves preservadas + `is_creating_customer`.
- Webhook updated stub → chaves preservadas + billing attrs.
- Create service success → idem.

**Rollback:** revert commit.

---

### T0c — Specs de regressão dos bugs confirmados

- **Agent:** `agent-test-engineer` · **Skill:** `rails-expert`
- **Priority:** P0 · **Deps:** T0a, T0b

**OUTPUT:** specs nomeados por bug:
- `B1` não apaga attrs com flag on (merge).
- `B1` não apaga attrs com flag off (no update).
- `B2` não cria sub com `cus_` presente e flag off.
- `B3` stub: deleted não instancia `CreateStripeCustomerService` (prepara T5; pode skip até T5 land).

**VERIFY:** `bundle exec rspec spec/enterprise/` (billing subset verde).

---

### Deploy-0 (produção — HOTFIX)

**Conteúdo:** T0a + T0b + T0c num único PR.

**Checklist pós-deploy:**
1. Flag false na UI.
2. 1 account com `custom_attributes` não-billing → admin abre Billing → attrs intactos.
3. Stripe Dashboard: 0 resources novos em 1h.
4. Sidekiq limpo.

**Ainda proibido:** vincular `cus_`, ligar webhook.

---

### T3 — `LinkStripeCustomerService`

- **Agent:** `agent-backend-specialist` · **Skill:** `rails-expert`
- **Priority:** P0 · **Deps:** deploy-0
- **Corrige:** gap funcional (vínculo); não reintroduz B2

**Regras:**
| Condição | Ação |
|---|---|
| `cus_` inválido / 404 Stripe | Erro, sem persistir |
| `cus_` já em outra account | Erro com `account.id` dona |
| 0 subs `active`/`trialing` | Erro |
| 2+ subs `active`/`trialing` | Erro (operador limpa no Stripe) |
| Product fora de `CHATWOOT_CLOUD_PLANS` | Erro |
| 1 sub usável | Merge attrs + aplicar features do plano |
| Qualquer caso | **Nunca** `Customer.create` / `Subscription.create` |

**Campos gravados:** `stripe_customer_id`, `stripe_price_id`, `stripe_product_id`, `plan_name`, `subscribed_quantity`, `subscription_status`, `subscription_ends_on`.

**VERIFY:** `bundle exec rspec spec/enterprise/services/enterprise/billing/link_stripe_customer_service_spec.rb`

---

### T4 — Super Admin: status + vínculo

- **Agent:** `agent-backend-specialist` · **Skill:** `rails-expert`
- **Priority:** P0 · **Deps:** T3

**OUTPUT:**
- Partial `_stripe_link.html.erb` na show da account.
- `POST /super_admin/accounts/:id/link_stripe` com `stripe_customer_id`.
- Exibir: estado (não vinculado / active / canceled), `cus_`, plano, quantity, status, fim do período.
- Sucesso: flash com **nome + e-mail** do customer Stripe (conferência humana).
- Erro Stripe/validação: flash, zero persistência parcial.

**VERIFY:** request spec Super Admin (auth, happy, duplicado, inválido).

---

### Deploy-1 + Deploy-2

- Deploy-1: T3 (código morto até T4).
- Deploy-2: T4 (operável).
- Smoke: form abre; submit com `cus_` fake → erro limpo; **não** submeter live ainda.

---

### T5 — Webhook: fix B3 + sync seguro

- **Agent:** `agent-backend-specialist` · **Skill:** `rails-expert`
- **Priority:** P0 · **Deps:** T0b; deploy após T4
- **Corrige:** B3

**`subscription.deleted`:**
- Account encontrada por `cus_` → `subscription_status: canceled`, features do **primeiro** plano em `CHATWOOT_CLOUD_PLANS`, **manter** `stripe_customer_id`.
- **Não** chamar `CreateStripeCustomerService`.
- Spec existente L72–78 **deve mudar** (hoje espera create — isso é o bug).

**`subscription.updated`:** merge attrs (T0b) + features. Orphan `cus_` → log + no-op.

**VERIFY:** `bundle exec rspec spec/enterprise/services/enterprise/billing/handle_stripe_event_service_spec.rb`

---

### Deploy-3 + T6 — Webhook (ops)

**Só após T5 em produção.**

1. `STRIPE_SECRET_KEY` + `STRIPE_WEBHOOK_SECRET` no servidor.
2. Stripe Dashboard → endpoint `https://<host>/webhooks/stripe`.
3. Eventos: **apenas** `customer.subscription.updated`, `customer.subscription.deleted`.
4. Test events → 200.
5. Confirmar: deleted de teste **não** cria sub nova (Stripe Dashboard).

**Rollback:** desativar endpoint **antes** de reverter código.

---

### T7 — Catálogo + canário

**Pré-requisitos:** `CHATWOOT_CLOUD_PLANS`, `CHATWOOT_CLOUD_PLAN_FEATURES`, keys live.

**Procedimento canário (1 account):**
1. Escolher account de menor risco.
2. Super Admin → colar `cus_` conhecido.
3. Conferir flash (nome/e-mail) vs. cliente real.
4. Conferir plano/quantity na ficha.
5. No Stripe: alterar quantity → webhook → account atualiza em < 5 min.
6. Aguardar 24h.

**Rollback vínculo errado:** POST novo `cus_` correto (T3 libera o antigo). Sem unlink automático neste épico.

---

### T8 — Mapeamento em massa

- **Deps:** T7 estável 24h
- Uma account por vez; planilha externa `account_id ↔ cus_` (fora do repo).
- **VERIFY final:**
  ```sql
  -- accounts pagantes sem vínculo (ajustar critério se necessário)
  SELECT id, name FROM accounts
  WHERE custom_attributes->>'stripe_customer_id' IS NULL;
  ```
- Stripe: customers criados desde início do épico = 0 pelo app.

---

### T9 — Billing Vue: não disparar subscription (SHOULD)

- **Agent:** `agent-frontend-specialist` · **Skill:** `vue-best-practices`
- **Priority:** P1 · **Deps:** deploy-0
- **Corrige:** gatilho automático B1 na UI (defesa em profundidade)

**Mudança:** remover `dispatch('accounts/subscription')` do `mounted()` em `billing/Index.vue`. Mostrar estado “assinatura não vinculada — contate o suporte” (ou i18n existente).

**Por quê não MUST:** deploy-0 já neutraliza o endpoint. T9 evita ruído e chamadas desnecessárias.

**VERIFY:** abrir Billing sem `plan_name` → nenhum POST `/subscription` no network tab.

---

## Matriz bug → task

| Bug | Task que corrige | Onda |
|---|---|---|
| B1 wipe no POST subscription | T0b (+ T0a no-op) | 0 |
| B2 sempre cria Subscription | T0a | 0 |
| B3 deleted recria | T5 | 3 |
| B4 wipe nos services | T0b (+ T3/T5 usam merge) | 0 |
| Gatilho Vue automático | T9 | 5 |

---

## Riscos e mitigação

| Risco | Prob. | Impacto | Mitigação |
|---|---|---|---|
| Admin abre Billing antes deploy-0 | Média | Perda attrs + possível cobrança | Aviso imediato + deploy-0 urgente |
| Webhook ativo com código antigo | Baixa/Média | Recreate em cancelamento | Desativar webhook agora; T6 só pós-T5 |
| `CHATWOOT_CLOUD_PLANS` vazio | Alta | Vínculo recusado / sync no-op | Preencher antes T7 |
| 2+ subs ativas no `cus_` | Média | Vínculo bloqueado | Operador cancela extras no Stripe |
| `default_plan['name']` nil em deleted | Baixa | Features erradas | Guard em T5 se config vazia |
| Re-vínculo `cus_` errado | Média | Account no plano errado | Flash nome/e-mail; planilha externa |

---

## Queries úteis (ops)

```sql
-- Status de vínculo
SELECT id, name,
       custom_attributes->>'stripe_customer_id' AS cus,
       custom_attributes->>'plan_name' AS plan,
       custom_attributes->>'subscription_status' AS status
FROM accounts
ORDER BY id;

-- Pendentes de vínculo
SELECT id, name FROM accounts
WHERE custom_attributes->>'stripe_customer_id' IS NULL;

-- Duplicatas (não deveria existir pós-T3)
SELECT custom_attributes->>'stripe_customer_id' AS cus, COUNT(*)
FROM accounts
WHERE custom_attributes->>'stripe_customer_id' IS NOT NULL
GROUP BY 1 HAVING COUNT(*) > 1;
```

---

## Phase X: Verification

- [ ] Specs T0a–T0c, T3, T4, T5 verdes
- [ ] `bundle exec rubocop` nos arquivos tocados
- [ ] deploy-0: B1/B2 reproduzidos e corrigidos em staging
- [ ] Flag autoprovimento false em produção
- [ ] 0 Stripe resources novos pós-deploy-0
- [ ] Webhook ausente até deploy-3
- [ ] Canário: pull + updated + (staging) deleted sem recreate
- [ ] Zero migrations nas ondas 0–3

## ✅ PHASE X COMPLETE

- (preencher após checks reais)
- Date:

---

## Handoff

| Ordem | O que | PR |
|---|---|---|
| 1 | **T0a + T0b + T0c** (hotfix) | 1 PR — deploy imediato |
| 2 | T3 | PR separado |
| 3 | T4 | pode junto com T3 se revisão ok |
| 4 | T5 | PR separado — **antes** de T6 |
| 5 | T7–T8 | operação |
| 6 | T9 | quando conveniente |

**Agente:** `agent-backend-specialist` + `rails-expert` (ondas 0–3). `agent-frontend-specialist` só T9.

**Não fazer:** vincular `cus_` antes deploy-0 · ligar webhook antes deploy-3 · um PR gigante com tudo.
