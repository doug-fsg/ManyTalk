# Anexo — Logs e respostas API — Inbox 610 — 2026-09-18

Documento complementar a **`INCIDENTE_WHATSAPP_INBOX_610_18SET2026.md`**.  
Conteúdo colado tal como capturado no VPS (sem segredos).

---

## A. `journalctl` — SendReplyJob — erro 133010 (2026-09-18, 15:55–16:30 BRT)

Serviço: `chatwoot-worker.1`  
Host: `vmi1313120.contaboserver.net`

```text
Sep 18 15:59:31 vmi1313120.contaboserver.net chatwoot-worker.1[3430331]: E, [2026-09-18T15:59:31.791281 #3430331] ERROR -- : [ActiveJob] [SendReplyJob] [4f232de8-5bc8-4c61-96c2-4fe8a1547bb9] {"error":{"message":"(#133010) Account not registered","code":133010,"type":"OAuthException","fbtrace_id":"ALQ2LOYa4QM62xFAHj4JKKD"}}
Sep 18 16:00:26 vmi1313120.contaboserver.net chatwoot-worker.1[3430331]: E, [2026-09-18T16:00:26.316997 #3430331] ERROR -- : [ActiveJob] [SendReplyJob] [6e4a1afe-b0ce-4f8e-bfbc-50df8aa103c6] {"error":{"message":"(#133010) Account not registered","code":133010,"type":"OAuthException","fbtrace_id":"AO0Ky8TvdXZzeHk3lz8j_-N"}}
Sep 18 16:00:57 vmi1313120.contaboserver.net chatwoot-worker.1[3430331]: E, [2026-09-18T16:00:57.576018 #3430331] ERROR -- : [ActiveJob] [SendReplyJob] [02c69e76-be19-4f4a-96aa-e983d9a40383] {"error":{"message":"(#133010) Account not registered","code":133010,"type":"OAuthException","fbtrace_id":"A1U6OdWocAupHWctj5Av_Y6"}}
Sep 18 16:01:02 vmi1313120.contaboserver.net chatwoot-worker.1[3430331]: E, [2026-09-18T16:01:02.092254 #3430331] ERROR -- : [ActiveJob] [SendReplyJob] [40cc0efc-af15-47c6-a1ee-4c4b149de253] {"error":{"message":"(#133010) Account not registered","code":133010,"type":"OAuthException","fbtrace_id":"AIUR_QApY883urUFx6Yuv9P"}}
Sep 18 16:02:50 vmi1313120.contaboserver.net chatwoot-worker.1[3430331]: E, [2026-09-18T16:02:50.883376 #3430331] ERROR -- : [ActiveJob] [SendReplyJob] [5f1182f7-7423-496e-a640-0222c137ca11] {"error":{"message":"(#133010) Account not registered","code":133010,"type":"OAuthException","fbtrace_id":"A6n7JU68gEA60PyPfKJoPdQ"}}
Sep 18 16:02:55 vmi1313120.contaboserver.net chatwoot-worker.1[3430331]: E, [2026-09-18T16:02:55.015687 #3430331] ERROR -- : [ActiveJob] [SendReplyJob] [a24a55a7-7a3f-4939-ae71-f2e6cce85be4] {"error":{"message":"(#133010) Account not registered","code":133010,"type":"OAuthException","fbtrace_id":"A_TU48eohbOOK73NEp64-2L"}}
Sep 18 16:02:57 vmi1313120.contaboserver.net chatwoot-worker.1[3430331]: E, [2026-09-18T16:02:57.730252 #3430331] ERROR -- : [ActiveJob] [SendReplyJob] [46bce45c-3b0c-4bff-af40-071e4d9a532a] {"error":{"message":"(#133010) Account not registered","code":133010,"type":"OAuthException","fbtrace_id":"A4c_7kRRBjTPQgRMUVkazcj"}}
Sep 18 16:07:59 vmi1313120.contaboserver.net chatwoot-worker.1[3430331]: E, [2026-09-18T16:07:59.680230 #3430331] ERROR -- : [ActiveJob] [SendReplyJob] [2d8529f5-5b59-4c61-a494-0f017e6d0534] {"error":{"message":"(#133010) Account not registered","code":133010,"type":"OAuthException","fbtrace_id":"Am04wwsaUvrCZcbcSTubXaG"}}
Sep 18 16:19:28 vmi1313120.contaboserver.net chatwoot-worker.1[3430331]: E, [2026-09-18T16:19:28.509922 #3430331] ERROR -- : [ActiveJob] [SendReplyJob] [f9743488-93a2-4bf7-ac64-9dc99a71ab2a] {"error":{"message":"(#133010) Account not registered","code":133010,"type":"OAuthException","fbtrace_id":"AOJIIb_d60fYwIDu9uC2F_p"}}
Sep 18 16:19:41 vmi1313120.contaboserver.net chatwoot-worker.1[3430331]: E, [2026-09-18T16:19:41.563113 #3430331] ERROR -- : [ActiveJob] [SendReplyJob] [4e40ffdd-1220-41fe-8eaa-2c03ecd0dca3] {"error":{"message":"(#133010) Account not registered","code":133010,"type":"OAuthException","fbtrace_id":"AEFoyrZbo5uswIt968-6J1o"}}
Sep 18 16:19:57 vmi1313120.contaboserver.net chatwoot-worker.1[3430331]: E, [2026-09-18T16:19:57.254609 #3430331] ERROR -- : [ActiveJob] [SendReplyJob] [50c1b4b8-03ca-424f-b52f-f0618d44abb4] {"error":{"message":"(#133010) Account not registered","code":133010,"type":"OAuthException","fbtrace_id":"AHoGaK2YdOMSC922x1P5APZ"}}
Sep 18 16:20:30 vmi1313120.contaboserver.net chatwoot-worker.1[3430331]: E, [2026-09-18T16:20:30.242889 #3430331] ERROR -- : [ActiveJob] [SendReplyJob] [363a4d0c-fa24-44ae-adb6-fa2600571d65] {"error":{"message":"(#133010) Account not registered","code":133010,"type":"OAuthException","fbtrace_id":"AJ_bJiJPvxdn84grRiJ2Gcd"}}
Sep 18 16:20:40 vmi1313120.contaboserver.net chatwoot-worker.1[3430331]: E, [2026-09-18T16:20:40.436926 #3430331] ERROR -- : [ActiveJob] [SendReplyJob] [4fa29362-4401-4edc-9cc3-ebc494ce86db] {"error":{"message":"(#133010) Account not registered","code":133010,"type":"OAuthException","fbtrace_id":"Ac2BkgtKX5cry5QL99f1Qrc"}}
Sep 18 16:21:40 vmi1313120.contaboserver.net chatwoot-worker.1[3430331]: E, [2026-09-18T16:21:40.194300 #3430331] ERROR -- : [ActiveJob] [SendReplyJob] [48056701-abce-4973-a342-2ab59eaef5b3] {"error":{"message":"(#133010) Account not registered","code":133010,"type":"OAuthException","fbtrace_id":"Ajsj-y7nz4rqDzUuVrs_fV3"}}
Sep 18 16:22:15 vmi1313120.contaboserver.net chatwoot-worker.1[3430331]: E, [2026-09-18T16:22:15.585612 #3430331] ERROR -- : [ActiveJob] [SendReplyJob] [e6b423fb-d5e8-4303-b654-dc09c0a587fc] {"error":{"message":"(#133010) Account not registered","code":133010,"type":"OAuthException","fbtrace_id":"AKN7aE8YMQo6CbHgiD8KgQC"}}
Sep 18 16:28:06 vmi1313120.contaboserver.net chatwoot-worker.1[3430331]: E, [2026-09-18T16:28:06.969803 #3430331] ERROR -- : [ActiveJob] [SendReplyJob] [c326bfab-9222-49e0-a0f2-b7b0d92ade09] {"error":{"message":"(#133010) Account not registered","code":133010,"type":"OAuthException","fbtrace_id":"AHfAdcO04GbQup_mo2v2fvE"}}
Sep 18 16:28:09 vmi1313120.contaboserver.net chatwoot-worker.1[3430331]: E, [2026-09-18T16:28:09.457190 #3430331] ERROR -- : [ActiveJob] [SendReplyJob] [117ceb0b-2149-4929-a130-48a4d882a0b9] {"error":{"message":"(#133010) Account not registered","code":133010,"type":"OAuthException","fbtrace_id":"AehUDRTDO_QrVVoxpOn3aYZ"}}
```

