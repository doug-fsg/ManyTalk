<template>
  <transition name="fade">
    <div v-if="show && current" class="announcement-overlay">
      <div class="announcement-card">
        <!-- Close Button -->
        <button class="close-btn" @click="dismiss">
          <fluent-icon icon="dismiss" size="20" />
        </button>

        <!-- Media -->
        <div v-if="current.media_url" class="media-container">
          <!-- Imagem/GIF -->
          <img 
            v-if="isImage(current.media_url)"
            :src="current.media_url" 
            :alt="current.title"
          />
          <!-- Vídeo -->
          <video 
            v-else-if="isVideo(current.media_url)"
            :src="current.media_url"
            controls
            autoplay
            muted
            loop
          >
            Seu navegador não suporta vídeo.
          </video>
        </div>

        <!-- Content -->
        <div class="content">
          <h2>{{ current.title }}</h2>
          <p>{{ current.description }}</p>
        </div>

        <!-- Actions -->
        <div class="actions">
          <button v-if="hasNext" @click="next" class="btn-next">
            Próximo ({{ remaining }})
          </button>
          <button @click="dismissAll" class="btn-primary">
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
  },
};
</script>

<style lang="scss" scoped>
.announcement-overlay {
  @apply fixed inset-0 z-[9999] flex items-center justify-center;
  background-color: rgba(0, 0, 0, 0.5);
}

.announcement-card {
  @apply relative bg-white dark:bg-slate-800 rounded-lg shadow-2xl max-w-2xl w-full mx-4;
  max-height: 90vh;
  display: flex;
  flex-direction: column;
}

.close-btn {
  @apply absolute top-4 right-4 z-10 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 p-1 rounded-full hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors;
}

.media-container {
  @apply w-full bg-slate-100 dark:bg-slate-900 flex items-center justify-center;
  max-height: 300px; /* Reduzido para dar mais espaço ao conteúdo */
  min-height: 150px; /* Reduzido */
  overflow: hidden;
  flex-shrink: 0; /* Não encolhe */
  
  img, video {
    @apply w-full h-auto object-contain;
    max-height: 300px; /* Reduzido */
  }
}

.content {
  @apply p-6; /* Reduzido padding */
  flex: 1;
  min-height: 120px; /* Garante espaço mínimo para título e descrição */
  
  h2 {
    @apply text-xl font-bold text-slate-900 dark:text-slate-100 mb-3; /* Reduzido */
  }
  
  p {
    @apply text-slate-600 dark:text-slate-400 leading-relaxed text-sm; /* Texto menor */
  }
}

.actions {
  @apply px-6 pb-4 flex gap-3 justify-end; /* Reduzido padding */
  flex-shrink: 0; /* Não encolhe */
}

.btn-primary {
  @apply inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-woot-500 hover:bg-woot-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-woot-500 transition-colors;
}

.btn-next {
  @apply inline-flex items-center px-4 py-2 border border-slate-300 text-sm font-medium rounded-md text-slate-700 bg-white hover:bg-slate-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-woot-500 transition-colors;
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
