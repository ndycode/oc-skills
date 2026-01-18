# Error Handling & Observability

> **Auto-trigger**: Error handling, logging, monitoring setup, Sentry integration

---

## 1. Sentry Integration

### 1.1 Next.js Setup

```typescript
// sentry.client.config.ts
import * as Sentry from '@sentry/nextjs';

Sentry.init({
  dsn: process.env.NEXT_PUBLIC_SENTRY_DSN,
  environment: process.env.NODE_ENV,
  tracesSampleRate: 1.0,
  replaysSessionSampleRate: 0.1,
  replaysOnErrorSampleRate: 1.0,
  integrations: [
    Sentry.replayIntegration({
      maskAllText: true,
      blockAllMedia: true,
    }),
  ],
});

// sentry.server.config.ts
import * as Sentry from '@sentry/nextjs';

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  tracesSampleRate: 1.0,
  profilesSampleRate: 1.0,
});

// next.config.js
const { withSentryConfig } = require('@sentry/nextjs');

module.exports = withSentryConfig(nextConfig, {
  silent: true,
  org: 'your-org',
  project: 'your-project',
});
```

### 1.2 Manual Error Capture

```typescript
import * as Sentry from '@sentry/nextjs';

// Capture exception with context
try {
  await riskyOperation();
} catch (error) {
  Sentry.captureException(error, {
    tags: {
      feature: 'checkout',
      userId: user.id,
    },
    extra: {
      orderId: order.id,
      items: order.items,
    },
  });
  throw error;
}

// Capture message
Sentry.captureMessage('User reached rate limit', {
  level: 'warning',
  tags: { userId: user.id },
});

// Set user context
Sentry.setUser({
  id: user.id,
  email: user.email,
  username: user.name,
});

// Add breadcrumb
Sentry.addBreadcrumb({
  category: 'auth',
  message: 'User logged in',
  level: 'info',
});
```

### 1.3 Error Boundary with Sentry

```typescript
'use client';

import * as Sentry from '@sentry/nextjs';
import { useEffect } from 'react';

export default function ErrorBoundary({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    Sentry.captureException(error);
  }, [error]);

  return (
    <div className="flex flex-col items-center justify-center min-h-[400px]">
      <h2 className="text-xl font-semibold mb-4">Something went wrong</h2>
      <button
        onClick={reset}
        className="px-4 py-2 bg-primary text-white rounded"
      >
        Try again
      </button>
    </div>
  );
}
```

---

## 2. Structured Logging

### 2.1 Pino Setup

```typescript
// lib/logger.ts
import pino from 'pino';

const isProduction = process.env.NODE_ENV === 'production';

export const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  formatters: {
    level: (label) => ({ level: label }),
    bindings: () => ({}),
  },
  timestamp: pino.stdTimeFunctions.isoTime,
  ...(isProduction
    ? {}
    : {
        transport: {
          target: 'pino-pretty',
          options: {
            colorize: true,
            ignore: 'pid,hostname',
          },
        },
      }),
});

// Child logger with context
export function createLogger(context: Record<string, unknown>) {
  return logger.child(context);
}
```

### 2.2 Request Logging

```typescript
import { randomUUID } from 'crypto';
import pinoHttp from 'pino-http';

export const httpLogger = pinoHttp({
  logger,
  genReqId: (req) => req.headers['x-request-id'] || randomUUID(),
  customLogLevel: (req, res, err) => {
    if (res.statusCode >= 500 || err) return 'error';
    if (res.statusCode >= 400) return 'warn';
    return 'info';
  },
  customSuccessMessage: (req, res) => {
    return `${req.method} ${req.url} ${res.statusCode}`;
  },
  customErrorMessage: (req, res, err) => {
    return `${req.method} ${req.url} ${res.statusCode} - ${err.message}`;
  },
  redact: {
    paths: ['req.headers.authorization', 'req.headers.cookie', 'res.headers["set-cookie"]'],
    censor: '[REDACTED]',
  },
  serializers: {
    req: (req) => ({
      method: req.method,
      url: req.url,
      query: req.query,
      params: req.params,
    }),
    res: (res) => ({
      statusCode: res.statusCode,
    }),
  },
});
```

