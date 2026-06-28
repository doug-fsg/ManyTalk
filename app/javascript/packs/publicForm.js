import Vue from 'vue';
import '../publicForm/application.scss';
import App from '../publicForm/App.vue';

Vue.config.productionTip = false;

window.onload = () => {
  window.PUBLIC_FORM_APP = new Vue({
    render: h => h(App),
  }).$mount('#app');
};
