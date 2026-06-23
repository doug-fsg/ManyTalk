# Fluxo de Atendimento — Melhorias e Roadmap de Produto

> Como evoluir o Fluxo de Atendimento de **feature visual** para **motor de processos de relacionamento** — alinhado à visão de [Sistema Operacional de Relacionamento](./sistema-operacional-de-relacionamento.md) e à [arquitetura de IA](./inteligencia-artificial.md).

---

## Sumário

1. [Diagnóstico](#diagnóstico)
2. [Reposicionamento](#reposicionamento)
3. [Jobs reais que o fluxo deve resolver](#jobs-reais-que-o-fluxo-deve-resolver)
4. [Priorização MoSCoW](#priorização-moscow)
5. [Mapa estratégico: Fluxo × 5 Prioridades](#mapa-estratégico-fluxo--5-prioridades)
6. [Integração com IA (n8n)](#integração-com-ia-n8n)
7. [Métricas que importam](#métricas-que-importam)
8. [Mudanças de experiência (UX)](#mudanças-de-experiência-ux)
9. [Roadmap em 3 fases](#roadmap-em-3-fases)
10. [Priorização RICE](#priorização-rice)
11. [O que não construir](#o-que-não-construir)
12. [Recomendações de implementação](#recomendações-de-implementação)
13. [Decisões em aberto](#decisões-em-aberto)

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

### Por que parece feature inútil hoje

| Sintoma | Causa raiz |
|---------|------------|
| Gestor compara com n8n e acha incompleto | Expectativa desalinhada — fluxo é **cadência temporal**, não orquestrador genérico |
| Mensagens duplicadas | Automações clássicas (v1) + Fluxos (v2) no mesmo gatilho |
| “Ativei e não sei se funcionou” | Falhas de ação silenciosas; métricas superficiais |
| Medo de editar fluxo ao vivo | Fluxo ativo = diagrama bloqueado |
| IA nos nós “não funciona” | Usuário espera ChatGPT nativo; na prática exige webhook n8n |
| Cliente não reentra no fluxo | Re-enrollment restrito; relacionamento é longo |
| IA reativa e fluxo temporal não conversam | Duas ilhas: n8n (mensagem) vs Fluxo (tempo) |

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
| Cobrar resposta em D+1, D+3, D+7 | ✅ Forte | Confiança / observabilidade |
| Nutrir lead até oportunidade | ⚠️ Parcial | Sem origem/score no gatilho |
| Vendedor dispara régua na conversa | ✅ Forte | Métricas de conversão fracas |
| CRM mudou estágio → jornada | ✅ Forte | Desconectado da jornada completa |
| IA atende → humano assume no momento certo | ❌ | Sem handoff integrado |
| Ex-cliente volta → reengajar | ❌ | Re-enrollment bloqueado |
| Saber se o processo gera resultado | ⚠️ | Só reply rate 30d |
| Experiência diferente por campanha | ❌ | Prioridade 1 ainda não no fluxo |
| Priorizar lead quente no fluxo | ❌ | Prioridade 2 ainda não no fluxo |
| Compromisso na conversa → follow-up | ❌ | Prioridade 3 (tarefas) ausente |

---

## Priorização MoSCoW

Legenda de esforço: **S** (pequeno) · **M** (médio) · **L** (grande)

---

### 🔴 MUST — sem isso continua feature de vitrine

---

#### M1. Detector de conflito Automações × Fluxos

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

#### M2. Log de execução por enrollment (visível)

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

#### M3. Modo simulação / dry-run

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

#### M4. Regras de re-enrollment

**Problema:** um enrollment por workflow/contato impede recompra, reativação e ciclos de relacionamento ([Prioridade 5](./sistema-operacional-de-relacionamento.md)).

**User story:**  
Como **gestor**, quero **configurar quando um contato pode entrar novamente no mesmo fluxo**, para **operar retenção e recompra**.

**Settings propostos:**

| Setting | Descrição | Default sugerido |
|---------|-----------|------------------|
| `allow_reenrollment_after_days` | Dias após conclusão/cancelamento | `30` |
| `max_enrollments_per_contact` | Limite total | `5` |
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

#### M5. Edição sem desativar (draft / versionamento)

**Problema:** fluxo ativo bloqueia diagrama — inviável em operação contínua.

**User story:**  
Como **gestor**, quero **editar rascunho enquanto a versão publicada roda**, para **corrigir processos sem interromper enrollments ativos**.

**Acceptance criteria:**

```gherkin
Given fluxo v2 ativo com 50 enrollments em andamento
When edito e salvo rascunho v3
Then enrollments ativos continuam em v2
When publico v3
Then novos enrollments usam v3
And vejo indicador "Versão publicada: v3" na listagem
```

| Atributo | Valor |
|----------|-------|
| Esforço | L |
| Impacto | Crítico (operação) |

---

#### M6. Cancelar fluxo quando humano ou IA assume

**Problema:** fluxo automático compete com agente ou bot.

**User story:**  
Como **agente**, quero **que o fluxo pare quando assumo a conversa**, para **não enviar mensagens automáticas enquanto atendo**.

**Settings propostos:**

| Setting | Descrição |
|---------|-----------|
| `cancel_on_agent_reply` | Cancela quando atendente envia mensagem |
| `cancel_on_labels` | Lista de labels que cancelam (ex.: `humano-ativo`, `escalado-ia`) |
| `pause_on_handoff` | Pausa em vez de cancelar (retomável) |

**Integração n8n:** fluxo n8n aplica label → enrollment cancela/pausa.

| Atributo | Valor |
|----------|-------|
| Esforço | S–M |
| Impacto | Alto (experiência cliente) |

---

### 🟡 SHOULD — conecta fluxo ao Sistema Operacional de Relacionamento

---

#### S1. Gatilhos e condições por Origem/Campanha (Prioridade 1)

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

#### S2. Condições por Lead Score (Prioridade 2)

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

#### S3. Nó Handoff — IA / humano (ponte com n8n)

**Problema:** [`inteligencia-artificial.md`](./inteligencia-artificial.md) descreve IA reativa; fluxo descreve tempo — precisam conversar.

**User story:**  
Como **gestor**, quero **um passo do fluxo que entregue a conversa para IA ou fila humana com contexto**, para **orquestrar bot + humano + cadência**.

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

#### S4. Nó Criar Tarefa (Prioridade 3)

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

#### S5. Métricas de processo (não só reply rate)

**Problema:** `reply_rate_30d` não prova valor de negócio.

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

#### S6. Biblioteca de templates por estágio de relação (Prioridade 5)

Categorizar templates além de “atendimento/vendas” — alinhar à jornada:

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

#### S7. Clarificar nós de IA no editor

**Problema:** usuário configura `ai_outreach` achando que é IA nativa.

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

#### C1. Nó Webhook Request (wait for response)

POST para URL externa (n8n, ERP) com payload do enrollment; aguarda JSON de resposta para ramificar.

**Casos:** consultar estoque, score externo, aprovação manual, pagamento confirmado.

| Esforço | L |
|---------|---|

---

#### C2. Injetar Memória de Relacionamento (Prioridade 4)

Antes de `send_message` ou nós de IA, incluir no payload / interpolar variáveis:

- Objetivos, objeções, preferências, histórico resumido

**Exemplo em mensagem:**  
`Olá {{contact.name}}, lembro que você buscava {{memory.objective}}...`

| Esforço | L |
|---------|---|
| Dependência | Prioridade 4 — modelo de memória por contato |

---

#### C3. Gatilhos de sistema alimentados por IA

| Evento | Origem | Uso no fluxo |
|--------|--------|--------------|
| `lead_score_changed` | IA/n8n | Ramificar ou assign |
| `commitment_detected` | IA (Prioridade 3) | Criar tarefa + fluxo pós-venda |
| `memory_updated` | IA | Personalizar próximo passo |

| Esforço | M |
|---------|---|

---

#### C4. Switch multi-ramo (além de IF binário)

Nó com N saídas (ex.: score bands, origem, estágio CRM) — evita cadeias longas de IF encadeados.

| Esforço | M–L |
|---------|-----|

---

#### C5. Horário respeitando timezone/preferência do contato

Além de `respect_business_hours` do inbox — usar preferência de contato da memória (Prioridade 4).

| Esforço | M |
|---------|---|

---

#### C6. A/B test nativo em `send_message` (expandir)

Já existe base (`ab_test`, `AbVariantSelector`) — expor no editor com métricas de conversão por variante.

| Esforço | S–M |
|---------|-----|

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

| Padrão | Descrição |
|--------|-----------|
| **Fluxo → IA** | Nó `handoff_ai` pausa enrollment; n8n responde via API; label `ia-ativo` |
| **IA → Fluxo** | n8n inicia enrollment manual via API ou aplica label que dispara gatilho |
| **Fluxo + IA proativa** | Nó `ai_outreach` envia `workflow.ai_outreach` com prompt do passo |
| **Cancelamento mútuo** | Label `humano-ativo` cancela fluxo; fluxo ativo sinaliza n8n para não competir |
| **Memória compartilhada** (futuro) | n8n grava memória; fluxo lê no próximo passo |

### Eventos webhook a documentar (novos)

| Evento | Direção | Uso |
|--------|---------|-----|
| `workflow.handoff` | ManyTalks → n8n | Entregar conversa para IA com contexto |
| `workflow.ai_outreach` | ManyTalks → n8n | Mensagem proativa (existente) |
| `workflow.ai_conversation_analysis` | ManyTalks → n8n | Análise (existente) |
| `workflow.resume` | n8n → ManyTalks API | Retomar enrollment pausado |
| `workflow.external_whatsapp` | ManyTalks → n8n | Envio WhatsApp externo (existente) |

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

| Área | Hoje | Proposta |
|------|------|----------|
| Nome na UI | Fluxo de Atendimento | **Processos de Relacionamento** (ou subtítulo explicativo) |
| Comparação mental | “Tipo n8n” | “Cadência HubSpot / régua comercial” |
| Ativar fluxo | Trava edição | Rascunho + publicar versão |
| Listagem | Reply rate 30d | Funil: iniciou → respondeu → concluiu → converteu |
| Nó IA | Parece nativo | Badge + link doc + health check webhook |
| Conflito v1 | Só doc | Alerta visual na ativação |
| Régua | Timeline básica | Timeline com ✅❌ e erros legíveis |
| Criar fluxo | Templates genéricos | Galeria por jornada + origem |
| Empty state | “Crie automação” | “Monte um processo: ex. follow-up 3 toques” |

---

## Roadmap em 3 fases

### Fase A — Confiança (4–6 semanas)

**Objetivo:** gestor ativa fluxo sem medo de quebrar produção.

| # | Entrega | ID |
|---|---------|-----|
| A1 | Detector conflito Automações × Fluxos | M1 |
| A2 | Log de execução na Régua + relatório falhas | M2 |
| A3 | `cancel_on_agent_reply` + cancel por labels | M6 |
| A4 | Badge e doc nos nós de IA | S7 |
| A5 | Simulação básica (dry-run) | M3 |

**Definition of Done (fase):**

- Zero tickets “mensagem duplicada v1+v2” sem alerta prévio
- 100% falhas de ação visíveis na Régua
- Simulação disponível antes de toggle ativo

---

### Fase B — Relacionamento (6–8 semanas)

**Objetivo:** fluxo = processo comercial mensurável.

| # | Entrega | ID |
|---|---------|-----|
| B1 | Re-enrollment configurável | M4 |
| B2 | Draft / versionamento | M5 |
| B3 | Nó handoff IA + humano | S3 |
| B4 | Métricas de funil do fluxo | S5 |
| B5 | Condições origem + score (quando P1/P2 prontos) | S1, S2 |
| B6 | Templates por estágio de jornada | S6 |

**Definition of Done (fase):**

- Gestor mede conclusão e handoff por fluxo
- Handoff n8n documentado e usado em 1 template oficial
- Re-enrollment habilitado em template “Reativação”

---

### Fase C — Diferenciação (8+ semanas)

**Objetivo:** difícil de copiar sem conversa + tempo + contexto.

| # | Entrega | ID |
|---|---------|-----|
| C1 | Nó create_task | S4 |
| C2 | Webhook wait-response | C1 |
| C3 | Memória no payload / interpolação | C2 |
| C4 | Gatilhos `score_changed`, `commitment_detected` | C3 |
| C5 | Switch multi-ramo | C4 |
| C6 | A/B test exposto + métricas | C6 |

---

## Priorização RICE

Fórmula: `(Reach × Impact × Confidence) / Effort`  
Impacto: 1–3. Esforço: 1=S, 2=M, 3=L. Confidence: 0–1.

| Rank | Item | R | I | C | E | Score |
|------|------|---|---|---|---|-------|
| 1 | M2 Log execução | 10 | 3 | 0.95 | 2 | **14.3** |
| 2 | M1 Conflito v1/v2 | 10 | 3 | 0.90 | 2 | **13.5** |
| 3 | M4 Re-enrollment | 8 | 3 | 0.85 | 2 | **10.2** |
| 4 | M6 Cancel agent/label | 9 | 3 | 0.90 | 1 | **24.3** |
| 5 | S3 Handoff IA/humano | 8 | 3 | 0.80 | 2 | **9.6** |
| 6 | M3 Simulação | 7 | 2 | 0.90 | 3 | **4.2** |
| 7 | M5 Versionamento | 8 | 3 | 0.75 | 3 | **6.0** |
| 8 | S5 Métricas funil | 7 | 2 | 0.85 | 2 | **5.9** |
| 9 | S7 UX nós IA | 9 | 2 | 0.95 | 1 | **17.1** |
| 10 | S1 Origem campanha | 6 | 3 | 0.70 | 2 | **6.3** |

**Recomendação de sprint imediato:** M6 → S7 → M1 → M2 (quick wins + confiança).

---

## O que não construir

| Item | Motivo |
|------|--------|
| Paridade com n8n (HTTP genérico infinito, loops, cron) | n8n já resolve; duplicar aumenta superfície de bug |
| IA LLM nativa no ManyTalks (curto prazo) | Arquitetura webhook consolidada; investir em integração |
| Sub-workflows aninhados | Complexidade; só com demanda comprovada |
| 50 tipos de nó | Confunde gestor; viola MVP |
| Loops no grafo | Acíclico é decisão de design válida |
| Editor fluxo ativo editável sem versionamento | Corrompe enrollments em andamento |

---

## Recomendações de implementação

### Por fase

| Fase | Melhor agent | Skill |
|------|--------------|-------|
| A — confiança, logs, conflito | Backend + Frontend Specialist | `systematic-debugging` |
| A — simulação | Backend Specialist | `testing-patterns` |
| B — handoff / webhooks | Backend Specialist | `api-patterns` |
| B — versionamento UX | Frontend Specialist | `architecture` |
| B — métricas | Backend + Performance | `performance-profiling` |
| C — memória / score | Backend + PO | alinhar PRD Prioridades 2 e 4 |
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

| # | Decisão | Opções | Default recomendado |
|---|---------|--------|---------------------|
| 1 | Nome na UI | Manter “Fluxo de Atendimento” vs “Processos de Relacionamento” | Subtítulo explicativo primeiro; rename depois |
| 2 | Handoff pausa vs cancela | Pausar enrollment vs cancelar ao passar para IA | **Pausar** — permite retomar cadência |
| 3 | Score mid-flow | Reavaliar IFs quando score muda vs congelar no enrollment | **Congelar** no MVP; reavaliar na v2 |
| 4 | Simulação | Zero side effects vs inbox sandbox | **Zero side effects** |
| 5 | Versionamento | Cópia de grafo vs tabela `workflow_versions` | Tabela dedicada |
| 6 | Métrica norte | Conclusão vs conversão CRM vs receita | **Conclusão** no MVP; CRM na Fase B |

---

## Apêndice: User stories consolidadas (backlog)

| ID | Story | Prioridade |
|----|-------|------------|
| M1 | Conflito Automações × Fluxos | Must |
| M2 | Log execução visível | Must |
| M3 | Simulação dry-run | Must |
| M4 | Re-enrollment | Must |
| M5 | Draft / versionamento | Must |
| M6 | Cancel on agent / label | Must |
| S1 | Condições origem/campanha | Should |
| S2 | Condições lead score | Should |
| S3 | Nó handoff IA/humano | Should |
| S4 | Nó create_task | Should |
| S5 | Métricas de funil | Should |
| S6 | Templates por jornada | Should |
| S7 | UX nós IA | Should |
| C1 | Webhook wait-response | Could |
| C2 | Memória no fluxo | Could |
| C3 | Gatilhos IA sistema | Could |
| C4 | Switch multi-ramo | Could |
| C5 | Timezone contato | Could |
| C6 | A/B test exposto | Could |

---

*Documento vivo — revisar após Fase A e alinhamento com PRDs das Prioridades 1–5.*
