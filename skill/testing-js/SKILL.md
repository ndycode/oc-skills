# JavaScript/TypeScript Testing Best Practices

> **Sources**: 
> - [goldbergyoni/javascript-testing-best-practices](https://github.com/goldbergyoni/javascript-testing-best-practices) (24k+ stars)
> - [testing-library/react-testing-library](https://github.com/testing-library/react-testing-library) (19k+ stars)
> 
> **Auto-trigger**: Test files (`*.test.ts`, `*.spec.ts`), Vitest/Jest config present

---

## 1. The Golden Rule

> **Test behavior, not implementation.**

If you refactor code and tests break (but behavior didn't change), your tests are testing implementation details.

```typescript
// BAD - Testing implementation
test('should set isLoading to true', () => {
  const { result } = renderHook(() => useUsers());
  act(() => result.current.fetchUsers());
  expect(result.current.isLoading).toBe(true); // Implementation detail
});

// GOOD - Testing behavior
test('shows loading indicator while fetching users', async () => {
  render(<UserList />);
  expect(screen.getByRole('progressbar')).toBeInTheDocument();
  await waitForElementToBeRemoved(() => screen.queryByRole('progressbar'));
  expect(screen.getByText('John Doe')).toBeInTheDocument();
});
```

---

## 2. Test Structure (AAA Pattern)

### 2.1 Arrange, Act, Assert

```typescript
test('creates a new user with valid data', async () => {
  // Arrange - Set up test data and conditions
  const userData = {
    email: 'test@example.com',
    name: 'Test User',
  };
  
  // Act - Perform the action being tested
  const user = await userService.create(userData);
  
  // Assert - Verify the outcome
  expect(user).toMatchObject({
    id: expect.any(String),
    email: 'test@example.com',
    name: 'Test User',
    createdAt: expect.any(Date),
  });
});
```

### 2.2 One Concept Per Test

```typescript
// BAD - Multiple concepts
test('user operations', async () => {
  const user = await createUser(data);
  expect(user.id).toBeDefined();
  
  const updated = await updateUser(user.id, { name: 'New Name' });
  expect(updated.name).toBe('New Name');
  
  await deleteUser(user.id);
  const found = await findUser(user.id);
  expect(found).toBeNull();
});

// GOOD - Single concept per test
describe('UserService', () => {
  test('creates user with valid data', async () => {
    const user = await createUser(data);
    expect(user.id).toBeDefined();
  });

  test('updates user name', async () => {
    const user = await createUser(data);
    const updated = await updateUser(user.id, { name: 'New Name' });
    expect(updated.name).toBe('New Name');
  });

  test('deletes user', async () => {
    const user = await createUser(data);
    await deleteUser(user.id);
    const found = await findUser(user.id);
    expect(found).toBeNull();
  });
});
```

### 2.3 Descriptive Test Names

```typescript
// BAD
test('test1', () => {});
test('should work', () => {});
test('handles error', () => {});

// GOOD - Describes scenario and expected outcome
test('returns 404 when user does not exist', () => {});
test('sends welcome email after successful registration', () => {});
test('rejects passwords shorter than 8 characters', () => {});
test('allows admin to delete any user', () => {});
```

---

## 3. Component Testing (React Testing Library)

### 3.1 Query Priority

```typescript
// BEST - Accessible queries (how users/screen readers find elements)
screen.getByRole('button', { name: /submit/i });
screen.getByLabelText('Email address');
screen.getByPlaceholderText('Enter your email');
screen.getByText('Welcome back');
screen.getByDisplayValue('john@example.com');

// OK - Semantic queries
screen.getByAltText('User avatar');
screen.getByTitle('Close dialog');

// LAST RESORT - Test IDs (only when no other option)
screen.getByTestId('custom-dropdown');
```

### 3.2 User Event Testing

```typescript
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

test('submits form with user input', async () => {
  const user = userEvent.setup();
  const onSubmit = vi.fn();
  
  render(<LoginForm onSubmit={onSubmit} />);
  
  // Type into inputs
  await user.type(screen.getByLabelText(/email/i), 'test@example.com');
  await user.type(screen.getByLabelText(/password/i), 'password123');
  
  // Click submit
  await user.click(screen.getByRole('button', { name: /sign in/i }));
  
  // Verify submission
  expect(onSubmit).toHaveBeenCalledWith({
    email: 'test@example.com',
    password: 'password123',
  });
});
```

### 3.3 Async Testing

```typescript
import { render, screen, waitFor, waitForElementToBeRemoved } from '@testing-library/react';

test('loads and displays users', async () => {
  render(<UserList />);
  
  // Wait for loading to finish
  await waitForElementToBeRemoved(() => screen.queryByText(/loading/i));
  
  // Verify data is displayed
  expect(screen.getByText('John Doe')).toBeInTheDocument();
  expect(screen.getByText('Jane Smith')).toBeInTheDocument();
});

test('shows error message on fetch failure', async () => {
  server.use(
    http.get('/api/users', () => {
      return HttpResponse.json({ error: 'Server error' }, { status: 500 });
    })
  );
  
  render(<UserList />);
  
  // Wait for error to appear
  await waitFor(() => {
    expect(screen.getByRole('alert')).toHaveTextContent(/failed to load/i);
  });
});
```

### 3.4 Testing Custom Hooks

```typescript
import { renderHook, act, waitFor } from '@testing-library/react';

test('useCounter increments value', () => {
  const { result } = renderHook(() => useCounter({ initial: 0 }));
  
  expect(result.current.count).toBe(0);
  
  act(() => {
    result.current.increment();
  });
  
  expect(result.current.count).toBe(1);
});

test('useFetch returns data', async () => {
  const { result } = renderHook(() => useFetch('/api/users'));
  
  expect(result.current.isLoading).toBe(true);
  
  await waitFor(() => {
    expect(result.current.isLoading).toBe(false);
  });
  
  expect(result.current.data).toEqual([{ id: '1', name: 'John' }]);
});
```

---

## 4. API/Integration Testing

### 4.1 MSW (Mock Service Worker)

```typescript
// mocks/handlers.ts
import { http, HttpResponse } from 'msw';

export const handlers = [
  http.get('/api/users', () => {
    return HttpResponse.json([
      { id: '1', name: 'John Doe', email: 'john@example.com' },
      { id: '2', name: 'Jane Smith', email: 'jane@example.com' },
    ]);
  }),
  
  http.post('/api/users', async ({ request }) => {
    const body = await request.json();
    return HttpResponse.json(
      { id: '3', ...body, createdAt: new Date().toISOString() },
      { status: 201 }
    );
  }),
  
  http.get('/api/users/:id', ({ params }) => {
    if (params.id === '999') {
      return HttpResponse.json({ error: 'Not found' }, { status: 404 });
    }
    return HttpResponse.json({ id: params.id, name: 'John Doe' });
  }),
];

// mocks/server.ts
import { setupServer } from 'msw/node';
import { handlers } from './handlers';

export const server = setupServer(...handlers);

// setup.ts
beforeAll(() => server.listen({ onUnhandledRequest: 'error' }));
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
```

### 4.2 API Route Testing (Supertest)

```typescript
import request from 'supertest';
import { app } from '../src/app';
import { db } from '../src/db';

describe('POST /api/users', () => {
  beforeEach(async () => {
    await db.user.deleteMany();
  });

  test('creates user with valid data', async () => {
    const response = await request(app)
      .post('/api/users')
      .send({
        email: 'test@example.com',
        name: 'Test User',
        password: 'password123',
      })
      .expect(201);

    expect(response.body).toMatchObject({
      id: expect.any(String),
      email: 'test@example.com',
      name: 'Test User',
    });
    expect(response.body).not.toHaveProperty('password');
  });

  test('returns 400 for invalid email', async () => {
    const response = await request(app)
      .post('/api/users')
      .send({
        email: 'invalid',
        name: 'Test User',
        password: 'password123',
      })
      .expect(400);

    expect(response.body.error).toBe('VALIDATION_ERROR');
  });

  test('returns 409 for duplicate email', async () => {
    await db.user.create({
      data: { email: 'test@example.com', name: 'Existing', password: 'hash' },
    });

    await request(app)
      .post('/api/users')
      .send({
        email: 'test@example.com',
        name: 'New User',
        password: 'password123',
      })
      .expect(409);
  });
});
```

---

## 5. Mocking

### 5.1 When to Mock

```typescript
// MOCK: External services (APIs, databases, file system)
// MOCK: Time-dependent code
// MOCK: Random values

// DON'T MOCK: Your own code (usually)
// DON'T MOCK: Simple utility functions
```

### 5.2 Mocking Modules

```typescript
import { vi } from 'vitest';

// Mock entire module
vi.mock('@/lib/email', () => ({
  sendEmail: vi.fn().mockResolvedValue({ success: true }),
}));

// Mock specific function
import { sendEmail } from '@/lib/email';
vi.mocked(sendEmail).mockResolvedValueOnce({ success: false, error: 'Failed' });

// Spy on function
const consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {});
// ... test
expect(consoleSpy).toHaveBeenCalledWith('Error:', expect.any(Error));
consoleSpy.mockRestore();
```

### 5.3 Mocking Time

```typescript
import { vi, beforeEach, afterEach } from 'vitest';

beforeEach(() => {
  vi.useFakeTimers();
  vi.setSystemTime(new Date('2024-01-15T10:00:00Z'));
});

afterEach(() => {
  vi.useRealTimers();
});

test('creates record with current timestamp', async () => {
  const record = await createRecord({ name: 'Test' });
  expect(record.createdAt).toEqual(new Date('2024-01-15T10:00:00Z'));
});

test('expires token after 1 hour', async () => {
  const token = createToken();
  
  vi.advanceTimersByTime(59 * 60 * 1000); // 59 minutes
  expect(isTokenValid(token)).toBe(true);
  
  vi.advanceTimersByTime(2 * 60 * 1000); // 2 more minutes
  expect(isTokenValid(token)).toBe(false);
});
```

---

## 6. Test Data

### 6.1 Factories

```typescript
// factories/user.ts
import { faker } from '@faker-js/faker';
import type { User } from '@/types';

export function createMockUser(overrides?: Partial<User>): User {
  return {
    id: faker.string.uuid(),
    email: faker.internet.email(),
    name: faker.person.fullName(),
    role: 'user',
    createdAt: faker.date.past(),
    updatedAt: faker.date.recent(),
    ...overrides,
  };
}

export function createMockUsers(count: number, overrides?: Partial<User>): User[] {
  return Array.from({ length: count }, () => createMockUser(overrides));
}

// Usage in tests
const user = createMockUser({ role: 'admin' });
const users = createMockUsers(5);
```

### 6.2 Database Seeding

```typescript
// test/helpers/db.ts
import { db } from '@/lib/db';

export async function resetDatabase() {
  await db.$transaction([
    db.comment.deleteMany(),
    db.post.deleteMany(),
    db.user.deleteMany(),
  ]);
}

export async function seedUser(data?: Partial<User>) {
  return db.user.create({
    data: {
      email: `test-${Date.now()}@example.com`,
      name: 'Test User',
      password: await hashPassword('password123'),
      ...data,
    },
  });
}

// In tests
beforeEach(async () => {
  await resetDatabase();
});

test('user can create post', async () => {
  const user = await seedUser();
  const post = await createPost(user.id, { title: 'Test' });
  expect(post.authorId).toBe(user.id);
});
```

---

## 7. Test Organization

### 7.1 File Structure

```
src/
├── features/
│   └── users/
│       ├── components/
│       │   ├── user-card.tsx
│       │   └── user-card.test.tsx    # Co-located
│       ├── api/
│       │   ├── get-users.ts
│       │   └── get-users.test.ts
│       └── hooks/
│           ├── use-users.ts
│           └── use-users.test.ts

tests/
├── integration/                       # Cross-feature tests
│   └── user-flow.test.ts
├── e2e/                              # End-to-end tests
│   └── auth.spec.ts
└── helpers/
    ├── db.ts
    ├── render.tsx
    └── mocks/
```

### 7.2 Test Setup

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./tests/setup.ts'],
    include: ['**/*.test.{ts,tsx}'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html'],
      exclude: ['node_modules', 'tests'],
      thresholds: {
        statements: 80,
        branches: 80,
        functions: 80,
        lines: 80,
      },
    },
  },
});

