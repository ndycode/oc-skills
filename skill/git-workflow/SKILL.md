# Git Workflow & CI/CD

> **Auto-trigger**: Git operations, `.github/workflows/`, CI/CD setup

---

## 1. Conventional Commits

### 1.1 Format

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### 1.2 Types

| Type | Description | Example |
|------|-------------|---------|
| `feat` | New feature | `feat(auth): add password reset` |
| `fix` | Bug fix | `fix(api): handle null response` |
| `docs` | Documentation | `docs: update API readme` |
| `style` | Formatting | `style: fix indentation` |
| `refactor` | Code refactoring | `refactor(db): optimize queries` |
| `perf` | Performance | `perf: lazy load images` |
| `test` | Tests | `test(auth): add login tests` |
| `build` | Build system | `build: update webpack` |
| `ci` | CI/CD | `ci: add deploy workflow` |
| `chore` | Maintenance | `chore: update deps` |
| `revert` | Revert commit | `revert: feat(auth): add oauth` |

### 1.3 Breaking Changes

```bash
# With footer
feat(api): change response format

BREAKING CHANGE: Response now uses camelCase keys

# With ! in type
feat(api)!: change response format

Changed all response keys from snake_case to camelCase.
```

### 1.4 Commitlint Config

```javascript
// commitlint.config.js
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [
      2,
      'always',
      ['feat', 'fix', 'docs', 'style', 'refactor', 'perf', 'test', 'build', 'ci', 'chore', 'revert'],
    ],
    'subject-case': [2, 'always', 'lower-case'],
    'subject-max-length': [2, 'always', 72],
    'body-max-line-length': [2, 'always', 100],
  },
};
```

---

## 2. Branch Strategy

### 2.1 GitHub Flow (Recommended for Most)

```
main ─────────────────────────────────────────►
       ↑         ↑         ↑
       │         │         │
  feature/a  feature/b  feature/c
       └─────────┴─────────┘
            merge via PR
```

### 2.2 Branch Naming

```bash
# Feature branches
feature/auth-oauth-google
feature/user-profile-page

# Bug fixes
fix/login-redirect-loop
fix/null-pointer-dashboard

# Improvements
improve/api-response-time
refactor/database-queries

# Hotfixes (production issues)
hotfix/payment-calculation
```

### 2.3 Branch Protection Rules

```yaml
# Required for main branch:
# - Require PR reviews (1+)
# - Require status checks to pass
# - Require branch to be up to date
# - No direct pushes
# - No force pushes
```

---

## 3. PR Templates

### 3.1 Pull Request Template

```markdown
<!-- .github/PULL_REQUEST_TEMPLATE.md -->
## Description
<!-- What does this PR do? -->

## Type of Change
- [ ] Bug fix (non-breaking change fixing an issue)
- [ ] New feature (non-breaking change adding functionality)
- [ ] Breaking change (fix or feature causing existing functionality to change)
- [ ] Documentation update

## How Has This Been Tested?
<!-- Describe testing approach -->
- [ ] Unit tests
- [ ] Integration tests
- [ ] Manual testing

## Checklist
- [ ] My code follows the project's style guidelines
- [ ] I have performed a self-review
- [ ] I have commented my code where necessary
- [ ] I have updated the documentation
- [ ] My changes generate no new warnings
- [ ] I have added tests that prove my fix/feature works
- [ ] New and existing tests pass locally

## Screenshots (if applicable)
<!-- Add screenshots for UI changes -->

## Related Issues
Closes #<!-- issue number -->
```

---

## 4. GitHub Actions

### 4.1 CI Workflow

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v3
        with:
          version: 9
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'pnpm'
      - run: pnpm install --frozen-lockfile
      - run: pnpm lint

  typecheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v3
        with:
          version: 9
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'pnpm'
      - run: pnpm install --frozen-lockfile
      - run: pnpm typecheck

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v3
        with:
          version: 9
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'pnpm'
      - run: pnpm install --frozen-lockfile
      - run: pnpm test:ci
      - uses: codecov/codecov-action@v4
        with:
          token: ${{ secrets.CODECOV_TOKEN }}

  build:
    runs-on: ubuntu-latest
    needs: [lint, typecheck, test]
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v3
        with:
          version: 9
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'pnpm'
      - run: pnpm install --frozen-lockfile
      - run: pnpm build
