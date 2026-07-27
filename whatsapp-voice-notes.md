# WhatsApp Voice Notes (plano enxuto)

> Revisões: **archaeologist** → **rails-expert** → **vue-best-practices**.  
> Princípio único: **mínimo de arquivos, zero abstração prematura, derivar estado, não inventar UI.**

## Overview

Flag ON + WhatsApp Cloud + gravação → OGG Opus + `voice: true`.  
1ª falha Meta → **1 retry** do mesmo `link` **sem** `voice`.  
Flag OFF → MP3 como hoje.

## Decisões

| # | Valor |
|---|--------|
| Escopo | Só gravação no reply box; Macro zero |
| Canal | Só `whatsapp_cloud` |
| Flag | `whatsapp_voice_notes`, OFF default |
| Fallback | Mesmo OGG sem `voice` (sem dual-MP3) |
| MIME (B) | No send, não no incoming |

---

## Vue: superfície mínima (obrigatório)

### O que o ReplyBox **já** tem (não reinventar)

| Já existe | Uso |
|-----------|-----|
| Options API + `computed` + `mapGetters` | Manter — **não** migrar para `<script setup>` neste PR |
| `isFeatureEnabledonAccount` + `accountId` | Mesmo padrão do gravador / features |
| `isAWhatsAppCloudChannel` (`inboxMixin`) | Gate de canal |
| `audioRecordFormat` computed | **Único** ponto FE a alterar |
| `:audio-record-format="audioRecordFormat"` → `AudioRecorder` | Props down já existe — **não** adicionar props |
| `RECORDER_CONFIG.OGG` no `AudioRecorder` | Zero mudança no filho (salvo hotfix MIME 1 linha se staging exigir) |

### Por que NÃO extrair composable / componente

| Tentação | Por que cortar |
|----------|----------------|
| `useWhatsappVoiceNotes.js` | 1 boolean derivado — composable sem reuse = over-abstraction |
| Novo componente de gravador WA | `AudioRecorder` já é o boundary; ReplyBox só escolhe formato |
| Migrar `audioRecordFormat` para Composition API | Diff ruidoso; Options API é a lei deste SFC |
| UI “Enviando como nota de voz…” | Hick: zero escolha nova pro agente; flag é invisível (UX psychology) |
| Dual encode / segundo upload no FE | Plano Rails já cortou; FE não reintroduz |

**Regra:** se não for reuse em 2+ SFCs, **não** cria composable. Aqui é 1 SFC.

### Component map (MVP)

```
ReplyBox.vue          → escolhe formato (computed) — ORQUESTRAÇÃO MÍNIMA
  └─ AudioRecorder.vue → já grava OGG/MP3/WAV conforme prop — NÃO MEXER
```

Entry/view continua thin: nenhuma feature folder nova.

### Implementação FE (texto canônico)

```js
// featureFlags.js
WHATSAPP_VOICE_NOTES: 'whatsapp_voice_notes',

// ReplyBox.vue — computed (Options API)
isWhatsappVoiceNotesEnabled() {
  return this.isFeatureEnabledonAccount(
    this.accountId,
    FEATURE_FLAGS.WHATSAPP_VOICE_NOTES
  );
},
audioRecordFormat() {
  // Cloud + flag ANTES do branch genérico isAWhatsAppChannel (que força MP3)
  if (this.isAWhatsAppCloudChannel && this.isWhatsappVoiceNotesEnabled) {
    return AUDIO_FORMATS.OGG;
  }
  if (
    this.isAWhatsAppChannel ||
    this.isATelegramChannel ||
    this.isANotificaMeChannel
  ) {
    return AUDIO_FORMATS.MP3;
  }
  if (this.isAPIInbox) {
    return AUDIO_FORMATS.OGG;
  }
  return AUDIO_FORMATS.WAV;
},
```

