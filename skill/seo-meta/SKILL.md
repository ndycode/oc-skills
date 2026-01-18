# SEO & Metadata

> **Sources**: [Next.js Metadata Docs](https://nextjs.org/docs/app/building-your-application/optimizing/metadata), [Schema.org](https://schema.org/), [Open Graph Protocol](https://ogp.me/)
> **Auto-trigger**: Files containing `metadata`, `generateMetadata`, `opengraph`, `JsonLd`, `robots.txt`, `sitemap.xml`, SEO-related configurations

---

## Next.js Metadata API (App Router)

### Static Metadata
```typescript
// app/layout.tsx
import type { Metadata } from 'next';

export const metadata: Metadata = {
  // Base metadata
  title: {
    default: 'My App',
    template: '%s | My App', // Page title | My App
  },
  description: 'A comprehensive description for search engines (150-160 chars)',
  keywords: ['keyword1', 'keyword2', 'keyword3'],

  // Canonical URL
  metadataBase: new URL('https://myapp.com'),
  alternates: {
    canonical: '/',
    languages: {
      'en-US': '/en-US',
      'es-ES': '/es-ES',
    },
  },

  // Open Graph
  openGraph: {
    type: 'website',
    locale: 'en_US',
    url: 'https://myapp.com',
    siteName: 'My App',
    title: 'My App - Tagline',
    description: 'Description for social sharing',
    images: [
      {
        url: '/og-image.png',
        width: 1200,
        height: 630,
        alt: 'My App Preview',
      },
    ],
  },

  // Twitter Card
  twitter: {
    card: 'summary_large_image',
    site: '@myapp',
    creator: '@creator',
    title: 'My App',
    description: 'Description for Twitter',
    images: ['/twitter-image.png'],
  },

  // Robots
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      'max-video-preview': -1,
      'max-image-preview': 'large',
      'max-snippet': -1,
    },
  },

  // Icons
  icons: {
    icon: '/favicon.ico',
    shortcut: '/favicon-16x16.png',
    apple: '/apple-touch-icon.png',
    other: {
      rel: 'mask-icon',
      url: '/safari-pinned-tab.svg',
    },
  },

  // Manifest
  manifest: '/site.webmanifest',

  // Verification
  verification: {
    google: 'google-site-verification-code',
    yandex: 'yandex-verification-code',
  },

  // App-specific
  applicationName: 'My App',
  authors: [{ name: 'Author', url: 'https://author.com' }],
  generator: 'Next.js',
  referrer: 'origin-when-cross-origin',
  creator: 'Creator Name',
  publisher: 'Publisher Name',
  formatDetection: {
    email: false,
    address: false,
    telephone: false,
  },
};
```

### Dynamic Metadata
```typescript
// app/blog/[slug]/page.tsx
import type { Metadata, ResolvingMetadata } from 'next';
import { notFound } from 'next/navigation';
import { getPost } from '@/lib/posts';

interface Props {
  params: { slug: string };
}

export async function generateMetadata(
  { params }: Props,
  parent: ResolvingMetadata
): Promise<Metadata> {
  const post = await getPost(params.slug);

  if (!post) {
    return {};
  }

  // Optionally access parent metadata
  const previousImages = (await parent).openGraph?.images || [];

  return {
    title: post.title,
    description: post.excerpt,
    authors: [{ name: post.author.name }],
    publishedTime: post.publishedAt,
    modifiedTime: post.updatedAt,

    openGraph: {
      type: 'article',
      title: post.title,
      description: post.excerpt,
      url: `/blog/${params.slug}`,
      publishedTime: post.publishedAt,
      modifiedTime: post.updatedAt,
      authors: [post.author.name],
      images: [
        {
          url: post.coverImage,
          width: 1200,
          height: 630,
          alt: post.title,
        },
        ...previousImages,
      ],
    },

    twitter: {
      card: 'summary_large_image',
      title: post.title,
      description: post.excerpt,
      images: [post.coverImage],
    },
  };
}

export default async function BlogPost({ params }: Props) {
  const post = await getPost(params.slug);
  if (!post) notFound();

  return <article>{/* ... */}</article>;
}
```

### Product Page Metadata
```typescript
// app/products/[id]/page.tsx
import type { Metadata } from 'next';
import { getProduct } from '@/lib/products';

export async function generateMetadata({ params }): Promise<Metadata> {
  const product = await getProduct(params.id);

  return {
    title: product.name,
    description: product.description,

    openGraph: {
      type: 'product',
      title: product.name,
      description: product.description,
      images: product.images.map((img) => ({
        url: img.url,
        width: 800,
        height: 800,
        alt: product.name,
      })),
    },

    other: {
      'product:price:amount': product.price.toString(),
      'product:price:currency': 'USD',
      'product:availability': product.inStock ? 'instock' : 'oos',
    },
  };
}
```

---

## JSON-LD Structured Data

### Organization Schema
```typescript
// components/JsonLd.tsx
export function OrganizationJsonLd() {
  const jsonLd = {
    '@context': 'https://schema.org',
    '@type': 'Organization',
    name: 'My Company',
    url: 'https://mycompany.com',
    logo: 'https://mycompany.com/logo.png',
    sameAs: [
      'https://twitter.com/mycompany',
      'https://linkedin.com/company/mycompany',
      'https://github.com/mycompany',
    ],
    contactPoint: {
      '@type': 'ContactPoint',
      telephone: '+1-800-555-1234',
      contactType: 'customer service',
      availableLanguage: ['English', 'Spanish'],
    },
  };

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
    />
  );
}
```

### Article Schema
```typescript
// components/ArticleJsonLd.tsx
interface ArticleJsonLdProps {
  title: string;
  description: string;
  url: string;
  imageUrl: string;
  datePublished: string;
  dateModified: string;
  authorName: string;
  authorUrl?: string;
}

export function ArticleJsonLd({
  title,
  description,
  url,
  imageUrl,
  datePublished,
  dateModified,
  authorName,
  authorUrl,
}: ArticleJsonLdProps) {
  const jsonLd = {
    '@context': 'https://schema.org',
    '@type': 'Article',
    headline: title,
    description,
    url,
    image: imageUrl,
    datePublished,
    dateModified,
    author: {
      '@type': 'Person',
      name: authorName,
      url: authorUrl,
    },
    publisher: {
      '@type': 'Organization',
      name: 'My Company',
      logo: {
        '@type': 'ImageObject',
        url: 'https://mycompany.com/logo.png',
      },
    },
    mainEntityOfPage: {
      '@type': 'WebPage',
      '@id': url,
    },
  };

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
    />
  );
}
```

### Product Schema
```typescript
// components/ProductJsonLd.tsx
interface ProductJsonLdProps {
  name: string;
  description: string;
  image: string;
  price: number;
  currency: string;
  sku: string;
  brand: string;
  availability: 'InStock' | 'OutOfStock' | 'PreOrder';
  rating?: {
    value: number;
    count: number;
  };
  reviews?: Array<{
    author: string;
    rating: number;
    body: string;
    date: string;
  }>;
}

export function ProductJsonLd({
  name,
  description,
  image,
  price,
  currency,
  sku,
  brand,
  availability,
  rating,
  reviews,
}: ProductJsonLdProps) {
  const jsonLd: any = {
    '@context': 'https://schema.org',
    '@type': 'Product',
    name,
    description,
    image,
    sku,
    brand: {
      '@type': 'Brand',
      name: brand,
    },
    offers: {
      '@type': 'Offer',
      price,
      priceCurrency: currency,
      availability: `https://schema.org/${availability}`,
      url: typeof window !== 'undefined' ? window.location.href : '',
    },
  };

  if (rating) {
    jsonLd.aggregateRating = {
      '@type': 'AggregateRating',
      ratingValue: rating.value,
      reviewCount: rating.count,
    };
  }

  if (reviews?.length) {
    jsonLd.review = reviews.map((review) => ({
      '@type': 'Review',
      author: { '@type': 'Person', name: review.author },
      reviewRating: {
        '@type': 'Rating',
        ratingValue: review.rating,
      },
      reviewBody: review.body,
      datePublished: review.date,
    }));
  }

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
    />
  );
}
```

### FAQ Schema
```typescript
// components/FaqJsonLd.tsx
interface FaqItem {
  question: string;
  answer: string;
}

