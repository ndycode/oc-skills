# Transactional Email

> **Sources**: [Resend](https://github.com/resend/resend-node) (800⭐), [React Email](https://github.com/resend/react-email) (14k⭐), [Nodemailer](https://github.com/nodemailer/nodemailer) (17k⭐)
> **Auto-trigger**: Files containing email sending, `resend`, `react-email`, `nodemailer`, email templates, transactional emails

---

## Technology Selection

| Tool | Best For | Pricing |
|------|----------|---------|
| **Resend** | Modern, developer-first | Free tier |
| **SendGrid** | Enterprise, scale | Free tier |
| **Postmark** | Transactional focus | Pay per email |
| **AWS SES** | High volume, low cost | Pay per email |
| **Nodemailer** | Self-hosted SMTP | Free |

---

## Resend Setup

### Installation
```bash
npm install resend @react-email/components
```

### Client Configuration
```typescript
// lib/email.ts
import { Resend } from 'resend';

if (!process.env.RESEND_API_KEY) {
  throw new Error('RESEND_API_KEY is not set');
}

export const resend = new Resend(process.env.RESEND_API_KEY);

export const EMAIL_FROM = 'MyApp <noreply@myapp.com>';
```

---

## React Email Templates

### Project Structure
```
├── emails/
│   ├── components/
│   │   ├── Button.tsx
│   │   ├── Footer.tsx
│   │   └── Header.tsx
│   ├── welcome.tsx
│   ├── password-reset.tsx
│   ├── order-confirmation.tsx
│   └── invoice.tsx
```

### Base Components
```typescript
// emails/components/Button.tsx
import { Button as EmailButton } from '@react-email/components';

interface ButtonProps {
  href: string;
  children: React.ReactNode;
}

export function Button({ href, children }: ButtonProps) {
  return (
    <EmailButton
      href={href}
      style={{
        backgroundColor: '#000',
        borderRadius: '8px',
        color: '#fff',
        fontSize: '16px',
        fontWeight: 600,
        textDecoration: 'none',
        textAlign: 'center' as const,
        display: 'inline-block',
        padding: '12px 24px',
      }}
    >
      {children}
    </EmailButton>
  );
}

// emails/components/Footer.tsx
import { Section, Text, Link } from '@react-email/components';

export function Footer() {
  return (
    <Section style={{ marginTop: '32px', textAlign: 'center' as const }}>
      <Text style={{ color: '#666', fontSize: '12px' }}>
        © {new Date().getFullYear()} MyApp. All rights reserved.
      </Text>
      <Text style={{ color: '#666', fontSize: '12px' }}>
        <Link href="https://myapp.com/unsubscribe" style={{ color: '#666' }}>
          Unsubscribe
        </Link>
        {' · '}
        <Link href="https://myapp.com/privacy" style={{ color: '#666' }}>
          Privacy Policy
        </Link>
      </Text>
    </Section>
  );
}
```

### Welcome Email
```typescript
// emails/welcome.tsx
import {
  Html,
  Head,
  Body,
  Container,
  Section,
  Heading,
  Text,
  Preview,
  Img,
} from '@react-email/components';
import { Button } from './components/Button';
import { Footer } from './components/Footer';

interface WelcomeEmailProps {
  name: string;
  verifyUrl: string;
}

export default function WelcomeEmail({ name, verifyUrl }: WelcomeEmailProps) {
  return (
    <Html>
      <Head />
      <Preview>Welcome to MyApp! Verify your email to get started.</Preview>
      <Body style={main}>
        <Container style={container}>
          <Img
            src="https://myapp.com/logo.png"
            width="120"
            height="40"
            alt="MyApp"
            style={{ margin: '0 auto 24px' }}
          />

          <Heading style={heading}>Welcome, {name}!</Heading>

          <Text style={paragraph}>
            Thanks for signing up for MyApp. We're excited to have you on board.
            Click the button below to verify your email address and get started.
          </Text>

          <Section style={{ textAlign: 'center' as const, marginTop: '24px' }}>
            <Button href={verifyUrl}>Verify Email</Button>
          </Section>

          <Text style={{ ...paragraph, marginTop: '24px', color: '#666' }}>
            If you didn't create an account, you can safely ignore this email.
          </Text>

          <Footer />
        </Container>
      </Body>
    </Html>
  );
}

const main = {
  backgroundColor: '#f6f9fc',
  fontFamily:
    '-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,"Helvetica Neue",Ubuntu,sans-serif',
};

const container = {
  backgroundColor: '#ffffff',
  margin: '0 auto',
  padding: '40px 20px',
  borderRadius: '8px',
  maxWidth: '600px',
};

const heading = {
  fontSize: '24px',
  fontWeight: 600,
  textAlign: 'center' as const,
  margin: '0 0 24px',
};

const paragraph = {
  fontSize: '16px',
  lineHeight: '24px',
  color: '#333',
};

// For preview/testing
WelcomeEmail.PreviewProps = {
  name: 'John',
  verifyUrl: 'https://myapp.com/verify?token=abc123',
} satisfies WelcomeEmailProps;
```

### Password Reset Email
```typescript
// emails/password-reset.tsx
import {
  Html,
  Head,
  Body,
  Container,
  Section,
  Heading,
  Text,
  Preview,
  Code,
} from '@react-email/components';
import { Button } from './components/Button';
import { Footer } from './components/Footer';

interface PasswordResetEmailProps {
  resetUrl: string;
  expiresIn: string;
  ipAddress?: string;
}

export default function PasswordResetEmail({
  resetUrl,
  expiresIn,
  ipAddress,
}: PasswordResetEmailProps) {
  return (
    <Html>
      <Head />
      <Preview>Reset your MyApp password</Preview>
      <Body style={main}>
        <Container style={container}>
          <Heading style={heading}>Reset Your Password</Heading>

          <Text style={paragraph}>
            We received a request to reset your password. Click the button below
            to create a new password:
          </Text>

          <Section style={{ textAlign: 'center' as const, margin: '24px 0' }}>
            <Button href={resetUrl}>Reset Password</Button>
          </Section>

          <Text style={{ ...paragraph, color: '#666', fontSize: '14px' }}>
            This link will expire in {expiresIn}. If you didn't request a
            password reset, you can safely ignore this email.
          </Text>

          {ipAddress && (
            <Text style={{ ...paragraph, color: '#999', fontSize: '12px' }}>
              This request was made from IP address: <Code>{ipAddress}</Code>
            </Text>
          )}

          <Footer />
        </Container>
      </Body>
    </Html>
  );
}

const main = {
  backgroundColor: '#f6f9fc',
  fontFamily:
    '-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,"Helvetica Neue",Ubuntu,sans-serif',
};

const container = {
  backgroundColor: '#ffffff',
  margin: '0 auto',
  padding: '40px 20px',
  borderRadius: '8px',
  maxWidth: '600px',
};

const heading = {
  fontSize: '24px',
  fontWeight: 600,
  textAlign: 'center' as const,
  margin: '0 0 24px',
};

const paragraph = {
  fontSize: '16px',
  lineHeight: '24px',
  color: '#333',
};
```

### Order Confirmation Email
```typescript
// emails/order-confirmation.tsx
import {
  Html,
  Head,
  Body,
  Container,
  Section,
  Row,
  Column,
  Heading,
  Text,
  Preview,
  Hr,
  Img,
} from '@react-email/components';
import { Button } from './components/Button';
import { Footer } from './components/Footer';

interface OrderItem {
  name: string;
  quantity: number;
  price: number;
  image?: string;
}

interface OrderConfirmationEmailProps {
  orderNumber: string;
  items: OrderItem[];
  subtotal: number;
  shipping: number;
  tax: number;
  total: number;
  shippingAddress: {
    name: string;
    street: string;
    city: string;
    state: string;
    zip: string;
  };
  trackingUrl?: string;
}

export default function OrderConfirmationEmail({
  orderNumber,
  items,
  subtotal,
  shipping,
  tax,
  total,
  shippingAddress,
  trackingUrl,
}: OrderConfirmationEmailProps) {
  return (
    <Html>
      <Head />
      <Preview>Your order #{orderNumber} has been confirmed!</Preview>
      <Body style={main}>
        <Container style={container}>
          <Heading style={heading}>Order Confirmed!</Heading>

          <Text style={paragraph}>
            Thank you for your order. We'll send you a shipping confirmation
            once your order is on its way.
          </Text>

          <Section style={orderInfo}>
            <Text style={orderNumber}>Order #{orderNumber}</Text>
          </Section>

          <Hr style={{ borderColor: '#e6e6e6', margin: '24px 0' }} />

          {/* Order Items */}
          {items.map((item, index) => (
            <Row key={index} style={{ marginBottom: '16px' }}>
              <Column style={{ width: '80px' }}>
                {item.image && (
                  <Img
                    src={item.image}
                    width="60"
                    height="60"
                    alt={item.name}
                    style={{ borderRadius: '4px' }}
                  />
                )}
              </Column>
              <Column>
                <Text style={{ margin: 0, fontWeight: 600 }}>{item.name}</Text>
                <Text style={{ margin: 0, color: '#666' }}>
                  Qty: {item.quantity}
                </Text>
              </Column>
              <Column style={{ textAlign: 'right' as const }}>
                <Text style={{ margin: 0 }}>
                  ${(item.price * item.quantity).toFixed(2)}
                </Text>
              </Column>
            </Row>
          ))}

          <Hr style={{ borderColor: '#e6e6e6', margin: '24px 0' }} />

          {/* Order Summary */}
          <Section>
            <Row>
              <Column>Subtotal</Column>
              <Column style={{ textAlign: 'right' as const }}>
                ${subtotal.toFixed(2)}
              </Column>
            </Row>
            <Row>
              <Column>Shipping</Column>
              <Column style={{ textAlign: 'right' as const }}>
                ${shipping.toFixed(2)}
              </Column>
            </Row>
            <Row>
              <Column>Tax</Column>
              <Column style={{ textAlign: 'right' as const }}>
                ${tax.toFixed(2)}
              </Column>
            </Row>
            <Row style={{ fontWeight: 600, fontSize: '18px' }}>
              <Column>Total</Column>
              <Column style={{ textAlign: 'right' as const }}>
                ${total.toFixed(2)}
              </Column>
            </Row>
          </Section>

          <Hr style={{ borderColor: '#e6e6e6', margin: '24px 0' }} />

          {/* Shipping Address */}
          <Section>
            <Text style={{ fontWeight: 600, marginBottom: '8px' }}>
              Shipping Address
            </Text>
            <Text style={{ color: '#666', margin: 0 }}>
              {shippingAddress.name}
              <br />
              {shippingAddress.street}
              <br />
              {shippingAddress.city}, {shippingAddress.state}{' '}
              {shippingAddress.zip}
            </Text>
          </Section>

          {trackingUrl && (
            <Section style={{ textAlign: 'center' as const, marginTop: '24px' }}>
              <Button href={trackingUrl}>Track Your Order</Button>
            </Section>
          )}

          <Footer />
        </Container>
      </Body>
    </Html>
  );
}

const main = {
  backgroundColor: '#f6f9fc',
  fontFamily:
    '-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,"Helvetica Neue",Ubuntu,sans-serif',
};

const container = {
  backgroundColor: '#ffffff',
  margin: '0 auto',
  padding: '40px 20px',
  borderRadius: '8px',
  maxWidth: '600px',
};

const heading = {
  fontSize: '24px',
  fontWeight: 600,
  textAlign: 'center' as const,
  margin: '0 0 24px',
};

const paragraph = {
  fontSize: '16px',
  lineHeight: '24px',
  color: '#333',
};

const orderInfo = {
  backgroundColor: '#f4f4f4',
  borderRadius: '4px',
  padding: '12px',
  textAlign: 'center' as const,
};
```

---

## Sending Emails

### Email Service
```typescript
// lib/email-service.ts
import { resend, EMAIL_FROM } from './email';
import WelcomeEmail from '@/emails/welcome';
import PasswordResetEmail from '@/emails/password-reset';
import OrderConfirmationEmail from '@/emails/order-confirmation';
import { render } from '@react-email/components';

export async function sendWelcomeEmail(
  to: string,
  props: { name: string; verifyUrl: string }
) {
  const { data, error } = await resend.emails.send({
    from: EMAIL_FROM,
    to,
    subject: 'Welcome to MyApp! Verify your email',
    react: WelcomeEmail(props),
  });

  if (error) {
    console.error('Failed to send welcome email:', error);
    throw error;
  }

  return data;
}

export async function sendPasswordResetEmail(
  to: string,
  props: { resetUrl: string; expiresIn: string; ipAddress?: string }
) {
  const { data, error } = await resend.emails.send({
    from: EMAIL_FROM,
    to,
    subject: 'Reset your MyApp password',
    react: PasswordResetEmail(props),
  });

  if (error) {
    console.error('Failed to send password reset email:', error);
    throw error;
  }

  return data;
}

export async function sendOrderConfirmation(
  to: string,
  props: Parameters<typeof OrderConfirmationEmail>[0]
) {
  const { data, error } = await resend.emails.send({
    from: EMAIL_FROM,
    to,
    subject: `Order #${props.orderNumber} Confirmed`,
    react: OrderConfirmationEmail(props),
    // Optional: plain text fallback
    text: `Your order #${props.orderNumber} has been confirmed. Total: $${props.total.toFixed(2)}`,
  });

  if (error) {
    console.error('Failed to send order confirmation:', error);
    throw error;
  }

  return data;
}

