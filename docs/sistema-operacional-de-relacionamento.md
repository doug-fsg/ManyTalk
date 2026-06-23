# Sistema Operacional de Relacionamento

> **ManyTalks** — de plataforma de WhatsApp para camada de relacionamento que opera a jornada completa do contato.

---

## Mudança de categoria

| Antes | Depois |
|-------|--------|
| Plataforma de WhatsApp | **Sistema Operacional de Relacionamento** |
| Ferramenta de atendimento | Infraestrutura de decisão sobre relacionamento |
| Automações pontuais | Processos completos de jornada |

O mercado nos enxerga hoje como **“Plataforma de WhatsApp”**. Essa categoria limita a percepção de valor: reduz o produto a um canal, quando o que construímos é uma **camada operacional** sobre como empresas se relacionam com pessoas ao longo do tempo.

---

## Tese central

**A conversa é apenas o meio. O que automatizamos é a tomada de decisão.**

Essa distinção muda tudo:

- Não vendemos “robô que responde mensagem”.
- Vendemos **processos que decidem o que fazer** com cada pessoa, no momento certo, com o contexto certo.
- A mensagem é a *execução* de uma decisão já tomada — não o produto em si.

### Analogias de mercado

| Player | Nasceu em | Automatiza |
|--------|-----------|------------|
| **RD Station** | E-mail | Marketing |
| **CRM tradicional** | Pipeline / deals | Vendas |
| **ManyTalks** | Conversa | **Relacionamento** |

O RD Station não substituiu o e-mail — criou uma camada de marketing sobre ele.  
O CRM tradicional não substituiu planilhas — criou uma camada de pipeline sobre oportunidades.  
**Nós não substituímos o RD Station** — isso é pequeno demais. Construímos a **camada de relacionamento** capaz de operar toda a jornada, porque hoje uma empresa **conversa muito mais do que envia e-mails**.

---

## Jornada que queremos operar

Um único ambiente. Uma única relação — não uma transação isolada.

```
Lead → Oportunidade → Cliente → Pós-venda → Retenção → Indicação → Recompra
         ↑                                                              │
         └──────────────────── mesma pessoa, mesma memória ──────────────┘
```

**Objetivo:** enxergar a evolução da pessoa ao longo do tempo, não apenas um negócio fechado ou uma conversa resolvida.

Estados possíveis da relação (não mutuamente exclusivos):

- Lead
- Oportunidade
- Cliente
- Ex-cliente
- Indicador
- Cliente novamente (recompra / reativação)

Cada transição deve poder ser **detectada, pontuada, acionada e medida** — com ou sem intervenção humana.

---

## O que apresentamos aos clientes

Não apresentamos **automações**. Apresentamos **processos completos**:

| Processo | O que decide | Exemplo |
|----------|--------------|---------|
| Qualificação | Quem merece atenção humana agora | Lead quente (score 92) → fila comercial prioritária |
| Nutrição | Quando e como retomar contato | Sem resposta em 24h → cadência de follow-up |
| Handoff | Quem assume e com qual contexto | IA detectou intenção de compra → tarefa + assign |
| Retenção | Quando reengajar antes do churn | Cliente inativo 30 dias → jornada de reativação |
| Pós-venda | O que fazer após a venda | Compromisso na conversa → tarefa automática de follow-up |
| Indicação | Quando pedir e como recompensar | NPS alto + histórico positivo → fluxo de indicação |

**Fluxo de Atendimento** (workflows) é um pilar dessa visão — não um fim em si. É o motor de **cadências temporais e decisões sequenciais**. Automações clássicas cobrem regras instantâneas; fluxos cobrem **jornadas com tempo e ramificação**.

---

## Cinco prioridades estratégicas

### Prioridade 1 — Origem e Campanhas

**Problema:** Sem origem, todo lead é tratado igual — e a promessa da captação se perde no primeiro atendimento.

**O que construir:**

- Rastrear de qual **campanha** veio o lead
- Registrar qual **anúncio** originou o contato
- Registrar qual **promessa** foi feita na captação (copy, oferta, landing)

**Por que importa:**

- Permite **experiências completamente diferentes por origem**
- O fluxo de boas-vindas de quem veio de “consultoria gratuita” ≠ quem veio de “desconto Black Friday”
- Conecta investimento em mídia ao resultado em conversa — fechando o loop marketing → relacionamento

**Critério de sucesso:** gestor consegue filtrar, segmentar e acionar processos por origem sem planilha externa.

---

### Prioridade 2 — Lead Scoring por IA

**Problema:** A IA já classifica pessoas internamente — mas o gestor não vê, não confia e não opera em cima disso.

**O que construir:**

- **Score numérico em tempo real** visível para gestor e agente
- Faixas operacionais claras: ex. **92 = Quente** / **63 = Morno** / **18 = Frio**
- Score influenciando filas, fluxos, prioridade e tarefas

**Por que importa:**

- Aproxima o produto de um **CRM moderno** sem virar CRM genérico
- Aumenta **controle comercial** sobre volume alto de conversas
- Transforma “achismo” em **decisão baseada em sinal**

**Critério de sucesso:** equipe comercial prioriza inbox e follow-ups pelo score, com melhora mensurável em tempo de resposta a leads quentes.

---

### Prioridade 3 — Tarefas Inteligentes

**Problema:** Tarefas existem, mas dependem do humano lembrar de criar — e compromissos se perdem na conversa.

**O que construir:**

- IA detecta **compromissos implícitos ou explícitos** na conversa
- Cria **tarefa automaticamente** (data, responsável, contexto)
- Exemplos: “Te mando a proposta amanhã”, “Ligo na sexta”, “Agendar demo terça 15h”

