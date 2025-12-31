<template>
  <transition name="fade">
    <div v-if="show && current" class="announcement-overlay">
      <div class="announcement-card">
        <!-- Close Button -->
        <button class="close-btn" @click="dismiss" aria-label="Fechar anúncio">
          <fluent-icon icon="dismiss" size="20" />
        </button>

        <!-- Badge de Urgência -->
        <div v-if="current.badge_text && current.badge_color" class="badge-container">
          <span 
            class="badge"
            :class="badgeClass"
          >
            {{ current.badge_text }}
          </span>
        </div>

        <!-- Media -->
        <div v-if="current.media_url" class="media-container">
          <!-- Imagem/GIF -->
          <img 
            v-if="isImage(current.media_url)"
            :src="current.media_url" 
            :alt="current.title"
            class="media-image"
          />
          <!-- Vídeo -->
          <video 
            v-else-if="isVideo(current.media_url)"
            :src="current.media_url"
            controls
            autoplay
            muted
            loop
            class="media-video"
          >
            Seu navegador não suporta vídeo.
          </video>
        </div>

        <!-- Content -->
        <div class="content">
          <h2 class="announcement-title">{{ current.title }}</h2>
          <div class="announcement-description">
            <div 
              v-if="!isExpanded && isLongDescription"
              class="description-preview"
            >
              <span v-html="formattedDescriptionPreview"></span>
              <button 
                @click="toggleExpand"
                class="read-more-btn"
              >
                Ler mais
              </button>
            </div>
            <div 
              v-else-if="isLongDescription"
              class="description-full"
            >
              <span v-html="formattedDescription"></span>
              <button 
                @click="toggleExpand"
                class="read-more-btn"
              >
                Ler menos
              </button>
            </div>
            <div 
              v-else
              class="description-full"
            >
              <span v-html="formattedDescription"></span>
            </div>
          </div>
        </div>

        <!-- CTA Button -->
        <div v-if="current.cta_text && current.cta_url" class="cta-container">
          <a 
            :href="current.cta_url"
            target="_blank"
            rel="noopener noreferrer"
            class="cta-button"
          >
            {{ current.cta_text }}
            <fluent-icon icon="arrow-right" size="14" class="ml-1" />
          </a>
        </div>

        <!-- Actions -->
        <div class="actions">
          <button v-if="hasNext" @click="next" class="btn-next">
            Próximo ({{ remaining }})
          </button>
          <button v-if="!current.cta_text || !current.cta_url" @click="dismissAll" class="btn-primary">
            Entendi ✓
          </button>
        </div>

        <!-- Progress -->
        <div v-if="total > 1" class="progress">
          <span>{{ currentIndex + 1 }} / {{ total }}</span>
        </div>
      </div>
    </div>
  </transition>
</template>
<script>
/* global axios */
import { LocalStorage } from 'shared/helpers/localStorage';
import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';
import { mapGetters } from 'vuex';