// Batch sending
export async function sendBulkEmails(
  emails: Array<{
    to: string;
    subject: string;
    react: React.ReactElement;
  }>
) {
  const { data, error } = await resend.batch.send(
    emails.map((email) => ({
      from: EMAIL_FROM,
      ...email,
    }))
  );

  if (error) {
    console.error('Failed to send bulk emails:', error);
    throw error;
  }

  return data;
}
```

### API Routes
```typescript
// app/api/auth/register/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { sendWelcomeEmail } from '@/lib/email-service';
import { db } from '@/lib/db';
import { generateVerificationToken } from '@/lib/tokens';

export async function POST(req: NextRequest) {
  const { email, name, password } = await req.json();

  // Create user
  const user = await db.user.create({
    data: { email, name, password: await hash(password) },
  });

  // Generate verification token
  const token = await generateVerificationToken(user.id);

  // Send welcome email (async, don't block response)
  sendWelcomeEmail(email, {
    name,
    verifyUrl: `${process.env.NEXT_PUBLIC_APP_URL}/verify?token=${token}`,
  }).catch(console.error);

  return NextResponse.json({ success: true });
}
```

---

## Email Preview & Testing

### Development Preview
```bash
# Install email CLI
npm install -D email-dev

# Add script to package.json
"scripts": {
  "email:dev": "email dev --dir emails"
}

