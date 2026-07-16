import { shallowMount, createLocalVue } from '@vue/test-utils';
import Vuex from 'vuex';
import KanbanAttributes from '../components/KanbanAttributes.vue';
import KanbanColumn from '../components/KanbanColumn.vue';
import draggable from 'vuedraggable';
import ContactAPI from 'dashboard/api/contacts';

vi.mock('dashboard/api/contacts', () => ({
  default: {
    updatePipelinePosition: vi.fn(),
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
    });

    await wrapper.vm.onItemMoved({
      contactId: 1,
      sourceColumnTitle: '1ºcontato',
      targetColumnTitle: '2ºcontato',
      oldIndex: 0,
      newIndex: 0,
    });

    expect(ContactAPI.updatePipelinePosition).toHaveBeenCalled();
  });
});
