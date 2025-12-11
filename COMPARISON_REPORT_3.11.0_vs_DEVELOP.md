# Relatório Comparativo: Versão 3.11.0 vs Desenvolvimento Atual

**Data da Análise:** 2 de Dezembro de 2025  
**Objetivo:** Identificar funcionalidades e código presentes no desenvolvimento atual que não existem na versão 3.11.0

---

## Resumo Executivo

A versão de desenvolvimento atual possui **funcionalidades significativas que NÃO estão presentes na versão 3.11.0**, incluindo:

1. **Sistema Kanban Completo** - Uma funcionalidade completa de visualização e gestão de contatos em formato Kanban
2. **Canal NotificaMe** - Integração com o canal brasileiro NotificaMe
3. **Melhorias de UI/UX** - Diversas melhorias em componentes e estilos
4. **Novas Dependências** - Pacotes adicionais para funcionalidades extras

---

## 1. Funcionalidades Principais Ausentes na 3.11.0

### 1.1 Sistema Kanban (⚠️ CRÍTICO)

O desenvolvimento atual implementa um **sistema completo de visualização Kanban para contatos** que está totalmente ausente na versão 3.11.0.

#### Arquivos Relacionados ao Kanban:

**Migrações de Banco de Dados:**
- `20240530120000_add_is_kanban_to_custom_attribute_definitions.rb` - Adiciona suporte a atributos customizados Kanban
- `20250115120000_add_kanban_indexes.rb` - Adiciona índices para performance
- `20250115130000_create_contact_pipeline_positions.rb` - Cria tabela de posições no pipeline
- `20250118000000_add_position_to_contact_pipeline_positions.rb` - Adiciona campo de posição

**Models:**
- `app/models/contact_pipeline_position.rb` - Model para gerenciar posições no Kanban
- `app/models/concerns/contact_kanban_data.rb` - Concern para dados do Kanban

**Services:**
- `app/services/contacts/kanban_sync_service.rb` - Serviço para sincronização de dados Kanban

**Jobs:**
- `app/jobs/contacts/migrate_kanban_data_job.rb` - Job para migração de dados para o Kanban

**Documentação:**
- `KANBAN_DUAL_WRITE_IMPLEMENTATION.md` - Documentação completa da implementação (564 linhas)

### 1.2 Canal NotificaMe (⚠️ IMPORTANTE)

Integração completa com o canal brasileiro NotificaMe, ausente na 3.11.0.

#### Arquivos do Canal NotificaMe:

**Migrações:**
- `20240325215901_create_channel_notifica_me.rb` - Cria a tabela do canal

**Models:**
- `app/models/channel/notifica_me.rb` - Model do canal NotificaMe

**Controllers:**
- `app/controllers/webhooks/notifica_me_controller.rb` - Controller para webhooks

**Services:**
- `app/services/notifica_me/send_on_notifica_me_service.rb` - Serviço de envio
- `app/services/notifica_me/webhook_setup_service.rb` - Configuração de webhooks

**Jobs:**
- `app/jobs/webhooks/notifica_me_events_job.rb` - Processamento de eventos

---

## 2. Migrações de Banco de Dados Ausentes na 3.11.0

Total de **10 migrações** presentes no develop mas ausentes na 3.11.0:

| Migração | Descrição | Impacto |
|----------|-----------|---------|
| `20230726203159_add_allow_agent_to_delete_message_to_inboxes.rb` | Permite agentes deletarem mensagens | Funcionalidade de permissões |
| `20240118132749_enable_send_agent_name_in_whatsapp_message.rb` | Habilita envio de nome do agente no WhatsApp | Melhoria WhatsApp |
| `20240129143157_enable_read_message.rb` | Habilita leitura de mensagens | Funcionalidade de mensagens |
| `20240131075225_disable_whatsapp_messaging_window.rb` | Desabilita janela de mensagens WhatsApp | Configuração WhatsApp |
| `20240325215901_create_channel_notifica_me.rb` | Cria canal NotificaMe | **Canal completo** |
| `20240528173755_alter_message_source_id_length.rb` | Altera tamanho do source_id | Melhoria técnica |
| `20240530120000_add_is_kanban_to_custom_attribute_definitions.rb` | Adiciona suporte Kanban | **Sistema Kanban** |
| `20250115120000_add_kanban_indexes.rb` | Índices Kanban | **Sistema Kanban** |
| `20250115130000_create_contact_pipeline_positions.rb` | Tabela de posições Kanban | **Sistema Kanban** |
| `20250118000000_add_position_to_contact_pipeline_positions.rb` | Campo de posição Kanban | **Sistema Kanban** |

