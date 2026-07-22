<template>
  <div
    class="activities-calendar-container bg-slate-50 dark:bg-slate-900 overflow-y-auto flex flex-col"
    :class="showCreateButton ? 'min-h-screen' : 'h-full min-h-0'"
  >
    <!-- Header com navegação e filtros (padding alinhado ao corpo) -->
    <div class="calendar-header bg-white dark:bg-slate-800 border-b border-slate-200 dark:border-slate-700 px-6 py-3 sticky top-0 z-20 backdrop-blur-sm bg-white/95 dark:bg-slate-800/95">
      <div class="flex items-center justify-between gap-4">
        <!-- Lado esquerdo: Navegação e título -->
        <div class="flex items-center gap-3">
          <!-- Navegação de mês -->
          <div class="flex items-center gap-1">
            <button
              @click="previousMonth"
              class="w-8 h-8 flex items-center justify-center rounded-lg hover:bg-slate-50 dark:hover:bg-slate-700 transition-all duration-150 ease-smooth text-slate-600 dark:text-slate-300"
            >
              <fluent-icon icon="chevron-left" size="16" />
            </button>
            <button
              @click="goToToday"
              class="px-3 py-1.5 text-xs font-medium rounded-lg hover:bg-slate-50 dark:hover:bg-slate-700 transition-all duration-150 ease-smooth text-slate-700 dark:text-slate-200"
            >
              Hoje
            </button>
            <button
              @click="nextMonth"
              class="w-8 h-8 flex items-center justify-center rounded-lg hover:bg-slate-50 dark:hover:bg-slate-700 transition-all duration-150 ease-smooth text-slate-600 dark:text-slate-300"
            >
              <fluent-icon icon="chevron-right" size="16" />
            </button>
          </div>

          <!-- Título do mês -->
          <h2 class="text-lg font-semibold text-slate-900 dark:text-white">
            {{ currentMonthLabel }}
          </h2>

          <!-- Total filtrado -->
          <span
            class="px-2 py-0.5 rounded-full bg-slate-100 dark:bg-slate-700 text-xs font-medium text-slate-600 dark:text-slate-300"
            :title="$t('ACTIVITIES.FILTERS.TOTAL', { count: filteredTotalCount })"
          >
            {{ filteredTotalLabel }}
          </span>
        </div>

        <!-- Lado direito: Pesquisa - Mês/Lista - Filtros - Nova Atividade -->
        <div class="flex items-center gap-2">
          <!-- Pesquisa -->
          <div class="hidden md:flex items-center gap-2" v-on-clickaway="closeQuickSearch">
            <button
              @click="showQuickSearch = !showQuickSearch"
              :class="[
                'relative inline-flex items-center justify-center w-8 h-8 rounded-lg text-xs font-medium transition-all duration-200 ease-smooth',
                'text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-slate-100',
                'hover:bg-slate-50 dark:hover:bg-slate-700',
                showQuickSearch ? 'bg-woot-50 text-woot-600 dark:bg-woot-900/20 dark:text-woot-400' : ''
              ]"
              v-tooltip.top="$t('KANBAN.SEARCH_PLACEHOLDER')"
            >
              <fluent-icon icon="search" class="w-5 h-5 flex-shrink-0 text-current" />
            </button>

            <!-- Campo de busca expansível -->
            <transition
              enter-active-class="transition ease-out duration-200"
              enter-from-class="opacity-0 transform -translate-x-2"
              enter-to-class="opacity-100 transform translate-x-0"
              leave-active-class="transition ease-in duration-150"
              leave-from-class="opacity-100 transform translate-x-0"
              leave-to-class="opacity-0 transform -translate-x-2"
            >
              <input
                v-show="showQuickSearch"
                v-model="searchQuery"
                type="search"
                :placeholder="$t('KANBAN.SEARCH_PLACEHOLDER')"
                class="px-3 py-1.5 text-xs border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-woot-500 focus:border-transparent dark:bg-slate-700 dark:border-slate-600 dark:text-slate-200 dark:placeholder-slate-400 w-48 transition-colors duration-150 ease-smooth"
                @input="debouncedSearch"
              >
            </transition>
          </div>

          <!-- Toggle Mês/Lista -->
          <div class="flex items-center gap-0.5 bg-slate-100/60 dark:bg-slate-700/50 rounded-lg p-0.5">
            <button
              v-for="view in availableViews"
              :key="view.id"
              :class="[
                'px-2.5 py-1.5 rounded-lg text-xs font-medium transition-all duration-200 ease-smooth flex items-center gap-1.5',
                currentView === view.id
                  ? 'bg-white dark:bg-slate-800 text-woot-600 dark:text-woot-400 shadow-soft'
                  : 'text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white'
              ]"
              @click="currentView = view.id"
              v-tooltip.top="view.label"
            >
              <fluent-icon :icon="view.icon" size="14" />
              <span class="hidden sm:inline">{{ view.label }}</span>
            </button>
          </div>

          <!-- Filtros -->
          <div class="relative" v-on-clickaway="closeFiltersDropdown">
            <button
              @click="showFiltersDropdown = !showFiltersDropdown"
              :class="[
                'relative inline-flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-xs font-medium transition-all duration-200 ease-smooth',
                'text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-slate-100',
                'hover:bg-slate-50 dark:hover:bg-slate-700',
                hasActiveFilters
                  ? 'bg-slate-50 dark:bg-slate-800/50 text-slate-700 dark:text-slate-200'
                  : '',
                showFiltersDropdown ? 'bg-slate-100 dark:bg-slate-700 text-slate-900 dark:text-slate-100' : ''
              ]"
              v-tooltip.top="$t('KANBAN.FILTERS.TITLE')"
            >
              <fluent-icon icon="filter" size="14" />
              <span class="hidden lg:inline">{{ $t('KANBAN.FILTERS.TITLE') }}</span>
              <fluent-icon
                icon="chevron-down"
                size="10"
                :class="['transition-transform duration-200', showFiltersDropdown ? 'rotate-180' : '']"
              />
              <span
                v-if="hasActiveFilters"
                class="absolute -top-1 -right-1 bg-woot-500 text-white text-[10px] font-semibold rounded-full min-w-[16px] h-4 px-1 flex items-center justify-center leading-none"
              >
                {{ activeFiltersCount }}
              </span>
            </button>

            <!-- Dropdown de filtros (w-96 como Kanban) -->
            <transition
              enter-active-class="transition ease-out duration-100"
              enter-from-class="transform opacity-0 scale-95"
              enter-to-class="transform opacity-100 scale-100"
              leave-active-class="transition ease-in duration-75"
              leave-from-class="transform opacity-100 scale-100"
              leave-to-class="transform opacity-0 scale-95"
            >
              <div
                v-if="showFiltersDropdown"
                class="absolute right-0 mt-2 w-96 rounded-xl shadow-soft-xl bg-white dark:bg-slate-800 ring-1 ring-black ring-opacity-5 z-50 p-4 animate-scale-in"
              >
                <div class="p-3 space-y-3">
                  <!-- Filtro de status -->
                  <div>
                    <label class="block text-sm font-medium text-slate-700 dark:text-slate-200 mb-2">
                      {{ $t('ACTIVITIES.FILTERS.STATUS') }}
                    </label>
                    <select
                      v-model="filters.status"
                      class="w-full px-2 py-1 text-xs border border-slate-200 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-700 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-slate-700 dark:border-slate-600 dark:text-slate-200 transition-colors duration-150 ease-smooth"
                    >
                      <option value="all">{{ $t('ACTIVITIES.FILTERS.ALL') }}</option>
                      <option value="pending">{{ $t('ACTIVITIES.STATUS.PENDING') }}</option>
                      <option value="completed">{{ $t('ACTIVITIES.STATUS.COMPLETED') }}</option>
                      <option value="cancelled">{{ $t('ACTIVITIES.STATUS.CANCELLED') }}</option>
                      <option value="overdue">{{ $t('ACTIVITIES.FILTERS.OVERDUE') }}</option>
                      <option value="failed">{{ $t('ACTIVITIES.STATUS.FAILED') }}</option>
                    </select>
                  </div>

                  <!-- Filtro de tipo -->
                  <div>
                    <label class="block text-sm font-medium text-slate-700 dark:text-slate-200 mb-2">
                      {{ $t('ACTIVITIES.FILTERS.TYPE') }}
                    </label>
                    <select
                      v-model="filters.type"
                      class="w-full px-2 py-1 text-xs border border-slate-200 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-700 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-slate-700 dark:border-slate-600 dark:text-slate-200 transition-colors duration-150 ease-smooth"
                    >
                      <option value="all">{{ $t('ACTIVITIES.FILTERS.ALL') }}</option>
                      <option value="task">{{ $t('ACTIVITIES.TYPE.TASK') }}</option>
                      <option value="scheduled_message">{{ $t('ACTIVITIES.TYPE.SCHEDULED_MESSAGE') }}</option>
                    </select>
                  </div>

                  <!-- Filtro de responsável -->
                  <div>
                    <label class="block text-sm font-medium text-slate-700 dark:text-slate-200 mb-2">
                      {{ $t('ACTIVITIES.FORM.ASSIGNEE') }}
                    </label>
                    <select
                      v-model="filters.assigneeId"
                      class="w-full px-2 py-1 text-xs border border-slate-200 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-700 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-slate-700 dark:border-slate-600 dark:text-slate-200 transition-colors duration-150 ease-smooth"
                    >
                      <option value="all">{{ $t('ACTIVITIES.FILTERS.ALL') }}</option>
                      <option v-for="agent in agents" :key="agent.id" :value="agent.id">
                        {{ agent.name }}
                      </option>
                    </select>
                  </div>

                  <!-- Filtro de criador -->
                  <div>
                    <label class="block text-sm font-medium text-slate-700 dark:text-slate-200 mb-2">
                      {{ $t('ACTIVITIES.FILTERS.CREATED_BY') }}
                    </label>
                    <select
                      v-model="filters.userId"
                      class="w-full px-2 py-1 text-xs border border-slate-200 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-700 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-slate-700 dark:border-slate-600 dark:text-slate-200 transition-colors duration-150 ease-smooth"
                    >
                      <option value="all">{{ $t('ACTIVITIES.FILTERS.ALL') }}</option>
                      <option v-for="agent in agents" :key="`creator-${agent.id}`" :value="agent.id">
                        {{ agent.name }}
                      </option>
                    </select>
                  </div>

                  <!-- Filtro de intervalo de datas -->
                  <div class="grid grid-cols-2 gap-2">
                    <div>
                      <label class="block text-sm font-medium text-slate-700 dark:text-slate-200 mb-2">
                        {{ $t('ACTIVITIES.FILTERS.DATE_FROM') }}
                      </label>
                      <input
                        v-model="filters.dateFrom"
                        type="date"
                        class="w-full px-2 py-1 text-xs border border-slate-200 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-700 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-slate-700 dark:border-slate-600 dark:text-slate-200 transition-colors duration-150 ease-smooth"
                      >
                    </div>
                    <div>
                      <label class="block text-sm font-medium text-slate-700 dark:text-slate-200 mb-2">
                        {{ $t('ACTIVITIES.FILTERS.DATE_TO') }}
                      </label>
                      <input
                        v-model="filters.dateTo"
                        type="date"
                        class="w-full px-2 py-1 text-xs border border-slate-200 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-700 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-slate-700 dark:border-slate-600 dark:text-slate-200 transition-colors duration-150 ease-smooth"
                      >
                    </div>
                  </div>

                  <!-- Busca (estilo Kanban) -->
                  <div>
                    <label class="block text-sm font-medium text-slate-700 dark:text-slate-200 mb-2">
                      Buscar
                    </label>
                    <input
                      v-model="searchQuery"
                      type="search"
                      placeholder="Título ou descrição..."
                      class="w-full px-2 py-1 text-xs border border-slate-200 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-700 text-slate-900 dark:text-white placeholder-slate-400 dark:placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-slate-700 dark:border-slate-600 dark:text-slate-200 transition-colors duration-150 ease-smooth"
                      @input="debouncedSearch"
                    >
                  </div>

                  <!-- Botão limpar filtros -->
                  <button
                    v-if="hasActiveFilters"
                    @click="clearFilters"
                    class="w-full px-2 py-1.5 text-xs font-medium text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white rounded-lg hover:bg-slate-50 dark:hover:bg-slate-700 transition-all duration-150"
                  >
                    Limpar filtros
                  </button>
                </div>
              </div>
            </transition>
          </div>

          <!-- Botão informativo (reabrir modal de onboarding) -->
          <button
            v-if="showOnboardingButton && onOpenOnboarding"
            @click="onOpenOnboarding()"
            class="relative inline-flex items-center justify-center w-8 h-8 rounded-lg text-xs font-medium transition-all duration-200 ease-smooth text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-slate-100 hover:bg-slate-50 dark:hover:bg-slate-700"
            v-tooltip.top="$t('ACTIVITIES.ONBOARDING.TITLE')"
          >
            <fluent-icon icon="info" size="16" />
          </button>

          <!-- Nova Atividade (botão verde primário) -->
          <woot-button
            v-if="showCreateButton"
            icon="add-circle"
            size="small"
            color-scheme="success"
            @click="openCreateModal"
          >
            <span class="hidden sm:inline">{{ $t('ACTIVITIES.CREATE') }}</span>
          </woot-button>
        </div>
      </div>
    </div>

    <!-- Conteúdo principal (padding alinhado ao header) -->
    <div
      class="calendar-content px-6 py-6 overflow-y-auto flex-1 min-h-0"
      :style="showCreateButton ? 'max-height: calc(100vh - 120px)' : ''"
    >
      <!-- Vista Mensal -->
      <div v-if="currentView === 'month'" class="calendar-month-view relative">
        <div v-if="loading" class="absolute inset-0 z-10 flex items-center justify-center bg-white/60 dark:bg-slate-900/60">
          <spinner />
        </div>
        <div class="bg-white dark:bg-slate-800 rounded-xl shadow-soft border border-slate-200 dark:border-slate-700 overflow-hidden">
          <!-- Cabeçalho dos dias da semana -->
          <div class="calendar-weekdays grid grid-cols-7 bg-slate-50 dark:bg-slate-700/50 border-b border-slate-200 dark:border-slate-700">
            <div
              v-for="day in weekDays"
              :key="day"
              class="px-2 py-3 text-center text-xs font-semibold text-slate-600 dark:text-slate-300 uppercase tracking-wider"
            >
              {{ day }}
            </div>
          </div>

          <!-- Grid de dias -->
          <div class="calendar-grid grid grid-cols-7">
            <div
              v-for="day in calendarDays"
              :key="day.date"
              :class="[
                'calendar-day min-h-[220px] border-r border-b border-slate-200 dark:border-slate-700 p-2 transition-colors',
                {
                  'bg-slate-50/50 dark:bg-slate-900/50': !day.isCurrentMonth,
                  'bg-white dark:bg-slate-800': day.isCurrentMonth,
                  'bg-blue-50/30 dark:bg-blue-900/10': day.isToday,
                  'cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-700/50': day.isCurrentMonth
                }
              ]"
              @click="day.isCurrentMonth && selectDay(day)"
            >
              <!-- Número do dia -->
              <div class="flex items-center justify-between mb-2">
                <span
                  :class="[
                    'text-sm font-medium',
                    day.isToday
                      ? 'bg-woot-500 text-white w-6 h-6 flex items-center justify-center rounded-full'
                      : day.isCurrentMonth
                      ? 'text-slate-900 dark:text-white'
                      : 'text-slate-400 dark:text-slate-600'
                  ]"
                >
                  {{ day.dayNumber }}
                </span>
                <!-- Badge de contagem -->
                <span
                  v-if="day.activitiesCount > 0"
                  :class="[
                    'px-2 py-0.5 rounded-full text-xs font-semibold',
                    getCountBadgeClass(day)
                  ]"
                >
                  {{ day.activitiesCount }}
                </span>
              </div>

              <!-- Lista de atividades do dia (mostra até 8, scroll para mais) -->
              <div class="space-y-1 overflow-y-auto max-h-[200px] min-h-[24px]">
                <div
                  v-for="activity in day.activities.slice(0, 8)"
                  :key="activity.id"
                  :class="[
                    'activity-card-mini px-2 py-1 rounded text-xs cursor-pointer transition-all duration-150 group relative',
                    getActivityClass(activity)
                  ]"
                  @click.stop="openActivityDetail(activity)"
                  @mouseenter="showTooltip(activity, $event)"
                  @mouseleave="hideTooltip"
                >
                  <div class="flex items-center gap-1">
                    <fluent-icon
                      :icon="activity.activity_type === 'scheduled_message' ? 'send-clock' : 'checkmark-circle'"
                      size="10"
                    />
                    <span class="truncate font-medium">
                      {{ formatTime(activity.scheduled_at) }} {{ activity.title }}
                    </span>
                  </div>
                  <!-- Nome do contato -->
                  <div v-if="activity.contact" class="text-[10px] text-slate-600 dark:text-slate-400 mt-0.5 truncate">
                    👤 {{ activity.contact.name }}
                  </div>
                </div>
                <!-- Mostrar "+N mais" se houver mais atividades -->
                <div
                  v-if="day.activities.length > 8"
                  class="text-xs text-slate-500 dark:text-slate-400 px-2 py-1 cursor-pointer hover:text-slate-700 dark:hover:text-slate-300 font-medium"
                  @click.stop="selectDay(day)"
                >
                  +{{ day.activities.length - 8 }} mais
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Vista de Lista -->
      <div v-else-if="currentView === 'list'" class="calendar-list-view">
        <div class="space-y-4">
          <!-- Loading -->
          <div v-if="loading" class="flex items-center justify-center py-12">
            <spinner />
          </div>

          <!-- Empty state -->
          <div v-else-if="!activitiesForCurrentMonth.length" class="text-center py-12">
            <fluent-icon icon="calendar" size="48" class="mx-auto mb-4 text-slate-400 dark:text-slate-600" />
            <p class="text-slate-500 dark:text-slate-400">
              {{ searchQuery ? 'Nenhuma atividade encontrada' : 'Nenhuma atividade agendada' }}
            </p>
          </div>

          <!-- Lista de atividades agrupadas -->
          <div v-else v-for="group in groupedActivities" :key="group.label" class="bg-white dark:bg-slate-800 rounded-xl shadow-soft border border-slate-200 dark:border-slate-700 overflow-hidden">
            <!-- Cabeçalho do grupo -->
            <div class="px-4 py-3 bg-slate-50 dark:bg-slate-700/50 border-b border-slate-200 dark:border-slate-700">
              <h3 class="text-sm font-semibold text-slate-900 dark:text-white">
                {{ group.label }} ({{ group.activities.length }})
              </h3>
            </div>

            <!-- Atividades do grupo -->
            <div class="divide-y divide-slate-200 dark:divide-slate-700">
              <div
                v-for="activity in group.activities"
                :key="activity.id"
                :class="[
                  'activity-card-list p-4 cursor-pointer transition-colors hover:bg-slate-50 dark:hover:bg-slate-700/50',
                  getActivityBorderClass(activity)
                ]"
                @click="openActivityDetail(activity)"
              >
                <div class="flex items-start gap-3">
                  <!-- Ícone de tipo -->
                  <div
                    :class="[
                      'flex-shrink-0 w-10 h-10 rounded-lg flex items-center justify-center',
                      getActivityIconBgClass(activity)
                    ]"
                  >
                    <fluent-icon
                      :icon="activity.activity_type === 'scheduled_message' ? 'send-clock' : 'checkmark-circle'"
                      size="20"
                      :class="getActivityIconColorClass(activity)"
                    />
                  </div>

                  <!-- Conteúdo -->
                  <div class="flex-1 min-w-0">
                    <div class="flex items-start justify-between gap-2 mb-1">
                      <h4 class="text-sm font-semibold text-slate-900 dark:text-white">
                        {{ activity.title }}
                      </h4>
                      <span
                        :class="[
                          'flex-shrink-0 px-2 py-0.5 rounded-full text-xs font-medium',
                          getStatusBadgeClass(activity)
                        ]"
                      >
                        {{ getStatusLabel(activity.status) }}
                      </span>
                    </div>

                    <p v-if="activity.description" class="text-xs text-slate-600 dark:text-slate-400 mb-2 line-clamp-2">
                      {{ activity.description }}
                    </p>

                    <!-- Metadados -->
                    <div class="flex items-center gap-3 text-xs text-slate-500 dark:text-slate-400">
                      <span class="flex items-center gap-1">
                        <fluent-icon icon="calendar" size="12" />
                        {{ formatDate(activity.scheduled_at) }}
                      </span>
                      <span class="flex items-center gap-1">
                        <fluent-icon icon="clock" size="12" />
                        {{ formatTime(activity.scheduled_at) }}
                      </span>
                      <span v-if="activity.contact" class="flex items-center gap-1">
                        <fluent-icon icon="person" size="12" />
                        {{ activity.contact.name }}
                      </span>
                    </div>
                  </div>

                  <!-- Ações rápidas -->
                  <div class="flex items-center gap-1 flex-shrink-0">
                    <button
                      v-if="activity.status === 'pending'"
                      class="p-1.5 rounded-lg hover:bg-green-100 dark:hover:bg-green-900/30 text-green-600 dark:text-green-400 transition-colors"
                      @click.stop="completeActivity(activity.id)"
                      v-tooltip="$t('ACTIVITIES.ACTIONS.COMPLETE')"
                    >
                      <fluent-icon icon="checkmark" size="16" />
                    </button>
                    <button
                      v-if="activity.status === 'pending' || activity.status === 'failed'"
                      class="p-1.5 rounded-lg hover:bg-red-100 dark:hover:bg-red-900/30 text-red-600 dark:text-red-400 transition-colors"
                      @click.stop="deleteActivity(activity.id)"
                      v-tooltip="$t('ACTIVITIES.ACTIONS.DELETE')"
                    >
                      <fluent-icon icon="delete" size="16" />
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal de visualização -->
    <woot-modal
      v-if="showDetailModal && selectedActivity"
      :show.sync="showDetailModal"
      :on-close="closeDetailModal"
    >
      <activity-detail-modal
        :activity="selectedActivity"
        :account-id="$route.params.accountId"
        @edit="openEditFromDetail"
        @delete="deleteActivity"
        @complete="completeActivity"
      />
    </woot-modal>

    <!-- Modal de criação/edição -->
    <woot-modal
      v-if="showFormModal"
      :show.sync="showFormModal"
      :on-close="closeFormModal"
    >
      <activity-form-modal
        :activity="selectedActivity"
        :contact-id="selectedActivity && selectedActivity.contact_id ? selectedActivity.contact_id : null"
        :pipeline-id="pipelineId"
        @submit="handleActivitySubmit"
        @cancel="closeFormModal"
      />
    </woot-modal>

    <!-- Modal de atividades do dia -->
    <woot-modal
      v-if="showDayModal"
      :show.sync="showDayModal"
      :on-close="closeDayModal"
    >
      <div class="p-6">
        <h3 class="text-base font-semibold text-slate-900 dark:text-white mb-4">
          {{ selectedDay ? formatDate(selectedDay.date) : '' }}
        </h3>
        <div v-if="!selectedDayActivities.length" class="text-sm text-slate-500 dark:text-slate-400">
          {{ $t('ACTIVITIES.EMPTY') }}
        </div>
        <div v-else class="space-y-2 max-h-96 overflow-y-auto">
          <div
            v-for="activity in selectedDayActivities"
            :key="activity.id"
            class="p-3 rounded-lg border border-slate-200 dark:border-slate-700"
          >
            <div class="flex items-center justify-between gap-2">
              <button
                type="button"
                class="flex-1 min-w-0 text-left"
                @click="openActivityDetail(activity); closeDayModal()"
              >
                <span class="text-sm font-medium text-slate-900 dark:text-white">{{ activity.title }}</span>
                <span class="block text-xs text-slate-500">{{ formatTime(activity.scheduled_at) }}</span>
              </button>
              <div class="flex items-center gap-1 flex-shrink-0">
                <button
                  v-if="activity.status === 'pending'"
                  type="button"
                  class="p-1.5 rounded-lg hover:bg-green-100 dark:hover:bg-green-900/30 text-green-600 dark:text-green-400"
                  @click.stop="completeActivity(activity.id)"
                >
                  <fluent-icon icon="checkmark" size="14" />
                </button>
                <button
                  v-if="activity.status === 'pending' || activity.status === 'failed'"
                  type="button"
                  class="p-1.5 rounded-lg hover:bg-red-100 dark:hover:bg-red-900/30 text-red-600 dark:text-red-400"
                  @click.stop="deleteActivity(activity.id)"
                >
                  <fluent-icon icon="delete" size="14" />
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </woot-modal>

    <!-- Tooltip informativo -->
    <div class="activity-tooltip-wrapper">
      <transition
        enter-active-class="transition ease-out duration-150"
        enter-from-class="opacity-0 transform scale-95"
        enter-to-class="opacity-100 transform scale-100"
        leave-active-class="transition ease-in duration-100"
        leave-from-class="opacity-100 transform scale-100"
        leave-to-class="opacity-0 transform scale-95"
      >
        <div
          v-if="tooltipActivity"
          class="activity-tooltip fixed z-[9999] bg-white dark:bg-slate-800 rounded-xl shadow-soft-xl dark:shadow-2xl border border-slate-200 dark:border-slate-700 p-3 min-w-[280px] max-w-[320px] pointer-events-none"
          :style="{
            left: tooltipPosition.x + 'px',
            top: tooltipPosition.y + 'px',
            transform: tooltipAbove ? 'translate(-50%, -100%)' : 'translate(-50%, 0%)',
            marginTop: tooltipAbove ? '-8px' : '8px'
          }"
        >
          <!-- Header do tooltip -->
          <div class="flex items-start justify-between gap-2 mb-2">
            <div class="flex items-center gap-2 flex-1 min-w-0">
              <div
                :class="[
                  'flex-shrink-0 w-8 h-8 rounded-lg flex items-center justify-center',
                  getActivityIconBgClass(tooltipActivity)
                ]"
              >
                <fluent-icon
                  :icon="tooltipActivity.activity_type === 'scheduled_message' ? 'send-clock' : 'checkmark-circle'"
                  size="16"
                  :class="getActivityIconColorClass(tooltipActivity)"
                />
              </div>
              <div class="flex-1 min-w-0">
                <h4 class="text-sm font-semibold text-slate-900 dark:text-white truncate">
                  {{ tooltipActivity.title }}
                </h4>
                <span
                  :class="[
                    'inline-block mt-1 px-2 py-0.5 rounded-full text-xs font-medium',
                    getStatusBadgeClass(tooltipActivity)
                  ]"
                >
                  {{ getStatusLabel(tooltipActivity.status) }}
                </span>
              </div>
            </div>
          </div>

          <!-- Descrição -->
          <p v-if="tooltipActivity.description" class="text-xs text-slate-600 dark:text-slate-400 mb-3 line-clamp-2">
            {{ tooltipActivity.description }}
          </p>

          <!-- Informações -->
          <div class="space-y-1.5 border-t border-slate-200 dark:border-slate-700 pt-2">
            <!-- Contato -->
            <div v-if="tooltipActivity.contact" class="flex items-center gap-2 text-xs">
              <fluent-icon icon="person" size="12" class="text-slate-400 dark:text-slate-500 flex-shrink-0" />
              <span class="text-slate-700 dark:text-slate-300 truncate">{{ tooltipActivity.contact.name }}</span>
            </div>

            <!-- Data e hora -->
            <div class="flex items-center gap-2 text-xs">
              <fluent-icon icon="calendar-clock" size="12" class="text-slate-400 dark:text-slate-500 flex-shrink-0" />
              <span class="text-slate-700 dark:text-slate-300">
                {{ formatDate(tooltipActivity.scheduled_at) }} às {{ formatTime(tooltipActivity.scheduled_at) }}
              </span>
            </div>

            <!-- Pipeline (se disponível) -->
            <div v-if="tooltipActivity.pipeline" class="flex items-center gap-2 text-xs">
              <fluent-icon icon="kanban" size="12" class="text-slate-400 dark:text-slate-500 flex-shrink-0" />
              <span class="text-slate-700 dark:text-slate-300 truncate">
                {{ tooltipActivity.pipeline.name }}
                <template v-if="tooltipActivity.pipeline.stage_id">
                  · {{ tooltipActivity.pipeline.stage_id }}
                </template>
              </span>
            </div>

            <!-- Tipo -->
            <div class="flex items-center gap-2 text-xs">
              <fluent-icon icon="tag" size="12" class="text-slate-400 dark:text-slate-500 flex-shrink-0" />
              <span class="text-slate-700 dark:text-slate-300">
                {{ tooltipActivity.activity_type === 'scheduled_message' ? 'Mensagem Agendada' : 'Tarefa' }}
              </span>
            </div>
          </div>

          <!-- Seta do tooltip (apenas se tooltip estiver acima) -->
          <div v-if="tooltipAbove" class="absolute bottom-0 left-1/2 transform -translate-x-1/2 translate-y-full w-0 h-0 border-l-8 border-r-8 border-t-8 border-transparent border-t-slate-200 dark:border-t-slate-700"></div>
          <div v-if="tooltipAbove" class="absolute bottom-0 left-1/2 transform -translate-x-1/2 translate-y-full -mb-1 w-0 h-0 border-l-8 border-r-8 border-t-8 border-transparent border-t-white dark:border-t-slate-800"></div>
          <!-- Seta do tooltip (se tooltip estiver abaixo) -->
          <div v-else class="absolute top-0 left-1/2 transform -translate-x-1/2 -translate-y-full w-0 h-0 border-l-8 border-r-8 border-b-8 border-transparent border-b-slate-200 dark:border-b-slate-700"></div>
          <div v-else class="absolute top-0 left-1/2 transform -translate-x-1/2 -translate-y-full mt-1 w-0 h-0 border-l-8 border-r-8 border-b-8 border-transparent border-b-white dark:border-b-slate-800"></div>
        </div>
      </transition>
    </div>
  </div>
