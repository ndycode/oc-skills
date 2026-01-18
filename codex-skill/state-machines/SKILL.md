---
name: state-machines
description: State machines with XState for complex flows
metadata:
  short-description: State machines
---

# State Machines (XState)

> **Sources**: [XState](https://github.com/statelyai/xstate) (27k⭐), [Stately.ai](https://stately.ai/docs)
> **Auto-trigger**: Files containing `xstate`, state machines, `createMachine`, `useMachine`, complex workflows, multi-step forms, checkout flows

---

## When to Use State Machines

| Use Case | Without State Machine | With State Machine |
|----------|----------------------|-------------------|
| Multi-step form | Spaghetti if/else | Clear states |
| Checkout flow | Error-prone state | Guaranteed valid |
| Authentication | Race conditions | Sequential guards |
| Complex UI | Impossible states possible | Impossible states impossible |

---

## Installation

```bash
npm install xstate @xstate/react
```

---

## Basic Machine

### Definition
```typescript
// machines/toggle.ts
import { createMachine } from 'xstate';

export const toggleMachine = createMachine({
  id: 'toggle',
  initial: 'inactive',
  states: {
    inactive: {
      on: { TOGGLE: 'active' },
    },
    active: {
      on: { TOGGLE: 'inactive' },
    },
  },
});
```

### React Usage
```typescript
// components/Toggle.tsx
'use client';

import { useMachine } from '@xstate/react';
import { toggleMachine } from '@/machines/toggle';

export function Toggle() {
  const [state, send] = useMachine(toggleMachine);

  return (
    <button onClick={() => send({ type: 'TOGGLE' })}>
      {state.matches('active') ? 'ON' : 'OFF'}
    </button>
  );
}
```

---

## Multi-Step Form Machine

### Machine Definition
```typescript
// machines/checkout.ts
import { createMachine, assign } from 'xstate';

interface CheckoutContext {
  cart: CartItem[];
  shippingAddress?: Address;
  billingAddress?: Address;
  paymentMethod?: PaymentMethod;
  orderId?: string;
  error?: string;
}

type CheckoutEvent =
  | { type: 'NEXT' }
  | { type: 'BACK' }
  | { type: 'SET_SHIPPING'; address: Address }
  | { type: 'SET_BILLING'; address: Address }
  | { type: 'SET_PAYMENT'; method: PaymentMethod }
  | { type: 'SUBMIT' }
  | { type: 'RETRY' };

export const checkoutMachine = createMachine({
  id: 'checkout',
  initial: 'cart',
  context: {
    cart: [],
    shippingAddress: undefined,
    billingAddress: undefined,
    paymentMethod: undefined,
    orderId: undefined,
    error: undefined,
  } as CheckoutContext,
  states: {
    cart: {
      on: {
        NEXT: {
          target: 'shipping',
          guard: 'hasItemsInCart',
        },
      },
    },
    shipping: {
      on: {
        SET_SHIPPING: {
          actions: assign({
            shippingAddress: ({ event }) => event.address,
          }),
        },
        NEXT: {
          target: 'billing',
          guard: 'hasShippingAddress',
        },
        BACK: 'cart',
      },
    },
    billing: {
      on: {
        SET_BILLING: {
          actions: assign({
            billingAddress: ({ event }) => event.address,
          }),
        },
        NEXT: {
          target: 'payment',
          guard: 'hasBillingAddress',
        },
        BACK: 'shipping',
      },
    },
    payment: {
      on: {
        SET_PAYMENT: {
          actions: assign({
            paymentMethod: ({ event }) => event.method,
          }),
        },
        SUBMIT: {
          target: 'processing',
          guard: 'hasPaymentMethod',
        },
        BACK: 'billing',
      },
    },
    processing: {
      invoke: {
        id: 'submitOrder',
        src: 'submitOrder',
        onDone: {
          target: 'success',
          actions: assign({
            orderId: ({ event }) => event.output.orderId,
          }),
        },
        onError: {
          target: 'error',
          actions: assign({
            error: ({ event }) => event.error.message,
          }),
        },
      },
    },
    success: {
      type: 'final',
    },
    error: {
      on: {
        RETRY: 'payment',
        BACK: 'payment',
      },
    },
  },
}, {
  guards: {
    hasItemsInCart: ({ context }) => context.cart.length > 0,
    hasShippingAddress: ({ context }) => !!context.shippingAddress,
    hasBillingAddress: ({ context }) => !!context.billingAddress,
    hasPaymentMethod: ({ context }) => !!context.paymentMethod,
  },
  actors: {
    submitOrder: async ({ context }) => {
      const response = await fetch('/api/orders', {
        method: 'POST',
        body: JSON.stringify({
          cart: context.cart,
          shipping: context.shippingAddress,
          billing: context.billingAddress,
          payment: context.paymentMethod,
        }),
      });
      if (!response.ok) throw new Error('Order failed');
      return response.json();
    },
  },
});
```

### React Component
```typescript
// components/Checkout.tsx
'use client';

import { useMachine } from '@xstate/react';
import { checkoutMachine } from '@/machines/checkout';

export function Checkout() {
  const [state, send] = useMachine(checkoutMachine);

  const currentStep = state.value;
  const { cart, shippingAddress, error, orderId } = state.context;

  return (
    <div>
      {/* Progress indicator */}
      <Steps current={currentStep} />

      {/* Step content */}
      {state.matches('cart') && (
        <CartStep
          cart={cart}
          onNext={() => send({ type: 'NEXT' })}
        />
      )}

      {state.matches('shipping') && (
        <ShippingStep
          address={shippingAddress}
          onSubmit={(address) => {
            send({ type: 'SET_SHIPPING', address });
            send({ type: 'NEXT' });
          }}
          onBack={() => send({ type: 'BACK' })}
        />
      )}

      {state.matches('billing') && (
        <BillingStep
          onSubmit={(address) => {
            send({ type: 'SET_BILLING', address });
            send({ type: 'NEXT' });
          }}
          onBack={() => send({ type: 'BACK' })}
        />
      )}

      {state.matches('payment') && (
        <PaymentStep
          onSubmit={(method) => {
            send({ type: 'SET_PAYMENT', method });
            send({ type: 'SUBMIT' });
          }}
          onBack={() => send({ type: 'BACK' })}
        />
      )}

      {state.matches('processing') && <LoadingSpinner />}

      {state.matches('success') && (
        <SuccessMessage orderId={orderId!} />
      )}

      {state.matches('error') && (
        <ErrorMessage
          error={error!}
          onRetry={() => send({ type: 'RETRY' })}
        />
      )}
    </div>
  );
}
```

---

## Authentication Machine

```typescript
// machines/auth.ts
import { createMachine, assign } from 'xstate';

interface AuthContext {
  user: User | null;
  error: string | null;
  returnTo: string | null;
}

type AuthEvent =
  | { type: 'LOGIN'; email: string; password: string }
  | { type: 'LOGOUT' }
  | { type: 'SIGNUP'; email: string; password: string; name: string }
  | { type: 'FORGOT_PASSWORD'; email: string }
  | { type: 'RESET_PASSWORD'; token: string; password: string }
  | { type: 'SESSION_EXPIRED' }
  | { type: 'REFRESH_TOKEN' };

export const authMachine = createMachine({
  id: 'auth',
  initial: 'checking',
  context: {
    user: null,
    error: null,
    returnTo: null,
  } as AuthContext,
  states: {
    checking: {
      invoke: {
        src: 'checkSession',
        onDone: {
          target: 'authenticated',
          actions: assign({ user: ({ event }) => event.output }),
        },
        onError: 'unauthenticated',
      },
    },
    unauthenticated: {
      on: {
        LOGIN: 'loggingIn',
        SIGNUP: 'signingUp',
        FORGOT_PASSWORD: 'forgotPassword',
      },
    },
    loggingIn: {
      invoke: {
        src: 'login',
        input: ({ event }) => ({
          email: event.email,
          password: event.password,
        }),
        onDone: {
          target: 'authenticated',
          actions: assign({
            user: ({ event }) => event.output,
            error: null,
          }),
        },
        onError: {
          target: 'unauthenticated',
          actions: assign({
            error: ({ event }) => event.error.message,
          }),
        },
      },
    },
    signingUp: {
      invoke: {
        src: 'signup',
        input: ({ event }) => ({
          email: event.email,
          password: event.password,
          name: event.name,
        }),
        onDone: {
          target: 'authenticated',
          actions: assign({ user: ({ event }) => event.output }),
        },
        onError: {
          target: 'unauthenticated',
          actions: assign({ error: ({ event }) => event.error.message }),
        },
      },
    },
    forgotPassword: {
      invoke: {
        src: 'sendResetEmail',
        input: ({ event }) => ({ email: event.email }),
        onDone: 'resetEmailSent',
        onError: {
          target: 'unauthenticated',
          actions: assign({ error: ({ event }) => event.error.message }),
        },
      },
    },
    resetEmailSent: {
      on: {
        RESET_PASSWORD: 'resettingPassword',
      },
    },
    resettingPassword: {
      invoke: {
        src: 'resetPassword',
        input: ({ event }) => ({
          token: event.token,
          password: event.password,
        }),
        onDone: 'unauthenticated',
        onError: {
          target: 'resetEmailSent',
          actions: assign({ error: ({ event }) => event.error.message }),
        },
      },
    },
    authenticated: {
      on: {
        LOGOUT: 'loggingOut',
        SESSION_EXPIRED: 'refreshing',
      },
    },
    refreshing: {
      invoke: {
        src: 'refreshToken',
        onDone: 'authenticated',
        onError: {
          target: 'unauthenticated',
          actions: assign({ user: null }),
        },
      },
    },
    loggingOut: {
      invoke: {
        src: 'logout',
        onDone: {
          target: 'unauthenticated',
          actions: assign({ user: null }),
        },
        onError: {
          target: 'unauthenticated',
          actions: assign({ user: null }),
        },
      },
    },
  },
}, {
  actors: {
    checkSession: async () => {
      const response = await fetch('/api/auth/session');
      if (!response.ok) throw new Error('No session');
      return response.json();
    },
    login: async ({ input }) => {
      const response = await fetch('/api/auth/login', {
        method: 'POST',
        body: JSON.stringify(input),
      });
      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.message);
      }
      return response.json();
    },
    logout: async () => {
      await fetch('/api/auth/logout', { method: 'POST' });
    },
    // ... other actors
  },
});
```

---

## Upload Machine with Parallel States

```typescript
// machines/upload.ts
import { createMachine, assign } from 'xstate';

interface UploadContext {
  files: File[];
  uploadedFiles: UploadedFile[];
  currentIndex: number;
  progress: number;
  error: string | null;
}

export const uploadMachine = createMachine({
  id: 'upload',
  initial: 'idle',
  context: {
    files: [],
    uploadedFiles: [],
    currentIndex: 0,
    progress: 0,
    error: null,
  } as UploadContext,
  states: {
    idle: {
      on: {
        SELECT_FILES: {
          target: 'validating',
          actions: assign({
            files: ({ event }) => event.files,
            uploadedFiles: [],
            currentIndex: 0,
            error: null,
          }),
        },
      },
    },
    validating: {
      invoke: {
        src: 'validateFiles',
        onDone: 'uploading',
        onError: {
          target: 'idle',
          actions: assign({ error: ({ event }) => event.error.message }),
        },
      },
    },
    uploading: {
      initial: 'active',
      states: {
        active: {
          invoke: {
            src: 'uploadFile',
            onDone: {
              actions: [
                assign({
                  uploadedFiles: ({ context, event }) => [
                    ...context.uploadedFiles,
                    event.output,
                  ],
                  currentIndex: ({ context }) => context.currentIndex + 1,
                  progress: ({ context }) =>
                    ((context.currentIndex + 1) / context.files.length) * 100,
                }),
              ],
              target: 'checkComplete',
            },
            onError: 'failed',
          },
        },
        checkComplete: {
          always: [
            {
              target: '#upload.complete',
              guard: ({ context }) =>
                context.currentIndex >= context.files.length,
            },
            { target: 'active' },
          ],
        },
        failed: {
          on: {
            RETRY: 'active',
            SKIP: {
              target: 'checkComplete',
              actions: assign({
                currentIndex: ({ context }) => context.currentIndex + 1,
              }),
            },
            CANCEL: '#upload.idle',
          },
        },
      },
      on: {
        CANCEL: {
          target: 'idle',
          actions: assign({
            files: [],
            uploadedFiles: [],
            currentIndex: 0,
          }),
        },
      },
    },
    complete: {
      on: {
        RESET: {
          target: 'idle',
          actions: assign({
            files: [],
            uploadedFiles: [],
            currentIndex: 0,
            progress: 0,
          }),
        },
      },
    },
  },
}, {
  actors: {
    validateFiles: async ({ context }) => {
      for (const file of context.files) {
        if (file.size > 10 * 1024 * 1024) {
          throw new Error(`${file.name} exceeds 10MB limit`);
        }
      }
    },
    uploadFile: async ({ context }) => {
      const file = context.files[context.currentIndex];
      const formData = new FormData();
      formData.append('file', file);
      
      const response = await fetch('/api/upload', {
        method: 'POST',
        body: formData,
      });
      
      if (!response.ok) throw new Error('Upload failed');
      return response.json();
    },
  },
});
```

---

## Spawning Child Machines

```typescript
// machines/order.ts
import { createMachine, assign, spawn } from 'xstate';
import { paymentMachine } from './payment';
import { shippingMachine } from './shipping';

export const orderMachine = createMachine({
  id: 'order',
  initial: 'pending',
  context: {
    orderId: null,
    paymentRef: null,
    shippingRef: null,
  },
  states: {
    pending: {
      on: {
        CONFIRM: {
          target: 'processing',
          actions: assign({
            paymentRef: ({ spawn }) => spawn(paymentMachine),
            shippingRef: ({ spawn }) => spawn(shippingMachine),
          }),
        },
      },
    },
    processing: {
      type: 'parallel',
      states: {
        payment: {
          initial: 'pending',
          states: {
            pending: {
              on: {
                'PAYMENT.SUCCESS': 'completed',
                'PAYMENT.FAILED': 'failed',
              },
            },
            completed: { type: 'final' },
            failed: {},
          },
        },
        shipping: {
          initial: 'pending',
          states: {
            pending: {
              on: {
                'SHIPPING.CONFIRMED': 'confirmed',
              },
            },
            confirmed: { type: 'final' },
          },
        },
      },
      onDone: 'completed',
    },
    completed: {
      type: 'final',
    },
  },
});
```

---

## Persisting State

```typescript
// lib/machine-persistence.ts
import { createActor, type AnyActorLogic, type SnapshotFrom } from 'xstate';

export function createPersistedActor<T extends AnyActorLogic>(
  machine: T,
  storageKey: string
) {
  // Load persisted state
  const persistedState = typeof window !== 'undefined'
    ? localStorage.getItem(storageKey)
    : null;

  const actor = createActor(machine, {
    snapshot: persistedState ? JSON.parse(persistedState) : undefined,
  });

  // Persist on state changes
  actor.subscribe((snapshot) => {
    localStorage.setItem(storageKey, JSON.stringify(snapshot));
  });

  return actor;
}

// Usage
const checkoutActor = createPersistedActor(
  checkoutMachine,
  'checkout-state'
);
checkoutActor.start();
```

---

## Testing

```typescript
// machines/__tests__/checkout.test.ts
import { createActor } from 'xstate';
import { checkoutMachine } from '../checkout';

describe('Checkout Machine', () => {
  it('should start in cart state', () => {
    const actor = createActor(checkoutMachine);
    actor.start();
    
    expect(actor.getSnapshot().value).toBe('cart');
  });

  it('should not proceed from cart without items', () => {
    const actor = createActor(checkoutMachine);
    actor.start();
    
    actor.send({ type: 'NEXT' });
    
    expect(actor.getSnapshot().value).toBe('cart'); // Still in cart
  });

  it('should proceed through all steps', async () => {
    const actor = createActor(checkoutMachine.provide({
      actors: {
        submitOrder: async () => ({ orderId: '123' }),
      },
    }));
    actor.start();

    // Add item to context
    actor.send({ type: 'NEXT' }); // Won't work without items
    
    // Test with items
    const actorWithItems = createActor(checkoutMachine.provide({
      actors: {
        submitOrder: async () => ({ orderId: '123' }),
      },
    }), {
      input: { cart: [{ id: '1', name: 'Item', price: 10 }] },
    });
    
    actorWithItems.start();
    actorWithItems.send({ type: 'NEXT' });
    expect(actorWithItems.getSnapshot().value).toBe('shipping');
  });
});
```

---

## Anti-Patterns

```typescript
// ❌ NEVER: Store derived state
context: {
  items: [],
  itemCount: 0, // Derived from items.length!
  hasItems: false, // Derived!
}

// ✅ CORRECT: Derive in selectors
const hasItems = state.context.items.length > 0;

// ❌ NEVER: Mutate context directly
actions: assign({
  items: ({ context }) => {
    context.items.push(newItem); // Mutation!
    return context.items;
  },
})

// ✅ CORRECT: Return new array
actions: assign({
  items: ({ context }) => [...context.items, newItem],
})

// ❌ NEVER: Complex logic in guards
guards: {
  canProceed: ({ context }) => {
    // 50 lines of validation logic...
  },
}

// ✅ CORRECT: Simple guards, complex logic in actions/services
guards: {
  isValid: ({ context }) => context.validationResult.isValid,
}

// ❌ NEVER: Skip typing
const machine = createMachine({
  context: {},
  // No types = runtime errors
});

// ✅ CORRECT: Full typing
const machine = createMachine({
  types: {} as {
    context: CheckoutContext;
    events: CheckoutEvent;
  },
  context: initialContext,
});
```

---

## Quick Reference

### State Node Types
| Type | Purpose |
|------|---------|
| `atomic` | Simple state (default) |
| `compound` | Has child states |
| `parallel` | Multiple active children |
| `final` | Terminal state |
| `history` | Remember last child |

### Actions
| Action | Purpose |
|--------|---------|
| `assign` | Update context |
| `raise` | Send event to self |
| `sendTo` | Send to another actor |
| `log` | Log for debugging |
| `stop` | Stop child actor |

### Transition Types
| Type | Syntax |
|------|--------|
| Event | `on: { EVENT: 'target' }` |
| Always | `always: 'target'` |
| After | `after: { 1000: 'target' }` |
| Done | `onDone: 'target'` |
| Error | `onError: 'target'` |

### Checklist
- [ ] Types for context and events
- [ ] Guards for conditional transitions
- [ ] Actions for side effects
- [ ] Actors for async operations
- [ ] Final states for completion
- [ ] Error states for failure handling
- [ ] Tests for state transitions
- [ ] Visualize with Stately.ai