---

## 3. Dependências Adicionadas no Desenvolvimento

### 3.1 Dependências JavaScript (package.json)

**Novas Dependências:**
```json
{
  "socket.io-client": "^4.7.5",  // Cliente Socket.IO - NÃO ESTÁ na 3.11.0
  "xlsx": "^0.18.5"               // Manipulação de planilhas Excel - NÃO ESTÁ na 3.11.0
}
```

**Versões Atualizadas:**
```json
{
  "eslint-plugin-vue": "^9.27.0"  // 3.11.0 tem versão ^9.17.0
}
```

**Configurações Alteradas:**
- Limite de tamanho do widget aumentado: `300 KB` → `310 KB`

### 3.2 Dependências Ruby (Gemfile)

**Novas Gems:**
```ruby
gem 'mutex_m'        # NÃO ESTÁ na 3.11.0 - Sincronização de threads
gem 'phonelib'       # NÃO ESTÁ na 3.11.0 - Validação de números de telefone
```

**Versões Atualizadas:**
```ruby
gem 'sentry-rails', '>= 5.18.2'     # 3.11.0 tem >= 5.18.1
gem 'sentry-sidekiq', '>= 5.18.2'   # 3.11.0 tem >= 5.18.1
```

---

## 4. Estrutura de Código Ausente na 3.11.0

### 4.1 Services Adicionais

**Diretório `app/services/api/`** (completo):
- `delivery_status_service.rb`
- `incoming_message_service.rb`
- `oneoff_api_campaign_service.rb`
- `send_on_sms_service.rb`

**Outros Services:**
- `contact_attribute_file_upload_service.rb` - Upload de arquivos de atributos
- `contacts/kanban_sync_service.rb` - Sincronização Kanban
- **Diretório `notifica_me/`** (completo) - Services do canal NotificaMe

### 4.2 Jobs Adicionais

**Jobs de Conversação:**
- `conversations/forward_message_job.rb` - Encaminhamento de mensagens

**Jobs de Contatos:**
- `contacts/migrate_kanban_data_job.rb` - Migração de dados Kanban

**Jobs de Sistema:**
- `update_last_seen_job.rb` - Atualização de último acesso
- `webhooks/notifica_me_events_job.rb` - Eventos NotificaMe

### 4.3 Components e Helpers JavaScript

**Novos Componentes:**
- `dashboard/components/CustomAttributeFileUpload.vue` - Upload de arquivos em atributos customizados
- `dashboard/components/CustomBrandPolicyWrapper.vue` - Wrapper de políticas de marca

**Novos Composables:**
- `dashboard/composables/useAdmin.js` - Hook para funcionalidades de admin
- `dashboard/composables/useUISettings.js` - Hook para configurações de UI

**Novos Helpers:**
- `dashboard/helper/CacheHelper/` - Helpers para cache

---

## 5. Melhorias de Configuração

### 5.1 Tailwind Config

O desenvolvimento atual possui configurações adicionais no `tailwind.config.js`:

```javascript
// Presente no develop, ausente na 3.11.0:
fontFamily: {
  interDisplay: ['Inter Display', ...defaultTheme.fontFamily.sans],
},
screens: {
  xs: '480px',
  sm: '640px',
  md: '768px',
  lg: '1024px',
  xl: '1280px',
  '2xl': '1536px',
}
```

### 5.2 Estrutura JavaScript Otimizada

- **3.11.0:** ~7.000 arquivos JavaScript/Vue
- **Develop:** ~1.700 arquivos JavaScript/Vue

A estrutura do desenvolvimento atual é **significativamente mais otimizada** e refatorada, com redução de ~75% no número de arquivos, indicando uma consolidação e otimização substancial do código.

---

## 6. Arquivos de Documentação

**Novo no Develop:**
- `KANBAN_DUAL_WRITE_IMPLEMENTATION.md` - Documentação completa do sistema Kanban (564 linhas)