// tests/setup.ts
import '@testing-library/jest-dom';
import { cleanup } from '@testing-library/react';
import { afterEach, vi } from 'vitest';
import { server } from './mocks/server';

// MSW setup
beforeAll(() => server.listen({ onUnhandledRequest: 'error' }));
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

// Cleanup after each test
afterEach(() => {
  cleanup();
  vi.clearAllMocks();
});

// Mock window.matchMedia
Object.defineProperty(window, 'matchMedia', {
  value: vi.fn().mockImplementation((query) => ({
    matches: false,
    media: query,
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
  })),
});
```

---

## 8. Testing Patterns

### 8.1 Snapshot Testing (Use Sparingly)

```typescript
// GOOD use - Stable output
test('renders error message correctly', () => {
  const { container } = render(<ErrorMessage message="Something went wrong" />);
  expect(container.firstChild).toMatchSnapshot();
});

// BAD use - Dynamic content
test('renders user list', () => {
  render(<UserList users={users} />);
  expect(screen.getByRole('list')).toMatchSnapshot(); // Will break constantly
});
```

### 8.2 Parameterized Tests

```typescript
test.each([
  { input: '', expected: false },
  { input: 'test', expected: false },
  { input: 'test@', expected: false },
  { input: 'test@example', expected: false },
  { input: 'test@example.com', expected: true },
  { input: 'Test@Example.COM', expected: true },
])('validates email "$input" as $expected', ({ input, expected }) => {
  expect(isValidEmail(input)).toBe(expected);
});