**Contagem (30 dias):** `journalctl ... | grep -c '133010'` → **91**

---

## B. `journalctl` — escalada para Graph 100 (mesmo phone_number_id)

```text
Sep 18 17:00:08 vmi1313120.contaboserver.net chatwoot-worker.1[3430331]: E, [2026-09-18T17:00:08.122193 #3430331] ERROR -- : [ActiveJob] [SendReplyJob] [b85f36a5-d2ad-43cb-8a0e-c467dcf48c71] {"error":{"message":"Unsupported post request. Object with ID '832656013256861' does not exist, cannot be loaded due to missing permissions, or does not support this operation. Please read the Graph API documentation at https://developers.facebook.com/docs/graph-api","code":100,"type":"GraphMethodException","error_subcode":33,"fbtrace_id":"AJwclmsOvlvV-Zt2-rHCGlE"}}
```

---

## C. Rails runner — `Whatsapp::HealthService` (canal 18)

```text
inbox: 610 phone: +554187814116
E, [2026-09-18T16:59:32.525185 #125663] ERROR -- : [WHATSAPP HEALTH] WhatsApp API request failed: 400 - {"error":{"message":"Unsupported get request. Object with ID '832656013256861' does not exist, cannot be loaded due to missing permissions, or does not support this operation. Please read the Graph API documentation at https:\/\/developers.facebook.com\/docs\/graph-api","type":"GraphMethodException","code":100,"error_subcode":33,"fbtrace_id":"AjeHz-9UrDU6_NC5KzYnXCJ"}}
health: WhatsApp API request failed: 400 - {"error":{"message":"Unsupported get request. Object with ID '832656013256861' does not exist, cannot be loaded due to missing permissions, or does not support this operation ...
```