---

## 7. Concerns e Validators Adicionais

**Models Concerns (develop):**
- `brazilian_number_validator.rb` - Validação de números brasileiros (NÃO ESTÁ na 3.11.0)
- `contact_kanban_data.rb` - Dados do Kanban (NÃO ESTÁ na 3.11.0)

---

## 8. Análise de Impacto

### 8.1 Funcionalidades Críticas Ausentes na 3.11.0

| Funcionalidade | Impacto | Arquivos Envolvidos |
|----------------|---------|---------------------|
| **Sistema Kanban** | **ALTO** | 4 migrações, 1 model, 1 concern, 1 service, 1 job, documentação completa |
| **Canal NotificaMe** | **ALTO** | 1 migração, 1 model, 1 controller, 2 services, 1 job |
| **Socket.IO** | **MÉDIO** | Dependência npm, possível integração em tempo real |
| **Excel Export (xlsx)** | **MÉDIO** | Dependência npm para exportação de dados |
| **Validação Brasileira** | **MÉDIO** | Validator, gem phonelib |

### 8.2 Melhorias Técnicas

| Categoria | Melhoria | Impacto |
|-----------|----------|---------|
| **Performance** | Estrutura JavaScript refatorada (-75% arquivos) | **ALTO** |
| **Banco de Dados** | Índices Kanban adicionados | **MÉDIO** |
| **Configuração** | Tailwind screens e fonts expandidos | **BAIXO** |
| **WhatsApp** | 3 melhorias específicas do canal | **MÉDIO** |

---

## 9. Conclusões e Recomendações

### 9.1 Principais Descobertas

1. **O desenvolvimento atual está SIGNIFICATIVAMENTE MAIS AVANÇADO** que a versão 3.11.0
2. **Sistema Kanban** é uma funcionalidade completa e bem documentada ausente na 3.11.0
3. **Canal NotificaMe** é uma integração brasileira completa não presente na 3.11.0
4. A estrutura de código foi **massivamente refatorada e otimizada** no develop
5. Diversas melhorias incrementais em WhatsApp, validações e funcionalidades

### 9.2 Recomendações

#### Se você precisa da funcionalidade Kanban ou NotificaMe:
- ✅ **USE a versão de desenvolvimento atual**
- ❌ **NÃO reverta para 3.11.0** - você perderá funcionalidades críticas

#### Se você está considerando atualizar da 3.11.0 para o develop:
1. **Backup completo** do banco de dados antes de rodar as migrações
2. Execute as **10 migrações** na ordem cronológica
3. Instale as novas dependências (`yarn install` e `bundle install`)
4. Teste especialmente:
   - Sistema Kanban (se usar atributos customizados)
   - Canal NotificaMe (se usar)
   - Funcionalidades de WhatsApp

#### Próximos Passos Sugeridos:
1. **Revisar o arquivo `KANBAN_DUAL_WRITE_IMPLEMENTATION.md`** para entender completamente o sistema Kanban
2. **Testar todas as migrações** em ambiente de desenvolvimento/staging primeiro
3. **Verificar compatibilidade** das novas dependências com seu ambiente de produção
4. **Planejar rollout** das novas funcionalidades para usuários finais

---

## 10. Resumo de Arquivos por Categoria

### Ausentes na 3.11.0 (Presentes no Develop):

**Migrações:** 10 arquivos  
**Models:** 2 arquivos (1 model + 1 concern)  
**Controllers:** 1 arquivo  
**Services:** 7 arquivos (1 diretório completo)  
**Jobs:** 4 arquivos  
**Components Vue:** 2+ arquivos  
**Composables:** 2 arquivos  
**Dependências npm:** 2 pacotes  
**Gems Ruby:** 2 gems  
**Documentação:** 1 arquivo (564 linhas)

**Total Estimado:** ~30+ arquivos significativos + refatoração massiva da estrutura JavaScript

---

## Contato e Suporte

Para dúvidas sobre este relatório ou sobre a migração entre versões, consulte:
- Documentação do Kanban: `KANBAN_DUAL_WRITE_IMPLEMENTATION.md`
- Histórico de commits entre 3.11.0 e HEAD
- Equipe de desenvolvimento

---

**Fim do Relatório**

