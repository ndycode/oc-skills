---
name: docker-deploy
description: Docker, docker-compose, and deployment to Vercel/Railway
metadata:
  short-description: Docker deployment
---

# Docker & Deployment

> **Sources**: [Docker Docs](https://docs.docker.com/), [Vercel Docs](https://vercel.com/docs), [Railway Docs](https://docs.railway.app/)
> **Auto-trigger**: Files named `Dockerfile`, `docker-compose.yml`, `.dockerignore`, `vercel.json`, `railway.json`, deployment configs

---

## Dockerfile Best Practices

### Node.js Application
```dockerfile
# Dockerfile
# Stage 1: Dependencies
FROM node:20-alpine AS deps
WORKDIR /app

# Install dependencies based on lockfile
COPY package.json package-lock.json* ./
RUN npm ci --only=production

# Stage 2: Build
FROM node:20-alpine AS builder
WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm ci

COPY . .

# Build the application
ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build

# Stage 3: Production
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# Create non-root user
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copy only necessary files
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

CMD ["node", "server.js"]
```

### Next.js with Standalone Output
```javascript
// next.config.js
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  // Reduces bundle size significantly
};

module.exports = nextConfig;
```

### Python/FastAPI Application
```dockerfile
# Dockerfile
FROM python:3.12-slim AS base

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY . .

# Create non-root user
RUN useradd --create-home --shell /bin/bash app
USER app

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### .dockerignore
```dockerignore
# .dockerignore
node_modules
npm-debug.log
.git
.gitignore
.env
.env.*
!.env.example
Dockerfile
docker-compose*.yml
.dockerignore
README.md
.next
out
coverage
.nyc_output
*.log

# Python
__pycache__
*.pyc
.venv
venv
.pytest_cache

# IDE
.vscode
.idea
*.swp
```

---

## Docker Compose

### Development Setup
```yaml
# docker-compose.yml
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
      target: builder  # Use builder stage for dev
    volumes:
      - .:/app
      - /app/node_modules  # Exclude node_modules
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=development
      - DATABASE_URL=postgresql://postgres:password@db:5432/myapp
      - REDIS_URL=redis://redis:6379
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    command: npm run dev

  db:
    image: postgres:16-alpine
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
      POSTGRES_DB: myapp
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

  # Optional: Database admin
  adminer:
    image: adminer
    ports:
      - "8080:8080"
    depends_on:
      - db

volumes:
  postgres_data:
  redis_data:
```

### Production Setup
```yaml
# docker-compose.prod.yml
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - DATABASE_URL=${DATABASE_URL}
      - REDIS_URL=${REDIS_URL}
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M
```

### Running Commands
```bash
# Development
docker compose up -d
docker compose logs -f app
docker compose exec app npm run db:migrate

# Production
docker compose -f docker-compose.prod.yml up -d --build

# Cleanup
docker compose down -v  # Remove volumes too
docker system prune -a  # Remove unused images
```

---

## Vercel Deployment

### vercel.json Configuration
```json
{
  "framework": "nextjs",
  "regions": ["iad1", "sfo1"],
  "headers": [
    {
      "source": "/api/(.*)",
      "headers": [
        { "key": "Cache-Control", "value": "no-store" }
      ]
    },
    {
      "source": "/(.*)",
      "headers": [
        { "key": "X-Content-Type-Options", "value": "nosniff" },
        { "key": "X-Frame-Options", "value": "DENY" },
        { "key": "X-XSS-Protection", "value": "1; mode=block" }
      ]
    }
  ],
  "rewrites": [
    {
      "source": "/api/proxy/:path*",
      "destination": "https://api.example.com/:path*"
    }
  ],
  "redirects": [
    {
      "source": "/old-page",
      "destination": "/new-page",
      "permanent": true
    }
  ],
  "crons": [
    {
      "path": "/api/cron/daily",
      "schedule": "0 0 * * *"
    }
  ]
}
```

### Environment Variables
```bash
# Set production env vars
vercel env add STRIPE_SECRET_KEY production
vercel env add DATABASE_URL production

# Pull env vars locally
vercel env pull .env.local

# List all env vars
vercel env ls
```

### CLI Commands
```bash
# Deploy to preview
vercel

# Deploy to production
vercel --prod

# Deploy and skip build cache
vercel --force

# Link to existing project
vercel link

# View deployment logs
vercel logs <deployment-url>

# Rollback to previous deployment
vercel rollback
```

### Serverless Function Config
```typescript
// app/api/slow-endpoint/route.ts
export const maxDuration = 60; // seconds (Pro plan)
export const dynamic = 'force-dynamic';

// pages/api/upload.ts (Pages Router)
export const config = {
  api: {
    bodyParser: {
      sizeLimit: '10mb',
    },
    responseLimit: false,
  },
  maxDuration: 60,
};
```

---

## Railway Deployment

### railway.json
```json
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "NIXPACKS",
    "buildCommand": "npm run build"
  },
  "deploy": {
    "startCommand": "npm start",
    "healthcheckPath": "/api/health",
    "healthcheckTimeout": 300,
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 3
  }
}
```

### Procfile (Alternative)
```procfile
web: npm start
worker: npm run worker
```

### Railway CLI
```bash
# Login
railway login

