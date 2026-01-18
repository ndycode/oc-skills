---
name: i18n-localization
description: Internationalization with next-intl and RTL support
metadata:
  short-description: i18n localization
---

# Internationalization (i18n)

> **Sources**: [next-intl](https://github.com/amannn/next-intl) (2.5k⭐), [ICU Message Format](https://unicode-org.github.io/icu/userguide/format_parse/messages/), [CLDR](https://cldr.unicode.org/)
> **Auto-trigger**: Files containing `next-intl`, `useTranslations`, `getTranslations`, `messages/`, locale files, `[locale]` folder structure

---

## Setup with next-intl

### Installation
```bash
npm install next-intl
```

### Project Structure
```
├── messages/
│   ├── en.json
│   ├── es.json
│   └── ar.json
├── app/
│   └── [locale]/
│       ├── layout.tsx
│       └── page.tsx
├── i18n/
│   ├── request.ts
│   └── routing.ts
└── middleware.ts
```

### Routing Configuration
```typescript
// i18n/routing.ts
import { defineRouting } from 'next-intl/routing';
import { createNavigation } from 'next-intl/navigation';

export const routing = defineRouting({
  locales: ['en', 'es', 'ar', 'ja', 'zh'],
  defaultLocale: 'en',
  localePrefix: 'as-needed', // or 'always' | 'never'
});

export const { Link, redirect, usePathname, useRouter } =
  createNavigation(routing);
```

### Request Configuration
```typescript
// i18n/request.ts
import { getRequestConfig } from 'next-intl/server';
import { routing } from './routing';

export default getRequestConfig(async ({ requestLocale }) => {
  let locale = await requestLocale;

  // Validate locale
  if (!locale || !routing.locales.includes(locale as any)) {
    locale = routing.defaultLocale;
  }

  return {
    locale,
    messages: (await import(`../messages/${locale}.json`)).default,
  };
});
```

### Middleware
```typescript
// middleware.ts
import createMiddleware from 'next-intl/middleware';
import { routing } from './i18n/routing';

export default createMiddleware(routing);

export const config = {
  matcher: [
    // Match all pathnames except:
    '/((?!api|_next|_vercel|.*\\..*).*)',
  ],
};
```

### Root Layout
```typescript
// app/[locale]/layout.tsx
import { NextIntlClientProvider } from 'next-intl';
import { getMessages, setRequestLocale } from 'next-intl/server';
import { routing } from '@/i18n/routing';
import { notFound } from 'next/navigation';

export function generateStaticParams() {
  return routing.locales.map((locale) => ({ locale }));
}

export default async function LocaleLayout({
  children,
  params: { locale },
}: {
  children: React.ReactNode;
  params: { locale: string };
}) {
  // Validate locale
  if (!routing.locales.includes(locale as any)) {
    notFound();
  }

  // Enable static rendering
  setRequestLocale(locale);

  const messages = await getMessages();

  return (
    <html lang={locale} dir={locale === 'ar' ? 'rtl' : 'ltr'}>
      <body>
        <NextIntlClientProvider messages={messages}>
          {children}
        </NextIntlClientProvider>
      </body>
    </html>
  );
}
```

---

## Message Files

### Basic Structure
```json
// messages/en.json
{
  "common": {
    "loading": "Loading...",
    "error": "An error occurred",
    "save": "Save",
    "cancel": "Cancel",
    "delete": "Delete",
    "confirm": "Are you sure?"
  },
  "nav": {
    "home": "Home",
    "about": "About",
    "products": "Products",
    "contact": "Contact"
  },
  "auth": {
    "login": "Log in",
    "logout": "Log out",
    "signup": "Sign up",
    "forgotPassword": "Forgot password?"
  },
  "home": {
    "title": "Welcome to Our App",
    "subtitle": "Build something amazing today"
  }
}
```

### ICU Message Format
```json
// messages/en.json
{
  "messages": {
    "greeting": "Hello, {name}!",

    "itemCount": "{count, plural, =0 {No items} one {# item} other {# items}}",

    "gender": "{gender, select, male {He} female {She} other {They}} liked your post",

    "lastSeen": "Last seen {date, date, medium} at {date, time, short}",

    "price": "Price: {amount, number, ::currency/USD}",

    "percentage": "Completed: {value, number, ::percent}",

    "ordinal": "You finished {place, selectordinal, one {#st} two {#nd} few {#rd} other {#th}}",

    "richText": "Please <link>click here</link> to continue",

    "nested": "You have {count, plural, =0 {no new messages} one {<b>one</b> new message} other {<b>#</b> new messages}}"
  }
}
```

### Spanish Translation
```json
// messages/es.json
{
  "messages": {
    "greeting": "¡Hola, {name}!",

    "itemCount": "{count, plural, =0 {Sin artículos} one {# artículo} other {# artículos}}",

    "gender": "{gender, select, male {A él} female {A ella} other {A ellos}} le gustó tu publicación",

    "lastSeen": "Visto por última vez el {date, date, medium} a las {date, time, short}",

    "price": "Precio: {amount, number, ::currency/USD}"
  }
}
```

### Arabic (RTL)
```json
// messages/ar.json
{
  "common": {
    "loading": "جار التحميل...",
    "save": "حفظ",
    "cancel": "إلغاء"
  },
  "messages": {
    "greeting": "مرحباً، {name}!",
    "itemCount": "{count, plural, =0 {لا توجد عناصر} one {عنصر واحد} two {عنصران} few {# عناصر} many {# عنصر} other {# عنصر}}"
  }
}
```

---

## Using Translations

### Server Components
```typescript
// app/[locale]/page.tsx
import { useTranslations } from 'next-intl';
import { setRequestLocale } from 'next-intl/server';

export default function HomePage({
  params: { locale },
}: {
  params: { locale: string };
}) {
  setRequestLocale(locale);
  const t = useTranslations('home');

  return (
    <div>
      <h1>{t('title')}</h1>
      <p>{t('subtitle')}</p>
    </div>
  );
}
```

### Client Components
```typescript
'use client';

import { useTranslations } from 'next-intl';

export function Greeting({ name }: { name: string }) {
  const t = useTranslations('messages');

  return (
    <div>
      {/* Simple interpolation */}
      <p>{t('greeting', { name })}</p>

      {/* Pluralization */}
      <p>{t('itemCount', { count: 5 })}</p>

      {/* Date/Time formatting */}
      <p>{t('lastSeen', { date: new Date() })}</p>

      {/* Number formatting */}
      <p>{t('price', { amount: 29.99 })}</p>
    </div>
  );
}
```

### Rich Text (HTML in Translations)
```typescript
'use client';

import { useTranslations } from 'next-intl';
import Link from 'next/link';

export function RichTextExample() {
  const t = useTranslations('messages');

  return (
    <div>
      {t.rich('richText', {
        link: (chunks) => <Link href="/continue">{chunks}</Link>,
      })}

      {t.rich('nested', {
        count: 5,
        b: (chunks) => <strong>{chunks}</strong>,
      })}
    </div>
  );
}
```

### Async Server Actions
```typescript
// app/actions.ts
'use server';

import { getTranslations } from 'next-intl/server';

export async function submitForm(formData: FormData) {
  const t = await getTranslations('form');

  // Validate
  const email = formData.get('email');
  if (!email) {
    return { error: t('errors.emailRequired') };
  }

  return { success: t('success.formSubmitted') };
}
```

---

## Formatting

### Date & Time
```typescript
import { useFormatter, useNow } from 'next-intl';

function DateExamples() {
  const format = useFormatter();
  const now = useNow();

  return (
    <div>
      {/* Relative time */}
      <p>{format.relativeTime(new Date('2024-01-01'))}</p>
      {/* "2 months ago" */}

      {/* Date formatting */}
      <p>{format.dateTime(now, { dateStyle: 'full' })}</p>
      {/* "Friday, March 15, 2024" */}

      <p>{format.dateTime(now, { timeStyle: 'short' })}</p>
      {/* "3:45 PM" */}

      {/* Custom format */}
      <p>
        {format.dateTime(now, {
          year: 'numeric',
          month: 'long',
          day: 'numeric',
        })}
      </p>
      {/* "March 15, 2024" */}
    </div>
  );
}
```

### Numbers & Currency
```typescript
import { useFormatter } from 'next-intl';

function NumberExamples() {
  const format = useFormatter();

  return (
    <div>
      {/* Currency */}
      <p>{format.number(1234.56, { style: 'currency', currency: 'USD' })}</p>
      {/* "$1,234.56" */}

      {/* Percentage */}
      <p>{format.number(0.856, { style: 'percent' })}</p>
      {/* "86%" */}

      {/* Compact */}
      <p>{format.number(1500000, { notation: 'compact' })}</p>
      {/* "1.5M" */}

      {/* Units */}
      <p>{format.number(50, { style: 'unit', unit: 'kilometer' })}</p>
      {/* "50 km" */}
    </div>
  );
}
```

### Lists
```typescript
import { useFormatter } from 'next-intl';

function ListExample() {
  const format = useFormatter();
  const items = ['Apple', 'Banana', 'Cherry'];

  return (
    <div>
      <p>{format.list(items, { type: 'conjunction' })}</p>
      {/* "Apple, Banana, and Cherry" */}

      <p>{format.list(items, { type: 'disjunction' })}</p>
      {/* "Apple, Banana, or Cherry" */}
    </div>
  );
}
```

---

## RTL Support

### Layout Configuration
```typescript
// app/[locale]/layout.tsx
export default async function LocaleLayout({
  children,
  params: { locale },
}: {
  children: React.ReactNode;
  params: { locale: string };
}) {
  const isRTL = ['ar', 'he', 'fa', 'ur'].includes(locale);

  return (
    <html lang={locale} dir={isRTL ? 'rtl' : 'ltr'}>
      <body className={isRTL ? 'rtl' : 'ltr'}>{children}</body>
    </html>
  );
}
```

### CSS for RTL
```css
/* globals.css */
:root {
  --start: left;
  --end: right;
}

[dir='rtl'] {
  --start: right;
  --end: left;
}

/* Use logical properties */
.container {
  padding-inline-start: 1rem; /* Left in LTR, Right in RTL */
  padding-inline-end: 1rem;
  margin-inline-start: auto;
  text-align: start;
}

/* Directional icons need flipping */
[dir='rtl'] .icon-arrow {
  transform: scaleX(-1);
}

/* Tailwind CSS (v3+) */
.sidebar {
  @apply ps-4 pe-2 ms-auto text-start;
}
```

### Component Example
```typescript
'use client';

import { useLocale } from 'next-intl';

export function DirectionalIcon({ icon }: { icon: 'arrow' | 'chevron' }) {
  const locale = useLocale();
  const isRTL = ['ar', 'he', 'fa'].includes(locale);

  return (
    <span
      style={{
        display: 'inline-block',
        transform: isRTL ? 'scaleX(-1)' : 'none',
      }}
    >
      {icon === 'arrow' ? '→' : '›'}
    </span>
  );
}
```

---

## Language Switcher

```typescript
'use client';

import { useLocale } from 'next-intl';
import { usePathname, useRouter } from '@/i18n/routing';
import { routing } from '@/i18n/routing';

const localeNames: Record<string, string> = {
  en: 'English',
  es: 'Español',
  ar: 'العربية',
  ja: '日本語',
  zh: '中文',
};

export function LanguageSwitcher() {
  const locale = useLocale();
  const router = useRouter();
  const pathname = usePathname();

  const handleChange = (newLocale: string) => {
    router.replace(pathname, { locale: newLocale });
  };

  return (
    <select
      value={locale}
      onChange={(e) => handleChange(e.target.value)}
      aria-label="Select language"
    >
      {routing.locales.map((loc) => (
        <option key={loc} value={loc}>
          {localeNames[loc]}
        </option>
      ))}
    </select>
  );
}
```

### With Flags
```typescript
'use client';

import { useLocale } from 'next-intl';
import { Link, usePathname } from '@/i18n/routing';
import { routing } from '@/i18n/routing';

const localeConfig = {
  en: { name: 'English', flag: '🇺🇸' },
  es: { name: 'Español', flag: '🇪🇸' },
  ar: { name: 'العربية', flag: '🇸🇦' },
  ja: { name: '日本語', flag: '🇯🇵' },
  zh: { name: '中文', flag: '🇨🇳' },
};

export function LanguageMenu() {
  const locale = useLocale();
  const pathname = usePathname();

  return (
    <div className="language-menu">
      {routing.locales.map((loc) => (
        <Link
          key={loc}
          href={pathname}
          locale={loc}
          className={locale === loc ? 'active' : ''}
        >
          <span>{localeConfig[loc].flag}</span>
          <span>{localeConfig[loc].name}</span>
        </Link>
      ))}
    </div>
  );
}
```

---

## SEO for i18n

### Metadata with Locale
```typescript
// app/[locale]/page.tsx
import { getTranslations, setRequestLocale } from 'next-intl/server';
import type { Metadata } from 'next';

export async function generateMetadata({
  params: { locale },
}: {
  params: { locale: string };
}): Promise<Metadata> {
  const t = await getTranslations({ locale, namespace: 'home' });

  return {
    title: t('meta.title'),
    description: t('meta.description'),
    alternates: {
      canonical: `https://myapp.com/${locale}`,
      languages: {
        en: 'https://myapp.com/en',
        es: 'https://myapp.com/es',
        ar: 'https://myapp.com/ar',
      },
    },
    openGraph: {
      locale: locale,
      alternateLocale: ['en', 'es', 'ar'].filter((l) => l !== locale),
    },
  };
}
```

---

## Anti-Patterns

```typescript
// ❌ NEVER: Hardcode strings
return <button>Submit</button>;

