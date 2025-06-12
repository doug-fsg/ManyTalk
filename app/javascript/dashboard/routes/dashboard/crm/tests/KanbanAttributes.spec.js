import { shallowMount, createLocalVue } from '@vue/test-utils';
import Vuex from 'vuex';
import KanbanAttributes from '../components/KanbanAttributes.vue';
import KanbanColumn from '../components/KanbanColumn.vue';
import draggable from 'vuedraggable';

const localVue = createLocalVue();
localVue.use(Vuex);
localVue.component('draggable', draggable);

describe('KanbanAttributes.vue', () => {
  let wrapper;
  let store;
  let actions;
  let getters;

  beforeEach(() => {
    actions = {
      'contacts/update': vi.fn(),
      'contacts/get': vi.fn(),
      'attributes/get': vi.fn(),
    };

    getters = {
      'contacts/getContacts': () => [
        { 
          id: 1, 
          name: 'Test Contact 1',
          custom_attributes: { 'pipeline-123': '1ºcontato' }
        },
        { 
          id: 2, 
          name: 'Test Contact 2',
          custom_attributes: { 'pipeline-123': '2ºcontato' }
        }
      ],
      'contacts/getMeta': () => ({ count: 2 }),
      'attributes/getAttributes': () => [
        {
          id: 1,
          attribute_display_name: 'Pipeline Test',
          attribute_key: 'pipeline-123',
          attribute_display_type: 'list',
          attribute_values: ['1ºcontato', '2ºcontato']
        }
      ],
      'attributes/getUIFlags': () => ({ isFetching: false }),
    };

    store = new Vuex.Store({
      actions,
      getters,
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
      },
    });
  });

  afterEach(() => {
    wrapper.destroy();
  });

  it('should initialize with correct data', () => {
    expect(wrapper.vm.columns).toBeDefined();
    expect(wrapper.vm.selectedAttribute).toBeDefined();
    expect(wrapper.vm.operationManager).toBeDefined();
  });

  it('should setup columns correctly when attribute is selected', async () => {
    await wrapper.vm.selectAttribute({
      attribute_key: 'pipeline-123',
      attribute_values: ['1ºcontato', '2ºcontato']
    });
    
    expect(wrapper.vm.columns.length).toBe(2);
    expect(wrapper.vm.columns[0].items.length).toBe(1);
  });

  it('should handle card movement correctly', async () => {
    const contact = { 
      id: 1, 
      name: 'Test Contact',
      custom_attributes: { 'pipeline-123': '1ºcontato' }
    };
    
    await wrapper.vm.onItemMoved({
      contactId: 1,
      sourceColumnId: 'column-0',
      targetColumnId: 'column-1',
      sourceColumnTitle: '1ºcontato',
      targetColumnTitle: '2ºcontato'
    });

    expect(actions['contacts/update']).toHaveBeenCalled();
  });

  it('should handle errors during card movement', async () => {
    actions['contacts/update'].mockRejectedValue(new Error('Update failed'));
    
    await wrapper.vm.onItemMoved({
      contactId: 1,
      sourceColumnId: 'column-0',
      targetColumnId: 'column-1',
      sourceColumnTitle: '1ºcontato',
      targetColumnTitle: '2ºcontato'
    });

    expect(wrapper.vm.operationManager.hasOperationFailed(1)).toBe(true);
  });
});
