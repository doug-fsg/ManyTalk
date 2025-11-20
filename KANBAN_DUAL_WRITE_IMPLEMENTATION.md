# Implementação Completa do Kanban com `contact_pipeline_positions`

## Resumo

A migração completa do Kanban para usar **exclusivamente** a tabela `contact_pipeline_positions` está **CONCLUÍDA**!

- ✅ **Escrita**: Dados são salvos **diretamente** em `contact_pipeline_positions` via API dedicada
- ✅ **Leitura**: Dados são lidos **exclusivamente** de `contact_pipeline_positions`
- ✅ **Performance**: Queries SQL diretas com índices otimizados
- ✅ **Migração Completa**: Sistema agora usa 100% `contact_pipeline_positions`, sem dependência de JSON

## Mudanças Implementadas

### 1. Escrita Direta na Tabela

**Arquivos:**
- `app/controllers/api/v1/accounts/contacts/pipeline_positions_controller.rb` - Controller dedicado para pipeline positions
- `app/javascript/dashboard/api/contacts.js` - API client com método `updatePipelinePosition` e `deletePipelinePosition`
- `app/javascript/dashboard/routes/dashboard/crm/components/KanbanAttributes.vue` - Componente principal que usa `ContactAPI.updatePipelinePosition`

- ✅ Todas as atualizações de stage, deal_value e metadata são feitas diretamente na tabela
- ✅ Endpoint `/api/v1/accounts/:account_id/contacts/:contact_id/pipeline_positions/:pipeline_id` para atualizações
- ✅ Endpoint DELETE para remover contato do pipeline
- ✅ Sem dependência de `custom_attributes` ou `additional_attributes` para dados kanban

### 2. Leitura Exclusiva da Tabela

**Arquivos:**
- `app/models/concerns/contact_kanban_data.rb` - Métodos helper que leem apenas de `contact_pipeline_positions`
- `app/services/contacts/filter_service.rb` - Queries otimizadas com LEFT JOIN em `contact_pipeline_positions`
- `app/javascript/dashboard/routes/dashboard/crm/utils/pipelinePositionsHelper.js` - Helper functions no frontend para ler dados

- ✅ Todos os métodos helper leem **apenas** de `contact_pipeline_positions`
- ✅ FilterService usa LEFT JOIN direto com `contact_pipeline_positions`
- ✅ Sem fallback para JSON - se não existir na tabela, não existe
- ✅ Frontend usa `pipelinePositionsHelper.js` para centralizar leitura de dados

### 3. Remoção de Código Legado

**Arquivos Removidos/Atualizados:**
- `app/listeners/kanban_sync_listener.rb` - ❌ REMOVIDO (não há mais dual-write)
- `app/dispatchers/async_dispatcher.rb` - Removido registro do `KanbanSyncListener`

- ✅ Removido sistema de sincronização JSON → Tabela
- ✅ Removido fallback de leitura JSON
- ✅ Removido dual-write completamente

### 4. Componentes Frontend Migrados

**Arquivos:**
- `app/javascript/dashboard/routes/dashboard/crm/components/KanbanAttributes.vue` - Componente principal
- `app/javascript/dashboard/routes/dashboard/crm/components/KanbanCard.vue` - Cards individuais
- `app/javascript/dashboard/routes/dashboard/crm/components/KanbanCardModal.vue` - Modal de detalhes
- `app/javascript/dashboard/routes/dashboard/crm/components/AddContactToStageModal.vue` - Modal de adição
- `app/javascript/dashboard/routes/dashboard/crm/components/KanbanDashboard.vue` - Dashboard de estatísticas
- `app/javascript/dashboard/routes/dashboard/crm/components/KanbanColumn.vue` - Colunas do kanban
- `app/javascript/dashboard/components/widgets/conversation/KanbanStageIndicator.vue` - Indicador de stage

- ✅ Todos os componentes leem dados via `pipelinePositionsHelper.js`
- ✅ Todas as atualizações usam `ContactAPI.updatePipelinePosition`
- ✅ Remoção de código usa `ContactAPI.deletePipelinePosition`
- ✅ Sem manipulação de `custom_attributes` ou `additional_attributes` para dados kanban
- ✅ Cálculo de totais de colunas usa `pipeline_positions`
- ✅ Estatísticas do dashboard usam `pipeline_positions`

