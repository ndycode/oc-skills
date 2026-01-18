# Secrets Management

> **Sources**: [HashiCorp Vault](https://www.vaultproject.io/docs), [OWASP Secrets Management](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html), [12-Factor App Config](https://12factor.net/config)
> **Auto-trigger**: Files containing `.env`, `secrets`, `vault`, `credentials`, API keys, tokens, passwords, environment variables

---

## Core Principles

1. **Never commit secrets** - Not in code, not in comments, not "temporarily"
2. **Rotate regularly** - Automated rotation reduces breach impact
3. **Least privilege** - Only grant access that's absolutely needed
4. **Audit access** - Log who accessed what, when
5. **Encrypt at rest** - Secrets storage must be encrypted

---

## Environment Variables

### Structure
```bash
# .env.example (COMMIT THIS - no real values)
# Database
DATABASE_URL=postgresql://user:password@localhost:5432/dbname

# Authentication
AUTH_SECRET=generate-with-openssl-rand-base64-32
NEXTAUTH_URL=http://localhost:3000

# External Services
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...

# Cloud
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_REGION=us-east-1
```

```bash
# .env.local (NEVER COMMIT - real values)
DATABASE_URL=postgresql://admin:realpassword@prod-db.example.com:5432/myapp
AUTH_SECRET=K8s2Jf9Lm3Np6Qr1Tv4Wx7Za0Bc5De8Fg
```

### .gitignore
```gitignore
# Environment files with secrets
.env
.env.local
.env.*.local
.env.development
.env.production

# Keep example file
!.env.example

# Cloud credentials
.aws/
.gcp/
credentials.json
service-account.json

# SSH keys
*.pem
*.key
id_rsa*
```

### Validation on Startup
```typescript
// lib/env.ts
import { z } from 'zod';

const envSchema = z.object({
  // Database
  DATABASE_URL: z.string().url(),

  // Auth
  AUTH_SECRET: z.string().min(32),
  NEXTAUTH_URL: z.string().url(),

  // Stripe
  STRIPE_SECRET_KEY: z.string().startsWith('sk_'),
  STRIPE_WEBHOOK_SECRET: z.string().startsWith('whsec_'),

  // Optional with defaults
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  LOG_LEVEL: z.enum(['debug', 'info', 'warn', 'error']).default('info'),
});

// Validate at startup
function validateEnv() {
  const result = envSchema.safeParse(process.env);

  if (!result.success) {
    console.error('❌ Invalid environment variables:');
    console.error(result.error.flatten().fieldErrors);
    process.exit(1);
  }

  return result.data;
}

export const env = validateEnv();

// Type-safe access
// env.DATABASE_URL - string
// env.STRIPE_SECRET_KEY - string starting with 'sk_'
```

### Next.js Specific
```typescript
// next.config.js
/** @type {import('next').NextConfig} */
const nextConfig = {
  // Only expose NEXT_PUBLIC_ vars to client
  // Server-only vars stay on server
  env: {
    // DON'T DO THIS - exposes to client!
    // STRIPE_SECRET_KEY: process.env.STRIPE_SECRET_KEY,
  },
};

module.exports = nextConfig;
```

---

## Secret Generation

### Strong Secrets
```bash
# Generate 32-byte random string (base64)
openssl rand -base64 32

# Generate hex string
openssl rand -hex 32

# Generate URL-safe string
openssl rand -base64 32 | tr '+/' '-_' | tr -d '='

# Generate UUID
uuidgen

# Node.js
node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"
```

### In Code
```typescript
import { randomBytes, randomUUID } from 'crypto';

// API keys
function generateApiKey(): string {
  const prefix = 'sk_live_';
  const random = randomBytes(24).toString('base64url');
  return `${prefix}${random}`;
}

// Tokens
function generateToken(): string {
  return randomBytes(32).toString('hex');
}

// Session IDs
function generateSessionId(): string {
  return randomUUID();
}
```

---

## HashiCorp Vault Integration

### Setup
```bash
npm install node-vault
```

### Client Configuration
```typescript
// lib/vault.ts
import vault from 'node-vault';

const vaultClient = vault({
  apiVersion: 'v1',
  endpoint: process.env.VAULT_ADDR,
  token: process.env.VAULT_TOKEN,
});

// For Kubernetes
async function getVaultClientK8s() {
  const client = vault({
    apiVersion: 'v1',
    endpoint: process.env.VAULT_ADDR,
  });

  // Authenticate with Kubernetes service account
  const k8sToken = await fs.readFile(
    '/var/run/secrets/kubernetes.io/serviceaccount/token',
    'utf8'
  );

  const result = await client.kubernetesLogin({
    role: 'myapp',
    jwt: k8sToken,
  });

  client.token = result.auth.client_token;
  return client;
}
```

### Reading Secrets
```typescript
// lib/secrets.ts
import { vaultClient } from './vault';

interface DatabaseSecrets {
  username: string;
  password: string;
  host: string;
  port: number;
}

// Cache secrets in memory (with TTL awareness)
const secretsCache = new Map<string, { value: unknown; expiresAt: number }>();

export async function getSecret<T>(path: string, ttlMs = 300000): Promise<T> {
  const cached = secretsCache.get(path);
  if (cached && cached.expiresAt > Date.now()) {
    return cached.value as T;
  }

  try {
    const result = await vaultClient.read(`secret/data/${path}`);
    const value = result.data.data as T;

    secretsCache.set(path, {
      value,
      expiresAt: Date.now() + ttlMs,
    });

    return value;
  } catch (error) {
    console.error(`Failed to read secret at ${path}:`, error);
    throw new Error(`Secret not found: ${path}`);
  }
}

// Usage
async function getDatabaseConfig() {
  const secrets = await getSecret<DatabaseSecrets>('myapp/database');

  return {
    connectionString: `postgresql://${secrets.username}:${secrets.password}@${secrets.host}:${secrets.port}/myapp`,
  };
}
```

### Dynamic Database Credentials
```typescript
// lib/db-credentials.ts
import { vaultClient } from './vault';

