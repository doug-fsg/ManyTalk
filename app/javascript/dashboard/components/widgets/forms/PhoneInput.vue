<template>
  <div class="phone-input--wrap relative">
    <div
      class="flex items-center dark:bg-slate-900 justify-start rounded-lg border border-solid transition-all duration-200 ease-smooth"
      :class="
        error
          ? 'border border-solid border-red-400 dark:border-red-400 mb-1'
          : 'mb-4 border-slate-200 dark:border-slate-600'
      "
    >
      <div
        ref="countrySelector"
        class="cursor-pointer py-2 pr-1.5 pl-2 rounded-tl-lg rounded-bl-lg flex items-center justify-center gap-1.5 bg-slate-25 dark:bg-slate-700 h-10 w-14 transition-colors duration-150 ease-smooth hover:bg-slate-50 dark:hover:bg-slate-600"
        @click.prevent="toggleCountryDropdown"
      >
        <span v-if="activeCountry" class="mb-0 text-base leading-none font-normal">
          {{ activeCountry.emoji }}
        </span>
        <fluent-icon v-else icon="globe" class="fluent-icon" size="16" />
        <fluent-icon icon="chevron-down" class="fluent-icon" size="12" />
      </div>
      <span
        v-if="activeDialCode"
        class="flex bg-white dark:bg-slate-900 text-slate-800 dark:text-slate-100 font-normal text-sm leading-normal py-2 pl-2 pr-0"
      >
        {{ activeDialCode }}
      </span>
      <input
        ref="phoneNumberInput"
        :value="phoneNumber"
        type="tel"
        inputmode="tel"
        class="!mb-0 !rounded-tl-none !rounded-bl-none !border-0 font-normal !w-full dark:!bg-slate-900 text-base !px-1.5 placeholder:font-normal"
        :placeholder="placeholder"
        :readonly="readonly"
        :style="styles"
        @input="onChange"
        @keydown="onPhoneKeydown"
        @blur="onBlur"
      />
    </div>
    <div
      v-if="showDropdown"
      ref="dropdown"
      v-on-clickaway="onOutsideClick"
      tabindex="0"
      :style="fixedCountryDropdown ? countryDropdownStyles : null"
      class="h-60 w-[12.5rem] shadow-soft-xl overflow-y-auto rounded-xl px-0 pt-0 pb-1 bg-white dark:bg-slate-900 animate-scale-in"
      :class="fixedCountryDropdown ? '' : 'z-10 absolute top-10'"
      @keydown.prevent.up="moveUp"
      @keydown.prevent.down="moveDown"
      @keydown.prevent.enter="
        onSelectCountry(filteredCountriesBySearch[selectedIndex])
      "
    >
      <div class="top-0 sticky bg-white dark:bg-slate-900 p-1">
        <input
          ref="searchbar"
          v-model="searchCountry"
          type="text"
          placeholder="Search"
          class="!h-8 !mb-0 !text-sm !border !border-solid !border-slate-200 dark:!border-slate-600"
          @input="onSearchCountry"
        />
      </div>
      <div
        v-for="(country, index) in filteredCountriesBySearch"
        ref="dropdownItem"
        :key="index"
        class="flex items-center h-7 py-0 px-1 cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors duration-150 ease-smooth rounded-lg"
        :class="{
          'bg-slate-50 dark:bg-slate-700': country.id === activeCountryCode,
          'bg-slate-25 dark:bg-slate-800': index === selectedIndex,
        }"
        @click="onSelectCountry(country)"
      >
        <span class="text-base mr-1">{{ country.emoji }}</span>

        <span
          class="max-w-[7.5rem] overflow-hidden text-ellipsis whitespace-nowrap"
        >
          {{ country.name }}
        </span>
        <span class="ml-1 text-slate-300 dark:text-slate-300 text-xs">{{
          country.dial_code
        }}</span>
      </div>
      <div v-if="filteredCountriesBySearch.length === 0">
        <span
          class="flex items-center justify-center text-sm text-slate-500 dark:text-slate-300 mt-4"
        >
          No results found
        </span>
      </div>
    </div>
  </div>
</template>