## Como Usar

### Atualizar Stage de um Contato

```javascript
// Frontend
await ContactAPI.updatePipelinePosition(
  contactId,
  pipelineId,
  stageId,        // Novo stage
  position,       // Posição na coluna
  enteredAt,      // Data de entrada (ISO string)
  dealValue,      // Valor do negócio (opcional)
  metadata        // Metadados adicionais (opcional)
);
```

### Atualizar Deal Value e Metadata

```javascript
// Frontend
await ContactAPI.updatePipelinePosition(
  contactId,
  pipelineId,
  stageId,        // Stage atual (manter)
  position,       // Posição atual (manter)
  enteredAt,      // Data atual (manter)
  newDealValue,   // Novo valor
  newMetadata     // Novos metadados
);
```

### Remover Contato do Pipeline

```javascript
// Frontend
await ContactAPI.deletePipelinePosition(contactId, pipelineId);
```

### Ler Dados no Frontend

```javascript
import { 
  getStage, 
  getDealValue, 
  getEnteredAt, 
  getWinLostStatus,
  getPipelinePosition 
} from '../utils/pipelinePositionsHelper';

// Obter stage
const stage = getStage(contact, pipelineId);

// Obter deal value
const dealValue = getDealValue(contact, pipelineId);

// Obter data de entrada
const enteredAt = getEnteredAt(contact, pipelineId);

// Obter status win/lost
const winLost = getWinLostStatus(contact, pipelineId);

// Obter todos os dados
const position = getPipelinePosition(contact, pipelineId);
```

### Ler Dados no Backend

```ruby
# Verificar se contato está em um pipeline
contact.in_pipeline?(pipeline_id) # => true/false

# Obter stage_id
contact.kanban_stage_for_pipeline(pipeline_id) # => "lead"

# Obter deal_value
contact.kanban_deal_value_for_pipeline(pipeline_id) # => 1000.50

# Obter metadata (win/lost, etc)
contact.kanban_metadata_for_pipeline(pipeline_id) # => { "win_lost" => {...} }

# Obter entered_at
contact.kanban_entered_at_for_pipeline(pipeline_id) # => Time

# Obter todos os dados do pipeline
contact.kanban_data_for_pipeline(pipeline_id)
# => { stage_id: "lead", deal_value: 1000.50, entered_at: Time, metadata: {...} }
```

## Migração de Dados Legados

Se você tem dados antigos em `custom_attributes`/`additional_attributes.kanban` que precisam ser migrados para `contact_pipeline_positions`:

```bash
# Migração assíncrona (via Sidekiq)
bundle exec rake chatwoot:kanban:migrate_data

# Migração síncrona (para testes)
bundle exec rake chatwoot:kanban:migrate_data[sync]
```

**Nota:** Este job usa `Contacts::KanbanSyncService.sync_to_table_without_flag_check` para migrar dados do JSON para a tabela. Após migrar todos os dados, você pode limpar os campos JSON (opcional).

## Fluxo Completo

### Escrita (quando um contato é movido no kanban):

```
1. Frontend detecta mudança (drag & drop, modal, etc)
   ↓
2. ContactAPI.updatePipelinePosition é chamado
   ↓
3. API recebe requisição no PipelinePositionsController#update
   ↓
4. Dados são salvos diretamente em contact_pipeline_positions ✅
   ↓
5. Resposta retorna dados atualizados
   ↓
6. Frontend atualiza UI com dados da resposta
```

### Leitura (quando o kanban é consultado):

```
1. Frontend solicita lista de contatos do kanban
   ↓
2. FilterService detecta que é atributo kanban
   ↓
3. LEFT JOIN com contact_pipeline_positions é adicionado ✅
   ↓
4. Query retorna apenas dados da TABELA
   ↓
5. Frontend usa pipelinePositionsHelper.js para extrair dados
   ↓
6. Cards são renderizados com dados da tabela
```

## Estrutura da Tabela

