# Web Security Best Practices

> **Sources**: 
> - [OWASP/CheatSheetSeries](https://github.com/OWASP/CheatSheetSeries) (31k+ stars)
> - [shieldfy/API-Security-Checklist](https://github.com/shieldfy/API-Security-Checklist) (23k+ stars)
> 
> **Auto-trigger**: Any backend code, API routes, authentication implementation

---

## 1. Authentication

### 1.1 Password Handling

```typescript
// NEVER store plain passwords
// ALWAYS use bcrypt or argon2

import bcrypt from 'bcrypt';

const SALT_ROUNDS = 12; // Minimum 10, recommended 12+

export async function hashPassword(password: string): Promise<string> {
  return bcrypt.hash(password, SALT_ROUNDS);
}

export async function verifyPassword(
  password: string,
  hash: string
): Promise<boolean> {
  return bcrypt.compare(password, hash);
}

// Usage
const hashedPassword = await hashPassword(userInput);
await db.user.create({ data: { email, password: hashedPassword } });

// Verification
const isValid = await verifyPassword(inputPassword, user.password);
```

### 1.2 JWT Security

```typescript
import jwt from 'jsonwebtoken';

// NEVER store sensitive data in JWT payload
// ALWAYS set expiration
// ALWAYS use strong secrets (min 256 bits)

interface TokenPayload {
  userId: string;
  role: string;
}

const ACCESS_TOKEN_SECRET = process.env.ACCESS_TOKEN_SECRET!; // 32+ chars
const REFRESH_TOKEN_SECRET = process.env.REFRESH_TOKEN_SECRET!;
const ACCESS_TOKEN_EXPIRY = '15m';
const REFRESH_TOKEN_EXPIRY = '7d';

export function generateAccessToken(payload: TokenPayload): string {
  return jwt.sign(payload, ACCESS_TOKEN_SECRET, {
    expiresIn: ACCESS_TOKEN_EXPIRY,
    issuer: 'your-app',
    audience: 'your-app-users',
  });
}

export function generateRefreshToken(userId: string): string {
  return jwt.sign({ userId }, REFRESH_TOKEN_SECRET, {
    expiresIn: REFRESH_TOKEN_EXPIRY,
  });
}

export function verifyAccessToken(token: string): TokenPayload {
  return jwt.verify(token, ACCESS_TOKEN_SECRET, {
    issuer: 'your-app',
    audience: 'your-app-users',
  }) as TokenPayload;
}

// Token rotation on refresh
export async function rotateRefreshToken(oldToken: string) {
  const payload = jwt.verify(oldToken, REFRESH_TOKEN_SECRET) as { userId: string };
  
  // Invalidate old token in database
  await db.refreshToken.delete({ where: { token: oldToken } });
  
  // Issue new tokens
  const newAccessToken = generateAccessToken({ userId: payload.userId, role: 'user' });
  const newRefreshToken = generateRefreshToken(payload.userId);
  
  // Store new refresh token
  await db.refreshToken.create({ data: { token: newRefreshToken, userId: payload.userId } });
  
  return { accessToken: newAccessToken, refreshToken: newRefreshToken };
}
```

### 1.3 Session Security

```typescript
// Secure cookie settings
const sessionOptions = {
  httpOnly: true,           // Prevent XSS access
  secure: true,             // HTTPS only
  sameSite: 'lax' as const, // CSRF protection
  maxAge: 60 * 60 * 24 * 7, // 7 days
  path: '/',
  domain: process.env.COOKIE_DOMAIN,
};

// Set session cookie
res.cookie('session', sessionToken, sessionOptions);

// Clear session
res.clearCookie('session', {
  httpOnly: true,
  secure: true,
  sameSite: 'lax',
  path: '/',
});
```

---

## 2. Input Validation & Sanitization

### 2.1 Schema Validation

```typescript
import { z } from 'zod';

// ALWAYS validate ALL input
// NEVER trust client data

const createUserSchema = z.object({
  email: z.string()
    .email('Invalid email')
    .max(255)
    .toLowerCase()
    .trim(),
  password: z.string()
    .min(8, 'Password must be at least 8 characters')
    .max(100, 'Password too long')
    .regex(/[A-Z]/, 'Must contain uppercase')
    .regex(/[a-z]/, 'Must contain lowercase')
    .regex(/[0-9]/, 'Must contain number'),
  name: z.string()
    .min(2)
    .max(50)
    .trim()
    .regex(/^[a-zA-Z\s'-]+$/, 'Invalid characters'),
  age: z.number()
    .int()
    .min(13)
    .max(120)
    .optional(),
});

// Strict - reject unknown fields
const strictSchema = createUserSchema.strict();

// Validate
function validateInput<T>(schema: z.ZodSchema<T>, data: unknown): T {
  const result = schema.safeParse(data);
  if (!result.success) {
    throw new ValidationError('Invalid input', result.error.flatten());
  }
  return result.data;
}
```

### 2.2 SQL Injection Prevention

```typescript
// NEVER concatenate user input into queries

// BAD - SQL Injection vulnerable
const query = `SELECT * FROM users WHERE id = '${userId}'`;

// GOOD - Parameterized queries (Prisma)
const user = await prisma.user.findUnique({
  where: { id: userId },
});

// GOOD - Parameterized queries (raw SQL)
const user = await prisma.$queryRaw`
  SELECT * FROM users WHERE id = ${userId}
`;

// GOOD - Drizzle
const user = await db.select().from(users).where(eq(users.id, userId));

// If you MUST use raw queries
import { sql } from 'drizzle-orm';
const result = await db.execute(sql`
  SELECT * FROM users WHERE id = ${userId}
`);
```

### 2.3 NoSQL Injection Prevention

```typescript
// MongoDB - NEVER pass user input directly to operators

// BAD - NoSQL Injection
const user = await collection.findOne({
  email: req.body.email,
  password: req.body.password, // { $gt: '' } bypasses auth!
});

// GOOD - Type assertion and sanitization
import mongoSanitize from 'express-mongo-sanitize';

app.use(mongoSanitize()); // Strips $ and . from input

// Or manual validation
function sanitizeMongoInput(input: unknown): string {
  if (typeof input !== 'string') {
    throw new ValidationError('Invalid input type');
  }
  if (input.includes('$') || input.includes('.')) {
    throw new ValidationError('Invalid characters');
  }
  return input;
}
```

### 2.4 XSS Prevention

```typescript
import DOMPurify from 'isomorphic-dompurify';

// Sanitize HTML content
export function sanitizeHtml(dirty: string): string {
  return DOMPurify.sanitize(dirty, {
    ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'a', 'p', 'br'],
    ALLOWED_ATTR: ['href', 'target'],
  });
}

// For plain text - escape HTML
export function escapeHtml(text: string): string {
  const map: Record<string, string> = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#x27;',
  };
  return text.replace(/[&<>"']/g, (char) => map[char]);
}

// React automatically escapes - but be careful with:
// dangerouslySetInnerHTML={{ __html: sanitizeHtml(content) }}
```

### 2.5 File Upload Security

```typescript
import { fileTypeFromBuffer } from 'file-type';
import path from 'path';

const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'];
const MAX_SIZE = 5 * 1024 * 1024; // 5MB

export async function validateUpload(file: Buffer, filename: string) {
  // Check file size
  if (file.length > MAX_SIZE) {
    throw new ValidationError('File too large');
  }

  // Check MIME type from magic bytes (NOT extension)
  const type = await fileTypeFromBuffer(file);
  if (!type || !ALLOWED_TYPES.includes(type.mime)) {
    throw new ValidationError('Invalid file type');
  }

  // Sanitize filename
  const safeName = path.basename(filename)
    .replace(/[^a-zA-Z0-9.-]/g, '_')
    .substring(0, 100);

  // Generate unique name
  const uniqueName = `${Date.now()}-${crypto.randomUUID()}-${safeName}`;

  return { buffer: file, filename: uniqueName, mimeType: type.mime };
}

// Path traversal prevention
export function getSafePath(userInput: string, baseDir: string): string {
  const resolved = path.resolve(baseDir, userInput);
  if (!resolved.startsWith(baseDir)) {
    throw new SecurityError('Path traversal detected');
  }
  return resolved;
}
```

---

## 3. Authorization

### 3.1 Role-Based Access Control (RBAC)

```typescript
type Role = 'admin' | 'manager' | 'user';
type Permission = 'create' | 'read' | 'update' | 'delete';
type Resource = 'users' | 'posts' | 'orders';

const rolePermissions: Record<Role, Partial<Record<Resource, Permission[]>>> = {
  admin: {
    users: ['create', 'read', 'update', 'delete'],
    posts: ['create', 'read', 'update', 'delete'],
    orders: ['create', 'read', 'update', 'delete'],
  },
  manager: {
    users: ['read'],
    posts: ['create', 'read', 'update'],
    orders: ['read', 'update'],
  },
  user: {
    posts: ['read'],
    orders: ['create', 'read'],
  },
};

export function hasPermission(
  role: Role,
  resource: Resource,
  permission: Permission
): boolean {
  return rolePermissions[role]?.[resource]?.includes(permission) ?? false;
}

// Middleware
export function requirePermission(resource: Resource, permission: Permission) {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!hasPermission(req.user.role, resource, permission)) {
      return res.status(403).json({ error: 'Forbidden' });
    }
    next();
  };
}

// Usage
router.delete('/users/:id', requirePermission('users', 'delete'), deleteUser);
```

### 3.2 Object-Level Authorization (BOLA Prevention)

```typescript
// ALWAYS verify resource ownership

// BAD - BOLA vulnerable
router.get('/orders/:id', async (req, res) => {
  const order = await db.order.findUnique({ where: { id: req.params.id } });
  res.json(order); // Anyone can access any order!
});

// GOOD - Check ownership
router.get('/orders/:id', async (req, res) => {
  const order = await db.order.findUnique({
    where: {
      id: req.params.id,
      userId: req.user.id, // Ownership check
    },
  });
  
  if (!order) {
    return res.status(404).json({ error: 'Order not found' });
  }
  
  res.json(order);
});

// GOOD - Admin override
router.get('/orders/:id', async (req, res) => {
  const where: Prisma.OrderWhereUniqueInput = { id: req.params.id };
  
  // Only filter by user if not admin
  if (req.user.role !== 'admin') {
    where.userId = req.user.id;
  }
  
  const order = await db.order.findUnique({ where });
  // ...
});
```

---

## 4. API Security

### 4.1 Rate Limiting

```typescript
import rateLimit from 'express-rate-limit';
import RedisStore from 'rate-limit-redis';
import { redis } from './redis';

// General API limit
export const apiLimiter = rateLimit({
  store: new RedisStore({
    sendCommand: (...args: string[]) => redis.sendCommand(args),
  }),
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // 100 requests per window
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => req.ip || 'unknown',
  handler: (req, res) => {
    res.status(429).json({
      error: 'Too many requests',
      retryAfter: res.getHeader('Retry-After'),
    });
  },
});

// Strict auth limit
export const authLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 5, // 5 attempts
  skipSuccessfulRequests: true, // Only count failures
});

// Per-user limit for expensive operations
export const exportLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 3,
  keyGenerator: (req) => `export:${req.user?.id}`,
});
```

### 4.2 Request Size Limits

```typescript
import express from 'express';

// Limit JSON body size
app.use(express.json({ limit: '10kb' }));

// Limit URL-encoded body
app.use(express.urlencoded({ limit: '10kb', extended: true }));

// Custom limits for specific routes
router.post('/upload', express.raw({ limit: '10mb', type: 'image/*' }), uploadHandler);
```

### 4.3 CORS Configuration

```typescript
import cors from 'cors';

const corsOptions: cors.CorsOptions = {
  origin: (origin, callback) => {
    const allowedOrigins = [
      'https://yourapp.com',
      'https://admin.yourapp.com',
    ];
    
    // Allow requests with no origin (mobile apps, Postman)
    if (!origin) return callback(null, true);
    
    if (allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true, // Allow cookies
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  exposedHeaders: ['X-Total-Count', 'X-Request-Id'],
  maxAge: 86400, // 24 hours
};

app.use(cors(corsOptions));
```

---

## 5. Security Headers

### 5.1 Helmet Configuration

```typescript
import helmet from 'helmet';

app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'"], // Remove unsafe-inline if possible
      styleSrc: ["'self'", "'unsafe-inline'", 'https://fonts.googleapis.com'],
      imgSrc: ["'self'", 'data:', 'https:'],
      fontSrc: ["'self'", 'https://fonts.gstatic.com'],
      connectSrc: ["'self'", 'https://api.yourapp.com'],
      frameSrc: ["'none'"],
      objectSrc: ["'none'"],
      upgradeInsecureRequests: [],
    },
  },
  crossOriginEmbedderPolicy: true,
  crossOriginOpenerPolicy: { policy: 'same-origin' },
  crossOriginResourcePolicy: { policy: 'same-origin' },
  dnsPrefetchControl: { allow: false },
  frameguard: { action: 'deny' },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true,
  },
  ieNoOpen: true,
  noSniff: true,
  originAgentCluster: true,
  permittedCrossDomainPolicies: { permittedPolicies: 'none' },
  referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
  xssFilter: true,
}));
```

### 5.2 Next.js Security Headers

```typescript
// next.config.js
const securityHeaders = [
  {
    key: 'X-DNS-Prefetch-Control',
    value: 'on',
  },
  {
    key: 'Strict-Transport-Security',
    value: 'max-age=31536000; includeSubDomains; preload',
  },
  {
    key: 'X-Frame-Options',
    value: 'DENY',
  },
  {
    key: 'X-Content-Type-Options',
    value: 'nosniff',
  },
  {
    key: 'Referrer-Policy',
    value: 'strict-origin-when-cross-origin',
  },
  {
    key: 'Permissions-Policy',
    value: 'camera=(), microphone=(), geolocation=()',
  },
];

module.exports = {
  async headers() {
    return [
      {
        source: '/:path*',
        headers: securityHeaders,
      },
    ];
  },
};
```

---

## 6. Secrets Management

### 6.1 Environment Variables

```typescript
// NEVER commit secrets
// NEVER log secrets
// ALWAYS validate at startup

import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']),
  DATABASE_URL: z.string().url(),
  JWT_SECRET: z.string().min(32),
  STRIPE_SECRET_KEY: z.string().startsWith('sk_'),
  AWS_ACCESS_KEY_ID: z.string().optional(),
  AWS_SECRET_ACCESS_KEY: z.string().optional(),
});

// Validate on startup
const env = envSchema.parse(process.env);

// Export typed config
export const config = {
  isDev: env.NODE_ENV === 'development',
  isProd: env.NODE_ENV === 'production',
  database: { url: env.DATABASE_URL },
  jwt: { secret: env.JWT_SECRET },
  stripe: { secretKey: env.STRIPE_SECRET_KEY },
} as const;

// Prevent secret leakage in errors
export function sanitizeError(error: Error): Error {
  const secrets = [env.JWT_SECRET, env.STRIPE_SECRET_KEY, env.DATABASE_URL];
  let message = error.message;
  
  for (const secret of secrets) {
    if (secret) {
      message = message.replaceAll(secret, '[REDACTED]');
    }
  }
  
  return new Error(message);
}
```

### 6.2 .gitignore

```gitignore
# Environment files
.env
.env.local
.env.*.local
.env.development
.env.production

# Secrets
*.pem
*.key
secrets/
credentials.json

# IDE
.idea/
.vscode/settings.json

# Dependencies
node_modules/

# Build
dist/
.next/
```

---

## 7. Error Handling (Security)

```typescript
// NEVER expose stack traces in production
// NEVER expose internal error details

class AppError extends Error {
  constructor(
    public message: string,
    public statusCode: number,
    public code: string,
    public isOperational: boolean = true
  ) {
    super(message);
  }
}

// Error handler middleware
app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  // Log full error internally
  logger.error({
    error: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method,
    ip: req.ip,
    userId: req.user?.id,
  });

  // Don't leak details in production
  if (err instanceof AppError && err.isOperational) {
    return res.status(err.statusCode).json({
      error: err.code,
      message: err.message,
    });
  }

  // Generic error for unexpected issues
  res.status(500).json({
    error: 'INTERNAL_ERROR',
    message: 'An unexpected error occurred',
    // Only in development
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
  });
});
```

---

## Quick Reference

### Security Checklist

**Authentication**
- [ ] Passwords hashed with bcrypt (cost 12+) or argon2
- [ ] JWT with short expiry (15m access, 7d refresh)
- [ ] Secure cookie flags (httpOnly, secure, sameSite)
- [ ] Rate limiting on auth endpoints

**Input Validation**
- [ ] All input validated with Zod
- [ ] Parameterized queries only
- [ ] HTML sanitized before storage/display
- [ ] File uploads validated by magic bytes

**Authorization**
- [ ] RBAC implemented
- [ ] Object-level checks (BOLA prevention)
- [ ] Admin-only routes protected

**API Security**
- [ ] Rate limiting on all endpoints
- [ ] Request size limits
- [ ] CORS properly configured
- [ ] Security headers (Helmet)

**Secrets**
- [ ] .env files in .gitignore
- [ ] Secrets validated at startup
- [ ] No secrets in logs or errors

### OWASP Top 10 Quick Map

| Risk | Prevention |
|------|------------|
| Injection | Parameterized queries, input validation |
| Broken Auth | Strong passwords, JWT best practices |
| Sensitive Data | HTTPS, encryption at rest, minimal data |
| XXE | Disable DTDs in XML parsers |
| Broken Access | RBAC, object-level authorization |
| Misconfig | Helmet, secure defaults, no debug in prod |
| XSS | CSP, HTML sanitization, React escaping |
| Insecure Deserialization | Don't deserialize untrusted data |
| Components | npm audit, Snyk, regular updates |
| Logging | Structured logging, no secrets in logs |
