# PATCH_PLAN — performance workflows inbox

**Plano completo:** [docs/plano-correcao-performance-workflows-inbox.md](../../docs/plano-correcao-performance-workflows-inbox.md)

**Aprovação necessária:** sim, antes de qualquer edit em `app/`.

---

## Patch mínimo (PR1 — frontend)

### `ChatList.vue`

1. Delete `deep: true` on `conversationList` watcher.
2. Add `data`: `lastVisibleConversationIdsKey: ''`.
3. Add computed `visibleConversationIdsKey()` from `conversationList.map(c => c.id).slice(0, 50).join(',')`.
4. Replace watcher target with `visibleConversationIdsKey` handler:
   - if `newKey === oldKey` return;
   - else `debouncedFetchEnrollmentSummaries()`.
5. `onWorkflowEnrollmentUpdated(payload)`:
   - build summary object from payload (mirror API shape);
   - `Vue.set` / assign `enrollmentSummaries[conversation_id]`;
   - on terminal status, delete key;
   - optional: if payload missing fields, `WorkflowEnrollmentSummariesAPI.getSummaries([id])` only.

### New file (test seam)

`app/javascript/dashboard/helper/workflowEnrollmentSummaryFetch.js` + Vitest.

---

## Patch mínimo (PR2 — backend)

### `EnrollmentSummaryService#summary_for`

Replace `TimelineBuilder.new(enrollment).step_counts` with list-safe fields only (node label/type from `current_node_id`).

### Spec

`spec/services/workflows/enrollment_summary_service_spec.rb` — expect no `TimelineBuilder#build` on list path.

---

## Verify

```bash
node debug_outputs/performance-workflows-inbox/verify-structural-bug.mjs  # → exit 0 after PR1+script update
pnpm test app/javascript/dashboard/helper/specs/workflowEnrollmentSummaryFetch.spec.js
bundle exec rspec spec/services/workflows/enrollment_summary_service_spec.rb
```

---

## Rollback

Revert merge; restart web. No migration.