- Import: só `FEATURE_FLAGS` (se ainda não importado — hoje ReplyBox **não** importa FEATURE_FLAGS; adicionar **1** import).
- Template: **inalterado**.
- `onFinishRecorder` / `isRecordedAudio` / payload WhatsApp: **inalterados** (backend detecta OGG).

### Reactivity / lifecycle

- Fonte de verdade: flag na store de account + tipo do inbox (já reativos).
- `audioRecordFormat` é **derived** — sem `data` novo, sem `watch`.
- `AudioRecorder` monta quando `showAudioRecorderEditor` fica true → lê `audioRecordFormat` no `data()`/options na criação. OK: cada gravação remonta o player.
- **Não** precisa `watch` para trocar formato mid-recording.

### UX (frontend-design / psicologia) — o que NÃO fazer

- Sem toggle novo (Hick).
- Sem banner “modo nota de voz” (Von Restorff desnecessário; comportamento transparente).
- Feedback de falha: já existe bolha failed + ErrorHumanizer; retry silencioso no backend.
- Se fallback sem `voice` funcionar, agente não vê diferença além do celular do cliente — correto para MVP conservador.

### Hotfix MIME (só se staging falhar)

Uma linha em `AudioRecorder#finishRecord` quando `audioRecordFormat === OGG`:

```js
type = 'audio/ogg'; // em vez de audio/opus cru do MediaRecorder
```

**Não** planejar no PR inicial; só se 131053 aparecer com OGG gerado pelo app.

---

## Rails (resumo — inalterado na essência)

- Lógica só em `WhatsappCloudService` (privates).
- Retry **antes** de `process_response` (uma vez).
- `voice_note_eligible?` via flag + OGG/opus — sem MessageBuilder.
- MIME: `audio/opus` → `update_column` `audio/ogg` no send.

Detalhe completo: seções anteriores do plano (contrato `process_response`, specs WebMock).

---

## Superfície congelada

| Arquivo | Diff |
|---------|------|
| `config/features.yml` | +2–3 linhas |
| `featureFlags.js` | +1 constante |
| `ReplyBox.vue` | import + 1 computed helper + branch no `audioRecordFormat` (~10 linhas) |
| `whatsapp_cloud_service.rb` | ~25–40 linhas |
| `whatsapp_cloud_service_spec.rb` | +2–3 exemplos |

**Proibido:** composable, novo SFC, script setup migration, props novas no AudioRecorder, dual upload, Macro, builder, job, incoming #12850.

---

## Tasks

### T1 — Flag
`features.yml` + `FEATURE_FLAGS.WHATSAPP_VOICE_NOTES`

### T2 — Golden master (RSpec áudio sem `voice`)
Antes de patch no provider

### T3 — ReplyBox (Vue mínimo)
Conforme bloco canônico acima  
**VERIFY:** Cloud+flag → OGG; Cloud+flag off → MP3; Twilio WA → MP3; template diff vazio

### T4 — Provider + specs retry
`process_response` uma vez; voice + 1 retry sem voice

### T5 — Smoke / ops
`enable_features!` / `disable_features!` em 1 conta

## Dependency Graph

```
T1 → T3
T2 → T4
T3 + T4 → T5
```

## Fase 2 (proibida até evidência)

Dual MP3, composable, content_attributes, service object.

## Aprovação

Implementar **somente T1–T5**. FE = **um computed + um import**; sem UI nova; sem tocar `AudioRecorder` no happy path.

## ✅ Implementação (2026-07-27)

- [x] T1 Flag `whatsapp_voice_notes` (OFF default)
- [x] T2/T4 Specs voice + golden + retry
- [x] T3 ReplyBox OGG quando Cloud + flag
- [x] T4 Provider `voice: true` + 1 retry sem voice + MIME opus→ogg
- [ ] T5 Smoke manual em staging / ativar conta

### Ops

```ruby
Account.find(ID).enable_features!('whatsapp_voice_notes')
# rollback:
Account.find(ID).disable_features!('whatsapp_voice_notes')
```
