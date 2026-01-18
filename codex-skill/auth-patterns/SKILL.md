---
name: auth-patterns
description: Authentication patterns with NextAuth, OAuth, and RBAC
metadata:
  short-description: Auth patterns
---

# Authentication Patterns

> **Auto-trigger**: Auth implementation, NextAuth, Clerk, OAuth, RBAC, session management

---

## 1. NextAuth.js (Auth.js)

### 1.1 Setup

```typescript
// lib/auth.ts
import NextAuth from 'next-auth';
import { PrismaAdapter } from '@auth/prisma-adapter';
import Google from 'next-auth/providers/google';
import GitHub from 'next-auth/providers/github';
import Credentials from 'next-auth/providers/credentials';
import { prisma } from '@/lib/db';
import bcrypt from 'bcrypt';

export const { handlers, auth, signIn, signOut } = NextAuth({
  adapter: PrismaAdapter(prisma),
  session: { strategy: 'jwt' },
  pages: {
    signIn: '/login',
    error: '/auth/error',
  },
  providers: [
    Google({
      clientId: process.env.GOOGLE_CLIENT_ID!,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET!,
    }),
    GitHub({
      clientId: process.env.GITHUB_CLIENT_ID!,
      clientSecret: process.env.GITHUB_CLIENT_SECRET!,
    }),
    Credentials({
      name: 'credentials',
      credentials: {
        email: { label: 'Email', type: 'email' },
        password: { label: 'Password', type: 'password' },
      },
      async authorize(credentials) {
        if (!credentials?.email || !credentials?.password) {
          return null;
        }

        const user = await prisma.user.findUnique({
          where: { email: credentials.email as string },
        });

        if (!user || !user.password) {
          return null;
        }

        const isValid = await bcrypt.compare(
          credentials.password as string,
          user.password
        );

        if (!isValid) {
          return null;
        }

        return {
          id: user.id,
          email: user.email,
          name: user.name,
          role: user.role,
        };
      },
    }),
  ],
  callbacks: {
    async jwt({ token, user }) {
      if (user) {
        token.id = user.id;
        token.role = user.role;
      }
      return token;
    },
    async session({ session, token }) {
      if (session.user) {
        session.user.id = token.id as string;
        session.user.role = token.role as string;
      }
      return session;
    },
  },
});

// app/api/auth/[...nextauth]/route.ts
import { handlers } from '@/lib/auth';
export const { GET, POST } = handlers;
```

### 1.2 Session Usage

```typescript
// Server Component
import { auth } from '@/lib/auth';

export default async function ProfilePage() {
  const session = await auth();
  
  if (!session) {
    redirect('/login');
  }

  return <div>Welcome, {session.user.name}</div>;
}

// Client Component
'use client';

import { useSession } from 'next-auth/react';

export function UserMenu() {
  const { data: session, status } = useSession();

  if (status === 'loading') return <Skeleton />;
  if (!session) return <LoginButton />;

  return (
    <div>
      <span>{session.user.name}</span>
      <SignOutButton />
    </div>
  );
}
```

### 1.3 Protected Routes

```typescript
// middleware.ts
import { auth } from '@/lib/auth';

export default auth((req) => {
  const isLoggedIn = !!req.auth;
  const isAuthPage = req.nextUrl.pathname.startsWith('/login');
  const isProtectedRoute = req.nextUrl.pathname.startsWith('/dashboard');

  if (isAuthPage && isLoggedIn) {
    return Response.redirect(new URL('/dashboard', req.nextUrl));
  }

  if (isProtectedRoute && !isLoggedIn) {
    return Response.redirect(new URL('/login', req.nextUrl));
  }
});

export const config = {
  matcher: ['/((?!api|_next/static|_next/image|favicon.ico).*)'],
};
```

---

## 2. Role-Based Access Control (RBAC)

### 2.1 Permission System

```typescript
// lib/permissions.ts
type Role = 'admin' | 'manager' | 'user';
type Action = 'create' | 'read' | 'update' | 'delete';
type Resource = 'users' | 'posts' | 'orders' | 'analytics';

const permissions: Record<Role, Partial<Record<Resource, Action[]>>> = {
  admin: {
    users: ['create', 'read', 'update', 'delete'],
    posts: ['create', 'read', 'update', 'delete'],
    orders: ['create', 'read', 'update', 'delete'],
    analytics: ['read'],
  },
  manager: {
    users: ['read'],
    posts: ['create', 'read', 'update'],
    orders: ['read', 'update'],
    analytics: ['read'],
  },
  user: {
    posts: ['read'],
    orders: ['create', 'read'],
  },
};

export function hasPermission(
  role: Role,
  resource: Resource,
  action: Action
): boolean {
  return permissions[role]?.[resource]?.includes(action) ?? false;
}

export function requirePermission(resource: Resource, action: Action) {
  return async function middleware(req: Request) {
    const session = await auth();
    
    if (!session?.user?.role) {
      return new Response('Unauthorized', { status: 401 });
    }

    if (!hasPermission(session.user.role as Role, resource, action)) {
      return new Response('Forbidden', { status: 403 });
    }
  };
}
```

