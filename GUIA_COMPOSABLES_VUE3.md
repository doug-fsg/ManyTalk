# Guia de Uso dos Composables Vue 3

**Data:** Dezembro 2024  
**Versão:** Preparação Vue 3

---

## Visão Geral

Este projeto já possui uma infraestrutura completa de composables Vue 3, compatível com Vue 2.7 e preparada para Vue 3. Todos os composables seguem o padrão Composition API e podem ser usados com `<script setup>`.

---

## Composables Disponíveis

### 1. Store Composables

#### `useStore()`
Acesso direto ao Vuex store.

**Uso:**
```javascript
import { useStore } from 'dashboard/composables/store';

const store = useStore();
await store.dispatch('module/action', payload);
```

**Exemplo:**
```vue
<script setup>
import { useStore } from 'dashboard/composables/store';

const store = useStore();

const fetchData = async () => {
  await store.dispatch('labels/get');
};
</script>
```

---

#### `useStoreGetters()`
Acesso reativo a todos os getters do store.

**Uso:**
```javascript
import { useStoreGetters } from 'dashboard/composables/store';

const getters = useStoreGetters();
// Acessa: getters['module/getter'].value
```

**Exemplo:**
```vue
<script setup>
import { useStoreGetters } from 'dashboard/composables/store';
import { computed } from 'vue';

const getters = useStoreGetters();
const labels = computed(() => getters['labels/getLabels'].value);
const uiFlags = computed(() => getters['labels/getUIFlags'].value);
</script>
```

**Nota:** Todos os getters retornados são `computed`, então use `.value` para acessar o valor.

---

#### `mapGetter(key)`
Acesso reativo a um getter específico.

**Uso:**
```javascript
import { mapGetter } from 'dashboard/composables/store';

const labels = mapGetter('labels/getLabels');
// Acessa: labels.value
```

**Exemplo:**
```vue
<script setup>
import { mapGetter } from 'dashboard/composables/store';

const labels = mapGetter('labels/getLabels');
const uiFlags = mapGetter('labels/getUIFlags');
</script>
```

---

### 2. Internacionalização

#### `useI18n()`
Acesso à função de tradução `t`.

**Uso:**
```javascript
import { useI18n } from 'dashboard/composables/useI18n';

const { t } = useI18n();
const message = t('LABEL_MGMT.HEADER');
```

**Exemplo:**
```vue
<script setup>
import { useI18n } from 'dashboard/composables/useI18n';

const { t } = useI18n();
const title = t('LABEL_MGMT.HEADER');
</script>

<template>
  <h1>{{ title }}</h1>
</template>
```

---

### 3. Alertas e Notificações

#### `useAlert(message, action?)`
Exibe uma mensagem de toast.

**Uso:**
```javascript
import { useAlert } from 'dashboard/composables';

useAlert('Operação realizada com sucesso!');
useAlert('Erro ao salvar', { label: 'Tentar novamente', action: retry });
```

**Exemplo:**
```vue
<script setup>
import { useAlert } from 'dashboard/composables';

const saveData = async () => {
  try {
    await store.dispatch('module/save', data);
    useAlert('Salvo com sucesso!');
  } catch (error) {
    useAlert('Erro ao salvar');
  }
};
</script>
```

---

#### `useTrack()`
Rastreia eventos de analytics.

**Uso:**
```javascript
import { useTrack } from 'dashboard/composables';

const track = useTrack();
track('event_name', { property: 'value' });
```

**Exemplo:**
```vue
<script setup>
import { useTrack } from 'dashboard/composables';

const track = useTrack();

const handleClick = () => {
  track('button_clicked', { button: 'save' });
};
</script>
```

---

### 4. Configurações e Conta

#### `useAccount()`
Acesso a dados da conta atual.

**Uso:**
```javascript
import { useAccount } from 'dashboard/composables/useAccount';

const { accountId, account } = useAccount();
```

