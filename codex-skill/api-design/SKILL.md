---
name: api-design
description: REST and GraphQL API design following industry guidelines
metadata:
  short-description: API design guidelines
---

# API Design Best Practices

> **Sources**: 
> - [Microsoft REST API Guidelines](https://github.com/microsoft/api-guidelines) (23k+ stars)
> - [Google Cloud API Design Guide](https://cloud.google.com/apis/design)
> - [Zalando RESTful API Guidelines](https://github.com/zalando/restful-api-guidelines) (3k+ stars)
> 
> **Auto-trigger**: API routes, `route.ts` files, Express/Fastify endpoints

---

## 1. Resource Naming

### 1.1 Use Nouns, Not Verbs

```
# GOOD - Resources are nouns
GET    /users
GET    /users/{id}
POST   /users
PUT    /users/{id}
DELETE /users/{id}

# BAD - Verbs in URL
GET    /getUsers
POST   /createUser
POST   /deleteUser
```

### 1.2 Use Plural Nouns

```
# GOOD
GET /users
GET /users/123
GET /users/123/orders

# BAD
GET /user
GET /user/123
```

### 1.3 Use Kebab-Case for URLs

```
# GOOD
GET /user-profiles
GET /order-items

# BAD
GET /userProfiles
GET /user_profiles
GET /UserProfiles
```

### 1.4 Use camelCase for JSON Properties

```json
// GOOD
{
  "userId": "123",
  "firstName": "John",
  "createdAt": "2024-01-15T10:00:00Z"
}

// BAD
{
  "user_id": "123",
  "first-name": "John",
  "created-at": "2024-01-15T10:00:00Z"
}
```

### 1.5 Hierarchical Resources

```
# Parent-child relationships
GET /users/{userId}/orders
GET /users/{userId}/orders/{orderId}
POST /users/{userId}/orders

# Actions on resources (use verbs for actions only)
POST /orders/{orderId}/cancel
POST /users/{userId}/verify-email
```

---

## 2. HTTP Methods

### 2.1 Standard Methods

| Method | Purpose | Idempotent | Safe | Request Body | Response Body |
|--------|---------|------------|------|--------------|---------------|
| GET | Read | Yes | Yes | No | Yes |
| POST | Create | No | No | Yes | Yes |
| PUT | Full update | Yes | No | Yes | Yes |
| PATCH | Partial update | No* | No | Yes | Yes |
| DELETE | Remove | Yes | No | No | Optional |

### 2.2 Implementation Examples

```typescript
// GET - Retrieve resource
app.get('/api/users/:id', async (req, res) => {
  const user = await db.user.findUnique({ where: { id: req.params.id } });
  if (!user) return res.status(404).json({ error: 'User not found' });
  res.json(user);
});

// POST - Create resource
app.post('/api/users', async (req, res) => {
  const user = await db.user.create({ data: req.body });
  res.status(201).json(user);
  // Location header for new resource
  res.setHeader('Location', `/api/users/${user.id}`);
});

// PUT - Full replacement
app.put('/api/users/:id', async (req, res) => {
  const user = await db.user.update({
    where: { id: req.params.id },
    data: req.body, // Expects complete object
  });
  res.json(user);
});

// PATCH - Partial update
app.patch('/api/users/:id', async (req, res) => {
  const user = await db.user.update({
    where: { id: req.params.id },
    data: req.body, // Only provided fields
  });
  res.json(user);
});

// DELETE - Remove resource
app.delete('/api/users/:id', async (req, res) => {
  await db.user.delete({ where: { id: req.params.id } });
  res.status(204).send();
});
```

---

## 3. HTTP Status Codes

### 3.1 Success Codes

| Code | Meaning | When to Use |
|------|---------|-------------|
| 200 | OK | Successful GET, PUT, PATCH |
| 201 | Created | Successful POST (resource created) |
| 202 | Accepted | Request accepted for async processing |
| 204 | No Content | Successful DELETE |

### 3.2 Client Error Codes

| Code | Meaning | When to Use |
|------|---------|-------------|
| 400 | Bad Request | Invalid input, validation error |
| 401 | Unauthorized | Missing or invalid auth token |
| 403 | Forbidden | Valid auth but insufficient permissions |
| 404 | Not Found | Resource doesn't exist |
| 405 | Method Not Allowed | Wrong HTTP method |
| 409 | Conflict | Duplicate resource, state conflict |
| 422 | Unprocessable Entity | Semantic validation error |
| 429 | Too Many Requests | Rate limit exceeded |

### 3.3 Server Error Codes

| Code | Meaning | When to Use |
|------|---------|-------------|
| 500 | Internal Server Error | Unexpected server error |
| 502 | Bad Gateway | Upstream service error |
| 503 | Service Unavailable | Maintenance, overloaded |
| 504 | Gateway Timeout | Upstream timeout |

---

## 4. Error Handling

### 4.1 RFC 7807 Problem Details

```typescript
// Standard error response format
interface ProblemDetails {
  type: string;      // URI reference for error type
  title: string;     // Human-readable summary
  status: number;    // HTTP status code
  detail?: string;   // Specific error explanation
  instance?: string; // URI for this specific error
  [key: string]: unknown; // Extensions
}

// Implementation
app.use((err: AppError, req: Request, res: Response, next: NextFunction) => {
  const problem: ProblemDetails = {
    type: `https://api.example.com/errors/${err.code}`,
    title: err.title,
    status: err.statusCode,
    detail: err.message,
    instance: req.originalUrl,
    traceId: req.id,
  };

  if (err instanceof ValidationError) {
    problem.errors = err.details;
  }

  res.status(err.statusCode).json(problem);
});
```

### 4.2 Validation Errors

```json
{
  "type": "https://api.example.com/errors/validation-error",
  "title": "Validation Error",
  "status": 400,
  "detail": "One or more fields failed validation",
  "errors": {
    "email": ["Invalid email format"],
    "password": ["Must be at least 8 characters", "Must contain a number"]
  }
}
```

### 4.3 Common Error Types

```typescript
const errorTypes = {
  VALIDATION_ERROR: { status: 400, title: 'Validation Error' },
  UNAUTHORIZED: { status: 401, title: 'Unauthorized' },
  FORBIDDEN: { status: 403, title: 'Forbidden' },
  NOT_FOUND: { status: 404, title: 'Resource Not Found' },
  CONFLICT: { status: 409, title: 'Conflict' },
  RATE_LIMITED: { status: 429, title: 'Rate Limit Exceeded' },
  INTERNAL_ERROR: { status: 500, title: 'Internal Server Error' },
};
```

---

## 5. Pagination

### 5.1 Cursor-Based (Recommended)

```typescript
// Request
GET /api/users?limit=20&cursor=eyJpZCI6MTAwfQ

