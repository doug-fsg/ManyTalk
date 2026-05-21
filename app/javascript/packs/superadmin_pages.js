import 'chart.js';
import { createApp, h, configureCompat } from 'vue';
import VueDOMPurifyHTML from 'vue-dompurify-html';
import { compatConfig } from 'shared/compatConfig';

configureCompat(compatConfig);

const PlaygroundIndex = () =>
  import('../superadmin_pages/views/playground/Index.vue');

const ComponentMapping = {
  PlaygroundIndex: PlaygroundIndex,
};

const renderComponent = (componentName, props) => {
  const app = createApp({
    data: () => ({ props }),
    render() {
      return h(ComponentMapping[componentName], { 'component-data': this.props });
    },
  });

  app.use(VueDOMPurifyHTML);
  app.mount('#app');
};

document.addEventListener('DOMContentLoaded', () => {
  const element = document.getElementById('app');
  if (element) {
    const componentName = element.dataset.componentName;
    const props = JSON.parse(element.dataset.props);
    renderComponent(componentName, props);
  }
});
