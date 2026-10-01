/**
 * Shows refetch even without deep:true when getter returns new array after sort.
 * Run: node debug_outputs/performance-workflows-inbox/verify-getter-coupling.mjs
 */
import { createRequire } from 'module';
import path from 'path';
import { fileURLToPath } from 'url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const require = createRequire(import.meta.url);
const Vue = require(path.join(ROOT, 'node_modules/vue'));

function flush() {
  return new Promise(r => Vue.nextTick(r));
}

function makeVm(deep) {
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
        const filtered = this.allConversations
          .filter(
            c => c.meta.assignee?.id === 1 && c.status === 'open'
          )
          .sort((a, b) => b.last_activity_at - a.last_activity_at);
        return [...filtered];
      },
    },
    watch: {
      conversationList: {
        handler() {
          this.fetchCount += 1;
        },
        deep,
      },
    },
  });
}

const deepVm = makeVm(true);
const shallowVm = makeVm(false);
await flush();
deepVm.fetchCount = 0;
shallowVm.fetchCount = 0;

deepVm.allConversations[0].unread_count = 7;
shallowVm.allConversations[0].unread_count = 7;
await flush();
console.log(
  'unread_count  deep=',
  deepVm.fetchCount,
  'shallow=',
  shallowVm.fetchCount,
  'ids=',
  deepVm.conversationList.map(c => c.id).join(',')
);

deepVm.fetchCount = 0;
shallowVm.fetchCount = 0;
deepVm.allConversations[0].last_activity_at = 2000;
shallowVm.allConversations[0].last_activity_at = 2000;
await flush();
console.log(
  'last_activity deep=',
  deepVm.fetchCount,
  'shallow=',
  shallowVm.fetchCount,
  'ids=',
  deepVm.conversationList.map(c => c.id).join(',')
);

deepVm.fetchCount = 0;
shallowVm.fetchCount = 0;
Vue.set(deepVm.allConversations, 0, {
  ...deepVm.allConversations[0],
  unread_count: 8,
});
Vue.set(shallowVm.allConversations, 0, {
  ...shallowVm.allConversations[0],
  unread_count: 8,
});
await flush();
console.log('Vue.set row  deep=', deepVm.fetchCount, 'shallow=', shallowVm.fetchCount);