# Run preview server
npm run email:dev
```

### Testing
```typescript
// lib/email-service.test.ts
import { render } from '@react-email/components';
import WelcomeEmail from '@/emails/welcome';

describe('WelcomeEmail', () => {
  it('should render with required props', () => {
    const html = render(
      WelcomeEmail({
        name: 'John',
        verifyUrl: 'https://example.com/verify',
      })
    );

    expect(html).toContain('Welcome, John!');
    expect(html).toContain('https://example.com/verify');
  });

  it('should include unsubscribe link', () => {
    const html = render(
      WelcomeEmail({
        name: 'John',
        verifyUrl: 'https://example.com/verify',
      })
    );

    expect(html).toContain('Unsubscribe');
  });
});
```

---

## Background Email Processing

### With Queue
```typescript
// lib/email-queue.ts
import { Queue } from 'bullmq';
import { connection } from './redis';

interface EmailJob {
  type: 'welcome' | 'password-reset' | 'order-confirmation';
  to: string;
  props: Record<string, unknown>;
}

export const emailQueue = new Queue<EmailJob>('email', {
  connection,
  defaultJobOptions: {
    attempts: 3,
    backoff: {
      type: 'exponential',
      delay: 1000,
    },
    removeOnComplete: { age: 24 * 3600 },
    removeOnFail: { age: 7 * 24 * 3600 },
  },
});

