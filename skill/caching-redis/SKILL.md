# Caching & Redis Patterns

> **Sources**: [redis/node-redis](https://github.com/redis/node-redis) (17k⭐), [TanStack/query](https://github.com/TanStack/query) (43k⭐), [vercel/swr](https://github.com/vercel/swr) (30k⭐)
> **Auto-trigger**: Files containing `redis`, `createClient`, `useQuery`, `useSWR`, `cache`, `revalidate`, `stale-while-revalidate`

---

## Redis Setup

### Installation
```bash
npm install redis
# or with ioredis
npm install ioredis
```

### Connection
```typescript
// lib/redis.ts
import { createClient } from 'redis';

const globalForRedis = globalThis as unknown as {
  redis: ReturnType<typeof createClient> | undefined;
};

export const redis =
  globalForRedis.redis ??
  createClient({
    url: process.env.REDIS_URL,
    socket: {
      reconnectStrategy: (retries) => {
        if (retries > 10) {
          return new Error('Max retries reached');
        }
        return Math.min(retries * 100, 3000);
      },
    },
  });

if (process.env.NODE_ENV !== 'production') {
  globalForRedis.redis = redis;
}

// Connect on startup
redis.on('error', (err) => console.error('Redis Error:', err));
redis.on('connect', () => console.log('Redis connected'));

// Ensure connection
export async function ensureRedisConnection() {
  if (!redis.isOpen) {
    await redis.connect();
  }
  return redis;
}
```

### With ioredis
```typescript
// lib/redis.ts
import Redis from 'ioredis';

const globalForRedis = globalThis as unknown as {
  redis: Redis | undefined;
};

export const redis =
  globalForRedis.redis ??
  new Redis(process.env.REDIS_URL!, {
    maxRetriesPerRequest: 3,
    retryStrategy: (times) => {
      if (times > 10) return null;
      return Math.min(times * 100, 3000);
    },
    enableReadyCheck: true,
    lazyConnect: true,
  });

if (process.env.NODE_ENV !== 'production') {
  globalForRedis.redis = redis;
}
```

---

## Basic Caching Patterns

### Cache-Aside (Read-Through)
```typescript
// lib/cache.ts
import { redis } from './redis';

interface CacheOptions {
  ttl?: number; // seconds
  staleWhileRevalidate?: number;
}

export async function cached<T>(
  key: string,
  fetcher: () => Promise<T>,
  options: CacheOptions = {}
): Promise<T> {
  const { ttl = 3600, staleWhileRevalidate = 60 } = options;
  const cacheKey = `cache:${key}`;
  const metaKey = `cache:meta:${key}`;

  await redis.connect().catch(() => {}); // Ensure connected

  // Try to get from cache
  const cached = await redis.get(cacheKey);

  if (cached) {
    const meta = await redis.get(metaKey);
    const isStale = meta ? Date.now() > parseInt(meta) : false;

    if (isStale) {
      // Return stale data, revalidate in background
      setImmediate(async () => {
        try {
          const fresh = await fetcher();
          await setCache(cacheKey, metaKey, fresh, ttl, staleWhileRevalidate);
        } catch (error) {
          console.error('Background revalidation failed:', error);
        }
      });
    }

    return JSON.parse(cached) as T;
  }

  // Cache miss - fetch and cache
  const data = await fetcher();
  await setCache(cacheKey, metaKey, data, ttl, staleWhileRevalidate);

  return data;
}

async function setCache(
  cacheKey: string,
  metaKey: string,
  data: unknown,
  ttl: number,
  swr: number
) {
  const pipeline = redis.multi();
  pipeline.set(cacheKey, JSON.stringify(data), { EX: ttl + swr });
  pipeline.set(metaKey, (Date.now() + ttl * 1000).toString(), { EX: ttl + swr });
  await pipeline.exec();
}

// Usage
const user = await cached(
  `user:${userId}`,
  () => db.user.findUnique({ where: { id: userId } }),
  { ttl: 300, staleWhileRevalidate: 60 }
);
```

### Cache Invalidation
```typescript
// lib/cache.ts
export async function invalidateCache(pattern: string): Promise<void> {
  const keys = await redis.keys(`cache:${pattern}`);
  if (keys.length > 0) {
    await redis.del(keys);
    // Also delete meta keys
    const metaKeys = keys.map((k) => k.replace('cache:', 'cache:meta:'));
    await redis.del(metaKeys);
  }
}

// Tag-based invalidation
export async function cacheWithTags<T>(
  key: string,
  tags: string[],
  fetcher: () => Promise<T>,
  ttl = 3600
): Promise<T> {
  const data = await cached(key, fetcher, { ttl });

  // Store key reference for each tag
  for (const tag of tags) {
    await redis.sAdd(`tag:${tag}`, `cache:${key}`);
  }

  return data;
}

export async function invalidateByTag(tag: string): Promise<void> {
  const keys = await redis.sMembers(`tag:${tag}`);
  if (keys.length > 0) {
    await redis.del(keys);
  }
  await redis.del(`tag:${tag}`);
}

// Usage
const post = await cacheWithTags(
  `post:${postId}`,
  ['posts', `user:${post.authorId}`],
  () => getPost(postId)
);

// Invalidate all posts
await invalidateByTag('posts');

// Invalidate all content by user
await invalidateByTag(`user:${userId}`);
```

---

## Rate Limiting

### Sliding Window
```typescript
// lib/rate-limit.ts
import { redis } from './redis';

interface RateLimitResult {
  success: boolean;
  remaining: number;
  reset: number;
}

export async function rateLimit(
  identifier: string,
  limit: number,
  windowMs: number
): Promise<RateLimitResult> {
  const key = `ratelimit:${identifier}`;
  const now = Date.now();
  const windowStart = now - windowMs;

  // Use sorted set with timestamp as score
  const multi = redis.multi();

  // Remove old entries
  multi.zRemRangeByScore(key, 0, windowStart);

  // Add current request
  multi.zAdd(key, { score: now, value: now.toString() });

  // Count requests in window
  multi.zCard(key);

  // Set expiry
  multi.expire(key, Math.ceil(windowMs / 1000));

  const results = await multi.exec();
  const count = results?.[2] as number;

  const remaining = Math.max(0, limit - count);
  const reset = now + windowMs;

  return {
    success: count <= limit,
    remaining,
    reset,
  };
}

// Usage in middleware
import { NextRequest, NextResponse } from 'next/server';

export async function middleware(req: NextRequest) {
  const ip = req.ip ?? req.headers.get('x-forwarded-for') ?? 'unknown';

  const { success, remaining, reset } = await rateLimit(
    `api:${ip}`,
    100, // 100 requests
    60 * 1000 // per minute
  );

  if (!success) {
    return NextResponse.json(
      { error: 'Too many requests' },
      {
        status: 429,
        headers: {
          'X-RateLimit-Remaining': remaining.toString(),
          'X-RateLimit-Reset': reset.toString(),
          'Retry-After': Math.ceil((reset - Date.now()) / 1000).toString(),
        },
      }
    );
  }

  const response = NextResponse.next();
  response.headers.set('X-RateLimit-Remaining', remaining.toString());
  response.headers.set('X-RateLimit-Reset', reset.toString());

  return response;
}
```

### Token Bucket
```typescript
// lib/rate-limit.ts
export async function tokenBucket(
  identifier: string,
  maxTokens: number,
  refillRate: number, // tokens per second
  tokensRequired: number = 1
): Promise<{ success: boolean; tokens: number }> {
  const key = `bucket:${identifier}`;
  const now = Date.now();

  const lua = `
    local key = KEYS[1]
    local maxTokens = tonumber(ARGV[1])
    local refillRate = tonumber(ARGV[2])
    local tokensRequired = tonumber(ARGV[3])
    local now = tonumber(ARGV[4])

    local bucket = redis.call('HMGET', key, 'tokens', 'lastRefill')
    local tokens = tonumber(bucket[1]) or maxTokens
    local lastRefill = tonumber(bucket[2]) or now

    -- Refill tokens
    local elapsed = (now - lastRefill) / 1000
    tokens = math.min(maxTokens, tokens + elapsed * refillRate)

    local success = 0
    if tokens >= tokensRequired then
      tokens = tokens - tokensRequired
      success = 1
    end

    redis.call('HMSET', key, 'tokens', tokens, 'lastRefill', now)
    redis.call('EXPIRE', key, 3600)

    return {success, tokens}
  `;

  const result = await redis.eval(lua, {
    keys: [key],
    arguments: [
      maxTokens.toString(),
      refillRate.toString(),
      tokensRequired.toString(),
      now.toString(),
    ],
  });

  const [success, tokens] = result as [number, number];
  return { success: success === 1, tokens };
}
```

---

## Session Storage

```typescript
// lib/session.ts
import { redis } from './redis';
import { randomUUID } from 'crypto';

interface Session {
  userId: string;
  data: Record<string, unknown>;
  createdAt: number;
  expiresAt: number;
}

const SESSION_TTL = 7 * 24 * 60 * 60; // 7 days

export async function createSession(
  userId: string,
  data: Record<string, unknown> = {}
): Promise<string> {
  const sessionId = randomUUID();
  const now = Date.now();

  const session: Session = {
    userId,
    data,
    createdAt: now,
    expiresAt: now + SESSION_TTL * 1000,
  };

  await redis.set(`session:${sessionId}`, JSON.stringify(session), {
    EX: SESSION_TTL,
  });

  // Track user sessions for logout-all functionality
  await redis.sAdd(`user:sessions:${userId}`, sessionId);
  await redis.expire(`user:sessions:${userId}`, SESSION_TTL);

  return sessionId;
}

export async function getSession(sessionId: string): Promise<Session | null> {
  const data = await redis.get(`session:${sessionId}`);
  if (!data) return null;

  const session = JSON.parse(data) as Session;

  // Sliding expiration
  await redis.expire(`session:${sessionId}`, SESSION_TTL);

  return session;
}

export async function destroySession(sessionId: string): Promise<void> {
  const session = await getSession(sessionId);
  if (session) {
    await redis.sRem(`user:sessions:${session.userId}`, sessionId);
  }
  await redis.del(`session:${sessionId}`);
}

export async function destroyAllUserSessions(userId: string): Promise<void> {
  const sessionIds = await redis.sMembers(`user:sessions:${userId}`);
  if (sessionIds.length > 0) {
    await redis.del(sessionIds.map((id) => `session:${id}`));
  }
  await redis.del(`user:sessions:${userId}`);
}
```

---

## React Query (TanStack Query)

### Setup
```typescript
// lib/query-client.ts
import { QueryClient } from '@tanstack/react-query';

export function makeQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: {
        staleTime: 60 * 1000, // 1 minute
        gcTime: 5 * 60 * 1000, // 5 minutes (formerly cacheTime)
        retry: 3,
        retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 30000),
        refetchOnWindowFocus: false,
      },
      mutations: {
        retry: 1,
      },
    },
  });
}

// app/providers.tsx
'use client';

import { QueryClientProvider } from '@tanstack/react-query';
import { ReactQueryDevtools } from '@tanstack/react-query-devtools';
import { useState } from 'react';
import { makeQueryClient } from '@/lib/query-client';

export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => makeQueryClient());

  return (
    <QueryClientProvider client={queryClient}>
      {children}
      <ReactQueryDevtools initialIsOpen={false} />
    </QueryClientProvider>
  );
}
```

### Query Patterns
```typescript
// hooks/useUser.ts
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';

// Query keys factory
export const userKeys = {
  all: ['users'] as const,
  lists: () => [...userKeys.all, 'list'] as const,
  list: (filters: string) => [...userKeys.lists(), { filters }] as const,
  details: () => [...userKeys.all, 'detail'] as const,
  detail: (id: string) => [...userKeys.details(), id] as const,
};

// Fetch user
export function useUser(userId: string) {
  return useQuery({
    queryKey: userKeys.detail(userId),
    queryFn: async () => {
      const response = await fetch(`/api/users/${userId}`);
      if (!response.ok) throw new Error('Failed to fetch user');
      return response.json();
    },
    staleTime: 5 * 60 * 1000, // 5 minutes
  });
}

// Update user with optimistic updates
export function useUpdateUser() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ userId, data }: { userId: string; data: Partial<User> }) => {
      const response = await fetch(`/api/users/${userId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
      });
      if (!response.ok) throw new Error('Failed to update user');
      return response.json();
    },
    onMutate: async ({ userId, data }) => {
      // Cancel outgoing refetches
      await queryClient.cancelQueries({ queryKey: userKeys.detail(userId) });

      // Snapshot previous value
      const previousUser = queryClient.getQueryData(userKeys.detail(userId));

      // Optimistically update
      queryClient.setQueryData(userKeys.detail(userId), (old: User) => ({
        ...old,
        ...data,
      }));

      return { previousUser };
    },
    onError: (err, { userId }, context) => {
      // Rollback on error
      queryClient.setQueryData(
        userKeys.detail(userId),
        context?.previousUser
      );
    },
    onSettled: (data, error, { userId }) => {
      // Refetch to ensure consistency
      queryClient.invalidateQueries({ queryKey: userKeys.detail(userId) });
    },
  });
}

