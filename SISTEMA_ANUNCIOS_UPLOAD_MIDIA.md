# 📸 Sistema de Upload de Mídia para Anúncios

## 🎯 Objetivo

Permitir que administradores façam **upload de imagens** diretamente, além da opção de URL externa.

---

## 📋 Funcionalidades

1. **Opção 1**: Upload de arquivo (novo)
2. **Opção 2**: URL externa (já existe)

---

## 🔧 Implementação

### **Passo 1: Usar o Endpoint de Upload Existente**

O Chatwoot já tem um endpoint de upload em:
```
POST /api/v1/accounts/:account_id/upload
```

**Controller**: `app/controllers/api/v1/accounts/upload_controller.rb`

**Resposta**:
```json
{
  "file_url": "http://localhost:3000/rails/active_storage/blobs/...",
  "blob_key": "abc123...",
  "blob_id": 456
}
```

---

### **Passo 2: Atualizar Frontend - AddAnnouncement.vue**

Adicionar componente de upload:

```vue
<!-- URL da Mídia ou Upload -->
<div class="w-full mb-4">
  <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
    Mídia (GIF/Imagem)
  </label>
  
  <!-- Tabs: URL ou Upload -->
  <div class="flex gap-2 mb-3">
    <button
      type="button"
      @click="mediaType = 'url'"
      class="px-3 py-1 rounded text-sm"
      :class="mediaType === 'url' 
        ? 'bg-woot-500 text-white' 
        : 'bg-slate-200 text-slate-700'"
    >
      🔗 URL
    </button>
    <button
      type="button"
      @click="mediaType = 'upload'"
      class="px-3 py-1 rounded text-sm"
      :class="mediaType === 'upload' 
        ? 'bg-woot-500 text-white' 
        : 'bg-slate-200 text-slate-700'"
    >
      📤 Upload
    </button>
  </div>

  <!-- Input URL -->
  <div v-if="mediaType === 'url'" class="space-y-2">
    <input
      v-model.trim="form.media_url"
      type="text"
      placeholder="https://exemplo.com/meu-gif.gif"
      class="w-full rounded-md border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 px-3 py-2"
    />
    <p class="text-xs text-slate-500 dark:text-slate-400">
      Cole a URL de um GIF ou imagem (max 5MB recomendado)
    </p>
  </div>

  <!-- Input Upload -->
  <div v-if="mediaType === 'upload'" class="space-y-2">
    <!-- Área de drag & drop ou clique -->
    <div
      @click="$refs.fileInput.click()"
      @dragover.prevent="isDragging = true"
      @dragleave.prevent="isDragging = false"
      @drop.prevent="handleFileDrop"
      class="border-2 border-dashed rounded-lg p-6 text-center cursor-pointer transition-colors"
      :class="isDragging 
        ? 'border-woot-500 bg-woot-50 dark:bg-woot-900/20' 
        : 'border-slate-300 dark:border-slate-700 hover:border-woot-400'"
    >
      <!-- Loading -->
      <div v-if="isUploading" class="space-y-2">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-woot-500 mx-auto"></div>
        <p class="text-sm text-slate-600 dark:text-slate-400">Fazendo upload...</p>
      </div>

      <!-- Arquivo já selecionado -->
      <div v-else-if="uploadedFile" class="space-y-3">
        <div class="flex items-center justify-center gap-2">
          <fluent-icon icon="checkmark-circle" size="24" class="text-green-500" />
          <span class="text-sm text-slate-700 dark:text-slate-300">{{ uploadedFile.name }}</span>
        </div>
        <button
          type="button"
          @click.stop="clearUpload"
          class="text-sm text-red-600 hover:text-red-700"
        >
          Remover
        </button>
      </div>

      <!-- Estado inicial -->
      <div v-else class="space-y-2">
        <fluent-icon icon="arrow-upload" size="32" class="text-slate-400 mx-auto" />
        <p class="text-sm text-slate-600 dark:text-slate-400">
          Clique ou arraste uma imagem aqui
        </p>
        <p class="text-xs text-slate-500">
          PNG, JPG, GIF (máx. 5MB)
        </p>
      </div>
    </div>

    <!-- Input file oculto -->
    <input
      ref="fileInput"
      type="file"
      accept="image/png,image/jpeg,image/gif,image/webp"
      @change="handleFileSelect"
      class="hidden"
    />
  </div>

  <!-- Preview da imagem -->
  <div v-if="previewUrl" class="mt-3">
    <p class="text-xs text-slate-600 dark:text-slate-400 mb-2">Preview:</p>
    <div class="border border-slate-300 dark:border-slate-700 rounded-lg p-2 bg-slate-50 dark:bg-slate-900">
      <img 
        :src="previewUrl" 
        alt="Preview" 
        class="max-h-40 mx-auto rounded"
      />
    </div>
  </div>
</div>
```

