# Stripe Payments Integration

> **Sources**: [stripe/stripe-node](https://github.com/stripe/stripe-node) (3.8k⭐), [Stripe Docs](https://stripe.com/docs)
> **Auto-trigger**: Files containing `stripe`, `@stripe/stripe-js`, `checkout`, `subscription`, `webhook` in payment context

---

## Stripe Setup

### Installation
```bash
npm install stripe @stripe/stripe-js @stripe/react-stripe-js
```

### Environment Variables
```env
# .env.local - NEVER commit these
STRIPE_SECRET_KEY=sk_test_...
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_PRICE_ID=price_...
```

### Server-Side Client
```typescript
// lib/stripe.ts
import Stripe from 'stripe';

if (!process.env.STRIPE_SECRET_KEY) {
  throw new Error('STRIPE_SECRET_KEY is not set');
}

export const stripe = new Stripe(process.env.STRIPE_SECRET_KEY, {
  apiVersion: '2024-11-20.acacia', // Always pin API version
  typescript: true,
});
```

### Client-Side Setup
```typescript
// lib/stripe-client.ts
import { loadStripe } from '@stripe/stripe-js';

let stripePromise: Promise<Stripe | null>;

export const getStripe = () => {
  if (!stripePromise) {
    stripePromise = loadStripe(process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY!);
  }
  return stripePromise;
};
```

---

## Checkout Session (One-Time Payments)

### Create Checkout Session (Server)
```typescript
// app/api/checkout/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { stripe } from '@/lib/stripe';
import { auth } from '@/lib/auth';

export async function POST(req: NextRequest) {
  try {
    const session = await auth();
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const { priceId, quantity = 1 } = await req.json();

    // Validate price exists
    const price = await stripe.prices.retrieve(priceId);
    if (!price.active) {
      return NextResponse.json({ error: 'Invalid price' }, { status: 400 });
    }

    const checkoutSession = await stripe.checkout.sessions.create({
      mode: 'payment',
      customer_email: session.user.email!,
      client_reference_id: session.user.id,
      line_items: [
        {
          price: priceId,
          quantity,
        },
      ],
      success_url: `${process.env.NEXT_PUBLIC_APP_URL}/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${process.env.NEXT_PUBLIC_APP_URL}/canceled`,
      metadata: {
        userId: session.user.id,
      },
    });

    return NextResponse.json({ sessionId: checkoutSession.id });
  } catch (error) {
    console.error('Checkout error:', error);
    return NextResponse.json(
      { error: 'Failed to create checkout session' },
      { status: 500 }
    );
  }
}
```

### Redirect to Checkout (Client)
```typescript
// components/CheckoutButton.tsx
'use client';

import { useState } from 'react';
import { getStripe } from '@/lib/stripe-client';

export function CheckoutButton({ priceId }: { priceId: string }) {
  const [loading, setLoading] = useState(false);

  const handleCheckout = async () => {
    setLoading(true);
    try {
      const response = await fetch('/api/checkout', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ priceId }),
      });

      const { sessionId, error } = await response.json();
      if (error) throw new Error(error);

      const stripe = await getStripe();
      await stripe?.redirectToCheckout({ sessionId });
    } catch (error) {
      console.error('Checkout failed:', error);
      // Show error toast
    } finally {
      setLoading(false);
    }
  };

  return (
    <button onClick={handleCheckout} disabled={loading}>
      {loading ? 'Loading...' : 'Buy Now'}
    </button>
  );
}
```

---

## Subscriptions

### Create Subscription Checkout
```typescript
// app/api/subscribe/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { stripe } from '@/lib/stripe';
import { auth } from '@/lib/auth';
import { db } from '@/lib/db';

export async function POST(req: NextRequest) {
  const session = await auth();
  if (!session?.user) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const { priceId } = await req.json();

  // Get or create Stripe customer
  let customerId = await db.user.findUnique({
    where: { id: session.user.id },
    select: { stripeCustomerId: true },
  }).then(u => u?.stripeCustomerId);

  if (!customerId) {
    const customer = await stripe.customers.create({
      email: session.user.email!,
      metadata: { userId: session.user.id },
    });
    customerId = customer.id;

    await db.user.update({
      where: { id: session.user.id },
      data: { stripeCustomerId: customerId },
    });
  }

  const checkoutSession = await stripe.checkout.sessions.create({
    mode: 'subscription',
    customer: customerId,
    line_items: [{ price: priceId, quantity: 1 }],
    success_url: `${process.env.NEXT_PUBLIC_APP_URL}/dashboard?success=true`,
    cancel_url: `${process.env.NEXT_PUBLIC_APP_URL}/pricing`,
    subscription_data: {
      metadata: { userId: session.user.id },
    },
    // Allow promo codes
    allow_promotion_codes: true,
    // Collect billing address for tax
    billing_address_collection: 'required',
  });

  return NextResponse.json({ sessionId: checkoutSession.id });
}
```

### Customer Portal (Manage Subscription)
```typescript
// app/api/portal/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { stripe } from '@/lib/stripe';
import { auth } from '@/lib/auth';
import { db } from '@/lib/db';

export async function POST(req: NextRequest) {
  const session = await auth();
  if (!session?.user) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const user = await db.user.findUnique({
    where: { id: session.user.id },
    select: { stripeCustomerId: true },
  });

  if (!user?.stripeCustomerId) {
    return NextResponse.json({ error: 'No subscription found' }, { status: 400 });
  }

  const portalSession = await stripe.billingPortal.sessions.create({
    customer: user.stripeCustomerId,
    return_url: `${process.env.NEXT_PUBLIC_APP_URL}/dashboard`,
  });

  return NextResponse.json({ url: portalSession.url });
}
```

---

## Webhooks (CRITICAL)

### Webhook Handler
```typescript
// app/api/webhooks/stripe/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { headers } from 'next/headers';
import Stripe from 'stripe';
import { stripe } from '@/lib/stripe';
import { db } from '@/lib/db';

// Disable body parsing - Stripe needs raw body
export const config = {
  api: { bodyParser: false },
};

export async function POST(req: NextRequest) {
  const body = await req.text();
  const signature = headers().get('stripe-signature');

  if (!signature) {
    return NextResponse.json({ error: 'No signature' }, { status: 400 });
  }

  let event: Stripe.Event;

  try {
    event = stripe.webhooks.constructEvent(
      body,
      signature,
      process.env.STRIPE_WEBHOOK_SECRET!
    );
  } catch (err) {
    console.error('Webhook signature verification failed:', err);
    return NextResponse.json({ error: 'Invalid signature' }, { status: 400 });
  }

  try {
    switch (event.type) {
      case 'checkout.session.completed':
        await handleCheckoutComplete(event.data.object);
        break;

      case 'customer.subscription.created':
      case 'customer.subscription.updated':
        await handleSubscriptionChange(event.data.object);
        break;

      case 'customer.subscription.deleted':
        await handleSubscriptionDeleted(event.data.object);
        break;

      case 'invoice.payment_failed':
        await handlePaymentFailed(event.data.object);
        break;

      case 'invoice.payment_succeeded':
        await handlePaymentSucceeded(event.data.object);
        break;

      default:
        console.log(`Unhandled event type: ${event.type}`);
    }

    return NextResponse.json({ received: true });
  } catch (error) {
    console.error('Webhook handler error:', error);
    // Return 200 to prevent Stripe retries for handled errors
    return NextResponse.json({ error: 'Handler failed' }, { status: 500 });
  }
}

async function handleCheckoutComplete(session: Stripe.Checkout.Session) {
  const userId = session.metadata?.userId || session.client_reference_id;
  if (!userId) {
    console.error('No user ID in checkout session');
    return;
  }

  if (session.mode === 'subscription') {
    // Subscription created - handled by subscription.created event
    return;
  }

  // One-time payment
  await db.purchase.create({
    data: {
      userId,
      stripeSessionId: session.id,
      amount: session.amount_total!,
      status: 'completed',
    },
  });
}

async function handleSubscriptionChange(subscription: Stripe.Subscription) {
  const userId = subscription.metadata.userId;
  if (!userId) {
    // Try to get from customer
    const customer = await stripe.customers.retrieve(
      subscription.customer as string
    );
    if (customer.deleted) return;
  }

  const priceId = subscription.items.data[0]?.price.id;

  await db.subscription.upsert({
    where: { stripeSubscriptionId: subscription.id },
    create: {
      userId: userId!,
      stripeSubscriptionId: subscription.id,
      stripePriceId: priceId,
      status: subscription.status,
      currentPeriodEnd: new Date(subscription.current_period_end * 1000),
    },
    update: {
      stripePriceId: priceId,
      status: subscription.status,
      currentPeriodEnd: new Date(subscription.current_period_end * 1000),
    },
  });
}

async function handleSubscriptionDeleted(subscription: Stripe.Subscription) {
  await db.subscription.update({
    where: { stripeSubscriptionId: subscription.id },
    data: { status: 'canceled' },
  });
}

async function handlePaymentFailed(invoice: Stripe.Invoice) {
  const subscriptionId = invoice.subscription as string;
  if (!subscriptionId) return;

  // Send email notification about failed payment
  const subscription = await db.subscription.findUnique({
    where: { stripeSubscriptionId: subscriptionId },
    include: { user: true },
  });

  if (subscription) {
    // await sendPaymentFailedEmail(subscription.user.email);
    console.log(`Payment failed for user ${subscription.userId}`);
  }
}

async function handlePaymentSucceeded(invoice: Stripe.Invoice) {
  // Update subscription period, send receipt, etc.
  console.log(`Payment succeeded for invoice ${invoice.id}`);
}
```

### Testing Webhooks Locally
```bash
# Install Stripe CLI
# Forward webhooks to local server
stripe listen --forward-to localhost:3000/api/webhooks/stripe

# Trigger test events
stripe trigger checkout.session.completed
stripe trigger customer.subscription.created
stripe trigger invoice.payment_failed
```

---

## Idempotency (CRITICAL for Production)

### Idempotent Requests
```typescript
// Always use idempotency keys for mutating operations
import { randomUUID } from 'crypto';

// Store idempotency key with the operation
async function createPaymentIntent(orderId: string, amount: number) {
  const idempotencyKey = `pi_${orderId}`;

  const paymentIntent = await stripe.paymentIntents.create(
    {
      amount,
      currency: 'usd',
      metadata: { orderId },
    },
    {
      idempotencyKey,
    }
  );

  return paymentIntent;
}

// Webhook idempotency - track processed events
async function handleWebhook(event: Stripe.Event) {
  // Check if already processed
  const existing = await db.stripeEvent.findUnique({
    where: { eventId: event.id },
  });

  if (existing) {
    console.log(`Event ${event.id} already processed`);
    return { alreadyProcessed: true };
  }

  // Process event
  await processEvent(event);

  // Mark as processed
  await db.stripeEvent.create({
    data: {
      eventId: event.id,
      type: event.type,
      processedAt: new Date(),
    },
  });
}
```

---

## Embedded Checkout (Alternative to Redirect)

```typescript
// components/EmbeddedCheckout.tsx
'use client';

import { useEffect, useState } from 'react';
import {
  EmbeddedCheckoutProvider,
  EmbeddedCheckout,
} from '@stripe/react-stripe-js';
import { getStripe } from '@/lib/stripe-client';

export function EmbeddedCheckoutForm({ priceId }: { priceId: string }) {
  const [clientSecret, setClientSecret] = useState<string>();

  useEffect(() => {
    fetch('/api/checkout/embedded', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ priceId }),
    })
      .then(res => res.json())
      .then(data => setClientSecret(data.clientSecret));
  }, [priceId]);

  if (!clientSecret) {
    return <div>Loading...</div>;
  }

  return (
    <EmbeddedCheckoutProvider
      stripe={getStripe()}
      options={{ clientSecret }}
    >
      <EmbeddedCheckout />
    </EmbeddedCheckoutProvider>
  );
}
```

---

## Anti-Patterns

```typescript
// ❌ NEVER: Verify payment on client side only
const handlePayment = async () => {
  const result = await stripe.confirmPayment();
  if (result.paymentIntent.status === 'succeeded') {
    // Granting access here is INSECURE - use webhooks!
    grantAccess();
  }
};

// ❌ NEVER: Trust client-provided prices
const session = await stripe.checkout.sessions.create({
  line_items: [{
    price_data: {
      unit_amount: req.body.price, // User can manipulate this!
      currency: 'usd',
    },
  }],
});

// ✅ CORRECT: Always use server-defined prices
const session = await stripe.checkout.sessions.create({
  line_items: [{
    price: 'price_xxx', // Defined in Stripe Dashboard
    quantity: 1,
  }],
});

// ❌ NEVER: Skip webhook signature verification
export async function POST(req) {
  const event = await req.json(); // INSECURE - anyone can send fake events
}

// ✅ CORRECT: Always verify signatures
const event = stripe.webhooks.constructEvent(body, signature, secret);
```

---

## Quick Reference

### Webhook Events to Handle
| Event | Purpose |
|-------|---------|
| `checkout.session.completed` | Payment/subscription initiated |
| `customer.subscription.created` | New subscription |
| `customer.subscription.updated` | Plan change, renewal |
| `customer.subscription.deleted` | Cancellation |
| `invoice.payment_succeeded` | Successful charge |
| `invoice.payment_failed` | Failed charge (retry/dunning) |

### Testing Cards
| Number | Result |
|--------|--------|
| `4242424242424242` | Successful payment |
| `4000000000000002` | Card declined |
| `4000002500003155` | Requires 3D Secure |
| `4000000000009995` | Insufficient funds |

### Subscription Statuses
| Status | Meaning |
|--------|---------|
| `active` | Paid and current |
| `past_due` | Payment failed, in retry |
| `canceled` | Ended |
| `unpaid` | All retries failed |
| `trialing` | In trial period |

### Checklist
- [ ] Stripe API version pinned
- [ ] Webhook signature verification
- [ ] Idempotency keys for mutations
- [ ] Event processing idempotency (store event IDs)
- [ ] Customer portal configured
- [ ] Test mode vs live mode env vars
- [ ] Error handling with proper status codes
- [ ] Logging for debugging
