const path = require('path');

const resolve = {
  extensions: ['.js', '.vue'],
  alias: {
    // Vue 3 compat mode: redirect all "vue" imports to @vue/compat
    vue: '@vue/compat',
    vue$: '@vue/compat',
    dashboard: path.resolve('./app/javascript/dashboard'),
    widget: path.resolve('./app/javascript/widget'),
    survey: path.resolve('./app/javascript/survey'),
    assets: path.resolve('./app/javascript/dashboard/assets'),
    components: path.resolve('./app/javascript/dashboard/components'),
    helpers: path.resolve('./app/javascript/shared/helpers'),
    shared: path.resolve('./app/javascript/shared'),
    v3: path.resolve('./app/javascript/v3'),
    './iconfont.eot': 'vue-easytable/libs/font/iconfont.eot',
    './iconfont.woff': 'vue-easytable/libs/font/iconfont.woff',
    './iconfont.ttf': 'vue-easytable/libs/font/iconfont.ttf',
    './iconfont.svg': 'vue-easytable/libs/font/iconfont.svg',
  },
};

module.exports = resolve;