### 2.3 Logging Best Practices

```typescript
// GOOD - Structured logging
logger.info({ userId: user.id, action: 'login' }, 'User logged in');

logger.error(
  {
    err: error,
    userId: user.id,
    orderId: order.id,
  },
  'Failed to process order'
);

// BAD - String concatenation
logger.info(`User ${user.id} logged in`);
logger.error(`Error: ${error.message}`);

// Log levels
logger.trace('Detailed debugging');     // Most verbose
logger.debug('Debugging information');
logger.info('Normal operations');
logger.warn('Warning conditions');
logger.error('Error conditions');
logger.fatal('System is unusable');     // Most severe
```

---

## 3. Distributed Tracing

### 3.1 OpenTelemetry Setup

```typescript
// instrumentation.ts
import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { Resource } from '@opentelemetry/resources';
import { SemanticResourceAttributes } from '@opentelemetry/semantic-conventions';

const sdk = new NodeSDK({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: 'my-app',
    [SemanticResourceAttributes.SERVICE_VERSION]: process.env.npm_package_version,
  }),
  traceExporter: new OTLPTraceExporter({
    url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT,
  }),
  instrumentations: [
    getNodeAutoInstrumentations({
      '@opentelemetry/instrumentation-fs': { enabled: false },
    }),
  ],
});

sdk.start();

process.on('SIGTERM', () => {
  sdk.shutdown().finally(() => process.exit(0));
});
```

### 3.2 Custom Spans

```typescript
import { trace, SpanStatusCode } from '@opentelemetry/api';

const tracer = trace.getTracer('my-app');

async function processOrder(orderId: string) {
  return tracer.startActiveSpan('processOrder', async (span) => {
    try {
      span.setAttribute('order.id', orderId);

      // Child span for database operation
      await tracer.startActiveSpan('fetchOrder', async (dbSpan) => {
        const order = await db.order.findUnique({ where: { id: orderId } });
        dbSpan.setAttribute('order.status', order.status);
        dbSpan.end();
        return order;
      });

      // Child span for payment
      await tracer.startActiveSpan('processPayment', async (paymentSpan) => {
        await stripe.charges.create({ amount: order.total });
        paymentSpan.end();
      });

      span.setStatus({ code: SpanStatusCode.OK });
    } catch (error) {
      span.setStatus({
        code: SpanStatusCode.ERROR,
        message: error.message,
      });
      span.recordException(error);
      throw error;
    } finally {
      span.end();
    }
  });
}
```

---

## 4. Error Classes

```typescript
// errors/index.ts
export class AppError extends Error {
  constructor(
    message: string,
    public statusCode: number = 500,
    public code: string = 'INTERNAL_ERROR',
    public isOperational: boolean = true,
    public details?: unknown
  ) {
    super(message);
    this.name = this.constructor.name;
    Error.captureStackTrace(this, this.constructor);
  }

  toJSON() {
    return {
      error: {
        code: this.code,
        message: this.message,
        ...(this.details && { details: this.details }),
      },
    };
  }
}

export class ValidationError extends AppError {
  constructor(message: string, details?: unknown) {
    super(message, 400, 'VALIDATION_ERROR', true, details);
  }
}

export class NotFoundError extends AppError {
  constructor(resource: string = 'Resource') {
    super(`${resource} not found`, 404, 'NOT_FOUND', true);
  }
}

export class UnauthorizedError extends AppError {
  constructor(message: string = 'Unauthorized') {
    super(message, 401, 'UNAUTHORIZED', true);
  }
}

export class ForbiddenError extends AppError {
  constructor(message: string = 'Forbidden') {
    super(message, 403, 'FORBIDDEN', true);
  }
}

export class ConflictError extends AppError {
  constructor(message: string) {
    super(message, 409, 'CONFLICT', true);
  }
}

export class RateLimitError extends AppError {
  constructor(retryAfter?: number) {
    super('Too many requests', 429, 'RATE_LIMITED', true, { retryAfter });
  }
}
```

---

