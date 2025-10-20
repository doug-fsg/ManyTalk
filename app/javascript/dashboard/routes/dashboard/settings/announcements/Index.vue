<template>
  <div class="flex-1 overflow-auto">
    <woot-button
      color-scheme="success"
      class-names="button--fixed-top"
      icon="add-circle"
      @click="openAddPopup"
    >
      Novo Anúncio
    </woot-button>

    <div class="flex flex-row gap-4 p-8">
      <div class="w-full">
        <p
          v-if="!uiFlags.isFetching && !announcements.length"
          class="flex flex-col items-center justify-center h-full text-slate-500"
        >
          Nenhum anúncio criado ainda
        </p>

        <woot-loading-state
          v-if="uiFlags.isFetching"
          message="Carregando anúncios..."
        />

        <table v-if="!uiFlags.isFetching && announcements.length" class="woot-table">
          <thead>
            <th>Título</th>
            <th>Descrição</th>
            <th>Público</th>
            <th>Status</th>
            <th>Data</th>
            <th>Ações</th>
          </thead>
          <tbody>
            <tr v-for="announcement in announcements" :key="announcement.id">
              <td>
                <strong>{{ announcement.title.pt_BR }}</strong>
                <br />
                <small class="text-slate-500">{{ announcement.title.en }}</small>
              </td>
              <td class="max-w-xs">
                <div class="truncate">
                  {{ announcement.description.pt_BR }}
                </div>
              </td>
              <td>
                <div class="flex gap-1">
                  <span
                    v-for="role in announcement.target_roles"
                    :key="role"
                    class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-slate-100 text-slate-700 dark:bg-slate-700 dark:text-slate-300"
                  >
                    {{ role === 'administrator' ? 'Admin' : 'Agente' }}
                  </span>
                </div>
              </td>
              <td>
                <div class="flex flex-col gap-1">
                  <span
                    class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium"
                    :class="
                      announcement.active
                        ? 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200'
                        : 'bg-slate-100 text-slate-800 dark:bg-slate-700 dark:text-slate-300'
                    "
                  >
                    {{ announcement.active ? 'Ativo' : 'Inativo' }}
                  </span>
                  
                  <!-- Agendado -->
                  <span
                    v-if="announcement.scheduled_at && isScheduledForFuture(announcement.scheduled_at)"
                    class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200"
                  >
                    📅 Agendado
                  </span>
                  
                  <!-- Expira em breve -->
                  <span
                    v-if="announcement.expires_at && !isExpired(announcement.expires_at)"
                    class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-orange-100 text-orange-800 dark:bg-orange-900 dark:text-orange-200"
                  >
                    ⏰ Expira em {{ formatRelativeTime(announcement.expires_at) }}
                  </span>
                  
                  <!-- Expirado -->
                  <span
                    v-if="announcement.expires_at && isExpired(announcement.expires_at)"
                    class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200"
                  >
                    ❌ Expirado
                  </span>
                </div>
              </td>
              <td>
                <small>{{ formatDate(announcement.published_at) }}</small>
              </td>
              <td class="button-wrapper">
                <woot-button
                  v-tooltip.top="'Visualizar'"
                  variant="smooth"
                  size="tiny"
                  color-scheme="secondary"
                  icon="eye-show"
                  @click="openPreviewPopup(announcement)"
                />
                <woot-button
                  v-tooltip.top="'Editar'"
                  variant="smooth"
                  size="tiny"
                  color-scheme="secondary"
                  icon="edit"
                  @click="openEditPopup(announcement)"
                />
                <woot-button
                  v-tooltip.top="'Resetar visualizações (todos verão novamente)'"
                  variant="smooth"
                  size="tiny"
                  color-scheme="warning"
                  icon="arrow-clockwise"
                  @click="resetAnnouncement(announcement)"
                />
                <woot-button
                  v-tooltip.top="'Excluir'"
                  variant="smooth"
                  color-scheme="alert"
                  size="tiny"
                  icon="dismiss-circle"
                  @click="openDeletePopup(announcement)"
                />
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Modal Add -->
    <woot-modal :show.sync="showAddPopup" :on-close="hideAddPopup">
      <add-announcement @close="hideAddPopup" />
    </woot-modal>

    <!-- Modal Edit -->
    <woot-modal :show.sync="showEditPopup" :on-close="hideEditPopup">
      <edit-announcement
        :announcement="selectedAnnouncement"
        @close="hideEditPopup"
      />
    </woot-modal>

    <!-- Modal Preview -->
    <woot-modal :show.sync="showPreviewPopup" :on-close="hidePreviewPopup">
      <preview-announcement
        :announcement="selectedAnnouncement"
        @close="hidePreviewPopup"
      />
    </woot-modal>

    <!-- Modal Delete -->
    <woot-delete-modal
      :show.sync="showDeletePopup"
      :on-close="closeDeletePopup"
      :on-confirm="confirmDeletion"
      title="Confirmar exclusão"
      message="Tem certeza que deseja excluir este anúncio?"
      :message-value="deleteMessage"
      confirm-text="Sim, excluir"
      reject-text="Cancelar"
    />
  </div>