**Exemplo:**
```vue
<script setup>
import { useAccount } from 'dashboard/composables/useAccount';

const { accountId, account } = useAccount();
// accountId.value - ID da conta
// account.value - Objeto completo da conta
</script>
```

---

#### `useConfig()`
Acesso a configurações globais.

**Uso:**
```javascript
import { useConfig } from 'dashboard/composables/useConfig';

const config = useConfig();
// config.value - Objeto de configurações
```

**Exemplo:**
```vue
<script setup>
import { useConfig } from 'dashboard/composables/useConfig';

const config = useConfig();
const isFeatureEnabled = computed(() => config.value.featureFlag);
</script>
```

---

#### `useAdmin()`
Verifica se o usuário atual é administrador.

**Uso:**
```javascript
import { useAdmin } from 'dashboard/composables/useAdmin';

const { isAdmin } = useAdmin();
```

**Exemplo:**
```vue
<script setup>
import { useAdmin } from 'dashboard/composables/useAdmin';

const { isAdmin } = useAdmin();
</script>

<template>
  <button v-if="isAdmin">Ações de Admin</button>
</template>
```

---

### 5. Macros

#### `useMacros()`
Acesso a macros e execução.

**Uso:**
```javascript
import { useMacros } from 'dashboard/composables/useMacros';

const { macros, executeMacro } = useMacros();
```

**Exemplo:**
```vue
<script setup>
import { useMacros } from 'dashboard/composables/useMacros';

const { macros, executeMacro } = useMacros();

const handleMacro = (macroId) => {
  executeMacro(macroId, conversationId);
};
</script>
```

---

### 6. Labels de Conversação

#### `useConversationLabels()`
Gerencia labels de conversação.

**Uso:**
```javascript
import { useConversationLabels } from 'dashboard/composables/useConversationLabels';

const { labels, addLabel, removeLabel } = useConversationLabels(conversationId);
```

**Exemplo:**
```vue
<script setup>
import { useConversationLabels } from 'dashboard/composables/useConversationLabels';

const props = defineProps({
  conversationId: Number
});

const { labels, addLabel, removeLabel } = useConversationLabels(props.conversationId);
</script>
```

---

### 7. Teclado e Navegação

#### `useKeyboardEvents()`
Gerencia eventos de teclado.

**Uso:**
```javascript
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';

useKeyboardEvents({
  'Escape': () => closeModal(),
  'Enter': () => submitForm()
});
```

**Exemplo:**
```vue
<script setup>
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import { onMounted, onUnmounted } from 'vue';

const { register, unregister } = useKeyboardEvents();

onMounted(() => {
  register({
    'Escape': () => closeModal()
  });
});

onUnmounted(() => {
  unregister();
});
</script>
```

---

#### `useKeyboardNavigableList()`
Navegação por teclado em listas.

**Uso:**
```javascript
import { useKeyboardNavigableList } from 'dashboard/composables/useKeyboardNavigableList';

const { handleKeyDown, selectedIndex } = useKeyboardNavigableList(items);
```

**Exemplo:**
```vue
<script setup>
import { useKeyboardNavigableList } from 'dashboard/composables/useKeyboardNavigableList';

const items = ref([...]);
const { handleKeyDown, selectedIndex } = useKeyboardNavigableList(items);
</script>

<template>
  <div @keydown="handleKeyDown">
    <div v-for="(item, index) in items" :key="item.id">
      <div :class="{ selected: index === selectedIndex }">
        {{ item.name }}
      </div>
    </div>
  </div>
</template>
```

---

#### `useDetectKeyboardLayout()`
Detecta o layout do teclado (QWERTY, AZERTY, etc).

**Uso:**
```javascript
import { useDetectKeyboardLayout } from 'dashboard/composables/useDetectKeyboardLayout';

const layout = useDetectKeyboardLayout();
```

---

### 8. UI Settings

#### `useUISettings()`
Gerencia configurações de UI.

