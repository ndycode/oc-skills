---
name: headers-cors-csp
description: HTTP security headers, CORS, and CSP configuration
metadata:
  short-description: Security headers
---

# HTTP Security Headers

> **Sources**: [OWASP Secure Headers](https://owasp.org/www-project-secure-headers/), [Helmet.js](https://helmetjs.github.io/), [MDN HTTP Headers](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers)
> **Auto-trigger**: Files containing security headers, CSP, CORS, helmet, middleware configuration, `next.config.js` headers

---

## Next.js Security Headers

### next.config.js
```javascript
// next.config.js
/** @type {import('next').NextConfig} */

const securityHeaders = [
  // Prevent clickjacking
  {
    key: 'X-Frame-Options',
    value: 'DENY',
  },
  // Prevent MIME type sniffing
  {
    key: 'X-Content-Type-Options',
    value: 'nosniff',
  },
  // Enable XSS filter (legacy browsers)
  {
    key: 'X-XSS-Protection',
    value: '1; mode=block',
  },
  // Control referrer information
  {
    key: 'Referrer-Policy',
    value: 'strict-origin-when-cross-origin',
  },
  // DNS prefetch control
  {
    key: 'X-DNS-Prefetch-Control',
    value: 'on',
  },
  // Disable browser features
  {
    key: 'Permissions-Policy',
    value: 'camera=(), microphone=(), geolocation=(), interest-cohort=()',
  },
  // Strict Transport Security (HTTPS only)
  {
    key: 'Strict-Transport-Security',
    value: 'max-age=63072000; includeSubDomains; preload',
  },
];

const nextConfig = {
  async headers() {
    return [
      {
        source: '/:path*',
        headers: securityHeaders,
      },
    ];
  },
};

module.exports = nextConfig;
```

---

## Content Security Policy (CSP)

### Basic CSP
```javascript
// next.config.js
const ContentSecurityPolicy = `
  default-src 'self';
  script-src 'self' 'unsafe-eval' 'unsafe-inline';
  style-src 'self' 'unsafe-inline';
  img-src 'self' blob: data: https:;
  font-src 'self' https://fonts.gstatic.com;
  connect-src 'self' https://api.example.com;
  frame-ancestors 'none';
  base-uri 'self';
  form-action 'self';
  upgrade-insecure-requests;
`;

const securityHeaders = [
  {
    key: 'Content-Security-Policy',
    value: ContentSecurityPolicy.replace(/\s{2,}/g, ' ').trim(),
  },
  // ... other headers
];
```

### Strict CSP with Nonces
```typescript
// middleware.ts
import { NextRequest, NextResponse } from 'next/server';
import { randomBytes } from 'crypto';

export function middleware(request: NextRequest) {
  const nonce = randomBytes(16).toString('base64');
  
  const cspHeader = `
    default-src 'self';
    script-src 'self' 'nonce-${nonce}' 'strict-dynamic';
    style-src 'self' 'nonce-${nonce}';
    img-src 'self' blob: data: https:;
    font-src 'self';
    connect-src 'self' https://api.example.com;
    frame-ancestors 'none';
    base-uri 'self';
    form-action 'self';
    upgrade-insecure-requests;
  `;

  const response = NextResponse.next();
  
  response.headers.set(
    'Content-Security-Policy',
    cspHeader.replace(/\s{2,}/g, ' ').trim()
  );
  
  // Pass nonce to client
  response.headers.set('X-Nonce', nonce);

  return response;
}
```

```typescript
// app/layout.tsx
import { headers } from 'next/headers';
import Script from 'next/script';

export default function RootLayout({ children }: { children: React.ReactNode }) {
  const nonce = headers().get('X-Nonce') ?? '';

  return (
    <html lang="en">
      <head>
        <Script
          src="https://analytics.example.com/script.js"
          nonce={nonce}
          strategy="afterInteractive"
        />
      </head>
      <body>{children}</body>
    </html>
  );
}
```

### CSP Report-Only Mode
```javascript
// Test CSP without blocking
{
  key: 'Content-Security-Policy-Report-Only',
  value: `${cspPolicy}; report-uri /api/csp-report`,
}
```

```typescript
// app/api/csp-report/route.ts
import { NextRequest, NextResponse } from 'next/server';

export async function POST(req: NextRequest) {
  const report = await req.json();
  
  console.log('CSP Violation:', {
    document: report['csp-report']['document-uri'],
    violated: report['csp-report']['violated-directive'],
    blocked: report['csp-report']['blocked-uri'],
    source: report['csp-report']['source-file'],
  });

  return NextResponse.json({ received: true });
}
```

---

## CORS Configuration

### Next.js API Routes
```typescript
// app/api/[...]/route.ts
import { NextRequest, NextResponse } from 'next/server';

const ALLOWED_ORIGINS = [
  'https://myapp.com',
  'https://www.myapp.com',
  process.env.NODE_ENV === 'development' ? 'http://localhost:3000' : null,
].filter(Boolean) as string[];

export async function GET(req: NextRequest) {
  const origin = req.headers.get('origin');
  
  const response = NextResponse.json({ data: 'example' });
  
  // Set CORS headers
  if (origin && ALLOWED_ORIGINS.includes(origin)) {
    response.headers.set('Access-Control-Allow-Origin', origin);
    response.headers.set('Access-Control-Allow-Credentials', 'true');
  }
  
  return response;
}

export async function OPTIONS(req: NextRequest) {
  const origin = req.headers.get('origin');
  
  const response = new NextResponse(null, { status: 204 });
  
  if (origin && ALLOWED_ORIGINS.includes(origin)) {
    response.headers.set('Access-Control-Allow-Origin', origin);
    response.headers.set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    response.headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    response.headers.set('Access-Control-Max-Age', '86400'); // 24 hours
    response.headers.set('Access-Control-Allow-Credentials', 'true');
  }
  
  return response;
}
```

### CORS Middleware
```typescript
// middleware.ts
import { NextRequest, NextResponse } from 'next/server';

const ALLOWED_ORIGINS = ['https://myapp.com', 'https://www.myapp.com'];

export function middleware(req: NextRequest) {
  const origin = req.headers.get('origin');
  const isApiRoute = req.nextUrl.pathname.startsWith('/api/');

  // Handle preflight
  if (req.method === 'OPTIONS' && isApiRoute) {
    const response = new NextResponse(null, { status: 204 });
    
    if (origin && ALLOWED_ORIGINS.includes(origin)) {
      response.headers.set('Access-Control-Allow-Origin', origin);
      response.headers.set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE');
      response.headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
      response.headers.set('Access-Control-Max-Age', '86400');
    }
    
    return response;
  }

  const response = NextResponse.next();

  // Add CORS headers to API responses
  if (isApiRoute && origin && ALLOWED_ORIGINS.includes(origin)) {
    response.headers.set('Access-Control-Allow-Origin', origin);
    response.headers.set('Access-Control-Allow-Credentials', 'true');
  }

  return response;
}

export const config = {
  matcher: '/api/:path*',
};
```

---

## Express/Node.js with Helmet

### Setup
```bash
npm install helmet cors
```

### Configuration
```typescript
// server.ts
import express from 'express';
import helmet from 'helmet';
import cors from 'cors';

const app = express();

// Helmet with custom options
app.use(
  helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        scriptSrc: ["'self'", "'unsafe-inline'"],
        styleSrc: ["'self'", "'unsafe-inline'", 'https://fonts.googleapis.com'],
        fontSrc: ["'self'", 'https://fonts.gstatic.com'],
        imgSrc: ["'self'", 'data:', 'https:'],
        connectSrc: ["'self'", 'https://api.example.com'],
        frameAncestors: ["'none'"],
        upgradeInsecureRequests: [],
      },
    },
    crossOriginEmbedderPolicy: false, // May need to disable for some use cases
    hsts: {
      maxAge: 63072000, // 2 years
      includeSubDomains: true,
      preload: true,
    },
  })
);

// CORS
app.use(
  cors({
    origin: (origin, callback) => {
      const allowedOrigins = ['https://myapp.com', 'https://www.myapp.com'];
      if (!origin || allowedOrigins.includes(origin)) {
        callback(null, true);
      } else {
        callback(new Error('Not allowed by CORS'));
      }
    },
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    maxAge: 86400,
  })
);

app.listen(3000);
```

---

## Permissions Policy

### Comprehensive Configuration
```javascript
// Disable all sensitive browser features
const permissionsPolicy = [
  'accelerometer=()',
  'autoplay=()',
  'camera=()',
  'cross-origin-isolated=()',
  'display-capture=()',
  'encrypted-media=()',
  'fullscreen=(self)',
  'geolocation=()',
  'gyroscope=()',
  'keyboard-map=()',
  'magnetometer=()',
  'microphone=()',
  'midi=()',
  'payment=()',
  'picture-in-picture=()',
  'publickey-credentials-get=()',
  'screen-wake-lock=()',
  'sync-xhr=()',
  'usb=()',
  'xr-spatial-tracking=()',
  'interest-cohort=()', // Disable FLoC
].join(', ');

// In headers config
{
  key: 'Permissions-Policy',
  value: permissionsPolicy,
}
```

---

## Cookie Security

### Secure Cookie Settings
```typescript
// lib/cookies.ts
import { cookies } from 'next/headers';

export function setSecureCookie(name: string, value: string) {
  cookies().set(name, value, {
    httpOnly: true,      // Prevent XSS access
    secure: true,        // HTTPS only
    sameSite: 'strict',  // CSRF protection
    maxAge: 60 * 60 * 24 * 7, // 7 days
    path: '/',
  });
}

// For auth tokens
export function setAuthCookie(token: string) {
  cookies().set('auth-token', token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax', // 'lax' for OAuth redirects
    maxAge: 60 * 60 * 24, // 24 hours
    path: '/',
  });
}

// For CSRF tokens (client-accessible)
export function setCsrfCookie(token: string) {
  cookies().set('csrf-token', token, {
    httpOnly: false, // Must be readable by JS
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict',
    maxAge: 60 * 60 * 24,
    path: '/',
  });
}
```

### Cookie Prefixes
```typescript
// __Host- prefix for strictest security
cookies().set('__Host-session', sessionId, {
  httpOnly: true,
  secure: true,
  sameSite: 'strict',
  path: '/',
  // Cannot set domain with __Host-
});

// __Secure- prefix for secure cookies
cookies().set('__Secure-token', token, {
  httpOnly: true,
  secure: true,
  sameSite: 'lax',
  path: '/',
  domain: '.example.com',
});
```

---

## Security Headers Testing

### Manual Check
```bash
# Check headers
curl -I https://myapp.com

# Check specific header
curl -s -D - https://myapp.com -o /dev/null | grep -i "content-security-policy"
```

### Automated Testing
```typescript
// tests/security-headers.test.ts
import { describe, it, expect } from 'vitest';

const BASE_URL = 'http://localhost:3000';

describe('Security Headers', () => {
  it('should have X-Frame-Options', async () => {
    const response = await fetch(BASE_URL);
    expect(response.headers.get('x-frame-options')).toBe('DENY');
  });

  it('should have X-Content-Type-Options', async () => {
    const response = await fetch(BASE_URL);
    expect(response.headers.get('x-content-type-options')).toBe('nosniff');
  });

  it('should have Strict-Transport-Security', async () => {
    const response = await fetch(BASE_URL);
    const hsts = response.headers.get('strict-transport-security');
    expect(hsts).toContain('max-age=');
    expect(hsts).toContain('includeSubDomains');
  });

  it('should have Content-Security-Policy', async () => {
    const response = await fetch(BASE_URL);
    const csp = response.headers.get('content-security-policy');
    expect(csp).toContain("default-src 'self'");
    expect(csp).toContain("frame-ancestors 'none'");
  });

  it('should have Referrer-Policy', async () => {
    const response = await fetch(BASE_URL);
    expect(response.headers.get('referrer-policy')).toBe('strict-origin-when-cross-origin');
  });

  it('should not expose server info', async () => {
    const response = await fetch(BASE_URL);
    expect(response.headers.get('x-powered-by')).toBeNull();
    expect(response.headers.get('server')).toBeNull();
  });
});
```

---

## Anti-Patterns

```javascript
// ❌ NEVER: Wildcard CORS
{
  key: 'Access-Control-Allow-Origin',
  value: '*',  // Anyone can access!
}

// ✅ CORRECT: Specific origins
const origin = req.headers.get('origin');
if (ALLOWED_ORIGINS.includes(origin)) {
  response.headers.set('Access-Control-Allow-Origin', origin);
}

// ❌ NEVER: Disable CSP entirely
{
  key: 'Content-Security-Policy',
  value: "default-src *; script-src * 'unsafe-inline' 'unsafe-eval'",
}

// ✅ CORRECT: Restrictive CSP
{
  key: 'Content-Security-Policy',
  value: "default-src 'self'; script-src 'self'",
}

// ❌ NEVER: X-Frame-Options SAMEORIGIN for public sites
// Allows embedding from same origin - usually not needed

// ✅ CORRECT: DENY unless embedding is required
{
  key: 'X-Frame-Options',
  value: 'DENY',
}

// ❌ NEVER: Skip HSTS
// Users can be downgraded to HTTP

// ✅ CORRECT: Enable HSTS with preload
{
  key: 'Strict-Transport-Security',
  value: 'max-age=63072000; includeSubDomains; preload',
}

// ❌ NEVER: Cookies without security flags
cookies().set('session', token);  // Not secure!

// ✅ CORRECT: All security flags
cookies().set('session', token, {
  httpOnly: true,
  secure: true,
  sameSite: 'strict',
});
```

---

## Quick Reference

### Essential Headers
| Header | Value | Purpose |
|--------|-------|---------|
| `X-Frame-Options` | `DENY` | Prevent clickjacking |
| `X-Content-Type-Options` | `nosniff` | Prevent MIME sniffing |
| `Strict-Transport-Security` | `max-age=63072000; includeSubDomains` | Force HTTPS |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | Control referrer |
| `Content-Security-Policy` | (see examples) | Prevent XSS |
| `Permissions-Policy` | `camera=(), microphone=()` | Disable features |

### CSP Directives
| Directive | Purpose |
|-----------|---------|
| `default-src` | Fallback for other directives |
| `script-src` | JavaScript sources |
| `style-src` | CSS sources |
| `img-src` | Image sources |
| `connect-src` | XHR, fetch, WebSocket |
| `frame-ancestors` | Who can embed this page |
| `base-uri` | Allowed `<base>` values |
| `form-action` | Form submission targets |

### Cookie Attributes
| Attribute | Purpose |
|-----------|---------|
| `HttpOnly` | No JavaScript access |
| `Secure` | HTTPS only |
| `SameSite=Strict` | No cross-site requests |
| `SameSite=Lax` | Cross-site for navigation |
| `__Host-` prefix | Strictest security |

### Checklist
- [ ] X-Frame-Options: DENY
- [ ] X-Content-Type-Options: nosniff
- [ ] Strict-Transport-Security configured
- [ ] Content-Security-Policy (report-only first)
- [ ] Referrer-Policy set
- [ ] Permissions-Policy restricts features
- [ ] CORS properly configured
- [ ] Cookies have security attributes
- [ ] Server info headers removed
- [ ] Security headers tested