export default {
  data() {
    return {
      show: false,
      announcements: [],
      currentIndex: 0,
      isExpanded: false,
    };
  },

  computed: {
    ...mapGetters({
      currentUser: 'getCurrentUser',
      currentLocale: 'getCurrentAccountLocale',
      accountId: 'getCurrentAccountId', // 🆕 Account ID do Vuex
    }),

    current() {
      const announcement = this.announcements[this.currentIndex];
      if (!announcement) return null;

      return {
        ...announcement,
        title: announcement.title[this.currentLocale] || announcement.title.pt_BR || announcement.title.en,
        description: announcement.description[this.currentLocale] || announcement.description.pt_BR || announcement.description.en,
      };
    },

    // Processar descrição com links e quebra de linha
    formattedDescription() {
      if (!this.current || !this.current.description) return '';
      return this.processDescription(this.current.description);
    },

    formattedDescriptionPreview() {
      if (!this.current || !this.current.description) return '';
      const preview = this.current.description.substring(0, 300);
      return this.processDescription(preview);
    },

    isLongDescription() {
      if (!this.current || !this.current.description) return false;
      return this.current.description.length > 300 || this.current.description.split('\n').length > 5;
    },

    // Classes CSS para badge
    badgeClass() {
      if (!this.current || !this.current.badge_color) return '';
      const color = this.current.badge_color;
      return `badge-${color}`;
    },

    hasNext() {
      return this.currentIndex < this.announcements.length - 1;
    },

    remaining() {
      return this.announcements.length - this.currentIndex - 1;
    },

    total() {
      return this.announcements.length;
    },
  },

  mounted() {
    // 🆕 Aguardar usuário e account estarem disponíveis antes de carregar
    this.$nextTick(() => {
      // Pequeno delay para garantir que tudo foi carregado
      setTimeout(() => {
        this.load();
      }, 1000); // 1 segundo após página carregar
    });
  },

  methods: {
    async load() {
      try {
        // ✅ Verificar se currentUser e accountId estão disponíveis
        if (!this.currentUser || !this.currentUser.role || !this.accountId) {
          // Tentar novamente em 2 segundos
          setTimeout(() => this.load(), 2000);
          return;
        }

        const response = await axios.get(`/api/v1/accounts/${this.accountId}/announcements/data`);
        const data = response.data;
        
        const dismissed = this.getDismissed();
        const userRole = this.currentUser.role;

        this.announcements = (data.announcements || [])
          .filter(a => a.active)
          .filter(a => {
            // Criar chave única: ID + data de publicação
            const uniqueKey = `${a.id}_${a.published_at}`;
            return !dismissed.includes(uniqueKey);
          })
          .filter(a => a.target_roles.includes(userRole));

        if (this.announcements.length > 0) {
          this.show = true;
        }
      } catch (error) {
        console.error('❌ Failed to load announcements:', error);
      }
    },

    getDismissed() {
      return LocalStorage.get(LOCAL_STORAGE_KEYS.DISMISSED_ANNOUNCEMENTS) || [];
    },

    saveDismissed(ids) {
      LocalStorage.set(LOCAL_STORAGE_KEYS.DISMISSED_ANNOUNCEMENTS, ids);
    },

    dismiss() {
      const dismissed = this.getDismissed();
      // Usar chave única: ID + data de publicação
      const uniqueKey = `${this.current.id}_${this.announcements[this.currentIndex].published_at}`;
      dismissed.push(uniqueKey);
      this.saveDismissed(dismissed);

      if (this.hasNext) {
        this.currentIndex++;
      } else {
        this.show = false;
      }
    },

    dismissAll() {
      const dismissed = this.getDismissed();
      // Usar chaves únicas para todos os anúncios
      const allUniqueKeys = this.announcements.map(a => `${a.id}_${a.published_at}`);
      this.saveDismissed([...dismissed, ...allUniqueKeys]);
      this.show = false;
    },

    next() {
      if (this.hasNext) {
        this.currentIndex++;
      }
    },

    // 🆕 Detectar se é imagem
    isImage(url) {
      if (!url) return false;
      const imageExtensions = ['.png', '.jpg', '.jpeg', '.gif', '.webp'];
      return imageExtensions.some(ext => url.toLowerCase().includes(ext));
    },

    // 🆕 Detectar se é vídeo
    isVideo(url) {
      if (!url) return false;
      const videoExtensions = ['.mp4', '.webm', '.mov'];
      return videoExtensions.some(ext => url.toLowerCase().includes(ext));
    },

    // Processar descrição: detectar links e preservar quebras de linha
    processDescription(text) {
      if (!text) return '';
      
      // Escapar HTML para segurança
      let processed = text
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;');

      // Detectar URLs e torná-las clicáveis
      const urlRegex = /(https?:\/\/[^\s]+)/g;
      processed = processed.replace(urlRegex, '<a href="$1" target="_blank" rel="noopener noreferrer" class="announcement-link">$1</a>');

      // Converter quebras de linha em <br>
      processed = processed.replace(/\n/g, '<br>');

      return processed;
    },

    toggleExpand() {
      this.isExpanded = !this.isExpanded;
    },
  },

  watch: {
    currentIndex() {
      // Resetar estado de expansão ao mudar de anúncio
      this.isExpanded = false;
    },
  },
};
</script>

