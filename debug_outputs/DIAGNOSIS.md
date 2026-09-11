# Diagnóstico — Matriz de permissões Custom Roles

## Loop de feedback

```bash
bundle exec rspec spec/enterprise/custom_roles/permissions_matrix_spec.rb
pnpm test app/javascript/dashboard/helper/specs/permissionsHelper.spec.js
```

Cada exemplo asserta allow/deny para **uma permissão específica** no backend (policy/scope) ou no roteamento frontend.

## Gaps encontrados na auditoria

| Permissão | Backend antes | Frontend antes |
|-----------|---------------|----------------|
| Conversas (3 tipos) | Finder OK; filter corrigido antes | `agent` concedia tudo |
| contact_manage | Parcial | `agent` concedia tudo |
| report_manage | OK | OK |
| knowledge_base_manage | write OK; **index/show abertos** | parcial |
| workflow_manage | **index/show abertos** | `agent` concedia tudo |
| automation_manage | OK | `agent` concedia tudo |
| form_manage | **index/show abertos** | `agent` concedia tudo |
| campaign_manage | **index/show abertos** | `agent` concedia tudo |
| crm_manage | parcial (controller) | N/A |

## Causa raiz do frontend

`permissionsHelper` adicionava `agent` a **todos** os custom roles, liberando rotas de campanhas/workflows/etc.

## Correções desta rodada

- Policies enterprise completas (read + write) para workflow, campaign, forms, KB.
- `permissionsHelper`: custom role só passa se tiver permissão explícita (exceto rotas legadas de agente normal).
- Rotas Vue atualizadas com permissões granulares.
- `spec/enterprise/custom_roles/permissions_matrix_spec.rb` — matriz de regressão.
