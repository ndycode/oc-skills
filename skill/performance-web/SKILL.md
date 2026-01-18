# Web Performance Best Practices

> **Auto-trigger**: Performance optimization, Lighthouse audits, Core Web Vitals

---

## 1. Core Web Vitals

### 1.1 Metrics

| Metric | Good | Needs Improvement | Poor |
|--------|------|-------------------|------|
| **LCP** (Largest Contentful Paint) | ≤2.5s | 2.5s - 4s | >4s |
| **INP** (Interaction to Next Paint) | ≤200ms | 200ms - 500ms | >500ms |
| **CLS** (Cumulative Layout Shift) | ≤0.1 | 0.1 - 0.25 | >0.25 |

### 1.2 Measuring

```typescript
// Using web-vitals library
import { onLCP, onINP, onCLS } from 'web-vitals';

function sendToAnalytics(metric) {
  const body = JSON.stringify({
    name: metric.name,
    value: metric.value,
    delta: metric.delta,
    id: metric.id,
    page: window.location.pathname,
  });
  
  navigator.sendBeacon('/api/analytics', body);
}

onLCP(sendToAnalytics);
onINP(sendToAnalytics);
onCLS(sendToAnalytics);
```

---

## 2. Image Optimization

### 2.1 Next.js Image Component

```tsx
import Image from 'next/image';

// Responsive image
<Image
  src="/hero.jpg"
  alt="Hero image"
  width={1200}
  height={600}
  priority // Above the fold
  placeholder="blur"
  blurDataURL="data:image/jpeg;base64,..."
/>

// Fill container
<div className="relative h-64 w-full">
  <Image
    src="/product.jpg"
    alt="Product"
    fill
    sizes="(max-width: 768px) 100vw, 50vw"
    className="object-cover"
  />
</div>
```

### 2.2 Responsive Images (HTML)

```html
<picture>
  <source
    media="(min-width: 1024px)"
    srcset="/hero-lg.webp 1x, /hero-lg@2x.webp 2x"
    type="image/webp"
  />
  <source
    media="(min-width: 768px)"
    srcset="/hero-md.webp 1x, /hero-md@2x.webp 2x"
    type="image/webp"
  />
  <source srcset="/hero-sm.webp 1x, /hero-sm@2x.webp 2x" type="image/webp" />
  <img
    src="/hero-sm.jpg"
    alt="Hero"
    loading="lazy"
    decoding="async"
    width="800"
    height="400"
  />
</picture>
```

### 2.3 Lazy Loading

```tsx
// Native lazy loading
<img src="/image.jpg" loading="lazy" alt="..." />

// Intersection Observer for custom lazy loading
function useLazyLoad() {
  const ref = useRef<HTMLImageElement>(null);
  const [isLoaded, setIsLoaded] = useState(false);

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setIsLoaded(true);
          observer.disconnect();
        }
      },
      { rootMargin: '200px' }
    );

    if (ref.current) observer.observe(ref.current);
    return () => observer.disconnect();
  }, []);

  return { ref, isLoaded };
}
```

---

## 3. JavaScript Optimization

### 3.1 Code Splitting

```tsx
// Route-based splitting (Next.js does this automatically)
import dynamic from 'next/dynamic';

const HeavyChart = dynamic(() => import('@/components/Chart'), {
  loading: () => <ChartSkeleton />,
  ssr: false, // Client-only if needed
});

// React lazy
const Modal = lazy(() => import('./Modal'));

function App() {
  return (
    <Suspense fallback={<ModalSkeleton />}>
      {showModal && <Modal />}
    </Suspense>
  );
}
```

### 3.2 Bundle Analysis

```bash
# Next.js
ANALYZE=true pnpm build

# Vite
pnpm add -D rollup-plugin-visualizer
```

```typescript
// vite.config.ts
import { visualizer } from 'rollup-plugin-visualizer';

export default defineConfig({
  plugins: [
    visualizer({
      filename: 'dist/stats.html',
      open: true,
    }),
  ],
});
```

### 3.3 Tree Shaking

```typescript
// BAD - imports entire library
import _ from 'lodash';
_.debounce(fn, 300);

// GOOD - imports only what's needed
import debounce from 'lodash/debounce';
debounce(fn, 300);

// BETTER - use native or smaller alternatives
function debounce(fn: Function, ms: number) {
  let timeoutId: ReturnType<typeof setTimeout>;
  return function (...args: unknown[]) {
    clearTimeout(timeoutId);
    timeoutId = setTimeout(() => fn(...args), ms);
  };
}
```

---

## 4. CSS Optimization

### 4.1 Critical CSS

