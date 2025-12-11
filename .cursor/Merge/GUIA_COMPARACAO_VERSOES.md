# Guia Prático: Como Comparar Versões do Chatwoot

**Objetivo:** Identificar diferenças entre versões e decidir o que migrar

---

## 🚀 Método Rápido (Recomendado)

### Passo 1: Gerar Arquivo de Diferenças

```bash
cd /Ubuntu-20.04/home/chatwoot/chatwoot

# Comparar duas versões (excluindo arquivos temporários)
diff -r --brief . chatwoot-3.12.0/ \
  --exclude=node_modules \
  --exclude=vendor \
  --exclude=tmp \
  --exclude=log \
  --exclude=.git \
  --exclude=storage \
  --exclude=public/packs \
  --exclude="*.Identifier" \
  --exclude=yarn.lock \
  --exclude=Gemfile.lock \
  > diferencas.txt

# Ver resultado
cat diferencas.txt | wc -l
```

### Passo 2: Analisar Categorias

```bash
# Ver APENAS arquivos que existem na nova versão mas não na sua
grep "^Only in chatwoot-3.12.0" diferencas.txt

# Ver APENAS arquivos que existem na sua mas não na nova versão
grep "^Only in \\./" diferencas.txt

# Ver arquivos que existem em ambas mas são diferentes
grep "^Files.*differ$" diferencas.txt
```

### Passo 3: Análise por Diretório

```bash
# Diferenças em models
grep "app/models" diferencas.txt

# Diferenças em controllers
grep "app/controllers" diferencas.txt

# Diferenças em services
grep "app/services" diferencas.txt

# Diferenças em migrações
grep "db/migrate" diferencas.txt

# Diferenças em JavaScript/Vue
grep "app/javascript" diferencas.txt

# Diferenças em traduções
grep "i18n/locale" diferencas.txt
```

---

## 📊 Métodos de Comparação

### Método 1: diff -r (Usado para gerar diferencas.txt)

**Quando usar:** Primeira análise, visão geral completa

```bash
# Básico
diff -r pasta1/ pasta2/

# Com exclusões
diff -r --brief pasta1/ pasta2/ \
  --exclude=node_modules \
  --exclude=vendor \
  --exclude=tmp \
  --exclude=log \
  --exclude=.git

# Salvar em arquivo
diff -r --brief . versao-nova/ \
  --exclude=node_modules \
  --exclude=vendor \
  > diferencas.txt
```

**Vantagens:**
- ✅ Rápido
- ✅ Visão completa
- ✅ Fácil de filtrar depois

**Desvantagens:**
- ⚠️ Não mostra conteúdo das diferenças
- ⚠️ Precisa análise adicional

---

### Método 2: Git Diff (Melhor para análise detalhada)

**Quando usar:** Quando as versões estão em branches Git diferentes

```bash
# Comparar duas branches
git diff branch1..branch2

# Comparar e salvar
git diff branch1..branch2 > diferencas-detalhadas.txt

# Ver estatísticas
git diff --stat branch1..branch2

# Ver só nomes dos arquivos modificados
git diff --name-only branch1..branch2

# Ver só arquivos adicionados
git diff --name-status branch1..branch2 | grep "^A"

# Ver só arquivos removidos
git diff --name-status branch1..branch2 | grep "^D"

# Ver só arquivos modificados
git diff --name-status branch1..branch2 | grep "^M"
```

**Vantagens:**
- ✅ Mostra conteúdo exato das mudanças
- ✅ Integrado com Git
- ✅ Estatísticas detalhadas

**Desvantagens:**
- ⚠️ Requer que ambas as versões estejam em Git

---

### Método 3: rsync --dry-run (Simular Merge)

**Quando usar:** Planejar o que copiar

