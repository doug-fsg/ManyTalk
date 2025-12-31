<template>
  <div class="announcement-form-modal">
    <woot-modal-header header-title="Editar Anúncio" />
    
    <!-- Layout de 2 colunas -->
    <div class="grid grid-cols-[2fr_1fr] gap-6 h-[calc(100vh-160px)] overflow-hidden">
      <!-- Coluna Esquerda: Formulário -->
      <div class="overflow-y-auto">
        <form class="flex flex-wrap mx-0 p-6" @submit.prevent="updateAnnouncement">
          <!-- Status Ativo -->
          <div class="w-full mb-4 pb-4 border-b border-slate-200 dark:border-slate-700">
            <label class="inline-flex items-center">
              <input
                type="checkbox"
                v-model="form.active"
                class="rounded-lg border-slate-300 text-woot-500 shadow-soft focus:border-woot-300 focus:ring focus:ring-woot-200 focus:ring-opacity-50 dark:bg-slate-700 dark:border-slate-600 transition-all duration-150 ease-smooth"
              />
              <span class="ml-2 text-sm font-medium text-slate-700 dark:text-slate-300">
                Anúncio ativo
              </span>
            </label>
          </div>

      <!-- Título (PT-BR) - OBRIGATÓRIO -->
      <div class="w-full mb-4">
        <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
          Título*
        </label>
        <input
          v-model.trim="form.title_pt_BR"
          type="text"
          required
          class="w-full rounded-lg border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 px-3 py-2 transition-colors duration-150 ease-smooth"
        />
      </div>

      <!-- Descrição (PT-BR) - OBRIGATÓRIA -->
      <div class="w-full mb-4">
        <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
          Descrição*
        </label>
        <textarea
          v-model.trim="form.description_pt_BR"
          rows="4"
          required
          placeholder="Descreva a nova funcionalidade...&#10;&#10;Você pode quebrar linhas e incluir links (http:// ou https://) que serão automaticamente clicáveis."
          class="w-full rounded-lg border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 px-3 py-2 transition-colors duration-150 ease-smooth"
        ></textarea>
        <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">
          Use Enter para quebrar linhas. Links serão automaticamente detectados e tornados clicáveis.
        </p>
      </div>

      <!-- Botão para mostrar traduções -->
      <div class="w-full mb-4">
        <button
          type="button"
          @click="showTranslations = !showTranslations"
          class="text-sm text-slate-600 dark:text-slate-400 hover:text-woot-500 dark:hover:text-woot-400 flex items-center gap-2 transition-colors duration-150 ease-smooth"
        >
          <fluent-icon :icon="showTranslations ? 'chevron-down' : 'chevron-right'" size="14" />
          {{ showTranslations ? 'Ocultar traduções' : '+ Editar traduções (opcional)' }}
        </button>
      </div>

      <!-- Traduções (OPCIONAL - Colapsável) -->
      <div v-if="showTranslations" class="w-full space-y-4 mb-4 p-4 bg-slate-50 dark:bg-slate-800 rounded-xl shadow-soft animate-fade-in">
        <!-- EN -->
        <div class="border-b border-slate-200 dark:border-slate-700 pb-4">
          <h4 class="text-sm font-semibold text-slate-700 dark:text-slate-300 mb-3">
            🇺🇸 English
          </h4>
          <div class="mb-3">
            <label class="block text-sm text-slate-600 dark:text-slate-400 mb-1">Title</label>
            <input
              v-model.trim="form.title_en"
              type="text"
              class="w-full rounded-md border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100 px-3 py-2"
            />
          </div>
          <div>
            <label class="block text-sm text-slate-600 dark:text-slate-400 mb-1">Description</label>
            <textarea
              v-model.trim="form.description_en"
              rows="2"
              class="w-full rounded-md border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100 px-3 py-2"
            ></textarea>
          </div>
        </div>

        <!-- ES -->
        <div class="border-b border-slate-200 dark:border-slate-700 pb-4">
          <h4 class="text-sm font-semibold text-slate-700 dark:text-slate-300 mb-3">
            🇪🇸 Español
          </h4>
          <div class="mb-3">
            <label class="block text-sm text-slate-600 dark:text-slate-400 mb-1">Título</label>
            <input
              v-model.trim="form.title_es"
              type="text"
              class="w-full rounded-md border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100 px-3 py-2"
            />
          </div>
          <div>
            <label class="block text-sm text-slate-600 dark:text-slate-400 mb-1">Descripción</label>
            <textarea
              v-model.trim="form.description_es"
              rows="2"
              class="w-full rounded-md border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100 px-3 py-2"
            ></textarea>
          </div>
        </div>

        <!-- PT -->
        <div>
          <h4 class="text-sm font-semibold text-slate-700 dark:text-slate-300 mb-3">
            🇵🇹 Português (Portugal)
          </h4>
          <div class="mb-3">
            <label class="block text-sm text-slate-600 dark:text-slate-400 mb-1">Título</label>
            <input
              v-model.trim="form.title_pt"
              type="text"
              class="w-full rounded-md border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100 px-3 py-2"
            />
          </div>
          <div>
            <label class="block text-sm text-slate-600 dark:text-slate-400 mb-1">Descrição</label>
            <textarea
              v-model.trim="form.description_pt"
              rows="2"
              class="w-full rounded-md border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100 px-3 py-2"
            ></textarea>
          </div>
        </div>
      </div>

      <!-- Mídia: URL ou Upload -->
      <div class="w-full mb-4">
        <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
          Mídia (Imagem/GIF/Vídeo)
        </label>
        
        <!-- Tabs: URL ou Upload -->
        <div class="flex gap-2 mb-3">
          <button
            type="button"
            @click="mediaType = 'url'"
            class="px-3 py-1.5 rounded-lg text-sm font-medium transition-all duration-200 ease-smooth"
            :class="mediaType === 'url' 
              ? 'bg-woot-500 text-white' 
              : 'bg-slate-200 text-slate-700 dark:bg-slate-700 dark:text-slate-300 hover:bg-slate-300 dark:hover:bg-slate-600'"
          >
            URL
          </button>
          <button
            type="button"
            @click="mediaType = 'upload'"
            class="px-3 py-1.5 rounded-lg text-sm font-medium transition-all duration-200 ease-smooth"
            :class="mediaType === 'upload' 
              ? 'bg-woot-500 text-white' 
              : 'bg-slate-200 text-slate-700 dark:bg-slate-700 dark:text-slate-300 hover:bg-slate-300 dark:hover:bg-slate-600'"
          >
            Upload
          </button>
        </div>

        <!-- Opção 1: URL Externa -->
        <div v-if="mediaType === 'url'" class="space-y-2">
          <input
            v-model.trim="form.media_url"
            type="text"
            placeholder="https://exemplo.com/meu-arquivo.gif"
            class="w-full rounded-lg border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 px-3 py-2 transition-colors duration-150 ease-smooth"
          />
          <p class="text-xs text-slate-500 dark:text-slate-400">
            Cole a URL de uma imagem, GIF ou vídeo (max 10MB recomendado)
          </p>
        </div>

        <!-- Opção 2: Upload de Arquivo -->
        <div v-if="mediaType === 'upload'" class="space-y-3">
          <!-- Área de drag & drop -->
          <div
            @click="!isUploading && $refs.fileInput.click()"
            @dragover.prevent="isDragging = true"
            @dragleave.prevent="isDragging = false"
            @drop.prevent="handleFileDrop"
            class="border-2 border-dashed rounded-xl p-6 text-center transition-all duration-300 ease-smooth"
            :class="[
              isDragging 
                ? 'border-woot-500 bg-woot-50 dark:bg-woot-900/20' 
                : 'border-slate-300 dark:border-slate-700 hover:border-woot-400 dark:hover:border-woot-500',
              isUploading ? 'cursor-wait' : 'cursor-pointer'
            ]"
          >
            <!-- Estado: Uploading -->
            <div v-if="isUploading" class="space-y-2">
              <div class="animate-spin rounded-full h-10 w-10 border-b-2 border-woot-500 mx-auto"></div>
              <p class="text-sm text-slate-600 dark:text-slate-400 font-medium">
                Fazendo upload...
              </p>
              <p class="text-xs text-slate-500">
                Aguarde, isso pode levar alguns segundos
              </p>
            </div>

            <!-- Estado: Arquivo enviado -->
            <div v-else-if="uploadedFile" class="space-y-3">
              <div class="flex items-center justify-center gap-2">
                <fluent-icon icon="checkmark-circle" size="24" class="text-green-500" />
                <span class="text-sm font-medium text-slate-700 dark:text-slate-300">
                  {{ uploadedFile.name }}
                </span>
              </div>
              <div class="flex justify-center gap-2">
                <button
                  type="button"
                  @click.stop="clearUpload"
                  class="text-sm text-red-600 hover:text-red-700 dark:text-red-400 dark:hover:text-red-300 font-medium"
                >
                  Remover
                </button>
              </div>
            </div>

            <!-- Estado: Inicial (sem arquivo) -->
            <div v-else class="space-y-3">
              <fluent-icon icon="arrow-upload" size="40" class="text-slate-400 mx-auto" />
              <div>
                <p class="text-sm font-medium text-slate-600 dark:text-slate-400">
                  Clique ou arraste um arquivo aqui
                </p>
                <p class="text-xs text-slate-500 dark:text-slate-500 mt-1">
                  Imagens: PNG, JPG, GIF, WEBP
                </p>
                <p class="text-xs text-slate-500 dark:text-slate-500">
                  Vídeos: MP4, WEBM (máx. 10MB)
                </p>
              </div>
            </div>
          </div>

          <!-- Input file oculto -->
          <input
            ref="fileInput"
            type="file"
            accept="image/png,image/jpeg,image/gif,image/webp,video/mp4,video/webm"
            @change="handleFileSelect"
            class="hidden"
          />

          <!-- Dica -->
          <div class="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-md p-2">
            <p class="text-xs text-blue-700 dark:text-blue-300 flex items-start gap-2">
              <fluent-icon icon="info" size="14" class="mt-0.5 flex-shrink-0" />
              <span>
                <strong>Dica:</strong> Faça upload de um novo arquivo para substituir a mídia atual.
              </span>
            </p>
          </div>
        </div>

      </div>

      <!-- Público-alvo -->
      <div class="w-full mb-4">
        <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
          Quem deve ver? *
        </label>
        <div class="space-y-2">
          <label class="inline-flex items-center">
            <input
              type="checkbox"
              v-model="form.target_roles"
              value="administrator"
              class="rounded border-slate-300 text-woot-500 shadow-sm focus:border-woot-300 focus:ring focus:ring-woot-200 focus:ring-opacity-50 dark:bg-slate-700 dark:border-slate-600"
            />
            <span class="ml-2 text-sm text-slate-700 dark:text-slate-300">Administradores</span>
          </label>
          <label class="inline-flex items-center ml-4">
            <input
              type="checkbox"
              v-model="form.target_roles"
              value="agent"
              class="rounded border-slate-300 text-woot-500 shadow-sm focus:border-woot-300 focus:ring focus:ring-woot-200 focus:ring-opacity-50 dark:bg-slate-700 dark:border-slate-600"
            />
            <span class="ml-2 text-sm text-slate-700 dark:text-slate-300">Atendentes</span>
          </label>
        </div>
      </div>

      <!-- Agendamento e Expiração -->
      <div class="w-full mb-4">
        <div class="grid grid-cols-2 gap-4">
          <!-- Agendamento -->
          <div>
            <label class="inline-flex items-center mb-2">
              <input
                type="checkbox"
                v-model="form.hasScheduled"
                class="rounded-lg border-slate-300 text-woot-500 shadow-soft focus:border-woot-300 focus:ring focus:ring-woot-200 focus:ring-opacity-50 dark:bg-slate-700 dark:border-slate-600 transition-all duration-150 ease-smooth"
              />
              <span class="ml-2 text-sm font-medium text-slate-700 dark:text-slate-300">
                📅 Agendar publicação
              </span>
            </label>
            <div v-if="form.hasScheduled" class="mt-2">
              <input
                v-model="form.scheduled_at"
                type="datetime-local"
                class="w-full rounded-md border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100 px-3 py-2"
              />
              <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">
                O anúncio só ficará visível a partir desta data/hora
              </p>
            </div>
          </div>

          <!-- Expiração -->
          <div>
            <label class="inline-flex items-center mb-2">
              <input
                type="checkbox"
                v-model="form.hasExpires"
                class="rounded-lg border-slate-300 text-woot-500 shadow-soft focus:border-woot-300 focus:ring focus:ring-woot-200 focus:ring-opacity-50 dark:bg-slate-700 dark:border-slate-600 transition-all duration-150 ease-smooth"
              />
              <span class="ml-2 text-sm font-medium text-slate-700 dark:text-slate-300">
                ⏰ Expirar automaticamente
              </span>
            </label>
            <div v-if="form.hasExpires" class="mt-2">
              <input
                v-model="form.expires_at"
                type="datetime-local"
                class="w-full rounded-md border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100 px-3 py-2"
              />
              <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">
                O anúncio será desativado automaticamente nesta data/hora
              </p>
            </div>
          </div>
        </div>
      </div>

      <!-- Botão de Ação (CTA) -->
      <div class="w-full mb-4">
        <label class="inline-flex items-center mb-3">
          <input
            type="checkbox"
            v-model="form.hasCta"
            class="rounded border-slate-300 text-woot-500 shadow-sm focus:border-woot-300 focus:ring focus:ring-woot-200 focus:ring-opacity-50 dark:bg-slate-700 dark:border-slate-600"
          />
          <span class="ml-2 text-sm font-medium text-slate-700 dark:text-slate-300">
            Adicionar botão de ação (CTA)
          </span>
        </label>
        <div v-if="form.hasCta" class="mt-3">
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-sm text-slate-600 dark:text-slate-400 mb-1">
                Texto do botão *
              </label>
              <input
                v-model.trim="form.cta_text"
                type="text"
                placeholder="Ex: Ver mais, Experimentar, Saiba mais"
                class="w-full rounded-md border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100 px-3 py-2"
              />
            </div>
            <div>
              <label class="block text-sm text-slate-600 dark:text-slate-400 mb-1">
                Link do botão (URL) *
              </label>
              <input
                v-model.trim="form.cta_url"
                type="url"
                placeholder="https://exemplo.com"
                class="w-full rounded-md border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100 px-3 py-2"
              />
            </div>
          </div>
        </div>
      </div>

      <!-- Badge de Urgência -->
      <div class="w-full mb-4">
        <label class="inline-flex items-center mb-3">
          <input
            type="checkbox"
            v-model="form.hasBadge"
            class="rounded border-slate-300 text-woot-500 shadow-sm focus:border-woot-300 focus:ring focus:ring-woot-200 focus:ring-opacity-50 dark:bg-slate-700 dark:border-slate-600"
          />
          <span class="ml-2 text-sm font-medium text-slate-700 dark:text-slate-300">
            Adicionar badge de urgência
          </span>
        </label>
        <div v-if="form.hasBadge" class="mt-3">
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-sm text-slate-600 dark:text-slate-400 mb-1">
                Texto do badge *
              </label>
              <input
                v-model.trim="form.badge_text"
                type="text"
                placeholder="Ex: Importante, Novo, Urgente"
                class="w-full rounded-md border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100 px-3 py-2"
              />
            </div>
            <div>
              <label class="block text-sm text-slate-600 dark:text-slate-400 mb-1">
                Cor do badge *
              </label>
              <select
                v-model="form.badge_color"
                class="w-full rounded-md border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100 px-3 py-2"
              >
                <option value="blue">Azul</option>
                <option value="green">Verde</option>
                <option value="yellow">Amarelo</option>
                <option value="red">Vermelho</option>
                <option value="purple">Roxo</option>
              </select>
            </div>
          </div>
        </div>
      </div>

          <!-- Botões -->
          <div class="flex items-center justify-end w-full gap-2 px-0 py-2">
            <woot-button class="button clear" @click.prevent="onClose">
              Cancelar
            </woot-button>
            <woot-button :is-loading="isUpdating">
              Atualizar Anúncio
            </woot-button>
          </div>
        </form>
      </div>

      <!-- Coluna Direita: Preview -->
      <div class="overflow-y-auto bg-slate-50 dark:bg-slate-900 p-4 border-l border-slate-200 dark:border-slate-700">
        <div class="sticky top-0 flex flex-col items-center">
          <h3 class="text-xs font-semibold text-slate-600 dark:text-slate-400 mb-3 uppercase w-full text-center">Preview</h3>
          <div class="scale-75 origin-top">
            <announcement-preview :announcement="previewData" />
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import AnnouncementsAPI from 'dashboard/api/announcements';
import { useAlert } from 'dashboard/composables';
import AnnouncementPreview from './AnnouncementPreview.vue';

