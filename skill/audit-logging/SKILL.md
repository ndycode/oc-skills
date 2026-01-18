# Audit Logging

> **Sources**: [OWASP Logging](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html), [GDPR Article 30](https://gdpr-info.eu/art-30-gdpr/), [SOC 2 Logging Requirements](https://www.aicpa.org/soc2)
> **Auto-trigger**: Files containing audit logs, security events, compliance, GDPR, SOC2, user activity tracking, immutable logs

---

## Core Principles

1. **Immutability** - Logs cannot be modified or deleted
2. **Completeness** - All security-relevant events captured
3. **Integrity** - Tamper-evident with checksums
4. **Availability** - Accessible for investigation
5. **Confidentiality** - Protected from unauthorized access

---

## Audit Event Types

### What to Log
```typescript
// types/audit.ts
export type AuditEventType =
  // Authentication
  | 'auth.login.success'
  | 'auth.login.failure'
  | 'auth.logout'
  | 'auth.password.change'
  | 'auth.password.reset.request'
  | 'auth.password.reset.complete'
  | 'auth.mfa.enable'
  | 'auth.mfa.disable'
  | 'auth.session.revoke'
  
  // Authorization
  | 'authz.permission.grant'
  | 'authz.permission.revoke'
  | 'authz.role.assign'
  | 'authz.role.remove'
  | 'authz.access.denied'
  
  // Data Access
  | 'data.read'
  | 'data.create'
  | 'data.update'
  | 'data.delete'
  | 'data.export'
  | 'data.bulk.operation'
  
  // Account Management
  | 'account.create'
  | 'account.update'
  | 'account.delete'
  | 'account.suspend'
  | 'account.reactivate'
  
  // API Keys & Tokens
  | 'apikey.create'
  | 'apikey.revoke'
  | 'token.generate'
  | 'token.refresh'
  
  // Settings & Configuration
  | 'settings.update'
  | 'config.change'
  
  // Security Events
  | 'security.suspicious.activity'
  | 'security.rate.limit'
  | 'security.ip.blocked';

export interface AuditEvent {
  id: string;
  timestamp: string;
  type: AuditEventType;
  actor: {
    id: string;
    type: 'user' | 'system' | 'api';
    ip?: string;
    userAgent?: string;
  };
  target?: {
    type: string;
    id: string;
  };
  context: {
    organizationId?: string;
    sessionId?: string;
    requestId?: string;
  };
  metadata: Record<string, unknown>;
  outcome: 'success' | 'failure';
  reason?: string;
}
```

---

## Audit Logger Implementation

### Core Logger
```typescript
// lib/audit.ts
import { randomUUID } from 'crypto';

interface AuditLogInput {
  type: AuditEventType;
  actor: {
    id: string;
    type: 'user' | 'system' | 'api';
    ip?: string;
    userAgent?: string;
  };
  target?: {
    type: string;
    id: string;
  };
  context?: {
    organizationId?: string;
    sessionId?: string;
    requestId?: string;
  };
  metadata?: Record<string, unknown>;
  outcome: 'success' | 'failure';
  reason?: string;
}

class AuditLogger {
  private async persist(event: AuditEvent): Promise<void> {
    // Store in database
    await db.auditLog.create({
      data: {
        id: event.id,
        timestamp: event.timestamp,
        type: event.type,
        actorId: event.actor.id,
        actorType: event.actor.type,
        actorIp: event.actor.ip,
        targetType: event.target?.type,
        targetId: event.target?.id,
        organizationId: event.context.organizationId,
        metadata: event.metadata,
        outcome: event.outcome,
        reason: event.reason,
        // Checksum for integrity
        checksum: this.generateChecksum(event),
      },
    });

    // Also send to external log service for immutability
    await this.sendToExternalLog(event);
  }

  private generateChecksum(event: AuditEvent): string {
    const crypto = require('crypto');
    const content = JSON.stringify({
      id: event.id,
      timestamp: event.timestamp,
      type: event.type,
      actor: event.actor,
      target: event.target,
      outcome: event.outcome,
    });
    return crypto.createHmac('sha256', process.env.AUDIT_HMAC_SECRET!)
      .update(content)
      .digest('hex');
  }

  private async sendToExternalLog(event: AuditEvent): Promise<void> {
    // Send to immutable log storage (e.g., AWS CloudWatch, Datadog, etc.)
    // This provides tamper-evidence - if local DB is compromised,
    // external logs remain intact
  }

  async log(input: AuditLogInput): Promise<void> {
    const event: AuditEvent = {
      id: randomUUID(),
      timestamp: new Date().toISOString(),
      ...input,
      context: input.context || {},
      metadata: this.sanitizeMetadata(input.metadata || {}),
    };

    await this.persist(event);
  }

  private sanitizeMetadata(metadata: Record<string, unknown>): Record<string, unknown> {
    // Remove sensitive fields from metadata
    const sensitiveKeys = ['password', 'token', 'secret', 'apiKey', 'ssn', 'cardNumber'];
    const sanitized: Record<string, unknown> = {};

    for (const [key, value] of Object.entries(metadata)) {
      if (sensitiveKeys.some(k => key.toLowerCase().includes(k))) {
        sanitized[key] = '[REDACTED]';
      } else if (typeof value === 'object' && value !== null) {
        sanitized[key] = this.sanitizeMetadata(value as Record<string, unknown>);
      } else {
        sanitized[key] = value;
      }
    }

    return sanitized;
  }
}

export const audit = new AuditLogger();
```

### Usage Examples
```typescript
// Authentication events
await audit.log({
  type: 'auth.login.success',
  actor: { id: user.id, type: 'user', ip, userAgent },
  context: { sessionId },
  metadata: { method: 'password', mfaUsed: true },
  outcome: 'success',
});

await audit.log({
  type: 'auth.login.failure',
  actor: { id: attemptedEmail, type: 'user', ip, userAgent },
  metadata: { reason: 'invalid_password', attemptCount: 3 },
  outcome: 'failure',
  reason: 'Invalid credentials',
});

// Data access
await audit.log({
  type: 'data.read',
  actor: { id: session.userId, type: 'user', ip },
  target: { type: 'customer', id: customerId },
  context: { organizationId: session.orgId },
  metadata: { fields: ['email', 'phone'] },
  outcome: 'success',
});

// Permission changes
await audit.log({
  type: 'authz.role.assign',
  actor: { id: adminId, type: 'user', ip },
  target: { type: 'user', id: targetUserId },
  context: { organizationId },
  metadata: { role: 'admin', previousRole: 'member' },
  outcome: 'success',
});
```

---

## Database Schema

### Prisma Schema
```prisma
// schema.prisma
model AuditLog {
  id             String   @id @default(uuid())
  timestamp      DateTime @default(now())
  type           String
  
  // Actor
  actorId        String
  actorType      String   // user, system, api
  actorIp        String?
  
  // Target
  targetType     String?
  targetId       String?
  
  // Context
  organizationId String?
  sessionId      String?
  requestId      String?
  
  // Event details
  metadata       Json     @default("{}")
  outcome        String   // success, failure
  reason         String?
  
  // Integrity
  checksum       String
  
  // Indexes for common queries
  @@index([organizationId, timestamp])
  @@index([actorId, timestamp])
  @@index([targetType, targetId])
  @@index([type, timestamp])
  
  // Prevent updates/deletes at application level
  // Use database-level restrictions for true immutability
}
```

### PostgreSQL Immutability
```sql
-- Prevent UPDATE and DELETE on audit_logs
CREATE OR REPLACE FUNCTION prevent_audit_modification()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'Audit logs cannot be modified or deleted';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER audit_log_immutable
BEFORE UPDATE OR DELETE ON "AuditLog"
FOR EACH ROW
EXECUTE FUNCTION prevent_audit_modification();

-- Partition by month for performance
CREATE TABLE audit_log_2024_01 PARTITION OF "AuditLog"
FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
```

---

## Middleware Integration

### Request Tracking
```typescript
// middleware.ts
import { NextRequest, NextResponse } from 'next/server';
import { randomUUID } from 'crypto';

export async function middleware(req: NextRequest) {
  const requestId = randomUUID();
  
  // Add request ID to headers for tracking
  const response = NextResponse.next();
  response.headers.set('X-Request-ID', requestId);

  // Store in request for later use
  req.headers.set('X-Request-ID', requestId);

  return response;
}
```

### Route Handler Wrapper
```typescript
// lib/with-audit.ts
import { NextRequest, NextResponse } from 'next/server';
import { auth } from './auth';
import { audit } from './audit';

type Handler = (req: NextRequest, context: any) => Promise<NextResponse>;

export function withAudit(
  auditType: AuditEventType,
  targetExtractor?: (req: NextRequest, context: any) => { type: string; id: string }
) {
  return (handler: Handler): Handler => {
    return async (req: NextRequest, context: any) => {
      const session = await auth();
      const requestId = req.headers.get('X-Request-ID') || randomUUID();
      const ip = req.ip || req.headers.get('x-forwarded-for') || 'unknown';
      const userAgent = req.headers.get('user-agent') || 'unknown';

      try {
        const response = await handler(req, context);

        // Log successful operation
        await audit.log({
          type: auditType,
          actor: {
            id: session?.user?.id || 'anonymous',
            type: session?.user ? 'user' : 'api',
            ip,
            userAgent,
          },
          target: targetExtractor?.(req, context),
          context: {
            requestId,
            organizationId: session?.user?.orgId,
            sessionId: session?.sessionId,
          },
          outcome: 'success',
        });

        return response;
      } catch (error) {
        // Log failed operation
        await audit.log({
          type: auditType,
          actor: {
            id: session?.user?.id || 'anonymous',
            type: session?.user ? 'user' : 'api',
            ip,
            userAgent,
          },
          target: targetExtractor?.(req, context),
          context: { requestId },
          outcome: 'failure',
          reason: error instanceof Error ? error.message : 'Unknown error',
        });

        throw error;
      }
    };
  };
}

// Usage
// app/api/users/[id]/route.ts
export const GET = withAudit(
  'data.read',
  (req, { params }) => ({ type: 'user', id: params.id })
)(async (req, { params }) => {
  const user = await getUser(params.id);
  return NextResponse.json(user);
});
```

---

## GDPR Compliance

### Data Subject Access Request (DSAR)
```typescript
// lib/gdpr.ts
export async function handleDataSubjectAccessRequest(userId: string) {
  // Get all audit logs for this user
  const auditLogs = await db.auditLog.findMany({
    where: {
      OR: [
        { actorId: userId },
        { targetId: userId },
      ],
    },
    orderBy: { timestamp: 'desc' },
  });

  // Get all personal data
  const userData = await db.user.findUnique({
    where: { id: userId },
    include: {
      profile: true,
      orders: true,
      // ... all related data
    },
  });

  // Log the DSAR itself
  await audit.log({
    type: 'data.export',
    actor: { id: userId, type: 'user' },
    target: { type: 'user', id: userId },
    metadata: { requestType: 'DSAR' },
    outcome: 'success',
  });

  return {
    personalData: userData,
    activityLog: auditLogs,
    exportedAt: new Date().toISOString(),
  };
}

// Right to erasure (with audit trail)
export async function handleErasureRequest(userId: string, adminId: string) {
  // Anonymize personal data
  await db.user.update({
    where: { id: userId },
    data: {
      email: `deleted-${userId}@example.com`,
      name: '[DELETED]',
      phone: null,
      // Preserve ID for audit log integrity
    },
  });

  // Log the erasure
  await audit.log({
    type: 'account.delete',
    actor: { id: adminId, type: 'user' },
    target: { type: 'user', id: userId },
    metadata: { 
      requestType: 'GDPR_ERASURE',
      retainedForAudit: true,
    },
    outcome: 'success',
  });

  // Note: Audit logs are NOT deleted - they're anonymized
  // The userId in audit logs now points to anonymized data
}
```

### Retention Policy
```typescript
// scripts/audit-retention.ts
const RETENTION_PERIODS = {
  'auth.*': 365, // 1 year
  'data.*': 730, // 2 years
  'security.*': 1825, // 5 years
  'default': 365,
};

async function applyRetentionPolicy() {
  for (const [pattern, days] of Object.entries(RETENTION_PERIODS)) {
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - days);

    // Archive to cold storage instead of deleting
    const logsToArchive = await db.auditLog.findMany({
      where: {
        type: pattern === 'default' ? undefined : { startsWith: pattern.replace('.*', '') },
        timestamp: { lt: cutoff },
        archived: false,
      },
    });

    // Export to S3 Glacier
    await archiveToGlacier(logsToArchive);

    // Mark as archived
    await db.auditLog.updateMany({
      where: {
        id: { in: logsToArchive.map(l => l.id) },
      },
      data: { archived: true },
    });
  }
}
```

---

## Querying Audit Logs

### Admin Dashboard Queries
```typescript
// lib/audit-queries.ts
export async function getAuditLogsForOrg(
  orgId: string,
  filters: {
    startDate?: Date;
    endDate?: Date;
    types?: AuditEventType[];
    actorId?: string;
    targetType?: string;
    outcome?: 'success' | 'failure';
  },
  pagination: {
    page: number;
    limit: number;
  }
) {
  const where: any = {
    organizationId: orgId,
  };

  if (filters.startDate || filters.endDate) {
    where.timestamp = {};
    if (filters.startDate) where.timestamp.gte = filters.startDate;
    if (filters.endDate) where.timestamp.lte = filters.endDate;
  }

  if (filters.types?.length) {
    where.type = { in: filters.types };
  }

  if (filters.actorId) {
    where.actorId = filters.actorId;
  }

  if (filters.outcome) {
    where.outcome = filters.outcome;
  }

  const [logs, total] = await Promise.all([
    db.auditLog.findMany({
      where,
      orderBy: { timestamp: 'desc' },
      skip: (pagination.page - 1) * pagination.limit,
      take: pagination.limit,
    }),
    db.auditLog.count({ where }),
  ]);

  return {
    logs,
    total,
    pages: Math.ceil(total / pagination.limit),
  };
}

// Security investigation
export async function investigateUserActivity(
  userId: string,
  timeWindow: { start: Date; end: Date }
) {
  const logs = await db.auditLog.findMany({
    where: {
      actorId: userId,
      timestamp: {
        gte: timeWindow.start,
        lte: timeWindow.end,
      },
    },
    orderBy: { timestamp: 'asc' },
  });

  // Build activity timeline
  return logs.map(log => ({
    time: log.timestamp,
    action: log.type,
    target: log.targetId ? `${log.targetType}:${log.targetId}` : null,
    ip: log.actorIp,
    outcome: log.outcome,
    details: log.metadata,
  }));
}
```

---

## Anti-Patterns

```typescript
// ❌ NEVER: Log sensitive data
await audit.log({
  metadata: { password: newPassword, ssn: user.ssn }, // Exposed!
});

// ✅ CORRECT: Redact sensitive fields
await audit.log({
  metadata: { passwordChanged: true },
});

// ❌ NEVER: Allow audit log modification
await db.auditLog.update({ where: { id }, data: { ... } }); // Tampering!

// ✅ CORRECT: Append-only with database constraints
// Use triggers to prevent UPDATE/DELETE

// ❌ NEVER: Log everything without filtering
await audit.log({ type: 'data.read', metadata: entireDatabaseRecord });

// ✅ CORRECT: Log only what's needed
await audit.log({
  type: 'data.read',
  target: { type: 'user', id: userId },
  metadata: { fields: ['email', 'profile'] },
});

// ❌ NEVER: Skip logging for "trusted" operations
if (user.isAdmin) { /* skip logging */ }

// ✅ CORRECT: Log everything, especially admin actions
// Admin actions are high-value audit targets
```

---

## Quick Reference

### What to Always Log
| Event | Why |
|-------|-----|
| Login success/failure | Security, compliance |
| Password changes | Account security |
| Permission changes | Access control audit |
| Data exports | GDPR, data exfiltration |
| Admin actions | Privilege abuse detection |
| API key operations | Security |
| Failed auth attempts | Attack detection |

### What to Never Log
| Data | Risk |
|------|------|
| Passwords (even hashed) | Security |
| Full credit card numbers | PCI-DSS |
| SSN/Tax IDs | Privacy |
| Session tokens | Security |
| API keys | Security |

### Retention Guidelines
| Log Type | Retention | Reason |
|----------|-----------|--------|
| Security events | 5+ years | Forensics |
| Authentication | 1 year | Compliance |
| Data access | 2 years | GDPR |
| API usage | 90 days | Troubleshooting |

### Checklist
- [ ] All security events logged
- [ ] Sensitive data redacted
- [ ] Logs are immutable (DB triggers)
- [ ] External backup for tamper-evidence
- [ ] Checksums for integrity
- [ ] Retention policy implemented
- [ ] GDPR export capability
- [ ] Query interface for investigations
- [ ] Alerting on suspicious patterns