---

### **Passo 3: Adicionar Lógica no Script**

```vue
<script>
import AnnouncementsAPI from 'dashboard/api/announcements';

export default {
  data() {
    return {
      form: {
        title_pt_BR: '',
        description_pt_BR: '',
        // ... outros campos
        media_url: '',
      },
      mediaType: 'url', // 'url' ou 'upload'
      uploadedFile: null,
      isUploading: false,
      isDragging: false,
      showTranslations: false,
      showAdvanced: false,
      isCreating: false,
    };
  },

  computed: {
    isFormValid() {
      return (
        this.form.title_pt_BR &&
        this.form.description_pt_BR &&
        this.form.target_roles.length > 0
      );
    },
    
    previewUrl() {
      if (this.mediaType === 'url' && this.form.media_url) {
        return this.form.media_url;
      }
      if (this.mediaType === 'upload' && this.uploadedFile) {
        return this.uploadedFile.preview;
      }
      return null;
    },
  },

  methods: {
    async createAnnouncement() {
      this.isCreating = true;
      this.errors = {};

      try {
        // Se for upload, garantir que tem URL
        if (this.mediaType === 'upload' && !this.form.media_url) {
          throw new Error('Faça upload da imagem primeiro');
        }

        await AnnouncementsAPI.create(this.form);
        this.showAlert('Anúncio criado com sucesso!');
        this.$emit('announcement-created');
        this.onClose();
      } catch (error) {
        this.showAlert(error.message || 'Erro ao criar anúncio. Tente novamente.');
        console.error(error);
      } finally {
        this.isCreating = false;
      }
    },

    // 🆕 Manipulador de seleção de arquivo
    async handleFileSelect(event) {
      const file = event.target.files[0];
      if (file) {
        await this.uploadFile(file);
      }
    },

    // 🆕 Manipulador de drag & drop
    async handleFileDrop(event) {
      this.isDragging = false;
      const file = event.dataTransfer.files[0];
      if (file) {
        await this.uploadFile(file);
      }
    },

    // 🆕 Upload do arquivo
    async uploadFile(file) {
      // Validar tipo
      const validTypes = ['image/png', 'image/jpeg', 'image/gif', 'image/webp'];
      if (!validTypes.includes(file.type)) {
        this.showAlert('Tipo de arquivo inválido. Use PNG, JPG, GIF ou WEBP.');
        return;
      }

      // Validar tamanho (5MB)
      if (file.size > 5 * 1024 * 1024) {
        this.showAlert('Arquivo muito grande. Máximo: 5MB.');
        return;
      }

      this.isUploading = true;

      try {
        // Criar FormData
        const formData = new FormData();
        formData.append('attachment', file);

        // Fazer upload usando endpoint do Chatwoot
        const accountId = window.location.pathname.split('/')[3];
        const response = await axios.post(
          `/api/v1/accounts/${accountId}/upload`,
          formData,
          {
            headers: {
              'Content-Type': 'multipart/form-data'
            }
          }
        );

        // Salvar URL retornada
        this.form.media_url = response.data.file_url;
        
        // Salvar info do arquivo para preview
        this.uploadedFile = {
          name: file.name,
          preview: URL.createObjectURL(file),
          url: response.data.file_url,
        };

        this.showAlert('Upload concluído!');
      } catch (error) {
        console.error('Upload error:', error);
        this.showAlert('Erro ao fazer upload. Tente novamente.');
      } finally {
        this.isUploading = false;
      }
    },

    // 🆕 Limpar upload
    clearUpload() {
      this.uploadedFile = null;
      this.form.media_url = '';
      if (this.$refs.fileInput) {
        this.$refs.fileInput.value = '';
      }
    },

    onClose() {
      this.clearUpload();
      this.$emit('close');
    },

    showAlert(message) {
      this.$emitter.emit('newToastMessage', message);
    },
  },
};
</script>
```

