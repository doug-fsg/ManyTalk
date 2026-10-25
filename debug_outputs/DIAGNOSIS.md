# Diagnóstico: chat em `/app/accounts/67/dashboard`

**Data:** 24/10/2026  
**Escopo:** rota home de conversas (conta `67`, dev local)  
**Método:** reprodução no browser (`localhost:3002`), chamadas API autenticadas, leitura de código e logs (`development.log`, terminal overmind).

## Veredito

**Não há bug crítico bloqueando o chat na conta 67 no ambiente correto (Rails em `3002`).** A lista carrega 1 conversa, ao abrir `#/conversations/1` as 9 mensagens são buscadas e renderizadas no DOM.

Há **problemas de ambiente**, **performance no painel do contato** e **comportamentos que parecem defeito** mas são esperados pelo produto.

## Evidências

| Sintoma / observação | Severidade | Causa provável | Evidência |
|----------------------|------------|----------------|-----------|
| Abrir `localhost:3000` não mostra o dashboard Chatwoot | **Alta (ambiente)** | Porta `3000` ocupada por `next-server` (ManyTalks IA); Rails/Puma em **`127.0.0.1:3002`** | `ss -tlnp`: `3000` → next, `3002` → ruby; curl em `3000` retorna HTML Next.js 404 |
| Spinner no painel direito ao entrar no dashboard | **Baixa (transitório)** | `EmptyState` exibe loading enquanto `listLoadingStatus` ou `inboxes.isFetching` | `EmptyState.vue` L4–6; após carga `listLoading: false` no Vuex |
| Só a lista de conversas no `/dashboard` (sem thread) | **Info (UX)** | Layout **expandido**: `showMessageView = !isOnExpandedLayout` sem `conversationId` | `ConversationView.vue` L104–108 |
| Preview “Please rate the support” vs última atividade “John adicionou comercial” | **Info** | Card usa `last_non_activity_message`; array `messages` no payload traz só a última linha (inclui atividade) | API lista: `messages[0]` = atividade, `last_non_activity_message` = CSAT |
| `GET .../contacts/192/contactable_inboxes` repetido + Bullet “AVOID eager loading” | **Média (perf)** | Painel lateral / compose chama `fetchContactableInbox`; `fetch_contact` faz `includes` que o Bullet considera desnecessário para essa action | Terminal overmind; `contacts_controller.rb` L303–306 |
| `contactable_inboxes` → `payload: []` | **Info** | WebWidget: não permite novo contato se já existe conversa no inbox | `ContactableInboxesService#website_contactable_inbox` L37–43 |
| Thread “só uma mensagem” no snapshot a11y | **Falso positivo** | 9 mensagens no Vuex e `#message11`…`#message19` no DOM | CDP `Runtime.evaluate` após abrir conversa 1 |

### Conta 67 (dados)

- Nome: **Acme Inc**
- Inbox: `164` (Acme Support, WebWidget)
- Conversa: `display_id` **1** (`id` interno 131), contato **jane** (`192`)
- APIs com token: lista `200`, mensagens `/conversations/1/messages` `200` (9 mensagens)

### O que **não** é defeito do chat nesta rota

- Alterações locais em `App.vue` / `conversations/actions.js` (Sentry diagnostics) não mudam fluxo de mensagens.
- Jobs `Notification::*` com `DeserializationError` no log são ruído de dev (notificações apagadas), não da thread.

## Confiança

| Item | Confiança |
|------|-----------|
| Chat funcional em `3002` conta 67 | **Alta** (reproduzido) |
| Conflito de porta 3000 | **Alta** |
| Preview lista vs atividade | **Alta** (payload API) |
| Bullet / contactable_inboxes | **Média** (log + código; impacto depende de uso do painel) |

## Reprodução recomendada

1. Usar **`http://localhost:3002/app/accounts/67/dashboard`** (ou alinhar `Procfile.dev` / matar processo na 3000).
2. Login `john@acme.inc` (seed).
3. Abrir conversa **jane** → rota `/conversations/1`.
4. DevTools → Network: `conversations?status=open`, `conversations/1/messages`, opcional `contacts/192/contactable_inboxes`.
