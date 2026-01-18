# Search Patterns

> **Sources**: [Meilisearch](https://github.com/meilisearch/meilisearch) (47k⭐), [Algolia](https://www.algolia.com/doc/), [PostgreSQL Full-Text Search](https://www.postgresql.org/docs/current/textsearch.html)
> **Auto-trigger**: Files containing search functionality, `meilisearch`, `algolia`, full-text search, `tsvector`, autocomplete, faceted search

---

## Technology Selection

| Tool | Best For | Self-Hosted | Latency |
|------|----------|-------------|---------|
| **Meilisearch** | Documents, e-commerce | Yes | <50ms |
| **Algolia** | Enterprise, scale | No | <20ms |
| **PostgreSQL FTS** | Simple search, low volume | Built-in | Varies |
| **Elasticsearch** | Complex queries, analytics | Yes | <100ms |

---

## Meilisearch

### Setup
```bash
# Docker
docker run -p 7700:7700 getmeili/meilisearch:latest

# Install client
npm install meilisearch
```

### Client Configuration
```typescript
// lib/meilisearch.ts
import { MeiliSearch } from 'meilisearch';

export const meilisearch = new MeiliSearch({
  host: process.env.MEILISEARCH_HOST || 'http://localhost:7700',
  apiKey: process.env.MEILISEARCH_API_KEY,
});

// Index names
export const INDEXES = {
  PRODUCTS: 'products',
  POSTS: 'posts',
  USERS: 'users',
} as const;
```

### Index Configuration
```typescript
// lib/search/setup.ts
import { meilisearch, INDEXES } from '@/lib/meilisearch';

export async function setupSearchIndexes() {
  // Create products index
  const productsIndex = meilisearch.index(INDEXES.PRODUCTS);

  await productsIndex.updateSettings({
    // Searchable attributes (order matters for relevance)
    searchableAttributes: [
      'name',
      'description',
      'brand',
      'category',
      'tags',
    ],
    // Attributes to return in results
    displayedAttributes: [
      'id',
      'name',
      'description',
      'price',
      'image',
      'category',
      'brand',
      'rating',
    ],
    // Filterable for facets
    filterableAttributes: [
      'category',
      'brand',
      'price',
      'rating',
      'inStock',
    ],
    // Sortable
    sortableAttributes: [
      'price',
      'rating',
      'createdAt',
    ],
    // Typo tolerance
    typoTolerance: {
      enabled: true,
      minWordSizeForTypos: {
        oneTypo: 4,
        twoTypos: 8,
      },
    },
    // Pagination
    pagination: {
      maxTotalHits: 1000,
    },
  });

  // Posts index
  const postsIndex = meilisearch.index(INDEXES.POSTS);
  await postsIndex.updateSettings({
    searchableAttributes: ['title', 'content', 'author', 'tags'],
    filterableAttributes: ['author', 'publishedAt', 'status', 'category'],
    sortableAttributes: ['publishedAt', 'viewCount'],
  });
}
```

### Indexing Data
```typescript
// lib/search/sync.ts
import { meilisearch, INDEXES } from '@/lib/meilisearch';
import { db } from '@/lib/db';

interface SearchableProduct {
  id: string;
  name: string;
  description: string;
  price: number;
  category: string;
  brand: string;
  tags: string[];
  rating: number;
  inStock: boolean;
  image: string;
}

// Full reindex
export async function reindexProducts() {
  const products = await db.product.findMany({
    where: { status: 'published' },
    include: { category: true, brand: true },
  });

  const documents: SearchableProduct[] = products.map((p) => ({
    id: p.id,
    name: p.name,
    description: p.description,
    price: p.price,
    category: p.category.name,
    brand: p.brand.name,
    tags: p.tags,
    rating: p.rating,
    inStock: p.stock > 0,
    image: p.images[0] || '',
  }));

  const index = meilisearch.index(INDEXES.PRODUCTS);
  
  // Add or replace documents
  const task = await index.addDocuments(documents);
  
  // Wait for indexing to complete
  await meilisearch.waitForTask(task.taskUid);
}

// Incremental sync (on product update)
export async function syncProduct(productId: string) {
  const product = await db.product.findUnique({
    where: { id: productId },
    include: { category: true, brand: true },
  });

  const index = meilisearch.index(INDEXES.PRODUCTS);

  if (!product || product.status !== 'published') {
    // Remove from index
    await index.deleteDocument(productId);
  } else {
    // Update in index
    await index.addDocuments([{
      id: product.id,
      name: product.name,
      // ... map other fields
    }]);
  }
}

// Prisma middleware for auto-sync
prisma.$use(async (params, next) => {
  const result = await next(params);

  if (params.model === 'Product') {
    if (['create', 'update', 'delete'].includes(params.action)) {
      const productId = params.args.where?.id || result.id;
      await syncProduct(productId).catch(console.error);
    }
  }

  return result;
});
```

### Search API
```typescript
// app/api/search/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { meilisearch, INDEXES } from '@/lib/meilisearch';
import { z } from 'zod';

const searchSchema = z.object({
  q: z.string().min(1).max(100),
  page: z.coerce.number().min(1).default(1),
  limit: z.coerce.number().min(1).max(50).default(20),
  category: z.string().optional(),
  brand: z.string().optional(),
  minPrice: z.coerce.number().optional(),
  maxPrice: z.coerce.number().optional(),
  sort: z.enum(['price:asc', 'price:desc', 'rating:desc']).optional(),
});

export async function GET(req: NextRequest) {
  const params = Object.fromEntries(req.nextUrl.searchParams);
  const result = searchSchema.safeParse(params);

  if (!result.success) {
    return NextResponse.json({ error: 'Invalid parameters' }, { status: 400 });
  }

  const { q, page, limit, category, brand, minPrice, maxPrice, sort } = result.data;

  // Build filters
  const filters: string[] = [];
  if (category) filters.push(`category = "${category}"`);
  if (brand) filters.push(`brand = "${brand}"`);
  if (minPrice !== undefined) filters.push(`price >= ${minPrice}`);
  if (maxPrice !== undefined) filters.push(`price <= ${maxPrice}`);
  filters.push('inStock = true');

  const index = meilisearch.index(INDEXES.PRODUCTS);

  const searchResults = await index.search(q, {
    limit,
    offset: (page - 1) * limit,
    filter: filters.length > 0 ? filters.join(' AND ') : undefined,
    sort: sort ? [sort] : undefined,
    // Get facet counts
    facets: ['category', 'brand'],
    // Highlight matches
    attributesToHighlight: ['name', 'description'],
    highlightPreTag: '<mark>',
    highlightPostTag: '</mark>',
  });

  return NextResponse.json({
    hits: searchResults.hits,
    total: searchResults.estimatedTotalHits,
    page,
    limit,
    facets: searchResults.facetDistribution,
    processingTimeMs: searchResults.processingTimeMs,
  });
}
```

### Autocomplete
```typescript
// app/api/search/autocomplete/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { meilisearch, INDEXES } from '@/lib/meilisearch';

export async function GET(req: NextRequest) {
  const q = req.nextUrl.searchParams.get('q');
  if (!q || q.length < 2) {
    return NextResponse.json({ suggestions: [] });
  }

  const index = meilisearch.index(INDEXES.PRODUCTS);

  const results = await index.search(q, {
    limit: 8,
    attributesToRetrieve: ['id', 'name', 'category'],
    attributesToHighlight: ['name'],
  });

  const suggestions = results.hits.map((hit) => ({
    id: hit.id,
    name: hit.name,
    category: hit.category,
    highlighted: hit._formatted?.name || hit.name,
  }));

  return NextResponse.json({ suggestions });
}
```

### React Component
```typescript
// components/SearchBox.tsx
'use client';

import { useState, useEffect, useRef } from 'react';
import { useDebounce } from '@/hooks/useDebounce';

interface Suggestion {
  id: string;
  name: string;
  category: string;
  highlighted: string;
}

export function SearchBox() {
  const [query, setQuery] = useState('');
  const [suggestions, setSuggestions] = useState<Suggestion[]>([]);
  const [isOpen, setIsOpen] = useState(false);
  const debouncedQuery = useDebounce(query, 200);

  useEffect(() => {
    if (debouncedQuery.length < 2) {
      setSuggestions([]);
      return;
    }

    fetch(`/api/search/autocomplete?q=${encodeURIComponent(debouncedQuery)}`)
      .then((res) => res.json())
      .then((data) => setSuggestions(data.suggestions))
      .catch(() => setSuggestions([]));
  }, [debouncedQuery]);

  return (
    <div className="relative">
      <input
        type="search"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        onFocus={() => setIsOpen(true)}
        placeholder="Search products..."
        className="w-full px-4 py-2 border rounded-lg"
      />

      {isOpen && suggestions.length > 0 && (
        <ul className="absolute w-full mt-1 bg-white border rounded-lg shadow-lg z-10">
          {suggestions.map((suggestion) => (
            <li key={suggestion.id}>
              <a
                href={`/products/${suggestion.id}`}
                className="block px-4 py-2 hover:bg-gray-100"
                dangerouslySetInnerHTML={{ __html: suggestion.highlighted }}
              />
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
```

---

## Algolia

### Setup
```bash
npm install algoliasearch
```

### Client Configuration
```typescript
// lib/algolia.ts
import algoliasearch from 'algoliasearch';

export const algoliaClient = algoliasearch(
  process.env.ALGOLIA_APP_ID!,
  process.env.ALGOLIA_ADMIN_KEY!
);

export const algoliaSearchClient = algoliasearch(
  process.env.ALGOLIA_APP_ID!,
  process.env.ALGOLIA_SEARCH_KEY! // Read-only key for frontend
);

export const productsIndex = algoliaClient.initIndex('products');
```

### Index Configuration
```typescript
// lib/algolia/setup.ts
import { productsIndex } from '@/lib/algolia';

export async function configureAlgoliaIndex() {
  await productsIndex.setSettings({
    searchableAttributes: [
      'name',
      'description',
      'brand',
      'category',
    ],
    attributesForFaceting: [
      'filterOnly(inStock)',
      'category',
      'brand',
      'searchable(tags)',
    ],
    customRanking: [
      'desc(rating)',
      'desc(popularity)',
    ],
    attributesToSnippet: [
      'description:50',
    ],
    attributesToHighlight: [
      'name',
      'description',
    ],
  });
}
```

### Indexing
```typescript
// lib/algolia/sync.ts
import { productsIndex } from '@/lib/algolia';

export async function indexProducts(products: Product[]) {
  const objects = products.map((p) => ({
    objectID: p.id,
    name: p.name,
    description: p.description,
    price: p.price,
    category: p.category,
    brand: p.brand,
    tags: p.tags,
    rating: p.rating,
    popularity: p.salesCount,
    inStock: p.stock > 0,
    image: p.images[0],
  }));

  await productsIndex.saveObjects(objects);
}

// Partial update
export async function updateProduct(productId: string, updates: Partial<Product>) {
  await productsIndex.partialUpdateObject({
    objectID: productId,
    ...updates,
  });
}

// Delete
export async function deleteProduct(productId: string) {
  await productsIndex.deleteObject(productId);
}
```

---

## PostgreSQL Full-Text Search

### Schema Setup
```sql
-- Add tsvector column
ALTER TABLE posts ADD COLUMN search_vector tsvector;

-- Create index
CREATE INDEX posts_search_idx ON posts USING GIN(search_vector);

-- Update function
CREATE OR REPLACE FUNCTION update_search_vector()
RETURNS TRIGGER AS $$
BEGIN
  NEW.search_vector := 
    setweight(to_tsvector('english', COALESCE(NEW.title, '')), 'A') ||
    setweight(to_tsvector('english', COALESCE(NEW.content, '')), 'B') ||
    setweight(to_tsvector('english', COALESCE(NEW.author, '')), 'C');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger
CREATE TRIGGER posts_search_update
BEFORE INSERT OR UPDATE ON posts
FOR EACH ROW
EXECUTE FUNCTION update_search_vector();
```

### Prisma Raw Queries
```typescript
// lib/search/postgres.ts
import { db } from '@/lib/db';

export async function searchPosts(query: string, limit = 20, offset = 0) {
  // Convert query to tsquery format
  const tsquery = query
    .split(/\s+/)
    .filter(Boolean)
    .map((term) => `${term}:*`)
    .join(' & ');

  const results = await db.$queryRaw<Array<{
    id: string;
    title: string;
    content: string;
    rank: number;
    headline: string;
  }>>`
    SELECT 
      id,
      title,
      content,
      ts_rank(search_vector, to_tsquery('english', ${tsquery})) as rank,
      ts_headline(
        'english',
        content,
        to_tsquery('english', ${tsquery}),
        'StartSel=<mark>, StopSel=</mark>, MaxWords=50, MinWords=25'
      ) as headline
    FROM posts
    WHERE search_vector @@ to_tsquery('english', ${tsquery})
    ORDER BY rank DESC
    LIMIT ${limit}
    OFFSET ${offset}
  `;

  return results;
}
```

---

## Anti-Patterns

```typescript
// ❌ NEVER: Search in request handler
app.get('/search', async (req, res) => {
  const products = await db.product.findMany();
  const results = products.filter(p => 
    p.name.toLowerCase().includes(query) // Slow and bad relevance
  );
});

// ✅ CORRECT: Use search engine
const results = await searchIndex.search(query);

// ❌ NEVER: Sync search index synchronously in request
app.post('/products', async (req, res) => {
  const product = await db.product.create({ data: req.body });
  await searchIndex.addDocument(product); // Blocks request!
  res.json(product);
});

// ✅ CORRECT: Async sync via queue or middleware
await queue.add('sync-product', { productId: product.id });

// ❌ NEVER: Expose admin API key to frontend
const client = algoliasearch(appId, adminKey); // Security risk!

// ✅ CORRECT: Use search-only key for frontend
const client = algoliasearch(appId, searchOnlyKey);

// ❌ NEVER: Index raw HTML
await index.addDocument({
  content: post.htmlContent, // Includes tags, scripts, etc.
});

// ✅ CORRECT: Strip HTML before indexing
await index.addDocument({
  content: stripHtml(post.htmlContent).result,
});
```

---

## Quick Reference

### Meilisearch Filter Syntax
| Operator | Example |
|----------|---------|
| Equals | `category = "Electronics"` |
| Not equals | `category != "Books"` |
| Greater than | `price > 100` |
| Less than | `price < 500` |
| Range | `price 100 TO 500` |
| IN | `category IN ["A", "B"]` |
| AND/OR | `category = "A" AND price < 100` |
| EXISTS | `brand EXISTS` |

### PostgreSQL FTS Functions
| Function | Purpose |
|----------|---------|
| `to_tsvector()` | Convert text to searchable |
| `to_tsquery()` | Convert query to search format |
| `ts_rank()` | Calculate relevance score |
| `ts_headline()` | Highlight matches |
| `setweight()` | Assign importance (A-D) |

### Indexing Best Practices
| Practice | Reason |
|----------|--------|
| Async sync | Don't block requests |
| Batch updates | Reduce API calls |
| Searchable subset | Index only what's searched |
| Facets for filtering | Fast category counts |

### Checklist
- [ ] Search index configured
- [ ] Searchable attributes prioritized
- [ ] Facets for filtering
- [ ] Typo tolerance enabled
- [ ] Highlighting configured
- [ ] Async indexing (queue)
- [ ] Search-only API key for frontend
- [ ] Pagination limits set
- [ ] Index sync on data changes