---

### **Passo 4: Repetir para EditAnnouncement.vue**

A mesma lógica deve ser adicionada ao componente de edição.

---

## 🎨 **Preview Visual**

```
┌─────────────────────────────────────────────┐
│ Mídia (GIF/Imagem)                          │
├─────────────────────────────────────────────┤
│ [🔗 URL] [📤 Upload]  ← Tabs                │
├─────────────────────────────────────────────┤
│                                             │
│ ╔═══════════════════════════════════════╗   │
│ ║                                       ║   │
│ ║         [📤 ícone upload]            ║   │
│ ║                                       ║   │
│ ║  Clique ou arraste uma imagem aqui    ║   │
│ ║                                       ║   │
│ ║  PNG, JPG, GIF (máx. 5MB)            ║   │
│ ║                                       ║   │
│ ╚═══════════════════════════════════════╝   │
│                                             │
└─────────────────────────────────────────────┘

↓ (após upload)

┌─────────────────────────────────────────────┐
│ Mídia (GIF/Imagem)                          │
├─────────────────────────────────────────────┤
│ [🔗 URL] [📤 Upload]  ← Upload selecionado  │
├─────────────────────────────────────────────┤
│                                             │
│ ╔═══════════════════════════════════════╗   │
│ ║  ✅ kanban-demo.gif                   ║   │
│ ║                                       ║   │
│ ║  [Remover]                            ║   │
│ ╚═══════════════════════════════════════╝   │
│                                             │
│ Preview:                                    │
│ ┌───────────────────────────────────────┐   │
│ │                                       │   │
│ │      [Imagem do GIF aqui]            │   │
│ │                                       │   │
│ └───────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
```

---

## ✅ **Vantagens da Implementação**

1. **Usa infraestrutura existente** (Active Storage do Chatwoot)
2. **Validação de tipo** (PNG, JPG, GIF, WEBP)
3. **Validação de tamanho** (máx. 5MB)
4. **Drag & drop** (melhor UX)
5. **Preview imediato**
6. **Loading state** (feedback visual)
7. **Compatível** com URL externa

---

## 🔐 **Segurança**

O endpoint `/api/v1/accounts/:account_id/upload` já tem:
- ✅ Autenticação (before_action)
- ✅ Permissões de conta
- ✅ Active Storage (gerencia arquivos automaticamente)

---

## 📦 **Armazenamento**

Os arquivos serão armazenados:
- **Desenvolvimento**: `storage/` (local disk)
- **Produção**: Configurável (S3, Google Cloud, Azure)

Configuração em: `config/storage.yml`

---

## 🚀 **Como Testar**

1. Acesse `/settings/announcements`
2. Clique "Novo Anúncio"
3. Em "Mídia", clique na tab "📤 Upload"
4. Arraste uma imagem ou clique para selecionar
5. Aguarde upload (loading spinner)
6. Ver preview
7. Salvar anúncio
8. Verificar que imagem aparece no popup

---

## 🔄 **Diferença: URL vs Upload**

| Característica | URL Externa | Upload |
|---|---|---|
| **Onde fica** | Servidor externo | Active Storage |
| **Controle** | ❌ Depende do link | ✅ Total controle |
| **Performance** | Depende do servidor externo | ✅ Otimizado |
| **Validade** | Link pode quebrar | ✅ Permanente |
| **Processamento** | Não | ✅ Pode redimensionar |

---

## 💡 **Melhorias Futuras (Opcional)**

1. **Redimensionamento automático** (usar Active Storage variants)
2. **Múltiplas imagens** (carousel de imagens)
3. **Suporte a vídeo** (além de GIF)
4. **Compressão automática** (otimizar tamanho)
5. **Crop de imagem** (antes do upload)

---

## 📝 **Exemplo de Uso**

```javascript
// Frontend envia
FormData {
  attachment: [File: kanban.gif]
}

// Backend retorna
{
  "file_url": "http://localhost:3000/rails/active_storage/blobs/redirect/.../kanban.gif",
  "blob_key": "abc123def456",
  "blob_id": 789
}

// Frontend salva no anúncio
{
  "media_url": "http://localhost:3000/rails/active_storage/blobs/redirect/.../kanban.gif"
}
```

---

**Sistema de upload pronto para implementação!** 🎉