### 2.2 Component-Level Authorization

```typescript
// components/CanAccess.tsx
import { auth } from '@/lib/auth';
import { hasPermission, type Resource, type Action } from '@/lib/permissions';

interface CanAccessProps {
  resource: Resource;
  action: Action;
  children: React.ReactNode;
  fallback?: React.ReactNode;
}

export async function CanAccess({
  resource,
  action,
  children,
  fallback = null,
}: CanAccessProps) {
  const session = await auth();
  
  if (!session?.user?.role) {
    return fallback;
  }

  const canAccess = hasPermission(session.user.role, resource, action);
  
  return canAccess ? children : fallback;
}

// Usage
<CanAccess resource="users" action="delete">
  <DeleteUserButton userId={user.id} />
</CanAccess>
```

---

## 3. JWT Patterns

### 3.1 Token Generation

```typescript
import jwt from 'jsonwebtoken';

const ACCESS_SECRET = process.env.JWT_ACCESS_SECRET!;
const REFRESH_SECRET = process.env.JWT_REFRESH_SECRET!;

interface TokenPayload {
  userId: string;
  role: string;
}

export function generateAccessToken(payload: TokenPayload): string {
  return jwt.sign(payload, ACCESS_SECRET, {
    expiresIn: '15m',
    issuer: 'your-app',
  });
}

export function generateRefreshToken(userId: string): string {
  return jwt.sign({ userId }, REFRESH_SECRET, {
    expiresIn: '7d',
    issuer: 'your-app',
  });
}

export function verifyAccessToken(token: string): TokenPayload {
  return jwt.verify(token, ACCESS_SECRET) as TokenPayload;
}

export function verifyRefreshToken(token: string): { userId: string } {
  return jwt.verify(token, REFRESH_SECRET) as { userId: string };
}
```

### 3.2 Token Refresh

```typescript
// app/api/auth/refresh/route.ts
import { cookies } from 'next/headers';

export async function POST() {
  const cookieStore = cookies();
  const refreshToken = cookieStore.get('refresh_token')?.value;

  if (!refreshToken) {
    return Response.json({ error: 'No refresh token' }, { status: 401 });
  }

  try {
    const { userId } = verifyRefreshToken(refreshToken);
    
    // Check if token is in database (for revocation)
    const storedToken = await prisma.refreshToken.findUnique({
      where: { token: refreshToken },
    });

    if (!storedToken || storedToken.revoked) {
      return Response.json({ error: 'Invalid token' }, { status: 401 });
    }

    // Get user
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      return Response.json({ error: 'User not found' }, { status: 401 });
    }

    // Generate new tokens
    const newAccessToken = generateAccessToken({
      userId: user.id,
      role: user.role,
    });
    const newRefreshToken = generateRefreshToken(user.id);

    // Rotate refresh token
    await prisma.$transaction([
      prisma.refreshToken.update({
        where: { id: storedToken.id },
        data: { revoked: true },
      }),
      prisma.refreshToken.create({
        data: { token: newRefreshToken, userId: user.id },
      }),
    ]);

    // Set new refresh token cookie
    cookieStore.set('refresh_token', newRefreshToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
      maxAge: 60 * 60 * 24 * 7, // 7 days
    });

    return Response.json({ accessToken: newAccessToken });
  } catch (error) {
    return Response.json({ error: 'Invalid token' }, { status: 401 });
  }
}
```

---

## 4. OAuth Patterns

### 4.1 OAuth Flow

```typescript
// Manual OAuth implementation (if not using NextAuth)
export async function handleOAuthCallback(code: string, provider: 'google' | 'github') {
  // 1. Exchange code for tokens
  const tokens = await exchangeCodeForTokens(code, provider);
  
  // 2. Get user info from provider
  const providerUser = await getProviderUser(tokens.access_token, provider);
  
  // 3. Find or create user
  let user = await prisma.user.findFirst({
    where: {
      accounts: {
        some: {
          provider,
          providerAccountId: providerUser.id,
        },
      },
    },
  });

  if (!user) {
    // Check if email exists
    const existingUser = await prisma.user.findUnique({
      where: { email: providerUser.email },
    });

    if (existingUser) {
      // Link account to existing user
      await prisma.account.create({
        data: {
          userId: existingUser.id,
          provider,
          providerAccountId: providerUser.id,
          access_token: tokens.access_token,
          refresh_token: tokens.refresh_token,
        },
      });
      user = existingUser;
    } else {
      // Create new user
      user = await prisma.user.create({
        data: {
          email: providerUser.email,
          name: providerUser.name,
          image: providerUser.avatar,
          accounts: {
            create: {
              provider,
              providerAccountId: providerUser.id,
              access_token: tokens.access_token,
              refresh_token: tokens.refresh_token,
            },
          },
        },
      });
    }
  }

  // 4. Create session
  const session = await createSession(user.id);
  
  return { user, session };
}
```