export function FaqJsonLd({ items }: { items: FaqItem[] }) {
  const jsonLd = {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: items.map((item) => ({
      '@type': 'Question',
      name: item.question,
      acceptedAnswer: {
        '@type': 'Answer',
        text: item.answer,
      },
    })),
  };

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
    />
  );
}
```

### Breadcrumb Schema
```typescript
// components/BreadcrumbJsonLd.tsx
interface BreadcrumbItem {
  name: string;
  url: string;
}

export function BreadcrumbJsonLd({ items }: { items: BreadcrumbItem[] }) {
  const jsonLd = {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: items.map((item, index) => ({
      '@type': 'ListItem',
      position: index + 1,
      name: item.name,
      item: item.url,
    })),
  };

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
    />
  );
}
```

---

## Sitemap & Robots

### Dynamic Sitemap
```typescript
// app/sitemap.ts
import { MetadataRoute } from 'next';
import { getAllPosts } from '@/lib/posts';
import { getAllProducts } from '@/lib/products';

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const baseUrl = 'https://myapp.com';

  // Static pages
  const staticPages = [
    '',
    '/about',
    '/contact',
    '/pricing',
  ].map((route) => ({
    url: `${baseUrl}${route}`,
    lastModified: new Date(),
    changeFrequency: 'monthly' as const,
    priority: route === '' ? 1 : 0.8,
  }));

  // Dynamic blog posts
  const posts = await getAllPosts();
  const blogPages = posts.map((post) => ({
    url: `${baseUrl}/blog/${post.slug}`,
    lastModified: new Date(post.updatedAt),
    changeFrequency: 'weekly' as const,
    priority: 0.6,
  }));

  // Dynamic products
  const products = await getAllProducts();
  const productPages = products.map((product) => ({
    url: `${baseUrl}/products/${product.id}`,
    lastModified: new Date(product.updatedAt),
    changeFrequency: 'daily' as const,
    priority: 0.9,
  }));

  return [...staticPages, ...blogPages, ...productPages];
}
```

### Sitemap Index (Large Sites)
```typescript
// app/sitemap.ts
import { MetadataRoute } from 'next';

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    {
      url: 'https://myapp.com/sitemaps/pages.xml',
      lastModified: new Date(),
    },
    {
      url: 'https://myapp.com/sitemaps/blog.xml',
      lastModified: new Date(),
    },
    {
      url: 'https://myapp.com/sitemaps/products.xml',
      lastModified: new Date(),
    },
  ];
}

