# Background Jobs & Queues

> **Sources**: [BullMQ](https://github.com/taskforcesh/bullmq) (6k⭐), [Inngest](https://github.com/inngest/inngest) (4k⭐), [Trigger.dev](https://github.com/triggerdotdev/trigger.dev) (8k⭐)
> **Auto-trigger**: Files containing job queues, background processing, `bullmq`, `inngest`, `trigger.dev`, async workers, cron jobs

---

## Technology Selection

| Tool | Best For | Infrastructure |
|------|----------|----------------|
| **BullMQ** | Self-hosted, full control | Redis required |
| **Inngest** | Serverless, event-driven | Managed |
| **Trigger.dev** | Long-running, complex workflows | Managed |
| **Vercel Cron** | Simple scheduled tasks | Vercel only |

---

## BullMQ

### Setup
```bash
npm install bullmq ioredis
```

### Queue Definition
```typescript
// lib/queue.ts
import { Queue, Worker, Job } from 'bullmq';
import IORedis from 'ioredis';

const connection = new IORedis(process.env.REDIS_URL!, {
  maxRetriesPerRequest: null, // Required for BullMQ
});

// Define job data types
interface EmailJobData {
  to: string;
  subject: string;
  template: string;
  data: Record<string, unknown>;
}

interface ProcessImageJobData {
  imageId: string;
  operations: Array<'resize' | 'compress' | 'watermark'>;
}

// Create queues
export const emailQueue = new Queue<EmailJobData>('email', { connection });
export const imageQueue = new Queue<ProcessImageJobData>('image-processing', { connection });

// Queue events
emailQueue.on('error', (err) => {
  console.error('Email queue error:', err);
});
```

### Adding Jobs
```typescript
// services/email.ts
import { emailQueue } from '@/lib/queue';

export async function sendWelcomeEmail(userId: string, email: string) {
  await emailQueue.add(
    'welcome-email',
    {
      to: email,
      subject: 'Welcome to Our App!',
      template: 'welcome',
      data: { userId },
    },
    {
      attempts: 3,
      backoff: {
        type: 'exponential',
        delay: 1000,
      },
      removeOnComplete: {
        age: 24 * 3600, // Keep for 24 hours
        count: 1000,    // Keep last 1000
      },
      removeOnFail: {
        age: 7 * 24 * 3600, // Keep failed for 7 days
      },
    }
  );
}

// Delayed job
export async function scheduleReminder(userId: string, delay: number) {
  await emailQueue.add(
    'reminder',
    { to: userId, subject: 'Reminder', template: 'reminder', data: {} },
    { delay } // milliseconds
  );
}

// Scheduled/cron job
export async function scheduleRecurringReport() {
  await emailQueue.add(
    'daily-report',
    { to: 'admin@example.com', subject: 'Daily Report', template: 'report', data: {} },
    {
      repeat: {
        pattern: '0 9 * * *', // Every day at 9 AM
        tz: 'America/New_York',
      },
    }
  );
}

// Bulk jobs
export async function sendBulkEmails(emails: EmailJobData[]) {
  await emailQueue.addBulk(
    emails.map((data, index) => ({
      name: 'bulk-email',
      data,
      opts: {
        priority: 10, // Lower number = higher priority
        delay: index * 100, // Stagger to avoid rate limits
      },
    }))
  );
}
```

### Worker (Processor)
```typescript
// workers/email.worker.ts
import { Worker, Job } from 'bullmq';
import IORedis from 'ioredis';
import { sendEmail } from '@/lib/email';

const connection = new IORedis(process.env.REDIS_URL!, {
  maxRetriesPerRequest: null,
});

const emailWorker = new Worker(
  'email',
  async (job: Job<EmailJobData>) => {
    console.log(`Processing job ${job.id}: ${job.name}`);

    // Update progress
    await job.updateProgress(10);

    // Load template
    const template = await loadTemplate(job.data.template);
    await job.updateProgress(30);

    // Render email
    const html = await renderTemplate(template, job.data.data);
    await job.updateProgress(50);

    // Send email
    const result = await sendEmail({
      to: job.data.to,
      subject: job.data.subject,
      html,
    });

    await job.updateProgress(100);

    return { messageId: result.messageId };
  },
  {
    connection,
    concurrency: 5, // Process 5 jobs simultaneously
    limiter: {
      max: 100,
      duration: 60000, // 100 jobs per minute
    },
  }
);

// Event handlers
emailWorker.on('completed', (job, result) => {
  console.log(`Job ${job.id} completed:`, result);
});

emailWorker.on('failed', (job, err) => {
  console.error(`Job ${job?.id} failed:`, err);
});

emailWorker.on('progress', (job, progress) => {
  console.log(`Job ${job.id} progress: ${progress}%`);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  await emailWorker.close();
});
```

### Job Flow (Parent-Child)
```typescript
// Complex workflow with dependencies
import { FlowProducer } from 'bullmq';

const flow = new FlowProducer({ connection });

// Parent waits for all children to complete
await flow.add({
  name: 'process-order',
  queueName: 'orders',
  data: { orderId: '123' },
  children: [
    {
      name: 'validate-inventory',
      queueName: 'inventory',
      data: { orderId: '123' },
    },
    {
      name: 'charge-payment',
      queueName: 'payments',
      data: { orderId: '123' },
    },
    {
      name: 'send-confirmation',
      queueName: 'email',
      data: { orderId: '123' },
      opts: { delay: 1000 }, // Wait a bit after others complete
    },
  ],
});
```

---

## Inngest

### Setup
```bash
npm install inngest
```

### Client Configuration
```typescript
// lib/inngest.ts
import { Inngest } from 'inngest';

export const inngest = new Inngest({
  id: 'my-app',
  eventKey: process.env.INNGEST_EVENT_KEY,
});
```

### Define Functions
```typescript
// inngest/functions.ts
import { inngest } from '@/lib/inngest';
import { sendEmail } from '@/lib/email';

// Simple function
export const sendWelcomeEmail = inngest.createFunction(
  {
    id: 'send-welcome-email',
    retries: 3,
  },
  { event: 'user/created' },
  async ({ event, step }) => {
    const user = event.data;

    await step.run('send-email', async () => {
      await sendEmail({
        to: user.email,
        subject: 'Welcome!',
        template: 'welcome',
      });
    });

    return { sent: true };
  }
);

// Multi-step function with automatic retries
export const processOrder = inngest.createFunction(
  {
    id: 'process-order',
    retries: 5,
  },
  { event: 'order/placed' },
  async ({ event, step }) => {
    const order = event.data;

    // Each step is retried independently
    const inventory = await step.run('check-inventory', async () => {
      return await checkInventory(order.items);
    });

    if (!inventory.available) {
      // Cancel the function
      return { status: 'cancelled', reason: 'out-of-stock' };
    }

    const payment = await step.run('charge-payment', async () => {
      return await chargeCard(order.paymentMethodId, order.total);
    });

    await step.run('reserve-inventory', async () => {
      await reserveInventory(order.items);
    });

    // Wait before sending confirmation
    await step.sleep('wait-before-email', '5s');

    await step.run('send-confirmation', async () => {
      await sendEmail({
        to: order.customerEmail,
        subject: 'Order Confirmed',
        template: 'order-confirmation',
        data: { order, payment },
      });
    });

    return { status: 'completed', orderId: order.id };
  }
);

// Scheduled function (cron)
export const dailyReport = inngest.createFunction(
  {
    id: 'daily-report',
  },
  { cron: '0 9 * * *' }, // 9 AM daily
  async ({ step }) => {
    const report = await step.run('generate-report', async () => {
      return await generateDailyReport();
    });

    await step.run('send-report', async () => {
      await sendEmail({
        to: 'admin@example.com',
        subject: 'Daily Report',
        template: 'report',
        data: report,
      });
    });
  }
);

// Delayed function
export const sendFollowUp = inngest.createFunction(
  {
    id: 'send-follow-up',
  },
  { event: 'user/signed-up' },
  async ({ event, step }) => {
    // Wait 3 days
    await step.sleep('wait-3-days', '3d');

    // Check if user is still inactive
    const user = await step.run('check-user', async () => {
      return await getUser(event.data.userId);
    });

    if (!user.hasCompletedOnboarding) {
      await step.run('send-nudge', async () => {
        await sendEmail({
          to: user.email,
          subject: 'Need help getting started?',
          template: 'follow-up',
        });
      });
    }
  }
);
```

### API Route Handler
```typescript
// app/api/inngest/route.ts
import { serve } from 'inngest/next';
import { inngest } from '@/lib/inngest';
import {
  sendWelcomeEmail,
  processOrder,
  dailyReport,
  sendFollowUp,
} from '@/inngest/functions';

export const { GET, POST, PUT } = serve({
  client: inngest,
  functions: [sendWelcomeEmail, processOrder, dailyReport, sendFollowUp],
});
```

### Sending Events
```typescript
// Trigger from API routes
import { inngest } from '@/lib/inngest';

// After user signs up
await inngest.send({
  name: 'user/created',
  data: {
    userId: user.id,
    email: user.email,
    name: user.name,
  },
});

// After order placed
await inngest.send({
  name: 'order/placed',
  data: {
    orderId: order.id,
    items: order.items,
    total: order.total,
    customerEmail: customer.email,
    paymentMethodId: order.paymentMethodId,
  },
});

// Send multiple events
await inngest.send([
  { name: 'analytics/page-view', data: { page: '/pricing' } },
  { name: 'analytics/cta-click', data: { button: 'signup' } },
]);
```

---

## Trigger.dev

### Setup
```bash
npm install @trigger.dev/sdk @trigger.dev/nextjs
```

### Configuration
```typescript
// trigger.config.ts
import { defineConfig } from '@trigger.dev/sdk/v3';

export default defineConfig({
  project: 'my-app',
  runtime: 'node',
  retries: {
    enabledInDev: true,
    default: {
      maxAttempts: 3,
      minTimeoutInMs: 1000,
      maxTimeoutInMs: 10000,
      factor: 2,
    },
  },
});
```

### Define Tasks
```typescript
// trigger/tasks.ts
import { task, wait, retry, logger } from '@trigger.dev/sdk/v3';
import { sendEmail } from '@/lib/email';

export const processImage = task({
  id: 'process-image',
  retry: {
    maxAttempts: 3,
  },
  run: async (payload: { imageId: string; userId: string }) => {
    logger.info('Processing image', { imageId: payload.imageId });

    // Download image
    const image = await downloadImage(payload.imageId);

    // Process
    const processed = await optimizeImage(image);

    // Upload
    const url = await uploadImage(processed);

    // Notify user
    await sendEmail({
      to: await getUserEmail(payload.userId),
      subject: 'Image processed',
      template: 'image-ready',
      data: { url },
    });

    return { url };
  },
});

export const longRunningTask = task({
  id: 'long-running',
  run: async (payload: { datasetId: string }) => {
    // Can run for hours
    const dataset = await loadDataset(payload.datasetId);

    for (let i = 0; i < dataset.length; i++) {
      await processItem(dataset[i]);

      // Checkpoint for resumability
      if (i % 100 === 0) {
        logger.info(`Processed ${i}/${dataset.length}`);
      }
    }

    return { processed: dataset.length };
  },
});

// Scheduled task
export const dailyCleanup = task({
  id: 'daily-cleanup',
  // Configured in trigger.dev dashboard as cron
  run: async () => {
    const deleted = await cleanupOldRecords();
    return { deletedCount: deleted };
  },
});
```

### Trigger from App
```typescript
// app/api/process/route.ts
import { tasks } from '@trigger.dev/sdk/v3';
import { processImage } from '@/trigger/tasks';

export async function POST(req: Request) {
  const { imageId, userId } = await req.json();

  // Trigger the task
  const handle = await tasks.trigger(processImage, {
    imageId,
    userId,
  });

  return Response.json({
    taskId: handle.id,
    status: 'processing',
  });
}

// Batch trigger
export async function POST(req: Request) {
  const { images } = await req.json();

  const handles = await tasks.batchTrigger(
    processImage,
    images.map((img) => ({ payload: img }))
  );

  return Response.json({
    taskIds: handles.map((h) => h.id),
  });
}
```

---

## Retry Patterns

### Exponential Backoff
```typescript
// BullMQ
{
  attempts: 5,
  backoff: {
    type: 'exponential',
    delay: 1000, // 1s, 2s, 4s, 8s, 16s
  },
}

// Custom backoff
{
  attempts: 5,
  backoff: {
    type: 'custom',
  },
}

// In worker
const worker = new Worker('queue', processor, {
  settings: {
    backoffStrategy: (attemptsMade) => {
      // Custom: 1s, 5s, 30s, 2m, 10m
      const delays = [1000, 5000, 30000, 120000, 600000];
      return delays[Math.min(attemptsMade - 1, delays.length - 1)];
    },
  },
});
```

### Dead Letter Queue
```typescript
// BullMQ - after all retries exhausted
import { Queue } from 'bullmq';

const deadLetterQueue = new Queue('dead-letter', { connection });

const worker = new Worker('main', processor, {
  connection,
});

worker.on('failed', async (job, error) => {
  if (job && job.attemptsMade >= job.opts.attempts!) {
    // Move to dead letter queue
    await deadLetterQueue.add('failed-job', {
      originalQueue: 'main',
      originalJobId: job.id,
      data: job.data,
      error: error.message,
      failedAt: new Date().toISOString(),
    });
  }
});
```

---

## Monitoring & Admin UI

### Bull Board
```bash
npm install @bull-board/express @bull-board/api
```

```typescript
// admin/bull-board.ts
import { createBullBoard } from '@bull-board/api';
import { BullMQAdapter } from '@bull-board/api/bullMQAdapter';
import { ExpressAdapter } from '@bull-board/express';
import { emailQueue, imageQueue } from '@/lib/queue';

const serverAdapter = new ExpressAdapter();
serverAdapter.setBasePath('/admin/queues');

createBullBoard({
  queues: [
    new BullMQAdapter(emailQueue),
    new BullMQAdapter(imageQueue),
  ],
  serverAdapter,
});

// Mount on Express or standalone
app.use('/admin/queues', serverAdapter.getRouter());
```

---

## Anti-Patterns

```typescript
// ❌ NEVER: Forget to handle failures
await queue.add('job', data);
// What happens on failure?

// ✅ CORRECT: Always configure retries and monitoring
await queue.add('job', data, {
  attempts: 3,
  backoff: { type: 'exponential', delay: 1000 },
  removeOnFail: { age: 7 * 24 * 3600 },
});

// ❌ NEVER: Block on job completion in request
app.post('/process', async (req, res) => {
  const job = await queue.add('process', req.body);
  const result = await job.waitUntilFinished(); // Blocks request!
  res.json(result);
});

// ✅ CORRECT: Return immediately, poll or webhook
app.post('/process', async (req, res) => {
  const job = await queue.add('process', req.body);
  res.json({ jobId: job.id, status: 'processing' });
});

// ❌ NEVER: Store large payloads in job data
await queue.add('process', { file: hugeBase64String });

// ✅ CORRECT: Store reference, fetch in worker
await queue.add('process', { fileId: 'abc123' });
// Worker fetches file from storage

// ❌ NEVER: No idempotency
worker.on('process', async (job) => {
  await chargeCard(job.data.amount); // Could charge twice on retry!
});

// ✅ CORRECT: Idempotent operations
worker.on('process', async (job) => {
  const existing = await getPayment(job.data.orderId);
  if (existing) return existing;
  return await chargeCard(job.data.amount, { idempotencyKey: job.id });
});
```

---

## Quick Reference

### BullMQ Job Options
| Option | Purpose |
|--------|---------|
| `attempts` | Max retry attempts |
| `backoff` | Retry delay strategy |
| `delay` | Delay before processing |
| `priority` | Job priority (lower = higher) |
| `repeat` | Recurring schedule |
| `removeOnComplete` | Cleanup completed jobs |
| `removeOnFail` | Cleanup failed jobs |
| `jobId` | Custom job ID (for dedup) |

### Inngest Step Functions
| Function | Purpose |
|----------|---------|
| `step.run()` | Execute and retry a step |
| `step.sleep()` | Wait for duration |
| `step.sleepUntil()` | Wait until timestamp |
| `step.waitForEvent()` | Wait for another event |
| `step.invoke()` | Call another function |

### Common Cron Patterns
| Pattern | Meaning |
|---------|---------|
| `0 * * * *` | Every hour |
| `0 0 * * *` | Daily at midnight |
| `0 9 * * 1` | Monday at 9 AM |
| `0 0 1 * *` | First of month |
| `*/15 * * * *` | Every 15 minutes |

### Checklist
- [ ] Retry configuration with backoff
- [ ] Dead letter queue for failed jobs
- [ ] Idempotency for critical operations
- [ ] Job data references (not large payloads)
- [ ] Graceful shutdown handling
- [ ] Monitoring/admin UI
- [ ] Alerting on failures
- [ ] Rate limiting for external APIs
