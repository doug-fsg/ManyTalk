import Rails from '@rails/ujs';
import Turbolinks from 'turbolinks';
import '../portal/application.scss';
import {
  InitializationHelpers,
  setupPortalTurbolinks,
} from '../portal/portalHelpers';

Rails.start();
Turbolinks.start();

setupPortalTurbolinks();
document.addEventListener('turbolinks:load', InitializationHelpers.onLoad);
