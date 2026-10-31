# Plano de correção (propostas — aguardando aprovação)

Nenhum patch aplicado nesta análise (safe-debug).

---

## Opção A — Corrigir na resolução de blocos (recomendada para robustez)

**Objetivo:** quando a IA (ou o passo) colocar texto + `{{anexo:key}}` na mesma linha/bloco, dividir em texto + attachment.

**Escopo mínimo:**

1. Em `AiAttendant::ReplyBlocks` (ou helper em `ReferenceVariables`), após obter conteúdo de texto:
   - Se houver exatamente um `TOKEN_CAPTURE` e texto além dele, emitir bloco `:text` (texto sem token) + bloco `:attachment`.
   - Manter comportamento atual para bloco 100% token.
2. Specs em `reply_blocks_spec.rb` para:
   - `"Olá! {{anexo:img_5612}}"`
   - passo-like `"de uma saudacao , e envie isso {{anexo:img_5612}}"` como **saída** da IA (simulada).

**Risco:** baixo/médio — múltiplos tokens na mesma linha devem continuar indivisíveis (já rejeitados por `extract_key`).

---

## Opção B — Alinhar prompt + editor (complementar)

1. **Prompt:** em `files_section`, explicitar: “Se precisar falar algo antes do arquivo, use `\n\n` e em seguida um bloco só com `{{anexo:…}}`.”
2. **Editor:** ao inserir token via “Inserir” / menção `{`, opcionalmente inserir quebra de linha antes do token se o campo não estiver vazio.
3. **Validação suave:** detectar `{{anexo:` na mesma linha que outro texto em `behavior_steps` e mostrar hint (não bloquear save).

**Risco:** baixo — não garante compliance do modelo sozinho.

---

## Opção C — Teste com rascunho (produto)

Estender `POST .../test` para aceitar overlay opcional (ex.: `behavior_steps`, `company_context`, `reference_file_blob_ids` temporários) ou exigir save + aviso “Salve para testar anexos novos”.

**Risco:** médio (auth, tamanho payload, paridade com produção).

---

## Opção D — Histórico multi-turn com anexos

Em `conversation_history`, para mensagens outgoing com attachments e `content` blank, usar token derivado de `ReferenceVariables.entries` ou metadado salvo na mensagem.

**Risco:** médio — exige regra clara quando há vários anexos.

---

## Sugestão de ordem

1. **A** (fix objetivo para config 296 e casos inline).  
2. **B** (reduzir recorrência).  
3. **C** ou aviso UX rápido no botão Testar.  
4. **D** se houver queixa de “IA manda de novo / não lembra”.

---

## Correção imediata sem código (config 296)

Reescrever o passo para forçar formato compatível com o parser atual, por exemplo:

- Instrução: “Dê uma saudação. Depois envie o arquivo do passo seguinte.”
- Passo 2: “Envie apenas: `{{anexo:img_5612}}`”  

Ou uma única instrução com duas mensagens explícitas separadas por `\n\n` no texto que a IA deve **emitir**, não só no roteiro interno.
