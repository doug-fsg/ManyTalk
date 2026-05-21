# Quality gates — Fase 3 (Vue migration)

## Matriz compile vs runtime

| Ambiente | Compat MODE | Uso |
|----------|-------------|-----|
| Webpack produção (`application`, `widget`, …) | **2** | Comportamento Vue 2 via `@vue/compat` |
| Webpack produção (`v3app`) | **3** | Piloto login/signup |
| Vitest / Vite (`vite.config.ts`, `vitest.setup.js`) | **2** | Testes unitários |

**Regra:** gate oficial do piloto v3app = `yarn verify:fase2` (webpack MODE 3 + specs `v3/`).  
Testes verdes no Vitest **não** implicam compat estrito no build de produção do dashboard.

## Gates obrigatórios (Fase 3)

```bash
yarn verify:fase3      # todos os packs Vue + specs v3
yarn verify:builds     # só webpack, mais rápido
yarn verify:fase2        # piloto v3app isolado
```

## Gates opcionais (PR / release)

| Gate | Comando | Quando rodar |
|------|---------|--------------|
| Widget bundle budget | `yarn size` | PR que altera `widget/` ou deps compartilhadas |
| ESLint incremental | `yarn eslint -- app/javascript/packs/<pack>.js app/javascript/<area>/` | Paths alterados no PR |
| Baseline `.sync` | `rg "\.sync" app/javascript --glob "*.vue" \| wc -l` | Documentar contagem; **não** bloquear Fase 3 |

## O que não bloqueia deploy (MODE 2)

- `Vue.set` em Vuex mutations
- vuelidate 0.7.x nos packs
- `.sync` em modais (`woot-modal`)
- Plugins Vue 2 (v-tooltip, vue-formulate, vuedraggable, …)

Esses itens entram na Fase 4.
