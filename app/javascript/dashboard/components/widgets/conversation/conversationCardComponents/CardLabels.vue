<template>
  <div ref="labelContainer" v-resize="computeVisibleLabelPosition">
    <div
      v-if="activeLabels.length || $slots.before"
      class="flex items-end flex-shrink min-w-0 gap-y-1"
      :class="{ 'h-auto overflow-visible flex-row flex-wrap': showAllLabels }"
    >
      <slot name="before" />
      <woot-label
        v-for="(label, index) in activeLabels"
        :key="label.id"
        :title="label.title"
        :description="label.description"
        :color="label.color"
        variant="smooth"
        class="!mb-0 max-w-[calc(100%-0.5rem)]"
        small
        :class="{ hidden: !showAllLabels && index > labelPosition }"
      />
      <woot-button
        v-if="showExpandLabelButton"
        :title="
          showAllLabels
            ? $t('CONVERSATION.CARD.HIDE_LABELS')
            : $t('CONVERSATION.CARD.SHOW_LABELS')
        "
        class="sticky right-0 flex-shrink-0 mr-6 show-more--button rtl:rotate-180"
        color-scheme="secondary"
        variant="hollow"
        :icon="showAllLabels ? 'chevron-left' : 'chevron-right'"
        size="tiny"
        @click="onShowLabels"
      />
    </div>
  </div>
</template>
<script>
import conversationLabelMixin from 'dashboard/mixins/conversation/labelMixin';
export default {
  mixins: [conversationLabelMixin],
  props: {
    conversationId: {
      type: Number,
      required: true,
    },
    conversationLabels: {
      type: String,
      required: false,
      default: '',
    },
  },
  data() {
    return {
      showAllLabels: false,
      showExpandLabelButton: false,
      labelPosition: -1,
      isComputing: false,
    };
  },
  watch: {
    activeLabels() {
      this.$nextTick(() => this.computeVisibleLabelPosition());
    },
  },
  mounted() {
    // the problem here is that there is a certain amount of delay between the conversation
    // card being mounted and the resize event eventually being triggered
    // This means we need to run the function immediately after the component is mounted
    // Happens especially when used in a virtual list.
    // We can make the first trigger, a standard part of the directive, in case
    // we face this issue again
    this.computeVisibleLabelPosition();
  },
  methods: {
    onShowLabels(e) {
      e.stopPropagation();
      this.showAllLabels = !this.showAllLabels;
      this.$nextTick(() => this.computeVisibleLabelPosition());
    },
    computeVisibleLabelPosition() {
      // Proteção contra loops infinitos
      if (this.isComputing) return;
      
      this.isComputing = true;
      
      // Usar requestAnimationFrame para garantir execução após atualização do DOM
      requestAnimationFrame(() => {
        const beforeSlot = this.$slots.before ? 100 : 0;
        const labelContainer = this.$refs.labelContainer;
        if (!labelContainer) {
          this.isComputing = false;
          return;
        }

        // Buscar todos os labels
        const allLabels = Array.from(labelContainer.querySelectorAll('.label'));
        
        if (allLabels.length === 0) {
          this.showExpandLabelButton = false;
          this.labelPosition = -1;
          this.isComputing = false;
          return;
        }

        const containerWidth = labelContainer.clientWidth - 16 - beforeSlot;
        let labelOffset = 0;
        let lastVisibleIndex = -1;
        
        // Para evitar loops, calcular baseado em todos os labels como se estivessem visíveis
        // Temporariamente remover classe hidden para medir corretamente o tamanho real
        // Isso evita que labels ocultos (que não ocupam espaço) causem cálculo incorreto
        const hiddenLabels = [];
        allLabels.forEach((label) => {
          const wasHidden = label.classList.contains('hidden');
          if (wasHidden) {
            label.classList.remove('hidden');
            hiddenLabels.push(label);
          }
        });

        // Calcular quantos labels cabem no espaço disponível
        allLabels.forEach((label, index) => {
          const labelWidth = label.offsetWidth + 8;
          const newOffset = labelOffset + labelWidth;
          
          if (newOffset <= containerWidth) {
            labelOffset = newOffset;
            lastVisibleIndex = index;
          }
        });

        // Restaurar classe hidden nos labels que estavam ocultos
        // Isso é seguro porque isComputing previne loops e requestAnimationFrame
        // garante que isso acontece após o Vue atualizar o DOM
        hiddenLabels.forEach((label) => {
          label.classList.add('hidden');
        });

        // Atualizar labelPosition apenas se mudou
        const newLabelPosition = lastVisibleIndex;
        if (this.labelPosition !== newLabelPosition) {
          this.labelPosition = newLabelPosition;
        }

        // Mostrar botão apenas se há labels ocultos (mais labels do que os que cabem)
        const hasHiddenLabels = newLabelPosition < allLabels.length - 1;
        this.showExpandLabelButton = hasHiddenLabels && allLabels.length > 1;

        this.isComputing = false;
      });
    },
  },
};
</script>

<style lang="scss" scoped>
.show-more--button {
  @apply h-5;
  &.secondary:focus {
    @apply text-slate-700 dark:text-slate-200 border-slate-300 dark:border-slate-700;
  }
}

.labels-wrap {
  .secondary {
    @apply border border-solid border-slate-100 dark:border-slate-700;
  }
}

.hidden {
  @apply invisible absolute;
}
</style>