export default {
  components: {
    AnnouncementPreview,
  },
  props: {
    announcement: { type: Object, required: true },
  },
  data() {
    return {
      form: {
        id: this.announcement.id,
        title_pt_BR: this.announcement.title.pt_BR || '',
        title_en: this.announcement.title.en || '',
        title_es: this.announcement.title.es || '',
        title_pt: this.announcement.title.pt || '',
        description_pt_BR: this.announcement.description.pt_BR || '',
        description_en: this.announcement.description.en || '',
        description_es: this.announcement.description.es || '',
        description_pt: this.announcement.description.pt || '',
        media_url: this.announcement.media_url || '',
        target_roles: [...this.announcement.target_roles],
        active: this.announcement.active,
        // 🆕 Agendamento e Expiração
        hasScheduled: !!this.announcement.scheduled_at,
        scheduled_at: this.formatDateTimeLocal(this.announcement.scheduled_at),
        hasExpires: !!this.announcement.expires_at,
        expires_at: this.formatDateTimeLocal(this.announcement.expires_at),
        // 🆕 CTA
        hasCta: !!(this.announcement.cta_text && this.announcement.cta_url),
        cta_text: this.announcement.cta_text || '',
        cta_url: this.announcement.cta_url || '',
        // 🆕 Badge
        hasBadge: !!(this.announcement.badge_text && this.announcement.badge_color),
        badge_text: this.announcement.badge_text || '',
        badge_color: this.announcement.badge_color || 'blue',
      },
      showTranslations: false,
      isUpdating: false,
      // 🆕 Upload de mídia
      mediaType: 'url', // 'url' ou 'upload'
      uploadedFile: null,
      isUploading: false,
      isDragging: false,
    };
  },
  
  computed: {
    // 🆕 URL de preview da mídia
    previewUrl() {
      if (this.mediaType === 'url' && this.form.media_url) {
        return this.form.media_url;
      }
      if (this.mediaType === 'upload' && this.uploadedFile) {
        return this.uploadedFile.preview;
      }
      return null;
    },

    // 🆕 Detectar se é imagem
    isImage() {
      if (!this.previewUrl) return false;
      const imageExtensions = ['.png', '.jpg', '.jpeg', '.gif', '.webp'];
      return imageExtensions.some(ext => this.previewUrl.toLowerCase().includes(ext));
    },

    // 🆕 Detectar se é vídeo
    isVideo() {
      if (!this.previewUrl) return false;
      const videoExtensions = ['.mp4', '.webm', '.mov'];
      return videoExtensions.some(ext => this.previewUrl.toLowerCase().includes(ext));
    },

    // Dados para preview em tempo real
    previewData() {
      return {
        id: this.form.id,
        title: {
          pt_BR: this.form.title_pt_BR || 'Título do anúncio',
        },
        description: {
          pt_BR: this.form.description_pt_BR || 'Descrição do anúncio aparecerá aqui...',
        },
        media_url: this.form.media_url || null,
        badge_text: this.form.hasBadge ? this.form.badge_text : null,
        badge_color: this.form.hasBadge ? this.form.badge_color : null,
        cta_text: this.form.hasCta ? this.form.cta_text : null,
        cta_url: this.form.hasCta ? this.form.cta_url : null,
        active: this.form.active,
      };
    },
  },
  methods: {
    async updateAnnouncement() {
      this.isUpdating = true;
      try {
        // Validar se escolheu upload mas não fez upload
        if (this.mediaType === 'upload' && !this.form.media_url && !this.announcement.media_url) {
          throw new Error('Por favor, faça upload de um arquivo ou escolha a opção URL.');
        }

        // Preparar dados para envio (remover flags internas)
        const payload = { ...this.form };
        
        // Agendamento
        if (!payload.hasScheduled) {
          delete payload.scheduled_at;
        }
        delete payload.hasScheduled;
        
        // Expiração
        if (!payload.hasExpires) {
          delete payload.expires_at;
        }
        delete payload.hasExpires;
        
        // CTA
        if (!payload.hasCta) {
          delete payload.cta_text;
          delete payload.cta_url;
        }
        delete payload.hasCta;
        
        // Badge
        if (!payload.hasBadge) {
          delete payload.badge_text;
          delete payload.badge_color;
        }
        delete payload.hasBadge;

        // Remover campos vazios opcionais
        if (!payload.scheduled_at) delete payload.scheduled_at;
        if (!payload.expires_at) delete payload.expires_at;
        if (!payload.cta_text) delete payload.cta_text;
        if (!payload.cta_url) delete payload.cta_url;
        if (!payload.badge_text) delete payload.badge_text;
        if (!payload.badge_color) delete payload.badge_color;

        await AnnouncementsAPI.update(this.form.id, payload);
        useAlert('Anúncio atualizado com sucesso!');
        this.$emit('announcement-updated');
        this.onClose();
      } catch (error) {
        useAlert(error.message || 'Erro ao atualizar anúncio');
      } finally {
        this.isUpdating = false;
      }
    },

    // 🆕 Manipulador de seleção de arquivo (input)
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

    // 🆕 Upload do arquivo para o servidor
    async uploadFile(file) {
      // Validar tipo de arquivo
      const validTypes = [
        'image/png', 
        'image/jpeg', 
        'image/gif', 
        'image/webp',
        'video/mp4',
        'video/webm'
      ];
      
      if (!validTypes.includes(file.type)) {
        useAlert('Tipo de arquivo inválido. Use PNG, JPG, GIF, WEBP, MP4 ou WEBM.');
        return;
      }

      // Validar tamanho (10MB)
      const maxSize = 10 * 1024 * 1024; // 10MB
      if (file.size > maxSize) {
        useAlert('Arquivo muito grande. Máximo: 10MB.');
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
          type: file.type,
          preview: URL.createObjectURL(file),
          url: response.data.file_url,
        };

        useAlert('Upload concluído com sucesso!');
      } catch (error) {
        console.error('Upload error:', error);
        useAlert('Erro ao fazer upload. Tente novamente.');
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

    // Converter ISO 8601 para formato datetime-local do input HTML
    formatDateTimeLocal(isoString) {
      if (!isoString) return '';
      
      try {
        const date = new Date(isoString);
        // Formato: YYYY-MM-DDTHH:mm
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const day = String(date.getDate()).padStart(2, '0');
        const hours = String(date.getHours()).padStart(2, '0');
        const minutes = String(date.getMinutes()).padStart(2, '0');
        
        return `${year}-${month}-${day}T${hours}:${minutes}`;
      } catch (e) {
        return '';
      }
    },
  },
};
</script>

<style scoped>
.announcement-form-modal {
  @apply flex flex-col h-auto;
}

.announcement-form-modal :deep(.modal-container) {
  max-width: 95vw !important;
  width: 90rem !important;
}
</style>