## 5. Error Handler Middleware

```typescript
// middleware/error-handler.ts
import { NextFunction, Request, Response } from 'express';
import * as Sentry from '@sentry/node';
import { logger } from '@/lib/logger';
import { AppError } from '@/errors';

export function errorHandler(
  err: Error,
  req: Request,
  res: Response,
  next: NextFunction
) {
  // Add request context
  const requestContext = {
    method: req.method,
    path: req.path,
    requestId: req.id,
    userId: req.user?.id,
  };

  // Log error
  if (err instanceof AppError && err.isOperational) {
    logger.warn({ err, ...requestContext }, err.message);
  } else {
    logger.error({ err, ...requestContext }, 'Unhandled error');
    
    // Report to Sentry
    Sentry.captureException(err, {
      tags: requestContext,
      user: req.user ? { id: req.user.id, email: req.user.email } : undefined,
    });
  }

  // Send response
  if (err instanceof AppError) {
    return res.status(err.statusCode).json(err.toJSON());
  }

  // Don't leak internal errors
  res.status(500).json({
    error: {
      code: 'INTERNAL_ERROR',
      message: 'An unexpected error occurred',
      requestId: req.id,
    },
  });
}
```

---

## 6. Health Checks

```typescript
// routes/health.ts
import { Router } from 'express';
import { prisma } from '@/lib/db';
import { redis } from '@/lib/redis';

const router = Router();

// Basic health check
router.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Detailed health check
router.get('/health/ready', async (req, res) => {
  const checks: Record<string, { status: string; latency?: number }> = {};

  // Database check
  const dbStart = Date.now();
  try {
    await prisma.$queryRaw`SELECT 1`;
    checks.database = { status: 'ok', latency: Date.now() - dbStart };
  } catch (error) {
    checks.database = { status: 'error' };
  }

  // Redis check
  const redisStart = Date.now();
  try {
    await redis.ping();
    checks.redis = { status: 'ok', latency: Date.now() - redisStart };
  } catch (error) {
    checks.redis = { status: 'error' };
  }

  const allHealthy = Object.values(checks).every((c) => c.status === 'ok');

  res.status(allHealthy ? 200 : 503).json({
    status: allHealthy ? 'ok' : 'degraded',
    timestamp: new Date().toISOString(),
    checks,
  });
});

export default router;
```

---

## 7. Alerting Patterns

```typescript
// lib/alerts.ts
import * as Sentry from '@sentry/node';
import { logger } from './logger';

interface AlertOptions {
  level: 'info' | 'warning' | 'error' | 'critical';
  tags?: Record<string, string>;
  extra?: Record<string, unknown>;
}

export function alert(message: string, options: AlertOptions) {
  const { level, tags, extra } = options;

  // Log locally
  logger[level === 'critical' ? 'fatal' : level]({ tags, ...extra }, message);

  // Send to Sentry
  Sentry.captureMessage(message, {
    level: level === 'critical' ? 'fatal' : level,
    tags,
    extra,
  });

  // For critical alerts, could also:
  // - Send to Slack/Discord
  // - Send SMS via Twilio
  // - Page on-call via PagerDuty
}

// Usage
alert('Database connection pool exhausted', {
  level: 'critical',
  tags: { service: 'api', component: 'database' },
  extra: { poolSize: 20, activeConnections: 20 },
});
```

---

## Quick Reference

### Log Levels
| Level | When to Use |
|-------|-------------|
| `trace` | Detailed debugging (not in prod) |
| `debug` | Development debugging |
| `info` | Normal operations |
| `warn` | Potential issues |
| `error` | Errors that need attention |
| `fatal` | System is unusable |

### Error Response Format
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid email format",
    "details": { "field": "email" },
    "requestId": "abc123"
  }
}
```

### Checklist
- [ ] Sentry configured for frontend & backend
- [ ] Structured logging (not console.log)
- [ ] Request ID in all logs
- [ ] PII redacted from logs
- [ ] Health check endpoints
- [ ] Error boundaries in React
- [ ] Source maps uploaded to Sentry
- [ ] Alerting for critical errors
