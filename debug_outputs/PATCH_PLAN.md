# Plano de patch (conservador) — chat `/accounts/67/dashboard`

**Requer aprovação explícita antes de alterar código** (política safe-debug).

## 1. Ambiente: porta do dashboard (prioridade alta, sem mudança de app)

**Problema:** `FRONTEND_URL`/hábito de usar `:3000` enquanto Puma está em `:3002` e `3000` é outro serviço.

**Patch sugerido (escolher um):**

- A) Documentar no README/dev: `overmind` usa `tmp/Procfile.dev.3001` ou matar `next-server` na 3000 e subir Rails em 3000.
- B) Ajustar script de dev para falhar rápido se `3000` não for Puma (healthcheck).

**Risco:** baixo. **Escopo:** config/docs apenas.

---

## 2. Performance: `contactable_inboxes` + `fetch_contact` (prioridade média)

**Problema:** Bullet reporta eager loading não usado ao abrir contato no chat (`includes(:contact_inboxes, :contact_pipeline_positions)` em `fetch_contact`).

**Patch sugerido (mínimo):**

- Carregar `contact_pipeline_positions` só em actions que renderizam Kanban no contato (ex.: `show`), não em `contactable_inboxes`.
- Em `ContactableInboxesService`, evitar `includes([:inbox])` onde o Bullet apontou, ou usar `preload` só para inboxes retornados.

**Verificação:** repetir fluxo painel do contato na conversa 1; Bullet sem aviso; mesma resposta JSON.

**Risco:** médio (N+1 se remover includes demais). **Savepoint:** branch dedicado + spec/request existente.

---

## 3. Consistência do último message no payload da lista (prioridade baixa)

**Problema:** `json.messages` usa `conversation.messages...last` sem `reorder` explícito; `setActiveChat` pagina com `before: data.messages[0].id`. Hoje funciona na conta 67, mas é frágil se ordem default mudar.

**Patch sugerido:**

- Em `_conversation.json.jbuilder`, usar o mesmo critério de `last_non_activity_message` ou `order(id: :desc).first` para o único item de `messages`.

**Verificação:** spec de jbuilder ou request spec da lista; abrir conversa e confirmar histórico completo.

**Risco:** baixo/médio. **Aprovação:** recomendada antes de merge.

---

## 4. Não recomendado agora

- Mudar regra de `website_contactable_inbox` (comportamento upstream Chatwoot).
- Alterar layout expandido/condensado sem pedido de produto.
