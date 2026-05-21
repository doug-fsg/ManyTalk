<template>
  <div class="edit-pipeline-container">
    <!-- Header -->
    <div class="flex flex-col items-start px-12 pt-8 pb-0 flex-shrink-0">
      <div class="flex items-center justify-between w-full gap-4">
        <div class="flex items-center gap-3 flex-wrap">
          <h2 class="text-base font-semibold leading-6 text-slate-800 dark:text-slate-50">
            Editando: {{ selectedAttribute.attribute_display_name }}
          </h2>
          <div class="flex items-center gap-2 flex-wrap">
            <span class="text-xs text-slate-500 dark:text-slate-400">
              ID: {{ selectedAttribute.id }}
            </span>
            <button
              type="button"
              class="text-xs text-slate-400 dark:text-slate-500 hover:text-slate-600 dark:hover:text-slate-300 transition-colors"
              @click="copyId"
            >
              Copiar
            </button>
            <span v-if="formattedUpdatedAt" class="text-xs text-slate-400 dark:text-slate-500">
              • {{ formattedUpdatedAt }}
            </span>
          </div>
        </div>
        <div
          v-if="hasUnsavedChanges"
          class="flex items-center gap-1 px-2 py-0.5 rounded bg-amber-50 dark:bg-amber-900/20"
          role="status"
          aria-live="polite"
        >
          <fluent-icon icon="circle" size="4" class="text-amber-500 dark:text-amber-400 animate-pulse" />
          <span class="text-xs text-amber-600 dark:text-amber-400">
            Não salvo
          </span>
        </div>
      </div>
    </div>

    <!-- Layout de Duas Colunas -->
    <form class="flex w-full flex-1 min-h-0" @submit.prevent="editAttributes">
      <!-- Coluna Esquerda -->
      <div class="w-2/5 px-4 py-4 space-y-6">
        <!-- Dados Básicos -->
        <div class="basic-data-section">
          <!-- Header colapsável -->
          <div 
            class="section-header"
            @click="basicDataExpanded = !basicDataExpanded"
          >
            <div class="header-left">
              <fluent-icon 
                :icon="basicDataExpanded ? 'chevron-down' : 'chevron-right'" 
                size="16" 
                class="chevron-icon"
              />
              <fluent-icon icon="document" size="16" class="document-icon" />
              <h3 class="section-title">Dados Básicos</h3>
            </div>
            <fluent-icon 
              icon="chevron-down" 
              size="16" 
              class="expand-icon"
              :class="{ 'rotate-180': basicDataExpanded }"
            />
          </div>

          <!-- Conteúdo expansível -->
          <div v-if="basicDataExpanded" class="section-content">
            <woot-input
              v-model.trim="displayName"
              :label="$t('ATTRIBUTES_MGMT.ADD.FORM.NAME.LABEL')"
              type="text"
              :class="{ error: $v.displayName.$error }"
              :error="
                $v.displayName.$error
                  ? $t('ATTRIBUTES_MGMT.ADD.FORM.NAME.ERROR')
                  : ''
              "
              :placeholder="$t('ATTRIBUTES_MGMT.ADD.FORM.NAME.PLACEHOLDER')"
              @blur="$v.displayName.$touch"
              @input="$v.displayName.$touch"
              aria-required="true"
              aria-invalid="$v.displayName.$error"
            />

            <div class="mt-4">
              <label class="block mb-1.5 text-sm font-medium text-slate-700 dark:text-slate-300" for="pipeline-description">
                {{ $t('ATTRIBUTES_MGMT.ADD.FORM.DESC.LABEL') }}
                <span class="text-red-500 dark:text-red-400 ml-0.5" aria-label="obrigatório">*</span>
              </label>
              <textarea
                id="pipeline-description"
                v-model.trim="description"
                rows="4"
                class="w-full px-3 py-2 text-sm border rounded-lg bg-white dark:bg-slate-900 text-slate-900 dark:text-white resize-none transition-colors focus:outline-none focus:ring-2 focus:ring-woot-500 focus:border-transparent"
                :class="$v.description.$error ? 'border-red-500 dark:border-red-400 focus:ring-red-500 dark:focus:ring-red-400' : 'border-slate-200 dark:border-slate-600'"
                :placeholder="$t('ATTRIBUTES_MGMT.ADD.FORM.DESC.PLACEHOLDER')"
                @blur="$v.description.$touch"
                @input="$v.description.$touch"
                aria-required="true"
                :aria-invalid="$v.description.$error"
                :aria-describedby="$v.description.$error ? 'desc-error' : null"
              />
              <span 
                v-if="$v.description.$error" 
                id="desc-error"
                class="text-red-500 dark:text-red-400 text-xs mt-1.5 font-medium block" 
                role="alert"
              >
                {{ $t('ATTRIBUTES_MGMT.ADD.FORM.DESC.ERROR') }}
              </span>
            </div>
          </div>
        </div>
      </div>

      <!-- Coluna Direita (Sidebar) -->
      <div class="w-3/5 border-l border-slate-200 dark:border-slate-700">
        <!-- Etapas desse funil -->
        <div class="px-4 py-4 space-y-6">
          <div class="stages-section">
            <!-- Header colapsável -->
            <div 
              class="section-header"
              @click="stagesExpanded = !stagesExpanded"
              @keydown.enter="stagesExpanded = !stagesExpanded"
              @keydown.space.prevent="stagesExpanded = !stagesExpanded"
              role="button"
              :aria-expanded="stagesExpanded"
              aria-label="Etapas desse funil"
              tabindex="0"
            >
              <div class="header-left">
                <fluent-icon 
                  :icon="stagesExpanded ? 'chevron-down' : 'chevron-right'" 
                  size="16" 
                  class="chevron-icon"
                />
                <fluent-icon icon="list" size="16" class="list-icon" />
                <h3 class="section-title">Etapas desse funil</h3>
                <span class="px-1.5 py-0.5 text-xs font-medium bg-slate-200 dark:bg-slate-700 text-slate-600 dark:text-slate-400 rounded" aria-label="Total de etapas">
                  {{ values.length }}
                </span>
              </div>
              <fluent-icon 
                icon="chevron-down" 
                size="16" 
                class="expand-icon"
                :class="{ 'rotate-180': stagesExpanded }"
              />
            </div>

            <!-- Conteúdo expansível -->
            <div v-if="stagesExpanded" class="section-content">
              <draggable
                v-model="values"
                handle=".drag-handle"
                class="stages-list"
                animation="150"
                ghost-class="stage-ghost"
              >
                <div 
                  v-for="(stage, index) in values" 
                  :key="index"
                  class="stage-item"
                  role="listitem"
                >
                  <div class="stage-info">
                    <div class="drag-handle" v-tooltip="'Arrastar para reordenar'">
                      <fluent-icon icon="drag" size="16" />
                    </div>
                    <!-- Edição de cor inline -->
                    <div 
                      v-if="editingColorIndex === index"
                      class="stage-color-editor"
                      @click.stop
                    >
                      <color-picker
                        :value="stage.color || getStageColor(stage.name)"
                        @input="(color) => updateStageColorInline(index, color)"
                      />
                    </div>
                    <div 
                      v-else
                      class="stage-color-indicator stage-color-clickable" 
                      :style="{ backgroundColor: stage.color || getStageColor(stage.name) }"
                      :aria-label="`Cor da etapa ${stage.name}`"
                      v-tooltip="'Clique para editar a cor'"
                      @click.stop="startEditingColor(index)"
                    />
                    
                    <!-- Edição de nome inline -->
                    <input
                      v-if="editingNameIndex === index"
                      :ref="`stageNameInput-${index}`"
                      v-model="editingStageName"
                      type="text"
                      class="stage-name-input"
                      @blur="finishEditingName(index)"
                      @keyup.enter="finishEditingName(index)"
                      @keyup.esc="cancelEditingName"
                    />
                    <span 
                      v-else
                      class="stage-name stage-name-clickable"
                      v-tooltip="'Clique para editar o nome'"
                      @click.stop="startEditingName(index, stage.name)"
                    >
                      {{ stage.name }}
                    </span>
                  </div>
                  <div class="stage-actions">
                    <button
                      type="button"
                      class="stage-action-btn"
                      v-tooltip="'Copiar'"
                      @click.stop="copyStage(index)"
                      :aria-label="`Copiar etapa ${stage.name}`"
                    >
                      <fluent-icon icon="copy" size="14" />
                    </button>
                    <button
                      v-if="values.length > 1"
                      type="button"
                      class="stage-action-btn stage-action-btn-delete"
                      v-tooltip="'Deletar'"
                      @click.stop="confirmRemoveStage(index)"
                      :aria-label="`Deletar etapa ${stage.name}`"
                    >
                      <fluent-icon icon="delete" size="14" />
                    </button>
                  </div>
                </div>
              </draggable>
              
              <!-- Botão para adicionar nova etapa -->
              <button
                type="button"
                class="add-stage-btn"
                @click="addNewStage"
                v-tooltip="'Adicionar nova etapa'"
              >
                <fluent-icon icon="add" size="14" />
                <span>Adicionar etapa</span>
              </button>
            </div>
          </div>

          <!-- Agentes do Funil (apenas para administradores) -->
          <funnel-agents-permissions
            v-if="isAdministrator"
            :pipeline-id="selectedAttribute.id"
            :permissions.sync="agentPermissions"
          />
        </div>
      </div>
    </form>

    <!-- Footer com ações -->
    <div class="flex justify-end items-center gap-2 px-8 py-3 border-t border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800/50 flex-shrink-0">
      <woot-button 
        variant="clear" 
        type="button"
        @click="handleClose"
        aria-label="Descartar alterações"
      >
        Cancelar
      </woot-button>
      <woot-button 
        variant="primary" 
        type="button"
        :is-loading="isUpdating" 
        :disabled="isButtonDisabled"
        @click="editAttributes"
        :aria-label="isButtonDisabled ? 'Salvar (desabilitado - corrija os erros)' : 'Salvar alterações'"
      >
        Salvar
      </woot-button>
    </div>

    <!-- Modal de confirmação para deletar etapa -->
    <woot-delete-modal
      v-if="showDeleteStageModal"
      :show.sync="showDeleteStageModal"
      :on-close="cancelDeleteStage"
      :on-confirm="confirmDeleteStage"
      title="Deletar etapa"
      :message="deleteStageMessage"
      confirm-text="Deletar"
      reject-text="Cancelar"
    />

    <!-- Modal de confirmação para fechar com alterações não salvas -->
    <woot-modal
      v-if="showUnsavedChangesModal"
      :show.sync="showUnsavedChangesModal"
      :on-close="cancelCloseWithChanges"
    >
      <woot-modal-header
        header-title="Alterações não salvas"
        header-content="Você tem alterações não salvas. Deseja descartá-las e fechar o modal?"
      />
      <div class="flex justify-end items-center gap-2 p-6">
        <woot-button variant="clear" @click="cancelCloseWithChanges">
          Cancelar
        </woot-button>
        <woot-button variant="primary" color-scheme="alert" @click="confirmCloseWithChanges">
          Descartar alterações
        </woot-button>
      </div>
    </woot-modal>
  </div>
