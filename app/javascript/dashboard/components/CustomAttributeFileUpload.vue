<template>
  <div class="file-upload-wrapper">
    <div v-if="files.length < maxFiles" class="upload-area">
      <input
        ref="fileInput"
        type="file"
        :accept="acceptedFileTypes"
        :multiple="allowMultiple"
        class="hidden"
        @change="onFileSelect"
      />
      <woot-button
        size="small"
        variant="smooth"
        color-scheme="secondary"
        icon="attach"
        :is-disabled="isUploading"
        @click="$refs.fileInput.click()"
      >
        {{ $t('CUSTOM_ATTRIBUTES.FILE.UPLOAD_BUTTON') }}
      </woot-button>
      <span v-if="isUploading" class="text-xs text-slate-600 dark:text-slate-400 ml-2">
        {{ $t('CUSTOM_ATTRIBUTES.FILE.UPLOADING') }}
      </span>
    </div>

    <div v-if="files.length > 0" class="files-list mt-2">
      <div
        v-for="(file, index) in files"
        :key="index"
        class="file-item flex items-center justify-between p-2 mb-1 bg-slate-50 dark:bg-slate-800 rounded"
      >
        <div class="flex items-center flex-1 min-w-0">
          <fluent-icon :icon="getFileIcon(file.content_type)" size="16" class="flex-shrink-0" />
          <button
            class="ml-2 text-sm truncate hover:underline text-left flex-1 min-w-0"
            :title="file.filename"
            @click="onFileClick(file, index)"
          >
            {{ file.filename }}
          </button>
          <span class="ml-2 text-xs text-slate-500">
            ({{ formatFileSize(file.file_size) }})
          </span>
        </div>
        <woot-button
          v-if="!isUploading"
          variant="link"
          size="small"
          color-scheme="secondary"
          icon="dismiss"
          @click="onDeleteFile(index)"
        />
      </div>
    </div>

    <p v-if="files.length >= maxFiles" class="text-xs text-slate-600 dark:text-slate-400 mt-2">
      {{ $t('CUSTOM_ATTRIBUTES.FILE.MAX_FILES_REACHED', { max: maxFiles }) }}
    </p>

    <!-- GalleryView para imagens -->
    <gallery-view
      v-if="showGalleryViewer"
      :show.sync="showGalleryViewer"
      :attachment="selectedFileAttachment"
      :all-attachments="imageAttachments"
      @close="onCloseGallery"
    />
  </div>
</template>

<script>
import { useAlert } from 'dashboard/composables';
import ContactAttributeFilesAPI from 'dashboard/api/contactAttributeFiles';
import FluentIcon from 'shared/components/FluentIcon/Index.vue';
import GalleryView from 'dashboard/components/widgets/conversation/components/GalleryView.vue';

const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB

export default {
  components: {
    FluentIcon,
    GalleryView,
  },
  props: {
    value: {
      type: [Object, Array],
      default: () => [],
    },
    contactId: {
      type: Number,
      required: true,
    },
    attributeKey: {
      type: String,
      required: true,
    },
    maxFiles: {
      type: Number,
      default: 5,
    },
  },
  data() {
    return {
      isUploading: false,
      files: [],
      showGalleryViewer: false,
      selectedFileAttachment: null,
    };
  },
  computed: {
    allowMultiple() {
      return this.maxFiles > 1;
    },
    acceptedFileTypes() {
      return [
        'image/*',
        'application/pdf',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/vnd.ms-excel',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'text/plain',
        'text/csv',
      ].join(',');
    },
    imageAttachments() {
      return this.files
        .filter(file => file.content_type && file.content_type.startsWith('image/'))
        .map((file, index) => ({
          message_id: `file_${index}`,
          file_type: 'image',
          data_url: file.file_url,
          filename: file.filename,
          file_size: file.file_size,
          content_type: file.content_type,
        }));
    },
  },
  watch: {
    value: {
      immediate: true,
      handler(newValue) {
        if (Array.isArray(newValue)) {
          this.files = newValue;
        } else if (newValue && typeof newValue === 'object') {
          this.files = [newValue];
        } else {
          this.files = [];
        }
      },
    },
  },
  methods: {
    async onFileSelect(event) {
      const selectedFiles = Array.from(event.target.files);
      
      console.log('Files selected:', selectedFiles.length, 'Contact ID:', this.contactId, 'Attribute:', this.attributeKey);
      
      // Validate file count
      if (this.files.length + selectedFiles.length > this.maxFiles) {
        useAlert(
          this.$t('CUSTOM_ATTRIBUTES.FILE.TOO_MANY_FILES', { max: this.maxFiles })
        );
        return;
      }

      // Validate file sizes
      const oversizedFiles = selectedFiles.filter(file => file.size > MAX_FILE_SIZE);
      if (oversizedFiles.length > 0) {
        console.error('Files too large:', oversizedFiles.map(f => ({ name: f.name, size: f.size })));
        useAlert(this.$t('CUSTOM_ATTRIBUTES.FILE.FILE_TOO_LARGE'));
        return;
      }

      this.isUploading = true;

      try {
        console.log('Starting upload...');
        const response = await ContactAttributeFilesAPI.upload(
          this.contactId,
          this.attributeKey,
          selectedFiles.length === 1 ? selectedFiles[0] : selectedFiles
        );

        console.log('Upload response:', response.data);
        const uploadedFiles = response.data.files || [response.data];
        this.files = [...this.files, ...uploadedFiles];
        this.emitUpdate();

        useAlert(this.$t('CUSTOM_ATTRIBUTES.FILE.UPLOAD_SUCCESS'));
      } catch (error) {
        console.error('Upload failed:', error);
        console.error('Error response:', error?.response?.data);
        console.error('Error status:', error?.response?.status);
        
        const errorMessage = error?.response?.data?.error || 
                            error?.message || 
                            this.$t('CUSTOM_ATTRIBUTES.FILE.UPLOAD_ERROR');
        useAlert(errorMessage);
      } finally {
        this.isUploading = false;
        // Reset input
        event.target.value = '';
      }
    },

    async onDeleteFile(index) {
      const file = this.files[index];

      try {
        await ContactAttributeFilesAPI.delete(
          this.contactId,
          this.attributeKey,
          file.blob_key
        );

        this.files.splice(index, 1);
        this.emitUpdate();

        useAlert(this.$t('CUSTOM_ATTRIBUTES.FILE.DELETE_SUCCESS'));
      } catch (error) {
        useAlert(
          error?.response?.data?.error ||
            this.$t('CUSTOM_ATTRIBUTES.FILE.DELETE_ERROR')
        );
      }
    },

    emitUpdate() {
      const value = this.maxFiles === 1 ? this.files[0] || null : this.files;
      console.log('CustomAttributeFileUpload - Emitting update:', {
        attributeKey: this.attributeKey,
        value: value,
        files: this.files
      });
      this.$emit('input', value);
      this.$emit('update', this.attributeKey, value);
    },

    getFileIcon(contentType) {
      if (!contentType) return 'document';
      
      if (contentType.startsWith('image/')) return 'image';
      if (contentType.includes('pdf')) return 'document';
      if (contentType.includes('word') || contentType.includes('document')) return 'document';
      if (contentType.includes('sheet') || contentType.includes('excel')) return 'document';
      if (contentType.includes('zip') || contentType.includes('compressed')) return 'document';
      
      return 'document';
    },

    formatFileSize(bytes) {
      if (!bytes) return '0 B';
      
      const k = 1024;
      const sizes = ['B', 'KB', 'MB', 'GB'];
      const i = Math.floor(Math.log(bytes) / Math.log(k));
      
      return `${parseFloat((bytes / Math.pow(k, i)).toFixed(2))} ${sizes[i]}`;
    },

    onFileClick(file, index) {
      if (file.content_type && file.content_type.startsWith('image/')) {
        // Para imagens, abrir no GalleryView
        this.selectedFileAttachment = {
          message_id: `file_${index}`,
          file_type: 'image',
          data_url: file.file_url,
          filename: file.filename,
          file_size: file.file_size,
          content_type: file.content_type,
        };
        this.showGalleryViewer = true;
      } else if (file.content_type === 'application/pdf') {
        // Para PDFs, abrir em nova aba
        window.open(file.file_url, '_blank', 'noopener,noreferrer');
      } else {
        // Para outros tipos, fazer download
        const link = document.createElement('a');
        link.href = file.file_url;
        link.download = file.filename;
        link.target = '_blank';
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
      }
    },

    onCloseGallery() {
      this.showGalleryViewer = false;
      this.selectedFileAttachment = null;
    },
  },
};
</script>

<style scoped>
.file-upload-wrapper {
  @apply w-full;
}

.upload-area {
  @apply flex items-center;
}

.files-list {
  @apply space-y-1;
}

.file-item {
  @apply transition-colors;
}

.file-item:hover {
  @apply bg-slate-100 dark:bg-slate-700;
}
</style>