```ruby
# contact_pipeline_positions
- id             # Primary key
- contact_id     # FK para contacts.id
- pipeline_id    # FK para custom_attribute_definitions.id
- stage_id       # ID do stage atual
- position       # Posição na coluna (para ordenação)
- deal_value     # Valor do negócio (decimal)
- entered_at     # Data/hora de entrada no stage
- metadata       # Dados adicionais (JSONB: win_lost, etc)
- created_at     # Timestamp de criação
- updated_at     # Timestamp de atualização
```

## Índices Criados

```sql
- idx_contact_pipeline_positions_unique (contact_id, pipeline_id) UNIQUE
- idx_contact_pipeline_positions_pipeline_stage (pipeline_id, stage_id)
- idx_contact_pipeline_positions_contact (contact_id)
- idx_contact_pipeline_positions_pipeline (pipeline_id)
```

## Estrutura de Resposta da API

### GET /api/v1/accounts/:account_id/contacts/:contact_id

```json
{
  "id": 123,
  "name": "João Silva",
  "pipeline_positions": [
    {
      "pipeline_id": 1,
      "stage_id": "qualified",
      "position": 0,
      "deal_value": 5000.00,
      "entered_at": "2025-01-15T10:30:00Z",
      "metadata": {
        "win_lost": null
      }
    }
  ]
}
```

### PUT /api/v1/accounts/:account_id/contacts/:contact_id/pipeline_positions/:pipeline_id

**Request:**
```json
{
  "stage_id": "proposal",
  "position": 1,
  "entered_at": "2025-01-15T11:00:00Z",
  "deal_value": 7500.00,
  "metadata": {
    "win_lost": null
  }
}
```

**Response:**
```json
{
  "pipeline_id": 1,
  "stage_id": "proposal",
  "position": 1,
  "deal_value": 7500.00,
  "entered_at": "2025-01-15T11:00:00Z",
  "metadata": {
    "win_lost": null
  }
}
```

## Benefícios

1. **Performance**: Queries SQL diretas em vez de consultas JSONB complexas
2. **Índices**: Índices específicos para melhorar performance de filtros e ordenação
3. **Escalabilidade**: Estrutura normalizada facilita queries complexas e agregações
4. **Consistência**: Fonte única de verdade elimina problemas de sincronização
5. **Manutenibilidade**: Código mais simples e fácil de entender
6. **Integridade**: Constraints e índices únicos garantem consistência dos dados

## Fases da Implementação

### Fase 1: Dual-Write (Histórica - REMOVIDA ❌)
- ~~Escrever em ambas as estruturas (JSON + tabela)~~
- ~~Listener automático~~
- **Status:** Removido completamente

### Fase 2: Leitura da Tabela (Histórica - REMOVIDA ❌)
- ~~Ler da tabela `contact_pipeline_positions` primeiro~~
- ~~Fallback para JSON se não encontrar na tabela~~
- **Status:** Fallback removido, leitura exclusiva da tabela

### Fase 3: Migração Completa (CONCLUÍDA ✅)
- ✅ Remover leitura do JSON
- ✅ Usar apenas a tabela para leitura e escrita
- ✅ Remover sistema de sincronização dual-write
- ✅ Remover fallback para JSON
- ✅ Migrar todos os componentes frontend

### Fase 4: Correções de Compatibilidade (CONCLUÍDA ✅)
Após a migração completa, foram identificados e corrigidos alguns locais que ainda usavam a estrutura antiga `additional_attributes.kanban`:

**Correções Realizadas:**

1. **KanbanColumn.vue - `columnTotal` computed**
   - **Problema:** Estava lendo `deal_value` de `additional_attributes.kanban[pipelineId].deal.value`
   - **Solução:** Atualizado para usar `getDealValue()` do `pipelinePositionsHelper.js`
   - **Arquivo:** `app/javascript/dashboard/routes/dashboard/crm/components/KanbanColumn.vue`

2. **KanbanDashboard.vue - `longestInStage` computed**
   - **Problema:** Estava usando `additional_attributes.kanban` para calcular tempo na etapa e valores
   - **Solução:** Atualizado para usar `pipeline_positions` diretamente
   - **Arquivo:** `app/javascript/dashboard/routes/dashboard/crm/components/KanbanDashboard.vue`

3. **KanbanAttributes.vue - Métodos de migração legados**
   - **Problema:** Métodos `migrateContactsStageTracking()` e `migrateToGroupedStructure()` ainda escreviam na estrutura antiga
   - **Solução:** Desabilitadas as chamadas, pois a migração já foi concluída
   - **Arquivo:** `app/javascript/dashboard/routes/dashboard/crm/components/KanbanAttributes.vue`

