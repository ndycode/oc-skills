# Database Patterns (Prisma & Drizzle)

> **Auto-trigger**: `prisma/schema.prisma`, `drizzle.config.ts`, database operations

---

## 1. Prisma Setup

### 1.1 Schema Design

```prisma
// prisma/schema.prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id        String   @id @default(cuid())
  email     String   @unique
  name      String?
  password  String
  role      Role     @default(USER)
  posts     Post[]
  profile   Profile?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@index([email])
  @@map("users")
}

model Profile {
  id     String  @id @default(cuid())
  bio    String?
  avatar String?
  user   User    @relation(fields: [userId], references: [id], onDelete: Cascade)
  userId String  @unique

  @@map("profiles")
}

model Post {
  id          String     @id @default(cuid())
  title       String
  content     String?
  published   Boolean    @default(false)
  author      User       @relation(fields: [authorId], references: [id], onDelete: Cascade)
  authorId    String
  categories  Category[]
  createdAt   DateTime   @default(now())
  updatedAt   DateTime   @updatedAt

  @@index([authorId])
  @@index([published, createdAt])
  @@map("posts")
}

model Category {
  id    String @id @default(cuid())
  name  String @unique
  posts Post[]

  @@map("categories")
}

enum Role {
  USER
  ADMIN
}
```

### 1.2 Client Singleton

```typescript
// lib/db.ts
import { PrismaClient } from '@prisma/client';

const globalForPrisma = globalThis as unknown as {
  prisma: PrismaClient | undefined;
};

export const prisma = globalForPrisma.prisma ?? new PrismaClient({
  log: process.env.NODE_ENV === 'development' 
    ? ['query', 'error', 'warn'] 
    : ['error'],
});

if (process.env.NODE_ENV !== 'production') {
  globalForPrisma.prisma = prisma;
}

export default prisma;
```

---

## 2. Query Patterns

### 2.1 Basic CRUD

```typescript
// Create
const user = await prisma.user.create({
  data: {
    email: 'user@example.com',
    name: 'John Doe',
    password: hashedPassword,
    profile: {
      create: { bio: 'Hello world' },
    },
  },
  include: { profile: true },
});

// Read with relations
const userWithPosts = await prisma.user.findUnique({
  where: { id: userId },
  include: {
    posts: {
      where: { published: true },
      orderBy: { createdAt: 'desc' },
      take: 10,
    },
    profile: true,
  },
});

// Update
const updated = await prisma.user.update({
  where: { id: userId },
  data: { name: 'New Name' },
});

// Delete
await prisma.user.delete({
  where: { id: userId },
});
```

### 2.2 Select vs Include

```typescript
// Include - returns full related objects
const user = await prisma.user.findUnique({
  where: { id },
  include: { posts: true }, // Full Post objects
});

// Select - pick specific fields (better performance)
const user = await prisma.user.findUnique({
  where: { id },
  select: {
    id: true,
    name: true,
    email: true,
    posts: {
      select: { id: true, title: true },
      take: 5,
    },
  },
});
```

### 2.3 Pagination

```typescript
// Offset pagination (simple, but slow for large offsets)
async function getUsers(page: number, limit: number) {
  const [users, total] = await Promise.all([
    prisma.user.findMany({
      skip: (page - 1) * limit,
      take: limit,
      orderBy: { createdAt: 'desc' },
    }),
    prisma.user.count(),
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

// Cursor pagination (better for large datasets)
async function getUsersCursor(cursor?: string, limit = 20) {
  const users = await prisma.user.findMany({
    take: limit + 1,
    cursor: cursor ? { id: cursor } : undefined,
    skip: cursor ? 1 : 0,
    orderBy: { id: 'asc' },
  });

  const hasMore = users.length > limit;
  const data = hasMore ? users.slice(0, -1) : users;

  return {
    data,
    nextCursor: hasMore ? data[data.length - 1].id : null,
  };
}
```

