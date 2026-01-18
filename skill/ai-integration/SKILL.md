# AI Integration Patterns

> **Auto-trigger**: OpenAI, Anthropic, Vercel AI SDK, LLM integration, AI features

---

## 1. Vercel AI SDK

### 1.1 Setup

```bash
pnpm add ai @ai-sdk/openai @ai-sdk/anthropic
```

### 1.2 Basic Chat

```typescript
// app/api/chat/route.ts
import { openai } from '@ai-sdk/openai';
import { streamText } from 'ai';

export async function POST(req: Request) {
  const { messages } = await req.json();

  const result = await streamText({
    model: openai('gpt-4-turbo'),
    system: 'You are a helpful assistant.',
    messages,
  });

  return result.toDataStreamResponse();
}

// components/Chat.tsx
'use client';

import { useChat } from 'ai/react';

export function Chat() {
  const { messages, input, handleInputChange, handleSubmit, isLoading } = useChat();

  return (
    <div>
      <div className="space-y-4">
        {messages.map((m) => (
          <div key={m.id} className={m.role === 'user' ? 'text-right' : ''}>
            <span className="font-bold">{m.role === 'user' ? 'You' : 'AI'}:</span>
            <p>{m.content}</p>
          </div>
        ))}
      </div>

      <form onSubmit={handleSubmit} className="mt-4">
        <input
          value={input}
          onChange={handleInputChange}
          placeholder="Say something..."
          disabled={isLoading}
          className="w-full p-2 border rounded"
        />
      </form>
    </div>
  );
}
```

### 1.3 Structured Output

```typescript
import { openai } from '@ai-sdk/openai';
import { generateObject } from 'ai';
import { z } from 'zod';

const recipeSchema = z.object({
  name: z.string(),
  ingredients: z.array(z.object({
    name: z.string(),
    amount: z.string(),
  })),
  steps: z.array(z.string()),
  prepTime: z.number().describe('Prep time in minutes'),
  cookTime: z.number().describe('Cook time in minutes'),
});

export async function generateRecipe(dish: string) {
  const { object } = await generateObject({
    model: openai('gpt-4-turbo'),
    schema: recipeSchema,
    prompt: `Generate a recipe for ${dish}`,
  });

  return object;
}
```

### 1.4 Tool Calling

```typescript
import { openai } from '@ai-sdk/openai';
import { streamText, tool } from 'ai';
import { z } from 'zod';

export async function POST(req: Request) {
  const { messages } = await req.json();

  const result = await streamText({
    model: openai('gpt-4-turbo'),
    messages,
    tools: {
      getWeather: tool({
        description: 'Get the weather for a location',
        parameters: z.object({
          location: z.string().describe('City name'),
          unit: z.enum(['celsius', 'fahrenheit']).optional(),
        }),
        execute: async ({ location, unit = 'celsius' }) => {
          // Call weather API
          const weather = await fetchWeather(location);
          return {
            temperature: unit === 'celsius' ? weather.temp : weather.temp * 1.8 + 32,
            condition: weather.condition,
            location,
          };
        },
      }),
      searchProducts: tool({
        description: 'Search for products in the catalog',
        parameters: z.object({
          query: z.string(),
          category: z.string().optional(),
          maxPrice: z.number().optional(),
        }),
        execute: async ({ query, category, maxPrice }) => {
          const products = await db.product.findMany({
            where: {
              name: { contains: query, mode: 'insensitive' },
              ...(category && { category }),
              ...(maxPrice && { price: { lte: maxPrice } }),
            },
            take: 5,
          });
          return products;
        },
      }),
    },
  });

  return result.toDataStreamResponse();
}
```

---

## 2. OpenAI SDK (Direct)

### 2.1 Chat Completion

```typescript
import OpenAI from 'openai';

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

export async function chat(messages: OpenAI.ChatCompletionMessageParam[]) {
  const response = await openai.chat.completions.create({
    model: 'gpt-4-turbo',
    messages,
    temperature: 0.7,
    max_tokens: 1000,
  });

  return response.choices[0].message.content;
}

// Streaming
export async function chatStream(messages: OpenAI.ChatCompletionMessageParam[]) {
  const stream = await openai.chat.completions.create({
    model: 'gpt-4-turbo',
    messages,
    stream: true,
  });

  for await (const chunk of stream) {
    const content = chunk.choices[0]?.delta?.content;
    if (content) {
      process.stdout.write(content);
    }
  }
}
```

### 2.2 Embeddings

