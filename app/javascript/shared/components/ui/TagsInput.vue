<template>
  <div class="tags-input">
    <div class="tags-container">
      <span 
        v-for="(tag, index) in internalTags" 
        :key="index" 
        class="tag"
      >
        {{ tag }}
        <span 
          class="delete-tag" 
          @click="removeTag(index)"
        >
          &times;
        </span>
      </span>
    </div>
    <input
      ref="input"
      v-model="inputValue"
      :placeholder="placeholder"
      @keydown.enter.prevent="addTag"
      @keydown.tab.prevent="addTag"
      @keydown.188.prevent="addTag"
      @blur="onBlur"
    />
  </div>
</template>

<script>
export default {
  props: {
    value: {
      type: Array,
      default: () => [],
    },
    placeholder: {
      type: String,
      default: 'Adicionar etiquetas...',
    },
    allowDuplicates: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      inputValue: '',
      internalTags: [],
    };
  },
  watch: {
    value: {
      immediate: true,
      handler(newVal) {
        this.internalTags = [...newVal];
      },
    },
  },
  methods: {
    addTag() {
      if (!this.inputValue.trim()) return;
      
      const tags = this.inputValue.split(',')
        .map(tag => tag.trim())
        .filter(tag => tag);
      
      for (const tag of tags) {
        if (this.allowDuplicates || !this.internalTags.includes(tag)) {
          this.internalTags.push(tag);
        }
      }
      
      this.inputValue = '';
      this.emitChange();
    },
    removeTag(index) {
      this.internalTags.splice(index, 1);
      this.emitChange();
    },
    onBlur() {
      this.addTag();
    },
    emitChange() {
      this.$emit('input', this.internalTags);
    },
  },
};
</script>

<style lang="scss" scoped>
.tags-input {
  border: 1px solid var(--s-200);
  border-radius: var(--border-radius-normal);
  padding: 4px;
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  min-height: 38px;
  
  &:focus-within {
    border-color: var(--w-500);
  }
  
  input {
    flex: 1;
    border: none;
    outline: none;
    padding: 4px;
    font-size: var(--font-size-small);
    
    .dark-mode & {
      background-color: transparent;
      color: var(--s-100);
    }
  }
  
  .tags-container {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
  }
  
  .tag {
    background-color: var(--w-50);
    color: var(--w-800);
    padding: 2px 8px;
    border-radius: var(--border-radius-normal);
    display: flex;
    align-items: center;
    font-size: var(--font-size-small);
    
    .dark-mode & {
      background-color: var(--b-700);
      color: var(--s-100);
    }
    
    .delete-tag {
      margin-left: 4px;
      cursor: pointer;
      font-weight: bold;
      font-size: var(--font-size-small);
    }
  }
}
</style> 