// Prefetch
export async function prefetchUser(queryClient: QueryClient, userId: string) {
  await queryClient.prefetchQuery({
    queryKey: userKeys.detail(userId),
    queryFn: () => fetch(`/api/users/${userId}`).then((r) => r.json()),
  });
}
```

### Infinite Queries
```typescript
import { useInfiniteQuery } from '@tanstack/react-query';

export function useInfinitePosts() {
  return useInfiniteQuery({
    queryKey: ['posts', 'infinite'],
    queryFn: async ({ pageParam = 0 }) => {
      const response = await fetch(`/api/posts?cursor=${pageParam}&limit=20`);
      return response.json();
    },
    getNextPageParam: (lastPage) => lastPage.nextCursor ?? undefined,
    getPreviousPageParam: (firstPage) => firstPage.prevCursor ?? undefined,
    initialPageParam: 0,
  });
}

// Usage
function PostList() {
  const {
    data,
    fetchNextPage,
    hasNextPage,
    isFetchingNextPage,
    status,
  } = useInfinitePosts();

  return (
    <div>
      {data?.pages.map((page, i) => (
        <Fragment key={i}>
          {page.posts.map((post) => (
            <Post key={post.id} post={post} />
          ))}
        </Fragment>
      ))}

      <button
        onClick={() => fetchNextPage()}
        disabled={!hasNextPage || isFetchingNextPage}
      >
        {isFetchingNextPage
          ? 'Loading...'
          : hasNextPage
          ? 'Load More'
          : 'No more posts'}
      </button>
    </div>
  );
}
```

---

## SWR

### Basic Usage
```typescript
// hooks/useUser.ts
import useSWR from 'swr';

