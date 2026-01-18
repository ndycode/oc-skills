# OC Skills Collection

A portable collection of OpenCode + Codex skills and slash commands for AI-assisted development.

## Contents

### OpenCode Skills (47)
| Category | Skills |
|----------|--------|
| **Security** | `auth-patterns`, `db-security`, `dependency-security`, `headers-cors-csp`, `input-sanitization`, `rate-limit-ddos`, `secrets-management`, `security-web` |
| **Architecture** | `api-design`, `clean-architecture`, `database-patterns`, `node-backend`, `react-architecture`, `state-machines` |
| **Frontend** | `accessibility-a11y`, `forms-validation`, `frontend-design`, `i18n-localization`, `nextjs-patterns`, `performance-web`, `seo-meta`, `vue-modern` |
| **Expo/React Native** | `expo-api-routes`, `expo-building-ui`, `expo-cicd-workflows`, `expo-data-fetching`, `expo-deployment`, `expo-dev-client`, `expo-tailwind-setup`, `expo-upgrading`, `expo-use-dom` |
| **Backend** | `background-jobs`, `caching-redis`, `email-transactional`, `error-observability`, `file-storage`, `realtime-patterns`, `search-patterns` |
| **DevOps** | `audit-logging`, `docker-deploy`, `feature-flags`, `git-workflow` |
| **Other** | `ai-integration`, `flutter-official`, `payments-stripe`, `testing-js`, `typescript-senior` |

### Codex Skills (38)
| Category | Skills |
|----------|--------|
| **Security** | `auth-patterns`, `db-security`, `dependency-security`, `headers-cors-csp`, `input-sanitization`, `rate-limit-ddos`, `secrets-management`, `security-web` |
| **Architecture** | `api-design`, `clean-architecture`, `database-patterns`, `node-backend`, `react-architecture`, `state-machines` |
| **Frontend** | `accessibility-a11y`, `forms-validation`, `i18n-localization`, `nextjs-patterns`, `performance-web`, `seo-meta`, `vue-modern` |
| **Backend** | `background-jobs`, `caching-redis`, `email-transactional`, `error-observability`, `file-storage`, `realtime-patterns`, `search-patterns` |
| **DevOps** | `audit-logging`, `docker-deploy`, `feature-flags`, `git-workflow` |
| **Other** | `ai-integration`, `payments-stripe`, `testing-js`, `typescript-senior` |
| **System** | `skill-creator`, `skill-installer` |

### Slash Commands (4)
| Command | Description |
|---------|-------------|
| `/react-best-prac` | React best practices |
| `/react-perf` | React/Next.js performance optimization |
| `/vercel-deploy` | Deploy applications to Vercel |
| `/vercel-ui-review` | Review UI for Vercel guidelines |

## Installation

### macOS / Linux

```bash
git clone https://github.com/ndycode/oc-skills.git
cd oc-skills
./install.sh
```

### Windows (PowerShell)

```powershell
git clone https://github.com/ndycode/oc-skills.git
cd oc-skills
.\install.ps1
```

### Manual Installation

**OpenCode (macOS/Linux):**
```bash
cp -r skill/* ~/.config/opencode/skill/
cp -r command/* ~/.config/opencode/command/
```

**OpenCode (Windows):**
```powershell
robocopy skill "$env:USERPROFILE\.config\opencode\skill" /E
robocopy command "$env:USERPROFILE\.config\opencode\command" /E
```

**Codex (macOS/Linux):**
```bash
cp -r codex-skill/* ~/.codex/skills/
```

**Codex (Windows):**
```powershell
robocopy codex-skill "$env:USERPROFILE\.codex\skills" /E
```

## Skill Structure

Each skill follows this structure:
```
skill/
  skill-name/
    SKILL.md           # Main skill content
    .skill-meta.json   # Optional metadata
    references/        # Optional additional docs
```

## Slash Command Structure

Slash commands are standalone markdown files:
```
command/
  command-name.md
```

## Usage

After installation, skills are automatically available in OpenCode. You can invoke them:

```
# Skills are invoked via the skill tool
/skill-name

# Slash commands are invoked directly
/react-perf
/vercel-deploy
```

## Adding Custom Skills

1. Create a new directory in `skill/` with your skill name
2. Add a `SKILL.md` file with your skill content
3. Optionally add `.skill-meta.json` for metadata
4. Re-run the installer or manually copy to config

## License

MIT
