# Plano de patch — Custom Roles

## Arquivos alterados

| Arquivo | Mudança |
|---------|---------|
| `enterprise/app/services/enterprise/custom_role_conversation_scope.rb` | Novo — escopo único de conversas |
| `enterprise/app/services/enterprise/conversations/filter_service.rb` | Prepend — aplica escopo no filter |
| `enterprise/app/finders/enterprise/conversation_finder.rb` | Usa serviço compartilhado |
| `app/services/conversations/filter_service.rb` | Hook `scoped_conversations` + prepend |
| `enterprise/app/policies/enterprise/contact_policy.rb` | Restringe contatos por custom role |
| `enterprise/app/models/custom_role.rb` | Exige ≥1 permissão |
| `app/controllers/.../custom_attribute_definitions_controller.rb` | `crm_manage` no create Kanban |
| `db/seeds.rb` | Habilita `custom_roles` em dev |

## Risco

| Área | Risco | Mitigação |
|------|-------|-----------|
| Agentes normais (sem custom role) | Baixo | Escopo/policy só ativam com `custom_role_agent?` |
| Filter de conversas | Médio | Mesma lógica já usada no index |
| Contatos | Médio | Spec de policy; agente padrão inalterado |
| Seeds | Baixo | Só dev, idempotente via `enable_features!` |

## Regressão recomendada

```bash
bundle exec rspec spec/enterprise/services/enterprise/custom_role_conversation_scope_spec.rb \
  spec/enterprise/policies/enterprise/contact_policy_spec.rb \
  spec/models/custom_role_spec.rb \
  spec/models/account_user_spec.rb
```

## Rollback

Reverter commit; migration `custom_roles` permanece (sem down necessário para este patch).
