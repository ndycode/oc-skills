# Database Security

> **Sources**: [OWASP Database Security](https://cheatsheetseries.owasp.org/cheatsheets/Database_Security_Cheat_Sheet.html), [Supabase RLS](https://supabase.com/docs/guides/auth/row-level-security), [PostgreSQL Security](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
> **Auto-trigger**: Files containing database connections, Prisma schemas, SQL queries, RLS policies, `supabase`, encryption

---

## Row-Level Security (RLS)

### Supabase RLS Setup
```sql
-- Enable RLS on table
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only read their own posts
CREATE POLICY "Users can view own posts"
ON posts FOR SELECT
USING (auth.uid() = user_id);

-- Policy: Users can only insert posts for themselves
CREATE POLICY "Users can create own posts"
ON posts FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own posts
CREATE POLICY "Users can update own posts"
ON posts FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can delete their own posts
CREATE POLICY "Users can delete own posts"
ON posts FOR DELETE
USING (auth.uid() = user_id);

-- Policy: Public read access
CREATE POLICY "Anyone can view published posts"
ON posts FOR SELECT
USING (status = 'published');

-- Policy: Admin full access
CREATE POLICY "Admins have full access"
ON posts FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = auth.uid()
    AND users.role = 'admin'
  )
);
```

### Organization-Based Access
```sql
-- Users can access resources in their organization
CREATE POLICY "Org member access"
ON resources FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM organization_members
    WHERE organization_members.user_id = auth.uid()
    AND organization_members.org_id = resources.org_id
  )
);

-- Role-based within organization
CREATE POLICY "Org admin can manage"
ON resources FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM organization_members
    WHERE organization_members.user_id = auth.uid()
    AND organization_members.org_id = resources.org_id
    AND organization_members.role IN ('admin', 'owner')
  )
);
```

### Testing RLS Policies
```sql
-- Test as specific user
SET request.jwt.claim.sub = 'user-uuid-here';

-- Test query
SELECT * FROM posts;  -- Should only return user's posts

-- Reset
RESET request.jwt.claim.sub;

-- Or use Supabase client with user token
const { data, error } = await supabase
  .from('posts')
  .select('*');
// Automatically filtered by RLS
```

---

## Prisma Security Patterns

### Tenant Isolation Middleware
```typescript
// lib/prisma.ts
import { PrismaClient } from '@prisma/client';

const globalForPrisma = globalThis as unknown as {
  prisma: PrismaClient | undefined;
};

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: process.env.NODE_ENV === 'development' ? ['query', 'error', 'warn'] : ['error'],
  });

if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma;

// Tenant-scoped client
export function getTenantPrisma(tenantId: string) {
  return prisma.$extends({
    query: {
      $allModels: {
        async $allOperations({ model, operation, args, query }) {
          // Add tenant filter to all queries
          if (['findMany', 'findFirst', 'findUnique', 'count', 'aggregate'].includes(operation)) {
            args.where = { ...args.where, tenantId };
          }
          
          // Add tenant to creates
          if (['create', 'createMany'].includes(operation)) {
            if (Array.isArray(args.data)) {
              args.data = args.data.map((d: any) => ({ ...d, tenantId }));
            } else {
              args.data = { ...args.data, tenantId };
            }
          }
          
          // Add tenant filter to updates/deletes
          if (['update', 'updateMany', 'delete', 'deleteMany'].includes(operation)) {
            args.where = { ...args.where, tenantId };
          }
          
          return query(args);
        },
      },
    },
  });
}
```

### Usage with Tenant Scope
```typescript
// app/api/posts/route.ts
import { getTenantPrisma } from '@/lib/prisma';
import { auth } from '@/lib/auth';

export async function GET() {
  const session = await auth();
  if (!session?.user?.tenantId) {
    return new Response('Unauthorized', { status: 401 });
  }

  // All queries automatically scoped to tenant
  const db = getTenantPrisma(session.user.tenantId);
  
  const posts = await db.post.findMany({
    // No need to add tenantId filter - middleware handles it
    orderBy: { createdAt: 'desc' },
  });

  return Response.json(posts);
}
```

### Soft Delete Extension
```typescript
// lib/prisma.ts
export const prismaWithSoftDelete = prisma.$extends({
  query: {
    $allModels: {
      async findMany({ model, operation, args, query }) {
        args.where = { ...args.where, deletedAt: null };
        return query(args);
      },
      async findFirst({ model, operation, args, query }) {
        args.where = { ...args.where, deletedAt: null };
        return query(args);
      },
      async delete({ model, operation, args, query }) {
        // Soft delete instead of hard delete
        return prisma[model as any].update({
          ...args,
          data: { deletedAt: new Date() },
        });
      },
    },
  },
});
```

---

## Parameterized Queries

### Prisma (Default Safe)
```typescript
// ✅ SAFE: Prisma uses parameterized queries
const user = await prisma.user.findFirst({
  where: {
    email: userInput, // Safe - parameterized
  },
});

// ⚠️ CAREFUL: Raw queries need template literal
const users = await prisma.$queryRaw`
  SELECT * FROM users WHERE email = ${email}
`;

// ❌ UNSAFE: String interpolation in raw query
const users = await prisma.$queryRawUnsafe(
  `SELECT * FROM users WHERE email = '${email}'` // SQL injection!
);
```

### pg Library
```typescript
import { Pool } from 'pg';

const pool = new Pool();

// ✅ SAFE: Parameterized query
const result = await pool.query(
  'SELECT * FROM users WHERE email = $1 AND status = $2',
  [email, 'active']
);

// ✅ SAFE: Named parameters with pg-format for identifiers
import format from 'pg-format';

const tableName = 'users'; // From trusted source only!
const query = format('SELECT * FROM %I WHERE id = $1', tableName);
const result = await pool.query(query, [userId]);
```

### Dynamic WHERE Clauses
```typescript
// Building dynamic queries safely
function buildQuery(filters: Record<string, unknown>) {
  const conditions: string[] = [];
  const values: unknown[] = [];
  let paramIndex = 1;

  for (const [key, value] of Object.entries(filters)) {
    // Whitelist allowed columns
    const allowedColumns = ['status', 'category', 'created_at'];
    if (!allowedColumns.includes(key)) continue;

    conditions.push(`${key} = $${paramIndex}`);
    values.push(value);
    paramIndex++;
  }

  const whereClause = conditions.length > 0
    ? `WHERE ${conditions.join(' AND ')}`
    : '';

  return {
    query: `SELECT * FROM posts ${whereClause}`,
    values,
  };
}
```

---

## Encryption at Rest

### Application-Level Encryption
```typescript
// lib/encryption.ts
import { createCipheriv, createDecipheriv, randomBytes, scrypt } from 'crypto';
import { promisify } from 'util';

const scryptAsync = promisify(scrypt);

const ALGORITHM = 'aes-256-gcm';
const ENCODING = 'base64';

// Derive key from password
async function getKey(secret: string): Promise<Buffer> {
  const salt = process.env.ENCRYPTION_SALT!;
  return scryptAsync(secret, salt, 32) as Promise<Buffer>;
}

export async function encrypt(text: string): Promise<string> {
  const key = await getKey(process.env.ENCRYPTION_KEY!);
  const iv = randomBytes(16);
  const cipher = createCipheriv(ALGORITHM, key, iv);

  let encrypted = cipher.update(text, 'utf8', ENCODING);
  encrypted += cipher.final(ENCODING);

  const authTag = cipher.getAuthTag();

  // Combine iv + authTag + encrypted
  return Buffer.concat([
    iv,
    authTag,
    Buffer.from(encrypted, ENCODING),
  ]).toString(ENCODING);
}

export async function decrypt(encryptedData: string): Promise<string> {
  const key = await getKey(process.env.ENCRYPTION_KEY!);
  const buffer = Buffer.from(encryptedData, ENCODING);

  const iv = buffer.subarray(0, 16);
  const authTag = buffer.subarray(16, 32);
  const encrypted = buffer.subarray(32);

  const decipher = createDecipheriv(ALGORITHM, key, iv);
  decipher.setAuthTag(authTag);

  let decrypted = decipher.update(encrypted);
  decrypted = Buffer.concat([decrypted, decipher.final()]);

  return decrypted.toString('utf8');
}

// Usage
const encrypted = await encrypt('sensitive data');
const decrypted = await decrypt(encrypted);
```

### Prisma Middleware for Automatic Encryption
```typescript
// lib/prisma.ts
import { encrypt, decrypt } from './encryption';

const ENCRYPTED_FIELDS = {
  User: ['ssn', 'taxId'],
  Payment: ['cardNumber', 'accountNumber'],
};

export const prismaWithEncryption = prisma.$extends({
  query: {
    $allModels: {
      async create({ model, operation, args, query }) {
        const fields = ENCRYPTED_FIELDS[model as keyof typeof ENCRYPTED_FIELDS];
        if (fields) {
          for (const field of fields) {
            if (args.data[field]) {
              args.data[field] = await encrypt(args.data[field]);
            }
          }
        }
        return query(args);
      },
    },
  },
  result: {
    user: {
      ssn: {
        needs: { ssn: true },
        compute: async (user) => user.ssn ? await decrypt(user.ssn) : null,
      },
    },
  },
});
```

### Column-Level Encryption in PostgreSQL
```sql
-- Using pgcrypto extension
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Encrypt on insert
INSERT INTO users (email, ssn_encrypted)
VALUES (
  'user@example.com',
  pgp_sym_encrypt('123-45-6789', current_setting('app.encryption_key'))
);

-- Decrypt on select
SELECT 
  email,
  pgp_sym_decrypt(ssn_encrypted::bytea, current_setting('app.encryption_key')) as ssn
FROM users;
```

---

## Secure Connection

### Connection String Security
```typescript
// ✅ CORRECT: Use SSL in production
const connectionString = process.env.NODE_ENV === 'production'
  ? `${process.env.DATABASE_URL}?sslmode=require`
  : process.env.DATABASE_URL;

// Prisma schema
// schema.prisma
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
  // SSL is configured in connection string or provider-specific
}

// pg library
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' 
    ? { rejectUnauthorized: true }
    : false,
});
```

### Connection Pooling
```typescript
// lib/db.ts
import { Pool } from 'pg';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 20, // Maximum connections
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// Graceful shutdown
process.on('SIGINT', async () => {
  await pool.end();
  process.exit(0);
});
```

---

## Database User Permissions

### Principle of Least Privilege
```sql
-- Create application user with minimal permissions
CREATE USER app_user WITH PASSWORD 'secure_password';

-- Grant only necessary permissions
GRANT CONNECT ON DATABASE myapp TO app_user;
GRANT USAGE ON SCHEMA public TO app_user;

-- Read-only on some tables
GRANT SELECT ON users, posts, comments TO app_user;

-- Full CRUD on others
GRANT SELECT, INSERT, UPDATE, DELETE ON orders, cart_items TO app_user;

-- No direct table access for sensitive data
-- Use functions instead
GRANT EXECUTE ON FUNCTION get_user_profile(uuid) TO app_user;

-- Separate user for migrations
CREATE USER migration_user WITH PASSWORD 'different_password';
GRANT ALL PRIVILEGES ON DATABASE myapp TO migration_user;
```

### Read Replica User
```sql
-- Read-only user for analytics
CREATE USER readonly_user WITH PASSWORD 'readonly_password';
GRANT CONNECT ON DATABASE myapp TO readonly_user;
GRANT USAGE ON SCHEMA public TO readonly_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly_user;

-- Automatically grant SELECT on new tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT ON TABLES TO readonly_user;
```

---

## Sensitive Data Handling

### PII Masking
```typescript
// lib/masking.ts
export function maskEmail(email: string): string {
  const [local, domain] = email.split('@');
  const maskedLocal = local[0] + '*'.repeat(local.length - 2) + local.slice(-1);
  return `${maskedLocal}@${domain}`;
}

export function maskPhone(phone: string): string {
  return phone.replace(/(\d{3})\d{4}(\d{4})/, '$1****$2');
}

export function maskSSN(ssn: string): string {
  return `***-**-${ssn.slice(-4)}`;
}

export function maskCard(cardNumber: string): string {
  return `****-****-****-${cardNumber.slice(-4)}`;
}
```

### Audit-Safe Logging
```typescript
// lib/logger.ts
const SENSITIVE_FIELDS = ['password', 'ssn', 'cardNumber', 'token', 'secret'];

function redactSensitive(obj: unknown): unknown {
  if (typeof obj !== 'object' || obj === null) return obj;

  const redacted: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(obj)) {
    if (SENSITIVE_FIELDS.some(f => key.toLowerCase().includes(f))) {
      redacted[key] = '[REDACTED]';
    } else if (typeof value === 'object') {
      redacted[key] = redactSensitive(value);
    } else {
      redacted[key] = value;
    }
  }
  return redacted;
}

export function logSafe(message: string, data?: unknown) {
  console.log(message, data ? redactSensitive(data) : '');
}
```

---

## Anti-Patterns

```sql
-- ❌ NEVER: Disable RLS for convenience
ALTER TABLE posts DISABLE ROW LEVEL SECURITY;

-- ❌ NEVER: Overly permissive policy
CREATE POLICY "Everyone can do everything"
ON posts FOR ALL
USING (true);

-- ✅ CORRECT: Explicit, restrictive policies
CREATE POLICY "Users manage own posts"
ON posts FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);
```

```typescript
// ❌ NEVER: Store plaintext passwords
await prisma.user.create({
  data: { email, password: password }, // Plaintext!
});

// ✅ CORRECT: Hash passwords
import { hash } from 'bcrypt';
await prisma.user.create({
  data: { email, password: await hash(password, 12) },
});

// ❌ NEVER: Log sensitive data
console.log('User data:', user); // May contain PII

// ✅ CORRECT: Redact sensitive fields
console.log('User data:', redactSensitive(user));

// ❌ NEVER: Use admin credentials in app
DATABASE_URL=postgres://admin:adminpass@db/app

// ✅ CORRECT: Use least-privilege app user
DATABASE_URL=postgres://app_readonly:apppass@db/app
```

---

## Quick Reference

### RLS Policy Types
| Operation | USING | WITH CHECK |
|-----------|-------|------------|
| SELECT | ✓ | - |
| INSERT | - | ✓ |
| UPDATE | ✓ | ✓ |
| DELETE | ✓ | - |

### Encryption Types
| Type | Use Case |
|------|----------|
| At-rest (disk) | Database-level encryption |
| Column-level | Specific sensitive fields |
| Application-level | Before storing in DB |
| In-transit | SSL/TLS connections |

### Permission Levels
| Level | Production | Development |
|-------|------------|-------------|
| App user | SELECT, INSERT, UPDATE on specific tables | Same |
| Migration user | ALL (separate credentials) | Same |
| Admin | Manual access only | ALL |

### Checklist
- [ ] RLS enabled on all tables with sensitive data
- [ ] Policies follow least-privilege principle
- [ ] Application uses non-admin database user
- [ ] Passwords hashed with bcrypt (cost 12+)
- [ ] PII encrypted at rest
- [ ] SSL/TLS for database connections
- [ ] Connection pooling configured
- [ ] Sensitive data masked in logs
- [ ] Regular permission audits