// Response
{
  "data": [...],
  "pagination": {
    "limit": 20,
    "hasMore": true,
    "nextCursor": "eyJpZCI6MTIwfQ",
    "prevCursor": "eyJpZCI6MTAwfQ"
  }
}

// Implementation
async function getUsers(cursor?: string, limit = 20) {
  const decodedCursor = cursor ? JSON.parse(atob(cursor)) : null;
  
  const users = await db.user.findMany({
    take: limit + 1, // Fetch one extra to check hasMore
    cursor: decodedCursor ? { id: decodedCursor.id } : undefined,
    skip: decodedCursor ? 1 : 0,
    orderBy: { id: 'asc' },
  });

  const hasMore = users.length > limit;
  const data = hasMore ? users.slice(0, -1) : users;

  return {
    data,
    pagination: {
      limit,
      hasMore,
      nextCursor: hasMore ? btoa(JSON.stringify({ id: data[data.length - 1].id })) : null,
    },
  };
}
```

### 5.2 Offset-Based (Simple but Less Performant)

```typescript
// Request
GET /api/users?page=2&limit=20

// Response
{
  "data": [...],
  "pagination": {
    "page": 2,
    "limit": 20,
    "total": 150,
    "totalPages": 8
  }
}

// Implementation
async function getUsers(page = 1, limit = 20) {
  const [users, total] = await Promise.all([
    db.user.findMany({
      skip: (page - 1) * limit,
      take: limit,
    }),
    db.user.count(),
  ]);

  return {
    data: users,
    pagination: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit),
    },
  };
}
```

---

## 6. Filtering & Sorting

### 6.1 Query Parameters

```
# Filtering
GET /api/users?status=active&role=admin
GET /api/users?createdAfter=2024-01-01
GET /api/users?search=john

# Sorting
GET /api/users?sort=createdAt:desc
GET /api/users?sort=name:asc,createdAt:desc

# Field selection (sparse fieldsets)
GET /api/users?fields=id,name,email
```

### 6.2 Implementation

```typescript
import { z } from 'zod';

const querySchema = z.object({
  status: z.enum(['active', 'inactive', 'pending']).optional(),
  role: z.enum(['admin', 'user']).optional(),
  search: z.string().optional(),
  sort: z.string().optional(),
  fields: z.string().optional(),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});

app.get('/api/users', async (req, res) => {
  const query = querySchema.parse(req.query);
  
  // Build where clause
  const where: Prisma.UserWhereInput = {};
  if (query.status) where.status = query.status;
  if (query.role) where.role = query.role;
  if (query.search) {
    where.OR = [
      { name: { contains: query.search, mode: 'insensitive' } },
      { email: { contains: query.search, mode: 'insensitive' } },
    ];
  }

  // Build orderBy
  let orderBy: Prisma.UserOrderByWithRelationInput = { createdAt: 'desc' };
  if (query.sort) {
    const [field, direction] = query.sort.split(':');
    orderBy = { [field]: direction || 'asc' };
  }

  // Build select (field selection)
  let select: Prisma.UserSelect | undefined;
  if (query.fields) {
    select = query.fields.split(',').reduce((acc, field) => {
      acc[field.trim()] = true;
      return acc;
    }, {} as Prisma.UserSelect);
  }

  const users = await db.user.findMany({
    where,
    orderBy,
    select,
    skip: (query.page - 1) * query.limit,
    take: query.limit,
  });

  res.json({ data: users });
});
```

---

## 7. Versioning

### 7.1 URL Versioning (Recommended)

```
GET /api/v1/users
GET /api/v2/users
```

### 7.2 Header Versioning

```
GET /api/users
Accept: application/vnd.api+json; version=2

