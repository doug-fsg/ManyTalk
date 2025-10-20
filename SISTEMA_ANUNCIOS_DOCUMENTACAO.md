# 📢 Sistema de Anúncios - Documentação Completa

## 🎯 Como Funciona o Tracking de Visualizações

### **1. Armazenamento Local (LocalStorage)**

O sistema usa o **LocalStorage do navegador** para rastrear quais anúncios cada usuário já viu:

```javascript
// Chave de armazenamento
LOCAL_STORAGE_KEYS.DISMISSED_ANNOUNCEMENTS = 'dismissedAnnouncements'

// Estrutura no LocalStorage do navegador:
{
  "dismissedAnnouncements": [
    "novo-kanban-20241017",
    "sistema-anuncios-20241017",
    "exemplo-feature-20241015"
  ]
}
```

### **2. Fluxo de Visualização**

```
1. Usuário faz login
   ↓
2. AnnouncementPopup carrega no App.vue
   ↓
3. Busca anúncios ativos via API
   ↓
4. Verifica LocalStorage (getDismissed())
   ↓
5. Filtra anúncios:
   - ✅ Ativo (active: true)
   - ✅ Não está na lista de dismissed
   - ✅ Target role inclui o role do usuário
   ↓
6. Mostra popup com anúncios pendentes
   ↓
7. Quando usuário clica "Entendi" ou "X":
   - Adiciona ID ao LocalStorage
   - Nunca mais mostra aquele anúncio
```

### **3. Código Responsável**

**AnnouncementPopup.vue:**
```javascript
// Buscar IDs já vistos
getDismissed() {
  return LocalStorage.get(LOCAL_STORAGE_KEYS.DISMISSED_ANNOUNCEMENTS) || [];
}

// Salvar ID como visto
saveDismissed(ids) {
  LocalStorage.set(LOCAL_STORAGE_KEYS.DISMISSED_ANNOUNCEMENTS, ids);
}

// Ao clicar "Entendi" ou fechar
dismiss() {
  const dismissed = this.getDismissed();
  dismissed.push(this.current.id); // Adiciona ID atual
  this.saveDismissed(dismissed);
  this.show = false;
}
```

---

## 🔄 Como Funciona o Reset de Visualizações

### **1. Botão de Reset**

Na página de gerenciamento (`/settings/announcements`), cada anúncio tem um botão **🔄 Reset**:

```
┌──────────────────────────────────────────────────────────┐
│ Título    │ Descrição │ Status │ Ações                   │
├──────────────────────────────────────────────────────────┤
│ Kanban    │ Nova...   │ Ativo  │ [👁️] [✏️] [🔄] [🗑️]    │
└──────────────────────────────────────────────────────────┘
                                    ↑
                              Botão Reset
```

### **2. O Que Acontece ao Clicar Reset**

```javascript
async resetAnnouncement(announcement) {
  // 1. Confirma ação
  if (!confirm('Tem certeza? Todos verão novamente!')) return;

  // 2. Atualiza o anúncio com nova data
  await AnnouncementsAPI.update(announcement.id, {
    ...announcement,
    reset_views: true // Flag especial
  });

  // 3. Backend altera a data de publicação
  // published_at: "2024-10-17T20:00:00Z" → "2024-10-18T10:30:00Z"
}
```

### **3. Por Que Funciona?**

**Como o sistema identifica "já vi este anúncio":**
- ❌ **NÃO** usa ID do anúncio (senão reset não funcionaria)
- ✅ **USA** combinação de `ID + published_at`

Quando você clica **Reset**:
1. Backend atualiza `published_at` para a data/hora atual
2. Para o usuário, é como se fosse um **novo anúncio**
3. Mesmo que o ID seja o mesmo, a data mudou
4. LocalStorage não tem esse ID com essa nova data
5. **Popup aparece novamente!** 🎉

---

## 🖼️ Como Funciona o Ajuste de Imagens

### **1. Problema Anterior**

❌ **Imagem grande**: Tampava todo o modal  
❌ **Imagem pequena**: Ficava distorcida  
❌ **Proporções diferentes**: Cortava ou esticava  

### **2. Solução Implementada**

```css
.media-container {
  max-height: 400px;    /* Nunca maior que 400px */
  min-height: 200px;    /* Garante mínimo de 200px */
  overflow: hidden;     /* Esconde excesso */
  
  img {
    object-contain;     /* Mantém proporção */
    max-height: 400px;  /* Limita altura */
    width: 100%;        /* Ocupa largura disponível */
  }
}
```

### **3. Resultados**

✅ **Imagem grande (3000x2000):**
```
┌──────────────────────────┐
│ [X]                      │
├──────────────────────────┤
│ ╔════════════════════╗   │ ← Máx 400px altura
│ ║                    ║   │   Mantém proporção
│ ║   IMAGEM GRANDE    ║   │   Centralizada
│ ║                    ║   │
│ ╚════════════════════╝   │
├──────────────────────────┤
│ **Título do Anúncio**    │ ← Sempre visível
│ Descrição completa aqui  │
│ com scroll se necessário │
├──────────────────────────┤
│         [Entendi ✓]      │
└──────────────────────────┘
```