// Worker
import { Worker } from 'bullmq';
import * as emailService from './email-service';

const emailWorker = new Worker<EmailJob>(
  'email',
  async (job) => {
    switch (job.data.type) {
      case 'welcome':
        await emailService.sendWelcomeEmail(
          job.data.to,
          job.data.props as any
        );
        break;
      case 'password-reset':
        await emailService.sendPasswordResetEmail(
          job.data.to,
          job.data.props as any
        );
        break;
      case 'order-confirmation':
        await emailService.sendOrderConfirmation(
          job.data.to,
          job.data.props as any
        );
        break;
    }
  },
  { connection }
);

// Usage
await emailQueue.add('send-welcome', {
  type: 'welcome',
  to: user.email,
  props: { name: user.name, verifyUrl },
});
```

---

## Anti-Patterns

```typescript
// ❌ NEVER: Block request on email sending
export async function POST(req) {
  const user = await createUser(data);
  await sendWelcomeEmail(user.email); // Blocks request!
  return Response.json(user);
}

// ✅ CORRECT: Async email sending
export async function POST(req) {
  const user = await createUser(data);
  sendWelcomeEmail(user.email).catch(console.error); // Non-blocking
  return Response.json(user);
}

// ❌ NEVER: Hardcode styles inline everywhere
<Text style={{ fontSize: '16px', color: '#333', lineHeight: '24px' }}>
  First paragraph