</template>

<script>
import FluentIcon from 'shared/components/FluentIcon/DashboardIcon.vue';
import Spinner from 'shared/components/Spinner.vue';
import ActivityFormModal from './ActivityFormModal.vue';
import ActivityDetailModal from '../../activities/components/ActivityDetailModal.vue';
import { useAlert } from 'dashboard/composables';
import { mapGetters } from 'vuex';
import {
  startOfMonth,
  endOfMonth,
  startOfWeek,
  endOfWeek,
  eachDayOfInterval,
  format,
  isSameDay,
  isSameMonth,
  isToday,
  addMonths,
  subMonths,
  differenceInDays,
  startOfToday,
  isPast,
  parseISO,
  startOfDay,
  endOfDay,
} from 'date-fns';
import { ptBR } from 'date-fns/locale';

export default {
  name: 'ActivitiesCalendar',
  components: {
    FluentIcon,
    Spinner,
    ActivityFormModal,
    ActivityDetailModal,
  },
  props: {
    pipelineId: {
      type: [Number, String],
      default: null,
    },
    showCreateButton: {
      type: Boolean,
      default: true,
    },
    showOnboardingButton: {
      type: Boolean,
      default: false,
    },
    onOpenOnboarding: {
      type: Function,
      default: null,
    },
  },
  data() {
    return {
      currentDate: new Date(),
      currentView: 'month',
      availableViews: [
        { id: 'month', label: 'Mês', icon: 'calendar' },
        { id: 'list', label: 'Lista', icon: 'list' },
      ],
      weekDays: ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'],
      filters: {
        status: 'all',
        type: 'all',
        assigneeId: 'all',
        userId: 'all',
        dateFrom: '',
        dateTo: '',
      },
      searchQuery: '',
      searchTerm: '',
      loading: false,
      showFormModal: false,
      showDetailModal: false,
      selectedActivity: null,
      showFiltersDropdown: false,
      showQuickSearch: false,
      tooltipActivity: null,
      tooltipPosition: { x: 0, y: 0 },
      tooltipAbove: true,
      showDayModal: false,
      selectedDay: null,
    };
  },
  computed: {
    ...mapGetters({
      agents: 'agents/getAgents',
      currentUser: 'getCurrentUser',
      activitiesMeta: 'activities/getActivitiesMeta',
    }),
    activities() {
      if (!this.$store.state.activities) return [];
      return this.$store.state.activities.records || [];
    },
    currentMonthLabel() {
      return format(this.currentDate, 'MMMM yyyy', { locale: ptBR });
    },
    calendarDays() {
      const monthStart = startOfMonth(this.currentDate);
      const monthEnd = endOfMonth(this.currentDate);
      const calendarStart = startOfWeek(monthStart);
      const calendarEnd = endOfWeek(monthEnd);

      const days = eachDayOfInterval({ start: calendarStart, end: calendarEnd });

      return days.map(date => {
        const dayActivities = this.getActivitiesForDay(date);
        return {
          date: date.toISOString(),
          dayNumber: format(date, 'd'),
          isCurrentMonth: isSameMonth(date, this.currentDate),
          isToday: isToday(date),
          activities: dayActivities,
          activitiesCount: dayActivities.length,
        };
      });
    },
    filteredActivities() {
      let result = [...this.activities];

      // Filtro de status
      if (this.filters.status !== 'all') {
        if (this.filters.status === 'overdue') {
          result = result.filter(a => {
            const scheduledDate = parseISO(a.scheduled_at);
            return a.status === 'pending' && isPast(scheduledDate);
          });
        } else {
          result = result.filter(a => a.status === this.filters.status);
        }
      }

      // Filtro de tipo
      if (this.filters.type !== 'all') {
        result = result.filter(a => a.activity_type === this.filters.type);
      }

      // Busca
      if (this.searchTerm) {
        const searchLower = this.searchTerm.toLowerCase();
        result = result.filter(a =>
          a.title.toLowerCase().includes(searchLower) ||
          a.description?.toLowerCase().includes(searchLower) ||
          a.contact?.name?.toLowerCase().includes(searchLower)
        );
      }

      return result;
    },
    // Atividades do mês selecionado (para modo lista - segue o filtro do mês)
    activitiesForCurrentMonth() {
      return this.filteredActivities.filter(activity => {
        if (!activity.scheduled_at) return false;
        const activityDate = parseISO(activity.scheduled_at);
        return isSameMonth(activityDate, this.currentDate);
      });
    },
    groupedActivities() {
      const groups = [];
      const today = startOfToday();

      // No modo lista: usar apenas atividades do mês selecionado
      const activitiesToGroup = this.currentView === 'list'
        ? this.activitiesForCurrentMonth
        : this.filteredActivities;

      // Agrupar por período
      const grouped = activitiesToGroup.reduce((acc, activity) => {
        const date = parseISO(activity.scheduled_at);
        const diffDays = differenceInDays(date, today);

        let key;
        if (diffDays < 0) {
          key = 'Atrasadas';
        } else if (diffDays === 0) {
          key = 'Hoje';
        } else if (diffDays === 1) {
          key = 'Amanhã';
        } else if (diffDays <= 7) {
          key = 'Esta Semana';
        } else if (diffDays <= 30) {
          key = 'Este Mês';
        } else {
          key = 'Futuros';
        }

        if (!acc[key]) {
          acc[key] = [];
        }
        acc[key].push(activity);
        return acc;
      }, {});

      // Ordenar grupos
      const order = ['Atrasadas', 'Hoje', 'Amanhã', 'Esta Semana', 'Este Mês', 'Futuros'];
      order.forEach(label => {
        if (grouped[label]) {
          groups.push({
            label,
            activities: grouped[label].sort((a, b) =>
              new Date(a.scheduled_at) - new Date(b.scheduled_at)
            ),
          });
        }
      });

      return groups;
    },
    filteredTotalCount() {
      if (this.searchTerm) {
        return this.filteredActivities.length;
      }
      return this.activitiesMeta?.count ?? this.filteredActivities.length;
    },
    filteredTotalLabel() {
      const key = this.searchTerm
        ? 'ACTIVITIES.FILTERS.TOTAL_SEARCH'
        : 'ACTIVITIES.FILTERS.TOTAL';
      return this.$t(key, { count: this.filteredTotalCount });
    },
    hasActiveFilters() {
      return (
        this.filters.status !== 'all'
        || this.filters.type !== 'all'
        || this.filters.assigneeId !== 'all'
        || this.filters.userId !== 'all'
        || this.filters.dateFrom !== ''
        || this.filters.dateTo !== ''
        || this.searchQuery !== ''
      );
    },
    activeFiltersCount() {
      let count = 0;
      if (this.filters.status !== 'all') count++;
      if (this.filters.type !== 'all') count++;
      if (this.filters.assigneeId !== 'all') count++;
      if (this.filters.userId !== 'all') count++;
      if (this.filters.dateFrom !== '') count++;
      if (this.filters.dateTo !== '') count++;
      if (this.searchQuery !== '') count++;
      return count;
    },
    selectedDayActivities() {
      if (!this.selectedDay?.date) return [];
      const date = new Date(this.selectedDay.date);
      return this.getActivitiesForDay(date);
    },
  },
  watch: {
    currentDate() {
      this.loadActivities();
    },
    'filters.status'() {
      this.loadActivities();
    },
    'filters.type'() {
      this.loadActivities();
    },
    'filters.assigneeId'() {
      this.loadActivities();
    },
    'filters.userId'() {
      this.loadActivities();
    },
    'filters.dateFrom'() {
      this.loadActivities();
    },
    'filters.dateTo'() {
      this.loadActivities();
    },
  },
  mounted() {
    this.$store.dispatch('agents/get');
    this.applyRouteQueryFilters();
    this.loadActivities();
  },
  methods: {
    applyRouteQueryFilters() {
      const { assignee_id: assigneeId, status } = this.$route.query;
      if (assigneeId) {
        this.filters.assigneeId = assigneeId;
      }
      if (status === 'overdue') {
        this.filters.status = 'overdue';
      }
    },
    buildLoadParams() {
      const params = {};

      if (this.filters.dateFrom || this.filters.dateTo) {
        if (this.filters.dateFrom) {
          params.scheduled_from = startOfDay(parseISO(this.filters.dateFrom)).toISOString();
        }
        if (this.filters.dateTo) {
          params.scheduled_to = endOfDay(parseISO(this.filters.dateTo)).toISOString();
        }
      } else {
        const monthStart = startOfMonth(this.currentDate);
        const monthEnd = endOfMonth(this.currentDate);
        const rangeStart = startOfWeek(monthStart);
        const rangeEnd = endOfWeek(monthEnd);
        params.scheduled_from = rangeStart.toISOString();
        params.scheduled_to = rangeEnd.toISOString();
      }

      if (this.filters.status !== 'all') params.status = this.filters.status;
      if (this.filters.type !== 'all') params.activity_type = this.filters.type;
      if (this.filters.assigneeId !== 'all') params.assignee_id = this.filters.assigneeId;
      if (this.filters.userId !== 'all') params.user_id = this.filters.userId;
      return params;
    },
    async loadActivities() {
      this.loading = true;
      try {
        await this.$store.dispatch('activities/get', {
          params: this.buildLoadParams(),
          merge: false,
        });
      } catch (error) {
        useAlert(this.$t('ACTIVITIES.ERRORS.LOAD_FAILED'));
      } finally {
        this.loading = false;
      }
    },
    getActivitiesForDay(date) {
      return this.filteredActivities
        .filter(activity => {
          if (!activity.scheduled_at) return false;
          const activityDate = parseISO(activity.scheduled_at);
          return isSameDay(activityDate, date);
        })
        .sort((a, b) => new Date(a.scheduled_at) - new Date(b.scheduled_at));
    },
    previousMonth() {
      this.currentDate = subMonths(this.currentDate, 1);
    },
    nextMonth() {
      this.currentDate = addMonths(this.currentDate, 1);
    },
    goToToday() {
      this.currentDate = new Date();
    },
    selectDay(day) {
      this.selectedDay = day;
      this.showDayModal = true;
    },
    closeDayModal() {
      this.showDayModal = false;
      this.selectedDay = null;
    },
    openCreateModal() {
      this.selectedActivity = null;
      this.showFormModal = true;
    },
    openActivityDetail(activity) {
      this.selectedActivity = activity;
      this.showDetailModal = true;
    },
    openEditFromDetail(activity) {
      this.selectedActivity = activity;
      this.showDetailModal = false;
      this.showFormModal = true;
    },
    closeDetailModal() {
      this.showDetailModal = false;
      this.selectedActivity = null;
    },
    closeFormModal() {
      this.showFormModal = false;
      this.selectedActivity = null;
    },
    async handleActivitySubmit({ activity, inbox_id }) {
      try {
        const action = this.selectedActivity ? 'update' : 'create';
        await this.$store.dispatch(`activities/${action}`, {
          activityId: this.selectedActivity?.id,
          params: { ...activity, inbox_id },
        });
        this.closeFormModal();
        await this.loadActivities();
        useAlert(this.$t('ACTIVITIES.SUCCESS.SAVED'));
      } catch (error) {
        useAlert(this.$t('ACTIVITIES.ERRORS.SAVE_FAILED'));
      }
    },
    async completeActivity(activityId) {
      try {
        await this.$store.dispatch('activities/complete', { activityId });
        this.closeDetailModal();
        await this.loadActivities();
      } catch (error) {
        useAlert(this.$t('ACTIVITIES.ERRORS.COMPLETE_FAILED'));
      }
    },
    async deleteActivity(activityId) {
      try {
        await this.$store.dispatch('activities/destroy', { activityId });
        this.closeDetailModal();
        this.closeFormModal();
        this.closeDayModal();
        await this.loadActivities();
        useAlert(this.$t('ACTIVITIES.SUCCESS.DELETED'));
      } catch (error) {
        useAlert(this.$t('ACTIVITIES.ERRORS.DELETE_FAILED'));
      }
    },
    debouncedSearch() {
      // Debounce simples
      clearTimeout(this._searchTimeout);
      this._searchTimeout = setTimeout(() => {
        this.searchTerm = this.searchQuery;
      }, 300);
    },
    formatDate(dateString) {
      return format(parseISO(dateString), "d 'de' MMMM", { locale: ptBR });
    },
    formatTime(dateString) {
      return format(parseISO(dateString), 'HH:mm');
    },
    getActivityClass(activity) {
      const scheduledDate = parseISO(activity.scheduled_at);
      const isOverdue = activity.status === 'pending' && isPast(scheduledDate);

      if (isOverdue) {
        return 'bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400 border-l-2 border-red-500';
      }
      if (activity.status === 'completed') {
        return 'bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400 border-l-2 border-green-500';
      }
      if (activity.status === 'pending') {
        return 'bg-amber-100 dark:bg-amber-900/30 text-amber-700 dark:text-amber-400 border-l-2 border-amber-500';
      }
      if (activity.status === 'failed') {
        return 'bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400 border-l-2 border-red-600';
      }
      return 'bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-400 border-l-2 border-slate-400';
    },
    getActivityBorderClass(activity) {
      const scheduledDate = parseISO(activity.scheduled_at);
      const isOverdue = activity.status === 'pending' && isPast(scheduledDate);

      if (isOverdue) {
        return 'border-l-4 border-l-red-500';
      }
      if (activity.status === 'completed') {
        return 'border-l-4 border-l-green-500';
      }
      if (activity.status === 'pending') {
        return 'border-l-4 border-l-amber-500';
      }
      return 'border-l-4 border-l-slate-400';
    },
    getActivityIconBgClass(activity) {
      const scheduledDate = parseISO(activity.scheduled_at);
      const isOverdue = activity.status === 'pending' && isPast(scheduledDate);

      if (isOverdue) {
        return 'bg-red-100 dark:bg-red-900/30';
      }
      if (activity.status === 'completed') {
        return 'bg-green-100 dark:bg-green-900/30';
      }
      if (activity.status === 'pending') {
        return 'bg-amber-100 dark:bg-amber-900/30';
      }
      return 'bg-slate-100 dark:bg-slate-700';
    },
    getActivityIconColorClass(activity) {
      const scheduledDate = parseISO(activity.scheduled_at);
      const isOverdue = activity.status === 'pending' && isPast(scheduledDate);

      if (isOverdue) {
        return 'text-red-600 dark:text-red-400';
      }
      if (activity.status === 'completed') {
        return 'text-green-600 dark:text-green-400';
      }
      if (activity.status === 'pending') {
        return 'text-amber-600 dark:text-amber-400';
      }
      return 'text-slate-600 dark:text-slate-400';
    },
    getStatusBadgeClass(activity) {
      const scheduledDate = parseISO(activity.scheduled_at);
      const isOverdue = activity.status === 'pending' && isPast(scheduledDate);

      if (isOverdue) {
        return 'bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400';
      }
      if (activity.status === 'completed') {
        return 'bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400';
      }
      if (activity.status === 'pending') {
        return 'bg-amber-100 dark:bg-amber-900/30 text-amber-700 dark:text-amber-400';
      }
      return 'bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-400';
    },
    getCountBadgeClass(day) {
      const hasOverdue = day.activities.some(a => {
        const scheduledDate = parseISO(a.scheduled_at);
        return a.status === 'pending' && isPast(scheduledDate);
      });

      if (hasOverdue) {
        return 'bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400';
      }
      return 'bg-slate-100 dark:bg-slate-700 text-slate-700 dark:text-slate-300';
    },
    getStatusLabel(status) {
      const key = `ACTIVITIES.STATUS.${status.toUpperCase()}`;
      return this.$t(key) !== key ? this.$t(key) : status;
    },
    clearFilters() {
      this.filters.status = 'all';
      this.filters.type = 'all';
      this.filters.assigneeId = 'all';
      this.filters.userId = 'all';
      this.filters.dateFrom = '';
      this.filters.dateTo = '';
      this.searchQuery = '';
      this.searchTerm = '';
      this.loadActivities();
    },
    closeFiltersDropdown() {
      this.showFiltersDropdown = false;
    },
    closeQuickSearch() {
      if (!this.searchQuery) {
        this.showQuickSearch = false;
      }
    },
    showTooltip(activity, event) {
      this.tooltipActivity = activity;
      this.$nextTick(() => {
        const rect = event.currentTarget.getBoundingClientRect();
        const tooltipWidth = 320; // largura máxima do tooltip
        const tooltipHeight = 200; // altura estimada
        const viewportWidth = window.innerWidth;
        const viewportHeight = window.innerHeight;
        
        let x = rect.left + rect.width / 2;
        let y = rect.top - 10;
        let above = true;
        
        // Ajustar horizontalmente se sair da tela
        if (x - tooltipWidth / 2 < 10) {
          x = tooltipWidth / 2 + 10;
        } else if (x + tooltipWidth / 2 > viewportWidth - 10) {
          x = viewportWidth - tooltipWidth / 2 - 10;
        }
        
        // Ajustar verticalmente se sair da tela (mostrar abaixo se necessário)
        if (y - tooltipHeight < 10) {
          y = rect.bottom + 10;
          above = false;
        }
        
        this.tooltipPosition = { x, y };
        this.tooltipAbove = above;
      });
    },
    hideTooltip() {
      this.tooltipActivity = null;
    },
  },
  directives: {
    onClickaway: require('vue-clickaway').directive,
  },
};
</script>

<style scoped lang="scss">
.activities-calendar-container {
  min-height: calc(100vh - 80px);
  height: 100vh;
  overflow-y: auto;
  overflow-x: hidden;
}

.calendar-header {
  backdrop-filter: blur(8px);
}

.calendar-grid {
  @apply grid-cols-7;

  .calendar-day:nth-child(7n) {
    @apply border-r-0;
  }

  .calendar-day:nth-last-child(-n+7) {
    @apply border-b-0;
  }
}

.activity-card-mini {
  @apply hover:shadow-sm;
  
  &:hover {
    transform: translateY(-1px);
    z-index: 10;
  }
}

.activity-tooltip {
  animation: tooltip-fade-in 0.15s ease-out;
}

@keyframes tooltip-fade-in {
  from {
    opacity: 0;
    transform: translate(-50%, -100%) scale(0.95);
  }
  to {
    opacity: 1;
    transform: translate(-50%, -100%) scale(1);
  }
}

.line-clamp-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
</style>
