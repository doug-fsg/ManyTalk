import { describe, expect, it } from 'vitest';
import {
  buildFormWorkflowMap,
  resolveFormLinkage,
  linkageFromForm,
  effectivelyAutomates,
  LINKAGE_STATES,
} from '../formWorkflowLinkage';

const formCondition = formId => [
  {
    attribute_key: 'account_form_id',
    filter_operator: 'equal_to',
    values: [String(formId)],
    custom_attribute_type: '',
  },
];

const workflow = ({ id, name, active, formIds, manualOnly = false }) => ({
  id,
  name,
  active,
  trigger_event_name: 'form_submitted',
  graph: {
    nodes: [
      {
        id: 'trigger_1',
        type: 'trigger',
        data: {
          event_name: 'form_submitted',
          conditions: formCondition(formIds),
        },
      },
    ],
    edges: [],
    settings: {
      allow_manual_start_only: manualOnly,
    },
  },
});

describe('buildFormWorkflowMap', () => {
  it('returns contact_only when no workflows reference the form', () => {
    const map = buildFormWorkflowMap([
      workflow({ id: 1, name: 'Flow A', active: true, formIds: 10 }),
    ]);

    expect(resolveFormLinkage(map, 99)).toEqual({
      state: LINKAGE_STATES.CONTACT_ONLY,
      workflows: [],
    });
  });

  it('classifies active linked workflow as automates', () => {
    const map = buildFormWorkflowMap([
      workflow({ id: 1, name: 'Flow A', active: true, formIds: 5 }),
    ]);

    expect(resolveFormLinkage(map, 5)).toEqual({
      state: LINKAGE_STATES.AUTOMATES,
      workflows: [
        { id: 1, name: 'Flow A', active: true, manual_only: false },
      ],
    });
  });

  it('classifies inactive linked workflow as paused_flow', () => {
    const map = buildFormWorkflowMap([
      workflow({ id: 2, name: 'Flow B', active: false, formIds: 7 }),
    ]);

    expect(resolveFormLinkage(map, 7)).toEqual({
      state: LINKAGE_STATES.PAUSED_FLOW,
      workflows: [
        { id: 2, name: 'Flow B', active: false, manual_only: false },
      ],
    });
  });

  it('treats active manual-only workflows as paused_flow', () => {
    const map = buildFormWorkflowMap([
      workflow({
        id: 3,
        name: 'Manual',
        active: true,
        formIds: 8,
        manualOnly: true,
      }),
    ]);

    expect(resolveFormLinkage(map, 8).state).toBe(LINKAGE_STATES.PAUSED_FLOW);
    expect(effectivelyAutomates(resolveFormLinkage(map, 8).workflows[0])).toBe(
      false
    );
  });

  it('prefers automates when at least one linked workflow effectively automates', () => {
    const map = buildFormWorkflowMap([
      workflow({ id: 1, name: 'Inactive', active: false, formIds: 3 }),
      workflow({ id: 2, name: 'Active', active: true, formIds: 3 }),
    ]);

    expect(resolveFormLinkage(map, 3).state).toBe(LINKAGE_STATES.AUTOMATES);
    expect(resolveFormLinkage(map, 3).workflows).toHaveLength(2);
  });

  it('ignores workflows with other trigger events', () => {
    const map = buildFormWorkflowMap([
      {
        id: 9,
        name: 'Conversation flow',
        active: true,
        trigger_event_name: 'conversation_created',
        graph: {
          nodes: [
            {
              id: 'trigger_1',
              type: 'trigger',
              data: {
                event_name: 'conversation_created',
                conditions: formCondition(4),
              },
            },
          ],
        },
      },
    ]);

    expect(resolveFormLinkage(map, 4).state).toBe(LINKAGE_STATES.CONTACT_ONLY);
  });
});

describe('linkageFromForm', () => {
  it('uses API linkage_state when present', () => {
    const form = {
      id: 1,
      linkage_state: LINKAGE_STATES.AUTOMATES,
      linked_workflows: [{ id: 9, name: 'Flow', active: true, manual_only: false }],
    };

    expect(linkageFromForm(form)).toEqual({
      state: LINKAGE_STATES.AUTOMATES,
      workflows: form.linked_workflows,
    });
  });

  it('falls back to contact_only when API fields are absent', () => {
    expect(linkageFromForm({ id: 2 })).toEqual({
      state: LINKAGE_STATES.CONTACT_ONLY,
      workflows: [],
    });
  });
});