const fetcher = (url: string) => fetch(url).then((r) => r.json());

export function useUser(userId: string) {
  const { data, error, isLoading, mutate } = useSWR(
    userId ? `/api/users/${userId}` : null,
    fetcher,
    {
      revalidateOnFocus: false,
      revalidateIfStale: true,
      dedupingInterval: 60000, // 1 minute
    }
  );

  return {
    user: data,
    isLoading,
    isError: error,
    mutate,
  };
}
```

### SWR with Optimistic Updates
```typescript
import useSWR, { useSWRConfig } from 'swr';

export function useOptimisticUpdate() {
  const { mutate } = useSWRConfig();

  const updateUser = async (userId: string, newData: Partial<User>) => {
    // Optimistic update
    mutate(
      `/api/users/${userId}`,
      (current: User) => ({ ...current, ...newData }),
      false // Don't revalidate yet
    );

    try {
      await fetch(`/api/users/${userId}`, {
        method: 'PATCH',
        body: JSON.stringify(newData),
      });
      // Revalidate after success
      mutate(`/api/users/${userId}`);
    } catch (error) {
      // Revert on error
      mutate(`/api/users/${userId}`);
      throw error;
    }
  };

  return { updateUser };
}
```

---

## Next.js Caching

### Route Segment Config
```typescript
// app/api/posts/route.ts
export const revalidate = 3600; // Revalidate every hour
export const dynamic = 'force-static'; // or 'force-dynamic'