```tsx
// Next.js automatically inlines critical CSS
// For custom setups, use critters

// next.config.js
module.exports = {
  experimental: {
    optimizeCss: true,
  },
};
```

### 4.2 Avoid Layout Shifts

```css
/* Reserve space for images */
.image-container {
  aspect-ratio: 16 / 9;
  background-color: #f0f0f0;
}

/* Reserve space for fonts */
@font-face {
  font-family: 'CustomFont';
  font-display: swap; /* or optional */
  size-adjust: 100%;
  ascent-override: 90%;
  descent-override: 20%;
}

/* Skeleton loading */
.skeleton {
  background: linear-gradient(90deg, #f0f0f0 25%, #e0e0e0 50%, #f0f0f0 75%);
  background-size: 200% 100%;
  animation: shimmer 1.5s infinite;
}

@keyframes shimmer {
  0% { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}
```

### 4.3 Contain Property

```css
/* Isolate layout calculations */
.card {
  contain: layout style paint;
}

/* Full containment for off-screen content */
.virtualized-item {
  contain: strict;
  content-visibility: auto;
  contain-intrinsic-size: 0 100px;
}
```

---

## 5. Font Optimization

### 5.1 Next.js Fonts

```tsx
// app/layout.tsx
import { Inter, Roboto_Mono } from 'next/font/google';

const inter = Inter({
  subsets: ['latin'],
  display: 'swap',
  variable: '--font-inter',
});

const robotoMono = Roboto_Mono({
  subsets: ['latin'],
  display: 'swap',
  variable: '--font-roboto-mono',
});

export default function RootLayout({ children }) {
  return (
    <html className={`${inter.variable} ${robotoMono.variable}`}>
      <body>{children}</body>
    </html>
  );
}
```

### 5.2 Preload Critical Fonts

```html
<link
  rel="preload"
  href="/fonts/inter-var.woff2"
  as="font"
  type="font/woff2"
  crossorigin="anonymous"
/>
```

### 5.3 Font Subsetting

```css
/* Only load characters you need */
@font-face {
  font-family: 'CustomFont';
  src: url('/fonts/custom-latin.woff2') format('woff2');
  unicode-range: U+0000-00FF, U+0131, U+0152-0153;
  font-display: swap;
}
```

---

## 6. Caching Strategies

### 6.1 HTTP Cache Headers

```typescript
// next.config.js
module.exports = {
  async headers() {
    return [
      {
        source: '/:all*(svg|jpg|png|webp|avif)',
        headers: [
          {
            key: 'Cache-Control',
            value: 'public, max-age=31536000, immutable',
          },
        ],
      },
      {
        source: '/_next/static/:path*',
        headers: [
          {
            key: 'Cache-Control',
            value: 'public, max-age=31536000, immutable',
          },
        ],
      },
    ];
  },
};
```

### 6.2 Service Worker Caching

```typescript
// Using Workbox
import { precacheAndRoute } from 'workbox-precaching';
import { registerRoute } from 'workbox-routing';
import { StaleWhileRevalidate, CacheFirst } from 'workbox-strategies';

// Precache app shell
precacheAndRoute(self.__WB_MANIFEST);

// Cache images
registerRoute(
  ({ request }) => request.destination === 'image',
  new CacheFirst({
    cacheName: 'images',
    plugins: [
      new ExpirationPlugin({
        maxEntries: 60,
        maxAgeSeconds: 30 * 24 * 60 * 60, // 30 days
      }),
    ],
  })
);

// Cache API responses
registerRoute(
  ({ url }) => url.pathname.startsWith('/api/'),
  new StaleWhileRevalidate({
    cacheName: 'api-cache',
  })
);
```

---

## 7. Prefetching & Preloading

### 7.1 Link Prefetching

```tsx
// Next.js - automatic for Link components
import Link from 'next/link';

<Link href="/dashboard">Dashboard</Link>

// Disable prefetch for less important links
<Link href="/settings" prefetch={false}>Settings</Link>

// Manual prefetch
import { useRouter } from 'next/navigation';

const router = useRouter();

function handleHover() {
  router.prefetch('/dashboard');
}
```

### 7.2 Resource Hints

```html
<!-- DNS prefetch for external domains -->
<link rel="dns-prefetch" href="https://fonts.googleapis.com" />

<!-- Preconnect for critical third parties -->
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />

<!-- Preload critical resources -->
<link rel="preload" href="/critical.css" as="style" />
<link rel="preload" href="/hero.webp" as="image" />

<!-- Prefetch next page -->
<link rel="prefetch" href="/next-page.html" />
```

---

## 8. React Performance

### 8.1 Memoization

