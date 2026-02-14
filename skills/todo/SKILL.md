---
name: todo
description: Create and manage TODO.md task tracking files for complex multi-step work. Use when starting a larger task that benefits from progress tracking, when the user asks to create a todo list, checklist, or task breakdown, or when planning work across multiple sessions. Creates YAML frontmatter with metadata and checkable markdown items.
---

# TODO Task Tracker

Create structured TODO.md files to track progress on complex tasks. Essential for multi-session work where context may be lost.

## When to Create a TODO.md

- Task has 3+ distinct steps or phases
- Work spans multiple sessions
- Complex debugging with multiple hypotheses to test
- Feature development with components
- Refactoring with validation checkpoints
- User explicitly requests a todo/checklist

## TODO.md Structure

```markdown
---
task: "[Brief task description]"
created: "[YYYY-MM-DD HH:MM]"
updated: "[YYYY-MM-DD HH:MM]"
status: "[in-progress|completed|blocked]"
priority: "[high|medium|low]"
tags: "[comma-separated tags]"
context: |
  [Background context - why this task matters, constraints, dependencies]
---

# [Task Name]

## Overview

[1-2 sentence description of what we're accomplishing]

## Checklist

- [ ] [ ] First task item
  - [ ] Subtask if needed
  - [ ] Another subtask
- [ ] Second task item
- [ ] Third task item

## Progress Log

### [YYYY-MM-DD HH:MM]
- What was done
- What's next
- Any blockers

## Notes

- Important decisions made
- Things to remember
- Gotchas discovered
```

## Workflow

### 1. Initialize

When starting a complex task:

```bash
# Create TODO.md in the relevant directory
# Use current timestamp
```

Ask the user (or infer from context):
- Task description and name
- Priority level
- Any known constraints or dependencies

### 2. Generate Checklist

Break down the task into actionable items:

**Good items:**
- [ ] Implement user authentication endpoint
- [ ] Add input validation for email field
- [ ] Write unit tests for password hashing

**Bad items:**
- [ ] Work on auth (too vague)
- [ ] Code stuff (not actionable)
- [ ] Fix things (no specificity)

**Guidelines:**
- Each item should be completable in one session
- Use subtasks for complex items (indent with 2 spaces)
- Group related items together
- Order by dependency (what needs to happen first)

### 3. Track Progress

Update TODO.md as work progresses:

```markdown
- [x] Completed task
- [ ] Remaining task
- [ ] ~Cancelled task~  (strikethrough for cancelled)
```

Always update the `updated:` timestamp when modifying.

### 4. Log Progress

Add entries to the Progress Log section:

```markdown
### 2024-01-15 14:30
- Completed authentication endpoint
- Discovered API rate limit issue
- Next: Implement caching layer
```

### 5. Mark Completion

When a task is done:
- Set `status: completed`
- Add final progress log entry
- Optionally archive or delete TODO.md

## Example: Debugging Session

```markdown
---
task: "Fix memory leak in image processor"
created: "2024-01-15 09:00"
updated: "2024-01-15 11:30"
status: "in-progress"
priority: "high"
tags: "bug, memory, performance"
context: |
  Users reporting OOM errors after processing 50+ images.
  Started after v2.3.0 release. Likely related to new caching.
---

# Fix Memory Leak in Image Processor

## Overview

Investigate and fix memory leak causing OOM errors during batch image processing.

## Checklist

- [x] Reproduce the issue locally
  - [x] Create test dataset with 50 images
  - [x] Confirm memory growth with `top`
- [x] Profile memory usage
  - [x] Add logging for allocations
  - [x] Identify leak source in cache layer
- [ ] Fix the leak
  - [ ] Implement proper cache eviction
  - [ ] Add memory limits
- [ ] Validate fix
  - [ ] Run test dataset without OOM
  - [ ] Check memory stays stable
- [ ] Add regression test

## Progress Log

### 2024-01-15 09:00
- Started investigation
- Reproduced issue with 60-image batch
- Memory grows from 200MB to 2GB+

### 2024-01-15 10:15
- Added memory profiling
- Found: ImageCache holds references indefinitely
- No eviction policy implemented

### 2024-01-15 11:30
- Implementing LRU cache eviction
- Next: Test with memory limits

## Notes

- Cache was added in v2.3.0 commit abc123
- Consider using WeakRefs for large objects
- May need to limit batch size as additional safeguard
```

## Example: Feature Development

```markdown
---
task: "Add dark mode support"
created: "2024-01-15 09:00"
updated: "2024-01-15 09:00"
status: "in-progress"
priority: "medium"
tags: "feature, ui, css"
context: |
  Users requesting dark mode. Should use CSS custom properties
  and respect prefers-color-scheme. Store preference in localStorage.
---

# Add Dark Mode Support

## Overview

Implement system-aware dark mode with manual toggle and persistent preference.

## Checklist

- [ ] Design phase
  - [ ] Define color palette (dark/light)
  - [ ] Create CSS custom properties
- [ ] Implementation
  - [ ] Add theme toggle component
  - [ ] Implement localStorage persistence
  - [ ] Add system preference detection
- [ ] Testing
  - [ ] Test toggle in all browsers
  - [ ] Verify persistence across sessions
  - [ ] Check system preference sync
- [ ] Documentation
  - [ ] Update user guide
  - [ ] Add to changelog

## Progress Log

### 2024-01-15 09:00
- Task initialized
- Starting design phase

## Notes

- Use `prefers-color-scheme` media query
- Fallback to light mode if no preference
- Consider adding transition animation
```

## Quick Commands

Check current progress:
```bash
grep -E "^\s*-\s*\[" TODO.md | head -20
```

Count completed vs remaining:
```bash
echo "Completed: $(grep -c '^\s*- \[x\]' TODO.md)"
echo "Remaining: $(grep -c '^\s*- \[ \]' TODO.md)"
```

## Best Practices

1. **Be specific**: "Fix login bug on mobile" not "Fix bugs"
2. **Right granularity**: Tasks completable in one session
3. **Update frequently**: Log progress as you go
4. **Include context**: Future-you will thank present-you
5. **Use subtasks**: Break complex items into steps
6. **Mark blocked items**: Note blockers in progress log
7. **Archive when done**: Keep completed TODOs for reference