```typescript
export async function createEmbedding(text: string) {
  const response = await openai.embeddings.create({
    model: 'text-embedding-3-small',
    input: text,
  });

  return response.data[0].embedding;
}

// Batch embeddings
export async function createEmbeddings(texts: string[]) {
  const response = await openai.embeddings.create({
    model: 'text-embedding-3-small',
    input: texts,
  });

  return response.data.map((d) => d.embedding);
}
```

---

## 3. Anthropic SDK

```typescript
import Anthropic from '@anthropic-ai/sdk';

const anthropic = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY,
});

export async function chat(userMessage: string) {
  const response = await anthropic.messages.create({
    model: 'claude-3-5-sonnet-20241022',
    max_tokens: 1024,
    system: 'You are a helpful assistant.',
    messages: [{ role: 'user', content: userMessage }],
  });

  return response.content[0].type === 'text' 
    ? response.content[0].text 
    : null;
}

// Streaming
export async function chatStream(userMessage: string) {
  const stream = await anthropic.messages.stream({
    model: 'claude-3-5-sonnet-20241022',
    max_tokens: 1024,
    messages: [{ role: 'user', content: userMessage }],
  });

  for await (const event of stream) {
    if (event.type === 'content_block_delta' && event.delta.type === 'text_delta') {
      process.stdout.write(event.delta.text);
    }
  }

  return stream.finalMessage();
}
```

---

## 4. RAG (Retrieval Augmented Generation)

### 4.1 Vector Store with Supabase

```typescript
// lib/embeddings.ts
import { openai } from './openai';
import { supabase } from './supabase';

export async function indexDocument(content: string, metadata: Record<string, unknown>) {
  // Create embedding
  const embedding = await createEmbedding(content);

  // Store in Supabase
  const { error } = await supabase.from('documents').insert({
    content,
    embedding,
    metadata,
  });

  if (error) throw error;
}

export async function searchDocuments(query: string, limit = 5) {
  const queryEmbedding = await createEmbedding(query);

  const { data, error } = await supabase.rpc('match_documents', {
    query_embedding: queryEmbedding,
    match_threshold: 0.7,
    match_count: limit,
  });

  if (error) throw error;
  return data;
}

// SQL function for similarity search
/*
CREATE OR REPLACE FUNCTION match_documents(
  query_embedding vector(1536),
  match_threshold float,
  match_count int
)
RETURNS TABLE (
  id uuid,
  content text,
  metadata jsonb,
  similarity float
)
LANGUAGE sql STABLE
AS $$
  SELECT
    id,
    content,
    metadata,
    1 - (embedding <=> query_embedding) as similarity
  FROM documents
  WHERE 1 - (embedding <=> query_embedding) > match_threshold
  ORDER BY similarity DESC
  LIMIT match_count;
$$;
*/
```

### 4.2 RAG Chat

```typescript
export async function ragChat(query: string, conversationHistory: Message[]) {
  // 1. Search for relevant documents
  const relevantDocs = await searchDocuments(query);
  
  // 2. Build context
  const context = relevantDocs
    .map((doc) => doc.content)
    .join('\n\n---\n\n');

  // 3. Generate response with context
  const response = await openai.chat.completions.create({
    model: 'gpt-4-turbo',
    messages: [
      {
        role: 'system',
        content: `You are a helpful assistant. Use the following context to answer questions.
        
Context:
${context}

If the context doesn't contain relevant information, say so.`,
      },
      ...conversationHistory,
      { role: 'user', content: query },
    ],
  });

  return {
    answer: response.choices[0].message.content,
    sources: relevantDocs.map((d) => d.metadata),
  };
}
```

---

## 5. Prompt Engineering

### 5.1 System Prompts

```typescript
const prompts = {
  codeReview: `You are an expert code reviewer. Analyze the provided code for:
- Bugs and potential issues
- Security vulnerabilities
- Performance problems
- Code style and best practices
- Suggest improvements with examples

Be concise but thorough. Format your response with markdown.`,

  dataExtraction: `Extract structured data from the text. Return ONLY valid JSON.
If a field cannot be determined, use null.
Do not include explanations outside the JSON.`,

  summarization: `Summarize the following content. 
- Use bullet points for key takeaways
- Keep the summary under 200 words
- Preserve the most important information
- Use simple, clear language`,
};
```

### 5.2 Few-Shot Examples

```typescript
const classificationPrompt = `Classify the customer message into a category.

Categories:
- billing: Payment, invoices, refunds
- technical: Bugs, errors, how-to questions
- account: Login, password, profile
- other: Everything else

Examples:
User: I can't log into my account
Category: account

User: Why was I charged twice?
Category: billing

User: The page keeps crashing when I click submit
Category: technical

User: {{MESSAGE}}
Category:`;
```

### 5.3 Structured Output Prompting

```typescript
const structuredPrompt = `Analyze the product review and extract:
1. Sentiment (positive, negative, neutral)
2. Key topics mentioned
3. Rating (1-5)
4. Summary (one sentence)

Respond in this exact JSON format:
{
  "sentiment": "positive|negative|neutral",
  "topics": ["topic1", "topic2"],
  "rating": 4,
  "summary": "Brief summary here"
}

Review: {{REVIEW}}`;
```

---

## 6. Error Handling & Retries

```typescript
import OpenAI from 'openai';

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
  maxRetries: 3,
  timeout: 30000,
});

