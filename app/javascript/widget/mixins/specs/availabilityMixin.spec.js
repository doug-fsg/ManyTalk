import { mount } from '@vue/test-utils';
import availabilityMixin from '../availability';

global.chatwootWebChannel = {
  workingHoursEnabled: true,
  workingHours: [
    {
      day_of_week: 3,
      closed_all_day: false,
      open_hour: 8,
      open_minutes: 30,
      close_hour: 17,
      close_minutes: 35,
      open_all_day: false,
    },
    {
      day_of_week: 4,
      closed_all_day: false,
      open_hour: 8,
      open_minutes: 30,
      close_hour: 17,
      close_minutes: 30,
      open_all_day: false,
    },
  ],
  utcOffset: '-07:00',
};

describe('availabilityMixin', () => {
  beforeEach(() => {
    vi.useRealTimers();
  });

  it('returns valid isInBetweenWorkingHours if in different timezone', () => {
    const Component = {
      render() {},
      mixins: [availabilityMixin],
    };
    vi.useFakeTimers('modern').setSystemTime(
      new Date('Thu Apr 14 2022 06:04:46 GMT+0530')
    );
    const wrapper = mount(Component);
    expect(wrapper.vm.isInBetweenTheWorkingHours).toBe(true);
  });

  it('returns valid isInBetweenWorkingHours if in same timezone', () => {
    global.chatwootWebChannel.utcOffset = '+05:30';
    const Component = {
      render() {},
      mixins: [availabilityMixin],
    };
    vi.useFakeTimers('modern').setSystemTime(
      new Date('Thu Apr 14 2022 09:01:46 GMT+0530')
    );
    const wrapper = mount(Component);
    expect(wrapper.vm.isInBetweenTheWorkingHours).toBe(true);
  });

  it('returns false if closed all day', () => {
    const Component = {
      render() {},
      mixins: [availabilityMixin],
    };
    global.chatwootWebChannel.utcOffset = '-07:00';
    global.chatwootWebChannel.workingHours = [
      { day_of_week: 3, closed_all_day: true },
    ];
    vi.useFakeTimers('modern').setSystemTime(
      new Date('Thu Apr 14 2022 09:01:46 GMT+0530')
    );

    const wrapper = mount(Component);
    expect(wrapper.vm.isInBetweenTheWorkingHours).toBe(false);
  });

  it('returns true if open all day', () => {
    const Component = {
      render() {},
      mixins: [availabilityMixin],
    };
    global.chatwootWebChannel.utcOffset = '-07:00';
    global.chatwootWebChannel.workingHours = [
      { day_of_week: 3, open_all_day: true },
    ];
    vi.useFakeTimers('modern').setSystemTime(
      new Date('Thu Apr 14 2022 09:01:46 GMT+0530')
    );

    const wrapper = mount(Component);
    expect(wrapper.vm.isInBetweenTheWorkingHours).toBe(true);
  });
});