**Uso:**
```javascript
import { useUISettings } from 'dashboard/composables/useUISettings';

const { uiSettings, updateUISettings } = useUISettings();
```

---

### 9. Roteamento

#### `useRoute()`
Acesso à rota atual (do composable route.js).

**Uso:**
```javascript
import { useRoute } from 'dashboard/composables/route';

const route = useRoute();
const params = route.params;
```

---

### 10. Event Emitter

#### `useEmitter()` ou `emitter`
Emissor de eventos global.

**Uso:**
```javascript
import { emitter } from 'shared/helpers/mitt';

emitter.emit('event-name', data);
emitter.on('event-name', handler);
emitter.off('event-name', handler);
```

---

## Padrões de Uso Recomendados

### 1. Componente com `<script setup>`

```vue
<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { useI18n } from 'dashboard/composables/useI18n';
import { useAlert } from 'dashboard/composables';

const store = useStore();
const getters = useStoreGetters();
const { t } = useI18n();

const records = computed(() => getters['module/getRecords'].value);
const uiFlags = computed(() => getters['module/getUIFlags'].value);

onMounted(() => {
  store.dispatch('module/get');
});

const handleSave = async () => {
  try {
    await store.dispatch('module/save', data);
    useAlert(t('SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(t('ERROR_MESSAGE'));
  }
};
</script>
```

### 2. Getters que Retornam Funções

Alguns getters retornam funções para permitir parâmetros:

```vue
<script setup>
import { useStoreGetters } from 'dashboard/composables/store';

const getters = useStoreGetters();
const getSortedCannedResponses = getters['cannedResponse/getSortedCannedResponses'];

const sortOrder = ref('asc');
const records = computed(() => getSortedCannedResponses.value(sortOrder.value));
</script>
```

---

## Getters Faltantes nos Stores

### Stores que Precisam de Getters Adicionais

Para facilitar o uso com Composition API, alguns stores podem precisar de getters adicionais:

1. **Stores sem getters de ordenação:**
   - Adicionar getters similares a `getSortedCannedResponses` quando necessário

2. **Stores sem getters de UI flags:**
   - Todos os stores devem ter `getUIFlags` para consistência

3. **Stores sem getters de item único:**
   - Adicionar getters como `getItem: state => id => state.records[id]` quando necessário

### Exemplo de Getter Recomendado

```javascript
const getters = {
  getRecords(_state) {
    return _state.records;
  },
  getRecord: _state => id => {
    return _state.records.find(r => r.id === id) || {};
  },
  getSortedRecords: _state => sortOrder => {
    return [..._state.records].sort((a, b) => {
      // lógica de ordenação
    });
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};
```

---

## Migração de Options API para Composition API

### Antes (Options API)
```vue
<script>
export default {
  computed: {
    labels() {
      return this.$store.getters['labels/getLabels'];
    }
  },
  methods: {
    async fetchLabels() {
      await this.$store.dispatch('labels/get');
    }
  }
}
</script>
```

### Depois (Composition API)
```vue
<script setup>
import { computed } from 'vue';
import { useStore, useStoreGetters } from 'dashboard/composables/store';

const store = useStore();
const getters = useStoreGetters();

const labels = computed(() => getters['labels/getLabels'].value);

const fetchLabels = async () => {
  await store.dispatch('labels/get');
};
</script>
```

---

## Notas Importantes

1. **Todos os getters retornados por `useStoreGetters()` são `computed`**
   - Sempre use `.value` para acessar o valor

2. **`useStore()` retorna o store Vuex diretamente**
   - Use para dispatch de actions

3. **Composables devem ser chamados apenas dentro de `setup()`**
   - Não funcionam fora do contexto do componente

4. **Compatibilidade Vue 2.7**
   - Todos os composables funcionam com Vue 2.7
   - Preparados para Vue 3

---

**Última atualização:** Dezembro 2024

