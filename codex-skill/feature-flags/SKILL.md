---
name: feature-flags
description: Feature flags with LaunchDarkly and gradual rollouts
metadata:
  short-description: Feature flags
---

# Feature Flags

> **Sources**: [LaunchDarkly](https://docs.launchdarkly.com/), [Flagsmith](https://github.com/Flagsmith/flagsmith) (4.8k⭐), [Vercel Edge Config](https://vercel.com/docs/storage/edge-config)
> **Auto-trigger**: Files containing feature flags, `launchdarkly`, `flagsmith`, gradual rollouts, A/B testing, canary releases

---

## Technology Selection

| Tool | Best For | Self-Hosted | Pricing |
|------|----------|-------------|---------|
| **LaunchDarkly** | Enterprise, scale | No | $$$ |
| **Flagsmith** | Flexibility | Yes | Free tier |
| **Vercel Edge Config** | Edge, Vercel apps | No | Included |
| **PostHog** | Analytics + flags | Yes | Free tier |
| **Custom** | Simple needs | Yes | Free |

---

## LaunchDarkly

### Setup
```bash
npm install @launchdarkly/node-server-sdk
```

### Server-Side Client
```typescript
// lib/feature-flags.ts
import * as LaunchDarkly from '@launchdarkly/node-server-sdk';

const client = LaunchDarkly.init(process.env.LAUNCHDARKLY_SDK_KEY!);

// Wait for client to initialize
let initialized = false;

export async function getFlags() {
  if (!initialized) {
    await client.waitForInitialization();
    initialized = true;
  }
  return client;
}

// Graceful shutdown
process.on('SIGTERM', async () => {
  await client.close();
});
```

### User Context
```typescript
// lib/feature-flags.ts
import { LDContext } from '@launchdarkly/node-server-sdk';

export function createUserContext(user: {
  id: string;
  email: string;
  plan?: string;
  createdAt?: Date;
}): LDContext {
  return {
    kind: 'user',
    key: user.id,
    email: user.email,
    custom: {
      plan: user.plan || 'free',
      accountAge: user.createdAt
        ? Math.floor((Date.now() - user.createdAt.getTime()) / (1000 * 60 * 60 * 24))
        : 0,
    },
  };
}

// Multi-context (user + organization)
export function createMultiContext(
  user: { id: string; email: string },
  org: { id: string; plan: string }
): LDContext {
  return {
    kind: 'multi',
    user: {
      key: user.id,
      email: user.email,
    },
    organization: {
      key: org.id,
      plan: org.plan,
    },
  };
}
```

### Checking Flags
```typescript
// lib/feature-flags.ts
import { getFlags, createUserContext } from './feature-flags';

// Boolean flag
export async function isFeatureEnabled(
  flagKey: string,
  user: { id: string; email: string }
): Promise<boolean> {
  const client = await getFlags();
  const context = createUserContext(user);
  return client.variation(flagKey, context, false);
}

// Variation (A/B testing)
export async function getVariation<T>(
  flagKey: string,
  user: { id: string; email: string },
  defaultValue: T
): Promise<T> {
  const client = await getFlags();
  const context = createUserContext(user);
  return client.variation(flagKey, context, defaultValue);
}

// JSON flag (configuration)
export async function getConfig<T extends Record<string, unknown>>(
  flagKey: string,
  user: { id: string; email: string },
  defaultValue: T
): Promise<T> {
  const client = await getFlags();
  const context = createUserContext(user);
  return client.variation(flagKey, context, defaultValue);
}
```

### Usage in API Routes
```typescript
// app/api/checkout/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { isFeatureEnabled, getVariation } from '@/lib/feature-flags';
import { auth } from '@/lib/auth';

export async function POST(req: NextRequest) {
  const session = await auth();
  if (!session?.user) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const user = { id: session.user.id, email: session.user.email! };

  // Boolean flag
  const hasNewCheckout = await isFeatureEnabled('new-checkout-flow', user);

  if (hasNewCheckout) {
    return handleNewCheckout(req);
  }
  return handleLegacyCheckout(req);
}

// A/B testing pricing
export async function GET(req: NextRequest) {
  const session = await auth();
  const user = session?.user 
    ? { id: session.user.id, email: session.user.email! }
    : { id: 'anonymous', email: '' };

  const pricingVariant = await getVariation(
    'pricing-experiment',
    user,
    'control'
  );

  // Track exposure for analytics
  await trackExperimentExposure(user.id, 'pricing-experiment', pricingVariant);

  return NextResponse.json({
    variant: pricingVariant,
    prices: getPricesForVariant(pricingVariant),
  });
}
```

### React Client SDK
```bash
npm install @launchdarkly/react-client-sdk
```

```typescript
// app/providers.tsx
'use client';

import { LDProvider } from '@launchdarkly/react-client-sdk';

export function FeatureFlagProvider({ children }: { children: React.ReactNode }) {
  return (
    <LDProvider
      clientSideID={process.env.NEXT_PUBLIC_LD_CLIENT_SIDE_ID!}
      options={{
        bootstrap: 'localStorage', // Use cached flags initially
      }}
    >
      {children}
    </LDProvider>
  );
}

// components/NewFeature.tsx
'use client';

import { useFlags, useLDClient } from '@launchdarkly/react-client-sdk';
import { useEffect } from 'react';

export function NewFeature() {
  const { newFeature } = useFlags();
  const ldClient = useLDClient();

  // Identify user after login
  useEffect(() => {
    if (user && ldClient) {
      ldClient.identify({
        kind: 'user',
        key: user.id,
        email: user.email,
      });
    }
  }, [user, ldClient]);

  if (!newFeature) {
    return null;
  }

  return <div>New Feature Content</div>;
}
```

---

## Flagsmith

### Setup
```bash
npm install flagsmith-nodejs
```

### Server Configuration
```typescript
// lib/flagsmith.ts
import Flagsmith from 'flagsmith-nodejs';

export const flagsmith = new Flagsmith({
  environmentKey: process.env.FLAGSMITH_ENVIRONMENT_KEY!,
  enableLocalEvaluation: true, // Cache flags locally
  environmentRefreshIntervalSeconds: 60,
});
```

### Usage
```typescript
// lib/feature-flags.ts
import { flagsmith } from './flagsmith';

export async function isEnabled(flagKey: string, userId?: string): Promise<boolean> {
  if (userId) {
    const flags = await flagsmith.getIdentityFlags(userId);
    return flags.isFeatureEnabled(flagKey);
  }
  
  const flags = await flagsmith.getEnvironmentFlags();
  return flags.isFeatureEnabled(flagKey);
}

export async function getValue(flagKey: string, userId?: string): Promise<string | null> {
  if (userId) {
    const flags = await flagsmith.getIdentityFlags(userId);
    return flags.getFeatureValue(flagKey);
  }
  
  const flags = await flagsmith.getEnvironmentFlags();
  return flags.getFeatureValue(flagKey);
}
```

---

## Custom Feature Flags (Simple)

### Database Schema
```prisma
// schema.prisma
model FeatureFlag {
  id          String   @id @default(uuid())
  key         String   @unique
  name        String
  description String?
  enabled     Boolean  @default(false)
  percentage  Int      @default(100) // Rollout percentage
  rules       Json?    // Advanced targeting rules
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
}

model FeatureFlagOverride {
  id            String  @id @default(uuid())
  flagKey       String
  userId        String
  enabled       Boolean
  
  @@unique([flagKey, userId])
}
```

### Implementation
```typescript
// lib/feature-flags/custom.ts
import { db } from '@/lib/db';
import { createHash } from 'crypto';

// Cache flags in memory
const flagCache = new Map<string, { flag: any; expiresAt: number }>();
const CACHE_TTL = 60 * 1000; // 1 minute

async function getFlag(key: string) {
  const cached = flagCache.get(key);
  if (cached && cached.expiresAt > Date.now()) {
    return cached.flag;
  }

  const flag = await db.featureFlag.findUnique({
    where: { key },
  });

  if (flag) {
    flagCache.set(key, { flag, expiresAt: Date.now() + CACHE_TTL });
  }

  return flag;
}

export async function isFeatureEnabled(
  key: string,
  userId?: string
): Promise<boolean> {
  const flag = await getFlag(key);
  if (!flag) return false;
  if (!flag.enabled) return false;

  // Check user override
  if (userId) {
    const override = await db.featureFlagOverride.findUnique({
      where: { flagKey_userId: { flagKey: key, userId } },
    });
    if (override) return override.enabled;
  }

  // Percentage rollout
  if (flag.percentage < 100 && userId) {
    const hash = createHash('md5')
      .update(`${key}:${userId}`)
      .digest('hex');
    const bucket = parseInt(hash.substring(0, 8), 16) % 100;
    return bucket < flag.percentage;
  }

  // Check targeting rules
  if (flag.rules && userId) {
    return evaluateRules(flag.rules, userId);
  }

  return flag.percentage === 100;
}

// Gradual rollout
export async function setRolloutPercentage(key: string, percentage: number) {
  await db.featureFlag.update({
    where: { key },
    data: { percentage: Math.min(100, Math.max(0, percentage)) },
  });
  flagCache.delete(key);
}

// User override (beta testers, employees)
export async function setUserOverride(key: string, userId: string, enabled: boolean) {
  await db.featureFlagOverride.upsert({
    where: { flagKey_userId: { flagKey: key, userId } },
    create: { flagKey: key, userId, enabled },
    update: { enabled },
  });
}
```

### Admin API
```typescript
// app/api/admin/flags/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { auth } from '@/lib/auth';

export async function GET(req: NextRequest) {
  const session = await auth();
  if (!session?.user?.isAdmin) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const flags = await db.featureFlag.findMany({
    orderBy: { key: 'asc' },
  });

  return NextResponse.json(flags);
}

export async function POST(req: NextRequest) {
  const session = await auth();
  if (!session?.user?.isAdmin) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const { key, name, description, enabled, percentage } = await req.json();

  const flag = await db.featureFlag.create({
    data: { key, name, description, enabled, percentage },
  });

  return NextResponse.json(flag);
}

// app/api/admin/flags/[key]/route.ts
export async function PATCH(
  req: NextRequest,
  { params }: { params: { key: string } }
) {
  const session = await auth();
  if (!session?.user?.isAdmin) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const updates = await req.json();

  const flag = await db.featureFlag.update({
    where: { key: params.key },
    data: updates,
  });

  // Clear cache
  flagCache.delete(params.key);

  return NextResponse.json(flag);
}
```

---

## Vercel Edge Config

### Setup
```bash
npm install @vercel/edge-config
```

### Usage
```typescript
// lib/edge-config.ts
import { get, getAll } from '@vercel/edge-config';

export async function getFeatureFlag(key: string): Promise<boolean> {
  const value = await get<boolean>(key);
  return value ?? false;
}

export async function getFlags(): Promise<Record<string, boolean>> {
  const flags = await getAll<Record<string, boolean>>();
  return flags ?? {};
}
```

### Middleware Usage
```typescript
// middleware.ts
import { NextRequest, NextResponse } from 'next/server';
import { get } from '@vercel/edge-config';

export async function middleware(req: NextRequest) {
  // Check flag at the edge (fast!)
  const newLanding = await get<boolean>('new-landing-page');

  if (newLanding && req.nextUrl.pathname === '/') {
    return NextResponse.rewrite(new URL('/landing-v2', req.url));
  }

  return NextResponse.next();
}
```

---

## Gradual Rollout Patterns

### Percentage Rollout
```typescript
function isInRollout(userId: string, percentage: number, flagKey: string): boolean {
  // Consistent hashing - same user always gets same result
  const hash = createHash('sha256')
    .update(`${flagKey}:${userId}`)
    .digest('hex');
  
  const bucket = parseInt(hash.substring(0, 8), 16) % 100;
  return bucket < percentage;
}

// Rollout schedule
async function gradualRollout(flagKey: string) {
  const schedule = [
    { percentage: 1, wait: 60 * 60 * 1000 },   // 1% for 1 hour
    { percentage: 10, wait: 60 * 60 * 1000 },  // 10% for 1 hour
    { percentage: 25, wait: 4 * 60 * 60 * 1000 }, // 25% for 4 hours
    { percentage: 50, wait: 24 * 60 * 60 * 1000 }, // 50% for 1 day
    { percentage: 100, wait: 0 }, // 100%
  ];

  for (const step of schedule) {
    await setRolloutPercentage(flagKey, step.percentage);
    
    // Monitor for errors
    const errorRate = await getErrorRate(flagKey);
    if (errorRate > 0.01) { // 1% error rate threshold
      await setRolloutPercentage(flagKey, 0); // Rollback!
      throw new Error('Rollout aborted due to high error rate');
    }
    
    if (step.wait > 0) {
      await new Promise(resolve => setTimeout(resolve, step.wait));
    }
  }
}
```

### Canary Deployment
```typescript
// Route some traffic to new version
async function canaryRoute(req: NextRequest, user: User) {
  const canaryPercentage = await getFlag('canary-percentage'); // e.g., 5
  
  if (isInRollout(user.id, canaryPercentage, 'canary')) {
    return NextResponse.rewrite(new URL(req.url, process.env.CANARY_URL));
  }
  
  return NextResponse.next();
}
```

---

## React Hooks

```typescript
// hooks/useFeatureFlag.ts
'use client';

import { useEffect, useState } from 'react';
import useSWR from 'swr';

export function useFeatureFlag(key: string): {
  enabled: boolean;
  loading: boolean;
} {
  const { data, isLoading } = useSWR(
    `/api/flags/${key}`,
    (url) => fetch(url).then((r) => r.json()),
    {
      revalidateOnFocus: false,
      dedupingInterval: 60000, // 1 minute
    }
  );

  return {
    enabled: data?.enabled ?? false,
    loading: isLoading,
  };
}

// Usage
function MyComponent() {
  const { enabled, loading } = useFeatureFlag('new-feature');

  if (loading) return <Skeleton />;
  if (!enabled) return <OldFeature />;
  return <NewFeature />;
}
```

---

## Anti-Patterns

```typescript
// ❌ NEVER: Check flags synchronously on every render
function Component() {
  const isEnabled = checkFlagSync('feature'); // Blocks render!
}

// ✅ CORRECT: Use async with caching
function Component() {
  const { enabled, loading } = useFeatureFlag('feature');
}

// ❌ NEVER: Different flag values for same user
// User A sees feature, refreshes, feature is gone

// ✅ CORRECT: Consistent hashing
const bucket = hash(`${flagKey}:${userId}`) % 100;

// ❌ NEVER: Leave flags forever
if (await isEnabled('feature-2019')) { ... } // 5 years old!

// ✅ CORRECT: Remove old flags
// After rollout complete, remove flag check and clean up

// ❌ NEVER: Nest flags deeply
if (await isEnabled('a')) {
  if (await isEnabled('b')) {
    if (await isEnabled('c')) { ... }
  }
}

// ✅ CORRECT: Flat flag checks or compound flags
const config = await getConfig('feature-bundle');

// ❌ NEVER: Use flags for config that changes often
const apiUrl = await getFlag('api-url'); // Use env vars!

// ✅ CORRECT: Use flags for feature toggles, not config
const hasNewApi = await isEnabled('use-new-api');
const apiUrl = hasNewApi ? process.env.NEW_API : process.env.OLD_API;
```

---

## Quick Reference

### Flag Types
| Type | Use Case | Example |
|------|----------|---------|
| Boolean | On/off toggle | `new-checkout: true` |
| String | A/B variants | `pricing: "variant-b"` |
| Number | Rollout % | `rollout: 25` |
| JSON | Complex config | `limits: { uploads: 10 }` |

### Rollout Strategies
| Strategy | When to Use |
|----------|-------------|
| Percentage | Gradual feature release |
| User list | Beta testers, employees |
| Targeting rules | Specific segments |
| Time-based | Scheduled releases |

### Targeting Rules
| Rule | Example |
|------|---------|
| User attribute | `plan == "pro"` |
| Percentage | `bucket < 10` |
| Allow list | `userId in [...]` |
| Date range | `date > "2024-01-01"` |

### Checklist
- [ ] Consistent user bucketing
- [ ] Caching with TTL
- [ ] Fallback for flag service failures
- [ ] Analytics for A/B tests
- [ ] Flag cleanup process
- [ ] Admin UI for toggles
- [ ] Audit log for changes
- [ ] Rollback capability
