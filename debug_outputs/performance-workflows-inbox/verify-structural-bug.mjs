/**
 * Red-capable loop: structural workflow inbox bug still present?
 * Run from repo root: node debug_outputs/performance-workflows-inbox/verify-structural-bug.mjs
 * Exit 1 = bug present. Exit 0 = fixed.
 */
import { createRequire } from 'module';
import { readFileSync } from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '../..');
const require = createRequire(import.meta.url);
const Vue = require(path.join(ROOT, 'node_modules/vue'));

const CHATLIST = path.join(ROOT, 'app/javascript/dashboard/components/ChatList.vue');
const SUMMARY = path.join(ROOT, 'app/services/workflows/enrollment_summary_service.rb');
const TIMELINE = path.join(ROOT, 'app/services/workflows/timeline_builder.rb');
const HELPER = path.join(
  ROOT,
  'app/javascript/dashboard/helper/workflowEnrollmentSummaryFetch.js'
);

const findings = [];

function claim(name, stillBroken, evidence) {
  findings.push({ name, stillBroken, evidence });
  const tag = stillBroken ? 'RED ' : 'GREEN';
  console.log(`${tag} ${name}`);
  console.log(`     ${evidence}`);
}

const chatList = readFileSync(CHATLIST, 'utf8');
const helper = readFileSync(HELPER, 'utf8');
const summarySrc = readFileSync(SUMMARY, 'utf8');
const timelineSrc = readFileSync(TIMELINE, 'utf8');

claim(
  'ChatList conversationList watcher is deep and always refetches',
  /conversationList:\s*\{[\s\S]*?deep:\s*true/.test(chatList) &&
    /debouncedFetchEnrollmentSummaries/.test(
      (chatList.match(/conversationList:\s*\{[\s\S]*?handler\(\)\s*\{([\s\S]*?)\}/) || [
        '',
        '',
      ])[1]
    ),
  'expected visibleConversationIdsKey watcher without deep:true'
);

claim(
  'workflow_enrollment.updated still refetches the whole visible list',
  /onWorkflowEnrollmentUpdated\(payload\)[\s\S]*?debouncedFetchEnrollmentSummaries\(\)/.test(
    chatList
  ) && !/applyEnrollmentCableUpdate/.test(chatList),
  'expected local applyEnrollmentCableUpdate, not list refetch'
);

claim(
  'EnrollmentSummaryService badge path walks full TimelineBuilder',
  /TimelineBuilder\.new\(enrollment\)\.step_counts/.test(summarySrc) &&
    /def step_counts\s+meta = build/.test(timelineSrc.replace(/\r/g, '')),
  'expected list summary without TimelineBuilder#step_counts'
);

claim(
  'Helper does not compare visible ids before fetch',
  !/export function shouldFetchEnrollmentSummaries/.test(helper) ||
    !/export function visibleConversationIdsKey/.test(helper),
  'expected visibleConversationIdsKey helper'
);

function flush() {
  return new Promise(resolve => Vue.nextTick(resolve));
}

function makeVm() {
  return new Vue({
    data() {
      return {
        fetchCount: 0,
        allConversations: [
          {
            id: 101,
            unread_count: 0,
            last_activity_at: 1000,
            status: 'open',
            meta: { assignee: { id: 1 } },
          },
          {
            id: 102,
            unread_count: 0,
            last_activity_at: 900,
            status: 'open',
            meta: { assignee: { id: 1 } },
          },
        ],
      };
    },
    computed: {
      conversationList() {
        return [...this.allConversations]
          .filter(c => c.meta?.assignee?.id === 1 && c.status === 'open')
          .sort((a, b) => b.last_activity_at - a.last_activity_at);
      },
      visibleConversationIdsKey() {
        return this.conversationList
          .map(c => c.id)
          .slice(0, 50)
          .sort((a, b) => Number(a) - Number(b))
          .join(',');
      },
    },
    watch: {
      visibleConversationIdsKey() {
        this.fetchCount += 1;
      },
    },
  });
}

const vm = makeVm();
await flush();
vm.fetchCount = 0;
vm.allConversations[0].unread_count = 7;
vm.allConversations[0].last_activity_at = 2000;
await flush();

claim(
  'ID-key watcher still refetches on unread/last_activity with same ids',
  vm.fetchCount !== 0,
  `fetchCount=${vm.fetchCount} key=${vm.visibleConversationIdsKey}`
);

const red = findings.filter(f => f.stillBroken);
console.log('\n---');
console.log(
  `BUG STRUCTURAL: ${red.length}/${findings.length} claims still true in this tree`
);
process.exit(red.length ? 1 : 0);