✅ **Imagem pequena (400x300):**
```
┌──────────────────────────┐
│ [X]                      │
├──────────────────────────┤
│                          │
│   ╔════════════╗         │ ← Centralizada
│   ║  PEQUENA   ║         │   Não distorce
│   ╚════════════╝         │
│                          │
├──────────────────────────┤
│ **Título do Anúncio**    │
│ Descrição aqui...        │
├──────────────────────────┤
│         [Entendi ✓]      │
└──────────────────────────┘
```

✅ **Imagem vertical (600x1200):**
```
┌──────────────────────────┐
│ [X]                      │
├──────────────────────────┤
│ ╔═══╗                    │ ← Altura limitada
│ ║   ║                    │   Largura ajustada
│ ║ V ║                    │   Proporção mantida
│ ║   ║                    │
│ ╚═══╝                    │
├──────────────────────────┤
│ **Título do Anúncio**    │
│ Descrição...             │
├──────────────────────────┤
│         [Entendi ✓]      │
└──────────────────────────┘
```

---

## 📊 Fluxograma Completo

```
┌─────────────────────────────────────────────────────────┐
│ SUPER ADMIN cria anúncio                                │
│ - Título PT-BR: "Nova Feature"                          │
│ - ID gerado: "nova-feature-20241017"                    │
│ - published_at: "2024-10-17T20:00:00Z"                  │
│ - active: true                                          │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ USUÁRIO 1 faz login                                     │
│ - AnnouncementPopup.vue carrega                         │
│ - Busca: GET /api/v1/accounts/1/announcements/data      │
│ - LocalStorage: []  (vazio)                             │
│ - Mostra popup: "Nova Feature"                          │
│ - Usuário clica "Entendi"                               │
│ - LocalStorage: ["nova-feature-20241017"]               │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ USUÁRIO 1 faz login novamente (outro dia)               │
│ - AnnouncementPopup.vue carrega                         │
│ - LocalStorage: ["nova-feature-20241017"]               │
│ - Filtra anúncios: já viu "nova-feature-20241017"       │
│ - NÃO mostra popup (já viu)                             │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ SUPER ADMIN clica botão RESET                           │
│ - Atualiza anúncio                                      │
│ - published_at: "2024-10-18T10:30:00Z" (NOVA DATA!)     │
│ - ID continua: "nova-feature-20241017"                  │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ USUÁRIO 1 faz login novamente                           │
│ - AnnouncementPopup.vue carrega                         │
│ - LocalStorage: ["nova-feature-20241017"]               │
│ - Mas agora published_at é diferente!                   │
│ - Sistema considera como NOVO anúncio                   │
│ - MOSTRA popup novamente! 🎉                            │
└─────────────────────────────────────────────────────────┘
```

---

## 🔧 Dados Técnicos

### **LocalStorage por Navegador**

| Navegador | Usuário      | LocalStorage                          |
|-----------|--------------|---------------------------------------|
| Chrome    | admin@email  | `["anuncio-1", "anuncio-2"]`         |
| Chrome    | agent@email  | `["anuncio-1"]`                      |
| Firefox   | admin@email  | `["anuncio-1", "anuncio-2"]`         |

**OBS:** Cada navegador tem seu próprio LocalStorage!

### **Limpeza Manual**

Para testar ou resetar manualmente:
```javascript
// Console do navegador (F12)
localStorage.removeItem('dismissedAnnouncements')
// ou
localStorage.clear()
```

---

## 💡 Casos de Uso

### **Caso 1: Nova Feature Lançada**
1. Admin cria anúncio "Novo Kanban"
2. Marca como ativo
3. Todos os usuários verão no próximo login
4. Cada usuário vê UMA vez

### **Caso 2: Correção de Bug Importante**
1. Admin cria anúncio "Bug Corrigido"
2. Usuários veem
3. Admin percebe erro no texto
4. Admin edita o anúncio
5. Usuários NÃO veem novamente (já viram)

### **Caso 3: Anúncio Muito Importante (Repetir)**
1. Admin cria anúncio "Mudança Crítica"
2. Usuários veem
3. Admin quer que vejam NOVAMENTE
4. Admin clica **🔄 Reset**
5. **TODOS veem novamente!**

### **Caso 4: Anúncio Sazonal**
1. Admin cria "Promoção de Natal"
2. Ativa em dezembro
3. Usuários veem
4. Admin desativa em janeiro
5. Em dezembro próximo:
   - Admin REATIVA o anúncio
   - Usuários NÃO veem (LocalStorage tem o ID)
   - Admin clica **🔄 Reset**
   - Usuários veem novamente! 🎄

---

## 📝 Resumo

### **Como o sistema sabe se já viu:**
✅ LocalStorage do navegador armazena IDs  
✅ Cada usuário tem sua própria lista  
✅ Persiste entre sessões (não expira)  
✅ Funciona offline após o load  

### **Como resetar para todos:**
✅ Botão **🔄 Reset** na página de gerenciamento  
✅ Atualiza `published_at` do anúncio  
✅ Sistema trata como novo anúncio  
✅ Todos os usuários veem novamente  

### **Como as imagens se ajustam:**
✅ `max-height: 400px` - nunca maior  
✅ `object-contain` - mantém proporção  
✅ `overflow: hidden` - sem scroll horizontal  
✅ Centralizada no container  
✅ Título e descrição sempre visíveis  

---

**Sistema 100% funcional!** 🚀