**Status:** ✅ Todos os locais que ainda usavam a estrutura antiga foram corrigidos ou desabilitados

## Limpeza Opcional (Futuro)

Após validar que tudo está funcionando corretamente com `contact_pipeline_positions`, você pode opcionalmente limpar os dados kanban dos campos JSON:

```ruby
# Script para limpar dados kanban do JSON (executar após validação)
Contact.find_each do |contact|
  # Limpar custom_attributes de atributos kanban
  # Limpar additional_attributes.kanban
  
  # Nota: Execute com cuidado e faça backup antes!
end
```

**⚠️ Aviso:** Faça backup do banco de dados antes de executar qualquer limpeza de dados!

## Problemas Conhecidos e Correções

### Problema: Total da Coluna Não Aparecia Corretamente

**Sintoma:** O total monetário no cabeçalho da coluna não mostrava o valor correto, mesmo com cards tendo `deal_value`.

**Causa:** O computed `columnTotal` em `KanbanColumn.vue` estava lendo `deal_value` da estrutura antiga `additional_attributes.kanban[pipelineId].deal.value` em vez de usar `pipeline_positions`.

**Solução:** 
- Importado `getDealValue` do `pipelinePositionsHelper.js`
- Atualizado o computed para usar `getDealValue(contact, pipelineId)` que lê de `pipeline_positions`

**Arquivo Corrigido:** `app/javascript/dashboard/routes/dashboard/crm/components/KanbanColumn.vue`

### Problema: Dashboard Mostrava Dados Incorretos

**Sintoma:** A seção "Mais Tempo na Etapa" do dashboard não mostrava os cards corretos ou mostrava valores zerados.

**Causa:** O computed `longestInStage` em `KanbanDashboard.vue` estava usando `additional_attributes.kanban` para obter `entered_at` e `deal_value`.

**Solução:**
- Atualizado para usar `contact.pipeline_positions` diretamente
- Lê `entered_at` e `deal_value` de `pipeline_positions`
- Lê `win_lost` status de `metadata.win_lost` em `pipeline_positions`

**Arquivo Corrigido:** `app/javascript/dashboard/routes/dashboard/crm/components/KanbanDashboard.vue`

### Problema: Métodos de Migração Ainda Executando

**Sintoma:** Métodos legados de migração ainda tentavam escrever na estrutura antiga durante o carregamento.

**Causa:** Métodos `migrateContactsStageTracking()` e `migrateToGroupedStructure()` ainda estavam sendo chamados no `mounted()` do componente.

**Solução:**
- Desabilitadas as chamadas desses métodos, pois a migração já foi concluída
- Métodos mantidos no código para referência histórica, mas não executam mais

**Arquivo Corrigido:** `app/javascript/dashboard/routes/dashboard/crm/components/KanbanAttributes.vue`

## Troubleshooting

### Cards não aparecem no kanban

1. **Verifique se os dados estão na tabela:**
   ```ruby
   # Rails console
   ContactPipelinePosition.where(pipeline_id: pipeline_id).count
   ```

2. **Verifique se a API está retornando pipeline_positions:**
   ```bash
   # Teste a API
   curl -X GET "http://localhost:3000/api/v1/accounts/1/contacts/123" \
     -H "api_access_token: YOUR_TOKEN"
   ```

3. **Verifique os logs do frontend:**
   - Abra o DevTools do navegador
   - Verifique a aba Network para requisições de API
   - Verifique a aba Console para erros JavaScript

### Dados não são atualizados

1. **Verifique se a requisição está sendo enviada:**
   ```javascript
   // Adicione log antes da chamada
   console.log('Atualizando pipeline position:', {
     contactId,
     pipelineId,
     stageId,
     dealValue,
     metadata
   });
   ```

2. **Verifique a resposta da API:**
   - Abra o DevTools → Network
   - Encontre a requisição `PUT /pipeline_positions/:pipeline_id`
   - Verifique o status code e a resposta

3. **Verifique os logs do backend:**
   ```bash
   tail -f log/development.log | grep "pipeline_positions"
   ```