---

## D. Rails runner — tentativa `register_phone!` (canal 18, conservador)

```text
E, [2026-09-18T16:59:47.294421 #126330] ERROR -- : [WHATSAPP] Phone registration failed: Phone registration failed: {"error":{"message":"Unsupported post request. Object with ID '832656013256861' does not exist, cannot be loaded due to missing permissions, or does not support this operation. Please read the Graph API documentation at https:\/\/developers.facebook.com\/docs\/graph-api","type":"GraphMethodException","code":100,"error_subcode":33,"fbtrace_id":"A88RH4xQrT0yWiJoCA6BuYU"}}
```

---

## E. Resposta Graph API — probe POST (canal 18, sem envio real ao cliente)

Corpo da requisição usado apenas com número fictício de teste; resposta:

```json
{
  "error": {
    "message": "Unsupported post request. Object with ID '832656013256861' does not exist, cannot be loaded due to missing permissions, or does not support this operation. Please read the Graph API documentation at https://developers.facebook.com/docs/graph-api",
    "code": 100,
    "type": "GraphMethodException",
    "error_subcode": 33,
    "fbtrace_id": "Al-6EmQVPR912QfSiLOt8pZ"
  }
}
```

---

## F. Resposta Graph API — GET phone (comparação AGTU)

**Canal 18 (inbox 610):**

```text
Unsupported get request. Object with ID '832656013256861' does not exist, cannot be loaded due to missing permissions ...
```

**Canal 19 (inbox 611) — OK:**

```json
{
  "status": "CONNECTED",
  "display_phone_number": "+55 41 8486-5554",
  "id": "874756775724666"
}
```

**Canal 20 (inbox 612) — OK:**

```json
{
  "status": "CONNECTED",
  "display_phone_number": "+55 41 8801-8394",
  "id": "1078712815318935"
}
```

**Canal 27 (inbox 676) — OK:**

```json
{
  "status": "CONNECTED",
  "display_phone_number": "+55 41 8871-3737",
  "id": "1246597248548179"
}
```

---

## G. Postgres — amostra `content_attributes` (133010)

```text
    id    |         created_at         |                         content_attributes
----------+----------------------------+---------------------------------------------------------------------
 11500245 | 2026-09-18 18:59:31.018776 | "{\"external_error\":\"133010: (#133010) Account not registered\"}"
 11500271 | 2026-09-18 19:00:25.74731  | "{\"external_error\":\"133010: (#133010) Account not registered\"}"
 11500281 | 2026-09-18 19:00:54.156111 | "{\"external_error\":\"133010: (#133010) Account not registered\"}"
 11500287 | 2026-09-18 19:01:01.739574 | "{\"external_error\":\"133010: (#133010) Account not registered\"}"
 11500338 | 2026-09-18 19:02:46.760765 | "{\"external_error\":\"133010: (#133010) Account not registered\"}"
```

---

## H. Postgres — exemplos Graph 100 em mensagens (pós-133010)

```text
 11500891 | 2026-09-18 19:28:06.556439 | "{\"external_error\":\"100: Unsupported post request. Object with ID '832656013256861' does not exist, cannot be loaded due to missing permissions, or does not support this operation. Please read the Graph API documentation at https://developers.facebook.com/docs/graph-api\"}"
 11501418 | 2026-09-18 19:49:13.842342 | (mesmo padrão Graph 100)
```

---

## I. Redis — flag de reautorização (pós-intervenção conservadora)

```bash
redis-cli GET "alfred:REAUTHORIZATION_REQUIRED:channel_whatsapp:18"
# true
```

---

## J. Prompt sugerido para colar em outra IA

```text
Contexto: Chatwoot ManyTalks, VPS 173.249.22.227, account 88 AGTU, inbox 610 WhatsApp Cloud API (+554187814116). Erro 133010 Account not registered no SendReplyJob. Token canal 18 válido mas WABA 1432484038007576 ausente nos granular_scopes do token; phone_number_id 832656013256861 retorna Graph 100. Outros canais AGTU CONNECTED. Ler INCIDENTE_WHATSAPP_INBOX_610_18SET2026.md e logs no anexo _LOGS_. Objetivo: plano de reconexão Embedded Signup só inbox 610 sem impactar app ManyWP global.
```
