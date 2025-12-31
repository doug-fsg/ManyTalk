<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header header-title="Preview do Anúncio" header-content="Visualize como ficará o anúncio" />
    <div v-if="announcement" class="p-8">
      <div class="bg-white dark:bg-slate-800 rounded-xl shadow-soft-xl overflow-hidden border-2 border-slate-200 dark:border-slate-700">
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
            class="w-full h-full object-contain" 
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
        <div class="p-8">
          <h2 class="text-2xl font-bold text-slate-900 dark:text-slate-100 mb-4 leading-tight">
            {{ announcement.title.pt_BR }}
          </h2>
          <div 
            class="text-slate-700 dark:text-slate-300 leading-relaxed text-base whitespace-pre-wrap"
            v-html="formattedDescription"
          ></div>
        </div>

        <!-- CTA Button -->
        <div v-if="announcement.cta_text && announcement.cta_url" class="px-8 pb-4">
          <a 
            :href="announcement.cta_url"
            target="_blank"
            rel="noopener noreferrer"
            class="inline-flex items-center justify-center w-full px-4 py-2.5 text-sm font-semibold text-white bg-woot-500 hover:bg-woot-600 dark:bg-woot-600 dark:hover:bg-woot-700 rounded-lg transition-all duration-200 ease-smooth"
          >
            {{ announcement.cta_text }}
            <fluent-icon icon="arrow-right" size="14" class="ml-1" />
          </a>
        </div>

        <!-- Actions -->
        <div class="px-8 pb-6 flex gap-3 justify-end">
          <button class="px-4 py-2 border border-slate-300 dark:border-slate-600 text-sm font-medium rounded-lg text-slate-700 dark:text-slate-300 bg-white dark:bg-slate-700 hover:bg-slate-50 dark:hover:bg-slate-600 transition-all duration-200 ease-smooth">
            Próximo (1)
          </button>
          <button class="px-4 py-2 text-sm font-medium rounded-lg text-white bg-woot-500 hover:bg-woot-600 transition-all duration-200 ease-smooth">
            Entendi ✓
          </button>
        </div>
      </div>

      <!-- Informações -->
      <div class="mt-6 p-4 bg-blue-50 dark:bg-blue-900/20 rounded-xl shadow-soft">
        <h4 class="text-sm font-medium mb-2 text-slate-900 dark:text-slate-100">ℹ️ Informações</h4>
        <div class="text-sm space-y-1 text-slate-700 dark:text-slate-300">
          <p><strong>ID:</strong> {{ announcement.id }}</p>
          <p><strong>Status:</strong> {{ announcement.active ? 'Ativo' : 'Inativo' }}</p>
          <p><strong>Público:</strong> {{ announcement.target_roles.join(', ') }}</p>
          <p v-if="announcement.badge_text">
            <strong>Badge:</strong> {{ announcement.badge_text }} 
            <span class="text-xs">({{ announcement.badge_color }})</span>
          </p>
          <p v-if="announcement.cta_text">
            <strong>CTA:</strong> {{ announcement.cta_text }} → 
            <a :href="announcement.cta_url" target="_blank" class="text-woot-500 hover:underline">
              {{ announcement.cta_url }}
            </a>
          </p>
        </div>
      </div>

      <div class="flex justify-end mt-4">
        <woot-button class="button clear" @click.prevent="onClose">Fechar</woot-button>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  props: { announcement: { type: Object, required: true } },
  
  computed: {
    formattedDescription() {
      if (!this.announcement || !this.announcement.description) return '';
      const desc = this.announcement.description.pt_BR || '';
      
      // Escapar HTML para segurança
      let processed = desc
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
    onClose() {
      this.$emit('close');
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
