import Rails from '@rails/ujs';
import 'font-awesome/css/font-awesome.css';

export function start() {
  require.context('../images/', true);

  try {
    Rails.start();
  } catch (e) {
    // If called twice
  }
}