interface DynamicCredentials {
  username: string;
  password: string;
  leaseId: string;
  leaseDuration: number;
}

let currentCredentials: DynamicCredentials | null = null;
let renewalTimeout: NodeJS.Timeout | null = null;

export async function getDatabaseCredentials(): Promise<DynamicCredentials> {
  if (currentCredentials) {
    return currentCredentials;
  }

  const result = await vaultClient.read('database/creds/myapp-role');

  currentCredentials = {
    username: result.data.username,
    password: result.data.password,
    leaseId: result.lease_id,
    leaseDuration: result.lease_duration,
  };

  // Schedule renewal at 75% of lease duration
  scheduleRenewal(result.lease_duration * 0.75 * 1000);

  return currentCredentials;
}

function scheduleRenewal(delayMs: number) {
  if (renewalTimeout) {
    clearTimeout(renewalTimeout);
  }

  renewalTimeout = setTimeout(async () => {
    try {
      const result = await vaultClient.write('sys/leases/renew', {
        lease_id: currentCredentials!.leaseId,
      });

      currentCredentials!.leaseDuration = result.lease_duration;
      scheduleRenewal(result.lease_duration * 0.75 * 1000);
    } catch (error) {
      console.error('Failed to renew lease, fetching new credentials');
      currentCredentials = null;
      await getDatabaseCredentials();
    }
  }, delayMs);
}
```

---

## AWS Secrets Manager

```typescript
// lib/aws-secrets.ts
import {
  SecretsManagerClient,
  GetSecretValueCommand,
} from '@aws-sdk/client-secrets-manager';

const client = new SecretsManagerClient({
  region: process.env.AWS_REGION,
});

const cache = new Map<string, { value: string; expiresAt: number }>();

export async function getAwsSecret(
  secretName: string,
  cacheTtlMs = 300000
): Promise<Record<string, unknown>> {
  const cached = cache.get(secretName);
  if (cached && cached.expiresAt > Date.now()) {
    return JSON.parse(cached.value);
  }

  const command = new GetSecretValueCommand({
    SecretId: secretName,
  });

  const response = await client.send(command);

  if (!response.SecretString) {
    throw new Error(`Secret ${secretName} has no string value`);
  }

  cache.set(secretName, {
    value: response.SecretString,
    expiresAt: Date.now() + cacheTtlMs,
  });

  return JSON.parse(response.SecretString);
}

// Usage
const dbSecrets = await getAwsSecret('prod/myapp/database');
const connectionString = `postgresql://${dbSecrets.username}:${dbSecrets.password}@${dbSecrets.host}/myapp`;
```

---

## Secret Rotation

### API Key Rotation Pattern
```typescript
// lib/api-keys.ts
import { db } from './db';
import { randomBytes } from 'crypto';

export async function rotateApiKey(userId: string): Promise<{
  newKey: string;
  oldKeyValidUntil: Date;
}> {
  const newKey = `sk_live_${randomBytes(24).toString('base64url')}`;
  const newKeyHash = await hashApiKey(newKey);

  // Grace period for old key
  const oldKeyValidUntil = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24 hours

  await db.$transaction([
    // Mark current key as expiring
    db.apiKey.updateMany({
      where: { userId, status: 'active' },
      data: {
        status: 'rotating',
        expiresAt: oldKeyValidUntil,
      },
    }),
    // Create new key
    db.apiKey.create({
      data: {
        userId,
        keyHash: newKeyHash,
        keyPrefix: newKey.slice(0, 12),
        status: 'active',
      },
    }),
  ]);

  return { newKey, oldKeyValidUntil };
}

// Cleanup job (run daily)
export async function cleanupExpiredKeys(): Promise<void> {
  await db.apiKey.deleteMany({
    where: {
      status: 'rotating',
      expiresAt: { lt: new Date() },
    },
  });
}
```

### Database Password Rotation
```typescript
// scripts/rotate-db-password.ts
import { SecretsManagerClient, RotateSecretCommand } from '@aws-sdk/client-secrets-manager';