```tsx
// Memoize components
const MemoizedComponent = memo(function ExpensiveList({ items }) {
  return items.map(item => <Item key={item.id} {...item} />);
});

// Memoize values
const sortedItems = useMemo(() => {
  return [...items].sort((a, b) => a.name.localeCompare(b.name));
}, [items]);

// Memoize callbacks
const handleClick = useCallback((id: string) => {
  setSelected(id);
}, []);
```

### 8.2 Virtualization

```tsx
import { useVirtualizer } from '@tanstack/react-virtual';

function VirtualList({ items }: { items: Item[] }) {
  const parentRef = useRef<HTMLDivElement>(null);

  const virtualizer = useVirtualizer({
    count: items.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 50,
    overscan: 5,
  });

  return (
    <div ref={parentRef} className="h-[600px] overflow-auto">
      <div
        style={{
          height: `${virtualizer.getTotalSize()}px`,
          position: 'relative',
        }}
      >
        {virtualizer.getVirtualItems().map((virtualItem) => (
          <div
            key={virtualItem.key}
            style={{
              position: 'absolute',
              top: 0,
              left: 0,
              width: '100%',
              height: `${virtualItem.size}px`,
              transform: `translateY(${virtualItem.start}px)`,
            }}
          >
            <Item data={items[virtualItem.index]} />
          </div>
        ))}
      </div>
    </div>
  );
}
```

### 8.3 Concurrent Features

```tsx
// useTransition for non-urgent updates
function Search() {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState([]);
  const [isPending, startTransition] = useTransition();

  function handleChange(e) {
    setQuery(e.target.value);
    startTransition(() => {
      setResults(searchItems(e.target.value));
    });
  }

  return (
    <>
      <input value={query} onChange={handleChange} />
      {isPending && <Spinner />}
      <ResultsList results={results} />
    </>
  );
}

// useDeferredValue
function List({ items }) {
  const deferredItems = useDeferredValue(items);
  const isStale = items !== deferredItems;

  return (
    <div style={{ opacity: isStale ? 0.5 : 1 }}>
      {deferredItems.map(item => <Item key={item.id} {...item} />)}
    </div>
  );
}
```

---

## 9. Lighthouse Audit Fixes

### 9.1 Common Issues

| Issue | Fix |
|-------|-----|
| Render-blocking resources | Inline critical CSS, defer JS |
| Large images | Use Next.js Image, WebP/AVIF |
| Unused JavaScript | Code split, tree shake |
| No text compression | Enable gzip/brotli |
| Long main thread tasks | Break up work, use workers |
| CLS from images | Set width/height or aspect-ratio |
| CLS from fonts | Use font-display: swap |
| Slow server response | Edge caching, optimize queries |

### 9.2 Audit Script

```json
// package.json
{
  "scripts": {
    "lighthouse": "lhci autorun",
    "lighthouse:open": "npx lighthouse http://localhost:3000 --view"
  }
}
```

```yaml
# lighthouserc.js
module.exports = {
  ci: {
    collect: {
      url: ['http://localhost:3000/', 'http://localhost:3000/dashboard'],
      numberOfRuns: 3,
    },
    assert: {
      assertions: {
        'categories:performance': ['error', { minScore: 0.9 }],
        'categories:accessibility': ['error', { minScore: 0.9 }],
        'first-contentful-paint': ['error', { maxNumericValue: 2000 }],
        'largest-contentful-paint': ['error', { maxNumericValue: 2500 }],
      },
    },
    upload: {
      target: 'temporary-public-storage',
    },
  },
};
```

---

## Quick Reference

### Performance Budget

| Resource | Budget |
|----------|--------|
| Total JS | <200KB gzipped |
| Total CSS | <50KB gzipped |
| Total images | <500KB |
| Fonts | <100KB |
| Third-party | <100KB |
| LCP | <2.5s |
| TTI | <3.8s |

### Checklist

**Images**
- [ ] Use modern formats (WebP, AVIF)
- [ ] Responsive images with srcset
- [ ] Lazy load below-fold images
- [ ] Set explicit dimensions

**JavaScript**
- [ ] Code splitting by route
- [ ] Tree shaking enabled
- [ ] Defer non-critical scripts
- [ ] Remove unused dependencies

**CSS**
- [ ] Critical CSS inlined
- [ ] Unused CSS removed
- [ ] Avoid layout shifts
- [ ] Use content-visibility

**Fonts**
- [ ] Use font-display: swap
- [ ] Subset fonts
- [ ] Preload critical fonts
- [ ] Self-host if possible

**Caching**
- [ ] Long cache for static assets
- [ ] Versioned filenames
- [ ] Service worker for offline