<style lang="scss" scoped>
.announcement-overlay {
  @apply fixed inset-0 z-[9999] flex items-center justify-center;
  background-color: rgba(0, 0, 0, 0.5);
}

.announcement-card {
  @apply relative bg-white dark:bg-slate-800 rounded-2xl shadow-soft-xl max-w-2xl w-full mx-4 animate-scale-in;
  max-height: 90vh;
  display: flex;
  flex-direction: column;
}

.badge-container {
  @apply absolute top-4 left-4 z-10;
}

.badge {
  @apply inline-flex items-center px-3 py-1 rounded-full text-xs font-semibold uppercase tracking-wide;
  
  &.badge-blue {
    @apply bg-sky-100 text-sky-900 dark:bg-sky-700 dark:text-sky-100;
  }
  
  &.badge-green {
    @apply bg-green-100 text-green-900 dark:bg-green-700 dark:text-green-100;
  }
  
  &.badge-yellow {
    @apply bg-yellow-100 text-yellow-900 dark:bg-yellow-700 dark:text-yellow-100;
  }
  
  &.badge-red {
    @apply bg-red-100 text-red-900 dark:bg-red-700 dark:text-red-100;
  }
  
  &.badge-purple {
    @apply bg-violet-100 text-violet-900 dark:bg-violet-700 dark:text-violet-100;
  }
}

.close-btn {
  @apply absolute top-4 right-4 z-10 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 p-1 rounded-full hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors;
}

.media-container {
  @apply w-full bg-slate-100 dark:bg-slate-900 flex items-center justify-center;
  max-height: 400px;
  min-height: 200px;
  overflow: hidden;
  flex-shrink: 0;
  
  .media-image {
    @apply w-full h-full object-cover;
    max-height: 400px;
  }
  
  .media-video {
    @apply w-full h-full object-contain;
    max-height: 400px;
  }
}

.content {
  @apply p-6;
  flex: 1;
  min-height: 120px;
}

.announcement-title {
  @apply text-2xl font-bold text-slate-900 dark:text-slate-100 mb-4;
  line-height: 1.3;
}

.announcement-description {
  @apply text-slate-700 dark:text-slate-300 leading-relaxed;
  white-space: pre-wrap;
  word-wrap: break-word;
}

.description-preview,
.description-full {
  @apply text-base;
  
  .read-more-btn {
    @apply ml-2 text-sm font-medium text-woot-500 hover:text-woot-600 dark:text-white dark:hover:text-slate-200 transition-colors underline;
    cursor: pointer;
    display: inline;
    background: none;
    border: none;
    padding: 0;
  }
}

.announcement-link {
  @apply text-woot-500 hover:text-woot-600 dark:text-woot-400 dark:hover:text-woot-300 underline;
  word-break: break-all;
}

.cta-container {
  @apply px-6 pb-4;
  flex-shrink: 0;
}

.cta-button {
  @apply inline-flex items-center justify-center w-full px-4 py-2.5 text-sm font-semibold text-white bg-green-500 hover:bg-green-600 dark:bg-green-600 dark:hover:bg-green-700 rounded-lg transition-all duration-200 ease-smooth;
  text-decoration: none;
}

.actions {
  @apply px-6 pb-4 flex gap-3 justify-end; /* Reduzido padding */
  flex-shrink: 0; /* Não encolhe */
}

.btn-primary {
  @apply inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-lg text-white bg-woot-500 hover:bg-woot-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-woot-500 transition-all duration-200 ease-smooth;
}

.btn-next {
  @apply inline-flex items-center px-4 py-2 border border-slate-300 text-sm font-medium rounded-lg text-slate-700 bg-white hover:bg-slate-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-woot-500 transition-all duration-200 ease-smooth;
}

.progress {
  @apply px-8 pb-4 text-center text-sm text-slate-500;
}

.fade-enter-active, .fade-leave-active {
  transition: opacity 0.3s ease;
}

.fade-enter-from, .fade-leave-to {
  opacity: 0;
}
</style>
