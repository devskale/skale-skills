# Command Templates

## Development Commands

### Code Review
```yaml
---
description: Review code changes
agent: review
---
Review the following code changes for:
- Code quality issues
- Potential bugs
- Performance concerns
- Security vulnerabilities
- Style consistency

Changes:
!`git diff --cached`

Provide specific suggestions for improvement.
```

### Fix Tests
```yaml
---
description: Fix failing tests
agent: build
---
The following tests are failing:

!`npm test -- --reporter=json 2>/dev/null | jq '.failures[].fullMsg'`

Analyze the failures and provide fixes for each one.
Implement the fixes.
```

### Update Dependencies
```yaml
---
description: Update outdated dependencies
agent: build
---
Outdated packages:
!`npm outdated --json`

Update all packages to their latest minor/patch versions.
Ensure compatibility and run tests afterward.
```

### Create Component
```yaml
---
description: Create React component
---
Create a new React component named $1 with:
- TypeScript interfaces
- Proper props typing
- Basic structure
- Export statement

Place in: $2
```

## Documentation Commands

### Generate README
```yaml
---
description: Generate README
agent: general
---
Generate a README.md for this project based on:

Project structure:
!`find . -maxdepth 2 -type f -name "*.json" -o -name "*.md" | head -20`

Package.json:
@package.json

Include: overview, installation, usage, and contributing sections.
```

### Document API
```yaml
---
description: Document API endpoints
agent: general
---
Document the API endpoints in @src/routes/

For each endpoint, document:
- HTTP method and path
- Request parameters
- Response format
- Example usage
```

## Git Commands

### Prepare Commit
```yaml
---
description: Prepare commit message
agent: general
---
Staged changes:
!`git diff --cached --stat`

Generate a concise commit message following conventional commits.
Provide the full commit message with body.
```

### Analyze Commits
```yaml
---
description: Analyze commit history
agent: general
---
Recent commits:
!`git log --oneline -20 --graph`

Analyze the commit history and summarize:
- Recent work focus
- Any concerning patterns
- Suggestions for improvement
```

## Debug Commands

### Analyze Performance
```yaml
---
description: Analyze performance
agent: general
---
Performance profile:
!`npm run build -- --profile 2>&1 | head -50`

Bundle analysis:
!`npm run build -- --analyze 2>&1 | head -100`

Suggest optimizations for build size and runtime performance.
```

### Debug Error
```yaml
---
description: Debug error
agent: general
---
Error logs:
!`cat logs/*.log 2>/dev/null | tail -100`

Stack trace:
@error-stack.txt

Identify the root cause and suggest fixes.
```

## Security Commands

### Security Audit
```yaml
---
description: Run security audit
agent: security
---
Security audit results:
!`npm audit --audit-level=high --json`

Vulnerability details:
@audit-report.json

Prioritize and fix critical vulnerabilities.
```

### Scan Secrets
```yaml
---
description: Scan for secrets
agent: security
---
Scan results:
!`gitleaks detect --source=. --verbose 2>&1 | head -50`

Review any potential secret exposures and suggest remediation.
```