test.each`
  role        | canDelete | canCreate
  ${'admin'}  | ${true}   | ${true}
  ${'editor'} | ${false}  | ${true}
  ${'viewer'} | ${false}  | ${false}
`('$role has delete=$canDelete, create=$canCreate', ({ role, canDelete, canCreate }) => {
  expect(hasPermission(role, 'delete')).toBe(canDelete);
  expect(hasPermission(role, 'create')).toBe(canCreate);
});
```

### 8.3 Error Testing

```typescript
test('throws error for invalid input', () => {
  expect(() => processData(null)).toThrow('Input cannot be null');
  expect(() => processData(null)).toThrow(ValidationError);
});

test('rejects promise with error', async () => {
  await expect(fetchUser('invalid')).rejects.toThrow('User not found');
  await expect(fetchUser('invalid')).rejects.toMatchObject({
    code: 'NOT_FOUND',
    statusCode: 404,
  });
});
```

---

## Quick Reference

### Query Priority (React Testing Library)
1. `getByRole` — Best, accessible
2. `getByLabelText` — Form fields
3. `getByPlaceholderText` — Inputs
4. `getByText` — Non-interactive
5. `getByDisplayValue` — Filled inputs
6. `getByAltText` — Images
7. `getByTitle` — Title attribute
8. `getByTestId` — Last resort

### Async Utilities
```typescript
await waitFor(() => expect(...));           // Wait for assertion
await waitForElementToBeRemoved(element);   // Wait for removal
await screen.findByText('...');             // getBy + waitFor
```

### Common Matchers
```typescript
expect(element).toBeInTheDocument();
expect(element).toBeVisible();
expect(element).toBeDisabled();
expect(element).toHaveTextContent('...');
expect(element).toHaveAttribute('href', '/...');
expect(element).toHaveClass('active');
expect(element).toHaveFocus();
expect(input).toHaveValue('...');
```

### Test Checklist
- [ ] Tests behavior, not implementation
- [ ] Uses AAA pattern
- [ ] One concept per test
- [ ] Descriptive test names
- [ ] No test interdependence
- [ ] Uses accessible queries
- [ ] Mocks only external dependencies
- [ ] No flaky tests
