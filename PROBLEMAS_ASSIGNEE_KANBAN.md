# Problemas Identificados: Perda de Assignee no Kanban

## 🔴 Problemas Críticos

### 1. **updatePipelineCacheForContact() - PERDA DE ASSIGNEE NO CACHE**
**Localização**: `KanbanAttributes.vue` linha 2402-2446

**Problema**: Quando atualiza o cache do pipeline, cria um novo objeto `updatedPosition` **SEM preservar o assignee**:

```javascript
const updatedPosition = {
  pipeline_id: pipelineId,
  stage_id: newColumnValue,
  position: 0,
  entered_at: new Date().toISOString(),
  deal_value: null,
  metadata: {},
  // ❌ FALTA: assignee não é preservado!
};
```

**Impacto**: Se o cache for usado posteriormente (ex: ao recarregar dados), o assignee será perdido.

**Solução**: Preservar o assignee existente:
```javascript
const currentPosition = contact.pipeline_positions?.find(
  p => p.pipeline_id === pipelineId
);
const updatedPosition = {
  pipeline_id: pipelineId,
  stage_id: newColumnValue,
  position: currentPosition?.position || 0,
  entered_at: currentPosition?.entered_at || new Date().toISOString(),
  deal_value: currentPosition?.deal_value || null,
  metadata: currentPosition?.metadata || {},
  assignee: currentPosition?.assignee || null, // ✅ PRESERVAR ASSIGNEE
};
```

---

### 2. **handleDealValueUpdate() - PERDA DE ASSIGNEE NO MODAL**
**Localização**: `KanbanAttributes.vue` linha 2545-2552

**Problema**: Ao atualizar o modal (`selectedCardContact`), não inclui o `assignee`:

```javascript
this.$set(this.selectedCardContact.pipeline_positions, modalPositionIndex, {
  pipeline_id: response.data.pipeline_id,
  stage_id: response.data.stage_id,
  position: response.data.position,
  entered_at: response.data.entered_at,
  deal_value: response.data.deal_value,
  metadata: response.data.metadata || {},
  // ❌ FALTA: assignee não é incluído!
});
```

**Impacto**: O modal pode mostrar o card sem assignee, mesmo que ele tenha um dono.

**Solução**: Incluir o assignee da resposta:
```javascript
this.$set(this.selectedCardContact.pipeline_positions, modalPositionIndex, {
  pipeline_id: response.data.pipeline_id,
  stage_id: response.data.stage_id,
  position: response.data.position,
  entered_at: response.data.entered_at,
  deal_value: response.data.deal_value,
  metadata: response.data.metadata || {},
  assignee: response.data.assignee || null, // ✅ INCLUIR ASSIGNEE
});
```

---

### 3. **Race Condition: setupColumns() chamado antes da atualização do assignee**
**Localização**: `KanbanAttributes.vue` linha 1737-1744

**Problema**: Após mover o card, o código atualiza o assignee e depois chama `setupColumns()` após 100ms:

```javascript
.then((response) => {
  // Atualiza o assignee aqui (linha 1717)
  const positionData = {
    // ...
    assignee: response.data.assignee || null,
  };
  this.$set(updatedContact.pipeline_positions, positionIndex, positionData);
  
  // ⚠️ PROBLEMA: setupColumns() pode ser chamado antes do Vue processar a atualização
  this.$nextTick(() => {
    setTimeout(() => {
      this.setupColumns(); // Pode ler dados antigos se Vue ainda não atualizou
    }, 100);
  });
})
```

**Impacto**: Se `setupColumns()` for executado antes do Vue processar a atualização reativa, pode usar dados antigos sem assignee.

**Solução**: Garantir que a atualização seja processada antes de reconstruir colunas:
```javascript
.then(async (response) => {
  // Atualizar assignee
  const positionData = {
    // ...
    assignee: response.data.assignee || null,
  };
  this.$set(updatedContact.pipeline_positions, positionIndex, positionData);
  
  // Aguardar Vue processar TODAS as atualizações reativas
  await this.$nextTick();
  await this.$nextTick(); // Duplo nextTick para garantir
  
  // Agora sim, reconstruir colunas
  this.setupColumns();
  this.fetchColumnStats();
})
```

---

### 4. **updateColumnsLocally() não atualiza pipeline_positions**
**Localização**: `KanbanAttributes.vue` linha 994-1014

**Problema**: A função apenas move o objeto `contact` entre colunas, mas **não atualiza o `pipeline_positions`** do objeto:

```javascript
updateColumnsLocally(contact, newColumn, newIndex = null) {
  // Remove e adiciona o objeto contact entre colunas
  // Mas não atualiza contact.pipeline_positions.stage_id
}
```