---

## 5. Session Management

### 5.1 Secure Cookie Session

```typescript
import { cookies } from 'next/headers';
import { SignJWT, jwtVerify } from 'jose';

const secret = new TextEncoder().encode(process.env.SESSION_SECRET);

export async function createSession(userId: string) {
  const token = await new SignJWT({ userId })
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setExpirationTime('7d')
    .sign(secret);

  cookies().set('session', token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    maxAge: 60 * 60 * 24 * 7,
    path: '/',
  });

  return token;
}

export async function getSession() {
  const token = cookies().get('session')?.value;
  if (!token) return null;

  try {
    const { payload } = await jwtVerify(token, secret);
    return payload as { userId: string };
  } catch {
    return null;
  }
}

export async function deleteSession() {
  cookies().delete('session');
}
```

### 5.2 Session with Database

```typescript
export async function createDatabaseSession(userId: string) {
  const sessionToken = crypto.randomUUID();
  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

  await prisma.session.create({
    data: {
      sessionToken,
      userId,
      expiresAt,
    },
  });

  cookies().set('session', sessionToken, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    expires: expiresAt,
  });

  return sessionToken;
}

export async function validateSession(sessionToken: string) {
  const session = await prisma.session.findUnique({
    where: { sessionToken },
    include: { user: true },
  });

  if (!session || session.expiresAt < new Date()) {
    return null;
  }

  // Extend session on activity
  if (session.expiresAt.getTime() - Date.now() < 3 * 24 * 60 * 60 * 1000) {
    await prisma.session.update({
      where: { id: session.id },
      data: { expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) },
    });
  }

  return session;
}
```

---

## 6. Password Handling

```typescript
import bcrypt from 'bcrypt';
import { z } from 'zod';

const passwordSchema = z
  .string()
  .min(8, 'Password must be at least 8 characters')
  .regex(/[A-Z]/, 'Password must contain an uppercase letter')
  .regex(/[a-z]/, 'Password must contain a lowercase letter')
  .regex(/[0-9]/, 'Password must contain a number');

export async function hashPassword(password: string): Promise<string> {
  const validated = passwordSchema.parse(password);
  return bcrypt.hash(validated, 12);
}

export async function verifyPassword(
  password: string,
  hash: string
): Promise<boolean> {
  return bcrypt.compare(password, hash);
}

// Password reset flow
export async function requestPasswordReset(email: string) {
  const user = await prisma.user.findUnique({ where: { email } });
  if (!user) return; // Don't reveal if user exists

  const token = crypto.randomUUID();
  const expiresAt = new Date(Date.now() + 60 * 60 * 1000); // 1 hour

  await prisma.passwordResetToken.create({
    data: { token, userId: user.id, expiresAt },
  });

  await sendEmail({
    to: email,
    subject: 'Reset your password',
    html: `<a href="${process.env.APP_URL}/reset-password?token=${token}">Reset password</a>`,
  });
}

export async function resetPassword(token: string, newPassword: string) {
  const resetToken = await prisma.passwordResetToken.findUnique({
    where: { token },
    include: { user: true },
  });

  if (!resetToken || resetToken.expiresAt < new Date()) {
    throw new Error('Invalid or expired token');
  }

  const hashedPassword = await hashPassword(newPassword);

  await prisma.$transaction([
    prisma.user.update({
      where: { id: resetToken.userId },
      data: { password: hashedPassword },
    }),
    prisma.passwordResetToken.delete({ where: { id: resetToken.id } }),
    // Invalidate all sessions
    prisma.session.deleteMany({ where: { userId: resetToken.userId } }),
  ]);
}
```

---

## Quick Reference

### Auth Checklist
- [ ] Passwords hashed with bcrypt (cost 12+)
- [ ] JWT tokens with short expiry
- [ ] Refresh token rotation
- [ ] Secure cookie settings (httpOnly, secure, sameSite)
- [ ] RBAC implemented
- [ ] Session invalidation on password change
- [ ] Rate limiting on auth endpoints
- [ ] CSRF protection

### Cookie Settings
```typescript
{
  httpOnly: true,        // No JS access
  secure: true,          // HTTPS only
  sameSite: 'lax',       // CSRF protection
  maxAge: 60 * 60 * 24 * 7,  // 7 days
  path: '/',
}
```

### Token Expiry Guidelines
| Token Type | Expiry |
|------------|--------|
| Access Token | 15 minutes |
| Refresh Token | 7 days |
| Password Reset | 1 hour |
| Email Verification | 24 hours |