// app/sitemaps/blog.xml/route.ts
export async function GET() {
  const posts = await getAllPosts();

  const xml = `<?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
      ${posts
        .map(
          (post) => `
        <url>
          <loc>https://myapp.com/blog/${post.slug}</loc>
          <lastmod>${post.updatedAt}</lastmod>
          <changefreq>weekly</changefreq>
          <priority>0.6</priority>
        </url>
      `
        )
        .join('')}
    </urlset>`;

  return new Response(xml, {
    headers: {
      'Content-Type': 'application/xml',
    },
  });
}
```

### Robots.txt
```typescript
// app/robots.ts
import { MetadataRoute } from 'next';

export default function robots(): MetadataRoute.Robots {
  const baseUrl = 'https://myapp.com';

  return {
    rules: [
      {
        userAgent: '*',
        allow: '/',
        disallow: ['/api/', '/admin/', '/private/'],
      },
      {
        userAgent: 'Googlebot',
        allow: '/',
        disallow: '/api/',
      },
    ],
    sitemap: `${baseUrl}/sitemap.xml`,
    host: baseUrl,
  };
}
```

---

## Open Graph Images

### Static OG Image
```typescript
// app/opengraph-image.tsx (or .png, .jpg)
import { ImageResponse } from 'next/og';

export const runtime = 'edge';
export const alt = 'My App';
export const size = { width: 1200, height: 630 };
export const contentType = 'image/png';

