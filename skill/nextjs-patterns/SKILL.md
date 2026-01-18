# Next.js Patterns (App Router + shadcn + Turborepo)

> **Sources**: 
> - [vercel/next.js](https://github.com/vercel/next.js) (137k+ stars)
> - [vercel/next-forge](https://github.com/vercel/next-forge) (7k+ stars)
> - [t3-oss/create-t3-app](https://github.com/t3-oss/create-t3-app) (28k+ stars)
> - [shadcn/ui](https://github.com/shadcn-ui/ui) (75k+ stars)
> 
> **Auto-trigger**: `package.json` contains `next`, or `next.config.*` exists

---

## 1. Project Structure

### 1.1 App Router Structure

```
app/
├── (auth)/                     # Route group (no URL segment)
│   ├── login/
│   │   └── page.tsx
│   ├── register/
│   │   └── page.tsx
│   └── layout.tsx              # Auth layout
│
├── (dashboard)/                # Protected route group
│   ├── dashboard/
│   │   ├── page.tsx
│   │   └── loading.tsx
│   ├── settings/
│   │   ├── page.tsx
│   │   ├── profile/
│   │   │   └── page.tsx
│   │   └── layout.tsx
│   └── layout.tsx              # Dashboard layout with sidebar
│
├── api/                        # API routes
│   ├── users/
│   │   ├── route.ts            # GET, POST /api/users
│   │   └── [id]/
│   │       └── route.ts        # GET, PUT, DELETE /api/users/:id
│   └── webhooks/
│       └── stripe/
│           └── route.ts
│
├── layout.tsx                  # Root layout
├── page.tsx                    # Home page
├── error.tsx                   # Error boundary
├── not-found.tsx               # 404 page
├── loading.tsx                 # Global loading
└── globals.css
```

### 1.2 Feature-Based Structure (Large Apps)

```
src/
├── app/                        # Next.js App Router
├── components/
│   ├── ui/                     # shadcn components
│   └── shared/                 # Shared components
├── features/
│   ├── auth/
│   │   ├── actions/            # Server actions
│   │   ├── components/
│   │   ├── hooks/
│   │   └── lib/
│   └── users/
├── lib/
│   ├── db.ts                   # Database client
│   ├── auth.ts                 # Auth config
│   └── utils.ts
├── server/                     # Server-only code
│   ├── api/                    # tRPC or API logic
│   └── db/                     # Queries, mutations
└── types/
```

### 1.3 Turborepo Structure

```
my-turborepo/
├── apps/
│   ├── web/                    # Main Next.js app
│   ├── admin/                  # Admin Next.js app
│   └── docs/                   # Documentation site
│
├── packages/
│   ├── ui/                     # Shared UI components
│   │   ├── src/
│   │   │   ├── button.tsx
│   │   │   └── index.ts
│   │   └── package.json
│   ├── database/               # Prisma schema & client
│   │   ├── prisma/
│   │   ├── src/
│   │   └── package.json
│   ├── auth/                   # Shared auth logic
│   ├── email/                  # Email templates
│   └── config-typescript/      # Shared tsconfig
│
├── turbo.json
├── package.json
└── pnpm-workspace.yaml
```

---

## 2. Server Components

### 2.1 Default to Server Components

```typescript
// app/users/page.tsx - Server Component (default)
import { db } from '@/lib/db';
import { UserList } from './user-list';

export default async function UsersPage() {
  // Direct database access - no API needed
  const users = await db.user.findMany({
    orderBy: { createdAt: 'desc' },
  });

  return (
    <div>
      <h1>Users</h1>
      <UserList users={users} />
    </div>
  );
}
```

### 2.2 Client Components (When Needed)

```typescript
// components/user-search.tsx
'use client'; // Required for interactivity

import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { Input } from '@/components/ui/input';

export function UserSearch() {
  const [query, setQuery] = useState('');
  const [isPending, startTransition] = useTransition();
  const router = useRouter();

  const handleSearch = (value: string) => {
    setQuery(value);
    startTransition(() => {
      router.push(`/users?search=${encodeURIComponent(value)}`);
    });
  };

  return (
    <Input
      value={query}
      onChange={(e) => handleSearch(e.target.value)}
      placeholder="Search users..."
      className={isPending ? 'opacity-50' : ''}
    />
  );
}
```

### 2.3 Composition Pattern

```typescript
// Server Component with Client islands
// app/dashboard/page.tsx
import { Suspense } from 'react';
import { StatsCards } from './stats-cards';       // Server
import { RevenueChart } from './revenue-chart';   // Client
import { ActivityFeed } from './activity-feed';   // Server

export default function DashboardPage() {
  return (
    <div className="grid gap-6">
      {/* Server Component - fetches own data */}
      <Suspense fallback={<StatsCardsSkeleton />}>
        <StatsCards />
      </Suspense>

      {/* Client Component - receives data as props */}
      <Suspense fallback={<ChartSkeleton />}>
        <RevenueChartWrapper />
      </Suspense>

      {/* Server Component with streaming */}
      <Suspense fallback={<FeedSkeleton />}>
        <ActivityFeed />
      </Suspense>
    </div>
  );
}

// Wrapper to pass server data to client
async function RevenueChartWrapper() {
  const data = await getRevenueData();
  return <RevenueChart data={data} />;
}
```

---

## 3. Server Actions

### 3.1 Form Actions

```typescript
// features/auth/actions/login.ts
'use server';

import { z } from 'zod';
import { redirect } from 'next/navigation';
import { cookies } from 'next/headers';
import { createSession } from '@/lib/auth';

const loginSchema = z.object({
  email: z.string().email('Invalid email'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
});

export type LoginState = {
  errors?: {
    email?: string[];
    password?: string[];
    _form?: string[];
  };
};

export async function login(
  prevState: LoginState,
  formData: FormData
): Promise<LoginState> {
  // Validate
  const validatedFields = loginSchema.safeParse({
    email: formData.get('email'),
    password: formData.get('password'),
  });

  if (!validatedFields.success) {
    return {
      errors: validatedFields.error.flatten().fieldErrors,
    };
  }

  const { email, password } = validatedFields.data;

  try {
    const user = await verifyCredentials(email, password);
    if (!user) {
      return {
        errors: { _form: ['Invalid credentials'] },
      };
    }

    // Create session
    const session = await createSession(user.id);
    cookies().set('session', session.token, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
      maxAge: 60 * 60 * 24 * 7, // 7 days
    });
  } catch (error) {
    return {
      errors: { _form: ['An error occurred. Please try again.'] },
    };
  }

  redirect('/dashboard');
}
```

### 3.2 Using Server Actions in Forms

```typescript
// features/auth/components/login-form.tsx
'use client';

import { useFormState, useFormStatus } from 'react-dom';
import { login, type LoginState } from '../actions/login';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';

const initialState: LoginState = {};

export function LoginForm() {
  const [state, formAction] = useFormState(login, initialState);

  return (
    <form action={formAction} className="space-y-4">
      <div>
        <Label htmlFor="email">Email</Label>
        <Input id="email" name="email" type="email" required />
        {state.errors?.email && (
          <p className="text-sm text-destructive">{state.errors.email[0]}</p>
        )}
      </div>

      <div>
        <Label htmlFor="password">Password</Label>
        <Input id="password" name="password" type="password" required />
        {state.errors?.password && (
          <p className="text-sm text-destructive">{state.errors.password[0]}</p>
        )}
      </div>

      {state.errors?._form && (
        <p className="text-sm text-destructive">{state.errors._form[0]}</p>
      )}

      <SubmitButton />
    </form>
  );
}

function SubmitButton() {
  const { pending } = useFormStatus();
  
  return (
    <Button type="submit" disabled={pending} className="w-full">
      {pending ? 'Signing in...' : 'Sign in'}
    </Button>
  );
}
```

### 3.3 Mutations with Revalidation

```typescript
// features/users/actions/create-user.ts
'use server';

import { revalidatePath, revalidateTag } from 'next/cache';
import { db } from '@/lib/db';

export async function createUser(formData: FormData) {
  const user = await db.user.create({
    data: {
      name: formData.get('name') as string,
      email: formData.get('email') as string,
    },
  });

  // Revalidate specific path
  revalidatePath('/users');
  
  // Or revalidate by tag
  revalidateTag('users');

  return user;
}

// Using tags in fetch
async function getUsers() {
  const res = await fetch('/api/users', {
    next: { tags: ['users'] },
  });
  return res.json();
}
```

---

## 4. Data Fetching

### 4.1 Server-Side Fetching

```typescript
// app/users/[id]/page.tsx
import { notFound } from 'next/navigation';
import { db } from '@/lib/db';
import { cache } from 'react';

// Deduplicated across the request
const getUser = cache(async (id: string) => {
  const user = await db.user.findUnique({
    where: { id },
    include: { posts: true },
  });
  return user;
});

export async function generateMetadata({ params }: { params: { id: string } }) {
  const user = await getUser(params.id);
  if (!user) return { title: 'User Not Found' };
  return { title: user.name };
}

export default async function UserPage({ params }: { params: { id: string } }) {
  const user = await getUser(params.id);

  if (!user) {
    notFound();
  }

  return (
    <div>
      <h1>{user.name}</h1>
      <p>{user.email}</p>
    </div>
  );
}
```

### 4.2 Parallel Data Fetching

```typescript
// app/dashboard/page.tsx
export default async function DashboardPage() {
  // Parallel fetching - don't await sequentially!
  const [user, stats, notifications] = await Promise.all([
    getUser(),
    getStats(),
    getNotifications(),
  ]);

  return (
    <div>
      <UserHeader user={user} />
      <StatsGrid stats={stats} />
      <NotificationsList notifications={notifications} />
    </div>
  );
}
```

### 4.3 Streaming with Suspense

```typescript
// app/dashboard/page.tsx
import { Suspense } from 'react';

export default function DashboardPage() {
  return (
    <div>
      {/* Fast - show immediately */}
      <DashboardHeader />

      {/* Slow - stream when ready */}
      <Suspense fallback={<StatsSkeleton />}>
        <SlowStats />
      </Suspense>

      <Suspense fallback={<ChartSkeleton />}>
        <SlowChart />
      </Suspense>
    </div>
  );
}

async function SlowStats() {
  const stats = await getStats(); // 2s delay
  return <StatsGrid stats={stats} />;
}
```

---

## 5. shadcn/ui Integration

### 5.1 Setup

```bash
npx shadcn@latest init
npx shadcn@latest add button card input form
```

### 5.2 Custom Theme

```css
/* app/globals.css */
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  :root {
    --background: 0 0% 100%;
    --foreground: 222.2 84% 4.9%;
    --card: 0 0% 100%;
    --card-foreground: 222.2 84% 4.9%;
    --popover: 0 0% 100%;
    --popover-foreground: 222.2 84% 4.9%;
    --primary: 221.2 83.2% 53.3%;
    --primary-foreground: 210 40% 98%;
    --secondary: 210 40% 96%;
    --secondary-foreground: 222.2 47.4% 11.2%;
    --muted: 210 40% 96%;
    --muted-foreground: 215.4 16.3% 46.9%;
    --accent: 210 40% 96%;
    --accent-foreground: 222.2 47.4% 11.2%;
    --destructive: 0 84.2% 60.2%;
    --destructive-foreground: 210 40% 98%;
    --border: 214.3 31.8% 91.4%;
    --input: 214.3 31.8% 91.4%;
    --ring: 221.2 83.2% 53.3%;
    --radius: 0.5rem;
  }

  .dark {
    --background: 222.2 84% 4.9%;
    --foreground: 210 40% 98%;
    /* ... dark theme values */
  }
}
```

### 5.3 Form with shadcn + React Hook Form + Zod

```typescript
// features/users/components/user-form.tsx
'use client';

import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { Button } from '@/components/ui/button';
import {
  Form,
  FormControl,
  FormDescription,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from '@/components/ui/form';
import { Input } from '@/components/ui/input';

const userSchema = z.object({
  name: z.string().min(2, 'Name must be at least 2 characters'),
  email: z.string().email('Invalid email address'),
});

type UserFormValues = z.infer<typeof userSchema>;

interface UserFormProps {
  onSubmit: (data: UserFormValues) => Promise<void>;
  defaultValues?: Partial<UserFormValues>;
}

export function UserForm({ onSubmit, defaultValues }: UserFormProps) {
  const form = useForm<UserFormValues>({
    resolver: zodResolver(userSchema),
    defaultValues: {
      name: '',
      email: '',
      ...defaultValues,
    },
  });

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
        <FormField
          control={form.control}
          name="name"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Name</FormLabel>
              <FormControl>
                <Input placeholder="John Doe" {...field} />
              </FormControl>
              <FormDescription>Your full name</FormDescription>
              <FormMessage />
            </FormItem>
          )}
        />

        <FormField
          control={form.control}
          name="email"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Email</FormLabel>
              <FormControl>
                <Input placeholder="john@example.com" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <Button type="submit" disabled={form.formState.isSubmitting}>
          {form.formState.isSubmitting ? 'Saving...' : 'Save'}
        </Button>
      </form>
    </Form>
  );
}
```

---

## 6. API Routes

### 6.1 Route Handlers

```typescript
// app/api/users/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { z } from 'zod';
import { getSession } from '@/lib/auth';

export async function GET(request: NextRequest) {
  const session = await getSession();
  if (!session) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const { searchParams } = new URL(request.url);
  const page = parseInt(searchParams.get('page') || '1');
  const limit = parseInt(searchParams.get('limit') || '10');

  const users = await db.user.findMany({
    skip: (page - 1) * limit,
    take: limit,
    orderBy: { createdAt: 'desc' },
  });

  const total = await db.user.count();

  return NextResponse.json({
    data: users,
    pagination: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit),
    },
  });
}

const createUserSchema = z.object({
  name: z.string().min(2),
  email: z.string().email(),
});

export async function POST(request: NextRequest) {
  const session = await getSession();
  if (!session) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const body = await request.json();
  const validatedData = createUserSchema.safeParse(body);

  if (!validatedData.success) {
    return NextResponse.json(
      { error: 'Validation failed', details: validatedData.error.flatten() },
      { status: 400 }
    );
  }

  const user = await db.user.create({
    data: validatedData.data,
  });

  return NextResponse.json(user, { status: 201 });
}
```

### 6.2 Dynamic Route Handlers

```typescript
// app/api/users/[id]/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';

interface RouteParams {
  params: { id: string };
}

export async function GET(request: NextRequest, { params }: RouteParams) {
  const user = await db.user.findUnique({
    where: { id: params.id },
  });

  if (!user) {
    return NextResponse.json({ error: 'User not found' }, { status: 404 });
  }

  return NextResponse.json(user);
}

export async function PUT(request: NextRequest, { params }: RouteParams) {
  const body = await request.json();

  const user = await db.user.update({
    where: { id: params.id },
    data: body,
  });

  return NextResponse.json(user);
}

export async function DELETE(request: NextRequest, { params }: RouteParams) {
  await db.user.delete({
    where: { id: params.id },
  });

  return new NextResponse(null, { status: 204 });
}
```

---

## 7. Middleware

```typescript
// middleware.ts
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';
import { verifySession } from '@/lib/auth';

const publicPaths = ['/login', '/register', '/api/auth'];
const apiPaths = ['/api'];

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  // Skip public paths
  if (publicPaths.some((path) => pathname.startsWith(path))) {
    return NextResponse.next();
  }

  // Verify session
  const session = await verifySession(request);

  if (!session) {
    // API routes return 401
    if (apiPaths.some((path) => pathname.startsWith(path))) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    // Pages redirect to login
    const loginUrl = new URL('/login', request.url);
    loginUrl.searchParams.set('from', pathname);
    return NextResponse.redirect(loginUrl);
  }

  // Add user info to headers for server components
  const response = NextResponse.next();
  response.headers.set('x-user-id', session.userId);
  return response;
}

export const config = {
  matcher: [
    /*
     * Match all request paths except:
     * - _next/static (static files)
     * - _next/image (image optimization files)
     * - favicon.ico (favicon file)
     * - public folder
     */
    '/((?!_next/static|_next/image|favicon.ico|public/).*)',
  ],
};
```

---

## 8. Metadata & SEO

```typescript
// app/layout.tsx
import type { Metadata } from 'next';

export const metadata: Metadata = {
  metadataBase: new URL('https://myapp.com'),
  title: {
    default: 'My App',
    template: '%s | My App',
  },
  description: 'My awesome application',
  keywords: ['Next.js', 'React', 'TypeScript'],
  authors: [{ name: 'Your Name' }],
  openGraph: {
    type: 'website',
    locale: 'en_US',
    url: 'https://myapp.com',
    siteName: 'My App',
    images: [{ url: '/og-image.png', width: 1200, height: 630 }],
  },
  twitter: {
    card: 'summary_large_image',
    creator: '@yourhandle',
  },
  robots: {
    index: true,
    follow: true,
  },
};

// Dynamic metadata
// app/users/[id]/page.tsx
export async function generateMetadata({ params }: { params: { id: string } }): Promise<Metadata> {
  const user = await getUser(params.id);

  if (!user) {
    return { title: 'User Not Found' };
  }

  return {
    title: user.name,
    description: `Profile of ${user.name}`,
    openGraph: {
      title: user.name,
      images: [user.avatarUrl],
    },
  };
}
```

---

## Quick Reference

### Server vs Client Components

| Feature | Server Component | Client Component |
|---------|------------------|------------------|
| Fetch data | Yes (async) | Use React Query |
| Access backend | Yes (direct) | Via API |
| Use hooks | No | Yes |
| Event handlers | No | Yes |
| Browser APIs | No | Yes |
| Smaller bundle | Yes | No |

### When to Use Client Components
- `useState`, `useEffect`, `useContext`
- Event handlers (`onClick`, `onChange`)
- Browser APIs (`window`, `localStorage`)
- Custom hooks with state
- Third-party libs requiring hooks

### File Conventions
| File | Purpose |
|------|---------|
| `page.tsx` | Route UI |
| `layout.tsx` | Shared layout |
| `loading.tsx` | Loading UI |
| `error.tsx` | Error boundary |
| `not-found.tsx` | 404 UI |
| `route.ts` | API endpoint |
| `template.tsx` | Re-rendered layout |

### Revalidation Strategies
```typescript
// Time-based
fetch(url, { next: { revalidate: 3600 } }); // 1 hour

// On-demand
revalidatePath('/users');
revalidateTag('users');

// No cache
fetch(url, { cache: 'no-store' });
```
