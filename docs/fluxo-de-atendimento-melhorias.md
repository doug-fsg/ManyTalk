# Fluxo de Atendimento — Melhorias e Roadmap de Produto

> Como evoluir o Fluxo de Atendimento de **feature visual** para **motor de processos de relacionamento** — alinhado à visão de [Sistema Operacional de Relacionamento](./sistema-operacional-de-relacionamento.md) e à [arquitetura de IA](./inteligencia-artificial.md).

---

## Sumário

1. [Status atual (revisão ago/2026)](#status-atual-revisão-ago2026)
2. [Histórico entregue](#histórico-entregue)
3. [Backlog ativo](#backlog-ativo)
4. [Diagnóstico](#diagnóstico)
5. [Reposicionamento](#reposicionamento)
6. [Jobs reais que o fluxo deve resolver](#jobs-reais-que-o-fluxo-deve-resolver)
7. [Priorização MoSCoW (referência histórica)](#priorização-moscow-referência-histórica)
8. [Mapa estratégico: Fluxo × 5 Prioridades](#mapa-estratégico-fluxo--5-prioridades)
9. [Integração com IA (n8n)](#integração-com-ia-n8n)
10. [Métricas que importam](#métricas-que-importam)
11. [Mudanças de experiência (UX)](#mudanças-de-experiência-ux)
12. [Roadmap (histórico + próximo ciclo)](#roadmap-histórico--próximo-ciclo)
13. [Priorização RICE (backlog ativo)](#priorização-rice-backlog-ativo)
14. [O que não construir](#o-que-não-construir)
15. [Recomendações de implementação](#recomendações-de-implementação)
16. [Decisões em aberto](#decisões-em-aberto)

---

## Status atual (revisão ago/2026)

**Veredito:** o motor do Fluxo de Atendimento está **maduro e operacional**. A Fase A (confiança) foi **~90% entregue**. O gap restante não é reconstruir features — é **polimento operacional**, **defaults sensatos** e **conexão com as Prioridades 1–4** do [Sistema Operacional de Relacionamento](./sistema-operacional-de-relacionamento.md).

| Área | Situação |
|------|----------|
| Cadência temporal (`wait`, `wait_for_reply`, IF) | ✅ Entregue |
| Régua + timeline de execução | ✅ Entregue |
| Simulação (`dry_run`) | ✅ Entregue |
| Re-enrollment configurável | ✅ Entregue |
| Cancel on agent / labels | ✅ Entregue |
| Conflito v1/v2 | ⚠️ Parcial — alerta pós-ativação; falta aviso pré-ativação |
| Métricas | ⚠️ Parcial — relatórios existem; card da listagem só mostra reply rate |
| Versionamento / draft | ❌ Descartado — clone + desativar resolve |
| Nó handoff dedicado | ❌ Descartado — labels + n8n + settings cobrem |

---

## Histórico entregue

Itens do backlog original que **já foram implementados** (referência para não reabrir):

| ID | Entrega | Evidência no produto |
|----|---------|----------------------|
| **M2** | Log de execução por enrollment | `TimelineBuilder` + `ReguaTimeline` — status, horário, `error_message` por nó |
| **M3** | Simulação dry-run | `DryRunService` + `WorkflowSimulateModal` no editor |
| **M4** | Re-enrollment | Settings: `allow_reenrollment`, `reenrollment_min_interval_days`, `max_enrollments_per_contact`, `reenrollment_on_cancel` |
| **M6** | Cancel on agent / labels | Settings + backend em `WorkflowEnrollment` / `OrchestratorService` |
| **M1** | Detector conflito v1/v2 | `conflicting_automation_names` + banner em `WorkflowCard` (fluxo **já ativo**) |
| **S5** | Métricas de processo (base) | `WorkflowReports` — ativos, concluídos, cancelados, reply rate, métricas por etapa |
| **S6** | Templates (base) | `TemplateFactory` — galeria com categorias + 3 templates |
| **S7** | UX nós IA (base) | `WorkflowAiUpsellModal` quando feature `inteligencia_artificial` desabilitada |
| — | Gatilho `form_submitted` | Trigger + validação + `ProcessFormSubmittedJob` |
| — | Nó `ai_wait_for_intent` | Classificação via webhook + pré-filtro + ramos `intent_detected` / `timeout` |
| — | CRM Kanban | Gatilhos `contact_kanban_stage_changed` / `_idle` + condições kanban no IF |
| — | Controles na Régua | Pausar, retomar, cancelar, pular etapa, rebind de conversa |
| — | Validação de grafo | Bloqueio de ativação com grafo inválido |
| — | Clone de fluxo | Workaround para editar processo ativo sem versionamento |
| — | `external_whatsapp` | Webhook `workflow.external_whatsapp` + teste no editor |
| — | A/B test (backend) | `AbVariantSelector` em `action_service` — editor não exposto |

Referência técnica: [`fluxo-de-trabalho.md`](./fluxo-de-trabalho.md), [`workflow-graph-schema.md`](./workflow-graph-schema.md).

---

## Backlog ativo

Itens **pendentes e justificados** após revisão (ago/2026). Esforço: **S** · **M** · **L**.

### 🔴 Urgente / crítico

| ID | Item | Status |
|----|------|--------|
| **B1** | Conflito v1/v2 **antes** de ativar | ✅ `WorkflowActivateConfirmModal` |
| **B2** | Defaults operacionais nos templates | ✅ `TemplateFactory` + guia em `fluxo-de-trabalho.md` |
| **B3** | Editar **settings** com fluxo ativo | ✅ `UpdateService` + UI |

### 🟡 Importante (próximo ciclo)

| ID | Item | Status |
|----|------|--------|
| **B4** | Taxa de conclusão na listagem | ✅ `ListMetricsService` + `WorkflowCard` |
| **B5** | Relatório agregado de falhas | 📋 Pendente |
| **B6** | Badge n8n nos nós de IA (feature ativa) | 📋 Pendente |
| **B7** | Template “Reativação” com re-enrollment | ✅ `reactivation_30d` |

### 🔵 Dependem das Prioridades globais (não backlog do fluxo)

| ID | Item | Dependência |
|----|------|-------------|
| **S1** | Condições origem/campanha | Prioridade 1 — origem persistida no contato/conversa |
| **S2** | Condições lead score | Prioridade 2 — score visível e persistido |
| **S4** | Nó `create_task` | Prioridade 3 — detecção de compromissos |
| **C2** | Memória no payload | Prioridade 4 — modelo de memória por contato |
| **C3** | Gatilhos `score_changed`, `commitment_detected` | Prioridades 2 e 3 |

### Sprint sugerido (~1 sprint)

```
B2 → B1 → B3 → B4
```

---

## Diagnóstico

### Veredito

O **Fluxo de Atendimento não é inútil** — o motor técnico é real e funcional:

- Enrollments persistentes por contato/conversa
- Espera (`wait`) e aguardar resposta (`wait_for_reply`) com ramificação
- Orquestrador Sidekiq, validação de grafo, Régua na conversa
- Templates, métricas básicas, integração com CRM Kanban
- Nós de IA via webhook (quando inbox API + n8n configurados)

O risco não é “não funciona” — é **posicionamento errado**, **falta de confiança operacional** e **desconexão** da visão de Sistema Operacional de Relacionamento e da IA via n8n.

### Por que parecia feature inútil (ago/2026 — situação atualizada)

| Sintoma | Causa raiz | Status |
|---------|------------|--------|
| Gestor compara com n8n e acha incompleto | Expectativa desalinhada — fluxo é **cadência temporal**, não orquestrador genérico | 📋 Comunicação / doc |
| Mensagens duplicadas | Automações v1 + Fluxos v2 no mesmo gatilho | ⚠️ Alerta existe; falta aviso **pré-ativação** (B1) |
| “Ativei e não sei se funcionou” | Falhas silenciosas; métricas superficiais | ✅ Timeline na Régua; ⚠️ falta agregado gestor (B5) e conclusão no card (B4) |
| Medo de editar fluxo ao vivo | Fluxo ativo = diagrama bloqueado | ✅ Clone resolve; ⚠️ settings também bloqueados (B3) |
| IA nos nós “não funciona” | Usuário espera ChatGPT nativo; exige webhook n8n | ⚠️ Upsell quando off; falta badge quando on (B6) |
| Cliente não reentra no fluxo | Re-enrollment off por default | ✅ Configurável; falta template/guia (B2, B7) |
| IA reativa e fluxo temporal não conversam | n8n vs Fluxo como ilhas | ✅ `cancel_on_labels` + API; documentar padrão |

### O que já funciona bem (preservar)

| Caso de uso | Capacidade atual |
|-------------|------------------|
| Follow-up se cliente não responde | `wait_for_reply` + ramos `timeout` / `replied` |
| Régua manual iniciada pelo agente | Gatilho `manual` + painel Régua na conversa |
| Nutrição por mudança no CRM | Gatilho `contact_kanban_stage_changed` |
| Boas-vindas + lembrete | `conversation_created` + `wait` + `send_message` |
| Pausa quando cliente responde | `pause_on_contact_reply` |
| Controle operacional | Pausar, retomar, cancelar, pular etapa na Régua |

Referência técnica: [`docs/fluxo-de-trabalho.md`](./fluxo-de-trabalho.md), [`docs/workflow-graph-schema.md`](./workflow-graph-schema.md).

---

## Reposicionamento

### De → Para

| Hoje (implícito) | Deveria ser |
|------------------|-------------|
| Automação visual tipo n8n | **Processo de relacionamento com tempo** |
| Aba competindo com Automações | Automações = instantâneo; Fluxo = **jornada** |
| Feature de atendimento | Motor da [jornada Lead → Recompra](./sistema-operacional-de-relacionamento.md) |
| Nó de IA = inteligência nativa | Ponte documentada para **n8n** ([`inteligencia-artificial.md`](./inteligencia-artificial.md)) |

### Tríade de automação no ManyTalks

```
┌─────────────────────┐   ┌─────────────────────┐   ┌─────────────────────┐
│  Automações v1      │   │  Fluxo de Atendimento│   │  IA via n8n         │
│  (clássicas)        │   │  (v2 / workflows)    │   │  (webhook inbox API)│
├─────────────────────┤   ├─────────────────────┤   ├─────────────────────┤
│  Quando X → Y agora │   │  Ao longo de dias    │   │  Decisão por msg    │
│  Assign, label, etc.│   │  Espera, IF, cadência│   │  LLM, escalar, etc. │
│  Admin only (v1)    │   │  Estado (enrollment) │   │  Cérebro externo    │
└─────────────────────┘   └─────────────────────┘   └─────────────────────┘
         │                          │                          │
         └──────────────────────────┴──────────────────────────┘
                    Devem coexistir sem conflito
```

**Mensagem comercial:**

> **Automações** — quando algo acontece, faça imediatamente.  
> **Fluxo de Atendimento** — ao longo do tempo, decida o próximo passo da relação.  
> **IA (n8n)** — entenda a mensagem e decida quem responde agora.

---

## Jobs reais que o fluxo deve resolver

Processos completos — não “automações bonitas”.

| Job do gestor / operação | Fluxo resolve hoje? | Gap |
|--------------------------|---------------------|-----|
| Cobrar resposta em D+1, D+3, D+7 | ✅ Forte | — |
| Nutrir lead até oportunidade | ⚠️ Parcial | Origem/score — Prioridades 1–2 (S1, S2) |
| Vendedor dispara régua na conversa | ✅ Forte | Conclusão % visível na listagem (B4) |
| CRM mudou estágio → jornada | ✅ Forte | — |
| IA atende → humano assume no momento certo | ✅ Via labels + settings | Documentar padrão n8n; defaults nos templates (B2) |
| Ex-cliente volta → reengajar | ✅ Configurável | Template + defaults (B7, B2) |
| Saber se o processo gera resultado | ⚠️ Parcial | Conclusão no card (B4); agregado falhas (B5) |
| Experiência diferente por campanha | ❌ | Prioridade 1 global (S1) |
| Priorizar lead quente no fluxo | ❌ | Prioridade 2 global (S2) |
| Compromisso na conversa → follow-up | ❌ | Prioridade 3 global (S4) |

---

## Priorização MoSCoW (referência histórica)

> Specs originais preservadas abaixo. Para backlog vigente, ver [Backlog ativo](#backlog-ativo).  
> Legenda de status: ✅ Entregue · ⚠️ Parcial · 📋 Backlog ativo · ❌ Descartado · 🔵 Depende de prioridade global

Legenda de esforço: **S** (pequeno) · **M** (médio) · **L** (grande)

---

### 🔴 MUST — confiança operacional (Fase A)

---

#### M1. Detector de conflito Automações × Fluxos — ⚠️ Parcial → **B1**

**Status:** banner no card quando fluxo **já está ativo**. Pendente: aviso **antes** de ativar.

**Problema:** v1 e v2 com o mesmo gatilho executam simultaneamente — mensagens, labels e assigns duplicados. Documentado em [`fluxo-de-trabalho.md`](./fluxo-de-trabalho.md).

**User story:**  
Como **gestor de operação**, quero **ver alerta ao ativar um fluxo que conflita com automação clássica**, para **evitar mensagens em dobro ao cliente**.

**Acceptance criteria:**

```gherkin
Given existem Automações clássicas ativas com gatilho "conversation_created" no inbox 5
When ativo um Fluxo com o mesmo gatilho e condição de inbox equivalente
Then vejo banner de conflito listando automações afetadas
And não consigo ativar sem confirmar "Entendo o risco" ou desativar conflito
And há link direto para editar cada automação conflitante
```

| Atributo | Valor |
|----------|-------|
| Esforço | M |
| Impacto | Crítico (confiança) |
| Dependências | Nenhuma |

---

#### M2. Log de execução por enrollment (visível) — ✅ Entregue

**Status:** timeline na Régua com status, horários e erros legíveis. Pendente opcional: relatório agregado de falhas (**B5**).

**Problema:** ação falha → log no servidor; fluxo continua; usuário não vê.

**User story:**  
Como **agente ou gestor**, quero **ver o histórico de cada passo do fluxo (sucesso, falha, pulado, agendado)**, para **confiar e debugar sem acessar logs técnicos**.

**Acceptance criteria:**

```gherkin
Given um enrollment ativo na conversa 123
When abro a Régua / painel do fluxo
Then vejo timeline com cada nó: status, horário, erro legível se houver
And falha em send_message mostra motivo (ex.: janela WhatsApp, webhook timeout)
And gestor vê relatório agregado de falhas por fluxo (últimos 30 dias)
```

| Atributo | Valor |
|----------|-------|
| Esforço | M |
| Impacto | Alto |
| Base técnica | `workflow_step_executions` já existe — falta UX e mensagens amigáveis |

---

#### M3. Modo simulação / dry-run — ✅ Entregue

**Status:** `WorkflowSimulateModal` + API `dry_run` no editor.

**Problema:** medo de ativar fluxo errado em produção.

**User story:**  
Como **gestor**, quero **simular o fluxo em conversa de teste antes de ativar**, para **validar ramificações e mensagens**.

**Acceptance criteria:**

```gherkin
Given um fluxo inativo em edição
When clico "Simular" e escolho conversa de teste ou contato fictício
Then o sistema percorre o grafo sem efeitos colaterais (ou só inbox de teste)
And mostro qual ramo seria seguido para cada nó IF / wait_for_reply
And nenhuma mensagem real é enviada ao cliente (modo padrão)
```

| Atributo | Valor |
|----------|-------|
| Esforço | M–L |
| Impacto | Alto (onboarding e vendas) |

---

#### M4. Regras de re-enrollment — ✅ Entregue

**Status:** settings completos na UI. Pendente: template “Reativação” (**B7**) e defaults (**B2**).

**Settings implementados:**

| Setting | Descrição | Default atual |
|---------|-----------|---------------|
| `allow_reenrollment` | Permite reentrada | `false` |
| `reenrollment_min_interval_days` | Dias mínimos entre enrollments | `30` |
| `max_enrollments_per_contact` | Limite total (`0` = ilimitado) | `0` |
| `reenrollment_on_cancel` | Permite reinício após cancel manual | `true` |

**Acceptance criteria:**

```gherkin
Given fluxo "Reativação 30d" com allow_reenrollment_after_days = 30
And contato completou enrollment há 35 dias
When gatilho manual ou automático dispara
Then novo enrollment é criado
And enrollment anterior está completed
```

| Atributo | Valor |
|----------|-------|
| Esforço | M |
| Impacto | Alto (jornada completa) |

---

#### M5. Edição sem desativar (draft / versionamento) — ❌ Descartado

**Decisão (ago/2026):** clone + desativar/editar/reativar resolve para o volume atual. Esforço L com retorno marginal. Pendência real menor: editar **settings** com fluxo ativo (**B3**).

---

#### M6. Cancelar fluxo quando humano ou IA assume — ✅ Entregue

**Status:** `cancel_on_agent_reply`, `cancel_on_labels` na UI e backend. Pendente: defaults nos templates (**B2**).

---

### 🟡 SHOULD — conecta fluxo ao Sistema Operacional de Relacionamento

---

#### S1. Gatilhos e condições por Origem/Campanha (Prioridade 1) — 🔵 Depende P1

**User story:**  
Como **gestor de marketing/operação**, quero **iniciar fluxos diferentes conforme campanha, anúncio ou promessa de captação**, para **honrar a expectativa do lead na entrada**.

**Novos atributos condicionáveis (trigger + IF):**

- `campaign_id`
- `utm_source`, `utm_medium`, `utm_campaign`
- `captacao_promessa` (atributo customizado)
- `ad_id` / `ad_set_id` (quando integração ads existir)

**Templates sugeridos:**

| Template | Condição de entrada |
|----------|---------------------|
| Boas-vindas Black Friday | `utm_campaign = black-friday` |
| Consultoria gratuita | `captacao_promessa contains consultoria` |
| Lead orgânico | sem UTM |

| Atributo | Valor |
|----------|-------|
| Esforço | M |
| Dependência | Captura de origem no contato/conversa (Prioridade 1 global) |

---

#### S2. Condições por Lead Score (Prioridade 2) — 🔵 Depende P2

**User story:**  
Como **gestor comercial**, quero **ramificar fluxo por score de IA (ex.: ≥80 quente, 40–79 morno, <40 frio)**, para **priorizar esforço humano e cadências adequadas**.

**Exemplo de grafo:**

```
Trigger (conversation_created)
    → IF score >= 80 → assign vendas + mensagem prioritária
    → IF score 40-79 → wait 2h + nutrição
    → ELSE → fluxo longo 7 dias
```

**Acceptance criteria:**

- Condição `lead_score` com operadores `>`, `<`, `between`
- Score visível no header da conversa e na Régua
- Score atualizado mid-flow pode reavaliar próximo nó IF (decisão de produto)

| Atributo | Valor |
|----------|-------|
| Esforço | M |
| Dependência | Prioridade 2 — score persistido e visível |

---

#### S3. Nó Handoff — IA / humano (ponte com n8n) — ❌ Descartado

**Decisão (ago/2026):** `cancel_on_labels` + assign via ação + n8n via API cobrem o caso. Nó dedicado seria conveniência, não bloqueio. Manter spec abaixo como referência histórica.

**Tipos de nó propostos:**

| Nó | Comportamento |
|----|---------------|
| `handoff_ai` | POST webhook `workflow.handoff` → n8n assume; fluxo pausa |
| `handoff_human` | Assign team/agent + prioridade + nota privada resumo |
| `wait_for_human_reply` | Pausa até agente responder ou timeout |

**Payload webhook sugerido (`workflow.handoff`):**

```json
{
  "event": "workflow.handoff",
  "handoff_type": "ai",
  "enrollment_id": 123,
  "workflow_id": 45,
  "conversation": { "...": "..." },
  "context": {
    "objective": "Cliente parou no passo 2 — retomar proposta",
    "last_messages": []
  },
  "resume_after": "webhook_callback | agent_reply | timeout"
}
```

| Atributo | Valor |
|----------|-------|
| Esforço | M |
| Impacto | Alto — diferencial operacional |

---

#### S4. Nó Criar Tarefa (Prioridade 3) — 🔵 Depende P3

**User story:**  
Como **gestor comercial**, quero **que o fluxo crie tarefa com prazo** (ex.: D+1 após timeout, ou após detectar compromisso), para **não perder follow-ups em alto volume**.

**Ação proposta:** `create_task`

| Parâmetro | Exemplo |
|-----------|---------|
| `title` | "Retornar proposta — {{contact.name}}" |
| `due_in` | `24 hours` |
| `assignee` | assignee da conversa ou team |
| `body` | Contexto do enrollment |

**Evolução:** tarefa criada por IA (Prioridade 3) dispara gatilho `task_created` → entra em fluxo.

| Atributo | Valor |
|----------|-------|
| Esforço | M |
| Dependência | Módulo de tarefas (existente — evoluir) |

---

#### S5. Métricas de processo (não só reply rate) — ⚠️ Parcial → **B4**, **B5**

**Status:** relatórios com ativos, concluídos, cancelados, reply rate e métricas por etapa. Pendente: conclusão % no card; agregado de falhas; conversão CRM/receita (fase 2).

**Métricas propostas por fluxo:**

| Métrica | Definição | Decisão que suporta |
|---------|-----------|---------------------|
| **Taxa de conclusão** | completed / started | Processo chega ao fim? |
| **Taxa de resposta** | replied / started | Cliente engaja? |
| **Tempo médio por estágio** | média entre nós | Onde trava? |
| **Taxa de handoff** | handoff / started | Precisa humano? |
| **Taxa de cancelamento** | cancel / started | Cliente abandonou? |
| **Conversão CRM** | mudou estágio alvo / started | Gera oportunidade? |
| **Receita atribuída** (fase 2) | deal won pós-fluxo | ROI |

**UX:** dashboard em Relatórios + tooltip no card do fluxo + export CSV.

| Atributo | Valor |
|----------|-------|
| Esforço | M |
| Impacto | Gestor justifica investimento |

---

#### S6. Biblioteca de templates por estágio de relação — ⚠️ Parcial → **B7**

**Status:** galeria + 3 templates (`follow_up_basic`, `crm_stage_changed`, `welcome_conversation`). Pendente: template reativação + expansão por jornada quando P1/P5 avançarem.

| Categoria | Template | Gatilho típico |
|-----------|----------|----------------|
| **Captação** | Boas-vindas por origem | `conversation_created` + UTM |
| **Qualificação** | 3 toques sem resposta | `manual` / score baixo |
| **Vendas** | Pós-proposta | kanban stage |
| **Pós-venda** | Satisfação D+3 | `conversation_resolved` + label cliente |
| **Retenção** | Reativação 30d idle | `contact_kanban_stage_idle` |
| **Indicação** | Pedido de indicação | label + score alto |
| **Recompra** | Ex-cliente campanha | manual + re-enrollment |

| Atributo | Valor |
|----------|-------|
| Esforço | S (conteúdo) + M (galeria UX) |

---

#### S7. Clarificar nós de IA no editor — ⚠️ Parcial → **B6**

**Status:** upsell modal quando feature off. Pendente: badge + doc + health quando feature on.

**Melhorias UX:**

- Badge permanente: **“Processado via webhook n8n — requer inbox API configurado”**
- Link para [`inteligencia-artificial.md`](./inteligencia-artificial.md)
- Preview do evento: `workflow.ai_outreach` / `workflow.ai_conversation_analysis`
- Estado de saúde: webhook OK / falhou / feature desabilitada

| Atributo | Valor |
|----------|-------|
| Esforço | S |
| Impacto | Reduz suporte e frustração |

---

### 🟢 COULD — diferenciação de longo prazo

---

#### C1. Nó Webhook Request (wait for response) — ❌ Descartado

Território do n8n — não duplicar.

---

#### C2. Injetar Memória de Relacionamento (Prioridade 4) — 🔵 Depende P4

Antes de `send_message` ou nós de IA, incluir no payload / interpolar variáveis:

- Objetivos, objeções, preferências, histórico resumido

**Exemplo em mensagem:**  
`Olá {{contact.name}}, lembro que você buscava {{memory.objective}}...`

| Esforço | L |
|---------|---|
| Dependência | Prioridade 4 — modelo de memória por contato |

---

#### C3. Gatilhos de sistema alimentados por IA — 🔵 Depende P2/P3

| Evento | Origem | Uso no fluxo |
|--------|--------|--------------|
| `lead_score_changed` | IA/n8n | Ramificar ou assign |
| `commitment_detected` | IA (Prioridade 3) | Criar tarefa + fluxo pós-venda |
| `memory_updated` | IA | Personalizar próximo passo |

| Esforço | M |
|---------|---|

---

#### C4. Switch multi-ramo (além de IF binário) — ❌ Descartado

Cadeia de IFs atende casos atuais; só reavaliar com demanda comprovada.

---

#### C5. Horário respeitando timezone/preferência do contato — 🔵 Depende P4

---

#### C6. A/B test nativo em `send_message` (expandir) — 📋 Backlog baixo

Backend existe (`AbVariantSelector`); expor no editor só com demanda comprovada.

---

## Mapa estratégico: Fluxo × 5 Prioridades

```
                    ┌──────────────────────────┐
                    │ P1 — Origem / Campanhas  │
                    │ condições, templates     │
                    └────────────┬─────────────┘
                                 │
                    ┌────────────▼─────────────┐
                    │ P2 — Lead Score IA       │
                    │ IF por score, assign     │
                    └────────────┬─────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
┌────────▼────────┐   ┌──────────▼──────────┐   ┌────────▼────────┐
│ P3 — Tarefas    │   │ P4 — Memória        │   │ P5 — Jornada    │
│ nó create_task  │   │ contexto em msg/IA  │   │ re-enrollment   │
│ gatilho task    │   │ handoff enriquecido │   │ templates lifecycle│
└────────┬────────┘   └──────────┬──────────┘   └────────┬────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌────────────▼─────────────┐
                    │   FLUXO DE ATENDIMENTO   │
                    │ wait · IF · ações · IA  │
                    └────────────┬─────────────┘
                                 │
                    ┌────────────▼─────────────┐
                    │   IA reativa (n8n)       │
                    │ handoff · labels · API   │
                    └──────────────────────────┘
```

---

## Integração com IA (n8n)

Arquitetura atual ([`inteligencia-artificial.md`](./inteligencia-artificial.md)):

- ManyTalks = **estado** (conversa, enrollment, labels)
- n8n = **decisão por mensagem**
- Fluxo = **decisão ao longo do tempo**

### Padrões de integração recomendados

| Padrão | Descrição | Status |
|--------|-----------|--------|
| **Fluxo → IA** | n8n responde via API; label `ia-ativo` cancela/pausa fluxo | ✅ Via `cancel_on_labels` |
| **IA → Fluxo** | n8n inicia enrollment via API ou label dispara gatilho | ✅ Via API + automações |
| **Fluxo + IA proativa** | Nó `ai_outreach` envia `workflow.ai_outreach` | ✅ Entregue |
| **Cancelamento mútuo** | Label `humano-ativo` cancela fluxo | ✅ Entregue |
| **Memória compartilhada** (futuro) | n8n grava memória; fluxo lê no próximo passo | 🔵 Prioridade 4 |

### Eventos webhook a documentar (novos)

| Evento | Direção | Uso | Status |
|--------|---------|-----|--------|
| `workflow.handoff` | ManyTalks → n8n | Entregar conversa para IA com contexto | ❌ Não implementado (descartado — usar labels) |
| `workflow.ai_outreach` | ManyTalks → n8n | Mensagem proativa | ✅ |
| `workflow.ai_conversation_analysis` | ManyTalks → n8n | Análise | ✅ |
| `workflow.ai_wait_for_intent` | ManyTalks → n8n | Classificação de intenção | ✅ |
| `workflow.resume` | n8n → ManyTalks API | Retomar enrollment pausado | 📋 Backlog baixo |
| `workflow.external_whatsapp` | ManyTalks → n8n | Envio WhatsApp externo | ✅ |

---

## Métricas que importam

### Norte sugerida

> **% de enrollments que atingem o objetivo do processo** (conversão definida por fluxo: resposta, estágio CRM, handoff concluído, etc.)

### Por persona

| Persona | Métrica que importa |
|---------|---------------------|
| Gestor CS | Taxa conclusão + tempo por estágio |
| Gestor comercial | Handoff rate + conversão CRM |
| Operacao | Taxa de falha + conflitos v1/v2 |
| Diretoria | Receita / cohort pós-fluxo (fase 2) |

### Anti-métricas (evitar otimizar errado)

- Número de fluxos criados (vanity)
- Mensagens enviadas (spam)
- Ativações sem simulação (risco)

---

## Mudanças de experiência (UX)

| Área | Antes (spec original) | Hoje | Pendente |
|------|----------------------|------|----------|
| Nome na UI | Fluxo de Atendimento | Fluxo de Atendimento | Subtítulo explicativo (opcional) |
| Comparação mental | “Tipo n8n” | Doc + simulação | Guia operacional (B2) |
| Ativar fluxo | Trava edição | Diagrama bloqueado; clone resolve | Settings editáveis (B3) |
| Listagem | Reply rate 30d | Reply rate + ativos | Conclusão % (B4) |
| Nó IA | Parece nativo | Upsell quando off | Badge quando on (B6) |
| Conflito v1 | Só doc | Banner pós-ativação | Aviso pré-ativação (B1) |
| Régua | Timeline básica | Timeline com erros | Agregado falhas (B5) |
| Criar fluxo | Templates genéricos | Galeria + 3 templates | Template reativação (B7) |

---

## Roadmap (histórico + próximo ciclo)

### Fase A — Confiança — ✅ Concluída (ago/2026)

| # | Entrega | ID | Status |
|---|---------|-----|--------|
| A1 | Detector conflito Automações × Fluxos | M1 | ⚠️ Parcial → B1 |
| A2 | Log de execução na Régua | M2 | ✅ |
| A3 | `cancel_on_agent_reply` + cancel por labels | M6 | ✅ |
| A4 | UX nos nós de IA | S7 | ⚠️ Parcial → B6 |
| A5 | Simulação básica (dry-run) | M3 | ✅ |

**Itens adicionais entregues fora do plano original:** `form_submitted`, `ai_wait_for_intent`, relatórios, clone, `external_whatsapp`.

---

### Próximo ciclo — Polimento operacional (~1 sprint)

| # | Entrega | ID | Prioridade |
|---|---------|-----|------------|
| N1 | Defaults + guia operacional | B2 | 🔴 Crítico |
| N2 | Conflito v1/v2 pré-ativação | B1 | 🔴 Crítico |
| N3 | Settings editáveis com fluxo ativo | B3 | 🔴 Crítico |
| N4 | Taxa de conclusão no card | B4 | 🟡 Importante |
| N5 | Template reativação | B7 | 🟡 Importante |
| N6 | Badge n8n (feature on) | B6 | 🟡 Importante |
| N7 | Relatório agregado de falhas | B5 | 🟡 Importante |

---

### Fase B — Relacionamento — 🔵 Adiada (depende Prioridades 1–2)

| # | Entrega | ID | Status |
|---|---------|-----|--------|
| B1 | Re-enrollment configurável | M4 | ✅ |
| B2 | Draft / versionamento | M5 | ❌ Descartado |
| B3 | Nó handoff IA + humano | S3 | ❌ Descartado |
| B4 | Métricas de funil do fluxo | S5 | ⚠️ Parcial |
| B5 | Condições origem + score | S1, S2 | 🔵 Depende P1/P2 |
| B6 | Templates por estágio de jornada | S6 | ⚠️ Parcial |

---

### Fase C — Diferenciação — 🔵 Adiada (depende Prioridades 3–4)

| # | Entrega | ID | Status |
|---|---------|-----|--------|
| C1 | Nó create_task | S4 | 🔵 Depende P3 |
| C2 | Webhook wait-response | C1 | ❌ Descartado |
| C3 | Memória no payload | C2 | 🔵 Depende P4 |
| C4 | Gatilhos IA sistema | C3 | 🔵 Depende P2/P3 |
| C5 | Switch multi-ramo | C4 | ❌ Descartado |
| C6 | A/B test exposto | C6 | 📋 Backlog baixo |

---

## Priorização RICE (backlog ativo)

Fórmula: `(Reach × Impact × Confidence) / Effort`  
Impacto: 1–3. Esforço: 1=S, 2=M, 3=L. Confidence: 0–1.

| Rank | Item | R | I | C | E | Score |
|------|------|---|---|---|---|-------|
| 1 | B2 Defaults + guia | 10 | 3 | 0.95 | 1 | **28.5** |
| 2 | B1 Conflito pré-ativação | 10 | 3 | 0.90 | 1 | **27.0** |
| 3 | B3 Settings com fluxo ativo | 9 | 3 | 0.85 | 2 | **11.5** |
| 4 | B4 Conclusão no card | 7 | 2 | 0.90 | 1 | **12.6** |
| 5 | B7 Template reativação | 6 | 2 | 0.90 | 1 | **10.8** |
| 6 | B6 Badge n8n (on) | 8 | 2 | 0.85 | 1 | **13.6** |
| 7 | B5 Relatório falhas agregado | 6 | 2 | 0.80 | 2 | **4.8** |

**Sprint imediato:** B2 → B1 → B3 → B4

---

## O que não construir

| Item | Motivo |
|------|--------|
| Paridade com n8n (HTTP genérico infinito, loops, cron) | n8n já resolve; duplicar aumenta superfície de bug |
| IA LLM nativa no ManyTalks (curto prazo) | Arquitetura webhook consolidada; investir em integração |
| Sub-workflows aninhados | Complexidade; só com demanda comprovada |
| 50 tipos de nó | Confunde gestor; viola MVP |
| Loops no grafo | Acíclico é decisão de design válida |
| **M5 — Versionamento / draft** | Clone + desativar resolve; esforço L, retorno marginal |
| **S3 — Nó handoff dedicado** | Labels + n8n + settings cobrem |
| **C1 — Webhook wait-response** | Território n8n |
| **C4 — Switch multi-ramo** | IF encadeado basta hoje |
| Bloqueio hard na ativação por conflito | Alerta pré-ativação (B1) suficiente |
| Rename para “Processos de Relacionamento” | Cosmético; subtítulo basta |

---

## Recomendações de implementação

### Por fase

| Fase | Melhor agent | Skill |
|------|--------------|-------|
| Próximo ciclo — B1, B3, B4, B5 | Backend + Frontend Specialist | `systematic-debugging` |
| Próximo ciclo — B2, B6, B7 | Frontend + PO (conteúdo) | `documentation-templates` |
| Prioridades 1–4 (S1–S4, C2–C3) | Backend + PO | alinhar PRDs globais |
| QA contínuo | QA Automation Engineer | `tdd-workflow` |

### Rastreabilidade de documentos

| Documento | Relação |
|-----------|---------|
| [`sistema-operacional-de-relacionamento.md`](./sistema-operacional-de-relacionamento.md) | Visão e 5 prioridades |
| [`inteligencia-artificial.md`](./inteligencia-artificial.md) | Handoff, nós IA, n8n |
| [`fluxo-de-trabalho.md`](./fluxo-de-trabalho.md) | Limites e API atuais |
| [`workflow-graph-schema.md`](./workflow-graph-schema.md) | Schema para novos nós |
| **Este documento** | Backlog de produto e roadmap |

---

## Decisões em aberto

| # | Decisão | Opções | Decisão (ago/2026) |
|---|---------|--------|---------------------|
| 1 | Nome na UI | Manter “Fluxo de Atendimento” vs “Processos de Relacionamento” | **Manter** + subtítulo explicativo |
| 2 | Handoff pausa vs cancela | Pausar vs cancelar ao passar para IA | **Labels cancelam** — padrão documentado |
| 3 | Score mid-flow | Reavaliar IFs vs congelar | **Congelar** — reavaliar quando P2 existir |
| 4 | Simulação | Zero side effects vs inbox sandbox | ✅ **Zero side effects** (implementado) |
| 5 | Versionamento | Cópia de grafo vs tabela `workflow_versions` | ❌ **Descartado** — clone + desativar |
| 6 | Métrica norte | Conclusão vs conversão CRM vs receita | **Conclusão** no card (B4); CRM na fase P1/P2 |

---

## Apêndice: Backlog consolidado

### Entregue (histórico)

| ID | Story | Entregue em |
|----|-------|-------------|
| M2 | Log execução visível (Régua) | Fase A |
| M3 | Simulação dry-run | Fase A |
| M4 | Re-enrollment | Fase A |
| M6 | Cancel on agent / label | Fase A |
| M1 | Conflito v1/v2 (banner pós-ativação) | Fase A (parcial) |
| S5 | Métricas base + relatórios | Fase A (parcial) |
| S6 | Templates galeria (3) | Fase A (parcial) |
| S7 | UX nós IA (upsell) | Fase A (parcial) |

### Backlog ativo

| ID | Story | Prioridade |
|----|-------|------------|
| B1 | Conflito v1/v2 **pré-ativação** | 🔴 Crítico |
| B2 | Defaults operacionais + guia | 🔴 Crítico |
| B3 | Settings editáveis com fluxo ativo | 🔴 Crítico |
| B4 | Taxa de conclusão no card | 🟡 Importante |
| B5 | Relatório agregado de falhas | 🟡 Importante |
| B6 | Badge n8n (feature on) | 🟡 Importante |
| B7 | Template reativação | 🟡 Importante |

### Adiado / depende prioridade global

| ID | Story | Prioridade |
|----|-------|------------|
| S1 | Condições origem/campanha | P1 |
| S2 | Condições lead score | P2 |
| S4 | Nó create_task | P3 |
| C2 | Memória no fluxo | P4 |
| C3 | Gatilhos IA sistema | P2/P3 |
| C6 | A/B test exposto | Backlog baixo |

### Descartado

| ID | Story | Motivo |
|----|-------|--------|
| M5 | Draft / versionamento | Clone + desativar |
| S3 | Nó handoff IA/humano | Labels + n8n |
| C1 | Webhook wait-response | n8n |
| C4 | Switch multi-ramo | IF encadeado |

---

*Documento vivo — última revisão: ago/2026 (pós-Fase A).*
