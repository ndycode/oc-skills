---
name: input-sanitization
description: Input sanitization, SQL/XSS prevention, and file validation
metadata:
  short-description: Input sanitization
---

# Input Sanitization & Validation

> **Sources**: [OWASP Input Validation](https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html), [DOMPurify](https://github.com/cure53/DOMPurify) (14k⭐)
> **Auto-trigger**: Files containing form handling, user input, `req.body`, `req.query`, file uploads, database queries, HTML rendering

---

## Core Principle: Defense in Depth

1. **Validate** - Reject invalid input early
2. **Sanitize** - Clean input before use
3. **Escape** - Encode output for context
4. **Parameterize** - Never concatenate queries

---

## Input Validation with Zod

### Request Validation
```typescript
// lib/validation.ts
import { z } from 'zod';

// Common patterns
export const schemas = {
  // Email with normalization
  email: z.string().email().toLowerCase().trim(),

  // Username: alphanumeric, 3-20 chars
  username: z
    .string()
    .min(3)
    .max(20)
    .regex(/^[a-zA-Z0-9_]+$/, 'Only letters, numbers, and underscores'),

  // Password: strong requirements
  password: z
    .string()
    .min(8)
    .max(128)
    .regex(/[A-Z]/, 'Must contain uppercase')
    .regex(/[a-z]/, 'Must contain lowercase')
    .regex(/[0-9]/, 'Must contain number')
    .regex(/[^A-Za-z0-9]/, 'Must contain special character'),

  // URL: must be HTTPS
  secureUrl: z
    .string()
    .url()
    .refine((url) => url.startsWith('https://'), 'Must use HTTPS'),

  // UUID
  uuid: z.string().uuid(),

  // Positive integer (for IDs)
  positiveInt: z.coerce.number().int().positive(),

  // Slug: lowercase, hyphens, alphanumeric
  slug: z
    .string()
    .min(1)
    .max(100)
    .regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/, 'Invalid slug format'),

  // Phone: E.164 format
  phone: z.string().regex(/^\+[1-9]\d{1,14}$/, 'Use E.164 format (+1234567890)'),

  // Date string
  dateString: z.string().refine((date) => !isNaN(Date.parse(date)), 'Invalid date'),
};

// API endpoint validation
export const createPostSchema = z.object({
  title: z.string().min(1).max(200).trim(),
  content: z.string().min(1).max(50000),
  slug: schemas.slug,
  tags: z.array(z.string().max(50)).max(10).optional(),
  publishAt: schemas.dateString.optional(),
});

export type CreatePostInput = z.infer<typeof createPostSchema>;
```

### Route Handler Validation
```typescript
// app/api/posts/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { createPostSchema } from '@/lib/validation';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const result = createPostSchema.safeParse(body);

    if (!result.success) {
      return NextResponse.json(
        {
          error: 'Validation failed',
          details: result.error.flatten().fieldErrors,
        },
        { status: 400 }
      );
    }

    const validatedData = result.data;
    // Safe to use validatedData

    return NextResponse.json({ success: true });
  } catch {
    return NextResponse.json({ error: 'Invalid request' }, { status: 400 });
  }
}
```

---

## SQL Injection Prevention

### Always Use Parameterized Queries
```typescript
// ❌ VULNERABLE: String concatenation
const query = `SELECT * FROM users WHERE id = '${userId}'`;
// userId = "'; DROP TABLE users; --" → SQL injection!

// ✅ SAFE: Parameterized query (Prisma)
const user = await prisma.user.findUnique({
  where: { id: userId },
});

// ✅ SAFE: Parameterized query (raw SQL)
const users = await prisma.$queryRaw`
  SELECT * FROM users WHERE id = ${userId}
`;

// ✅ SAFE: pg library
import { Pool } from 'pg';
const pool = new Pool();

const result = await pool.query(
  'SELECT * FROM users WHERE email = $1 AND status = $2',
  [email, 'active']
);

// ❌ VULNERABLE: Dynamic column names
const orderBy = req.query.sort; // Could be "id; DROP TABLE users"
const query = `SELECT * FROM posts ORDER BY ${orderBy}`;

// ✅ SAFE: Whitelist allowed values
const ALLOWED_SORT_COLUMNS = ['id', 'created_at', 'title'] as const;
const orderBy = ALLOWED_SORT_COLUMNS.includes(req.query.sort as any)
  ? req.query.sort
  : 'created_at';
```

### Dynamic Queries Safely
```typescript
// Building dynamic WHERE clauses safely
import { Prisma } from '@prisma/client';

function buildUserQuery(filters: {
  email?: string;
  role?: string;
  createdAfter?: Date;
}) {
  const conditions: Prisma.UserWhereInput[] = [];

  if (filters.email) {
    conditions.push({ email: { contains: filters.email } });
  }
  if (filters.role) {
    conditions.push({ role: filters.role });
  }
  if (filters.createdAfter) {
    conditions.push({ createdAt: { gte: filters.createdAfter } });
  }

  return prisma.user.findMany({
    where: conditions.length > 0 ? { AND: conditions } : undefined,
  });
}
```

---

## NoSQL Injection Prevention

```typescript
// ❌ VULNERABLE: MongoDB query injection
const user = await collection.findOne({
  username: req.body.username,
  password: req.body.password,
});
// If password = { $ne: "" } → bypasses auth!

// ✅ SAFE: Validate and type-check input
const loginSchema = z.object({
  username: z.string().min(1).max(50),
  password: z.string().min(1).max(128),
});

const { username, password } = loginSchema.parse(req.body);

// Now we know these are strings, not objects
const user = await collection.findOne({
  username,
  password: await hashPassword(password),
});

// ✅ SAFE: Sanitize MongoDB operators
function sanitizeMongoQuery(input: unknown): unknown {
  if (typeof input === 'object' && input !== null) {
    const sanitized: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(input)) {
      // Block operator injection
      if (key.startsWith('$')) {
        throw new Error('Invalid query operator');
      }
      sanitized[key] = sanitizeMongoQuery(value);
    }
    return sanitized;
  }
  return input;
}
```

---

## XSS Prevention

### Output Encoding
```typescript
// React automatically escapes by default
function SafeComponent({ userInput }: { userInput: string }) {
  // ✅ SAFE: React escapes this
  return <div>{userInput}</div>;

  // ❌ DANGEROUS: Bypasses React's escaping
  return <div dangerouslySetInnerHTML={{ __html: userInput }} />;
}
```

### Sanitizing HTML (When Needed)
```typescript
// lib/sanitize.ts
import DOMPurify from 'isomorphic-dompurify';

// For rich text content
export function sanitizeHtml(dirty: string): string {
  return DOMPurify.sanitize(dirty, {
    ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'a', 'p', 'br', 'ul', 'ol', 'li', 'code', 'pre'],
    ALLOWED_ATTR: ['href', 'target', 'rel'],
    ALLOW_DATA_ATTR: false,
    ADD_ATTR: ['target'], // Add target="_blank" to links
    FORCE_BODY: true,
  });
}

// For user-generated links
export function sanitizeUrl(url: string): string | null {
  try {
    const parsed = new URL(url);
    // Only allow http(s) and mailto
    if (!['http:', 'https:', 'mailto:'].includes(parsed.protocol)) {
      return null;
    }
    return parsed.href;
  } catch {
    return null;
  }
}

// Strict - strip all HTML
export function stripHtml(input: string): string {
  return DOMPurify.sanitize(input, { ALLOWED_TAGS: [] });
}
```

### Using Sanitized HTML
```typescript
'use client';

import { sanitizeHtml } from '@/lib/sanitize';

function RichTextContent({ html }: { html: string }) {
  const cleanHtml = sanitizeHtml(html);

  return (
    <div
      className="prose"
      dangerouslySetInnerHTML={{ __html: cleanHtml }}
    />
  );
}
```

### Content Security Policy
```typescript
// next.config.js
const cspHeader = `
  default-src 'self';
  script-src 'self' 'unsafe-eval' 'unsafe-inline';
  style-src 'self' 'unsafe-inline';
  img-src 'self' blob: data: https:;
  font-src 'self';
  object-src 'none';
  base-uri 'self';
  form-action 'self';
  frame-ancestors 'none';
  upgrade-insecure-requests;
`;

module.exports = {
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [
          {
            key: 'Content-Security-Policy',
            value: cspHeader.replace(/\n/g, ''),
          },
        ],
      },
    ];
  },
};
```

---

## File Upload Validation

### Server-Side Validation
```typescript
// app/api/upload/route.ts
import { NextRequest, NextResponse } from 'next/server';

const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];
const MAX_SIZE = 5 * 1024 * 1024; // 5MB

// File signature magic bytes
const FILE_SIGNATURES: Record<string, number[][]> = {
  'image/jpeg': [[0xff, 0xd8, 0xff]],
  'image/png': [[0x89, 0x50, 0x4e, 0x47]],
  'image/gif': [[0x47, 0x49, 0x46, 0x38]],
  'image/webp': [[0x52, 0x49, 0x46, 0x46]], // RIFF header
};

function validateFileSignature(buffer: ArrayBuffer, mimeType: string): boolean {
  const signatures = FILE_SIGNATURES[mimeType];
  if (!signatures) return false;

  const bytes = new Uint8Array(buffer);
  return signatures.some((sig) =>
    sig.every((byte, index) => bytes[index] === byte)
  );
}

export async function POST(req: NextRequest) {
  try {
    const formData = await req.formData();
    const file = formData.get('file') as File | null;

    if (!file) {
      return NextResponse.json({ error: 'No file provided' }, { status: 400 });
    }

    // Check MIME type (from header - can be spoofed)
    if (!ALLOWED_TYPES.includes(file.type)) {
      return NextResponse.json({ error: 'Invalid file type' }, { status: 400 });
    }

    // Check file size
    if (file.size > MAX_SIZE) {
      return NextResponse.json({ error: 'File too large' }, { status: 400 });
    }

    // Validate actual file content (magic bytes)
    const buffer = await file.arrayBuffer();
    if (!validateFileSignature(buffer, file.type)) {
      return NextResponse.json(
        { error: 'File content does not match type' },
        { status: 400 }
      );
    }

    // Generate safe filename
    const ext = file.name.split('.').pop()?.toLowerCase() || '';
    const safeExt = ['jpg', 'jpeg', 'png', 'webp', 'gif'].includes(ext) ? ext : 'bin';
    const safeFilename = `${crypto.randomUUID()}.${safeExt}`;

    // Process file (e.g., upload to S3)
    // ...

    return NextResponse.json({ filename: safeFilename });
  } catch (error) {
    console.error('Upload error:', error);
    return NextResponse.json({ error: 'Upload failed' }, { status: 500 });
  }
}
```

### Image Processing (Prevent Image-Based Attacks)
```typescript
// lib/image-processing.ts
import sharp from 'sharp';

export async function processUploadedImage(
  buffer: Buffer,
  options: {
    maxWidth?: number;
    maxHeight?: number;
    format?: 'jpeg' | 'png' | 'webp';
    quality?: number;
  } = {}
): Promise<Buffer> {
  const { maxWidth = 2000, maxHeight = 2000, format = 'webp', quality = 80 } = options;

  // Re-encoding strips malicious metadata and code
  const processed = await sharp(buffer)
    .resize(maxWidth, maxHeight, {
      fit: 'inside',
      withoutEnlargement: true,
    })
    .rotate() // Auto-rotate based on EXIF
    .removeAlpha() // Remove alpha channel (prevents some attacks)
    .toFormat(format, { quality })
    .toBuffer();

  return processed;
}
```

---

## Path Traversal Prevention

```typescript
import path from 'path';

// ❌ VULNERABLE
function getFile(filename: string) {
  return fs.readFile(`./uploads/${filename}`);
  // filename = "../../../etc/passwd" → reads system files!
}

// ✅ SAFE: Validate and normalize path
function getFileSafe(filename: string): string | null {
  // Only allow alphanumeric, hyphen, underscore, dot
  if (!/^[a-zA-Z0-9_\-\.]+$/.test(filename)) {
    return null;
  }

  // Resolve to absolute and check it's within allowed directory
  const uploadsDir = path.resolve('./uploads');
  const filePath = path.resolve(uploadsDir, filename);

  // Ensure resolved path is within uploads directory
  if (!filePath.startsWith(uploadsDir + path.sep)) {
    return null;
  }

  return filePath;
}

// ✅ SAFE: Use UUIDs instead of user-provided names
function getFileById(fileId: string) {
  // Validate UUID format
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(fileId)) {
    throw new Error('Invalid file ID');
  }

  return fs.readFile(`./uploads/${fileId}`);
}
```

---

## Command Injection Prevention

```typescript
import { execFile } from 'child_process';
import { promisify } from 'util';

const execFileAsync = promisify(execFile);

// ❌ VULNERABLE
import { exec } from 'child_process';
function processFile(filename: string) {
  exec(`convert ${filename} output.jpg`);
  // filename = "image.jpg; rm -rf /" → disaster!
}

// ✅ SAFE: Use execFile with argument array
async function processFileSafe(filename: string): Promise<void> {
  // Validate filename first
  if (!/^[a-zA-Z0-9_\-\.]+$/.test(filename)) {
    throw new Error('Invalid filename');
  }

  // execFile doesn't use shell, args are passed directly
  await execFileAsync('convert', [filename, 'output.jpg'], {
    cwd: '/app/uploads',
    timeout: 30000,
  });
}

// ✅ SAFER: Use libraries instead of shell commands
import sharp from 'sharp';

async function processImageWithLibrary(inputPath: string): Promise<Buffer> {
  return sharp(inputPath).jpeg().toBuffer();
}
```

---

## Anti-Patterns

```typescript
// ❌ NEVER: Trust Content-Type header alone
if (file.type === 'image/jpeg') { /* upload */ }
// User can set any Content-Type they want!

// ✅ CORRECT: Validate magic bytes
const isValidJpeg = buffer[0] === 0xff && buffer[1] === 0xd8;

// ❌ NEVER: Use eval with user input
eval(userCode);
new Function(userCode);

// ❌ NEVER: Concatenate SQL
const query = `SELECT * FROM users WHERE name = '${name}'`;

// ✅ CORRECT: Parameterized query
const query = 'SELECT * FROM users WHERE name = $1';

// ❌ NEVER: Trust client-side validation alone
// Client validation is for UX, server validation is for security

// ❌ NEVER: Render user HTML without sanitization
<div dangerouslySetInnerHTML={{ __html: userContent }} />

// ✅ CORRECT: Sanitize first
<div dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(userContent) }} />

// ❌ NEVER: Use user input in redirects without validation
res.redirect(req.query.returnUrl);
// returnUrl = "https://evil.com" → open redirect!

// ✅ CORRECT: Validate redirect URLs
const allowedHosts = ['myapp.com', 'www.myapp.com'];
const url = new URL(req.query.returnUrl, 'https://myapp.com');
if (!allowedHosts.includes(url.hostname)) {
  return res.redirect('/');
}
res.redirect(url.pathname);
```

---

## Quick Reference

### Input Validation Checklist
| Input Type | Validation |
|------------|------------|
| Email | Format, lowercase, trim |
| Username | Length, charset (alphanumeric) |
| Password | Length, complexity |
| URL | Protocol whitelist (https) |
| File | Type, size, magic bytes |
| Number | Type, range, integer vs float |
| Date | Format, range |
| Free text | Length limit, sanitize |

### Common Attack Patterns
| Attack | Prevention |
|--------|------------|
| SQL Injection | Parameterized queries |
| NoSQL Injection | Input validation, type checking |
| XSS | Output encoding, CSP, DOMPurify |
| Path Traversal | Path validation, UUIDs |
| Command Injection | execFile, avoid shell |
| File Upload | Magic bytes, re-encoding |
| Open Redirect | URL whitelist |

### Validation Libraries
| Library | Purpose |
|---------|---------|
| Zod | Schema validation |
| DOMPurify | HTML sanitization |
| validator.js | String validation |
| sharp | Image re-encoding |

### Checklist
- [ ] All user input validated with Zod schemas
- [ ] SQL/NoSQL queries parameterized
- [ ] HTML sanitized before rendering
- [ ] File uploads validated (type, size, magic bytes)
- [ ] URLs validated before redirect
- [ ] Paths validated against traversal
- [ ] CSP headers configured
- [ ] Rate limiting on inputs
