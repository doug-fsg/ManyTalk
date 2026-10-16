import { shallowMount, createLocalVue } from '@vue/test-utils';
import Vuex from 'vuex';
import KanbanAttributes from '../components/KanbanAttributes.vue';
import KanbanColumn from '../components/KanbanColumn.vue';
import draggable from 'vuedraggable';
import ContactAPI from 'dashboard/api/contacts';

vi.mock('dashboard/api/contacts', () => ({
  default: {
    updatePipelinePosition: vi.fn(),
    reorderPipelinePositions: vi.fn(),
  },
}));

const localVue = createLocalVue();
localVue.use(Vuex);
localVue.component('draggable', draggable);

const pipelineId = 1;

const contactsWithPositions = [
  {
    id: 1,
    name: 'Test Contact 1',
    pipeline_positions: [
      { pipeline_id: pipelineId, stage_id: '1ºcontato', position: 0 },
    ],
  },
  {
    id: 2,
    name: 'Test Contact 2',
    pipeline_positions: [
      { pipeline_id: pipelineId, stage_id: '2ºcontato', position: 0 },
    ],
  },
];

describe('KanbanAttributes.vue', () => {
  let wrapper;
  let store;
  let actions;
  let getters;

  beforeEach(() => {
    actions = {
      'contacts/get': vi.fn(),
      'attributes/get': vi.fn(),
    };

    getters = {
      'contacts/getContacts': () => contactsWithPositions,
      'contacts/getMeta': () => ({ count: 2 }),
      'attributes/getAttributes': () => [
        {
          id: pipelineId,
          attribute_display_name: 'Pipeline Test',
          attribute_key: 'pipeline-123',
          attribute_display_type: 'list',
          attribute_values: [
            { name: '1ºcontato', color: '#111111' },
            { name: '2ºcontato', color: '#222222' },
          ],
          is_kanban: true,
          can_view: true,
        },
      ],
      'attributes/getUIFlags': () => ({ isFetching: false }),
      'kanban/canEditPipeline': () => () => true,
      'kanban/canViewPipeline': () => () => true,
      'kanban/getPipelinePermission': () => () => 'editor',
    };

    store = new Vuex.Store({
      actions,
      getters,
    });

    ContactAPI.updatePipelinePosition.mockResolvedValue({
      data: {
        pipeline_id: pipelineId,
        stage_id: '2ºcontato',
        position: 0,
        entered_at: new Date().toISOString(),
        deal_value: null,
        metadata: {},
        assignee: null,
      },
    });
    ContactAPI.reorderPipelinePositions.mockResolvedValue({ status: 200 });

    wrapper = shallowMount(KanbanAttributes, {
      store,
      localVue,
      stubs: {
        KanbanColumn,
        draggable,
      },
      mocks: {
        $t: msg => msg,
        $bus: {
          $on: vi.fn(),
          $off: vi.fn(),
          $emit: vi.fn(),
        },
        $route: { params: { accountId: 1 } },
      },
    });
  });

  afterEach(() => {
    wrapper.destroy();
    vi.clearAllMocks();
  });

  it('should initialize with correct data', () => {
    expect(wrapper.vm.columns).toBeDefined();
    expect(wrapper.vm.operationManager).toBeDefined();
  });

  it('should setup columns correctly when attribute is selected', async () => {
    await wrapper.vm.selectAttribute({
      id: pipelineId,
      attribute_key: 'pipeline-123',
      attribute_values: [
        { name: '1ºcontato', color: '#111111' },
        { name: '2ºcontato', color: '#222222' },
      ],
    });

    expect(wrapper.vm.columns.length).toBe(2);
    expect(wrapper.vm.columns[0].items.length).toBe(1);
  });

  it('should handle card movement correctly', async () => {
    wrapper.setData({
      selectedAttribute: {
        id: pipelineId,
        attribute_key: 'pipeline-123',
      },
      contacts: contactsWithPositions,
      columns: [
        {
          id: 'column-1ºcontato',
          title: '1ºcontato',
          items: [contactsWithPositions[0]],
        },
        {
          id: 'column-2ºcontato',
          title: '2ºcontato',
          items: [contactsWithPositions[1], contactsWithPositions[0]],
        },
      ],
    });

    await wrapper.vm.onItemMoved({
      contactId: 1,
      sourceColumnTitle: '1ºcontato',
      targetColumnTitle: '2ºcontato',
      oldIndex: 0,
      newIndex: 1,
    });

    expect(ContactAPI.reorderPipelinePositions).toHaveBeenCalled();
    const [, positions] = ContactAPI.reorderPipelinePositions.mock.calls[0];
    const moved = positions.find(p => p.contact_id === 1);
    expect(moved.entered_at).toBeTruthy();
    expect(moved.stage_id).toBe('2ºcontato');
  });

  it('same-stage reorder does not send entered_at and renumbers column', async () => {
    const a = {
      id: 10,
      name: 'A',
      pipeline_positions: [
        { pipeline_id: pipelineId, stage_id: '1ºcontato', position: 0, entered_at: '2024-01-01T00:00:00Z' },
      ],
    };
    const b = {
      id: 11,
      name: 'B',
      pipeline_positions: [
        { pipeline_id: pipelineId, stage_id: '1ºcontato', position: 1, entered_at: '2024-01-02T00:00:00Z' },
      ],
    };
    const c = {
      id: 12,
      name: 'C',
      pipeline_positions: [
        { pipeline_id: pipelineId, stage_id: '1ºcontato', position: 2, entered_at: '2024-01-03T00:00:00Z' },
      ],
    };

    wrapper.setData({
      selectedAttribute: { id: pipelineId, attribute_key: 'pipeline-123' },
      contacts: [a, b, c],
      columns: [
        {
          id: 'column-1ºcontato',
          title: '1ºcontato',
          items: [c, a, b],
        },
      ],
    });

    await wrapper.vm.onItemMoved({
      contactId: 12,
      sourceColumnTitle: '1ºcontato',
      targetColumnTitle: '1ºcontato',
      oldIndex: 2,
      newIndex: 0,
    });

    expect(ContactAPI.reorderPipelinePositions).toHaveBeenCalled();
    const [, positions] = ContactAPI.reorderPipelinePositions.mock.calls[0];
    expect(positions.map(p => p.contact_id)).toEqual([12, 10, 11]);
    expect(positions.map(p => p.position)).toEqual([0, 1, 2]);
    expect(positions.every(p => !p.entered_at)).toBe(true);
  });
});
