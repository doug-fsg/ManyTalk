<template>
  <div class="empty-state py-16 px-1 ml-0 mr-0">
    <h3
      v-if="title"
      class="text-slate-700 dark:text-slate-200 block text-center w-full text-xl font-thin"
    >
      {{ title }}
    </h3>
    <p
      v-if="message"
      class="block text-center text-slate-500 dark:text-slate-400 my-4 mx-auto w-[90%]"
    >
      {{ message }}
    </p>
    <div class="flex justify-center w-full mt-2">
      <slot />
    </div>
  </div>
</template>

<script>
export default {
  props: {
    title: { type: String, default: '' },
    message: { type: String, default: '' },
  },
};
</script>