```bash
# Ver o que seria copiado (sem copiar)
rsync -av --dry-run \
  --exclude=node_modules \
  --exclude=vendor \
  --exclude=tmp \
  --exclude=log \
  --exclude=.git \
  versao-nova/ versao-atual/

# Salvar em arquivo
rsync -av --dry-run \
  --exclude=node_modules \
  versao-nova/ versao-atual/ \
  > plano-merge.txt
```

**Vantagens:**
- ✅ Mostra exatamente o que será copiado
- ✅ Modo dry-run é seguro
- ✅ Pode executar depois sem --dry-run

**Desvantagens:**
- ⚠️ Saída verbosa

---

### Método 4: find + diff (Comparar Estruturas)

**Quando usar:** Comparar estrutura de diretórios

```bash
# Listar estrutura da versão 1
find . -type f \
  ! -path "*/node_modules/*" \
  ! -path "*/vendor/*" \
  ! -path "*/tmp/*" \
  ! -path "*/.git/*" \
  | sort > estrutura-v1.txt

# Listar estrutura da versão 2
cd chatwoot-3.12.0
find . -type f \
  ! -path "*/node_modules/*" \
  ! -path "*/vendor/*" \
  ! -path "*/tmp/*" \
  ! -path "*/.git/*" \
  | sort > estrutura-v2.txt

# Comparar
diff estrutura-v1.txt estrutura-v2.txt
```

**Vantagens:**
- ✅ Fácil de ver arquivos novos/removidos
- ✅ Comparação limpa

---

### Método 5: grep Específico (Buscar Features)

**Quando usar:** Procurar funcionalidade específica

```bash
# Procurar por "kanban"
grep -r "kanban" versao-nova/ --include="*.rb" --include="*.js" -i

# Procurar por novo canal
grep -r "notifica_me\|captain" versao-nova/ --include="*.rb" -i

# Procurar novas migrações
ls -la versao-nova/db/migrate/ | wc -l
ls -la db/migrate/ | wc -l
```

---

## 🎯 Workflow Completo Recomendado

### Fase 1: Análise Inicial (5 min)

```bash
cd /Ubuntu-20.04/home/chatwoot/chatwoot

# 1. Gerar diff básico
diff -r --brief . versao-nova/ \
  --exclude=node_modules \
  --exclude=vendor \
  --exclude=tmp \
  --exclude=log \
  --exclude=.git \
  --exclude=storage \
  --exclude=public/packs \
  --exclude="*.Identifier" \
  > diferencas.txt

# 2. Ver estatísticas gerais
echo "Total de diferenças:"
wc -l diferencas.txt

echo "Arquivos só na nova versão:"
grep "^Only in versao-nova" diferencas.txt | wc -l

echo "Arquivos só na sua versão:"
grep "^Only in \\." diferencas.txt | wc -l

echo "Arquivos modificados:"
grep "differ$" diferencas.txt | wc -l
```

### Fase 2: Análise por Categoria (10 min)

```bash
# Criar relatório categorizado
echo "=== MIGRAÇÕES ===" > analise-categorizada.txt
grep "db/migrate" diferencas.txt >> analise-categorizada.txt

echo -e "\n=== MODELS ===" >> analise-categorizada.txt
grep "app/models" diferencas.txt >> analise-categorizada.txt

echo -e "\n=== CONTROLLERS ===" >> analise-categorizada.txt
grep "app/controllers" diferencas.txt >> analise-categorizada.txt

echo -e "\n=== SERVICES ===" >> analise-categorizada.txt
grep "app/services" diferencas.txt >> analise-categorizada.txt

echo -e "\n=== JAVASCRIPT ===" >> analise-categorizada.txt
grep "app/javascript" diferencas.txt | head -50 >> analise-categorizada.txt

echo -e "\n=== TRADUÇÕES ===" >> analise-categorizada.txt
grep "i18n/locale" diferencas.txt >> analise-categorizada.txt

echo -e "\n=== DEPENDÊNCIAS ===" >> analise-categorizada.txt
grep -E "package.json|Gemfile|yarn.lock" diferencas.txt >> analise-categorizada.txt

# Ver resultado
less analise-categorizada.txt
```