</Text>
<Text style={{ fontSize: '16px', color: '#333', lineHeight: '24px' }}>
  Second paragraph
</Text>

// ✅ CORRECT: Reuse style objects
const paragraph = { fontSize: '16px', color: '#333', lineHeight: '24px' };
<Text style={paragraph}>First paragraph</Text>
<Text style={paragraph}>Second paragraph</Text>

// ❌ NEVER: Skip unsubscribe link
// This violates CAN-SPAM and will hurt deliverability

// ✅ CORRECT: Always include unsubscribe
<Footer /> // Contains unsubscribe link

// ❌ NEVER: Use relative URLs
<Button href="/verify">Verify</Button> // Won't work in email!

// ✅ CORRECT: Full URLs
<Button href={`${process.env.NEXT_PUBLIC_APP_URL}/verify`}>Verify</Button>
```

---

## Quick Reference

### Resend API
| Method | Purpose |
|--------|---------|
| `resend.emails.send()` | Send single email |
| `resend.batch.send()` | Send up to 100 emails |
| `resend.emails.get()` | Get email status |
| `resend.domains.list()` | List verified domains |

### React Email Components
| Component | Purpose |
|-----------|---------|
| `Html` | Root element |
| `Head` | Meta tags |
| `Body` | Content wrapper |
| `Container` | Centered container |
| `Section` | Content section |
| `Row` / `Column` | Layout |
| `Heading` | h1-h6 |
| `Text` | Paragraph |
| `Button` | CTA button |
| `Link` | Anchor |
| `Img` | Image |
| `Hr` | Horizontal rule |
| `Preview` | Preview text (inbox) |

### Deliverability Best Practices
| Practice | Reason |
|----------|--------|
| Verify domain (DKIM, SPF) | Authentication |
| Include unsubscribe | Legal compliance |
| Text fallback | Accessibility |
| < 102KB HTML | Gmail clipping |
| Alt text on images | Blocked images |

### Checklist
- [ ] Domain verified (DNS records)
- [ ] DKIM/SPF configured
- [ ] Unsubscribe link included
- [ ] Preview text set
- [ ] Alt text on images
- [ ] Full URLs (not relative)
- [ ] Text fallback provided
- [ ] Queue for background sending
- [ ] Error handling and retries
- [ ] Test in multiple clients