</template>

<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { required, minLength } from 'vuelidate/lib/validators';
import onClickAwayDirective from 'shared/directives/onClickOutside';
import draggable from 'vuedraggable';
import customAttributeMixin from '../../../../mixins/customAttributeMixin';
import FunnelAgentsPermissions from 'dashboard/routes/dashboard/crm/components/FunnelAgentsPermissions.vue';
import ColorPicker from 'dashboard/components/widgets/ColorPicker.vue';
import { format } from 'date-fns';
import { ptBR } from 'date-fns/locale';

export default {
  components: {
    FunnelAgentsPermissions,
    ColorPicker,
    draggable,
  },
  directives: {
    onClickaway: onClickAwayDirective,
  },
  mixins: [customAttributeMixin],
  props: {
    selectedAttribute: {
      type: Object,
      default: () => {},
    },
    isUpdating: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      displayName: '',
      description: '',
      attributeType: 6,
      regexPattern: null,
      regexCue: null,
      regexEnabled: false,
      show: true,
      values: [],
      options: [],
      isTouched: true,
      agentPermissions: {},
      stagesExpanded: true,
      basicDataExpanded: true,
      newStageName: '',
      newStageColor: '#FF6B6B',
      newStageDescription: '',
      colorMap: {},
      editingColorIndex: null,
      editingNameIndex: null,
      editingStageName: '',
      // Estados iniciais para rastreamento de mudanças
      initialDisplayName: '',
      initialDescription: '',
      initialValues: [],
      initialAgentPermissions: {},
      // Estados para modais
      showDeleteStageModal: false,
      stageToDelete: null,
      showUnsavedChangesModal: false,
      pendingClose: false,
      // Validação de nova etapa
      newStageError: null,
    };
  },
  validations: {
    displayName: {
      required,
    },
    description: {
      required,
      minLength: minLength(1),
    },
  },
  computed: {
    ...mapGetters({
      uiFlags: 'attributes/getUIFlags',
      currentUser: 'getCurrentUser',
      currentAccountId: 'getCurrentAccountId',
      currentRole: 'getCurrentRole',
    }),
    isAdministrator() {
      return this.currentRole === 'administrator';
    },
    setAttributeListValue() {
      if (!this.selectedAttribute.attribute_values) return [];
      
      let stages = [];
      
      // Se for array (pode ser array de strings ou array de objetos)
      if (Array.isArray(this.selectedAttribute.attribute_values)) {
        stages = this.selectedAttribute.attribute_values;
      }
      // Se for objeto com stages (formato novo: { stages: { "nome": { color } } })
      else if (this.selectedAttribute.attribute_values.stages) {
        const stagesObj = this.selectedAttribute.attribute_values.stages;
        // Se stages é objeto, converter para array
        if (typeof stagesObj === 'object' && !Array.isArray(stagesObj)) {
          stages = Object.entries(stagesObj).map(([name, data]) => ({
            name,
            color: data?.color || null
          }));
        } else {
          stages = stagesObj;
        }
      }
      
      // Converter para formato padronizado
      return stages.map(stage => {
        // Se já é um objeto com name e color
        if (typeof stage === 'object' && stage !== null) {
          const name = stage.name || stage.value || stage;
          const color = stage.color || null;
          
          // Se tem cor, salvar no colorMap
          if (color) {
            this.colorMap[name] = color;
          }
          
          return { name, color };
        }
        // Se é string (formato legado)
        else {
          const name = stage;
          // Gerar cor automaticamente usando getStageColor
          const color = this.getStageColor(name);
          return { name, color };
        }
      });
    },
    updatedAttributeListValues() {
      // Formato: { stages: { "nome": { color }, ... }, permissions: {...} }
      const stages = {};
      this.values.forEach((item) => {
        stages[item.name] = {
          color: item.color || this.getStageColor(item.name)
        };
      });
      
      return {
        stages,
        permissions: this.agentPermissions
      };
    },
    isButtonDisabled() {
      return this.$v.description.$invalid || this.isMultiselectInvalid;
    },
    isMultiselectInvalid() {
      return (
        this.isAttributeTypeList && this.isTouched && this.values.length === 0
      );
    },
    isAttributeTypeList() {
      return this.attributeType === 6;
    },
    formattedUpdatedAt() {
      if (!this.selectedAttribute.updated_at) return '';
      try {
        const date = new Date(this.selectedAttribute.updated_at);
        return format(date, "dd/MM/yyyy, HH:mm:ss", { locale: ptBR });
      } catch (e) {
        return '';
      }
    },
    hasUnsavedChanges() {
      // Verificar se há mudanças nos dados básicos
      const nameChanged = this.displayName !== this.initialDisplayName;
      const descChanged = this.description !== this.initialDescription;
      
      // Verificar se há mudanças nas etapas (incluindo cores)
      const currentStages = this.values.map(v => ({
        name: v.name,
        color: v.color || this.getStageColor(v.name)
      }));
      const initialStages = this.initialValues.map(v => ({
        name: v.name,
        color: v.color || this.getStageColor(v.name)
      }));
      const stagesChanged = JSON.stringify(currentStages) !== JSON.stringify(initialStages);
      
      // Verificar se há mudanças nas permissões
      const permissionsChanged = JSON.stringify(this.agentPermissions) !== 
                                JSON.stringify(this.initialAgentPermissions);
      
      return nameChanged || descChanged || stagesChanged || permissionsChanged;
    },
    deleteStageMessage() {
      if (!this.stageToDelete || !this.stageToDelete.name) {
        return 'Tem certeza que deseja deletar esta etapa?';
      }
      return `Tem certeza que deseja deletar a etapa "${this.stageToDelete.name}"?`;
    },
  },
  watch: {
    // Observar mudanças nas permissões de agentes
    agentPermissions: {
      handler() {
        // Trigger reatividade para hasUnsavedChanges
      },
      deep: true,
    },
    // Observar mudanças nos valores (etapas)
    values: {
      handler() {
        // Trigger reatividade para hasUnsavedChanges
      },
      deep: true,
    },
    // Gerenciar listener para fechar color picker ao clicar fora
    editingColorIndex(newVal) {
      if (newVal !== null) {
        this.$nextTick(() => {
          document.addEventListener('click', this.handleDocumentClick);
        });
      } else {
        document.removeEventListener('click', this.handleDocumentClick);
      }
    },
  },
  mounted() {
    this.setFormValues();
  },
  beforeDestroy() {
    // Limpar listener ao destruir componente
    document.removeEventListener('click', this.handleDocumentClick);
  },
  methods: {
    handleClose() {
      if (this.hasUnsavedChanges) {
        this.pendingClose = true;
        this.showUnsavedChangesModal = true;
      } else {
        this.onClose();
      }
    },
    cancelCloseWithChanges() {
      this.showUnsavedChangesModal = false;
      this.pendingClose = false;
    },
    confirmCloseWithChanges() {
      this.showUnsavedChangesModal = false;
      this.pendingClose = false;
      this.onClose();
    },
    onClose() {
      this.$emit('on-cancel');
    },
    copyId() {
      navigator.clipboard.writeText(this.selectedAttribute.id.toString());
      useAlert('ID copiado!');
    },
    getStageColor(stageName) {
      if (this.colorMap[stageName]) {
        return this.colorMap[stageName];
      }
      
      // Cores predefinidas
      const stageColors = {
        'novo': '#6554C0',
        'em análise': '#6554C0',
        'em desenvolvimento': '#FF5630',
        'em teste': '#FFAB00',
        'resolvido': '#36B37E',
      };
      
      const stageNameLower = stageName.toLowerCase();
      const matchingColor = Object.entries(stageColors).find(([key]) =>
        stageNameLower.includes(key) || key.includes(stageNameLower)
      );
      
      const color = matchingColor ? matchingColor[1] : '#6B7280';
      this.colorMap[stageName] = color;
      return color;
    },
    updateStageColor(index, color) {
      if (this.values[index]) {
        // Usar $set para garantir reatividade do Vue
        this.$set(this.values[index], 'color', color);
        this.$set(this.colorMap, this.values[index].name, color);
      }
    },
    startEditingColor(index) {
      this.editingColorIndex = index;
      // Fechar edição de nome se estiver aberta
      if (this.editingNameIndex !== null) {
        this.editingNameIndex = null;
      }
    },
    updateStageColorInline(index, color) {
      if (this.values[index]) {
        this.$set(this.values[index], 'color', color);
        this.$set(this.colorMap, this.values[index].name, color);
      }
    },
    handleDocumentClick(event) {
      // Verificar se o clique foi no color picker ou no chrome picker
      const colorPicker = event.target.closest('.colorpicker');
      const chromePicker = event.target.closest('.colorpicker--chrome');
      
      if (!colorPicker && !chromePicker) {
        // Clique foi fora, fechar edição
        this.editingColorIndex = null;
      }
    },
    startEditingName(index, currentName) {
      this.editingNameIndex = index;
      this.editingStageName = currentName;
      // Fechar edição de cor se estiver aberta
      if (this.editingColorIndex !== null) {
        this.editingColorIndex = null;
      }
      // Focar no input
      this.$nextTick(() => {
        const inputRef = `stageNameInput-${index}`;
        const input = this.$refs[inputRef];
        if (input && input.length) {
          input[0].focus();
          input[0].select();
        } else if (input) {
          input.focus();
          input.select();
        }
      });
    },
    finishEditingName(index) {
      if (this.editingNameIndex === null) return;
      
      const trimmedName = this.editingStageName.trim();
      
      if (!trimmedName) {
        // Se o nome estiver vazio, cancelar edição
        this.cancelEditingName();
        return;
      }
      
      // Verificar se já existe uma etapa com o mesmo nome (exceto a atual)
      const exists = this.values.some(
        (stage, idx) => idx !== index && stage.name.toLowerCase() === trimmedName.toLowerCase()
      );
      
      if (exists) {
        useAlert('Já existe uma etapa com este nome');
        this.cancelEditingName();
        return;
      }
      
      // Atualizar o nome
      if (this.values[index]) {
        const oldName = this.values[index].name;
        this.$set(this.values[index], 'name', trimmedName);
        
        // Atualizar colorMap se necessário
        if (this.colorMap[oldName] && !this.colorMap[trimmedName]) {
          this.colorMap[trimmedName] = this.colorMap[oldName];
          delete this.colorMap[oldName];
        }
      }
      
      this.editingNameIndex = null;
      this.editingStageName = '';
    },
    cancelEditingName() {
      this.editingNameIndex = null;
      this.editingStageName = '';
    },
    validateNewStage() {
      this.newStageError = null;
      
      if (!this.newStageName.trim()) {
        return;
      }
      
      const trimmedName = this.newStageName.trim();
      
      // Verificar se já existe uma etapa com o mesmo nome
      const exists = this.values.some(
        stage => stage.name.toLowerCase() === trimmedName.toLowerCase()
      );
      
      if (exists) {
        this.newStageError = 'Já existe uma etapa com este nome';
        return;
      }
      
      if (trimmedName.length < 2) {
        this.newStageError = 'O nome da etapa deve ter pelo menos 2 caracteres';
        return;
      }
    },
    addNewStage() {
      // Garantir que a sanfona esteja aberta
      if (!this.stagesExpanded) {
        this.stagesExpanded = true;
      }
      
      // Gerar nome único para nova etapa
      let stageNumber = 1;
      let newName = `Nova Etapa ${stageNumber}`;
      
      while (this.values.some(stage => stage.name.toLowerCase() === newName.toLowerCase())) {
        stageNumber++;
        newName = `Nova Etapa ${stageNumber}`;
      }
      
      // Adicionar nova etapa na lista
      const newStage = {
        name: newName,
        color: this.getStageColor(newName),
        description: '',
      };
      
      this.values.push(newStage);
      this.colorMap[newName] = newStage.color;
      
      // Abrir edição do nome automaticamente
      const newIndex = this.values.length - 1;
      this.$nextTick(() => {
        this.startEditingName(newIndex, newName);
      });
    },
    copyStage(index) {
      const stage = this.values[index];
      const copiedStage = {
        name: `${stage.name} (cópia)`,
        color: stage.color || this.getStageColor(stage.name),
        description: stage.description || '',
      };
      this.values.splice(index + 1, 0, copiedStage);
      // Atualizar colorMap para a cópia
      this.colorMap[copiedStage.name] = copiedStage.color;
      useAlert(`Etapa "${copiedStage.name}" copiada com sucesso!`);
    },
    editStage(index) {
      const stage = this.values[index];
      this.newStageName = stage.name;
      this.newStageColor = stage.color || this.getStageColor(stage.name);
      this.newStageDescription = stage.description || '';
      
      // Remover a etapa atual - será adicionada novamente quando o usuário clicar em "Adicionar Etapa"
      this.removeStage(index);
      useAlert(`Etapa "${stage.name}" movida para edição. Preencha o formulário e clique em "Adicionar Etapa" para salvar.`);
    },
    confirmRemoveStage(index) {
      this.stageToDelete = { ...this.values[index], index };
      this.showDeleteStageModal = true;
    },
    cancelDeleteStage() {
      this.showDeleteStageModal = false;
      this.stageToDelete = null;
    },
    confirmDeleteStage() {
      if (this.stageToDelete !== null && this.stageToDelete.index !== undefined) {
        const stageName = this.stageToDelete.name;
        this.values.splice(this.stageToDelete.index, 1);
        useAlert(`Etapa "${stageName}" removida com sucesso!`);
      }
      this.showDeleteStageModal = false;
      this.stageToDelete = null;
    },
    removeStage(index) {
      this.values.splice(index, 1);
    },
    setFormValues() {
      const regexPattern = this.selectedAttribute.regex_pattern
        ? this.getRegexp(this.selectedAttribute.regex_pattern).source
        : null;
      this.displayName = this.selectedAttribute.attribute_display_name;
      this.description = this.selectedAttribute.attribute_description;
      this.attributeType = 6; // Sempre será lista para Kanban
      this.regexPattern = regexPattern;
      this.regexCue = this.selectedAttribute.regex_cue;
      this.regexEnabled = regexPattern != null;
      
      // Resetar colorMap antes de carregar valores
      this.colorMap = {};
      
      // Carregar valores (isso também inicializa o colorMap)
      this.values = this.setAttributeListValue;
      
      // Garantir que todas as etapas tenham cores (para dados legados)
      this.values.forEach(stage => {
        if (!stage.color) {
          stage.color = this.getStageColor(stage.name);
        }
        // Atualizar colorMap com a cor final
        this.colorMap[stage.name] = stage.color;
      });
      
      // Carregar permissões existentes
      if (this.selectedAttribute.permissions) {
        this.agentPermissions = { ...this.selectedAttribute.permissions };
      } else {
        this.agentPermissions = {};
      }
      
      // Salvar estados iniciais para rastreamento de mudanças
      this.initialDisplayName = this.displayName;
      this.initialDescription = this.description;
      this.initialValues = JSON.parse(JSON.stringify(this.values));
      this.initialAgentPermissions = JSON.parse(JSON.stringify(this.agentPermissions));
    },
    async editAttributes() {
      this.$v.$touch();
      if (this.$v.$invalid) {
        return;
      }
      if (!this.regexEnabled) {
        this.regexPattern = null;
        this.regexCue = null;
      }
      try {
        const payload = {
          id: this.selectedAttribute.id,
          attribute_description: this.description,
          attribute_display_name: this.displayName,
          attribute_values: this.updatedAttributeListValues,
          regex_pattern: this.regexPattern
            ? new RegExp(this.regexPattern).toString()
            : null,
          regex_cue: this.regexCue,
        };

        await this.$store.dispatch('attributes/update', payload);
        this.alertMessage = this.$t('ATTRIBUTES_MGMT.EDIT.API.SUCCESS_MESSAGE');
        
        // Emitir evento para atualizar componentes que dependem dos nomes das etapas
        if (window.bus) {
          window.bus.$emit('attributes:updated');
        }
        
        // Atualizar estados iniciais após salvar com sucesso
        this.initialDisplayName = this.displayName;
        this.initialDescription = this.description;
        this.initialValues = JSON.parse(JSON.stringify(this.values));
        this.initialAgentPermissions = JSON.parse(JSON.stringify(this.agentPermissions));
        
        this.$emit('on-close');
      } catch (error) {
        const errorMessage = error?.message;
        this.alertMessage =
          errorMessage || this.$t('ATTRIBUTES_MGMT.EDIT.API.ERROR_MESSAGE');
      } finally {
        useAlert(this.alertMessage);
      }
    },
  },
};
</script>

