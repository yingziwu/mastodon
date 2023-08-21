import { useEffect, useState } from 'react';

import { IntlProvider as BaseIntlProvider } from 'react-intl';

import { getLocale, isLocaleLoaded } from './global_locale';
import { loadLocale } from './load_locale';

function onProviderError(error: unknown) {
  // Silent the error, like upstream does
  if (process.env.NODE_ENV === 'production') return;

  // This browser does not advertise Intl support for this locale, we only print a warning
  // As-per the spec, the browser should select the best matching locale
  if (
    error &&
    typeof error === 'object' &&
    error instanceof Error &&
    error.message.match('MISSING_DATA')
  ) {
    console.warn(error.message);
  }

  console.error(error);
}

export const IntlProvider: React.FC<
  Omit<React.ComponentProps<typeof BaseIntlProvider>, 'locale' | 'messages'>
> = ({ children, ...props }) => {
  const [localeLoaded, setLocaleLoaded] = useState(false);

  useEffect(() => {
    async function loadLocaleData() {
      if (!isLocaleLoaded()) {
        await loadLocale();
      }

      setLocaleLoaded(true);
    }
    void loadLocaleData();
  }, []);

  if (!localeLoaded) return null;

  const { locale, messages } = getLocale();

  return (
    <BaseIntlProvider
      locale={locale}
      messages={messages}
      onError={onProviderError}
      textComponent='span'
      {...props}
    >
      {children}
    </BaseIntlProvider>
  );
};