async function rotateDbPassword(secretId: string) {
  const client = new SecretsManagerClient({ region: 'us-east-1' });

  // Trigger rotation (requires Lambda rotation function configured)
  await client.send(
    new RotateSecretCommand({
      SecretId: secretId,
      RotateImmediately: true,
    })
  );

  console.log(`Rotation initiated for ${secretId}`);
}
```

---

## CI/CD Secrets

### GitHub Actions
```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production  # Uses environment secrets

    steps:
      - uses: actions/checkout@v4

      - name: Deploy
        env:
          # From repository secrets
          DATABASE_URL: ${{ secrets.DATABASE_URL }}
          # From environment secrets
          STRIPE_SECRET_KEY: ${{ secrets.STRIPE_SECRET_KEY }}
        run: |
          npm run deploy
```

### Vercel Secrets
```bash
# Add secret
vercel env add DATABASE_URL production

# Pull secrets locally
vercel env pull .env.local

# List secrets
vercel env ls production
```

### Railway Secrets
```bash
# Add via CLI
railway variables set DATABASE_URL="postgresql://..."

# Or use dashboard for sensitive values
railway open
```

---

## Secret Detection

### Pre-commit Hook
```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']
```

### Gitleaks
```yaml
# .gitleaks.toml
[allowlist]
description = "Allowlist for false positives"
paths = [
  '''\.env\.example$''',
  '''package-lock\.json$''',
]

[[rules]]
id = "generic-api-key"
description = "Generic API Key"
regex = '''(?i)(api[_-]?key|apikey)['":\s]*[=:]\s*['"]?([a-zA-Z0-9_\-]{20,})['"]?'''

[[rules]]
id = "aws-access-key"
description = "AWS Access Key"
regex = '''AKIA[0-9A-Z]{16}'''
```

```bash
# Scan before commit
gitleaks detect --source . --verbose

# In CI
gitleaks detect --source . --baseline-path .gitleaks-baseline.json
```

---

## Anti-Patterns

```typescript
// ❌ NEVER: Hardcode secrets
const STRIPE_KEY = 'sk_live_abc123...';

// ✅ CORRECT: Use environment variables
const STRIPE_KEY = process.env.STRIPE_SECRET_KEY;

// ❌ NEVER: Log secrets
console.log('Connecting with:', connectionString);

// ✅ CORRECT: Redact in logs
console.log('Connecting to:', redactConnectionString(connectionString));

// ❌ NEVER: Expose in client bundle
// next.config.js
env: {
  STRIPE_SECRET_KEY: process.env.STRIPE_SECRET_KEY  // Exposed!
}

// ✅ CORRECT: Only NEXT_PUBLIC_ for client
// STRIPE_SECRET_KEY stays server-only automatically

// ❌ NEVER: Store in localStorage/cookies
localStorage.setItem('apiKey', secretKey);

// ✅ CORRECT: Keep on server, use sessions
// Server handles API calls with secret

// ❌ NEVER: Commit .env files
git add .env  // NO!

// ✅ CORRECT: Only commit example
git add .env.example

// ❌ NEVER: Use weak secrets
AUTH_SECRET=password123

// ✅ CORRECT: Use strong random values
AUTH_SECRET=$(openssl rand -base64 32)

// ❌ NEVER: Share secrets across environments
# Same DATABASE_URL for dev and prod

// ✅ CORRECT: Separate secrets per environment
# dev: DATABASE_URL=...dev-db...
# prod: DATABASE_URL=...prod-db...
```

---

## Quick Reference

### Secret Types & Rotation Frequency
| Secret Type | Rotation | Notes |
|-------------|----------|-------|
| Database passwords | 30-90 days | Automated with Vault |
| API keys | 90 days | Grace period for migration |
| JWT signing keys | 6-12 months | Support key rollover |
| Encryption keys | 1-2 years | Re-encrypt data |
| Service accounts | 90 days | Automate via cloud provider |

### Environment Variable Prefixes
| Prefix | Meaning |
|--------|---------|
| `NEXT_PUBLIC_` | Exposed to client (Next.js) |
| `VITE_` | Exposed to client (Vite) |
| No prefix | Server-only (safe) |

### Tools
| Tool | Purpose |
|------|---------|
| Vault | Enterprise secrets management |
| AWS Secrets Manager | AWS native |
| GCP Secret Manager | GCP native |
| 1Password CLI | Team secrets |
| doppler | Developer-friendly secrets |
| detect-secrets | Pre-commit scanning |
| gitleaks | Git history scanning |

### Checklist
- [ ] `.env` files in `.gitignore`
- [ ] `.env.example` committed (no real values)
- [ ] Environment validation on startup
- [ ] Pre-commit secret detection
- [ ] Different secrets per environment
- [ ] Rotation schedule defined
- [ ] Audit logging for secret access
- [ ] Secrets never in logs
- [ ] Client/server separation enforced