<style scoped lang="scss">
.edit-pipeline-container {
  @apply flex flex-col;
  height: 80vh;
  max-height: 800px;
  min-height: 600px;
  overflow: hidden;
}

.edit-pipeline-container > form {
  @apply flex-1 min-h-0 overflow-y-auto overflow-x-hidden;
  flex: 1 1 auto;
  min-height: 0;
}

.basic-data-section {
  @apply border border-slate-200 dark:border-slate-600 rounded-xl;
  overflow: visible !important;
}

.stages-section {
  @apply border border-slate-200 dark:border-slate-600 rounded-xl;
  overflow: visible !important;
}

.section-header {
  @apply flex items-center justify-between px-4 py-3 cursor-pointer;
  @apply bg-slate-50 dark:bg-slate-800 hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors duration-150 ease-smooth;
  @apply transition-colors duration-200;

  .header-left {
    @apply flex items-center gap-2;
  }

  .chevron-icon,
  .list-icon,
  .document-icon {
    @apply text-slate-600 dark:text-slate-400;
  }

  .section-title {
    @apply text-sm font-medium text-slate-900 dark:text-white;
  }

  .expand-icon {
    @apply text-slate-400 dark:text-slate-500 transition-transform duration-200;
  }
}

.section-content {
  @apply p-3 space-y-2 bg-white dark:bg-slate-900;
  overflow: visible !important;
}