<script>
import countries from 'shared/constants/countries.js';
import parsePhoneNumber from 'libphonenumber-js';

export default {
  props: {
    value: {
      type: [String, Number],
      default: '',
    },
    placeholder: {
      type: String,
      default: '',
    },
    readonly: {
      type: Boolean,
      default: false,
    },
    styles: {
      type: Object,
      default: () => {},
    },
    error: {
      type: Boolean,
      default: false,
    },
    defaultCountryCode: {
      type: String,
      default: '',
    },
    fixedCountryDropdown: {
      type: Boolean,
      default: false,
    },
    digitsOnly: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      selectedIndex: -1,
      showDropdown: false,
      searchCountry: '',
      activeCountryCode: '',
      activeDialCode: '',
      phoneNumber: this.value,
      countryDropdownStyles: {},
    };
  },
  computed: {
    countries() {
      return [
        {
          name: this.dropdownFirstItemName,
          dial_code: '',
          emoji: '',
          id: '',
        },
        ...countries,
      ];
    },
    dropdownFirstItemName() {
      return this.activeCountryCode ? 'Clear selection' : 'Select Country';
    },
    filteredCountriesBySearch() {
      return this.countries.filter(country => {
        const { name, dial_code, id } = country;
        const search = this.searchCountry.toLowerCase();
        return (
          name.toLowerCase().includes(search) ||
          dial_code.toLowerCase().includes(search) ||
          id.toLowerCase().includes(search)
        );
      });
    },
    activeCountry() {
      if (this.activeCountryCode) {
        return this.countries.find(
          country => country.id === this.activeCountryCode
        );
      }
      return '';
    },
  },
  watch: {
    value() {
      const number = parsePhoneNumber(this.value);
      if (number) {
        this.activeCountryCode = number.country;
        this.activeDialCode = `+${number.countryCallingCode}`;
        this.phoneNumber = this.value.replace(
          `+${number.countryCallingCode}`,
          ''
        );
      }
    },
    showDropdown(isOpen) {
      if (isOpen && this.fixedCountryDropdown) {
        this.$nextTick(() => {
          this.updateCountryDropdownPosition();
        });
      }
    },
  },
  mounted() {
    this.setActiveCountry();
    this.applyDefaultCountry();

    if (this.fixedCountryDropdown) {
      window.addEventListener('resize', this.updateCountryDropdownPosition);
      window.addEventListener('scroll', this.updateCountryDropdownPosition, true);
    }
  },
  beforeDestroy() {
    if (this.fixedCountryDropdown) {
      window.removeEventListener('resize', this.updateCountryDropdownPosition);
      window.removeEventListener('scroll', this.updateCountryDropdownPosition, true);
    }
  },
  methods: {
    applyDefaultCountry() {
      if (this.phoneNumber || this.value || !this.defaultCountryCode) {
        return;
      }

      const country = countries.find(item => item.id === this.defaultCountryCode);
      if (!country) {
        return;
      }

      this.activeCountryCode = country.id;
      this.activeDialCode = country.dial_code;
    },
    onOutsideClick(e) {
      if (
        this.showDropdown &&
        e.target !== this.$refs.dropdown &&
        !this.$refs.dropdown.contains(e.target)
      ) {
        this.closeDropdown();
      }
    },
    onChange(e) {
      let { value } = e.target;

      if (this.digitsOnly) {
        if (value.includes('+')) {
          this.syncFromInternationalInput(value);
          e.target.value = this.phoneNumber;
          this.$emit('input', this.phoneNumber, this.activeDialCode);
          return;
        }

        value = value.replace(/\D/g, '');
        e.target.value = value;
      }

      this.phoneNumber = value;
      this.$emit('input', value, this.activeDialCode);
    },
    matchCountryByDigits(digits) {
      const sortedCountries = [...countries].sort(
        (a, b) =>
          b.dial_code.replace(/\D/g, '').length -
          a.dial_code.replace(/\D/g, '').length
      );

      return sortedCountries.find(country => {
        const codeDigits = country.dial_code.replace(/\D/g, '');
        return digits.startsWith(codeDigits);
      });
    },
    syncFromInternationalInput(rawValue) {
      const cleaned = rawValue.replace(/[^\d+]/g, '');

      if (!cleaned.startsWith('+')) {
        this.phoneNumber = cleaned.replace(/\D/g, '');
        return;
      }

      const digits = cleaned.slice(1);

      if (!digits) {
        this.phoneNumber = '+';
        return;
      }

      const country = this.matchCountryByDigits(digits);

      if (country) {
        const codeDigits = country.dial_code.replace(/\D/g, '');
        this.activeCountryCode = country.id;
        this.activeDialCode = country.dial_code;
        this.phoneNumber = digits.slice(codeDigits.length) || '';
        this.$emit('setCode', country.dial_code);
        return;
      }

      this.phoneNumber = `+${digits}`;
    },
    onPhoneKeydown(e) {
      if (e.key === 'Enter') {
        e.preventDefault();
        this.$emit('enter');
        return;
      }

      if (!this.digitsOnly) {
        return;
      }

      const allowedKeys = [
        'Backspace',
        'Delete',
        'Tab',
        'ArrowLeft',
        'ArrowRight',
        'Home',
        'End',
      ];

      if (allowedKeys.includes(e.key) || e.ctrlKey || e.metaKey) {
        return;
      }

      if (e.key === '+') {
        const input = e.target;
        const atStart = input.selectionStart === 0;
        const hasPlus = input.value.includes('+');

        if (atStart && !hasPlus) {
          return;
        }

        e.preventDefault();
        return;
      }

      if (e.key.length === 1 && !/\d/.test(e.key)) {
        e.preventDefault();
      }
    },
    onBlur(e) {
      this.$emit('blur', e.target.value);
    },
    onSearchCountry() {
      // Reset selected index to 0
      this.selectedIndex = 0;
    },
    moveUp() {
      if (!this.showDropdown) return;
      this.selectedIndex = Math.max(this.selectedIndex - 1, 0);
      this.scrollToSelected();
    },
    moveDown() {
      if (!this.showDropdown) return;
      this.selectedIndex = Math.min(
        this.selectedIndex + 1,
        this.filteredCountriesBySearch.length - 1
      );
      this.scrollToSelected();
    },
    scrollToSelected() {
      this.$nextTick(() => {
        const dropdown = this.$refs.dropdown;
        const selectedItem = this.$refs.dropdownItem[this.selectedIndex];
        const dropdownSearchbarHeight = 40;
        if (selectedItem) {
          const selectedItemTop = selectedItem.offsetTop;
          dropdown.scrollTop = selectedItemTop - dropdownSearchbarHeight;
        }
      });
    },
    onSelectCountry(country) {
      if (!country || !this.showDropdown) return;
      this.activeCountryCode = country.id;
      this.searchCountry = '';
      this.activeDialCode = country.dial_code;
      this.$emit('setCode', country.dial_code);
      this.closeDropdown();
      this.$refs.phoneNumberInput.focus();
    },
    setActiveCountry() {
      const { phoneNumber } = this;
      if (!phoneNumber) return;
      const number = parsePhoneNumber(phoneNumber);
      if (number) {
        this.activeCountryCode = number.country;
        this.activeDialCode = number.countryCallingCode;
      }
    },
    toggleCountryDropdown() {
      this.showDropdown = !this.showDropdown;
      this.selectedIndex = -1;
      if (this.showDropdown) {
        this.$nextTick(() => {
          this.updateCountryDropdownPosition();
          this.$refs.searchbar.focus();
        });
      }
    },
    updateCountryDropdownPosition() {
      if (!this.fixedCountryDropdown || !this.showDropdown) {
        return;
      }

      const selector = this.$refs.countrySelector;
      if (!selector) {
        return;
      }

      const rect = selector.getBoundingClientRect();
      this.countryDropdownStyles = {
        position: 'fixed',
        top: `${rect.bottom + 4}px`,
        left: `${rect.left}px`,
        width: '12.5rem',
        zIndex: 10001,
      };
    },
    closeDropdown() {
      this.selectedIndex = -1;
      this.showDropdown = false;
    },
  },
};
</script>