```

### 4.2 Deploy Workflow

```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4

      - name: Deploy to Vercel
        uses: amondnet/vercel-action@v25
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
          vercel-args: '--prod'
```

### 4.3 Reusable Workflow

```yaml
# .github/workflows/reusable-deploy.yml
name: Reusable Deploy

on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
    secrets:
      DEPLOY_TOKEN:
        required: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}
    steps:
      - uses: actions/checkout@v4
      - run: ./deploy.sh
        env:
          TOKEN: ${{ secrets.DEPLOY_TOKEN }}

# Usage in another workflow
jobs:
  deploy-staging:
    uses: ./.github/workflows/reusable-deploy.yml
    with:
      environment: staging
    secrets:
      DEPLOY_TOKEN: ${{ secrets.STAGING_TOKEN }}
```

---

## 5. Git Hooks (Husky)

### 5.1 Setup

```bash
pnpm add -D husky lint-staged @commitlint/cli @commitlint/config-conventional
pnpm exec husky init
```

### 5.2 Pre-commit Hook

```bash
# .husky/pre-commit
pnpm lint-staged
```

```json
// package.json
{
  "lint-staged": {
    "*.{ts,tsx}": ["eslint --fix", "prettier --write"],
    "*.{json,md,yml}": ["prettier --write"]
  }
}
```

### 5.3 Commit-msg Hook

```bash
# .husky/commit-msg
pnpm exec commitlint --edit $1
```

### 5.4 Pre-push Hook

```bash
# .husky/pre-push
pnpm typecheck
pnpm test
```

---

## 6. Release Automation

### 6.1 Semantic Release

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    branches: [main]

permissions:
  contents: write
  issues: write
  pull-requests: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
          persist-credentials: false
      
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      
      - run: npm install
      
      - name: Release
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
        run: npx semantic-release
```

```javascript
// release.config.js
module.exports = {
  branches: ['main'],
  plugins: [
    '@semantic-release/commit-analyzer',
    '@semantic-release/release-notes-generator',
    '@semantic-release/changelog',
    '@semantic-release/npm',
    '@semantic-release/github',
    [
      '@semantic-release/git',
      {
        assets: ['CHANGELOG.md', 'package.json'],
        message: 'chore(release): ${nextRelease.version} [skip ci]',
      },
    ],
  ],
};
```

### 6.2 Changesets

```bash
pnpm add -D @changesets/cli
pnpm changeset init
```

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    branches: [main]

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v3
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'pnpm'
      
      - run: pnpm install
      
      - name: Create Release PR or Publish
        uses: changesets/action@v1
        with:
          publish: pnpm release
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
```

---

## 7. Git Commands Cheat Sheet

### 7.1 Daily Commands

```bash
# Start new feature
git checkout -b feature/new-feature

# Stage and commit
git add .
git commit -m "feat: add new feature"

# Push and create PR
git push -u origin feature/new-feature

# Update from main
git fetch origin
git rebase origin/main

# Squash commits before PR
git rebase -i HEAD~3
```

### 7.2 Fixing Mistakes

```bash
# Amend last commit
git commit --amend -m "new message"

# Undo last commit (keep changes)
git reset --soft HEAD~1

# Undo last commit (discard changes)
git reset --hard HEAD~1

# Revert a commit (creates new commit)
git revert <commit-hash>

# Stash changes
git stash
git stash pop
```

### 7.3 Advanced

```bash
# Cherry-pick commit
git cherry-pick <commit-hash>

# Interactive rebase
git rebase -i HEAD~5

# Find commit that introduced bug
git bisect start
git bisect bad HEAD
git bisect good v1.0.0

# Clean untracked files
git clean -fd
```

---

## Quick Reference

### Commit Message Examples

```bash
# Feature
feat(auth): add Google OAuth login

# Fix with issue reference
fix(api): handle null response body

Closes #123

# Breaking change
feat(api)!: change response format to JSON:API

BREAKING CHANGE: All endpoints now return JSON:API format.
Migration guide: docs/migration.md

# Multiple scopes
feat(auth,api): add JWT refresh tokens

# Chore
chore(deps): update dependencies
```

### GitHub Actions Matrix

```yaml
jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
        node: [18, 20, 22]
    steps:
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node }}
```

### Branch Protection Checklist
- [ ] Require pull request reviews
- [ ] Require status checks to pass
- [ ] Require conversation resolution
- [ ] Require signed commits
- [ ] Include administrators
- [ ] Restrict who can push