.stages-list {
  @apply space-y-2;
  
  // Estados durante o drag
  .stage-ghost {
    @apply opacity-50;
  }
  
  .sortable-drag {
    @apply opacity-0;
  }
}

.stage-item {
  @apply flex items-center justify-between gap-3 py-2 px-3 rounded-lg;
  @apply bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700;
  @apply transition-all duration-200;

  &:hover {
    @apply bg-slate-100 dark:bg-slate-700;
  }
}

.stage-info {
  @apply flex items-center gap-3 flex-1 min-w-0;
}

.drag-handle {
  @apply cursor-grab active:cursor-grabbing text-slate-400 dark:text-slate-500;
  @apply hover:text-slate-600 dark:hover:text-slate-300 transition-colors;
  @apply flex-shrink-0;
  
  &:active {
    @apply cursor-grabbing;
  }
}

.stage-color-indicator {
  @apply w-2 h-2 rounded-full flex-shrink-0;
  
  &.stage-color-clickable {
    @apply cursor-pointer transition-all duration-200;
    
    &:hover {
      @apply scale-150;
    }
  }
}

.stage-color-editor {
  @apply flex-shrink-0 relative;
  
  // Garantir que o color picker possa sair para fora
  ::v-deep .colorpicker--chrome {
    z-index: 10000 !important;
  }
}

