---
name: dependency-security
description: Dependency security with npm audit and Snyk
metadata:
  short-description: Dependency security
---

# Dependency Security

> **Sources**: [npm audit](https://docs.npmjs.com/cli/v10/commands/npm-audit), [Snyk](https://snyk.io/), [Socket.dev](https://socket.dev/), [OWASP Dependency Check](https://owasp.org/www-project-dependency-check/)
> **Auto-trigger**: Files containing `package.json`, `package-lock.json`, `npm audit`, dependency management, security vulnerabilities

---

## npm Audit

### Basic Usage
```bash
# Check for vulnerabilities
npm audit

# Get JSON output for CI
npm audit --json

# Only report high/critical
npm audit --audit-level=high

# Fix automatically (when possible)
npm audit fix

# Fix with breaking changes (careful!)
npm audit fix --force
```

### CI Integration
```yaml
# .github/workflows/security.yml
name: Security

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 0 * * *'  # Daily at midnight

jobs:
  audit:
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

      - name: Run npm audit
        run: npm audit --audit-level=high
        continue-on-error: true

      - name: Create audit report
        if: failure()
        run: |
          npm audit --json > audit-report.json
          echo "## Security Audit Failed" >> $GITHUB_STEP_SUMMARY
          echo "High or critical vulnerabilities found." >> $GITHUB_STEP_SUMMARY

      - name: Upload audit report
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: audit-report
          path: audit-report.json
```

---

## Snyk Integration

### Setup
```bash
# Install Snyk CLI
npm install -g snyk

# Authenticate
snyk auth

# Test for vulnerabilities
snyk test

# Monitor project (continuous monitoring)
snyk monitor
```

### GitHub Action
```yaml
# .github/workflows/snyk.yml
name: Snyk Security

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  snyk:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Snyk to check for vulnerabilities
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=high

      - name: Upload Snyk report
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: snyk.sarif
```

### snyk.config.js
```javascript
// snyk.config.js
module.exports = {
  // Ignore specific vulnerabilities
  ignore: {
    'SNYK-JS-EXAMPLE-123456': {
      reason: 'No fix available, mitigated by X',
      expires: '2024-12-31',
    },
  },
  // Severity threshold
  severityThreshold: 'high',
  // Fail on issues
  failOnIssues: true,
};
```

---

## Socket.dev (Supply Chain Security)

### Package.json Integration
```json
{
  "scripts": {
    "prepare": "socket-security check"
  },
  "devDependencies": {
    "@socketsecurity/cli": "^1.0.0"
  }
}
```

### GitHub Action
```yaml
# .github/workflows/socket.yml
name: Socket Security

on:
  pull_request:
    paths:
      - 'package.json'
      - 'package-lock.json'

jobs:
  socket:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Socket Security Scan
        uses: SocketDev/socket-security-action@v1
        with:
          SOCKET_SECURITY_API_KEY: ${{ secrets.SOCKET_SECURITY_API_KEY }}
```

---

## Lockfile Security

### Lockfile Verification
```typescript
// scripts/verify-lockfile.ts
import { execSync } from 'child_process';
import { readFileSync, existsSync } from 'fs';

function verifyLockfile() {
  // Ensure lockfile exists
  if (!existsSync('package-lock.json')) {
    console.error('package-lock.json not found');
    process.exit(1);
  }

  // Ensure lockfile is in sync
  try {
    execSync('npm ci --dry-run', { stdio: 'pipe' });
  } catch (error) {
    console.error('Lockfile out of sync with package.json');
    process.exit(1);
  }

  // Check for registry tampering
  const lockfile = JSON.parse(readFileSync('package-lock.json', 'utf8'));
  
  function checkRegistries(packages: Record<string, any>, path = '') {
    for (const [name, pkg] of Object.entries(packages)) {
      if (pkg.resolved && !pkg.resolved.startsWith('https://registry.npmjs.org/')) {
        // Allow GitHub packages
        if (!pkg.resolved.includes('npm.pkg.github.com')) {
          console.warn(`Suspicious registry for ${path}${name}: ${pkg.resolved}`);
        }
      }
      if (pkg.dependencies) {
        checkRegistries(pkg.dependencies, `${path}${name}/`);
      }
    }
  }

  if (lockfile.packages) {
    checkRegistries(lockfile.packages);
  }

  console.log('Lockfile verification passed');
}

verifyLockfile();
```

### Pre-commit Hook
```yaml
# .husky/pre-commit
#!/bin/sh
. "$(dirname "$0")/_/husky.sh"

# Verify lockfile hasn't been tampered with
npm ci --ignore-scripts --dry-run
```

---

## Dependency Pinning

### Package.json Best Practices
```json
{
  "dependencies": {
    "next": "14.2.3",
    "react": "18.2.0",
    "react-dom": "18.2.0"
  },
  "devDependencies": {
    "typescript": "5.4.5",
    "eslint": "8.57.0"
  },
  "engines": {
    "node": ">=20.0.0",
    "npm": ">=10.0.0"
  },
  "overrides": {
    "vulnerable-package": "2.0.0"
  }
}
```

### Renovate Configuration
```json
// renovate.json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "config:base",
    "security:openssf-scorecard"
  ],
  "schedule": ["before 6am on Monday"],
  "prCreation": "not-pending",
  "prHourlyLimit": 5,
  "packageRules": [
    {
      "matchUpdateTypes": ["patch"],
      "automerge": true
    },
    {
      "matchUpdateTypes": ["minor"],
      "automerge": true,
      "automergeType": "branch"
    },
    {
      "matchUpdateTypes": ["major"],
      "automerge": false,
      "labels": ["major-update"]
    },
    {
      "matchPackagePatterns": ["*"],
      "matchUpdateTypes": ["patch", "minor"],
      "groupName": "all non-major dependencies",
      "groupSlug": "all-minor-patch"
    }
  ],
  "vulnerabilityAlerts": {
    "labels": ["security"],
    "automerge": true
  }
}
```

### Dependabot Configuration
```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
      time: "06:00"
    open-pull-requests-limit: 10
    groups:
      development-dependencies:
        dependency-type: "development"
        update-types:
          - "minor"
          - "patch"
      production-dependencies:
        dependency-type: "production"
        update-types:
          - "patch"
    ignore:
      - dependency-name: "*"
        update-types: ["version-update:semver-major"]
    reviewers:
      - "security-team"
    labels:
      - "dependencies"
```

---

## Allowed Dependencies (Allowlist)

### Configuration
```typescript
// scripts/check-dependencies.ts
const ALLOWED_SCOPES = ['@types', '@next', '@tanstack', '@radix-ui'];
const BLOCKED_PACKAGES = [
  'event-stream',     // Known compromised
  'flatmap-stream',   // Known compromised
  'ua-parser-js',     // Previously compromised
];

const ALLOWED_PACKAGES = [
  'next',
  'react',
  'react-dom',
  'typescript',
  'zod',
  'prisma',
  // ... explicit allowlist
];

interface PackageInfo {
  name: string;
  version: string;
  dependencies?: Record<string, PackageInfo>;
}

function checkDependencies() {
  const lockfile = JSON.parse(readFileSync('package-lock.json', 'utf8'));
  const violations: string[] = [];

  function check(packages: Record<string, any>) {
    for (const [name, pkg] of Object.entries(packages)) {
      const packageName = name.replace(/^node_modules\//, '');

      // Check blocked packages
      if (BLOCKED_PACKAGES.includes(packageName)) {
        violations.push(`BLOCKED: ${packageName} is not allowed`);
        continue;
      }

      // Check against allowlist
      const isScoped = ALLOWED_SCOPES.some(scope => packageName.startsWith(scope + '/'));
      const isAllowed = ALLOWED_PACKAGES.includes(packageName) || isScoped;

      if (!isAllowed) {
        violations.push(`UNAPPROVED: ${packageName} is not in allowlist`);
      }
    }
  }

  if (lockfile.packages) {
    check(lockfile.packages);
  }

  if (violations.length > 0) {
    console.error('Dependency violations found:');
    violations.forEach(v => console.error(`  - ${v}`));
    process.exit(1);
  }

  console.log('All dependencies approved');
}
```

---

## Runtime Protection

### Package Integrity Check
```typescript
// lib/integrity.ts
import { createHash } from 'crypto';
import { readFileSync, readdirSync, statSync } from 'fs';
import { join } from 'path';

// Generate integrity hashes at build time
export function generateIntegrityManifest(nodeModulesPath: string) {
  const manifest: Record<string, string> = {};

  function hashDirectory(dir: string, prefix = '') {
    const entries = readdirSync(dir);
    for (const entry of entries) {
      const fullPath = join(dir, entry);
      const relativePath = prefix ? `${prefix}/${entry}` : entry;
      const stat = statSync(fullPath);

      if (stat.isFile() && entry.endsWith('.js')) {
        const content = readFileSync(fullPath);
        manifest[relativePath] = createHash('sha256').update(content).digest('hex');
      } else if (stat.isDirectory() && !entry.startsWith('.')) {
        hashDirectory(fullPath, relativePath);
      }
    }
  }

  hashDirectory(nodeModulesPath);
  return manifest;
}

// Verify at runtime (optional, for high-security environments)
export function verifyIntegrity(manifest: Record<string, string>, nodeModulesPath: string) {
  for (const [path, expectedHash] of Object.entries(manifest)) {
    const fullPath = join(nodeModulesPath, path);
    const content = readFileSync(fullPath);
    const actualHash = createHash('sha256').update(content).digest('hex');

    if (actualHash !== expectedHash) {
      throw new Error(`Integrity check failed for ${path}`);
    }
  }
}
```

---

## Security Scanning Pipeline

### Complete CI Workflow
```yaml
# .github/workflows/security-scan.yml
name: Security Scan

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 6 * * *'  # Daily at 6 AM

jobs:
  npm-audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: npm audit --audit-level=high

  snyk:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=high

  license-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: npx license-checker --onlyAllow 'MIT;Apache-2.0;BSD-2-Clause;BSD-3-Clause;ISC'

  lockfile-lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: npx lockfile-lint --path package-lock.json --type npm --validate-https --allowed-hosts npm

  osv-scanner:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: google/osv-scanner-action@v1.0.0
        with:
          scan-args: |-
            --lockfile=package-lock.json
```

---

## Anti-Patterns

```bash
# ❌ NEVER: Install without lockfile
npm install  # In CI, always use npm ci

# ✅ CORRECT: Use ci for reproducible builds
npm ci

# ❌ NEVER: Force fix without review
npm audit fix --force  # Can break things!

# ✅ CORRECT: Review and test fixes
npm audit
npm update vulnerable-package
npm test

# ❌ NEVER: Ignore all audit warnings
npm audit || true  # Ignoring everything!

# ✅ CORRECT: Set appropriate threshold
npm audit --audit-level=high

# ❌ NEVER: Use latest for everything
"dependencies": {
  "package": "latest"
}

# ✅ CORRECT: Pin versions
"dependencies": {
  "package": "1.2.3"
}

# ❌ NEVER: Run postinstall scripts blindly
npm install suspicious-package

# ✅ CORRECT: Audit before installing
npm info suspicious-package
npm install suspicious-package --ignore-scripts
# Review scripts, then: npm rebuild
```

---

## Quick Reference

### npm Audit Levels
| Level | Meaning |
|-------|---------|
| info | Informational |
| low | Low severity |
| moderate | Medium severity |
| high | High severity |
| critical | Critical severity |

### Tools Comparison
| Tool | Focus | Cost |
|------|-------|------|
| npm audit | Vulnerabilities | Free |
| Snyk | Vulnerabilities + License | Free tier |
| Socket.dev | Supply chain | Free tier |
| Renovate | Updates | Free |
| Dependabot | Updates | Free |
| OWASP DC | Comprehensive | Free |

### License Compatibility
| License | Commercial Use |
|---------|---------------|
| MIT | ✅ Yes |
| Apache-2.0 | ✅ Yes |
| BSD-2/3-Clause | ✅ Yes |
| ISC | ✅ Yes |
| GPL-3.0 | ⚠️ Copyleft |
| AGPL-3.0 | ⚠️ Strong copyleft |

### Checklist
- [ ] npm audit in CI (--audit-level=high)
- [ ] Snyk or similar for continuous monitoring
- [ ] Lockfile committed and verified
- [ ] Dependencies pinned (exact versions)
- [ ] Renovate/Dependabot for updates
- [ ] License compliance checked
- [ ] Blocked packages list maintained
- [ ] Security alerts enabled
- [ ] Regular dependency review