### Fase 3: Análise Detalhada (20 min)

```bash
# Ver conteúdo de arquivos específicos diferentes
# Exemplo: package.json
diff -u package.json versao-nova/package.json

# Exemplo: Gemfile
diff -u Gemfile versao-nova/Gemfile

# Exemplo: migração específica
diff -u db/schema.rb versao-nova/db/schema.rb
```

### Fase 4: Decisão e Execução (variável)

Use o template de decisão abaixo.

---

## 📋 Template de Análise para Futuras Versões

### 1. Informações Básicas

```bash
# Versão real (pode ser diferente do nome da pasta)
cat versao-nova/VERSION_CW

# Changelog oficial
# Procurar no GitHub: https://github.com/chatwoot/chatwoot/releases
```

### 2. Checklist de Análise

```markdown
## Versão: X.Y.Z

### Banco de Dados
- [ ] Número de migrações na nova versão: ___
- [ ] Número de migrações na minha versão: ___
- [ ] Diferença: +/- ___
- [ ] Listar migrações exclusivas:
  - [ ] ___________________________
  - [ ] ___________________________

### Dependências
- [ ] Novos pacotes npm: _____________
- [ ] Novos gems Ruby: _____________
- [ ] Versões atualizadas: _____________

### Funcionalidades Novas
- [ ] Novo canal: _____________
- [ ] Nova integração: _____________
- [ ] Novo sistema: _____________

### Arquivos Exclusivos da Nova Versão
Backend:
- [ ] Models: ___
- [ ] Controllers: ___
- [ ] Services: ___
- [ ] Jobs: ___

Frontend:
- [ ] Componentes: ___
- [ ] Routes: ___
- [ ] Stores: ___
- [ ] Helpers: ___

### Arquivos Exclusivos da Minha Versão
- [ ] ___________________________
- [ ] ___________________________

### Decisão Final
- [ ] Copiar tudo
- [ ] Cherry-pick seletivo
- [ ] Ignorar por enquanto
```

---

## 🔍 Comandos Úteis para Análise

### Comparar Migrações

```bash
# Listar migrações da nova versão
ls -1 versao-nova/db/migrate/ | sort > migrations-new.txt

# Listar suas migrações
ls -1 db/migrate/ | sort > migrations-current.txt

# Ver diferenças
diff migrations-current.txt migrations-new.txt

# Migrações só na nova versão
comm -13 migrations-current.txt migrations-new.txt

# Migrações só na sua versão
comm -23 migrations-current.txt migrations-new.txt
```

### Comparar Dependências

```bash
# Comparar package.json lado a lado
diff -y package.json versao-nova/package.json | less

# Ver só dependências adicionadas
diff -u package.json versao-nova/package.json | grep "^+"

# Ver só dependências removidas
diff -u package.json versao-nova/package.json | grep "^-"

# Mesmo para Gemfile
diff -y Gemfile versao-nova/Gemfile | less
```

### Comparar Estrutura de Código

```bash
# Quantos models em cada versão
ls -1 app/models/*.rb | wc -l
ls -1 versao-nova/app/models/*.rb | wc -l

# Quantos controllers
find app/controllers -name "*.rb" | wc -l
find versao-nova/app/controllers -name "*.rb" | wc -l

# Quantos components Vue
find app/javascript -name "*.vue" | wc -l
find versao-nova/app/javascript -name "*.vue" | wc -l

# Quantos idiomas
ls -1 app/javascript/dashboard/i18n/locale/ | wc -l
ls -1 versao-nova/app/javascript/dashboard/i18n/locale/ | wc -l
```

### Buscar Funcionalidades Específicas

```bash
# Procurar por novo canal
grep -r "channel.*nome_do_canal" versao-nova/app/models/channel/ -i

# Procurar nova integração
ls versao-nova/app/services/ | grep -v "^$"

# Procurar novos jobs
diff <(ls -1 app/jobs/) <(ls -1 versao-nova/app/jobs/)
```