**Por que importa:**

- Extremamente valioso para **equipes comerciais com alto volume**
- Conecta conversa → ação → resultado (não deixa valor na thread)
- Alimenta Prioridade 4 (memória) e Prioridade 5 (jornada)

**Critério de sucesso:** % de compromissos detectados que viram tarefa concluída no prazo; redução de leads “esquecidos”.

---

### Prioridade 4 — Memória de Relacionamento

**Problema:** Cada conversa começa do zero. Meses depois, ninguém lembra objeções, preferências ou contexto.

**O que construir:**

- IA extrai e persiste **memória estruturada por contato:**
  - Objetivos
  - Histórico relevante
  - Objeções
  - Preferências (canal, horário, tom)
  - Compromissos anteriores
- Memória **reutilizada** em conversas futuras — por humano ou por IA
- Visível para agente (resumo) e consumível por fluxos (condições, mensagens personalizadas)

**Por que importa:**

- Talvez o recurso **mais diferenciador** que podemos construir
- Poucos sistemas no mundo entregam relacionamento contínuo real em escala
- É o que transforma “atendimento” em **relacionamento de longo prazo**

**Critério de sucesso:** agente ou IA referencia contexto passado sem o cliente repetir informação; NPS/retenção melhoram em cohorts com memória ativa.

---

### Prioridade 5 — Jornada Completa

**Problema:** CRM enxerga deal. Atendimento enxerga ticket. Ninguém enxerga **a pessoa**.

**O que construir:**

- Visão unificada da evolução: **Lead → Cliente → Ex-cliente → Indicador → Cliente novamente**
- Transições de estado acionáveis (manual, por regra ou por IA)
- Processos diferentes por **estágio da relação**, não só por estágio do funil de vendas
- Métricas de jornada: tempo em cada fase, taxa de reativação, indicação, recompra

**Por que importa:**

- Uma **relação**, não uma transação
- Permite operar pós-venda, retenção e indicação no **mesmo produto** que capturou o lead
- Fecha o loop estratégico das prioridades 1–4

**Critério de sucesso:** gestor enxerga cohort de contatos atravessando múltiplos estágios de relação dentro do ManyTalks, com processos automáticos em cada transição relevante.

---

## Como as prioridades se conectam

```
                    ┌─────────────────────┐
                    │ 1. Origem/Campanha  │  → contexto de entrada
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │ 2. Lead Scoring IA  │  → priorização
                    └──────────┬──────────┘
                               │
         ┌─────────────────────┼─────────────────────┐
         │                     │                     │
┌────────▼────────┐   ┌────────▼────────┐   ┌───────▼────────┐
│ 3. Tarefas IA   │   │ 4. Memória      │   │ 5. Jornada     │
│ (ação imediata) │   │ (contexto longo)│   │ (visão total)  │
└────────┬────────┘   └────────┬────────┘   └───────┬────────┘
         │                     │                     │
         └─────────────────────┼─────────────────────┘
                               │
                    ┌──────────▼──────────┐
                    │ Fluxos de Atendimento│  → execução temporal
                    │ + Automações         │  → execução instantânea
                    └─────────────────────┘
```

---

## Posicionamento competitivo (resumo)

| Pergunta | Resposta |
|----------|----------|
| Somos CRM? | Não — operamos **relacionamento via conversa**, não pipeline genérico |
| Substituímos RD Station? | Não — complementamos; RD no e-mail, nós na conversa |
| Somos WhatsApp? | WhatsApp é **canal dominante**, não **categoria de produto** |
| O que vendemos? | **Decisões sobre relacionamento**, executadas na conversa certa, na hora certa |

---

## Implicações para produto (hoje)

Coerência entre visão e o que já existe:

| Capacidade atual | Papel na visão | Evolução necessária |
|------------------|----------------|---------------------|
| Fluxo de Atendimento | Motor de cadências e decisões temporais | Confiança operacional, origem-aware, score-aware |
| Automações clássicas | Regras instantâneas | Integrar com jornada, evitar conflito com fluxos |
| CRM Kanban | Estágio comercial | Expandir para **estágio de relação** (Prioridade 5) |
| Régua na conversa | Controle humano sobre processo | Conectar a score, memória e tarefas |
| Nós de IA (webhook) | Ponte para inteligência externa | Evoluir para scoring, memória e tarefas **nativos** |

---

## Próximos passos (documentação e produto)

1. **Alinhar narrativa comercial** — pitch, site e demos falam “Sistema Operacional de Relacionamento”, não “automação de WhatsApp”.
2. **PRD por prioridade** — uma especificação incremental por prioridade (1 → 5), com MVP claro em cada.
3. **Reposicionar Fluxo de Atendimento** — “cadência de relacionamento”, não “n8n de atendimento”.
4. **Definir métrica norte** — ex.: % da jornada Lead → Recompra operada dentro do ManyTalks.

---

## Decisões em aberto

| # | Decisão | Opções | Impacto |
|---|---------|--------|---------|
| 1 | Score IA: caixa preta vs explicável | Só número vs número + motivos | Confiança do gestor |
| 2 | Memória: automática vs curada | IA grava tudo vs agente confirma | Qualidade vs escala |
| 3 | Jornada: substituir Kanban ou camada acima | Um modelo vs dois | Complexidade de UX |
| 4 | Origem: UTM nativo vs integração ads | Built-in vs conectores | Time-to-market P1 |

---

*Documento vivo — revisar conforme PRDs das prioridades 1–5 forem especificados.*