# Or custom header
GET /api/users
X-API-Version: 2
```

### 7.3 Implementation

```typescript
// URL versioning
app.use('/api/v1', v1Router);
app.use('/api/v2', v2Router);

// With version detection middleware
function apiVersion(versions: Record<string, Router>) {
  return (req: Request, res: Response, next: NextFunction) => {
    const version = req.headers['x-api-version'] || '1';
    const router = versions[`v${version}`];
    
    if (!router) {
      return res.status(400).json({ error: 'Unsupported API version' });
    }
    
    return router(req, res, next);
  };
}
```

---

## 8. Response Formatting

### 8.1 Consistent Envelope

```typescript
// Success response
{
  "data": { ... },
  "meta": {
    "requestId": "abc123",
    "timestamp": "2024-01-15T10:00:00Z"
  }
}

// Collection response
{
  "data": [...],
  "pagination": { ... },
  "meta": { ... }
}

// Error response
{
  "error": {
    "type": "...",
    "title": "...",
    "detail": "...",
    "status": 400
  }
}
```

### 8.2 Response Helper

```typescript
function sendSuccess<T>(res: Response, data: T, statusCode = 200) {
  res.status(statusCode).json({
    data,
    meta: {
      requestId: res.locals.requestId,
      timestamp: new Date().toISOString(),
    },
  });
}

function sendPaginated<T>(
  res: Response,
  data: T[],
  pagination: PaginationInfo
) {
  res.json({
    data,
    pagination,
    meta: {
      requestId: res.locals.requestId,
      timestamp: new Date().toISOString(),
    },
  });
}

function sendError(res: Response, error: AppError) {
  res.status(error.statusCode).json({
    error: {
      type: error.type,
      title: error.title,
      detail: error.message,
      status: error.statusCode,
    },
  });
}
```

---

## 9. Rate Limiting Headers

```typescript
// Standard rate limit headers
res.setHeader('X-RateLimit-Limit', '100');        // Max requests
res.setHeader('X-RateLimit-Remaining', '95');     // Remaining
res.setHeader('X-RateLimit-Reset', '1705320000'); // Reset timestamp
res.setHeader('Retry-After', '60');               // On 429 response
```

---

## 10. Idempotency

### 10.1 Idempotency Key

```typescript
// Client sends idempotency key
POST /api/orders
Idempotency-Key: unique-request-id-123

// Server implementation
async function handleIdempotentRequest(
  key: string,
  handler: () => Promise<Response>
) {
  // Check if we've seen this key
  const cached = await redis.get(`idempotency:${key}`);
  if (cached) {
    return JSON.parse(cached);
  }

  // Process request
  const response = await handler();

  // Cache response for 24 hours
  await redis.set(
    `idempotency:${key}`,
    JSON.stringify(response),
    'EX',
    86400
  );

  return response;
}
```

---

## 11. OpenAPI Specification

```yaml
openapi: 3.1.0
info:
  title: My API
  version: 1.0.0
  description: API description

servers:
  - url: https://api.example.com/v1
    description: Production
  - url: https://api-staging.example.com/v1
    description: Staging

paths:
  /users:
    get:
      summary: List users
      operationId: listUsers
      tags: [Users]
      parameters:
        - name: limit
          in: query
          schema:
            type: integer
            default: 20
            maximum: 100
        - name: cursor
          in: query
          schema:
            type: string
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/UserListResponse'
        '401':
          $ref: '#/components/responses/Unauthorized'

components:
  schemas:
    User:
      type: object
      required: [id, email, name]
      properties:
        id:
          type: string
          format: uuid
        email:
          type: string
          format: email
        name:
          type: string
        createdAt:
          type: string
          format: date-time
  
  responses:
    Unauthorized:
      description: Authentication required
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/Error'
```

---

## Quick Reference

### URL Patterns
```
GET    /resources           # List
GET    /resources/{id}      # Get one
POST   /resources           # Create
PUT    /resources/{id}      # Replace
PATCH  /resources/{id}      # Update
DELETE /resources/{id}      # Delete
POST   /resources/{id}/action  # Custom action
```

### Naming Conventions
| Type | Convention | Example |
|------|------------|---------|
| URLs | kebab-case | `/user-profiles` |
| JSON fields | camelCase | `"firstName"` |
| Query params | camelCase | `?sortBy=name` |

### Status Code Cheat Sheet
| Action | Success | Client Error | Server Error |
|--------|---------|--------------|--------------|
| GET | 200 | 404 | 500 |
| POST | 201 | 400, 409 | 500 |
| PUT/PATCH | 200 | 400, 404 | 500 |
| DELETE | 204 | 404 | 500 |

### Headers Checklist
- [ ] `Content-Type: application/json`
- [ ] `X-Request-Id` for tracing
- [ ] `X-RateLimit-*` for rate limiting
- [ ] `Cache-Control` for caching
- [ ] `ETag` for conditional requests