---

## 🛠️ Ferramentas Alternativas

### 1. Beyond Compare (GUI - Excelente)

Se tiver Windows, instale Beyond Compare:

```bash
# No Windows, abrir GUI
"C:\Program Files\Beyond Compare 4\BCompare.exe" \
  \\wsl$\Ubuntu-20.04\home\chatwoot\chatwoot \
  \\wsl$\Ubuntu-20.04\home\chatwoot\chatwoot\chatwoot-3.12.0
```

**Vantagens:**
- ✅ Interface visual
- ✅ Comparação lado a lado
- ✅ Merge visual
- ✅ Filtros poderosos

### 2. Meld (GUI - Linux)

```bash
# Instalar
sudo apt install meld

# Usar
meld . versao-nova/
```

### 3. VS Code (Built-in)

```bash
# Abrir comparação no VS Code
code --diff pasta1/arquivo.js pasta2/arquivo.js

# Ou usar extensão GitLens
```

### 4. difftastic (Moderna)

```bash
# Instalar
cargo install difftastic

# Usar
difft pasta1/ pasta2/
```

---

## 📝 Script Automatizado Completo

Salve como `compare-versions.sh`:

```bash
#!/bin/bash

# Script: compare-versions.sh
# Uso: ./compare-versions.sh versao-nova-pasta

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

VERSION_DIR="$1"

if [ -z "$VERSION_DIR" ]; then
  echo -e "${RED}Erro: Informe a pasta da nova versão${NC}"
  echo "Uso: $0 chatwoot-3.12.0"
  exit 1
fi

if [ ! -d "$VERSION_DIR" ]; then
  echo -e "${RED}Erro: Diretório $VERSION_DIR não encontrado${NC}"
  exit 1
fi

echo -e "${GREEN}=== Análise de Versões ===${NC}"
echo "Versão atual: $(pwd)"
echo "Versão nova: $VERSION_DIR"
echo ""

# 1. Verificar versões reais
echo -e "${YELLOW}1. Verificando versões reais...${NC}"
echo "Versão atual: $(cat VERSION_CW 2>/dev/null || echo 'N/A')"
echo "Versão nova: $(cat $VERSION_DIR/VERSION_CW 2>/dev/null || echo 'N/A')"
echo ""

# 2. Gerar diff completo
echo -e "${YELLOW}2. Gerando arquivo de diferenças...${NC}"
diff -r --brief . "$VERSION_DIR/" \
  --exclude=node_modules \
  --exclude=vendor \
  --exclude=tmp \
  --exclude=log \
  --exclude=.git \
  --exclude=storage \
  --exclude=public/packs \
  --exclude="*.Identifier" \
  --exclude=yarn.lock \
  --exclude=Gemfile.lock \
  > diferencas-$(basename $VERSION_DIR).txt 2>&1 || true

echo "Arquivo gerado: diferencas-$(basename $VERSION_DIR).txt"
echo "Total de linhas: $(wc -l < diferencas-$(basename $VERSION_DIR).txt)"
echo ""

# 3. Análise de migrações
echo -e "${YELLOW}3. Comparando migrações...${NC}"
CURRENT_MIG=$(ls -1 db/migrate/*.rb 2>/dev/null | wc -l)
NEW_MIG=$(ls -1 $VERSION_DIR/db/migrate/*.rb 2>/dev/null | wc -l)
echo "Migrações atuais: $CURRENT_MIG"
echo "Migrações na nova: $NEW_MIG"
echo "Diferença: $(($NEW_MIG - $CURRENT_MIG))"

if [ $NEW_MIG -gt $CURRENT_MIG ]; then
  echo -e "${GREEN}Nova versão tem mais migrações!${NC}"
elif [ $NEW_MIG -lt $CURRENT_MIG ]; then
  echo -e "${RED}Sua versão tem mais migrações!${NC}"
fi
echo ""

# 4. Comparar dependências
echo -e "${YELLOW}4. Comparando dependências...${NC}"

echo "--- Package.json ---"
diff -u package.json "$VERSION_DIR/package.json" 2>/dev/null | \
  grep -E "^[\+\-].*\".*\":" | head -20 || echo "Sem diferenças significativas"

echo ""
echo "--- Gemfile ---"
diff -u Gemfile "$VERSION_DIR/Gemfile" 2>/dev/null | \
  grep -E "^[\+\-].*gem " | head -20 || echo "Sem diferenças significativas"
echo ""

# 5. Análise de models
echo -e "${YELLOW}5. Comparando Models...${NC}"
CURRENT_MODELS=$(find app/models -name "*.rb" 2>/dev/null | wc -l)
NEW_MODELS=$(find $VERSION_DIR/app/models -name "*.rb" 2>/dev/null | wc -l)
echo "Models atuais: $CURRENT_MODELS"
echo "Models na nova: $NEW_MODELS"
echo "Diferença: $(($NEW_MODELS - $CURRENT_MODELS))"
echo ""

# 6. Análise de idiomas
echo -e "${YELLOW}6. Comparando Idiomas...${NC}"
CURRENT_LANGS=$(ls -1 app/javascript/dashboard/i18n/locale/ 2>/dev/null | wc -l)
NEW_LANGS=$(ls -1 $VERSION_DIR/app/javascript/dashboard/i18n/locale/ 2>/dev/null | wc -l)
echo "Idiomas atuais: $CURRENT_LANGS"
echo "Idiomas na nova: $NEW_LANGS"
echo "Diferença: $(($NEW_LANGS - $CURRENT_LANGS))"

if [ $NEW_LANGS -gt $CURRENT_LANGS ]; then
  echo -e "${GREEN}Nova versão tem mais idiomas!${NC}"
  echo "Idiomas adicionais:"
  comm -13 \
    <(ls -1 app/javascript/dashboard/i18n/locale/ 2>/dev/null | sort) \
    <(ls -1 $VERSION_DIR/app/javascript/dashboard/i18n/locale/ 2>/dev/null | sort) \
    | head -10
fi
echo ""

# 7. Análise categorizada
echo -e "${YELLOW}7. Gerando análise categorizada...${NC}"
DIFF_FILE="diferencas-$(basename $VERSION_DIR).txt"
ANALYSIS_FILE="analise-$(basename $VERSION_DIR).txt"

cat > "$ANALYSIS_FILE" << EOF
=== ANÁLISE DE DIFERENÇAS: $(basename $VERSION_DIR) ===
Data: $(date)

=== MIGRAÇÕES ===
EOF
grep "db/migrate" "$DIFF_FILE" >> "$ANALYSIS_FILE"

cat >> "$ANALYSIS_FILE" << EOF

=== MODELS ===
EOF
grep "app/models" "$DIFF_FILE" >> "$ANALYSIS_FILE"

cat >> "$ANALYSIS_FILE" << EOF

=== CONTROLLERS ===
EOF
grep "app/controllers" "$DIFF_FILE" >> "$ANALYSIS_FILE"

cat >> "$ANALYSIS_FILE" << EOF

=== SERVICES ===
EOF
grep "app/services" "$DIFF_FILE" >> "$ANALYSIS_FILE"

cat >> "$ANALYSIS_FILE" << EOF

=== JOBS ===
EOF
grep "app/jobs" "$DIFF_FILE" >> "$ANALYSIS_FILE"

cat >> "$ANALYSIS_FILE" << EOF

=== TRADUÇÕES ===
EOF
grep "i18n/locale" "$DIFF_FILE" | head -30 >> "$ANALYSIS_FILE"

echo "Análise salva em: $ANALYSIS_FILE"
echo ""

# 8. Resumo final
echo -e "${GREEN}=== RESUMO FINAL ===${NC}"
echo "1. Diferenças completas: diferencas-$(basename $VERSION_DIR).txt"
echo "2. Análise categorizada: analise-$(basename $VERSION_DIR).txt"
echo ""
echo "Próximos passos:"
echo "  1. Revisar analise-$(basename $VERSION_DIR).txt"
echo "  2. Decidir o que copiar"
echo "  3. Executar cherry-pick seletivo"
echo ""
```

