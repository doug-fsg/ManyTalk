# Guia de Migração Automática para Vue 3

**Projeto:** Chatwoot (fork customizado)  
**Versão atual:** 3.11.0  
**Data:** Agosto 2026  
**Stack atual:** Vue 2.7 + Webpack 4 + Vuex 2 + Vue Router 3

---

## Resumo

Não existe um comando único que migre este projeto para Vue 3 de forma segura. Com ~736 arquivos `.vue`, múltiplos entrypoints e dezenas de dependências Vue 2, a abordagem correta é **automatizar o máximo possível da sintaxe** e usar **@vue/compat** para rodar o app enquanto corrige o restante.

Este guia documenta ferramentas, pipeline, scripts e limitações conhecidas.

**Migração incremental em produção:** sim, é possível — ver seção [Migração incremental em produção](#migração-incremental-em-produção).

---

## Estado atual do projeto

### Números (baseline)

| Métrica | Quantidade |
|---|---|
| Arquivos `.vue` | ~736 |
| Componentes com `<script setup>` | ~165 |
| Componentes Options API (`export default {}`) | ~563 |
| Arquivos com `Vue.use` / `Vue.component` / plugins globais | ~37 |
| Entrypoints (`packs/*.js`) | 9 |
| Uso de `.native` em templates | ~3 arquivos |
| Uso de `slot` / `slot-scope` legado | ~13 arquivos |
| Filters Vue (deprecated) | ~9 ocorrências (cuidado: algumas são props/objetos, não filter Vue) |

### Entrypoints principais

```
app/javascript/packs/application.js   # Dashboard
app/javascript/packs/widget.js        # Widget
app/javascript/packs/v3app.js         # Login / v3
app/javascript/packs/survey.js
app/javascript/packs/portal.js
app/javascript/packs/publicForm.js
app/javascript/packs/superadmin_pages.js
```

Todos usam o padrão Vue 2:

```js
new Vue({
  router,
  store,
  i18n,
  render: h => h(App),
}).$mount('#app');
```

### O que já está preparado

- Vue 2.7 com Composition API disponível
- Composables em `app/javascript/dashboard/composables/` (ver `GUIA_COMPOSABLES_VUE3.md`)
- Parte dos componentes já em `<script setup>`
- `@vueuse/core` já instalado
- `@vuelidate/core` v2 já presente (mas `vuelidate` v0.7 ainda no package.json)

---

## O que pode ser automatizado

| Categoria | Ferramenta | Cobertura estimada |
|---|---|---|
| Sintaxe Vue (slots, lifecycle, filters, etc.) | GoGoCode / vue-codemod | 60–80% |
| Upgrade de deps no `package.json` | GoGoCode | Parcial |
| Detecção de breaking changes | ESLint `eslint-plugin-vue` | 100% detecção, fix parcial |
| Runtime compatível Vue 2 em Vue 3 | `@vue/compat` | Alta (não reescreve código) |
| Troca de imports de libs | Scripts custom (jscodeshift / sed) | Depende do mapa |
| Testes (`localVue` → `@vue/test-utils` v2) | Semi-automático | Média |

---

## O que NÃO será 100% automático

### Dependências Vue 2-only

| Pacote atual | Substituto Vue 3 | Notas |
|---|---|---|
| `v-tooltip` ~2.1 | `floating-vue` | API diferente |
| `vue-multiselect` ~2.1 | `vue-multiselect@next` ou componente interno | Testar UX |
| `vue-easytable` 2.5 | `@vue-easytable/vue` ou alternativa | Breaking changes |
| `vuedraggable` ^2.24 | `vuedraggable@next` (SortableJS 1.14+) | Import path muda |
| `vue-clickaway` | `@vueuse/core` (`onClickOutside`) | Já tem `@vueuse` |
| `vue2-datepicker` | `vue-datepicker-next` ou `@vuepic/vue-datepicker` | Props diferentes |
| `@braid/vue-formulate` | `@formkit/vue` ou forms nativos | Migração grande |
| `vue-color` 2.8 | `@ckpack/vue-color` | API similar |
| `vue-chartjs` 3.5 | `vue-chartjs` ^5 + `chart.js` ^4 | Chart.js também sobe |
| `vue-upload-component` | Alternativa Vue 3 ou componente próprio | Sem drop-in |
| `vue-virtual-scroll-list` | `@tanstack/vue-virtual` ou similar | API diferente |
| `vue-dompurify-html` | `vue-dompurify-html` ^5 | Versão Vue 3 |
| `vue-i18n` 8.x | `vue-i18n` 9.x | API de composables |
| `vue-router` 3.x | `vue-router` 4.x | History mode muda |
| `vuex` 2.x | `vuex` 4.x | Compatível, poucas mudanças |
| `vuelidate` 0.7 | `@vuelidate/core` + `@vuelidate/validators` | Já parcialmente migrado |
| `vue-loader` 15 | `@vitejs/plugin-vue` ou `vue-loader` 17 | Build muda |
| `vue-template-compiler` | `@vue/compiler-sfc` | Obrigatório no Vue 3 |
| `@vue/test-utils` 1.x | `@vue/test-utils` 2.x | `localVue` removido |
| `@vitejs/plugin-vue2` | `@vitejs/plugin-vue` | Só após migração |

### Áreas que exigem revisão manual

- Bootstrap de plugins globais (`Vue.use`, `Vue.component`, `Vue.prototype`)
- Specs de teste com `localVue.use(...)` e `new Vuex.Store`
- Mixins legados (migrar para composables conforme necessário)
- Filters Vue reais (converter para computed/methods/filters globais)
- Integração Sentry (`@sentry/vue` v6 → v7+ para Vue 3)
- Storybook (`@storybook/vue` → `@storybook/vue3`)

---

## Ferramentas de automação

### 1. GoGoCode (recomendado como primeiro passo)

Transforma AST de Vue 2 → Vue 3 e pode atualizar o `package.json`.

```bash
# Instalar globalmente
npm install -g gogocode-cli gogocode-plugin-vue

# IMPORTANTE: trabalhar em branch separada
git checkout -b migration/vue3-automated

# Transformar código (escreve no diretório de saída primeiro!)
gogocode -s ./app/javascript -t gogocode-plugin-vue -o ./app/javascript-vue3

# Revisar diff antes de substituir
diff -r app/javascript app/javascript-vue3 | head -100

# Se OK, substituir ou apontar saída para o mesmo dir:
# gogocode -s ./app/javascript -t gogocode-plugin-vue -o ./app/javascript

# Atualizar package.json (revisar manualmente depois!)
gogocode -s package.json -t gogocode-plugin-vue -o package.json
```

**Regras cobertas (parcial):** global API, lifecycle hooks, filters, slots, v-model, functional components, vue-router, vuex, emits, directives.

Docs: https://github.com/thx/gogocode/tree/main/packages/gogocode-plugin-vue

---

### 2. @originjs/vue-codemod

Alternativa/complemento ao GoGoCode. Modifica arquivos in-place.

```bash
npx @originjs/vue-codemod app/javascript -a -f log
```

Gera log (`log`) com padrões que precisam de intervenção manual.

Docs: https://github.com/originjs/vue-codemod

---

### 3. @vue/compat (migration build)

Permite rodar Vue 3 com comportamento Vue 2 configurável. Essencial para migração incremental.

#### package.json

```diff
 "dependencies": {
-  "vue": "^2.7.0",
+  "vue": "^3.4.0",
+  "@vue/compat": "^3.4.0",
   ...
 },
 "devDependencies": {
-  "vue-template-compiler": "^2.7.0",
+  "@vue/compiler-sfc": "^3.4.0",
-  "@vitejs/plugin-vue2": "^2.3.1",
+  "@vitejs/plugin-vue": "^5.0.0",
 }
```

#### vite.config.ts (vitest / dev futuro)

```ts
import vue from '@vitejs/plugin-vue';

export default defineConfig({
  plugins: [
    vue({
      template: {
        compilerOptions: {
          compatConfig: {
            MODE: 2, // Vue 2 behavior
          },
        },
      },
    }),
  ],
  resolve: {
    alias: {
      vue: '@vue/compat',
      // ... aliases existentes
    },
  },
});
```

#### Webpack (build atual de produção)

Adicionar alias no config do Webpacker:

```js
resolve: {
  alias: {
    vue: '@vue/compat/dist/vue.esm-bundler.js',
  },
},
module: {
  rules: [
    {
      test: /\.vue$/,
      loader: 'vue-loader',
      options: {
        compilerOptions: {
          compatConfig: { MODE: 2 },
        },
      },
    },
  ],
},
```

#### Desligar compat gradualmente

Conforme warnings desaparecem, ir setando flags para `false`:

```js
compatConfig: {
  MODE: 2,
  GLOBAL_MOUNT: false,
  GLOBAL_EXTEND: false,
  // ...
}
```

Docs: https://v3-migration.vuejs.org/migration-build.html

---

### 4. ESLint como detector automático

Adicionar/ativar regras Vue 3 no `.eslintrc`:

```json
{
  "extends": ["plugin:vue/vue3-recommended"],
  "rules": {
    "vue/no-deprecated-filter": "error",
    "vue/no-deprecated-v-bind-sync": "error",
    "vue/no-deprecated-slot-attribute": "error",
    "vue/no-deprecated-v-on-native-modifier": "error",
    "vue/no-v-for-template-key-on-child": "error",
    "vue/no-deprecated-destroyed-lifecycle": "error"
  }
}
```

Rodar:

```bash
pnpm eslint app/javascript --ext .vue,.js
pnpm eslint app/javascript --ext .vue,.js --fix  # corrige o que for possível
```

---

### 5. Scripts custom (jscodeshift / ast-grep)

Para padrões repetidos que codemods genéricos não cobrem.

#### Exemplo: trocar imports de libs

```bash
# vuedraggable v2 → v4
find app/javascript -name '*.vue' -o -name '*.js' | xargs sed -i \
  "s/from 'vuedraggable'/from 'vuedraggable\/dist\/vuedraggable.common'/g"

# vue-clickaway → @vueuse/core (requer refactor manual do uso)
grep -rl "vue-clickaway" app/javascript --include='*.{vue,js}'
```

#### Exemplo: ast-grep para lifecycle hooks

```yaml
# migrate-lifecycle.yml
id: migrate-destroyed
language: javascript
rule:
  pattern: destroyed()
fix: unmounted()
```

```bash
sg scan -r migrate-lifecycle.yml app/javascript
```

---

### 6. Migração em lote com agentes (Cursor / scripts)

Para áreas onde codemod falha:

1. Dividir por pasta: `packs/` → `dashboard/routes/` → `widget/` → `specs/`
2. Prompt fixo por lote: "Migrar para Vue 3 compat, manter comportamento, não alterar lógica de negócio"
3. Rodar testes após cada pasta

Ordem sugerida:

```
1. app/javascript/packs/          (entrypoints)
2. app/javascript/shared/         (menor, reutilizado)
3. app/javascript/v3/             (login, menor)
4. app/javascript/survey/
5. app/javascript/widget/
6. app/javascript/dashboard/      (maior, por subpasta)
7. specs (*.spec.js)
```

---

## Pipeline recomendado

```
┌─────────────────────────────────────────────────────────┐
│  FASE 0: Preparação                                     │
│  • Branch migration/vue3                                │
│  • Backup / tag do estado atual                         │
│  • Rodar testes baseline (pnpm test)                    │
└──────────────────────────┬──────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────┐
│  FASE 1: Codemod (GoGoCode ou vue-codemod)              │
│  • Output em dir separado, revisar diff                 │
│  • Aplicar no app/javascript                            │
└──────────────────────────┬──────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────┐
│  FASE 2: @vue/compat                                    │
│  • Atualizar vue, compiler-sfc, alias                   │
│  • Subir app em dev, coletar warnings no console        │
└──────────────────────────┬──────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────┐
│  FASE 3: Dependências Vue 2 → Vue 3                     │
│  • Trocar libs uma a uma (tabela acima)                 │
│  • Script de imports + teste manual por feature         │
└──────────────────────────┬──────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────┐
│  FASE 4: Entrypoints                                    │
│  • new Vue → createApp                                  │
│  • Vue.use → app.use                                    │
│  • Vue.component → app.component                        │
└──────────────────────────┬──────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────┐
│  FASE 5: Testes                                         │
│  • @vue/test-utils v2                                   │
│  • Remover localVue, usar global.plugins                │
└──────────────────────────┬──────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────┐
│  FASE 6: Remover compat                                 │
│  • compatConfig flags → false                           │
│  • Remover @vue/compat, alias vue                       │
│  • @vitejs/plugin-vue definitivo                        │
└─────────────────────────────────────────────────────────┘
```

> **Variante incremental:** o pipeline acima pode ser executado **por lote em produção** — ver [Migração incremental em produção](#migração-incremental-em-produção).

---

## Migração incremental em produção

### Resposta curta

**Sim.** Você pode migrar em partes, colocar em produção, testar em produção e só então avançar para o próximo lote.

O Chatwoot facilita isso porque **não é um único bundle**: cada `packs/*.js` vira um JS separado (`application.js`, `widget.js`, `survey.js`, etc.). Cada página carrega só o bundle dela.

A regra de ouro:

> **Vue 2 e Vue 3 não podem conviver na mesma página/bundle.**  
> **Mas bundles diferentes podem estar em versões diferentes durante a transição.**

---

### Três estratégias (do mais simples ao mais granular)

| Estratégia | O que vai pra produção | Risco | Quando usar |
|---|---|---|---|
| **A — @vue/compat no app inteiro** | Todo o frontend em Vue 3 runtime, comportamento Vue 2 | Baixo | Primeiro deploy Vue 3; validar que nada quebrou |
| **B — Um entrypoint (pack) por vez** | Só `survey.js`, depois só `widget.js`, etc. | Médio | Isolar blast radius por superfície |
| **C — Compat flags por lote** | Mesmo bundle, desligando flags de compat aos poucos | Baixo–médio | Refino depois da estratégia A |

Na prática, combine **A → B → C**:

1. Deploy 1: app inteiro com `@vue/compat` (MODE 2)
2. Deploys 2–N: migrar packs menores para Vue 3 “puro”
3. Deploy final: `application.js` (dashboard) sem compat

---

### Por que funciona neste projeto

Cada entrypoint é independente no build:

```
/packs/js/application.js   → Dashboard (agentes)
/packs/js/widget.js        → Widget no site do cliente
/packs/js/survey.js        → Pesquisa CSAT
/packs/js/v3app.js         → Login / signup
/packs/js/portal.js        → Help center
/packs/js/publicForm.js    → Formulários públicos
/packs/js/sdk.js           → SDK (sem Vue)
```

Uma página de widget **não carrega** o bundle do dashboard. Isso permite testar Vue 3 no widget em produção enquanto o dashboard ainda está em Vue 2.

**Atenção:** `app/javascript/shared/` é compartilhado entre packs. Código em `shared/` precisa funcionar na versão Vue dos packs que o importam.

---

### Estratégia A: @vue/compat no app inteiro (recomendada para o 1º deploy)

Menor risco para o primeiro passo em produção.

**O que muda:** runtime vira Vue 3; sintaxe e comportamento continuam Vue 2.

**O que NÃO muda:** componentes, stores, rotas — tudo igual visualmente.

```bash
# Deploy 1 — checklist
1. Instalar vue@3 + @vue/compat
2. Alias vue → @vue/compat no Webpack/Vite
3. compatConfig: { MODE: 2 }
4. pnpm test + smoke test staging
5. Deploy produção
6. Monitorar Sentry/console por 24–48h
7. Só então começar lote 2
```

**Vantagem:** um único deploy valida Vue 3 em todas as superfícies de uma vez, com rollback simples (reverter o deploy).

**Desvantagem:** o diff de deps é grande, mas o diff de código dos componentes pode ser mínimo.

---

### Estratégia B: Um entrypoint (pack) por vez

Migrar e testar cada bundle separadamente em produção.

#### Ordem sugerida (menor → maior impacto)

| Lote | Pack | Motivo |
|---|---|---|
| 0 | `sdk.js` | Sem Vue; zero risco Vue |
| 1 | `survey.js` | Pequeno, tráfego limitado |
| 2 | `v3app.js` | Login isolado |
| 3 | `publicForm.js` | Formulários públicos |
| 4 | `superadmin_pages.js` | Poucos usuários |
| 5 | `portal.js` | Help center |
| 6 | `widget.js` | Alto tráfego, mas bundle isolado |
| 7 | `application.js` | Dashboard — deixar por último |

#### Config Webpack: alias por entrypoint

Enquanto dashboard ainda é Vue 2, o widget pode usar Vue 3:

```js
// webpack config (conceito — adaptar ao Webpacker do projeto)
module.exports = {
  resolve: {
    alias: {
      // default: Vue 2
      vue: 'vue/dist/vue.esm.js',
    },
  },
  module: {
    rules: [
      {
        test: /widget\.js$/,
        resolve: {
          alias: {
            vue: '@vue/compat/dist/vue.esm-bundler.js',
          },
        },
      },
    ],
  },
};
```

Alternativa mais simples: **dois aliases no código** durante a transição:

```js
// packs/widget.js — já migrado
import { createApp } from 'vue'; // resolve para @vue/compat ou vue3

// packs/application.js — ainda Vue 2
import Vue from 'vue'; // resolve para vue2
```

Para isso, use `resolve.alias` condicional por entry ou pacotes npm alias (`vue2`, `vue3` no package.json).

#### Fluxo por lote

```
┌──────────────────────────────────────────────────────────┐
│  LOTE N: ex. widget.js                                   │
├──────────────────────────────────────────────────────────┤
│  1. Codemod só em app/javascript/widget/ + pack          │
│  2. Ajustar deps usadas pelo widget                      │
│  3. Testes + staging                                     │
│  4. Deploy produção                                      │
│  5. Testar widget em site real (embed)                   │
│  6. Monitorar Sentry filtrando widget.js                 │
│  7. Tag git: vue3-widget-done                            │
│  8. Próximo lote                                         │
└──────────────────────────────────────────────────────────┘
```

---

### Estratégia C: Compat flags por lote (dentro de um pack)

Depois do compat global, desligue flags aos poucos e faça deploy a cada grupo.

```js
// Lote 1 — só GLOBAL_MOUNT
compatConfig: {
  MODE: 2,
  GLOBAL_MOUNT: false,
}

// Lote 2 — lifecycle
compatConfig: {
  MODE: 2,
  GLOBAL_MOUNT: false,
  INSTANCE_EVENT_EMITTER: false,
  COMPONENT_FUNCTIONAL: false,
}

// ... até remover @vue/compat
```

Cada deploy = um grupo de flags `false` + testes em produção.

---

### Código compartilhado (`shared/`)

Principal ponto de atrito na migração por pack.

| Situação | Solução |
|---|---|
| Componente `shared/` usado só por packs já migrados | Migrar junto com o pack |
| Componente usado por Vue 2 e Vue 3 ao mesmo tempo | Manter compatível com ambos **ou** duplicar temporariamente |
| Helper JS puro (sem Vue) | Migrar quando quiser; não bloqueia |
| Composable | Funciona em Vue 2.7 e Vue 3; migrar cedo |

**Regra prática:** migre `shared/` **junto com o último pack que ainda depende dele**, ou garanta que funciona nos dois runtimes até todos os packs migrarem.

Durante a transição, evite refactors grandes em `shared/` — prefira mudanças mínimas e compatíveis.

---

### Workflow: deploy → produção → testar → próximo lote

#### Antes de cada deploy

```bash
git checkout -b migration/vue3-lote-N-descricao
pnpm test
pnpm eslint app/javascript/caminho/do/lote
# staging smoke test
git tag pre-vue3-lote-N
git push origin pre-vue3-lote-N
```

#### Deploy produção

```bash
# seu fluxo normal (Docker, Capistrano, etc.)
RAILS_ENV=production bundle exec rake assets:precompile
# deploy
```

#### Testar em produção (por lote)

| Lote | O que testar em prod |
|---|---|
| Compat global | Login, dashboard, widget embed, survey, portal |
| `survey.js` | Link CSAT real; responder pesquisa |
| `v3app.js` | Login, logout, signup, reset password |
| `widget.js` | Widget em site cliente; abrir chat; enviar msg |
| `portal.js` | Artigos, busca, navegação |
| `application.js` | Conversas, CRM, workflows, settings, reports |

#### Monitoramento

- **Sentry:** filtrar por `pack` / URL / release tag (`vue3-lote-N`)
- **Console:** warnings `@vue/compat` (staging; em prod evite log excessivo)
- **Métricas:** erros JS, tempo de load dos bundles migrados
- **Janela de observação:** 24–48h antes do próximo lote (widget/dashboard: 72h)

#### Rollback por lote (sem reverter tudo)

```bash
# Opção 1: revert do commit do lote
git revert <commit-do-lote-N>
# redeploy

# Opção 2: voltar à tag anterior
git checkout pre-vue3-lote-N
# redeploy

# Opção 3: feature flag (se implementar)
# PACK_VUE3_WIDGET=false no ENV → webpack usa entry Vue 2
```

Cada lote deve ser **reversível sozinho**, sem desfazer lotes anteriores já estáveis.

---

### Feature flag opcional (extra segurança)

Para packs críticos (`widget`, `application`), dá para manter **dois entrypoints** temporariamente:

```
packs/widget.js        → Vue 3 (novo)
packs/widget.legacy.js → Vue 2 (fallback)
```

No layout Rails, escolher qual carregar via ENV:

```ruby
# conceito
pack_name = ENV.fetch('VUE3_WIDGET', 'false') == 'true' ? 'widget' : 'widget_legacy'
javascript_pack_tag pack_name
```

Remove o fallback quando o lote estiver estável em produção.

---

### O que NÃO fazer em migração incremental

| ❌ Evitar | Por quê |
|---|---|
| Vue 2 e Vue 3 no **mesmo** bundle/página | Conflito de runtime |
| Migrar `application.js` antes dos packs menores | Maior blast radius |
| Refatorar `shared/` pesado no meio da transição | Quebra packs ainda em Vue 2 |
| Remover `@vue/compat` antes de todos os packs migrarem | Quebra packs legados |
| Deploy de lote sem tag git de rollback | Dificulta reverter só aquele lote |
| Pular testes em staging | Prod vira único ambiente de debug |

---

### Cronograma exemplo (8 semanas)

| Semana | Lote | Deploy prod | Observação |
|---|---|---|---|
| 1 | Prep + compat global (A) | Staging only | Validar build |
| 2 | Compat global (A) | **Produção** | Monitorar tudo |
| 3 | `survey.js` + `v3app.js` (B) | **Produção** | Superfícies pequenas |
| 4 | `portal.js` + `publicForm.js` (B) | **Produção** | |
| 5 | `widget.js` (B) | **Produção** | Alto tráfego — observar 72h |
| 6–7 | `application.js` por subpasta (B) | **Produção** | settings → conversations → CRM |
| 8 | Remover compat (C) | **Produção** | Vue 3 puro |

Ajuste o ritmo ao seu tráfego e tolerância a risco.

---

### Checklist por deploy incremental

Copie e use a cada lote:

```markdown
## Lote: _______________
- [ ] Branch criada
- [ ] Codemod/testes só no escopo do lote
- [ ] shared/ verificado (impacto cruzado)
- [ ] pnpm test passou
- [ ] Smoke test staging OK
- [ ] Tag git pre-vue3-lote-N criada
- [ ] Deploy produção
- [ ] Smoke test produção OK
- [ ] Sentry sem spike (24h)
- [ ] Documentar issues encontradas
- [ ] Tag vue3-lote-N-done
- [ ] Próximo lote definido
```

---

## Script de bootstrap (opcional)

Salvar como `scripts/migrate-vue3.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

BRANCH="migration/vue3-automated"
OUTPUT_DIR="app/javascript-vue3"

echo "==> Criando branch $BRANCH"
git checkout -b "$BRANCH" 2>/dev/null || git checkout "$BRANCH"

echo "==> Instalando ferramentas"
npm install -g gogocode-cli gogocode-plugin-vue

echo "==> Rodando GoGoCode (output separado)"
gogocode -s ./app/javascript -t gogocode-plugin-vue -o "./$OUTPUT_DIR"

echo "==> Rodando vue-codemod (log)"
npx @originjs/vue-codemod "./$OUTPUT_DIR" -a -f migration-log.txt || true

echo "==> Diff summary"
diff -rq app/javascript "$OUTPUT_DIR" | head -50

echo ""
echo "Próximos passos:"
echo "  1. Revisar diff em $OUTPUT_DIR"
echo "  2. Se OK: rsync ou mv para app/javascript"
echo "  3. Atualizar package.json com @vue/compat"
echo "  4. pnpm install && subir app"
echo "  5. Corrigir warnings do compat"
```

```bash
chmod +x scripts/migrate-vue3.sh
./scripts/migrate-vue3.sh
```

---

## Transformações manuais esperadas

### Entrypoint (application.js)

**Antes (Vue 2):**

```js
import Vue from 'vue';
import VueRouter from 'vue-router';
import Vuex from 'vuex';

Vue.use(VueRouter);
Vue.use(Vuex);

window.WOOT = new Vue({
  router,
  store,
  i18n,
  render: h => h(App),
}).$mount('#app');
```

**Depois (Vue 3):**

```js
import { createApp } from 'vue';
import { createRouter, createWebHistory } from 'vue-router';
import { createStore } from 'vuex';

const app = createApp(App);
const router = createRouter({ history: createWebHistory(), routes });
const store = createStore(/* ... */);

app.use(router);
app.use(store);
app.use(i18n);

window.WOOT = app.mount('#app');
```

### Testes (localVue → global)

**Antes:**

```js
const localVue = createLocalVue();
localVue.use(Vuex);
localVue.component('woot-button', WootButton);
```

**Depois:**

```js
import { mount } from '@vue/test-utils';

mount(Component, {
  global: {
    plugins: [store],
    components: { WootButton },
  },
});
```

### Filter Vue → computed

**Antes:**

```vue
<template>
  <span>{{ price | currency }}</span>
</template>
<script>
export default {
  filters: {
    currency(v) { return `$${v}`; }
  }
}
</script>
```

**Depois:**

```vue
<template>
  <span>{{ formatCurrency(price) }}</span>
</template>
<script setup>
const formatCurrency = (v) => `$${v}`;
</script>
```

---

## Checklist de verificação

### Por feature (smoke test)

- [ ] Login / logout (`v3app.js`)
- [ ] Dashboard carrega (`application.js`)
- [ ] Lista de conversas + abrir conversa
- [ ] Enviar mensagem
- [ ] Widget embed (`widget.js`)
- [ ] Survey (`survey.js`)
- [ ] Portal help center (`portal.js`)
- [ ] CRM / Kanban (custom)
- [ ] Workflows (custom)
- [ ] Settings (inbox, agents, labels)
- [ ] Relatórios / charts

### Comandos

```bash
# Testes JS
pnpm test

# Lint
pnpm eslint

# Build produção (quando compat estiver estável)
RAILS_ENV=production bundle exec rake assets:precompile
```

### Critérios de "migração concluída"

- [ ] Zero warnings de `@vue/compat` no console
- [ ] `@vue/compat` removido do package.json
- [ ] `vue` aponta direto para Vue 3 (sem alias)
- [ ] Todas as deps Vue 2-only substituídas
- [ ] Testes passando
- [ ] Smoke test manual OK

---

## Rollback

```bash
git checkout main   # ou branch anterior
git branch -D migration/vue3-automated  # se necessário
pnpm install        # restaurar lockfile anterior
```

Manter tag antes de começar:

```bash
git tag pre-vue3-migration
git push origin pre-vue3-migration
```

---

## Referências

- [Vue 3 Migration Guide](https://v3-migration.vuejs.org/)
- [@vue/compat (Migration Build)](https://v3-migration.vuejs.org/migration-build.html)
- [GoGoCode Vue Plugin](https://github.com/thx/gogocode/tree/main/packages/gogocode-plugin-vue)
- [@originjs/vue-codemod](https://github.com/originjs/vue-codemod)
- [Vue Router 4 Migration](https://router.vuejs.org/guide/migration/)
- [Vuex 4 Migration](https://vuex.vuejs.org/guide/migrating-to-4-0-from-3-x.html)
- [Vue I18n 9 Migration](https://vue-i18n.intlify.dev/guide/migration/vue3.html)
- Composables do projeto: `GUIA_COMPOSABLES_VUE3.md`

---

## Notas finais

1. **Migração incremental em produção é viável** — use multi-pack + `@vue/compat` + deploys pequenos (ver seção dedicada).
2. **Não converta 563 Options API → `<script setup>` de uma vez.** Options API funciona no Vue 3; migre incrementalmente.
3. **Codemod + compat > rewrite manual.** Use ferramentas para sintaxe, humanos para libs e lógica.
4. **Uma lib por vez.** Troque `vue-multiselect`, teste, commit. Troque `v-tooltip`, teste, commit.
5. **Filters com cuidado.** Nem todo `filters:` no código é filter Vue — alguns são props de CRM/Kanban.
6. **Expectativa realista:** 60–80% automatizado, 20–40% revisão manual e testes.