// ✅ CORRECT: Use translations
const t = useTranslations('common');
return <button>{t('submit')}</button>;

// ❌ NEVER: Concatenate translated strings
const message = t('hello') + ' ' + t('world');

// ✅ CORRECT: Single translation with variables
// messages: { greeting: "Hello, {name}! Welcome to {app}." }
const message = t('greeting', { name: 'John', app: 'MyApp' });

// ❌ NEVER: Use physical directions for RTL
style={{ marginLeft: '10px', textAlign: 'left' }}

// ✅ CORRECT: Use logical properties
style={{ marginInlineStart: '10px', textAlign: 'start' }}

// ❌ NEVER: Store locale in state
const [locale, setLocale] = useState('en');

// ✅ CORRECT: Use URL-based locale
const locale = useLocale(); // From URL segment
```

---

## Quick Reference

### ICU Plural Categories
| Language | Categories |
|----------|------------|
| English | one, other |
| French | one, other |
| Arabic | zero, one, two, few, many, other |
| Japanese | other |
| Russian | one, few, many, other |

### Logical CSS Properties
| Physical | Logical |
|----------|---------|
| `left` | `inline-start` |
| `right` | `inline-end` |
| `margin-left` | `margin-inline-start` |
| `padding-right` | `padding-inline-end` |
| `text-align: left` | `text-align: start` |
| `float: right` | `float: inline-end` |
| `border-left` | `border-inline-start` |

### Date Style Options
| Style | Example (en-US) |
|-------|-----------------|
| `full` | Friday, March 15, 2024 |
| `long` | March 15, 2024 |
| `medium` | Mar 15, 2024 |
| `short` | 3/15/24 |

### Checklist
- [ ] All user-facing strings in message files
- [ ] ICU format for plurals/gender/dates
- [ ] RTL support with logical CSS properties
- [ ] Language switcher accessible
- [ ] SEO: hreflang tags, localized metadata
- [ ] Fallback locale configured
- [ ] Date/number formatting localized
- [ ] Static generation for all locales