### Erro ao criar pipeline position

1. **Verifique se o contato e pipeline existem:**
   ```ruby
   # Rails console
   Contact.find(contact_id)
   CustomAttributeDefinition.find(pipeline_id)
   ```

2. **Verifique constraints:**
   ```ruby
   # Rails console
   position = ContactPipelinePosition.new(
     contact_id: contact_id,
     pipeline_id: pipeline_id,
     stage_id: stage_id
   )
   position.valid?
   position.errors.full_messages
   ```

## Métodos Helper Disponíveis

### Backend (Ruby)

O concern `ContactKanbanData` adiciona métodos úteis ao modelo `Contact`:

```ruby
# Verificar se contato está em um pipeline
contact.in_pipeline?(pipeline_id) # => true/false

# Obter stage_id
contact.kanban_stage_for_pipeline(pipeline_id) # => "lead"

# Obter deal_value
contact.kanban_deal_value_for_pipeline(pipeline_id) # => 1000.50

# Obter metadata (win/lost, etc)
contact.kanban_metadata_for_pipeline(pipeline_id) # => { "win_lost" => {...} }

# Obter entered_at
contact.kanban_entered_at_for_pipeline(pipeline_id) # => Time

# Obter todos os dados do pipeline
contact.kanban_data_for_pipeline(pipeline_id)
# => { stage_id: "lead", deal_value: 1000.50, entered_at: Time, metadata: {...} }
```

**Todos os métodos leem exclusivamente de `contact_pipeline_positions`!**

### Frontend (JavaScript)

O helper `pipelinePositionsHelper.js` fornece funções utilitárias:

```javascript
import { 
  getStage, 
  getDealValue, 
  getEnteredAt, 
  getWinLostStatus,
  getPipelinePosition 
} from '../utils/pipelinePositionsHelper';

// Obter stage de um contato para um pipeline
const stage = getStage(contact, pipelineId);

// Obter deal value
const dealValue = getDealValue(contact, pipelineId);

// Obter data de entrada no stage
const enteredAt = getEnteredAt(contact, pipelineId);

// Obter status win/lost
const winLost = getWinLostStatus(contact, pipelineId);
// Retorna: { status: 'won' | 'lost' | null, ...metadata }

// Obter todos os dados da posição
const position = getPipelinePosition(contact, pipelineId);
// Retorna: { stage_id, deal_value, entered_at, metadata, position }
```

## Considerações de Performance

- ✅ Queries SQL diretas sem parsing JSONB
- ✅ Índices específicos para melhorar performance
- ✅ LEFT JOIN eficiente para filtros
- ✅ Estrutura normalizada facilita agregações
- ✅ Sem overhead de sincronização ou dual-write

## Segurança

- ✅ Validações no modelo `ContactPipelinePosition`
- ✅ Foreign keys garantem integridade referencial
- ✅ Índice único previne duplicatas (contact_id, pipeline_id)
- ✅ Authorization checks no controller
- ✅ Validação de tipos e valores no frontend

## Vantagens da Implementação Atual

### Performance
- ✅ Queries SQL diretas em vez de JSONB parsing
- ✅ Índices específicos (`pipeline_id`, `stage_id`, etc)
- ✅ LEFT JOIN eficiente para filtros
- ✅ Sem overhead de sincronização

### Escalabilidade
- ✅ Estrutura normalizada facilita queries complexas
- ✅ Suporta milhões de registros sem degradação
- ✅ Índices compostos para queries comuns
- ✅ Fácil adicionar novos campos sem breaking changes

### Manutenibilidade
- ✅ Código limpo e organizado
- ✅ Concern reutilizável no backend
- ✅ Helper functions centralizadas no frontend
- ✅ Fonte única de verdade
- ✅ Sem complexidade de sincronização

### Integridade
- ✅ Constraints garantem consistência
- ✅ Índice único previne duplicatas
- ✅ Foreign keys garantem referencial integrity
- ✅ Sem problemas de sincronização entre JSON e tabela

---

**Status:** ✅ MIGRAÇÃO COMPLETA - 100% `contact_pipeline_positions`

**Data da Migração Completa:** 2025-01-15

**Data das Correções de Compatibilidade:** 2025-01-20

**Versão:** 3.1
