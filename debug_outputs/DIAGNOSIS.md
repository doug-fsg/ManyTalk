# Diagnóstico — anexos / variáveis `{{anexo:*}}` na rota IA (config 296)

**Rota:** `/app/accounts/624/settings/ia/296/edit`  
**Escopo:** upload de referência, variável no prompt, envio no chat real e no chat de teste  
**Método:** systematic-debugging (Fase 1–2) + safe-debug (sem alteração de código)

---

## Fluxo esperado (resumo)

```mermaid
flowchart LR
  A[Upload em ReferenceFilesEditor] --> B[Blob via /upload]
  B --> C[Salvar config: attach reference_files]
  C --> D[Token {{anexo:key}} no prompt / passos]
  D --> E[LLM responde com token em bloco isolado]
  E --> F[ReplyBlocks.parse]
  F --> G{token só no bloco?}
  G -->|sim| H[ResponseSender / test messages attachment]
  G -->|não| I[Texto literal com {{anexo:...}}]
```

---

## Evidência na config 296 (ambiente local)

| Campo | Valor relevante |
|--------|------------------|
| Anexo persistido | `IMG_5612.jpg` → token **`{{anexo:img_5612}}`** |
| Passo do roteiro | `"de uma saudacao , e envie isso {{anexo:img_5612}}"` (token **inline** na instrução) |

Teste `ReplyBlocks.parse` com esse token:

| Resposta simulada da IA | Resultado |
|-------------------------|-----------|
| `{{anexo:img_5612}}` (bloco só com variável) | **attachment** |
| `Segue\n{{anexo:img_5612}}` (variável em linha própria) | texto + **attachment** |
| `Segue\n\n{{anexo:img_5612}}` | texto + **attachment** |
| `Segue: {{anexo:img_5612}}` (mesma linha) | **texto literal** (anexo não enviado) |

**Causa raiz principal (alta confiança):** `AiAttendant::ReferenceVariables.extract_key` só resolve anexo quando o **bloco inteiro** é a variável (ou a variável sozinha em uma linha dentro de um parágrafo multilinha). Texto na mesma linha que `{{anexo:...}}` **nunca** vira attachment.

Isso entra em conflito com:

1. Passos do roteiro que mandam “envie isso {{anexo:…}}” na mesma frase (`behavior_script.rb` repassa a instrução literalmente).
2. Instrução em `PromptBuilder#files_section`: “bloco contendo **apenas** a variável” — o modelo frequentemente imita o estilo do passo e coloca saudação + token na mesma bolha.

---

## Bugs / gaps ranqueados

### 1. Crítico — token inline não vira anexo (chat + teste)

- **Onde:** `app/services/ai_attendant/reference_variables.rb` (`extract_key`), `app/services/ai_attendant/reply_blocks.rb` (`block_for` / `matching_file`).
- **Sintoma:** Cliente vê `{{anexo:img_5612}}` como texto; chat de teste idem; `ResponseSender` manda mensagem de texto.
- **Gatilho típico:** passo “saudação e envie isso {{anexo:…}}”; resposta “Olá! {{anexo:…}}”.
- **Config 296:** cenário reproduzível pelo conteúdo atual do passo.

### 2. Alto — chat de teste ignora rascunho não salvo

- **Onde:** `Editor.vue` → `AiAttendantTestModal` → `POST .../ai_attendant_configs/:id/test` (só `id` persistido).
- **Sintoma:** anexo recém-enviado (blob ok, mas `reference_file_blob_ids` ainda não salvos), passos, contexto ou regras editados **não** entram no teste.
- **Esperado pelo usuário:** “testar o que estou editando”; **comportamento real:** última versão salva no banco.

### 3. Médio — histórico do chat real não registra variável de anexo

- **Onde:** `ProcessMessageJob#conversation_history` usa só `message.content`.
- **Sintoma:** mensagens de attachment saem com `content: ''`; o histórico para a LLM **não** contém `{{anexo:…}}` (diferente do sandbox, que usa `historyContent` em `aiAttendantTestThread.js`).
- **Efeito:** turnos seguintes — modelo pode repetir envio ou não “lembrar” que já mandou o arquivo.

### 4. Médio — fragilidade do formato da resposta da IA

- **Onde:** `PromptBuilder#files_section` + regras de bloco `\n\n`.
- **Sintoma:** mesmo com prompt correto, respostas com token em markdown, aspas ou frase na mesma linha falham (sem fallback de extração inline).

### 5. Baixo — UX

- Botão **Testar** sem aviso de alterações/anexos pendentes.
- Remover anexo não remove tokens já inseridos no texto (token órfão → texto literal).

---

## O que está correto (sanity check)

- Slug front (`aiAttendantReferenceVariables.js`) vs back (`ReferenceVariables#slug`) alinhados nos casos testados (incl. `IMG_5612.jpg` → `img_5612`).
- `lookup_file` aceita `img_5612` vs `img-5612` via `normalize_key`.
- Upload + save + jbuilder devolvem token coerente (`{{anexo:img_5612}}` na API).
- Test modal: `ReplyBlocks.as_json` + `attachmentFromTestBlock` renderizam attachment quando `type === 'attachment' && url`.
- `ResponseSender` envia `signed_id` quando o bloco é `:attachment`.

---

## Hipótese única para validar em produção (Fase 3)

**“A IA responde com o token na mesma linha da saudação porque o passo do roteiro modela isso, e `ReplyBlocks` não extrai tokens inline.”**

**Teste mínimo:** no chat de teste, simular resposta só `{{anexo:img_5612}}` (via stub ou instrução explícita ao modelo). Se o anexo aparecer, o pipeline está ok e o problema é formato da resposta / passo inline.

---

## Arquivos-chave

| Área | Arquivo |
|------|---------|
| UI anexos | `ReferenceFilesEditor.vue`, `Editor.vue` |
| Variáveis `{` | `AiAttendantVariableField.vue`, `aiAttendantReferenceVariables.js` |
| Teste sandbox | `AiAttendantTestModal.vue`, `aiAttendantTestThread.js` |
| Resolução token → arquivo | `reference_variables.rb`, `reply_blocks.rb` |
| Envio conversa | `response_sender.rb`, `process_message_job.rb` |
| Prompt | `prompt_builder.rb`, `behavior_script.rb` |
