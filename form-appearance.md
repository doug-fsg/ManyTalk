# Form Appearance — Plan (lean)

## Overview

Personalizar o formulário público (Account Forms):

1. Cor de **fundo** do card
2. Cor do **texto** (título, descrição, labels)
3. **Alinhamento** da logo: esquerda | centro | direita
4. Logo **preencher cabeçalho** (banner)

`primary_color` (botão) e `logo_url` já existem. Branding é jsonb — **sem migration**.

| Decisão | Valor |
|---------|--------|
| Fundo | Card (não a página) |
| Texto | Título + descrição + labels (opacidade para hierarquia) |
| Expandir on | Esconde alinhamento |
| Inputs | Fundo próprio (legível em card escuro) |
| Estados loading/sucesso/erro | Neutros (sem branding) |

## Project Type

**WEB** — Rails + Vue dashboard + pack `publicForm`

## Success Criteria

- [ ] Admin define fundo, texto, align e expand na aba Aparência
- [ ] Preview = página pública
- [ ] Forms antigos mantêm visual atual (defaults)
- [ ] Cores inválidas não quebram / não injetam CSS (sanitize no backend)
- [ ] `FormDetail.vue` não inchou (settings extraídos)

## Tech Stack

| Peça | Abordagem |
|------|-----------|
| Persistência | `branding` jsonb |
| Backend | `DEFAULT_BRANDING` + `BrandingSanitizer` (irmão de `DefinitionSanitizer`) + `branding_for_api` |
| FE shared | `formBrandingHelpers.js` + `AccountFormCard.vue` |
| Editor | `FormAppearanceSettings.vue` (não inline em `FormDetail`) |
| Primitivos | `woot-color-picker`, `FormLogoUpload`, `FormPublicFieldInput` |

### Branding keys

```text
background_color  #default #ffffff
text_color        #default #0f172a
logo_alignment    #left|center|right  default center
logo_expand       #boolean  default false
```

Hex só `#RGB` / `#RRGGBB`. Inválido → default (coerce, não 422). Update faz **deep-merge** do branding.

## File Structure

```text
app/models/account_form.rb
app/services/account_forms/branding_sanitizer.rb          # NOVO
app/controllers/api/v1/accounts/account_forms_controller.rb
app/views/.../account_forms/**/*.jbuilder                 # branding_for_api

app/javascript/shared/helpers/formBrandingHelpers.js      # NOVO
app/javascript/shared/components/AccountFormCard.vue      # NOVO (preview + público)

app/javascript/dashboard/.../forms/
  FormAppearanceSettings.vue                              # NOVO
  FormDetail.vue                                          # só monta o filho
  FormPublicPreview.vue                                   # thin → AccountFormCard

app/javascript/publicForm/App.vue                         # estados + AccountFormCard

spec/services/account_forms/branding_sanitizer_spec.rb
spec/models/account_form_spec.rb
spec/requests/api/v1/accounts/account_forms_spec.rb
```

**Não tocar:** workflows, migrations, widget `Branding.vue`, rewrite de submissions.

## Tasks

```text
T1 BrandingSanitizer + defaults + branding_for_api + deep-merge no controller
T2 i18n pt_BR/en
T3 formBrandingHelpers + AccountFormCard
T4 FormAppearanceSettings + wire FormDetail
T5 Preview + App usam AccountFormCard
T6 Specs backend
T7 Smoke manual + precompile
```

Ordem: **T1 → T6** (backend) em paralelo com **T2**; depois **T3 → T4 → T5 → T7**.

### T1 — Backend

| | |
|--|--|
| **agent** | backend-specialist |
| **deps** | — |

**IN:** `branding: {}` aberto, defaults só no create, sem sanitize.  
**OUT:** keys novas em `DEFAULT_BRANDING`; `BrandingSanitizer` (whitelist, hex, enum, bool, `logo_url` seguro); deep-merge no update; `branding_for_api` nos jbuilders.  
**VERIFY:** `bundle exec rspec spec/services/account_forms/branding_sanitizer_spec.rb spec/models/account_form_spec.rb spec/requests/api/v1/accounts/account_forms_spec.rb`  
**Rollback:** reverter model/service/controller/jbuilders.

### T2 — i18n

| | |
|--|--|
| **agent** | frontend-specialist |
| **deps** | — |

Labels: fundo, texto, posição (E/C/D), preencher cabeçalho, hint quando expand.  
**VERIFY:** keys em `pt_BR` e `en`.

### T3 — Shared card

| | |
|--|--|
| **agent** | frontend-specialist |
| **deps** | T1 (defaults iguais ao Ruby) |

**OUT:** helper puro JS + `AccountFormCard` (`mode: preview|live`). Um lugar para logo normal/expand, cores, fields (`FormPublicFieldInput`).  
**VERIFY:** branding default = visual atual.  
**Rollback:** apagar shared novos.

### T4 — Editor

| | |
|--|--|
| **agent** | frontend-specialist |
| **deps** | T2, T3 |

**OUT:** `FormAppearanceSettings` (pickers + logo upload + align + expand). `FormDetail` só monta o componente.  
**VERIFY:** `FormDetail` não cresceu; preview reage ao vivo.

### T5 — Preview + público

| | |
|--|--|
| **agent** | frontend-specialist |
| **deps** | T3 |

**OUT:** `FormPublicPreview` e `App.vue` usam `AccountFormCard`. App mantém loading/sucesso/erro neutros.  
**VERIFY:** público = preview; submit ok.

### T6 — Specs

| | |
|--|--|
| **agent** | backend-specialist |
| **deps** | T1 |

Cobrir: defaults, hex inválido→default, PATCH parcial não apaga `logo_url`, GET público com keys em form legado.

### T7 — Phase X

| | |
|--|--|
| **deps** | T4, T5, T6 |

## Phase X

- [ ] Fundo / texto / align / expand no editor e no público
- [ ] Form legado sem keys novas não quebra
- [ ] Submit público ok
- [ ] Specs T6 verdes
- [ ] `assets:precompile` ok (packs dashboard + `publicForm`)
- [ ] Deploy: app + assets juntos; rollback = imagem anterior (sem migrate)

## Deploy (mínimo)

Sem migration. Rebuild de assets obrigatório. Rollback = commit/imagem anterior; jsonb com keys novas é ignorado pelo código antigo.

## Fora de escopo

Page background, cor do botão/inputs, contraste bloqueante, gradiente, rewrite total do `FormDetail`, backfill SQL.

## Kickoff

1. T1 + T6 (segurança no write/read)  
2. T3 → T4 → T5 (um card, sem duplicar markup)  
3. T7 smoke  

**Status:** implementado (T1–T6). Rodar specs localmente para confirmar.
)