**Uso:**

```bash
chmod +x compare-versions.sh
./compare-versions.sh chatwoot-3.12.0
```

---

## 🎨 Comparação Visual com Tabela

```bash
# Script para gerar tabela comparativa
echo "| Categoria | Atual | Nova | Diferença |"
echo "|-----------|-------|------|-----------|"

echo -n "| Migrações | "
echo -n "$(ls -1 db/migrate/*.rb 2>/dev/null | wc -l) | "
echo -n "$(ls -1 versao-nova/db/migrate/*.rb 2>/dev/null | wc -l) | "
echo "$(( $(ls -1 versao-nova/db/migrate/*.rb 2>/dev/null | wc -l) - $(ls -1 db/migrate/*.rb 2>/dev/null | wc -l) )) |"

echo -n "| Models | "
echo -n "$(find app/models -name '*.rb' 2>/dev/null | wc -l) | "
echo -n "$(find versao-nova/app/models -name '*.rb' 2>/dev/null | wc -l) | "
echo "$(( $(find versao-nova/app/models -name '*.rb' 2>/dev/null | wc -l) - $(find app/models -name '*.rb' 2>/dev/null | wc -l) )) |"

echo -n "| Components Vue | "
echo -n "$(find app/javascript -name '*.vue' 2>/dev/null | wc -l) | "
echo -n "$(find versao-nova/app/javascript -name '*.vue' 2>/dev/null | wc -l) | "
echo "$(( $(find versao-nova/app/javascript -name '*.vue' 2>/dev/null | wc -l) - $(find app/javascript -name '*.vue' 2>/dev/null | wc -l) )) |"

echo -n "| Idiomas | "
echo -n "$(ls -1 app/javascript/dashboard/i18n/locale/ 2>/dev/null | wc -l) | "
echo -n "$(ls -1 versao-nova/app/javascript/dashboard/i18n/locale/ 2>/dev/null | wc -l) | "
echo "$(( $(ls -1 versao-nova/app/javascript/dashboard/i18n/locale/ 2>/dev/null | wc -l) - $(ls -1 app/javascript/dashboard/i18n/locale/ 2>/dev/null | wc -l) )) |"
```

