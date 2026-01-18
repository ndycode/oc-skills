---
name: rate-limit-ddos
description: Rate limiting, DDoS protection, and Cloudflare integration
metadata:
  short-description: Rate limiting
---

# Rate Limiting & DDoS Protection

> **Sources**: [Upstash Ratelimit](https://github.com/upstash/ratelimit) (1.8k⭐), [Cloudflare WAF](https://developers.cloudflare.com/waf/), [OWASP Rate Limiting](https://cheatsheetseries.owasp.org/cheatsheets/Denial_of_Service_Cheat_Sheet.html)
> **Auto-trigger**: Files containing rate limiting, throttling, DDoS, Cloudflare, WAF, IP blocking, abuse prevention

---

## Rate Limiting Strategies

### Token Bucket (Bursty Traffic)
- Allows bursts up to bucket capacity
- Refills at constant rate
- Best for: APIs with occasional spikes

### Sliding Window (Smooth Limiting)
- Counts requests in rolling time window
- Smoother than fixed window
- Best for: Consistent rate enforcement

### Fixed Window (Simple)
- Resets at fixed intervals
- Can allow 2x limit at window boundaries
- Best for: Simple use cases

---

## Upstash Rate Limiter

### Setup
```bash
npm install @upstash/ratelimit @upstash/redis
```

### Configuration
```typescript
// lib/ratelimit.ts
import { Ratelimit } from '@upstash/ratelimit';
import { Redis } from '@upstash/redis';

const redis = new Redis({
  url: process.env.UPSTASH_REDIS_REST_URL!,
  token: process.env.UPSTASH_REDIS_REST_TOKEN!,
});

// Different rate limiters for different use cases
export const rateLimiters = {
  // API: 100 requests per 10 seconds
  api: new Ratelimit({
    redis,
    limiter: Ratelimit.slidingWindow(100, '10 s'),
    analytics: true,
    prefix: 'ratelimit:api',
  }),

  // Auth: 5 attempts per minute (prevent brute force)
  auth: new Ratelimit({
    redis,
    limiter: Ratelimit.slidingWindow(5, '1 m'),
    analytics: true,
    prefix: 'ratelimit:auth',
  }),

  // Signup: 3 per hour per IP
  signup: new Ratelimit({
    redis,
    limiter: Ratelimit.slidingWindow(3, '1 h'),
    analytics: true,
    prefix: 'ratelimit:signup',
  }),

  // AI/Expensive ops: 10 per minute
  expensive: new Ratelimit({
    redis,
    limiter: Ratelimit.tokenBucket(10, '1 m', 10),
    analytics: true,
    prefix: 'ratelimit:expensive',
  }),
};
```

### Middleware
```typescript
// middleware.ts
import { NextRequest, NextResponse } from 'next/server';
import { rateLimiters } from '@/lib/ratelimit';

export async function middleware(req: NextRequest) {
  // Skip static files
  if (req.nextUrl.pathname.startsWith('/_next')) {
    return NextResponse.next();
  }

  // Get identifier (IP or user ID)
  const ip = req.ip ?? req.headers.get('x-forwarded-for') ?? 'unknown';
  const identifier = `${ip}:${req.nextUrl.pathname}`;

  // Select rate limiter based on path
  const limiter = req.nextUrl.pathname.startsWith('/api/auth')
    ? rateLimiters.auth
    : rateLimiters.api;

  const { success, limit, reset, remaining } = await limiter.limit(identifier);

  if (!success) {
    return NextResponse.json(
      { error: 'Too many requests' },
      {
        status: 429,
        headers: {
          'X-RateLimit-Limit': limit.toString(),
          'X-RateLimit-Remaining': remaining.toString(),
          'X-RateLimit-Reset': reset.toString(),
          'Retry-After': Math.ceil((reset - Date.now()) / 1000).toString(),
        },
      }
    );
  }

  const response = NextResponse.next();
  response.headers.set('X-RateLimit-Limit', limit.toString());
  response.headers.set('X-RateLimit-Remaining', remaining.toString());
  response.headers.set('X-RateLimit-Reset', reset.toString());

  return response;
}

export const config = {
  matcher: ['/api/:path*'],
};
```

### Per-Route Rate Limiting
```typescript
// app/api/ai/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { rateLimiters } from '@/lib/ratelimit';
import { auth } from '@/lib/auth';

export async function POST(req: NextRequest) {
  const session = await auth();
  if (!session?.user) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  // Rate limit by user ID for authenticated routes
  const { success, remaining } = await rateLimiters.expensive.limit(
    `user:${session.user.id}`
  );

  if (!success) {
    return NextResponse.json(
      { error: 'Rate limit exceeded. Please try again later.' },
      { status: 429 }
    );
  }

  // Process request
  // ...
}
```

---

## Redis-Based Rate Limiting

### Sliding Window Implementation
```typescript
// lib/rate-limit-redis.ts
import { redis } from './redis';

interface RateLimitResult {
  success: boolean;
  limit: number;
  remaining: number;
  reset: number;
}

export async function rateLimit(
  key: string,
  limit: number,
  windowMs: number
): Promise<RateLimitResult> {
  const now = Date.now();
  const windowStart = now - windowMs;
  const redisKey = `ratelimit:${key}`;

  // Lua script for atomic operation
  const script = `
    -- Remove old entries
    redis.call('ZREMRANGEBYSCORE', KEYS[1], 0, ARGV[1])
    
    -- Count current entries
    local count = redis.call('ZCARD', KEYS[1])
    
    -- Check if under limit
    if count < tonumber(ARGV[2]) then
      -- Add new entry
      redis.call('ZADD', KEYS[1], ARGV[3], ARGV[3])
      redis.call('EXPIRE', KEYS[1], ARGV[4])
      return {1, count + 1}
    else
      return {0, count}
    end
  `;

  const result = await redis.eval(script, {
    keys: [redisKey],
    arguments: [
      windowStart.toString(),
      limit.toString(),
      now.toString(),
      Math.ceil(windowMs / 1000).toString(),
    ],
  }) as [number, number];

  const [allowed, count] = result;

  return {
    success: allowed === 1,
    limit,
    remaining: Math.max(0, limit - count),
    reset: now + windowMs,
  };
}
```

### Token Bucket Implementation
```typescript
// lib/token-bucket.ts
import { redis } from './redis';

export async function tokenBucket(
  key: string,
  maxTokens: number,
  refillRate: number, // tokens per second
  tokensRequired: number = 1
): Promise<{ success: boolean; tokens: number }> {
  const redisKey = `bucket:${key}`;
  const now = Date.now();

  const script = `
    local key = KEYS[1]
    local max = tonumber(ARGV[1])
    local rate = tonumber(ARGV[2])
    local required = tonumber(ARGV[3])
    local now = tonumber(ARGV[4])
    
    local data = redis.call('HMGET', key, 'tokens', 'last')
    local tokens = tonumber(data[1]) or max
    local last = tonumber(data[2]) or now
    
    -- Refill tokens
    local elapsed = (now - last) / 1000
    tokens = math.min(max, tokens + elapsed * rate)
    
    local allowed = 0
    if tokens >= required then
      tokens = tokens - required
      allowed = 1
    end
    
    redis.call('HMSET', key, 'tokens', tokens, 'last', now)
    redis.call('EXPIRE', key, 3600)
    
    return {allowed, tokens}
  `;

  const result = await redis.eval(script, {
    keys: [redisKey],
    arguments: [
      maxTokens.toString(),
      refillRate.toString(),
      tokensRequired.toString(),
      now.toString(),
    ],
  }) as [number, number];

  return {
    success: result[0] === 1,
    tokens: result[1],
  };
}
```

---

## IP Blocking

### Dynamic IP Blocklist
```typescript
// lib/ip-blocklist.ts
import { redis } from './redis';

const BLOCK_KEY = 'blocked:ips';
const TEMP_BLOCK_PREFIX = 'blocked:temp:';

// Permanent block
export async function blockIP(ip: string, reason: string): Promise<void> {
  await redis.hSet(BLOCK_KEY, ip, JSON.stringify({
    reason,
    blockedAt: new Date().toISOString(),
  }));
}

// Temporary block (auto-expires)
export async function tempBlockIP(ip: string, durationSeconds: number): Promise<void> {
  await redis.set(`${TEMP_BLOCK_PREFIX}${ip}`, '1', { EX: durationSeconds });
}

// Check if blocked
export async function isIPBlocked(ip: string): Promise<boolean> {
  const [permanent, temp] = await Promise.all([
    redis.hExists(BLOCK_KEY, ip),
    redis.exists(`${TEMP_BLOCK_PREFIX}${ip}`),
  ]);
  return permanent || temp === 1;
}

// Unblock
export async function unblockIP(ip: string): Promise<void> {
  await Promise.all([
    redis.hDel(BLOCK_KEY, ip),
    redis.del(`${TEMP_BLOCK_PREFIX}${ip}`),
  ]);
}

// Auto-block after repeated violations
export async function trackViolation(ip: string): Promise<boolean> {
  const key = `violations:${ip}`;
  const count = await redis.incr(key);
  await redis.expire(key, 3600); // 1 hour window

  if (count >= 10) {
    await tempBlockIP(ip, 24 * 60 * 60); // 24 hour block
    return true;
  }
  return false;
}
```

### IP Blocking Middleware
```typescript
// middleware.ts
import { NextRequest, NextResponse } from 'next/server';
import { isIPBlocked, trackViolation } from '@/lib/ip-blocklist';

export async function middleware(req: NextRequest) {
  const ip = req.ip ?? req.headers.get('x-forwarded-for')?.split(',')[0] ?? 'unknown';

  // Check blocklist
  if (await isIPBlocked(ip)) {
    return NextResponse.json(
      { error: 'Access denied' },
      { status: 403 }
    );
  }

  // Continue to rate limiting...
  const rateLimitResult = await rateLimit(ip);
  
  if (!rateLimitResult.success) {
    // Track violation for potential auto-block
    const blocked = await trackViolation(ip);
    
    return NextResponse.json(
      { error: blocked ? 'Access denied' : 'Rate limit exceeded' },
      { status: blocked ? 403 : 429 }
    );
  }

  return NextResponse.next();
}
```

---

## Cloudflare Integration

### Cloudflare WAF Rules
```javascript
// Example Cloudflare Worker for additional protection
export default {
  async fetch(request, env) {
    const ip = request.headers.get('CF-Connecting-IP');
    const country = request.headers.get('CF-IPCountry');
    const threatScore = request.cf?.threatScore ?? 0;

    // Block high threat scores
    if (threatScore > 50) {
      return new Response('Access denied', { status: 403 });
    }

    // Challenge suspicious countries (customize as needed)
    const challengeCountries = ['XX']; // Unknown country
    if (challengeCountries.includes(country)) {
      // Return challenge page or require verification
    }

    // Rate limiting at edge
    const { success } = await env.RATE_LIMITER.limit({ key: ip });
    if (!success) {
      return new Response('Too many requests', { status: 429 });
    }

    return fetch(request);
  },
};
```

### Turnstile CAPTCHA Integration
```typescript
// lib/turnstile.ts
const TURNSTILE_SECRET = process.env.TURNSTILE_SECRET_KEY!;

interface TurnstileResult {
  success: boolean;
  'error-codes'?: string[];
}

export async function verifyTurnstile(token: string, ip: string): Promise<boolean> {
  const response = await fetch(
    'https://challenges.cloudflare.com/turnstile/v0/siteverify',
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        secret: TURNSTILE_SECRET,
        response: token,
        remoteip: ip,
      }),
    }
  );

  const result: TurnstileResult = await response.json();
  return result.success;
}

// Usage in API route
export async function POST(req: NextRequest) {
  const { turnstileToken, ...data } = await req.json();
  const ip = req.ip ?? 'unknown';

  const isHuman = await verifyTurnstile(turnstileToken, ip);
  if (!isHuman) {
    return NextResponse.json(
      { error: 'CAPTCHA verification failed' },
      { status: 400 }
    );
  }

  // Process request...
}
```

### Client-Side Turnstile
```typescript
// components/TurnstileWidget.tsx
'use client';

import { Turnstile } from '@marsidev/react-turnstile';

interface TurnstileWidgetProps {
  onSuccess: (token: string) => void;
  onError?: () => void;
}

export function TurnstileWidget({ onSuccess, onError }: TurnstileWidgetProps) {
  return (
    <Turnstile
      siteKey={process.env.NEXT_PUBLIC_TURNSTILE_SITE_KEY!}
      onSuccess={onSuccess}
      onError={onError}
      options={{
        theme: 'auto',
        size: 'normal',
      }}
    />
  );
}
```

---

## DDoS Mitigation Patterns

### Request Validation
```typescript
// middleware.ts
export async function middleware(req: NextRequest) {
  // Reject oversized payloads early
  const contentLength = parseInt(req.headers.get('content-length') || '0');
  if (contentLength > 1024 * 1024) { // 1MB limit
    return NextResponse.json(
      { error: 'Payload too large' },
      { status: 413 }
    );
  }

  // Reject unusual methods
  const allowedMethods = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'];
  if (!allowedMethods.includes(req.method)) {
    return NextResponse.json(
      { error: 'Method not allowed' },
      { status: 405 }
    );
  }

  // Validate User-Agent (block empty or known bad)
  const userAgent = req.headers.get('user-agent');
  if (!userAgent || userAgent.length < 10) {
    return NextResponse.json(
      { error: 'Invalid request' },
      { status: 400 }
    );
  }

  return NextResponse.next();
}
```

### Slow Request Protection
```typescript
// lib/timeout.ts
export function withTimeout<T>(
  promise: Promise<T>,
  timeoutMs: number
): Promise<T> {
  return Promise.race([
    promise,
    new Promise<never>((_, reject) =>
      setTimeout(() => reject(new Error('Request timeout')), timeoutMs)
    ),
  ]);
}

// Usage
export async function POST(req: NextRequest) {
  try {
    const body = await withTimeout(req.json(), 5000); // 5s timeout for parsing
    const result = await withTimeout(processRequest(body), 30000); // 30s for processing
    return NextResponse.json(result);
  } catch (error) {
    if (error.message === 'Request timeout') {
      return NextResponse.json({ error: 'Request timeout' }, { status: 408 });
    }
    throw error;
  }
}
```

### Circuit Breaker
```typescript
// lib/circuit-breaker.ts
interface CircuitState {
  failures: number;
  lastFailure: number;
  state: 'closed' | 'open' | 'half-open';
}

const circuits = new Map<string, CircuitState>();

const FAILURE_THRESHOLD = 5;
const RECOVERY_TIMEOUT = 30000; // 30 seconds

export function withCircuitBreaker<T>(
  key: string,
  fn: () => Promise<T>
): Promise<T> {
  const circuit = circuits.get(key) || {
    failures: 0,
    lastFailure: 0,
    state: 'closed' as const,
  };

  // Check if circuit should remain open
  if (circuit.state === 'open') {
    if (Date.now() - circuit.lastFailure > RECOVERY_TIMEOUT) {
      circuit.state = 'half-open';
    } else {
      throw new Error('Circuit breaker is open');
    }
  }

  return fn()
    .then((result) => {
      // Success - reset circuit
      circuit.failures = 0;
      circuit.state = 'closed';
      circuits.set(key, circuit);
      return result;
    })
    .catch((error) => {
      // Failure - update circuit
      circuit.failures++;
      circuit.lastFailure = Date.now();

      if (circuit.failures >= FAILURE_THRESHOLD) {
        circuit.state = 'open';
      }

      circuits.set(key, circuit);
      throw error;
    });
}
```

---

## Anti-Patterns

```typescript
// ❌ NEVER: Rate limit only on success
if (response.ok) {
  await rateLimiter.consume(ip); // Attacker never gets limited!
}

// ✅ CORRECT: Rate limit before processing
const { success } = await rateLimiter.limit(ip);
if (!success) return error429;

// ❌ NEVER: Trust X-Forwarded-For blindly
const ip = req.headers.get('x-forwarded-for'); // Can be spoofed!

// ✅ CORRECT: Use trusted proxy headers
const ip = req.ip ?? req.headers.get('cf-connecting-ip') ?? 
           req.headers.get('x-forwarded-for')?.split(',')[0];

// ❌ NEVER: Same limit for all operations
const limiter = new Ratelimit(100, '1 m'); // Same for login and read?

// ✅ CORRECT: Different limits per operation
const authLimiter = new Ratelimit(5, '1 m');
const apiLimiter = new Ratelimit(100, '1 m');

// ❌ NEVER: Block without logging
if (isBlocked) return new Response('', { status: 403 });

// ✅ CORRECT: Log for monitoring and adjustment
if (isBlocked) {
  logger.warn('Blocked request', { ip, path, reason });
  return new Response('Access denied', { status: 403 });
}
```

---

## Quick Reference

### Rate Limit by Endpoint Type
| Endpoint | Limit | Window | Identifier |
|----------|-------|--------|------------|
| Public API | 100 | 10s | IP |
| Auth (login) | 5 | 1m | IP |
| Auth (signup) | 3 | 1h | IP |
| Authenticated API | 1000 | 1m | User ID |
| AI/Expensive | 10 | 1m | User ID |
| Webhooks | 100 | 1s | Source IP |

### Response Headers
| Header | Purpose |
|--------|---------|
| `X-RateLimit-Limit` | Max requests allowed |
| `X-RateLimit-Remaining` | Requests remaining |
| `X-RateLimit-Reset` | When limit resets (timestamp) |
| `Retry-After` | Seconds until retry (429 response) |

### HTTP Status Codes
| Code | Meaning |
|------|---------|
| 429 | Too Many Requests |
| 403 | Forbidden (blocked) |
| 408 | Request Timeout |
| 413 | Payload Too Large |
| 503 | Service Unavailable (circuit open) |

### Cloudflare Headers
| Header | Content |
|--------|---------|
| `CF-Connecting-IP` | True client IP |
| `CF-IPCountry` | 2-letter country code |
| `CF-Ray` | Request ID |

### Checklist
- [ ] Rate limiting on all API endpoints
- [ ] Stricter limits on auth endpoints
- [ ] IP blocking for repeated violations
- [ ] CAPTCHA for sensitive operations
- [ ] Request size limits
- [ ] Timeout protection
- [ ] Circuit breaker for downstream services
- [ ] Logging for blocked requests
- [ ] Monitoring and alerting
