<template>
  <div class="p-6 bg-slate-50 dark:bg-slate-900">
    <div class="bg-white dark:bg-slate-800 rounded-xl shadow-soft border border-slate-200 dark:border-slate-700">
      <div class="p-4 border-b border-slate-200 dark:border-slate-700">
        <h2 class="text-xl font-semibold text-slate-900 dark:text-white">
          {{ $t('KANBAN.LIST_VIEW.TITLE') }}
        </h2>
      </div>
      <div class="overflow-x-auto">
        <table class="w-full">
          <thead class="bg-slate-50 dark:bg-slate-700/50">
            <tr>
              <th class="px-4 py-3 text-left text-xs font-medium text-slate-600 dark:text-slate-300 uppercase tracking-wider">
                {{ $t('KANBAN.LIST_VIEW.NAME') }}
              </th>
              <th class="px-4 py-3 text-left text-xs font-medium text-slate-600 dark:text-slate-300 uppercase tracking-wider">
                {{ $t('KANBAN.LIST_VIEW.STAGE') }}
              </th>
              <th class="px-4 py-3 text-left text-xs font-medium text-slate-600 dark:text-slate-300 uppercase tracking-wider">
                {{ $t('KANBAN.LIST_VIEW.VALUE') }}
              </th>
              <th class="px-4 py-3 text-left text-xs font-medium text-slate-600 dark:text-slate-300 uppercase tracking-wider">
                {{ $t('KANBAN.LIST_VIEW.STATUS') }}
              </th>
              <th
                v-if="isSplitOwnership"
                class="px-4 py-3 text-left text-xs font-medium text-slate-600 dark:text-slate-300 uppercase tracking-wider"
              >
                {{ $t('KANBAN.OWNERSHIP.DEAL') }}
              </th>
              <th class="px-4 py-3 text-left text-xs font-medium text-slate-600 dark:text-slate-300 uppercase tracking-wider">
                {{ $t('KANBAN.OWNERSHIP.ATTENDANT') }}
              </th>
              <th class="px-4 py-3 text-left text-xs font-medium text-slate-600 dark:text-slate-300 uppercase tracking-wider">
                {{ $t('KANBAN.LIST_VIEW.TIME_IN_STAGE') }}
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-200 dark:divide-slate-700">
            <tr
              v-for="contact in contacts"
              :key="contact.id"
              class="cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-700/50 transition-colors duration-150 ease-smooth"
              @click="$emit('open-card', contact)"
            >
              <td class="px-4 py-3">
                <div class="text-sm font-medium text-slate-900 dark:text-white">
                  {{ contact.name }}
                </div>
                <div class="text-xs text-slate-500 dark:text-slate-400">
                  {{ contact.phone_number || contact.email || '—' }}
                </div>
              </td>
              <td class="px-4 py-3 whitespace-nowrap text-sm text-slate-900 dark:text-white">
                {{ stageName(contact) }}
              </td>
              <td class="px-4 py-3 whitespace-nowrap text-sm font-medium text-slate-900 dark:text-white">
                {{ formatValue(contact) }}
              </td>
              <td class="px-4 py-3 whitespace-nowrap">
                <span
                  class="inline-flex items-center px-2 py-0.5 rounded-full text-[11px] font-medium"
                  :class="statusClass(contact)"
                >
                  {{ statusLabel(contact) }}
                </span>
              </td>
              <td v-if="isSplitOwnership" class="px-4 py-3 whitespace-nowrap">
                <person-cell :person="dealOwner(contact)" />
              </td>
              <td class="px-4 py-3 whitespace-nowrap">
                <person-cell :person="attendant(contact)" />
              </td>
              <td class="px-4 py-3 whitespace-nowrap text-sm text-slate-500 dark:text-slate-400">
                {{ timeInStage(contact) }}
              </td>
            </tr>
            <tr v-if="!contacts.length">
              <td :colspan="columnCount" class="px-4 py-8 text-center text-slate-500 dark:text-slate-400">
                {{ $t('KANBAN.LIST_VIEW.NO_CONTACTS') }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div
        v-if="contacts.length > 0 && totalPages > 1"
        class="p-4 border-t border-slate-200 dark:border-slate-700 flex items-center justify-between"
      >
        <div class="text-sm text-slate-600 dark:text-slate-400">
          {{
            $t('KANBAN.LIST_VIEW.PAGINATION', {
              from: fromItem,
              to: toItem,
              total: totalCount,
            })
          }}
        </div>
        <div class="flex items-center gap-2">
          <button
            type="button"
            class="px-3 py-2 text-sm font-medium text-slate-700 dark:text-slate-300 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg hover:bg-slate-50 dark:hover:bg-slate-700 disabled:opacity-50 disabled:cursor-not-allowed"
            :disabled="currentPage === 1"
            @click="$emit('change-page', currentPage - 1)"
          >
            {{ $t('KANBAN.LIST_VIEW.PREVIOUS') }}
          </button>
          <span class="text-sm text-slate-600 dark:text-slate-400">
            {{ $t('KANBAN.LIST_VIEW.PAGE', { page: currentPage, pages: totalPages }) }}
          </span>
          <button
            type="button"
            class="px-3 py-2 text-sm font-medium text-slate-700 dark:text-slate-300 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg hover:bg-slate-50 dark:hover:bg-slate-700 disabled:opacity-50 disabled:cursor-not-allowed"
            :disabled="currentPage === totalPages"
            @click="$emit('change-page', currentPage + 1)"
          >
            {{ $t('KANBAN.LIST_VIEW.NEXT') }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import {
  getAssignee,
  getConversationAssignee,
  getDealValue,
  getEnteredAt,
  getStage,
  getWinLostStatus,
} from '../utils/pipelinePositionsHelper';

const PersonCell = {
  name: 'PersonCell',
  props: {
    person: {
      type: Object,
      default: null,
    },
  },
  computed: {
    name() {
      return this.person?.available_name || this.person?.name || '';
    },
    initials() {
      if (!this.name) return '';
      const parts = this.name.trim().split(/\s+/);
      if (parts.length === 1) return parts[0].charAt(0).toUpperCase();
      return (parts[0].charAt(0) + parts[parts.length - 1].charAt(0)).toUpperCase();
    },
    thumbnail() {
      return this.person?.thumbnail || this.person?.avatar_url || '';
    },
  },
  render(h) {
    if (!this.person) {
      return h(
        'span',
        { class: 'text-sm text-slate-400 dark:text-slate-500' },
        this.$t('KANBAN.LIST_VIEW.UNASSIGNED')
      );
    }
    return h('div', { class: 'flex items-center gap-2 min-w-0' }, [
      this.thumbnail
        ? h('img', {
            class: 'w-6 h-6 rounded-full object-cover shrink-0',
            attrs: { src: this.thumbnail, alt: this.name },
          })
        : h(
            'span',
            {
              class:
                'w-6 h-6 rounded-full bg-woot-500 text-white text-[10px] font-semibold flex items-center justify-center shrink-0',
            },
            this.initials
          ),
      h('span', { class: 'text-sm text-slate-900 dark:text-white truncate' }, this.name),
    ]);
  },
};

export default {
  name: 'KanbanListView',
  components: { PersonCell },
  props: {
    contacts: {
      type: Array,
      default: () => [],
    },
    pipelineId: {
      type: [Number, String],
      required: true,
    },
    ownershipMode: {
      type: String,
      default: 'linked',
    },
    currentPage: {
      type: Number,
      default: 1,
    },
    totalPages: {
      type: Number,
      default: 1,
    },
    totalCount: {
      type: Number,
      default: 0,
    },
    perPage: {
      type: Number,
      default: 25,
    },
  },
  computed: {
    isSplitOwnership() {
      return this.ownershipMode === 'split';
    },
    columnCount() {
      return this.isSplitOwnership ? 7 : 6;
    },
    fromItem() {
      return (this.currentPage - 1) * this.perPage + 1;
    },
    toItem() {
      return Math.min(this.currentPage * this.perPage, this.totalCount);
    },
  },
  methods: {
    stageName(contact) {
      return getStage(contact, this.pipelineId) || '—';
    },
    formatValue(contact) {
      const value = getDealValue(contact, this.pipelineId) || 0;
      return new Intl.NumberFormat('pt-BR', {
        style: 'currency',
        currency: 'BRL',
      }).format(value);
    },
    dealOwner(contact) {
      return getAssignee(contact, this.pipelineId);
    },
    attendant(contact) {
      if (this.isSplitOwnership) {
        return getConversationAssignee(contact, this.pipelineId);
      }
      return getAssignee(contact, this.pipelineId);
    },
    timeInStage(contact) {
      const enteredAt = getEnteredAt(contact, this.pipelineId);
      if (!enteredAt) return '—';
      const days = Math.floor((Date.now() - new Date(enteredAt).getTime()) / 86400000);
      return `${days}d`;
    },
    statusKey(contact) {
      const status = getWinLostStatus(contact, this.pipelineId)?.status;
      if (status === 'won' || status === 'lost') return status;
      return 'open';
    },
    statusLabel(contact) {
      const key = this.statusKey(contact).toUpperCase();
      return this.$t(`KANBAN.LIST_VIEW.${key}`);
    },
    statusClass(contact) {
      const status = this.statusKey(contact);
      if (status === 'won') {
        return 'bg-green-50 text-green-700 dark:bg-green-900/30 dark:text-green-300';
      }
      if (status === 'lost') {
        return 'bg-red-50 text-red-700 dark:bg-red-900/30 dark:text-red-300';
      }
      return 'bg-slate-100 text-slate-700 dark:bg-slate-700 dark:text-slate-200';
    },
  },
};
</script>
