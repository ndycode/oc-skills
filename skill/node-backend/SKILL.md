# Node.js Backend Best Practices

> **Source**: [goldbergyoni/nodebestpractices](https://github.com/goldbergyoni/nodebestpractices) (105k+ stars)
> **Auto-trigger**: `package.json` with `express`, `fastify`, `nestjs`, `koa`, or Node.js backend indicators

---

## 1. Project Structure

### 1.1 Component-Based Structure

```
src/
├── components/
│   ├── users/
│   │   ├── users.controller.ts
│   │   ├── users.service.ts
│   │   ├── users.repository.ts
│   │   ├── users.model.ts
│   │   ├── users.validation.ts
│   │   ├── users.routes.ts
│   │   └── users.test.ts
│   ├── orders/
│   └── products/
├── libraries/
│   ├── logger/
│   ├── db/
│   └── cache/
├── config/
│   ├── index.ts
│   └── env.validation.ts
├── middleware/
├── utils/
└── app.ts
```

### 1.2 Layer Separation

```typescript
// Controller - HTTP only, no business logic
export class UsersController {
  constructor(private usersService: UsersService) {}

  async getUser(req: Request, res: Response) {
    const user = await this.usersService.findById(req.params.id);
    res.json(user);
  }
}

// Service - Business logic, no HTTP awareness
export class UsersService {
  constructor(private usersRepository: UsersRepository) {}

  async findById(id: string): Promise<User> {
    const user = await this.usersRepository.findById(id);
    if (!user) throw new NotFoundError('User not found');
    return user;
  }
}

// Repository - Data access only
export class UsersRepository {
  async findById(id: string): Promise<User | null> {
    return prisma.user.findUnique({ where: { id } });
  }
}
```

### 1.3 Config Management

```typescript
// config/index.ts
import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']),
  PORT: z.coerce.number().default(3000),
  DATABASE_URL: z.string().url(),
  JWT_SECRET: z.string().min(32),
  REDIS_URL: z.string().url().optional(),
});

// Validate at startup - fail fast
const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  console.error('Invalid environment variables:', parsed.error.flatten());
  process.exit(1);
}

export const config = parsed.data;
```

---

## 2. Error Handling

### 2.1 Centralized Error Handling

```typescript
// errors/AppError.ts
export class AppError extends Error {
  constructor(
    public message: string,
    public statusCode: number = 500,
    public isOperational: boolean = true,
    public code?: string
  ) {
    super(message);
    Error.captureStackTrace(this, this.constructor);
  }
}

export class NotFoundError extends AppError {
  constructor(message = 'Resource not found') {
    super(message, 404, true, 'NOT_FOUND');
  }
}

export class ValidationError extends AppError {
  constructor(message: string, public details?: unknown) {
    super(message, 400, true, 'VALIDATION_ERROR');
  }
}

export class UnauthorizedError extends AppError {
  constructor(message = 'Unauthorized') {
    super(message, 401, true, 'UNAUTHORIZED');
  }
}
```

### 2.2 Error Handler Middleware

```typescript
// middleware/errorHandler.ts
import { ErrorRequestHandler } from 'express';
import { AppError } from '../errors/AppError';
import { logger } from '../libraries/logger';

export const errorHandler: ErrorRequestHandler = (err, req, res, next) => {
  // Log all errors
  logger.error({
    message: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method,
    requestId: req.id,
  });

  // Operational errors - safe to expose
  if (err instanceof AppError && err.isOperational) {
    return res.status(err.statusCode).json({
      status: 'error',
      code: err.code,
      message: err.message,
      ...(err.details && { details: err.details }),
    });
  }

  // Programming errors - don't leak details
  return res.status(500).json({
    status: 'error',
    code: 'INTERNAL_ERROR',
    message: 'An unexpected error occurred',
  });
};
```

### 2.3 Async Error Wrapper

```typescript
// utils/asyncHandler.ts
import { RequestHandler } from 'express';

export const asyncHandler = (fn: RequestHandler): RequestHandler => {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
};

// Usage
router.get('/users/:id', asyncHandler(async (req, res) => {
  const user = await usersService.findById(req.params.id);
  res.json(user);
}));
```

### 2.4 Unhandled Rejections

```typescript
// At app startup
process.on('unhandledRejection', (reason: Error) => {
  logger.fatal('Unhandled Rejection', { error: reason });
  // Give time to log, then exit
  setTimeout(() => process.exit(1), 1000);
});

process.on('uncaughtException', (error: Error) => {
  logger.fatal('Uncaught Exception', { error });
  setTimeout(() => process.exit(1), 1000);
});
```

---

## 3. Validation

### 3.1 Request Validation with Zod

```typescript
// users/users.validation.ts
import { z } from 'zod';

export const createUserSchema = z.object({
  body: z.object({
    email: z.string().email(),
    password: z.string().min(8).max(100),
    name: z.string().min(2).max(50),
  }),
});

export const getUserSchema = z.object({
  params: z.object({
    id: z.string().uuid(),
  }),
});

export type CreateUserInput = z.infer<typeof createUserSchema>['body'];
```

### 3.2 Validation Middleware

```typescript
// middleware/validate.ts
import { AnyZodObject, ZodError } from 'zod';
import { RequestHandler } from 'express';
import { ValidationError } from '../errors/AppError';

export const validate = (schema: AnyZodObject): RequestHandler => {
  return async (req, res, next) => {
    try {
      await schema.parseAsync({
        body: req.body,
        query: req.query,
        params: req.params,
      });
      next();
    } catch (error) {
      if (error instanceof ZodError) {
        next(new ValidationError('Invalid request', error.flatten()));
      } else {
        next(error);
      }
    }
  };
};

// Usage
router.post('/users', validate(createUserSchema), asyncHandler(createUser));
```

---

## 4. Security

### 4.1 Helmet Configuration

```typescript
import helmet from 'helmet';

app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", 'data:', 'https:'],
    },
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true,
  },
}));
```

### 4.2 Rate Limiting

```typescript
import rateLimit from 'express-rate-limit';
import RedisStore from 'rate-limit-redis';
import { redis } from './libraries/redis';

// General API rate limit
const apiLimiter = rateLimit({
  store: new RedisStore({ sendCommand: (...args) => redis.call(...args) }),
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests, please try again later' },
});

// Stricter limit for auth endpoints
const authLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 5, // 5 attempts per hour
  skipSuccessfulRequests: true,
});

app.use('/api/', apiLimiter);
app.use('/api/auth/login', authLimiter);
```

### 4.3 Input Sanitization

```typescript
import mongoSanitize from 'express-mongo-sanitize';
import xss from 'xss-clean';

// Prevent NoSQL injection
app.use(mongoSanitize());

// Prevent XSS
app.use(xss());

// Limit body size
app.use(express.json({ limit: '10kb' }));
```

---

## 5. Logging

### 5.1 Structured Logging with Pino

```typescript
// libraries/logger/index.ts
import pino from 'pino';
import { config } from '../../config';

export const logger = pino({
  level: config.NODE_ENV === 'production' ? 'info' : 'debug',
  formatters: {
    level: (label) => ({ level: label }),
  },
  timestamp: pino.stdTimeFunctions.isoTime,
  ...(config.NODE_ENV === 'development' && {
    transport: {
      target: 'pino-pretty',
      options: { colorize: true },
    },
  }),
});

// Child logger with request context
export const createRequestLogger = (requestId: string) => {
  return logger.child({ requestId });
};
```

### 5.2 Request Logging Middleware

```typescript
import { randomUUID } from 'crypto';
import pinoHttp from 'pino-http';
import { logger } from './libraries/logger';

app.use(pinoHttp({
  logger,
  genReqId: () => randomUUID(),
  customLogLevel: (req, res, err) => {
    if (res.statusCode >= 500 || err) return 'error';
    if (res.statusCode >= 400) return 'warn';
    return 'info';
  },
  customSuccessMessage: (req, res) => {
    return `${req.method} ${req.url} ${res.statusCode}`;
  },
  redact: ['req.headers.authorization', 'req.headers.cookie'],
}));
```

---

## 6. Testing

### 6.1 Integration Test Setup

```typescript
// tests/setup.ts
import { beforeAll, afterAll, beforeEach } from 'vitest';
import { app } from '../src/app';
import { prisma } from '../src/libraries/db';

beforeAll(async () => {
  await prisma.$connect();
});

afterAll(async () => {
  await prisma.$disconnect();
});

beforeEach(async () => {
  // Clean database between tests
  await prisma.$transaction([
    prisma.user.deleteMany(),
    prisma.order.deleteMany(),
  ]);
});

export { app };
```

### 6.2 API Testing

```typescript
// users/users.test.ts
import { describe, it, expect } from 'vitest';
import supertest from 'supertest';
import { app } from '../tests/setup';

const request = supertest(app);

describe('POST /api/users', () => {
  it('creates a user with valid input', async () => {
    const response = await request
      .post('/api/users')
      .send({
        email: 'test@example.com',
        password: 'securePassword123',
        name: 'Test User',
      })
      .expect(201);

    expect(response.body).toMatchObject({
      email: 'test@example.com',
      name: 'Test User',
    });
    expect(response.body).not.toHaveProperty('password');
  });

  it('rejects invalid email', async () => {
    const response = await request
      .post('/api/users')
      .send({
        email: 'invalid',
        password: 'securePassword123',
        name: 'Test User',
      })
      .expect(400);

    expect(response.body.code).toBe('VALIDATION_ERROR');
  });
});
```

---

## 7. Docker

### 7.1 Production Dockerfile

```dockerfile
# Build stage
FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production=false

COPY . .
RUN npm run build

# Production stage
FROM node:20-alpine AS production

# Security: non-root user
RUN addgroup -g 1001 nodejs && \
    adduser -S -u 1001 -G nodejs nodejs

WORKDIR /app

COPY --from=builder --chown=nodejs:nodejs /app/dist ./dist
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nodejs:nodejs /app/package.json ./

USER nodejs

EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

CMD ["node", "dist/app.js"]
```

### 7.2 Docker Compose

```yaml
version: '3.8'

services:
  api:
    build:
      context: .
      target: production
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgresql://user:pass@db:5432/app
      - REDIS_URL=redis://redis:6379
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    restart: unless-stopped

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
      POSTGRES_DB: app
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user -d app"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
```

---

## 8. Graceful Shutdown

```typescript
// app.ts
import { createServer } from 'http';
import { prisma } from './libraries/db';
import { redis } from './libraries/redis';
import { logger } from './libraries/logger';

const server = createServer(app);

const gracefulShutdown = async (signal: string) => {
  logger.info(`${signal} received. Starting graceful shutdown...`);

  // Stop accepting new connections
  server.close(async () => {
    logger.info('HTTP server closed');

    try {
      // Close database connections
      await prisma.$disconnect();
      logger.info('Database disconnected');

      // Close Redis
      await redis.quit();
      logger.info('Redis disconnected');

      process.exit(0);
    } catch (error) {
      logger.error('Error during shutdown', { error });
      process.exit(1);
    }
  });

  // Force exit after 30s
  setTimeout(() => {
    logger.error('Forced shutdown after timeout');
    process.exit(1);
  }, 30000);
};

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

server.listen(config.PORT, () => {
  logger.info(`Server running on port ${config.PORT}`);
});
```

---

## Quick Reference

### Project Checklist
- [ ] Component-based folder structure
- [ ] Layered architecture (Controller → Service → Repository)
- [ ] Environment validation at startup
- [ ] Centralized error handling
- [ ] Request validation with Zod
- [ ] Structured logging (Pino)
- [ ] Security headers (Helmet)
- [ ] Rate limiting
- [ ] Graceful shutdown
- [ ] Health check endpoint
- [ ] Docker multi-stage build
- [ ] Non-root Docker user

### Anti-Patterns to Avoid
- Business logic in controllers
- `catch (e) {}` — empty catch blocks
- `console.log` in production
- Hardcoded secrets
- Missing input validation
- No request ID tracking
- Synchronous file operations
- `process.exit()` without cleanup
