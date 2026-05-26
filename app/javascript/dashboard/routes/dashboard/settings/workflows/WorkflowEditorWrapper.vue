<script setup>
/**
 * Layout dedicado ao editor de fluxo: ocupa toda a área de conteúdo
 * (sem max-w-6xl nem header duplicado de Settings).
 */
</script>

<template>
  <div
    class="workflow-editor-layout flex flex-col flex-1 w-full min-h-0 h-full overflow-hidden bg-white dark:bg-slate-900"
  >
    <router-view />
  </div>
</template>
