<template>
  <div class="announcement-preview">
    <div class="bg-white dark:bg-slate-800 rounded-xl shadow-soft-xl overflow-hidden border-2 border-slate-200 dark:border-slate-700 max-w-md mx-auto">
      <!-- Badge -->
      <div v-if="announcement.badge_text && announcement.badge_color" class="relative">
        <span 
          class="absolute top-4 left-4 z-10 inline-flex items-center px-3 py-1 rounded-full text-xs font-semibold uppercase"
          :class="previewBadgeClass"
        >
          {{ announcement.badge_text }}
        </span>
      </div>

      <!-- Media -->
      <div v-if="announcement.media_url" class="w-full bg-slate-100 dark:bg-slate-900" style="aspect-ratio: 16/9; max-height: 300px;">
        <img 
          v-if="isImage(announcement.media_url)"
          :src="announcement.media_url" 
          :alt="announcement.title.pt_BR" 
          class="w-full h-full object-cover" 
        />
        <video 
          v-else-if="isVideo(announcement.media_url)"
          :src="announcement.media_url"
          controls
          class="w-full h-full object-contain"
        >
          Seu navegador não suporta vídeo.
        </video>
      </div>

      <!-- Content -->
      <div class="p-6">
        <h2 class="text-2xl font-bold text-slate-900 dark:text-slate-100 mb-4 leading-tight">
          {{ announcement.title.pt_BR }}
        </h2>
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
      <div v-if="announcement.cta_text && announcement.cta_url" class="px-6 pb-4">
        <a 
          :href="announcement.cta_url"
          target="_blank"
          rel="noopener noreferrer"
          class="inline-flex items-center justify-center w-full px-4 py-2.5 text-sm font-semibold text-white bg-green-500 hover:bg-green-600 dark:bg-green-600 dark:hover:bg-green-700 rounded-lg transition-all duration-200 ease-smooth"
        >
          {{ announcement.cta_text }}
          <fluent-icon icon="arrow-right" size="14" class="ml-1" />
        </a>
      </div>

      <!-- Actions -->
      <div class="px-6 pb-6 flex gap-3 justify-end">
        <button v-if="!announcement.cta_text || !announcement.cta_url" class="px-4 py-2 text-sm font-medium rounded-lg text-white bg-woot-500 hover:bg-woot-600 transition-all duration-200 ease-smooth">
          Entendi ✓
        </button>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  props: { 
    announcement: { 
      type: Object, 
      required: true 
    } 
  },
  
  data() {
    return {
      isExpanded: false,
    };
  },
  
  computed: {
    formattedDescription() {
      if (!this.announcement || !this.announcement.description) return '';
      const desc = this.announcement.description.pt_BR || '';
      return this.processDescription(desc);
    },

    formattedDescriptionPreview() {
      if (!this.announcement || !this.announcement.description) return '';
      const desc = this.announcement.description.pt_BR || '';
      const preview = desc.substring(0, 300);
      return this.processDescription(preview);
    },

    isLongDescription() {
      if (!this.announcement || !this.announcement.description) return false;
      const desc = this.announcement.description.pt_BR || '';
      return desc.length > 300 || desc.split('\n').length > 5;
    },

    previewBadgeClass() {
      if (!this.announcement || !this.announcement.badge_color) return '';
      const color = this.announcement.badge_color;
      const classes = {
        blue: 'bg-sky-100 text-sky-900 dark:bg-sky-700 dark:text-sky-100',
        green: 'bg-green-100 text-green-900 dark:bg-green-700 dark:text-green-100',
        yellow: 'bg-yellow-100 text-yellow-900 dark:bg-yellow-700 dark:text-yellow-100',
        red: 'bg-red-100 text-red-900 dark:bg-red-700 dark:text-red-100',
        purple: 'bg-violet-100 text-violet-900 dark:bg-violet-700 dark:text-violet-100',
      };
      return classes[color] || classes.blue;
    },
  },

  methods: {
    processDescription(text) {
      if (!text) return '';
      
      // Escapar HTML para segurança
      let processed = text
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;');

      // Detectar URLs e torná-las clicáveis
      const urlRegex = /(https?:\/\/[^\s]+)/g;
      processed = processed.replace(urlRegex, '<a href="$1" target="_blank" rel="noopener noreferrer" class="text-woot-500 hover:text-woot-600 dark:text-woot-400 dark:hover:text-woot-300 underline">$1</a>');

      // Converter quebras de linha em <br>
      processed = processed.replace(/\n/g, '<br>');

      return processed;
    },

    toggleExpand() {
      this.isExpanded = !this.isExpanded;
    },

    isImage(url) {
      if (!url) return false;
      const imageExtensions = ['.png', '.jpg', '.jpeg', '.gif', '.webp'];
      return imageExtensions.some(ext => url.toLowerCase().includes(ext));
    },

    isVideo(url) {
      if (!url) return false;
      const videoExtensions = ['.mp4', '.webm', '.mov'];
      return videoExtensions.some(ext => url.toLowerCase().includes(ext));
    },
  },
};
</script>

<style scoped lang="scss">
.announcement-preview {
  @apply w-full;
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
</style>

