# TypeScript Senior Patterns

> **Sources**: 
> - [type-challenges/type-challenges](https://github.com/type-challenges/type-challenges) (47k+ stars)
> - [sindresorhus/type-fest](https://github.com/sindresorhus/type-fest) (17k+ stars)
> - [labs42io/clean-code-typescript](https://github.com/labs42io/clean-code-typescript) (10k+ stars)
> 
> **Auto-trigger**: `tsconfig.json` exists in project

---

## 1. Strict Configuration

### 1.1 Production tsconfig.json

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "lib": ["ES2022"],
    
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "noPropertyAccessFromIndexSignature": true,
    "noFallthroughCasesInSwitch": true,
    "forceConsistentCasingInFileNames": true,
    "exactOptionalPropertyTypes": true,
    
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    
    "outDir": "./dist",
    "rootDir": "./src",
    
    "skipLibCheck": true,
    "esModuleInterop": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "verbatimModuleSyntax": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

### 1.2 Key Strict Options Explained

| Option | What It Catches |
|--------|-----------------|
| `noUncheckedIndexedAccess` | `arr[0]` returns `T \| undefined` |
| `exactOptionalPropertyTypes` | `{ a?: string }` means `string \| undefined`, not `string \| undefined \| missing` |
| `noPropertyAccessFromIndexSignature` | Forces `obj['key']` for index signatures |
| `noImplicitOverride` | Requires `override` keyword for overridden methods |

---

## 2. Utility Types Mastery

### 2.1 Built-in Utility Types

```typescript
// Partial<T> - All properties optional
type PartialUser = Partial<User>;

// Required<T> - All properties required
type RequiredConfig = Required<Config>;

// Readonly<T> - All properties readonly
type ImmutableState = Readonly<State>;

// Pick<T, K> - Select properties
type UserPreview = Pick<User, 'id' | 'name'>;

// Omit<T, K> - Exclude properties
type UserWithoutPassword = Omit<User, 'password'>;

// Record<K, V> - Object with keys K and values V
type UserMap = Record<string, User>;

// Extract<T, U> - Extract types assignable to U
type NumericEvents = Extract<Event, { value: number }>;

// Exclude<T, U> - Exclude types assignable to U
type NonNullableString = Exclude<string | null | undefined, null | undefined>;

// NonNullable<T> - Remove null and undefined
type DefinitelyString = NonNullable<string | null>;

// ReturnType<T> - Get function return type
type FetchResult = ReturnType<typeof fetchUser>;

// Parameters<T> - Get function parameters as tuple
type FetchParams = Parameters<typeof fetchUser>;

// Awaited<T> - Unwrap Promise
type User = Awaited<ReturnType<typeof fetchUser>>;
```

### 2.2 Advanced Custom Utility Types

```typescript
// DeepPartial - Recursive partial
type DeepPartial<T> = T extends object
  ? { [P in keyof T]?: DeepPartial<T[P]> }
  : T;

// DeepReadonly - Recursive readonly
type DeepReadonly<T> = T extends object
  ? { readonly [P in keyof T]: DeepReadonly<T[P]> }
  : T;

// Mutable - Remove readonly
type Mutable<T> = { -readonly [P in keyof T]: T[P] };

// RequireAtLeastOne - At least one property required
type RequireAtLeastOne<T, Keys extends keyof T = keyof T> = Pick<
  T,
  Exclude<keyof T, Keys>
> &
  { [K in Keys]-?: Required<Pick<T, K>> & Partial<Pick<T, Exclude<Keys, K>>> }[Keys];

// RequireOnlyOne - Exactly one property required
type RequireOnlyOne<T, Keys extends keyof T = keyof T> = Pick<
  T,
  Exclude<keyof T, Keys>
> &
  {
    [K in Keys]-?: Required<Pick<T, K>> &
      Partial<Record<Exclude<Keys, K>, never>>;
  }[Keys];

// Usage
type Filter = RequireAtLeastOne<{
  name?: string;
  email?: string;
  id?: string;
}, 'name' | 'email' | 'id'>;
```

### 2.3 Template Literal Types

```typescript
// Event names
type EventName<T extends string> = `on${Capitalize<T>}`;
type ClickEvent = EventName<'click'>; // 'onClick'

// Route parameters
type ExtractParams<T extends string> = T extends `${infer _Start}:${infer Param}/${infer Rest}`
  ? Param | ExtractParams<`/${Rest}`>
  : T extends `${infer _Start}:${infer Param}`
  ? Param
  : never;

type Params = ExtractParams<'/users/:userId/posts/:postId'>; // 'userId' | 'postId'

// API routes
type HttpMethod = 'GET' | 'POST' | 'PUT' | 'DELETE';
type ApiRoute = `${HttpMethod} /api/${string}`;

const route: ApiRoute = 'GET /api/users'; // Valid
```

---

## 3. Type Guards & Narrowing

### 3.1 Type Predicates

```typescript
// Custom type guard
function isUser(value: unknown): value is User {
  return (
    typeof value === 'object' &&
    value !== null &&
    'id' in value &&
    'email' in value &&
    typeof (value as User).id === 'string' &&
    typeof (value as User).email === 'string'
  );
}

// Usage
function processData(data: unknown) {
  if (isUser(data)) {
    // data is now User
    console.log(data.email);
  }
}
```

### 3.2 Assertion Functions

```typescript
function assertIsUser(value: unknown): asserts value is User {
  if (!isUser(value)) {
    throw new Error('Value is not a User');
  }
}

// After assertion, type is narrowed
function processUser(data: unknown) {
  assertIsUser(data);
  // data is now User for rest of function
  console.log(data.email);
}
```

### 3.3 Discriminated Unions

```typescript
// Always use a literal type discriminant
type Result<T, E = Error> =
  | { success: true; data: T }
  | { success: false; error: E };

function handleResult<T>(result: Result<T>) {
  if (result.success) {
    // result.data is available
    return result.data;
  } else {
    // result.error is available
    throw result.error;
  }
}

// API response pattern
type ApiResponse<T> =
  | { status: 'loading' }
  | { status: 'success'; data: T }
  | { status: 'error'; error: string };

function renderResponse<T>(response: ApiResponse<T>) {
  switch (response.status) {
    case 'loading':
      return <Spinner />;
    case 'success':
      return <Data data={response.data} />;
    case 'error':
      return <Error message={response.error} />;
  }
}
```

### 3.4 Exhaustive Checks

```typescript
// Ensures all cases are handled
function assertNever(value: never): never {
  throw new Error(`Unexpected value: ${value}`);
}

type Status = 'pending' | 'approved' | 'rejected';

function getStatusColor(status: Status): string {
  switch (status) {
    case 'pending':
      return 'yellow';
    case 'approved':
      return 'green';
    case 'rejected':
      return 'red';
    default:
      return assertNever(status); // Compile error if case missing
  }
}
```

---

## 4. Generics Patterns

### 4.1 Constrained Generics

```typescript
// Constrain to object with id
function findById<T extends { id: string }>(items: T[], id: string): T | undefined {
  return items.find((item) => item.id === id);
}

// Constrain to keys of object
function getProperty<T, K extends keyof T>(obj: T, key: K): T[K] {
  return obj[key];
}

// Multiple constraints
function merge<T extends object, U extends object>(obj1: T, obj2: U): T & U {
  return { ...obj1, ...obj2 };
}
```

### 4.2 Generic Defaults

```typescript
// Default type parameter
interface ApiResponse<T = unknown> {
  data: T;
  status: number;
  message: string;
}

// With constraints and defaults
interface Repository<T extends { id: string } = { id: string }> {
  findById(id: string): Promise<T | null>;
  save(entity: T): Promise<T>;
}
```

### 4.3 Conditional Types

```typescript
// Return different type based on input
type UnwrapPromise<T> = T extends Promise<infer U> ? U : T;

type A = UnwrapPromise<Promise<string>>; // string
type B = UnwrapPromise<number>; // number

// Flatten array or return as-is
type Flatten<T> = T extends Array<infer U> ? U : T;

// Extract function return type or undefined
type SafeReturnType<T> = T extends (...args: any[]) => infer R ? R : undefined;
```

### 4.4 Mapped Types with Modifiers

```typescript
// Make all properties optional and nullable
type Nullable<T> = { [P in keyof T]: T[P] | null };

// Make all properties required and mutable
type Complete<T> = { -readonly [P in keyof T]-?: T[P] };

// Rename keys with template literals
type Getters<T> = {
  [K in keyof T as `get${Capitalize<string & K>}`]: () => T[K];
};

type UserGetters = Getters<{ name: string; age: number }>;
// { getName: () => string; getAge: () => number }
```

---

## 5. SOLID Principles in TypeScript

### 5.1 Single Responsibility

```typescript
// BAD - Multiple responsibilities
class UserService {
  createUser(data: CreateUserDto) { /* ... */ }
  sendWelcomeEmail(user: User) { /* ... */ }
  generateReport(users: User[]) { /* ... */ }
}

// GOOD - Single responsibility each
class UserService {
  constructor(
    private userRepository: UserRepository,
    private eventEmitter: EventEmitter
  ) {}

  async createUser(data: CreateUserDto): Promise<User> {
    const user = await this.userRepository.create(data);
    this.eventEmitter.emit('user.created', user);
    return user;
  }
}

class EmailService {
  async sendWelcomeEmail(user: User): Promise<void> { /* ... */ }
}

class ReportService {
  generateUserReport(users: User[]): Report { /* ... */ }
}
```

### 5.2 Open/Closed Principle

```typescript
// BAD - Modifying existing code for new payment types
class PaymentProcessor {
  process(payment: Payment) {
    if (payment.type === 'credit') { /* ... */ }
    else if (payment.type === 'paypal') { /* ... */ }
    // Adding new type requires modifying this class
  }
}

// GOOD - Open for extension, closed for modification
interface PaymentStrategy {
  process(amount: number): Promise<PaymentResult>;
}

class CreditCardStrategy implements PaymentStrategy {
  async process(amount: number): Promise<PaymentResult> { /* ... */ }
}

class PayPalStrategy implements PaymentStrategy {
  async process(amount: number): Promise<PaymentResult> { /* ... */ }
}

class PaymentProcessor {
  constructor(private strategy: PaymentStrategy) {}

  async process(amount: number): Promise<PaymentResult> {
    return this.strategy.process(amount);
  }
}
```

### 5.3 Liskov Substitution

```typescript
// BAD - Square violates Rectangle's behavior
class Rectangle {
  constructor(public width: number, public height: number) {}
  
  setWidth(width: number) { this.width = width; }
  setHeight(height: number) { this.height = height; }
  getArea() { return this.width * this.height; }
}

class Square extends Rectangle {
  setWidth(width: number) {
    this.width = width;
    this.height = width; // Violates LSP!
  }
}

// GOOD - Use composition or separate abstractions
interface Shape {
  getArea(): number;
}

class Rectangle implements Shape {
  constructor(private width: number, private height: number) {}
  getArea() { return this.width * this.height; }
}

class Square implements Shape {
  constructor(private side: number) {}
  getArea() { return this.side * this.side; }
}
```

### 5.4 Interface Segregation

```typescript
// BAD - Fat interface
interface Worker {
  work(): void;
  eat(): void;
  sleep(): void;
}

class Robot implements Worker {
  work() { /* ... */ }
  eat() { throw new Error('Robots do not eat'); } // Violation!
  sleep() { throw new Error('Robots do not sleep'); }
}

// GOOD - Segregated interfaces
interface Workable {
  work(): void;
}

interface Eatable {
  eat(): void;
}

interface Sleepable {
  sleep(): void;
}

class Human implements Workable, Eatable, Sleepable {
  work() { /* ... */ }
  eat() { /* ... */ }
  sleep() { /* ... */ }
}

class Robot implements Workable {
  work() { /* ... */ }
}
```

### 5.5 Dependency Inversion

```typescript
// BAD - High-level depends on low-level
class UserService {
  private database = new MySQLDatabase(); // Tight coupling

  getUser(id: string) {
    return this.database.query(`SELECT * FROM users WHERE id = ${id}`);
  }
}

// GOOD - Both depend on abstraction
interface Database {
  query<T>(sql: string): Promise<T>;
}

class UserService {
  constructor(private database: Database) {} // Injected

  getUser(id: string) {
    return this.database.query(`SELECT * FROM users WHERE id = ?`, [id]);
  }
}

// Can inject any implementation
const userService = new UserService(new MySQLDatabase());
const testService = new UserService(new MockDatabase());
```

---

## 6. Error Handling Patterns

### 6.1 Result Type (No Exceptions)

```typescript
type Result<T, E = Error> =
  | { ok: true; value: T }
  | { ok: false; error: E };

// Helper functions
const Ok = <T>(value: T): Result<T, never> => ({ ok: true, value });
const Err = <E>(error: E): Result<never, E> => ({ ok: false, error });

// Usage
async function fetchUser(id: string): Promise<Result<User, 'NOT_FOUND' | 'NETWORK_ERROR'>> {
  try {
    const response = await fetch(`/api/users/${id}`);
    if (response.status === 404) {
      return Err('NOT_FOUND');
    }
    return Ok(await response.json());
  } catch {
    return Err('NETWORK_ERROR');
  }
}

// Caller handles explicitly
const result = await fetchUser('123');
if (result.ok) {
  console.log(result.value.name);
} else {
  switch (result.error) {
    case 'NOT_FOUND':
      console.log('User not found');
      break;
    case 'NETWORK_ERROR':
      console.log('Network error');
      break;
  }
}
```

### 6.2 Branded Types (Type Safety)

```typescript
// Prevent mixing up similar types
type Brand<T, B> = T & { __brand: B };

type UserId = Brand<string, 'UserId'>;
type OrderId = Brand<string, 'OrderId'>;

// Constructor functions
const UserId = (id: string): UserId => id as UserId;
const OrderId = (id: string): OrderId => id as OrderId;

// Now these are type-safe
function getUser(id: UserId): Promise<User> { /* ... */ }
function getOrder(id: OrderId): Promise<Order> { /* ... */ }

const userId = UserId('user-123');
const orderId = OrderId('order-456');

getUser(userId);  // OK
getUser(orderId); // Compile error!
```

---

## 7. Anti-Patterns to Avoid

### 7.1 Never Use

```typescript
// NEVER: any
let data: any; // Disables all type checking

// NEVER: Type assertions to lie
const user = data as User; // Could crash at runtime

// NEVER: Non-null assertion without check
const name = user!.name; // Could be undefined

// NEVER: @ts-ignore
// @ts-ignore
brokenCode(); // Hides real errors

// NEVER: Implicit any
function process(data) { } // Missing type annotation
```

### 7.2 Prefer Instead

```typescript
// PREFER: unknown for truly unknown data
let data: unknown;
if (isUser(data)) {
  console.log(data.name); // Safe after type guard
}

// PREFER: Explicit narrowing
const user = data as unknown;
if (isUser(user)) {
  console.log(user.name);
}

// PREFER: Optional chaining
const name = user?.name;

// PREFER: Fix the underlying issue
// Or use @ts-expect-error with explanation

// PREFER: Explicit types
function process(data: ProcessInput): ProcessOutput { }
```

---

## Quick Reference

### Type Narrowing Methods
1. `typeof` — primitives
2. `instanceof` — classes
3. `in` — property existence
4. Type predicates (`is`)
5. Assertion functions (`asserts`)
6. Discriminated unions
7. Truthiness checks

### Generic Constraints
- `T extends object` — must be object
- `T extends { id: string }` — must have id
- `K extends keyof T` — must be key of T
- `T extends (...args: any[]) => any` — must be function

### Utility Type Cheat Sheet
| Need | Use |
|------|-----|
| All optional | `Partial<T>` |
| All required | `Required<T>` |
| Immutable | `Readonly<T>` |
| Subset | `Pick<T, K>` |
| Exclude keys | `Omit<T, K>` |
| Key-value map | `Record<K, V>` |
| Remove null | `NonNullable<T>` |
| Function return | `ReturnType<T>` |
| Unwrap Promise | `Awaited<T>` |