.stage-name {
  @apply text-sm font-medium text-slate-900 dark:text-white;
  
  &.stage-name-clickable {
    @apply cursor-text px-1 py-0.5 rounded-lg hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors duration-150 ease-smooth;
    @apply transition-colors duration-200;
  }
}

.stage-name-input {
  @apply flex-1 px-2 py-1 text-sm border border-woot-500 dark:border-woot-400 rounded;
  @apply bg-white dark:bg-slate-800 text-slate-900 dark:text-white;
  @apply focus:outline-none focus:ring-2 focus:ring-woot-500 focus:border-transparent;
}

.stage-actions {
  @apply flex items-center gap-2;
}

.stage-action-btn {
  @apply p-1.5 rounded-lg text-slate-400 dark:text-slate-500;
  @apply hover:bg-slate-50 dark:hover:bg-slate-700 hover:text-slate-600 dark:hover:text-slate-300;
  @apply transition-all duration-200 cursor-pointer flex-shrink-0;
  @apply bg-transparent border-none;

  &.stage-action-btn-delete {
    @apply hover:bg-red-50 dark:hover:bg-red-900/20 hover:text-red-500 dark:hover:text-red-400;
  }
}

.add-stage-btn {
  @apply flex items-center gap-1.5 px-3 py-1.5 mt-2 text-xs font-medium;
  @apply text-slate-600 dark:text-slate-400 hover:text-woot-600 dark:hover:text-woot-400;
  @apply bg-transparent border border-dashed border-slate-300 dark:border-slate-600;
  @apply rounded-lg hover:border-woot-500 dark:hover:border-woot-400;
  @apply hover:bg-woot-50 dark:hover:bg-woot-900/20;
  @apply transition-all duration-200 cursor-pointer;
  @apply w-full justify-center;
}

// Garantir que tooltips apareçam acima do modal
::v-deep .tooltip {
  z-index: 10001 !important;
}

::v-deep .v-tooltip-container {
  z-index: 10001 !important;
}
</style>

<style lang="scss">
/* Estilos não escoped para afetar elementos fora do componente (tooltips no body) */
body > .tooltip {
  z-index: 10001 !important;
}

body > .v-tooltip-container {
  z-index: 10001 !important;
}
</style>

