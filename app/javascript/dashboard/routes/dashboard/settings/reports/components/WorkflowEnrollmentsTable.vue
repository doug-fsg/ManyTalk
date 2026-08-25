<script>
import { VeTable, VePagination } from 'vue-easytable';
import UserAvatarWithName from 'dashboard/components/widgets/UserAvatarWithName.vue';
import { mapGetters } from 'vuex';
import { messageStamp, dynamicTime } from 'shared/helpers/timeHelper';

export default {
  name: 'WorkflowEnrollmentsTable',
  components: {
    VeTable,
    VePagination,
  },
  props: {
    pageIndex: {
      type: Number,
      default: 1,
    },
    enrollments: {
      type: Array,
      default: () => [],
    },
    totalCount: {
      type: Number,
      default: 0,
    },
  },
  computed: {
    ...mapGetters({
      isRTL: 'accounts/isRTL',
    }),
    columns() {
      const align = this.isRTL ? 'right' : 'left';
      return [
        {
          field: 'contact',
          key: 'contact',
          title: this.$t('WORKFLOW_REPORTS.TABLE.HEADER.CONTACT'),
          align,
          width: 180,
          renderBodyCell: ({ row }) => {
            if (row.contact) {
              return (
                <UserAvatarWithName
                  textClass="text-sm text-slate-800"
                  size="24px"
                  user={row.contact}
                />
              );
            }
            return '---';
          },
        },
        {
          field: 'workflowName',
          key: 'workflowName',
          title: this.$t('WORKFLOW_REPORTS.TABLE.HEADER.WORKFLOW'),
          align,
          width: 160,
        },
        {
          field: 'enrollmentStatusLabel',
          key: 'enrollmentStatus',
          title: this.$t('WORKFLOW_REPORTS.TABLE.HEADER.FLOW_STATUS'),
          align,
          width: 120,
        },
        {
          field: 'conversationStatusLabel',
          key: 'conversationStatus',
          title: this.$t('WORKFLOW_REPORTS.TABLE.HEADER.CONVERSATION_STATUS'),
          align,
          width: 120,
        },
        {
          field: 'assignedAgent',
          key: 'assignedAgent',
          title: this.$t('WORKFLOW_REPORTS.TABLE.HEADER.ASSIGNEE'),
          align,
          width: 180,
          renderBodyCell: ({ row }) => {
            if (row.assignedAgent) {
              return <UserAvatarWithName size="24px" user={row.assignedAgent} />;
            }
            return '---';
          },
        },
        {
          field: 'startedBy',
          key: 'startedBy',
          title: this.$t('WORKFLOW_REPORTS.TABLE.HEADER.TRIGGERED_BY'),
          align,
          width: 180,
          renderBodyCell: ({ row }) => {
            if (row.startedBy) {
              return <UserAvatarWithName size="24px" user={row.startedBy} />;
            }
            return this.$t('WORKFLOW_REPORTS.TABLE.TRIGGERED_AUTOMATIC');
          },
        },
        {
          field: 'currentNodeLabel',
          key: 'currentNodeLabel',
          title: this.$t('WORKFLOW_REPORTS.TABLE.HEADER.STEP'),
          align,
          width: 160,
        },
        {
          field: 'conversationId',
          key: 'conversationId',
          title: '',
          align,
          width: 140,
          renderBodyCell: ({ row }) => {
            if (!row.conversationId) return '---';
            const routerParams = {
              name: 'inbox_conversation',
              params: { conversation_id: row.conversationId },
            };
            return (
              <div class="text-right">
                <router-link
                  to={routerParams}
                  class="inline-flex items-center px-2 py-1 text-xs font-medium rounded-md border border-woot-200 text-woot-500 hover:bg-woot-25 dark:border-woot-700 dark:hover:bg-slate-800"
                >
                  {this.$t('WORKFLOW_REPORTS.TABLE.GO_TO_CONVERSATION')}
                </router-link>
                <div class="workflow-report--timestamp" v-tooltip={row.startedAt}>
                  {row.startedAgo}
                </div>
              </div>
            );
          },
        },
      ];
    },
    tableData() {
      return this.enrollments.map(enrollment => ({
        contact: enrollment.contact,
        workflowName: enrollment.workflow_name || '---',
        enrollmentStatusLabel: this.enrollmentStatusLabel(enrollment.status),
        conversationStatusLabel: this.conversationStatusLabel(
          enrollment.conversation_status
        ),
        assignedAgent: enrollment.assigned_agent,
        startedBy: enrollment.started_by,
        currentNodeLabel: enrollment.current_node_label || '---',
        conversationId: enrollment.conversation_id,
        startedAgo: dynamicTime(enrollment.started_at),
        startedAt: messageStamp(enrollment.started_at, 'LLL d yyyy, h:mm a'),
      }));
    },
  },
  methods: {
    enrollmentStatusLabel(status) {
      const key = `WORKFLOW.REGUA.STATUS_${String(status || '').toUpperCase()}`;
      return this.$te(key) ? this.$t(key) : status || '---';
    },
    conversationStatusLabel(status) {
      const key = `CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.${status}.TEXT`;
      return this.$te(key) ? this.$t(key) : status || '---';
    },
    onPageNumberChange(pageIndex) {
      this.$emit('pageChange', pageIndex);
    },
  },
};
</script>

<template>
  <div class="workflow-report--table-container">
    <VeTable
      max-height="calc(100vh - 21.875rem)"
      fixed-header
      border-around
      :columns="columns"
      :table-data="tableData"
    />
    <div
      v-show="!tableData.length"
      class="workflow-report--empty-records"
    >
      {{ $t('WORKFLOW_REPORTS.TABLE.NO_RECORDS') }}
    </div>
    <div
      v-if="totalCount"
      class="table-pagination"
    >
      <VePagination
        :total="totalCount"
        :page-index="pageIndex"
        :page-size="25"
        :page-size-option="[25]"
        @on-page-number-change="onPageNumberChange"
      />
    </div>
  </div>
</template>

<style lang="scss" scoped>
.workflow-report--table-container {
  display: flex;
  flex-direction: column;
  flex: 1;

  .ve-table {
    @apply bg-white dark:bg-slate-900;

    &::v-deep {
      .ve-table-container {
        border-radius: var(--border-radius-normal);
      }

      th.ve-table-header-th {
        font-size: var(--font-size-mini) !important;
        padding: var(--space-normal) !important;
      }

      td.ve-table-body-td {
        padding: var(--space-small) var(--space-normal) !important;
      }
    }
  }

  &::v-deep .ve-pagination {
    background-color: transparent;
  }

  &::v-deep .ve-pagination-select {
    display: none;
  }

  .table-pagination {
    margin-top: var(--space-normal);
    text-align: right;
  }
}

.workflow-report--empty-records {
  align-items: center;
  border-top: 0;
  display: flex;
  font-size: var(--font-size-small);
  height: 12.5rem;
  justify-content: center;
  margin-top: -1px;
  width: 100%;
  @apply text-slate-600 dark:text-slate-200 bg-white dark:bg-slate-900 border border-t-0 border-solid border-slate-75 dark:border-slate-700;
}

.workflow-report--timestamp {
  @apply text-slate-600 dark:text-slate-200 text-sm mt-1;
}
</style>