### 2.4 Transactions

```typescript
// Sequential transaction
const [user, post] = await prisma.$transaction([
  prisma.user.create({ data: userData }),
  prisma.post.create({ data: postData }),
]);

// Interactive transaction
const result = await prisma.$transaction(async (tx) => {
  const user = await tx.user.findUnique({ where: { id: userId } });
  
  if (!user) throw new Error('User not found');
  
  const order = await tx.order.create({
    data: { userId: user.id, ...orderData },
  });
  
  await tx.user.update({
    where: { id: userId },
    data: { orderCount: { increment: 1 } },
  });
  
  return order;
}, {
  maxWait: 5000,
  timeout: 10000,
});
```

---

## 3. Drizzle ORM

### 3.1 Schema Definition

```typescript
// db/schema.ts
import { pgTable, text, timestamp, boolean, pgEnum } from 'drizzle-orm/pg-core';
import { relations } from 'drizzle-orm';

export const roleEnum = pgEnum('role', ['user', 'admin']);

export const users = pgTable('users', {
  id: text('id').primaryKey().$defaultFn(() => crypto.randomUUID()),
  email: text('email').unique().notNull(),
  name: text('name'),
  password: text('password').notNull(),
  role: roleEnum('role').default('user'),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

export const posts = pgTable('posts', {
  id: text('id').primaryKey().$defaultFn(() => crypto.randomUUID()),
  title: text('title').notNull(),
  content: text('content'),
  published: boolean('published').default(false),
  authorId: text('author_id').references(() => users.id, { onDelete: 'cascade' }),
  createdAt: timestamp('created_at').defaultNow(),
});

// Relations
export const usersRelations = relations(users, ({ many }) => ({
  posts: many(posts),
}));

export const postsRelations = relations(posts, ({ one }) => ({
  author: one(users, {
    fields: [posts.authorId],
    references: [users.id],
  }),
}));
```

### 3.2 Drizzle Queries

```typescript
// db/index.ts
import { drizzle } from 'drizzle-orm/node-postgres';
import { Pool } from 'pg';
import * as schema from './schema';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
export const db = drizzle(pool, { schema });

// Queries
import { eq, desc, and, like } from 'drizzle-orm';

// Select
const allUsers = await db.select().from(users);

// Select with where
const user = await db.select()
  .from(users)
  .where(eq(users.email, 'user@example.com'))
  .limit(1);

// Select with join
const postsWithAuthors = await db.select({
  post: posts,
  authorName: users.name,
})
  .from(posts)
  .leftJoin(users, eq(posts.authorId, users.id))
  .where(eq(posts.published, true))
  .orderBy(desc(posts.createdAt));

// Using query builder (with relations)
const userWithPosts = await db.query.users.findFirst({
  where: eq(users.id, userId),
  with: {
    posts: {
      where: eq(posts.published, true),
      limit: 10,
    },
  },
});

// Insert
const newUser = await db.insert(users)
  .values({ email: 'new@example.com', password: hash })
  .returning();

// Update
await db.update(users)
  .set({ name: 'New Name' })
  .where(eq(users.id, userId));

// Delete
await db.delete(users).where(eq(users.id, userId));
```

---

## 4. Query Optimization

### 4.1 N+1 Problem

```typescript
// BAD - N+1 queries
const posts = await prisma.post.findMany();
for (const post of posts) {
  const author = await prisma.user.findUnique({
    where: { id: post.authorId },
  }); // Runs N times!
}

// GOOD - Single query with include
const posts = await prisma.post.findMany({
  include: { author: true },
});

// GOOD - Batch loading
const posts = await prisma.post.findMany();
const authorIds = [...new Set(posts.map(p => p.authorId))];
const authors = await prisma.user.findMany({
  where: { id: { in: authorIds } },
});
const authorMap = new Map(authors.map(a => [a.id, a]));
```