# Initialize project
railway init

# Link to existing project
railway link

# Deploy
railway up

# Open dashboard
railway open

# View logs
railway logs

# Run command in production environment
railway run npm run db:migrate

# Connect to database
railway connect postgres
```

### Database Services
```bash
# Add PostgreSQL
railway add postgres

# Add Redis
railway add redis

# Environment variables are auto-injected:
# DATABASE_URL, REDIS_URL, etc.
```

---

## GitHub Actions CI/CD

### Build and Deploy
```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run linter
        run: npm run lint

      - name: Run tests
        run: npm test

      - name: Run type check
        run: npm run typecheck

  build:
    needs: test
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=sha,prefix=
            type=raw,value=latest

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  deploy:
    needs: build
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    environment: production

    steps:
      - name: Deploy to Railway
        uses: bervProject/railway-deploy@main
        with:
          railway_token: ${{ secrets.RAILWAY_TOKEN }}
          service: my-app

      # Or deploy via SSH
      - name: Deploy via SSH
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.SSH_HOST }}
          username: ${{ secrets.SSH_USERNAME }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd /app
            docker compose pull
            docker compose up -d --remove-orphans
            docker system prune -f
```

### Preview Deployments
```yaml
# .github/workflows/preview.yml
name: Preview

on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  preview:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write

    steps:
      - uses: actions/checkout@v4

      - name: Deploy to Vercel Preview
        uses: amondnet/vercel-action@v25
        id: vercel
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}

      - name: Comment PR
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `🚀 Preview deployed to: ${{ steps.vercel.outputs.preview-url }}`
            })
```

---

## Health Checks

### API Health Endpoint
```typescript
// app/api/health/route.ts
import { NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { redis } from '@/lib/redis';

export const dynamic = 'force-dynamic';

export async function GET() {
  const checks: Record<string, 'ok' | 'error'> = {};

  // Database check
  try {
    await db.$queryRaw`SELECT 1`;
    checks.database = 'ok';
  } catch {
    checks.database = 'error';
  }

  // Redis check
  try {
    await redis.ping();
    checks.redis = 'ok';
  } catch {
    checks.redis = 'error';
  }

  const allHealthy = Object.values(checks).every((v) => v === 'ok');

  return NextResponse.json(
    {
      status: allHealthy ? 'healthy' : 'unhealthy',
      timestamp: new Date().toISOString(),
      checks,
    },
    { status: allHealthy ? 200 : 503 }
  );
}
```

---

## Anti-Patterns

```dockerfile
# ❌ NEVER: Run as root
FROM node:20
WORKDIR /app
COPY . .
RUN npm install
CMD ["npm", "start"]  # Running as root!

# ✅ CORRECT: Use non-root user
RUN adduser --system --uid 1001 app
USER app

# ❌ NEVER: Copy node_modules
COPY . .  # Includes node_modules from local machine!

# ✅ CORRECT: Use .dockerignore and install fresh
COPY package*.json ./
RUN npm ci
COPY . .

# ❌ NEVER: Use latest tag in production
FROM node:latest  # Unpredictable!

# ✅ CORRECT: Pin specific version
FROM node:20.10-alpine

# ❌ NEVER: Store secrets in Dockerfile
ENV DATABASE_URL=postgresql://user:password@host/db

# ✅ CORRECT: Use runtime env vars
# Pass via docker run -e or docker-compose environment
```

---

## Quick Reference

### Docker Commands
| Command | Purpose |
|---------|---------|
| `docker build -t name .` | Build image |
| `docker run -p 3000:3000 name` | Run container |
| `docker compose up -d` | Start services |
| `docker compose down -v` | Stop and remove volumes |
| `docker logs -f container` | Follow logs |
| `docker exec -it container sh` | Shell into container |
| `docker system prune -a` | Clean unused resources |

### Vercel Limits (Hobby)
| Resource | Limit |
|----------|-------|
| Function duration | 10s |
| Function size | 50MB |
| Bandwidth | 100GB/month |
| Builds | 6000 min/month |

### Railway Limits (Hobby)
| Resource | Limit |
|----------|-------|
| Execution | $5 credit/month |
| Memory | 8GB |
| vCPU | 8 cores |

### Deployment Checklist
- [ ] Multi-stage Dockerfile
- [ ] Non-root user in container
- [ ] .dockerignore configured
- [ ] Health check endpoint
- [ ] Environment variables documented
- [ ] CI/CD pipeline set up
- [ ] Preview deployments for PRs
- [ ] Rollback strategy defined
- [ ] Logging and monitoring
- [ ] Resource limits configured