// app/posts/[slug]/page.tsx
export const revalidate = 60;
```

### On-Demand Revalidation
```typescript
// app/api/revalidate/route.ts
import { revalidatePath, revalidateTag } from 'next/cache';
import { NextRequest, NextResponse } from 'next/server';

export async function POST(req: NextRequest) {
  const { secret, path, tag } = await req.json();

  if (secret !== process.env.REVALIDATION_SECRET) {
    return NextResponse.json({ error: 'Invalid secret' }, { status: 401 });
  }

  if (path) {
    revalidatePath(path);
  }

  if (tag) {
    revalidateTag(tag);
  }

  return NextResponse.json({ revalidated: true, now: Date.now() });
}

// Usage in data fetching
async function getPosts() {
  const res = await fetch('https://api.example.com/posts', {
    next: { tags: ['posts'] },
  });
  return res.json();
}

// Revalidate from webhook
await fetch('/api/revalidate', {
  method: 'POST',
  body: JSON.stringify({ secret: '...', tag: 'posts' }),
});
```

---

## Anti-Patterns

```typescript
// ❌ NEVER: Cache without TTL
await redis.set('key', 'value'); // Never expires!

// ✅ CORRECT: Always set expiration
await redis.set('key', 'value', { EX: 3600 });

// ❌ NEVER: Store sensitive data in cache
await redis.set('user:123:password', hashedPassword);