</template>

<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import AddAnnouncement from './AddAnnouncement.vue';
import EditAnnouncement from './EditAnnouncement.vue';
import PreviewAnnouncement from './PreviewAnnouncement.vue';
import AnnouncementsAPI from 'dashboard/api/announcements';

export default {
  components: {
    AddAnnouncement,
    EditAnnouncement,
    PreviewAnnouncement,
  },

  data() {
    return {
      announcements: [],
      showAddPopup: false,
      showEditPopup: false,
      showPreviewPopup: false,
      showDeletePopup: false,
      selectedAnnouncement: null,
      uiFlags: {
        isFetching: false,
      },
    };
  },

  computed: {
    ...mapGetters({
      currentUser: 'getCurrentUser',
    }),
    deleteMessage() {
      return this.selectedAnnouncement?.title?.pt_BR || '';
    },
  },

  mounted() {
    this.fetchAnnouncements();
  },

  methods: {
    async fetchAnnouncements() {
      this.uiFlags.isFetching = true;
      try {
        const response = await AnnouncementsAPI.get();
        this.announcements = response.data.announcements || [];
      } catch (error) {
        console.error('Failed to load announcements:', error);
        // Fallback
        try {
          const fallback = await fetch('/announcements/data.json');
          const fallbackData = await fallback.json();
          this.announcements = fallbackData.announcements || [];
        } catch (e) {
          this.announcements = [];
        }
      } finally {
        this.uiFlags.isFetching = false;
      }
    },

    openAddPopup() {
      this.showAddPopup = true;
    },

    hideAddPopup() {
      this.showAddPopup = false;
      this.fetchAnnouncements();
    },

    openEditPopup(announcement) {
      this.selectedAnnouncement = announcement;
      this.showEditPopup = true;
    },

    hideEditPopup() {
      this.showEditPopup = false;
      this.selectedAnnouncement = null;
      this.fetchAnnouncements();
    },

    openPreviewPopup(announcement) {
      this.selectedAnnouncement = announcement;
      this.showPreviewPopup = true;
    },

    hidePreviewPopup() {
      this.showPreviewPopup = false;
      this.selectedAnnouncement = null;
    },

    openDeletePopup(announcement) {
      this.selectedAnnouncement = announcement;
      this.showDeletePopup = true;
    },

    closeDeletePopup() {
      this.showDeletePopup = false;
    },

    async confirmDeletion() {
      try {
        await AnnouncementsAPI.delete(this.selectedAnnouncement.id);
        useAlert('Anúncio excluído com sucesso');
        this.fetchAnnouncements();
      } catch (error) {
        useAlert('Erro ao excluir anúncio');
      } finally {
        this.closeDeletePopup();
      }
    },

    async resetAnnouncement(announcement) {
      if (!confirm(`Tem certeza que deseja resetar as visualizações do anúncio "${announcement.title.pt_BR}"?\n\nTodos os usuários verão este anúncio novamente!`)) {
        return;
      }

      try {
        // Alterar a data de publicação para forçar re-exibição
        const updatedAnnouncement = {
          ...announcement,
          published_at: new Date().toISOString() // Nova data = novo anúncio
        };

        await AnnouncementsAPI.update(announcement.id, {
          title_pt_BR: announcement.title.pt_BR,
          title_en: announcement.title.en,
          title_es: announcement.title.es,
          title_pt: announcement.title.pt,
          description_pt_BR: announcement.description.pt_BR,
          description_en: announcement.description.en,
          description_es: announcement.description.es,
          description_pt: announcement.description.pt,
          media_url: announcement.media_url,
          target_roles: announcement.target_roles,
          active: announcement.active,
          reset_views: true // Flag especial
        });

        useAlert('Anúncio resetado! Todos os usuários verão novamente.');
        this.fetchAnnouncements();
      } catch (error) {
        useAlert('Erro ao resetar anúncio');
        console.error(error);
      }
    },

    formatDate(dateString) {
      return new Date(dateString).toLocaleDateString('pt-BR', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      });
    },

    // 🆕 Verificar se está agendado para o futuro
    isScheduledForFuture(scheduledAt) {
      if (!scheduledAt) return false;
      return new Date(scheduledAt) > new Date();
    },

    // 🆕 Verificar se expirou
    isExpired(expiresAt) {
      if (!expiresAt) return false;
      return new Date(expiresAt) <= new Date();
    },

    // 🆕 Formatar tempo relativo
    formatRelativeTime(dateString) {
      const date = new Date(dateString);
      const now = new Date();
      const diff = date - now;
      
      const minutes = Math.floor(diff / 60000);
      const hours = Math.floor(diff / 3600000);
      const days = Math.floor(diff / 86400000);
      
      if (days > 0) return `${days}d`;
      if (hours > 0) return `${hours}h`;
      if (minutes > 0) return `${minutes}min`;
      return 'breve';
    },
  },
};
</script>

<style scoped>
.truncate {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  max-width: 300px;
}
</style>