export default async function Image() {
  return new ImageResponse(
    (
      <div
        style={{
          fontSize: 64,
          background: 'linear-gradient(to bottom, #1a1a2e, #16213e)',
          color: 'white',
          width: '100%',
          height: '100%',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <div style={{ fontSize: 80, fontWeight: 'bold' }}>My App</div>
        <div style={{ fontSize: 32, opacity: 0.8, marginTop: 20 }}>
          Build something amazing
        </div>
      </div>
    ),
    { ...size }
  );
}
```

### Dynamic OG Image
```typescript
// app/blog/[slug]/opengraph-image.tsx
import { ImageResponse } from 'next/og';
import { getPost } from '@/lib/posts';

export const runtime = 'edge';
export const alt = 'Blog Post';
export const size = { width: 1200, height: 630 };
export const contentType = 'image/png';

export default async function Image({ params }: { params: { slug: string } }) {
  const post = await getPost(params.slug);

  // Load custom font
  const interBold = fetch(
    new URL('../../../assets/Inter-Bold.ttf', import.meta.url)
  ).then((res) => res.arrayBuffer());

  return new ImageResponse(
    (
      <div
        style={{
          background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
          width: '100%',
          height: '100%',
          display: 'flex',
          flexDirection: 'column',
          padding: 60,
        }}
      >
        <div
          style={{
            fontSize: 24,
            color: 'rgba(255,255,255,0.8)',
            marginBottom: 20,
          }}
        >
          myapp.com/blog
        </div>
        <div
          style={{
            fontSize: 56,
            fontWeight: 'bold',
            color: 'white',
            lineHeight: 1.2,
            maxWidth: '80%',
          }}
        >
          {post?.title || 'Blog Post'}
        </div>
        <div
          style={{
            marginTop: 'auto',
            display: 'flex',
            alignItems: 'center',
            gap: 16,
          }}
        >
          <img
            src={post?.author.avatar}
            width={48}
            height={48}
            style={{ borderRadius: '50%' }}
          />
          <div style={{ color: 'white', fontSize: 24 }}>
            {post?.author.name}
          </div>
        </div>
      </div>
    ),
    {
      ...size,
      fonts: [
        {
          name: 'Inter',
          data: await interBold,
          style: 'normal',
          weight: 700,
        },
      ],
    }
  );
}
```

---

## Anti-Patterns

```typescript
// ❌ NEVER: Same title/description on all pages
export const metadata = {
  title: 'My App',  // Same everywhere!
  description: 'Welcome to my app',  // Same everywhere!
};

// ✅ CORRECT: Unique per page
export const metadata = {
  title: {
    default: 'My App',
    template: '%s | My App',
  },
};

// ❌ NEVER: Missing OG images
// Social shares look broken without images!

// ✅ CORRECT: Always provide OG images
openGraph: {
  images: [{ url: '/og-image.png', width: 1200, height: 630 }],
}

// ❌ NEVER: Hardcoded URLs
url: 'http://localhost:3000/page'

// ✅ CORRECT: Use metadataBase
metadataBase: new URL(process.env.NEXT_PUBLIC_APP_URL),

// ❌ NEVER: Skip structured data for products/articles
// Missing rich snippets in search results!

// ✅ CORRECT: Add JSON-LD
<ProductJsonLd name={...} price={...} />

// ❌ NEVER: Block important pages in robots.txt
disallow: ['/products/']  // No SEO for products!

// ✅ CORRECT: Only block private/API routes
disallow: ['/api/', '/admin/']
```

---

## Quick Reference

### OG Image Sizes
| Platform | Size |
|----------|------|
| Open Graph | 1200×630 |
| Twitter | 1200×600 |
| LinkedIn | 1200×627 |
| Facebook | 1200×630 |

### Common Schema Types
| Type | Use Case |
|------|----------|
| `Article` | Blog posts, news |
| `Product` | E-commerce items |
| `FAQPage` | FAQ sections |
| `Organization` | Company info |
| `LocalBusiness` | Physical locations |
| `BreadcrumbList` | Navigation paths |
| `Review` | Customer reviews |
| `Event` | Events, webinars |

### Meta Description Best Practices
| Guideline | Value |
|-----------|-------|
| Length | 150-160 characters |
| Include | Primary keyword |
| Avoid | Duplicate descriptions |
| Style | Actionable, compelling |

### Checklist
- [ ] Unique title per page (with template)
- [ ] Unique description per page (150-160 chars)
- [ ] OG image for all pages (1200×630)
- [ ] Twitter card configured
- [ ] JSON-LD for products/articles
- [ ] Sitemap with all pages
- [ ] robots.txt configured
- [ ] Canonical URLs set
- [ ] Mobile-friendly verification
- [ ] Core Web Vitals optimized