export async function safeCompletion(
  messages: OpenAI.ChatCompletionMessageParam[]
) {
  try {
    const response = await openai.chat.completions.create({
      model: 'gpt-4-turbo',
      messages,
    });
    return { success: true, data: response };
  } catch (error) {
    if (error instanceof OpenAI.APIError) {
      if (error.status === 429) {
        // Rate limited - wait and retry
        await sleep(error.headers?.['retry-after'] || 5000);
        return safeCompletion(messages);
      }
      if (error.status === 503) {
        // Service unavailable - use fallback model
        return fallbackCompletion(messages);
      }
    }
    return { success: false, error };
  }
}

// Token counting for cost estimation
import { encoding_for_model } from 'tiktoken';

export function countTokens(text: string, model = 'gpt-4') {
  const encoder = encoding_for_model(model);
  const tokens = encoder.encode(text);
  encoder.free();
  return tokens.length;
}
```

---

## 7. Streaming UI Patterns

```typescript
// components/StreamingMessage.tsx
'use client';

import { useChat } from 'ai/react';
import { motion, AnimatePresence } from 'framer-motion';

export function StreamingMessage({ content }: { content: string }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      className="prose"
    >
      {content}
      <motion.span
        animate={{ opacity: [0, 1, 0] }}
        transition={{ repeat: Infinity, duration: 1 }}
        className="inline-block w-2 h-4 bg-current ml-1"
      />
    </motion.div>
  );
}

// Abort/Cancel
export function ChatWithCancel() {
  const { messages, input, handleSubmit, stop, isLoading } = useChat();

  return (
    <div>
      {messages.map((m) => (
        <div key={m.id}>{m.content}</div>
      ))}
      
      {isLoading && (
        <button onClick={stop} className="text-red-500">
          Stop generating
        </button>
      )}

      <form onSubmit={handleSubmit}>
        <input value={input} disabled={isLoading} />
      </form>
    </div>
  );
}
```

---

## 8. Security

```typescript
// NEVER expose API keys to client
// Use server-side routes only

// Rate limiting for AI endpoints
import rateLimit from 'express-rate-limit';

export const aiRateLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 10, // 10 requests per minute
  message: { error: 'Too many AI requests' },
});

// Input validation
const maxInputLength = 4000;

export function validateInput(input: string) {
  if (!input || typeof input !== 'string') {
    throw new Error('Invalid input');
  }
  if (input.length > maxInputLength) {
    throw new Error(`Input too long (max ${maxInputLength} chars)`);
  }
  // Sanitize if needed
  return input.trim();
}

// Token budget per user
async function checkTokenBudget(userId: string, estimatedTokens: number) {
  const usage = await redis.get(`tokens:${userId}`);
  const current = parseInt(usage || '0');
  const limit = 100000; // Monthly limit

  if (current + estimatedTokens > limit) {
    throw new Error('Token limit exceeded');
  }

  await redis.incrby(`tokens:${userId}`, estimatedTokens);
}
```

---

## Quick Reference

### Model Selection
| Use Case | Recommended Model |
|----------|-------------------|
| Complex reasoning | GPT-4 Turbo, Claude 3.5 Sonnet |
| Fast responses | GPT-3.5 Turbo, Claude 3 Haiku |
| Embeddings | text-embedding-3-small |
| Vision | GPT-4 Vision, Claude 3 |

### Cost Optimization
- Use smaller models for simple tasks
- Cache frequent responses
- Set appropriate max_tokens
- Use streaming for long responses
- Implement token budgets

### Prompt Checklist
- [ ] Clear role in system prompt
- [ ] Specific output format
- [ ] Examples for complex tasks
- [ ] Constraints and guardrails
- [ ] Error handling instructions