---

## 📚 Dicas e Boas Práticas

### 1. Sempre Verificar Versão Real

```bash
# Nome da pasta pode ser diferente da versão interna
cat pasta-versao/VERSION_CW
```

### 2. Começar pelo Changelog Oficial

```bash
# Procurar no GitHub
# https://github.com/chatwoot/chatwoot/releases/tag/vX.Y.Z
```

### 3. Focar em Categorias

Priorize nesta ordem:
1. **Migrações** (impacto no banco de dados)
2. **Dependências** (impacto em instalação)
3. **Traduções** (fácil, alto valor)
4. **Models/Services** (funcionalidades core)
5. **Components** (UI/UX)

### 4. Usar Exclusões Inteligentes

```bash
# Sempre excluir:
--exclude=node_modules \
--exclude=vendor \
--exclude=tmp \
--exclude=log \
--exclude=.git \
--exclude=storage \
--exclude=public/packs \
--exclude="*.Identifier" \  # Arquivos do Windows
--exclude=yarn.lock \        # Lockfiles (analisar separado)
--exclude=Gemfile.lock
```

### 5. Git é Seu Amigo

Se possível, use Git para comparar:

```bash
# Adicionar versão nova como remote
git remote add upstream-3.12.0 /path/to/versao-nova

# Fetch
git fetch upstream-3.12.0

# Comparar
git diff HEAD..upstream-3.12.0/main

# Ver arquivos modificados
git diff --name-only HEAD..upstream-3.12.0/main
```