### 4.2 Indexes

```prisma
model Post {
  id        String   @id
  title     String
  authorId  String
  published Boolean
  createdAt DateTime

  // Single column index
  @@index([authorId])
  
  // Composite index for common query patterns
  @@index([published, createdAt])
  
  // Unique constraint (creates index)
  @@unique([authorId, title])
}
```

### 4.3 Query Analysis

```typescript
// Prisma query logging
const prisma = new PrismaClient({
  log: [
    { level: 'query', emit: 'event' },
  ],
});

prisma.$on('query', (e) => {
  console.log(`Query: ${e.query}`);
  console.log(`Duration: ${e.duration}ms`);
});

// PostgreSQL EXPLAIN
const result = await prisma.$queryRaw`
  EXPLAIN ANALYZE
  SELECT * FROM posts
  WHERE published = true
  ORDER BY created_at DESC
  LIMIT 10
`;
```

---

## 5. Migrations

### 5.1 Prisma Migrations

```bash
# Create migration
npx prisma migrate dev --name add_user_role

# Apply migrations in production
npx prisma migrate deploy

# Reset database (dev only)
npx prisma migrate reset

# Generate client after schema change
npx prisma generate
```

### 5.2 Drizzle Migrations

```bash
# Generate migration
npx drizzle-kit generate:pg

# Apply migrations
npx drizzle-kit push:pg

# Or use migrate function
import { migrate } from 'drizzle-orm/node-postgres/migrator';
await migrate(db, { migrationsFolder: './drizzle' });
```

---

## 6. Connection Pooling

### 6.1 Prisma with PgBouncer

```typescript
// For serverless (Vercel, etc.)
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
  directUrl = env("DIRECT_URL") // For migrations
}

// Connection limit for serverless
const prisma = new PrismaClient({
  datasources: {
    db: {
      url: process.env.DATABASE_URL,
    },
  },
});
```

### 6.2 Drizzle with Pool

```typescript
import { Pool } from 'pg';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

export const db = drizzle(pool, { schema });
```

---

## 7. Type Safety

### 7.1 Prisma Types

```typescript
import { Prisma, User, Post } from '@prisma/client';

// Input types
type CreateUserInput = Prisma.UserCreateInput;
type UpdateUserInput = Prisma.UserUpdateInput;

// With relations
type UserWithPosts = Prisma.UserGetPayload<{
  include: { posts: true };
}>;

// Custom select
type UserPreview = Prisma.UserGetPayload<{
  select: { id: true; name: true; email: true };
}>;
```

### 7.2 Drizzle Types

```typescript
import { InferSelectModel, InferInsertModel } from 'drizzle-orm';

type User = InferSelectModel<typeof users>;
type NewUser = InferInsertModel<typeof users>;

// Partial for updates
type UserUpdate = Partial<NewUser>;
```

---

## Quick Reference

### Prisma CLI Commands
```bash
npx prisma init              # Initialize
npx prisma generate          # Generate client
npx prisma migrate dev       # Create & apply migration
npx prisma migrate deploy    # Production migration
npx prisma db push           # Push without migration
npx prisma studio            # GUI browser
npx prisma db seed           # Run seed script
```

### Common Query Patterns
```typescript
// Prisma
findUnique({ where })
findFirst({ where, orderBy })
findMany({ where, orderBy, skip, take })
create({ data })
update({ where, data })
delete({ where })
upsert({ where, create, update })
count({ where })
aggregate({ _sum, _avg, _count })

// Drizzle
select().from(table).where().orderBy()
insert(table).values().returning()
update(table).set().where()
delete(table).where()
```

### Performance Checklist
- [ ] Use `select` instead of `include` when possible
- [ ] Add indexes for frequently queried columns
- [ ] Use cursor pagination for large datasets
- [ ] Batch related queries
- [ ] Use connection pooling in serverless
- [ ] Analyze slow queries with EXPLAIN