// ✅ CORRECT: Only cache non-sensitive, reconstructable data
await redis.set('user:123:profile', JSON.stringify(publicProfile));

// ❌ NEVER: Ignore cache stampede
// 1000 requests hit expired cache simultaneously
const data = await cached('popular-key', expensiveFetch);

// ✅ CORRECT: Use locking or stale-while-revalidate
const data = await cached('popular-key', expensiveFetch, {
  staleWhileRevalidate: 60,
});

// ❌ NEVER: Invalidate with KEYS in production
const keys = await redis.keys('cache:*'); // Blocks Redis!

// ✅ CORRECT: Use SCAN or tag-based invalidation
for await (const key of redis.scanIterator({ MATCH: 'cache:*' })) {
  await redis.del(key);
}

// ❌ NEVER: Cache errors
if (!result) {
  await redis.set('key', null); // Caching the miss!
}

// ✅ CORRECT: Only cache successful results
if (result) {
  await redis.set('key', JSON.stringify(result));
}
```

---

## Quick Reference

### Redis Data Types
| Type | Commands | Use Case |
|------|----------|----------|
| String | GET, SET, INCR | Simple values, counters |
| Hash | HGET, HSET, HMGET | Objects, user profiles |
| List | LPUSH, RPOP, LRANGE | Queues, recent items |
| Set | SADD, SMEMBERS, SINTER | Tags, unique items |
| Sorted Set | ZADD, ZRANGE, ZRANK | Leaderboards, rate limits |

### React Query vs SWR
| Feature | React Query | SWR |
|---------|-------------|-----|
| Devtools | Yes | No |
| Mutations | Built-in | Manual |
| Infinite | Built-in | `useSWRInfinite` |
| Bundle | ~13kb | ~4kb |
| Complexity | Higher | Lower |

### Cache Headers
| Header | Purpose |
|--------|---------|
| `Cache-Control: max-age=3600` | Cache for 1 hour |
| `Cache-Control: s-maxage=3600` | CDN cache for 1 hour |
| `Cache-Control: stale-while-revalidate=60` | Serve stale for 60s |
| `Cache-Control: no-store` | Never cache |

### Checklist
- [ ] TTL on all cached items
- [ ] Stale-while-revalidate for popular keys
- [ ] Tag-based invalidation for related data
- [ ] Rate limiting on expensive operations
- [ ] Error handling (don't cache errors)
- [ ] Connection pooling for Redis
- [ ] SCAN instead of KEYS in production
- [ ] Optimistic updates for UX
