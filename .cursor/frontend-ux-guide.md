# Guia Rápido - Frontend UX do Chatwoot

## 🌓 Dark Mode

### ✅ CORRETO: Use Tailwind `dark:` diretamente
O sistema já gerencia o dark mode através do `themeHelper.js` que adiciona a classe `dark` no `<body>`. **NÃO precisa criar CSS customizado para dark mode!**

```vue
<!-- ✅ CORRETO -->
<div class="bg-slate-50 dark:bg-slate-800">
  <h2 class="text-slate-900 dark:text-white">
  <p class="text-slate-600 dark:text-slate-400">
</div>
```

### ❌ ERRADO: Não use CSS customizado com `.dark-mode`
```scss
// ❌ NÃO FAÇA ISSO
.kanban-empty-state {
  background-color: var(--s-25);
  .dark-mode & {
    background-color: var(--b-800);
  }
}
```

**Por quê?** O Tailwind está configurado com `darkMode: 'class'` e detecta automaticamente a classe `dark` no `<body>`.

---

## 🎨 Cores e Backgrounds

### Backgrounds Padrão
- **Claro**: `bg-slate-50`
- **Escuro**: `dark:bg-slate-800` ou `dark:bg-slate-900`

### Textos
- **Títulos (claro)**: `text-slate-900 dark:text-white`
- **Texto secundário**: `text-slate-600 dark:text-slate-400`
- **Texto desabilitado**: `text-slate-400 dark:text-slate-500`

### Cores do Sistema (Woot)
- **Primária**: `bg-woot-500 dark:bg-woot-500`
- **Hover primário**: `hover:bg-woot-600 dark:hover:bg-woot-600`
- **Texto primário**: `text-woot-500 dark:text-woot-500`

---

## 🔘 Botões

### Botão Primário (Ação Principal)
```vue
<!-- Usando componente WootButton -->
<woot-button variant="primary">
   Novo botao
</woot-button>

<!-- Ou usando classes Tailwind diretamente -->
<button class="inline-flex items-center gap-2 px-6 py-3 bg-woot-500 hover:bg-woot-600 dark:bg-woot-500 dark:hover:bg-woot-600 text-white font-medium rounded-lg transition-colors">
   Novo botao
</button>
```

### Botão Secundário
```vue
<woot-button variant="secondary">
  Cancelar
</woot-button>
```

### Botão Success (Verde)
```vue
<woot-button variant="success">
  Salvar
</woot-button>

<!-- Ou Tailwind -->
<button class="bg-green-500 hover:bg-green-600 dark:bg-green-600 dark:hover:bg-green-700 text-white">
  Salvar
</button>
```

### Botão Clear (Transparente)
```vue
<woot-button variant="clear">
  Cancelar
</woot-button>
```

### Botão com Ícone
```vue
<button class="inline-flex items-center gap-2 px-6 py-3 bg-woot-500 hover:bg-woot-600 text-white rounded-lg">
  <fluent-icon icon="add" size="20" />
  <span>Criar Novo</span>
</button>
```

---

## 📐 Layout e Espaçamento

### Container Flex
```vue
<!-- Container que ocupa espaço disponível -->
<div class="flex items-center justify-center flex-1 px-4">
  <!-- Conteúdo -->
</div>
```

### Espaçamento Padrão
- **Padding horizontal**: `px-4` ou `px-6`
- **Padding vertical**: `py-3` ou `py-4`
- **Gap entre elementos**: `gap-2` ou `gap-4`
- **Margin bottom**: `mb-2`, `mb-4`, `mb-6`, `mb-8`

---

## 🎯 Empty States

### Estrutura Padrão
```vue
<template>
  <div class="flex items-center justify-center flex-1 px-4 bg-slate-50 dark:bg-slate-800">
    <div class="text-center max-w-md">
      <!-- Ícone -->
      <div class="mb-6 flex justify-center">
        <div class="p-4 rounded-full bg-slate-100 dark:bg-slate-800">
          <fluent-icon icon="kanban" size="64" class="text-slate-400 dark:text-slate-500" />
        </div>
      </div>

      <!-- Título -->
      <h2 class="text-2xl font-semibold text-slate-900 dark:text-white mb-2">
        {{ $t('TITLE') }}
      </h2>

      <!-- Descrição -->
      <p class="text-slate-600 dark:text-slate-400 mb-8">
        {{ $t('DESCRIPTION') }}
      </p>

      <!-- Botão de ação -->
      <woot-button variant="primary" @click="handleAction">
        {{ $t('ACTION') }}
      </woot-button>
    </div>
  </div>
</template>
```

---

## 📝 Formulários

### Inputs
```vue
<input
  type="text"
  class="block w-full h-10 px-2 rounded-md text-base bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border border-slate-200 dark:border-slate-600 focus:border-woot-500 dark:focus:border-woot-600"
/>
```

### Labels
```vue
<label class="block mb-2 text-sm font-medium text-slate-800 dark:text-slate-200">
  Nome do Campo
</label>
```

---

## 🎨 Cards e Containers

### Card Padrão
```vue
<div class="bg-white dark:bg-slate-800 rounded-lg shadow-sm border border-slate-200 dark:border-slate-700 p-4">
  <!-- Conteúdo -->
</div>
```

### Container com Background
```vue
<div class="bg-slate-50 dark:bg-slate-900 p-6">
  <!-- Conteúdo -->
</div>
```

---

## ⚡ Regras Importantes

1. **SEMPRE use `dark:` do Tailwind** - Não crie CSS customizado para dark mode
2. **SEMPRE defina background** - Elementos sem background ficam transparentes e mostram o fundo branco
3. **Use `flex-1`** para elementos que devem ocupar espaço disponível em containers flex
4. **Prefira componentes existentes** - Use `woot-button` ao invés de criar botões do zero
5. **Use i18n** - Sempre use `$t('KEY')` para textos, nunca texto hardcoded
6. **Cores consistentes** - Use as cores do sistema (woot-*, slate-*) ao invés de cores customizadas

---

## 🔍 Verificação Rápida

Antes de finalizar, verifique:
- [ ] Todos os elementos têm background definido (claro e escuro)
- [ ] Todos os textos têm cor definida para dark mode
- [ ] Botões usam as variantes corretas (primary, secondary, etc.)
- [ ] Espaçamento está consistente
- [ ] Textos estão usando i18n
- [ ] Não há CSS customizado desnecessário para dark mode

---

## 📚 Referências

- **Theme Helper**: `app/javascript/dashboard/helper/themeHelper.js`
- **Botões**: `app/javascript/dashboard/assets/scss/widgets/_buttons.scss`
- **Componente WootButton**: `app/javascript/dashboard/components/ui/WootButton.vue`
- **Tailwind Config**: `tailwind.config.js` (darkMode: 'class')