---

## 🎯 Estratégias de Merge

### Estratégia 1: Cherry-Pick Seletivo (RECOMENDADO)

```bash
# 1. Identificar o que quer
grep "específico" diferencas.txt

# 2. Copiar seletivamente
cp versao-nova/caminho/arquivo.rb caminho/arquivo.rb

# 3. Testar
bundle exec rspec spec/caminho/arquivo_spec.rb

# 4. Commit
git add caminho/arquivo.rb
git commit -m "feat: Add feature X from 3.12.0"
```

### Estratégia 2: Merge por Categoria

```bash
# Mergear uma categoria por vez

# 1. Traduções (seguro)
cp -r versao-nova/app/javascript/*/i18n/locale/* app/javascript/*/i18n/locale/

# 2. Configs (cuidado)
diff -u .eslintrc.js versao-nova/.eslintrc.js
# Decidir manualmente

# 3. Código (muito cuidado)
# Analisar arquivo por arquivo
```

### Estratégia 3: Merge Completo (NÃO RECOMENDADO)

```bash
# Só use se:
# - Não tem customizações
# - Está disposto a resolver centenas de conflitos
# - Tem tempo (dias/semanas)

git merge versao-nova-branch
# Resolver conflitos...
# Resolver conflitos...
# Resolver conflitos...
```

---

## 🔍 Análise Específica por Tipo de Arquivo

### Migrações (.rb em db/migrate/)

```bash
# Comparar migrações
diff <(ls -1 db/migrate/) <(ls -1 versao-nova/db/migrate/)

# Ver conteúdo de migração nova
cat versao-nova/db/migrate/YYYYMMDD_nome_da_migracao.rb

# Decisão:
# - Copiar se adiciona funcionalidade que você quer
# - SEMPRE testar em staging primeiro
```

### Models (.rb em app/models/)

```bash
# Ver models novos
comm -13 \
  <(ls -1 app/models/*.rb | xargs -n1 basename | sort) \
  <(ls -1 versao-nova/app/models/*.rb | xargs -n1 basename | sort)

# Ver models que você tem a mais
comm -23 \
  <(ls -1 app/models/*.rb | xargs -n1 basename | sort) \
  <(ls -1 versao-nova/app/models/*.rb | xargs -n1 basename | sort)

# Ver conteúdo de model novo
cat versao-nova/app/models/novo_model.rb
```

### Services (.rb em app/services/)

```bash
# Comparar estrutura de services
diff -r --brief app/services/ versao-nova/app/services/ \
  | grep "^Only"

# Ver service novo
cat versao-nova/app/services/novo_service.rb
```

### Components Vue (.vue)

```bash
# Components novos na nova versão
comm -13 \
  <(find app/javascript -name "*.vue" | sort) \
  <(find versao-nova/app/javascript -name "*.vue" | sort)

# Ver conteúdo
cat versao-nova/app/javascript/dashboard/components/NovoComponent.vue
```

### Traduções (JSON em i18n/locale/)

```bash
# Ver idiomas novos
comm -13 \
  <(ls -1 app/javascript/dashboard/i18n/locale/ | sort) \
  <(ls -1 versao-nova/app/javascript/dashboard/i18n/locale/ | sort)

# Copiar todos (seguro)
cp -r versao-nova/app/javascript/*/i18n/locale/* app/javascript/*/i18n/locale/
```

---

## 📊 Template de Relatório

Use este template para documentar suas análises:

```markdown
# Relatório de Comparação: Versão X.Y.Z

**Data:** ___________
**Versão Analisada:** X.Y.Z (real: _____ conforme VERSION_CW)
**Branch Atual:** develop

## 1. Estatísticas Gerais

| Métrica | Atual | Nova | Diferença |
|---------|-------|------|-----------|
| Migrações | ___ | ___ | +/- ___ |
| Models | ___ | ___ | +/- ___ |
| Controllers | ___ | ___ | +/- ___ |
| Services | ___ | ___ | +/- ___ |
| Components Vue | ___ | ___ | +/- ___ |
| Idiomas | ___ | ___ | +/- ___ |

## 2. Funcionalidades Novas

### Na Nova Versão:
- [ ] _____________________
- [ ] _____________________

### No Develop Atual (exclusivas):
- [x] Sistema Kanban
- [x] Canal NotificaMe
- [ ] _____________________

## 3. Decisões

### Copiar:
- [ ] Traduções
- [ ] _____________________

### Avaliar:
- [ ] _____________________

### Ignorar:
- [ ] _____________________

## 4. Comandos Executados

```bash
# Listar comandos executados
```

## 5. Próximos Passos

- [ ] _____________________
- [ ] _____________________
```

---

## 🚀 Comandos Rápidos (Cheat Sheet)

```bash
# ANÁLISE RÁPIDA
diff -r --brief . versao-nova/ --exclude={node_modules,vendor,tmp,log,.git} > diff.txt

# VER NOVOS ARQUIVOS
grep "^Only in versao-nova" diff.txt

# VER SEUS ARQUIVOS EXCLUSIVOS
grep "^Only in \\." diff.txt

# COMPARAR MIGRAÇÕES
ls -1 db/migrate/ > m1.txt
ls -1 versao-nova/db/migrate/ > m2.txt
diff m1.txt m2.txt

# COMPARAR PACKAGE.JSON
diff -y package.json versao-nova/package.json | less

# COMPARAR GEMFILE
diff -y Gemfile versao-nova/Gemfile | less

# CONTAR IDIOMAS
ls -1 app/javascript/dashboard/i18n/locale/ | wc -l
ls -1 versao-nova/app/javascript/dashboard/i18n/locale/ | wc -l

# COPIAR TRADUÇÕES (SEGURO)
cp -r versao-nova/app/javascript/*/i18n/locale/* app/javascript/*/i18n/locale/

# ATUALIZAR SENTRY (SEGURO)
sed -i 's/>= 5.18.2/>= 5.19.0/g' Gemfile && bundle install
```

---

## 📖 Referências Úteis

### Documentação de Comandos

```bash
man diff        # Manual do diff
man rsync       # Manual do rsync
man comm        # Manual do comm (compare sorted files)
man grep        # Manual do grep
```

### Links Úteis

- **Chatwoot Releases:** https://github.com/chatwoot/chatwoot/releases
- **Chatwoot Changelog:** https://github.com/chatwoot/chatwoot/blob/develop/CHANGELOG.md
- **Beyond Compare:** https://www.scootersoftware.com/
- **Meld:** https://meldmerge.org/

---

## 🎓 Resumo do Processo

### Como Chegamos ao `diferencas.txt`:

```bash
# 1. Comando executado
diff -r --brief . chatwoot-3.12.0/ \
  --exclude=node_modules \
  --exclude=vendor \
  --exclude=tmp \
  --exclude=log \
  --exclude=.git \
  --exclude=storage \
  --exclude=public/packs \
  --exclude="*.Identifier" \
  > diferencas.txt

# 2. Análise manual do arquivo
# 3. Categorização das diferenças
# 4. Decisão de valor (vale a pena copiar?)
```

### Ferramentas Usadas:

1. ✅ `diff -r --brief` - Comparação recursiva
2. ✅ `grep` - Filtrar categorias
3. ✅ `wc -l` - Contar linhas
4. ✅ `comm` - Comparar listas ordenadas
5. ✅ `find` - Localizar arquivos
6. ✅ Análise manual - Decisões de negócio

---

**Fim do Guia**

**Próxima vez que precisar comparar:**
1. Execute `./compare-versions.sh versao-nova`
2. Revise `analise-versao-nova.txt`
3. Use este guia para decidir o que copiar
4. Cherry-pick seletivo
5. Teste e commit

**Tempo total:** 15-30 minutos de análise + tempo de implementação das melhorias escolhidas

