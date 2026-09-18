# Índice — Documentação VPS ManyTalks

**Pipeline:** WhatsApp ↔ QuePasa ↔ n8n ↔ Chatwoot  
**Host:** `173.249.22.227`

---

## Por onde começar

| Situação | Documento |
|----------|-----------|
| WhatsApp Cloud **133010** inbox **610** (AGTU) | **`INCIDENTE_WHATSAPP_INBOX_610_18SET2026.md`** (+ logs: `_LOGS_`) |
| Erro "connection aborted / server offline" | `DIAGNOSTICO_INCIDENTE_15SET2026.md` → seção Erro #1 |
| HTTP 503 no webhook Chatwoot | `DIAGNOSTICO_INCIDENTE_15SET2026.md` → seção Erro #3 |
| Plano completo presente + futuro | **`ARQUITETURA_ALVO_N8N_QUEPASA_CHATWOOT.md`** |
| Estado pós-incidente Postgres 17/08 | `PLANO_ESCALA_VPS.md` |
| Auditoria histórica integrada | `AUDITORIA_CHATWOOT_N8N_QUEPASA.md` |

---

## Todos os documentos

| Arquivo | Descrição | Atualizado |
|---------|-----------|------------|
| `ARQUITETURA_ALVO_N8N_QUEPASA_CHATWOOT.md` | **Arquitetura alvo** — camadas, roadmap, diagramas, checklist | 15/09/2026 |
| `INCIDENTE_WHATSAPP_INBOX_610_18SET2026.md` | Incidente Meta 133010 — inbox 610 AGTU, causa token/WABA, ações | 18/09/2026 |
| `INCIDENTE_WHATSAPP_INBOX_610_LOGS_18SET2026.md` | Anexo — logs journalctl, Graph, Postgres, Redis | 18/09/2026 |
| `DIAGNOSTICO_INCIDENTE_15SET2026.md` | Diagnóstico sessão 15/09 — aborted, 503, 400, taxonomia | 15/09/2026 |
| `PLANO_ESCALA_VPS.md` | Plano escala pós-P0 — PgBouncer, cron, fases | 17/08/2026 |
| `AUDITORIA_CHATWOOT_N8N_QUEPASA.md` | Auditoria integrada Ago/2026 | 11/08/2026 |
| `AUDITORIA_N8N.md` | Camada n8n — rate limit, queue, workers | 11/08/2026 |
| `AUDITORIA_QUEPASA.md` | Camada QuePasa — SQLite, webhooks, API | 11/08/2026 |
| `RELATORIO_ERROS_13AGO_2026.md` | Relatório erros anteriores | 13/08/2026 |
| `Resumo do incidente.txt` | Incidente Postgres 17/08/2026 | 17/08/2026 |

---

## Mapa de problemas → documentos

| Problema | Onde ler |
|----------|----------|
| Timeout mídia / NodeApiError | Diagnóstico 15/09 · Arquitetura Fase A1 |
| 503 webhook | Diagnóstico 15/09 · Arquitetura Fluxo C |
| WhatsApp 420/403/LID | Diagnóstico 15/09 · Arquitetura matriz §5 |
| Postgres conexões | Plano Escala · Arquitetura Camada C |
| Rate limit QuePasa→n8n | Auditoria N8N N8N-01 |
| SQLite QuePasa | Auditoria QuePasa · Arquitetura C1 |
| Segurança portas | Auditorias · Arquitetura Camada D |
| Cron restart 04:00 | Diagnóstico 15/09 · Plano Escala · Arquitetura A7 |

---

## Comando rápido de saúde

```bash
curl -s -o /dev/null -w "quepasa:%{http_code} n8n:%{http_code} chatwoot:%{http_code}\n" \
  http://127.0.0.1:31000/health \
  http://127.0.0.1:5678/healthz \
  http://127.0.0.1:3000/api
```