**Impacto**: Se `setupColumns()` for chamado logo após `updateColumnsLocally()`, ele pode usar `contactsByColumn` que lê de `this.contacts`, e o `stage_id` pode estar desatualizado, causando o card aparecer na coluna errada ou perder o assignee.

**Solução**: Atualizar o `pipeline_positions` localmente também:
```javascript
updateColumnsLocally(contact, newColumn, newIndex = null) {
  // Remover card da coluna atual
  this.columns.forEach(column => {
    const index = column.items.findIndex(item => item.id === contact.id);
    if (index !== -1) {
      column.items.splice(index, 1);
    }
  });

  // ✅ ATUALIZAR pipeline_positions localmente
  if (contact.pipeline_positions && this.selectedAttribute) {
    const position = contact.pipeline_positions.find(
      p => p.pipeline_id === this.selectedAttribute.id
    );
    if (position) {
      // Preservar assignee ao atualizar stage_id
      this.$set(position, 'stage_id', newColumn);
    }
  }

  // Adicionar card na nova coluna
  const targetColumn = this.columns.find(col => col.title === newColumn);
  if (targetColumn) {
    if (newIndex !== null && newIndex >= 0 && newIndex <= targetColumn.items.length) {
      targetColumn.items.splice(newIndex, 0, contact);
    } else {
      targetColumn.items.push(contact);
    }
  }
}
```

---

### 5. **setupColumns() pode usar dados desatualizados**
**Localização**: `KanbanAttributes.vue` linha 1544

**Problema**: `setupColumns()` usa `contactsByColumn` que é um computed baseado em `this.contacts`. Se os dados em `this.contacts` não estiverem atualizados (assignee não sincronizado), o assignee será perdido:

```javascript
let contacts = this.contactsByColumn[stageName] || [];
// Se contact.pipeline_positions.assignee não estiver atualizado aqui,
// o assignee será perdido quando as colunas forem reconstruídas
```

**Impacto**: Mesmo que o assignee tenha sido atualizado na resposta da API, se `setupColumns()` for chamado antes do Vue atualizar `this.contacts`, o assignee será perdido.

**Solução**: Já coberto no problema #3 - garantir que Vue processe atualizações antes de chamar `setupColumns()`.

---

## 🟡 Problemas Menores

### 6. **Falta de validação se response.data.assignee existe**
**Localização**: `KanbanAttributes.vue` linha 1717

**Problema**: O código assume que `response.data.assignee` sempre existe ou é null, mas não valida se a resposta da API está correta:

```javascript
assignee: response.data.assignee || null,
```

**Impacto**: Se a API retornar uma resposta malformada (sem campo `assignee`), o código pode perder o assignee.

**Solução**: Validar e preservar assignee existente se resposta não tiver:
```javascript
const positionData = {
  // ...
  assignee: response.data.assignee !== undefined 
    ? response.data.assignee 
    : (currentPosition?.assignee || null), // Fallback para assignee atual
};
```

---

### 7. **Múltiplas chamadas de setupColumns() podem causar race conditions**
**Localização**: Várias linhas (962, 1154, 1168, 1223, 1233, 1646, 1740, 2558, etc.)

**Problema**: `setupColumns()` é chamado em muitos lugares, e mesmo com throttling, pode haver múltiplas execuções simultâneas.

**Impacto**: Se uma execução ler dados antes de outra atualizar o assignee, pode perder o assignee.

**Solução**: Melhorar o sistema de throttling e garantir que apenas uma atualização ocorra por vez.

---

## 📋 Resumo das Correções Necessárias

1. ✅ **Preservar assignee em `updatePipelineCacheForContact()`**
2. ✅ **Incluir assignee ao atualizar modal em `handleDealValueUpdate()`**
3. ✅ **Garantir que Vue processe atualizações antes de `setupColumns()`**
4. ✅ **Atualizar `pipeline_positions` em `updateColumnsLocally()`**
5. ✅ **Adicionar validação de fallback para assignee na resposta da API**

---

## 🧪 Como Testar

1. **Teste de perda de assignee ao mover card**:
   - Criar um card com assignee
   - Mover o card rapidamente entre colunas
   - Verificar se o assignee ainda está presente após mover

2. **Teste de cache**:
   - Mover um card com assignee
   - Recarregar a página
   - Verificar se o assignee foi preservado

3. **Teste de modal**:
   - Abrir modal de um card com assignee
   - Atualizar deal_value
   - Verificar se o assignee ainda aparece no modal

4. **Teste de race condition**:
   - Mover múltiplos cards rapidamente
   - Verificar se todos mantêm seus assignees

