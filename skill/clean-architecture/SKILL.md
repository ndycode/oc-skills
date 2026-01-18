# Clean Architecture & Design Patterns

> **Sources**: 
> - [Sairyss/domain-driven-hexagon](https://github.com/Sairyss/domain-driven-hexagon) (14k+ stars)
> - [ryanmcdermott/clean-code-javascript](https://github.com/ryanmcdermott/clean-code-javascript) (94k+ stars)
> 
> **Auto-trigger**: Complex business logic, multi-layer architecture, domain modeling

---

## 1. Hexagonal Architecture (Ports & Adapters)

### 1.1 Layer Structure

```
src/
├── domain/                 # Core business logic (innermost)
│   ├── entities/
│   ├── value-objects/
│   ├── events/
│   └── services/
│
├── application/            # Use cases & ports
│   ├── use-cases/
│   ├── ports/
│   │   ├── inbound/        # Driving ports (interfaces)
│   │   └── outbound/       # Driven ports (interfaces)
│   └── services/
│
├── infrastructure/         # External adapters (outermost)
│   ├── adapters/
│   │   ├── inbound/        # Controllers, CLI
│   │   └── outbound/       # Database, APIs
│   ├── persistence/
│   └── http/
│
└── main.ts                 # Composition root
```

### 1.2 Dependency Rule

```
┌─────────────────────────────────────────────────┐
│           Infrastructure (Adapters)              │
│  ┌─────────────────────────────────────────┐    │
│  │        Application (Use Cases)          │    │
│  │  ┌─────────────────────────────────┐   │    │
│  │  │      Domain (Entities)          │   │    │
│  │  │                                 │   │    │
│  │  │  - No external dependencies     │   │    │
│  │  │  - Pure business logic          │   │    │
│  │  └─────────────────────────────────┘   │    │
│  │                                         │    │
│  │  - Orchestrates domain logic            │    │
│  │  - Defines ports (interfaces)           │    │
│  └─────────────────────────────────────────┘    │
│                                                  │
│  - Implements adapters                           │
│  - Framework-specific code                       │
└─────────────────────────────────────────────────┘

Dependencies point INWARD only.
```

---

## 2. Domain Layer

### 2.1 Entities

```typescript
// domain/entities/user.entity.ts
import { Entity } from '../base/entity';
import { UserId } from '../value-objects/user-id';
import { Email } from '../value-objects/email';
import { UserCreatedEvent } from '../events/user-created.event';

interface UserProps {
  email: Email;
  name: string;
  status: 'active' | 'inactive';
  createdAt: Date;
}

export class User extends Entity<UserId, UserProps> {
  private constructor(id: UserId, props: UserProps) {
    super(id, props);
  }

  // Factory method - validates invariants
  static create(props: { email: string; name: string }): User {
    const email = Email.create(props.email);
    const user = new User(UserId.generate(), {
      email,
      name: props.name,
      status: 'active',
      createdAt: new Date(),
    });

    user.addDomainEvent(new UserCreatedEvent(user));
    return user;
  }

  // Reconstitute from persistence
  static fromPersistence(id: string, props: UserProps): User {
    return new User(UserId.from(id), props);
  }

  // Business methods
  deactivate(): void {
    if (this.props.status === 'inactive') {
      throw new Error('User is already inactive');
    }
    this.props.status = 'inactive';
  }

  changeName(name: string): void {
    if (name.length < 2) {
      throw new Error('Name must be at least 2 characters');
    }
    this.props.name = name;
  }

  // Getters (no setters - use methods)
  get email(): Email {
    return this.props.email;
  }

  get name(): string {
    return this.props.name;
  }

  get isActive(): boolean {
    return this.props.status === 'active';
  }
}
```

### 2.2 Value Objects

```typescript
// domain/value-objects/email.ts
export class Email {
  private readonly value: string;

  private constructor(value: string) {
    this.value = value;
  }

  static create(value: string): Email {
    if (!this.isValid(value)) {
      throw new Error('Invalid email format');
    }
    return new Email(value.toLowerCase().trim());
  }

  private static isValid(value: string): boolean {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
  }

  equals(other: Email): boolean {
    return this.value === other.value;
  }

  toString(): string {
    return this.value;
  }
}

// domain/value-objects/money.ts
export class Money {
  private constructor(
    private readonly amount: number,
    private readonly currency: string
  ) {}

  static create(amount: number, currency: string): Money {
    if (amount < 0) {
      throw new Error('Amount cannot be negative');
    }
    return new Money(Math.round(amount * 100) / 100, currency.toUpperCase());
  }

  add(other: Money): Money {
    this.ensureSameCurrency(other);
    return new Money(this.amount + other.amount, this.currency);
  }

  subtract(other: Money): Money {
    this.ensureSameCurrency(other);
    if (this.amount < other.amount) {
      throw new Error('Insufficient funds');
    }
    return new Money(this.amount - other.amount, this.currency);
  }

  private ensureSameCurrency(other: Money): void {
    if (this.currency !== other.currency) {
      throw new Error('Currency mismatch');
    }
  }

  equals(other: Money): boolean {
    return this.amount === other.amount && this.currency === other.currency;
  }
}
```

### 2.3 Domain Events

```typescript
// domain/events/domain-event.ts
export abstract class DomainEvent {
  readonly occurredAt: Date;
  readonly eventId: string;

  constructor() {
    this.occurredAt = new Date();
    this.eventId = crypto.randomUUID();
  }

  abstract get eventName(): string;
}

// domain/events/user-created.event.ts
export class UserCreatedEvent extends DomainEvent {
  constructor(
    public readonly user: User
  ) {
    super();
  }

  get eventName(): string {
    return 'user.created';
  }
}

// domain/base/entity.ts
export abstract class Entity<TId, TProps> {
  private _domainEvents: DomainEvent[] = [];

  constructor(
    protected readonly id: TId,
    protected props: TProps
  ) {}

  protected addDomainEvent(event: DomainEvent): void {
    this._domainEvents.push(event);
  }

  pullDomainEvents(): DomainEvent[] {
    const events = [...this._domainEvents];
    this._domainEvents = [];
    return events;
  }
}
```

---

## 3. Application Layer

### 3.1 Use Cases

```typescript
// application/use-cases/create-user.use-case.ts
import { User } from '../../domain/entities/user.entity';
import { UserRepository } from '../ports/outbound/user.repository';
import { EventPublisher } from '../ports/outbound/event-publisher';

interface CreateUserCommand {
  email: string;
  name: string;
}

interface CreateUserResult {
  userId: string;
}

export class CreateUserUseCase {
  constructor(
    private readonly userRepository: UserRepository,
    private readonly eventPublisher: EventPublisher
  ) {}

  async execute(command: CreateUserCommand): Promise<CreateUserResult> {
    // Check for existing user
    const existing = await this.userRepository.findByEmail(command.email);
    if (existing) {
      throw new Error('User with this email already exists');
    }

    // Create domain entity
    const user = User.create({
      email: command.email,
      name: command.name,
    });

    // Persist
    await this.userRepository.save(user);

    // Publish domain events
    const events = user.pullDomainEvents();
    await this.eventPublisher.publishAll(events);

    return { userId: user.id.toString() };
  }
}
```

### 3.2 Ports (Interfaces)

```typescript
// application/ports/outbound/user.repository.ts
export interface UserRepository {
  findById(id: UserId): Promise<User | null>;
  findByEmail(email: string): Promise<User | null>;
  save(user: User): Promise<void>;
  delete(id: UserId): Promise<void>;
}

// application/ports/outbound/event-publisher.ts
export interface EventPublisher {
  publish(event: DomainEvent): Promise<void>;
  publishAll(events: DomainEvent[]): Promise<void>;
}

// application/ports/inbound/create-user.port.ts
export interface CreateUserPort {
  execute(command: CreateUserCommand): Promise<CreateUserResult>;
}
```

---

## 4. Infrastructure Layer

### 4.1 Repository Adapter

```typescript
// infrastructure/adapters/outbound/prisma-user.repository.ts
import { PrismaClient } from '@prisma/client';
import { User } from '../../../domain/entities/user.entity';
import { UserRepository } from '../../../application/ports/outbound/user.repository';
import { Email } from '../../../domain/value-objects/email';

export class PrismaUserRepository implements UserRepository {
  constructor(private readonly prisma: PrismaClient) {}

  async findById(id: UserId): Promise<User | null> {
    const data = await this.prisma.user.findUnique({
      where: { id: id.toString() },
    });

    if (!data) return null;

    return this.toDomain(data);
  }

  async findByEmail(email: string): Promise<User | null> {
    const data = await this.prisma.user.findUnique({
      where: { email },
    });

    if (!data) return null;

    return this.toDomain(data);
  }

  async save(user: User): Promise<void> {
    const data = this.toPersistence(user);

    await this.prisma.user.upsert({
      where: { id: data.id },
      create: data,
      update: data,
    });
  }

  async delete(id: UserId): Promise<void> {
    await this.prisma.user.delete({
      where: { id: id.toString() },
    });
  }

  // Mapping methods
  private toDomain(data: PrismaUser): User {
    return User.fromPersistence(data.id, {
      email: Email.create(data.email),
      name: data.name,
      status: data.status,
      createdAt: data.createdAt,
    });
  }

  private toPersistence(user: User): PrismaUser {
    return {
      id: user.id.toString(),
      email: user.email.toString(),
      name: user.name,
      status: user.isActive ? 'active' : 'inactive',
      createdAt: user.createdAt,
    };
  }
}
```

### 4.2 Controller Adapter

```typescript
// infrastructure/adapters/inbound/user.controller.ts
import { Request, Response } from 'express';
import { CreateUserUseCase } from '../../../application/use-cases/create-user.use-case';

export class UserController {
  constructor(private readonly createUserUseCase: CreateUserUseCase) {}

  async create(req: Request, res: Response) {
    try {
      const result = await this.createUserUseCase.execute({
        email: req.body.email,
        name: req.body.name,
      });

      res.status(201).json(result);
    } catch (error) {
      if (error.message.includes('already exists')) {
        res.status(409).json({ error: error.message });
      } else {
        res.status(500).json({ error: 'Internal server error' });
      }
    }
  }
}
```

### 4.3 Composition Root

```typescript
// main.ts - Wire everything together
import { PrismaClient } from '@prisma/client';
import { PrismaUserRepository } from './infrastructure/adapters/outbound/prisma-user.repository';
import { EventBusPublisher } from './infrastructure/adapters/outbound/event-bus.publisher';
import { CreateUserUseCase } from './application/use-cases/create-user.use-case';
import { UserController } from './infrastructure/adapters/inbound/user.controller';

// Create infrastructure
const prisma = new PrismaClient();
const userRepository = new PrismaUserRepository(prisma);
const eventPublisher = new EventBusPublisher();

// Create use cases
const createUserUseCase = new CreateUserUseCase(userRepository, eventPublisher);

// Create controllers
const userController = new UserController(createUserUseCase);

// Wire to router
app.post('/users', (req, res) => userController.create(req, res));
```

---

## 5. SOLID Principles

### 5.1 Single Responsibility

```typescript
// BAD - Multiple responsibilities
class UserService {
  createUser() { }
  sendEmail() { }     // Email responsibility
  logActivity() { }   // Logging responsibility
  validateUser() { }  // Validation responsibility
}

// GOOD - Single responsibility each
class UserService {
  constructor(
    private validator: UserValidator,
    private emailService: EmailService,
    private logger: Logger
  ) {}

  async createUser(data: CreateUserDto) {
    this.validator.validate(data);
    const user = await this.repository.save(data);
    await this.emailService.sendWelcome(user);
    this.logger.info('User created', { userId: user.id });
    return user;
  }
}
```

### 5.2 Open/Closed

```typescript
// BAD - Modifying class for new types
class AreaCalculator {
  calculate(shape: Shape) {
    if (shape.type === 'circle') {
      return Math.PI * shape.radius ** 2;
    } else if (shape.type === 'square') {
      return shape.side ** 2;
    }
    // Must modify for each new shape
  }
}

// GOOD - Open for extension, closed for modification
interface Shape {
  area(): number;
}

class Circle implements Shape {
  constructor(private radius: number) {}
  area(): number {
    return Math.PI * this.radius ** 2;
  }
}

class Square implements Shape {
  constructor(private side: number) {}
  area(): number {
    return this.side ** 2;
  }
}

// New shapes don't require modifying existing code
class Triangle implements Shape {
  constructor(private base: number, private height: number) {}
  area(): number {
    return (this.base * this.height) / 2;
  }
}
```

### 5.3 Liskov Substitution

```typescript
// BAD - Subclass violates parent behavior
class Rectangle {
  setWidth(w: number) { this.width = w; }
  setHeight(h: number) { this.height = h; }
  area() { return this.width * this.height; }
}

class Square extends Rectangle {
  setWidth(w: number) {
    this.width = w;
    this.height = w; // Violates expectation!
  }
}

// GOOD - Use composition or interfaces
interface Shape {
  area(): number;
}

class Rectangle implements Shape {
  constructor(private width: number, private height: number) {}
  area() { return this.width * this.height; }
}

class Square implements Shape {
  constructor(private side: number) {}
  area() { return this.side ** 2; }
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

// Robot can't eat or sleep!
class Robot implements Worker {
  work() { }
  eat() { throw new Error('Cannot eat'); }
  sleep() { throw new Error('Cannot sleep'); }
}

// GOOD - Segregated interfaces
interface Workable {
  work(): void;
}

interface Eatable {
  eat(): void;
}

class Human implements Workable, Eatable {
  work() { }
  eat() { }
}

class Robot implements Workable {
  work() { }
}
```

### 5.5 Dependency Inversion

```typescript
// BAD - High-level depends on low-level
class OrderService {
  private database = new MySQLDatabase();

  save(order: Order) {
    this.database.insert(order);
  }
}

// GOOD - Both depend on abstraction
interface Database {
  insert(data: unknown): Promise<void>;
}

class OrderService {
  constructor(private database: Database) {}

  save(order: Order) {
    this.database.insert(order);
  }
}

// Inject any implementation
new OrderService(new MySQLDatabase());
new OrderService(new PostgresDatabase());
new OrderService(new InMemoryDatabase());
```

---

## 6. Design Patterns

### 6.1 Factory Pattern

```typescript
interface PaymentProcessor {
  process(amount: number): Promise<PaymentResult>;
}

class StripeProcessor implements PaymentProcessor { }
class PayPalProcessor implements PaymentProcessor { }

class PaymentProcessorFactory {
  static create(type: 'stripe' | 'paypal'): PaymentProcessor {
    switch (type) {
      case 'stripe':
        return new StripeProcessor();
      case 'paypal':
        return new PayPalProcessor();
      default:
        throw new Error(`Unknown payment type: ${type}`);
    }
  }
}
```

### 6.2 Strategy Pattern

```typescript
interface PricingStrategy {
  calculate(basePrice: number): number;
}

class RegularPricing implements PricingStrategy {
  calculate(basePrice: number): number {
    return basePrice;
  }
}

class PremiumPricing implements PricingStrategy {
  calculate(basePrice: number): number {
    return basePrice * 0.8; // 20% discount
  }
}

class Order {
  constructor(private pricingStrategy: PricingStrategy) {}

  getTotal(basePrice: number): number {
    return this.pricingStrategy.calculate(basePrice);
  }
}
```

### 6.3 Repository Pattern

```typescript
interface Repository<T, TId> {
  findById(id: TId): Promise<T | null>;
  findAll(): Promise<T[]>;
  save(entity: T): Promise<void>;
  delete(id: TId): Promise<void>;
}

interface UserRepository extends Repository<User, UserId> {
  findByEmail(email: string): Promise<User | null>;
  findActive(): Promise<User[]>;
}
```

### 6.4 Unit of Work Pattern

```typescript
interface UnitOfWork {
  users: UserRepository;
  orders: OrderRepository;
  commit(): Promise<void>;
  rollback(): Promise<void>;
}

class PrismaUnitOfWork implements UnitOfWork {
  private tx: PrismaClient;

  users: UserRepository;
  orders: OrderRepository;

  constructor(prisma: PrismaClient) {
    this.tx = prisma;
    this.users = new PrismaUserRepository(this.tx);
    this.orders = new PrismaOrderRepository(this.tx);
  }

  async commit(): Promise<void> {
    await this.tx.$transaction([
      // All pending operations
    ]);
  }

  async rollback(): Promise<void> {
    // Discard pending changes
  }
}

// Usage
async function transferMoney(uow: UnitOfWork) {
  const from = await uow.users.findById(fromId);
  const to = await uow.users.findById(toId);

  from.withdraw(amount);
  to.deposit(amount);

  await uow.users.save(from);
  await uow.users.save(to);
  await uow.commit(); // Atomic transaction
}
```

---

## Quick Reference

### Layer Dependencies
```
Infrastructure → Application → Domain
     ↓               ↓           ↓
  Adapters       Use Cases    Entities
  Database       Services     Value Objects
  HTTP/CLI       Ports        Domain Events
```

### When to Use Each Pattern

| Pattern | Use When |
|---------|----------|
| Entity | Has identity, lifecycle, business rules |
| Value Object | Immutable, no identity, validated |
| Factory | Complex object creation logic |
| Repository | Abstract data access |
| Strategy | Interchangeable algorithms |
| Unit of Work | Atomic transactions |

### Domain Checklist
- [ ] Entities are rich (behavior, not just data)
- [ ] Value objects are immutable
- [ ] No framework dependencies in domain
- [ ] Business rules in domain layer
- [ ] Use cases orchestrate domain
- [ ] Adapters handle I/O
