# Smoke checklist — Fase 3 (produção MODE 2)

Marque cada item antes de deploy. Ambiente: local ou staging com assets compilados (`yarn verify:fase3` verde).

## Pré-requisitos

- [ ] `yarn verify:fase3` exit 0
- [ ] Servidor Rails rodando (`bin/rails s` ou staging)
- [ ] Conta de teste com inbox configurada

## v3app (MODE 3)

| # | Fluxo | URL / ação | Esperado |
|---|--------|------------|----------|
| 1 | Login | `/app/login` | Formulário carrega; login redireciona ao dashboard |
| 2 | Signup | `/app/auth/signup` | Formulário carrega (se signup habilitado) |

## application (dashboard, MODE 2)

| # | Fluxo | URL / ação | Esperado |
|---|--------|------------|----------|
| 3 | Inbox | `/app/accounts/:id/dashboard` | Lista de conversas visível |
| 4 | Conversa | Abrir um ticket | Mensagens carregam; reply box presente |
| 5 | Click-away | Abrir dropdown/modal com `v-on-clickaway` | Fecha ao clicar fora (CRM Kanban ou menu lateral) |

## widget

| # | Fluxo | URL / ação | Esperado |
|---|--------|------------|----------|
| 6 | Embed | Página com script do widget | Bubble abre; chat carrega |

## survey

| # | Fluxo | URL / ação | Esperado |
|---|--------|------------|----------|
| 7 | CSAT | Link de survey (email ou URL de teste) | Formulário de rating renderiza |

## portal (Help Center)

| # | Fluxo | URL / ação | Esperado |
|---|--------|------------|----------|
| 8 | Portal home | `/hc/:portal_slug` | Página carrega |
| 9 | Busca | Campo de busca no portal | `#search-wrap` monta Vue; busca responde |
| 10 | Artigo + TOC | Abrir artigo com headings | TOC lateral (`#cw-hc-toc`) aparece |
| 11 | Turbolinks | Navegar entre 2 páginas do portal | Sem duplicar busca/TOC (DevTools: uma instância por container) |

## superadmin_pages

| # | Fluxo | URL / ação | Esperado |
|---|--------|------------|----------|
| 12 | Playground | Superadmin → páginas Vue | Componente monta sem erro no console |

## Assinatura

- Data: ___________
- Ambiente: ___________
- Responsável: ___________
- Resultado: [ ] Aprovado  [ ] Bloqueado (descrever abaixo)

Notas:

---

## Rollback rápido

```bash
git checkout HEAD -- app/javascript/packs/<pack>.js
yarn verify:fase2 && yarn verify:pack <pack>
```
