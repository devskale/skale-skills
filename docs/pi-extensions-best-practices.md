# Pi Coding Agent Extensions — Best Practices

A field guide to writing robust, composable, and user-friendly extensions for the [pi coding agent](https://pi.dev).

> **Scope.** This is a best-practice companion to the official [extensions.md](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/extensions.md) reference. It does not re-document the API; instead it distils patterns, pitfalls, and conventions observed across the built-in examples, the extension ecosystem, and production deployments.

---

## Table of Contents

1. [Decide What Kind of Extension You Need](#1-decide-what-kind-of-extension-you-need)
2. [Scaffolding & File Layout](#2-scaffolding--file-layout)
3. [Extension Entry Point](#3-extension-entry-point)
4. [Tool Registration — Do's and Don'ts](#4-tool-registration--dos-and-donts)
5. [Schema Design with TypeBox](#5-schema-design-with-typebox)
6. [State Management — The Branching Trap](#6-state-management--the-branching-trap)
7. [Event Handlers — Lifecycle Discipline](#7-event-handlers--lifecycle-discipline)
8. [Error Handling & Fail-Safe Defaults](#8-error-handling--fail-safe-defaults)
9. [Output Truncation — Non-Negotiable](#9-output-truncation--non-negotiable)
10. [Custom UI — Keep It Lean](#10-custom-ui--keep-it-lean)
11. [Mode Awareness — Headless Is Real](#11-mode-awareness--headless-is-real)
12. [Blocking & Gate Patterns](#12-blocking--gate-patterns)
13. [Session Replacement — Footgun Avoidance](#13-session-replacement--footgun-avoidance)
14. [Composing Extensions](#14-composing-extensions)
15. [Distributing Extensions](#15-distributing-extensions)
16. [Testing Strategy](#16-testing-strategy)
17. [Security Considerations](#17-security-considerations)
18. [Anti-Patterns](#18-anti-patterns)
19. [Gotchas — Real-World Pitfalls](#19-gotchas--real-world-pitfalls)
20. [Community Patterns — What Production Extensions Do](#20-community-patterns--what-production-extensions-do)
21. [Checklist](#21-checklist)
22. [Further Reading](#22-further-reading)

---

## 1. Decide What Kind of Extension You Need

Pi extensions sit on a spectrum from trivial to complex. Match your approach to the job:

| Category | Examples | Key APIs | Complexity |
|----------|----------|----------|------------|
| **Gating** | Block `rm -rf`, protect `.env` | `on("tool_call")` → `{ block }` | ★☆☆ |
| **Input transform** | Shortcuts, routing, instant replies | `on("input")` → `{ transform/handled }` | ★☆☆ |
| **Tool** | LLM-callable capability | `registerTool()` | ★★☆ |
| **Command** | Slash command for humans | `registerCommand()` | ★☆☆ |
| **Status / Widget** | Footer indicator, progress bar | `setStatus`, `setWidget` | ★★☆ |
| **Stateful tool** | Todo list, connection pool | `registerTool` + session reconstruction | ★★★ |
| **Mode switcher** | Plan mode, preset system | Commands + flags + `setActiveTools` + messages | ★★★ |
| **Full overlay UI** | Games, modals, complex wizards | `ui.custom()` + `@pi-tui` components | ★★★★ |

**Rule of thumb:** Start with the simplest approach. You can always escalate from a `tool_call` gate to a full custom tool later.

---

## 2. Scaffolding & File Layout

### Placement

| Location | Scope | Hot-reload? |
|----------|-------|-------------|
| `~/.pi/agent/extensions/*.ts` | Global (all projects) | ✅ `/reload` |
| `~/.pi/agent/extensions/*/index.ts` | Global (multi-file) | ✅ `/reload` |
| `.pi/extensions/*.ts` | Project-local | ✅ `/reload` |
| `.pi/extensions/*/index.ts` | Project-local (multi-file) | ✅ `/reload` |

**Best practice:** Use `-e` for quick prototyping only. Ship to the auto-discovery paths so `/reload` works.

### Single file (simple)

```
~/.pi/agent/extensions/
└── permission-gate.ts          # One concern, one file
```

### Directory with index.ts (multi-file)

```
~/.pi/agent/extensions/
└── plan-mode/
    ├── index.ts                # Entry point — exports default
    ├── utils.ts                # Extracted helpers
    └── plan-mode.test.ts       # Tests alongside source
```

### Package with npm dependencies

```
~/.pi/agent/extensions/
└── my-extension/
    ├── package.json            # Declares dependencies + pi entry
    ├── package-lock.json
    ├── node_modules/
    └── src/
        └── index.ts
```

```jsonc
// package.json
{
  "name": "my-extension",
  "dependencies": { "zod": "^3.0.0" },
  "pi": {
    "extensions": ["./src/index.ts"]
  }
}
```

Run `npm install` in the directory. Imports from `node_modules/` are resolved automatically.

### Conventions

- Name files in **kebab-case**: `permission-gate.ts`, `git-checkpoint.ts`
- The directory name IS the extension name. Use descriptive names.
- Co-locate tests next to the extension: `my-ext.test.ts` beside `my-ext.ts`.
- Keep `index.ts` as the public surface. Hide helpers in adjacent modules.

---

## 3. Extension Entry Point

The entry point is a **default export factory function** receiving `ExtensionAPI`:

```typescript
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  // Subscribe to events, register tools/commands
}
```

### Synchronous vs async factory

Use **sync** by default. Only go async when you need to await external resources at startup (fetching remote config, discovering models):

```typescript
// ✅ Async for one-time startup work — models available before session_start
export default async function (pi: ExtensionAPI) {
  const response = await fetch("http://localhost:1234/v1/models");
  const models = (await response.json()).data;
  pi.registerProvider("local-llm", { models, ... });
}
```

### Imports available

| Package | Use for |
|---------|---------|
| `@earendil-works/pi-coding-agent` | Types (`ExtensionAPI`, `ExtensionContext`), utilities (`truncateHead`, `withFileMutationQueue`) |
| `typebox` | Schema definitions for tool parameters |
| `@earendil-works/pi-ai` | `StringEnum` (required for Google models), `complete()` |
| `@earendil-works/pi-tui` | TUI components (`Text`, `Key`, `Editor`, `SelectList`) |
| Node built-ins | `node:fs/promises`, `node:path`, `node:net`, etc. |

**Tip:** Extensions are loaded via [jiti](https://github.com/unjs/jiti) — TypeScript works without compilation.

---

## 4. Tool Registration — Do's and Don'ts

### Minimal tool (with `defineTool`)

`defineTool()` is an exported helper that provides full type inference for params, execute args, and render contexts. The built-in `hello.ts` example uses it:

```typescript
import { Type } from "typebox";
import { defineTool, type ExtensionAPI } from "@earendil-works/pi-coding-agent";

const helloTool = defineTool({
  name: "hello",
  label: "Hello",
  description: "A simple greeting tool",
  parameters: Type.Object({
    name: Type.String({ description: "Name to greet" }),
  }),
  async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
    return {
      content: [{ type: "text", text: `Hello, ${params.name}!` }],
      details: { greeted: params.name },
    };
  },
});

export default function (pi: ExtensionAPI) {
  pi.registerTool(helloTool);
}
```

You can also pass the tool definition inline to `registerTool()` without `defineTool` — both work. `defineTool` is purely for better type narrowing at the call site.

### Minimal tool (inline)

```typescript
import { Type } from "typebox";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "greet",
    label: "Greet",
    description: "Greet someone by name",
    parameters: Type.Object({
      name: Type.String({ description: "Name to greet" }),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      return {
        content: [{ type: "text", text: `Hello, ${params.name}!` }],
        details: { greeted: params.name },
      };
    },
  });
}
```

### Do's

| Do | Why |
|----|-----|
| **Use `promptSnippet`** | One-line summary in the system prompt's "Available tools" section — without it, the LLM won't know your tool exists unless it reads the full description |
| **Use `promptGuidelines`** with explicit tool names | Bullets appended to the "Guidelines" section. Always write the tool name: `Use my_tool when...` not `Use this tool when...` |
| **Return `{ content, details }`** | `content` goes to the LLM. `details` goes to rendering and state reconstruction. Both matter. |
| **Use `details` for state** | Enables proper branching — fork/clone at different points gets the correct state |
| **Handle `signal?.aborted`** | Respects user cancellation. Pass `signal` to `fetch()`, `pi.exec()`, etc. |
| **Use `onUpdate()` for progress** | Streams intermediate results to the TUI during long operations |
| **Use `prepareArguments()`** for schema migration | Keeps old sessions resumable when you change the parameter shape |

### Don'ts

| Don't | Why |
|-------|-----|
| **Don't use `Type.Union`/`Type.Literal` for enums** | Doesn't work with Google's API. Use `StringEnum` from `@earendil-works/pi-ai` |
| **Don't forget to truncate output** | See [§9](#9-output-truncation--non-negotiable) |
| **Don't write state to external files** | Use tool result `details` or `pi.appendEntry()` instead — files break branching |
| **Don't mutate `event.input` without understanding the contract** | Mutations affect actual execution. No re-validation runs after your mutation. |
| **Don't return error info as content** | Throw an `Error` instead — it sets `isError: true` for the LLM |
| **Don't omit `details` on any return branch** | `details` is **required** on `AgentToolResult`, not optional. Every `return { content }` must include it (even `{}`) or strict typecheck fails |

### Signaling errors

```typescript
// ✅ Correct — sets isError: true on the result
async execute(_id, params) {
  if (!isValid(params.input)) {
    throw new Error(`Invalid input: ${params.input}`);
  }
  return { content: [{ type: "text", text: "OK" }], details: {} };
}

// ❌ Wrong — isError is NOT set by returning values
async execute(_id, params) {
  if (!isValid(params.input)) {
    return { content: [{ type: "text", text: "Error: invalid" }], details: { error: true } };
  }
}
```

### Early termination

Return `terminate: true` when the tool is the final step and no follow-up LLM call is needed:

```typescript
return {
  content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
  details: { result },
  terminate: true,  // Skip automatic follow-up turn
};
```

Only takes effect when **all** finalized tools in the batch return `terminate: true`.

### Dynamic tool registration

Tools registered after startup (in event handlers, commands) appear immediately — no `/reload` needed:

```typescript
pi.on("session_start", (_event, ctx) => {
  pi.registerTool({
    name: "echo_session",
    label: "Echo Session",
    description: "Echo a message",
    parameters: Type.Object({ message: Type.String() }),
    async execute(_id, params) {
      return { content: [{ type: "text", text: params.message }], details: {} };
    },
  });
});
```

---

## 5. Schema Design with TypeBox

### String enums — always use `StringEnum`

```typescript
import { StringEnum } from "@earendil-works/pi-ai";
import { Type } from "typebox";

// ✅ Works with all providers (Anthropic, Google, OpenAI)
const params = Type.Object({
  action: StringEnum(["list", "add", "toggle"] as const),
});

// ❌ Breaks Google's API
const params = Type.Object({
  action: Type.Union([
    Type.Literal("list"),
    Type.Literal("add"),
    Type.Literal("toggle"),
  ]),
});
```

### Descriptions are prompt context

The `description` field on each parameter is sent to the LLM. Write them for a machine reader, not a human:

```typescript
// ✅ Clear, specific
Type.String({ description: "Absolute or relative path to the file to read" })

// ❌ Vague
Type.String({ description: "Path" })
```

### `prepareArguments` for backward compatibility

When you change the schema shape, use `prepareArguments` to translate old sessions:

```typescript
prepareArguments(args) {
  // Old sessions may have top-level oldText/newText
  if (typeof args.oldText === "string") {
    return { ...args, edits: [{ oldText: args.oldText, newText: args.newText }] };
  }
  return args;
}
```

---

## 6. State Management — The Branching Trap

This is the single most common source of bugs in stateful extensions.

### The problem

Pi supports conversation branching (`/fork`, `/tree`). When you branch at entry #15, the new session replays entries 1–15. If your extension stores state in a module-level variable that was set at entry #42, the forked session sees the wrong state.

### The solution — store state in session entries

```typescript
let items: string[] = [];
let nextId = 1;

// Reconstruct state from session history
pi.on("session_start", async (_event, ctx) => {
  items = [];
  nextId = 1;
  for (const entry of ctx.sessionManager.getBranch()) {
    if (entry.type === "message" && entry.message.role === "toolResult") {
      if (entry.message.toolName === "todo") {
        const details = entry.message.details as { todos: Todo[]; nextId: number };
        items = details.todos;
        nextId = details.nextId;
      }
    }
  }
});
```

**Pattern:** Always return full state in `details` on every tool call. Reconstruction scans the branch and takes the last snapshot.

### Also reconstruct on `session_tree`

When navigating the tree (`/tree`), the branch changes. Always listen to both:

```typescript
pi.on("session_start", async (_event, ctx) => reconstructState(ctx));
pi.on("session_tree", async (_event, ctx) => reconstructState(ctx));
```

### Alternative — `pi.appendEntry()` for non-LLM state

For state that shouldn't appear in LLM context (e.g., UI preferences, counters):

```typescript
// Save
pi.appendEntry("my-state", { count: 42 });

// Restore
pi.on("session_start", async (_event, ctx) => {
  for (const entry of ctx.sessionManager.getEntries()) {
    if (entry.type === "custom" && entry.customType === "my-state") {
      // Reconstruct from entry.data
    }
  }
});
```

**Note:** `appendEntry` does NOT participate in LLM context. It persists across restarts but isn't sent to the model.

---

## 7. Event Handlers — Lifecycle Discipline

### Pick the right event

| Want to… | Use |
|----------|-----|
| Add tools/skills at startup | `session_start` |
| Inject context per-turn | `before_agent_start` |
| Modify messages before LLM call | `context` |
| Block a tool call | `tool_call` |
| Modify a tool result | `tool_result` |
| Track progress | `turn_start` / `turn_end` |
| React to user input | `input` |
| Clean up before shutdown | `session_shutdown` |

### Return only what you need

```typescript
// ✅ Correct — only block for matching tools
pi.on("tool_call", async (event, ctx) => {
  if (event.toolName !== "bash") return undefined;  // Let other tools pass
  // ...
});

// ❌ Returning { block: false } still blocks! Return undefined to pass through
pi.on("tool_call", async (event, ctx) => {
  return { block: false };  // Don't do this — return undefined instead
});
```

### Don't deadlock in event handlers

Never call `ctx.newSession()`, `ctx.fork()`, `ctx.switchSession()`, or `ctx.reload()` from event handlers. These are only available in command handlers. Use `pi.sendUserMessage("/my-command")` to bridge.

### The lifecycle flow (simplified)

```
input → before_agent_start → turn_start → context → [tool_call → tool_result]×N → turn_end → agent_end
```

Key ordering guarantees:
- `before_agent_start` fires before the agent loop
- `context` fires before each LLM call (including mid-turn calls)
- `tool_call` fires after `tool_execution_start`, before execution
- `tool_result` fires after execution, before `tool_execution_end`
- Handler return values chain across extensions in load order

---

## 8. Error Handling & Fail-Safe Defaults

### Extension errors don't crash pi

Pi catches extension errors and continues. Your extension should follow suit:

```typescript
// ✅ Fail-safe — block dangerous operations, let safe ones through
pi.on("tool_call", async (event, ctx) => {
  if (event.toolName !== "bash") return undefined;

  if (isDangerous(event.input.command)) {
    if (!ctx.hasUI) {
      // No UI available → block (safe default)
      return { block: true, reason: "Dangerous command blocked (no UI for confirmation)" };
    }
    const ok = await ctx.ui.confirm("Allow?", event.input.command);
    if (!ok) return { block: true, reason: "Blocked by user" };
  }
});
```

### Graceful degradation in non-interactive mode

```typescript
async execute(_id, params, _signal, _onUpdate, ctx) {
  if (ctx.mode !== "tui") {
    return {
      content: [{ type: "text", text: "UI required — not available in this mode" }],
      details: {},
    };
  }
  // ... interactive UI code
}
```

### Always handle `signal`

```typescript
async execute(_id, params, signal, _onUpdate, ctx) {
  const response = await fetch("https://api.example.com", { signal });
  // If user cancels (Esc), signal.aborted becomes true and fetch throws
}
```

---

## 9. Output Truncation — Non-Negotiable

Custom tools that return large output **must** truncate. Pi's built-in limit is **50KB / 2000 lines**. Exceeding this causes context overflow, compaction failures, and degraded model performance.

```typescript
import {
  truncateHead,
  truncateTail,
  formatSize,
  DEFAULT_MAX_BYTES,
  DEFAULT_MAX_LINES,
} from "@earendil-works/pi-coding-agent";

async execute(_id, params, _signal, _onUpdate, ctx) {
  const output = await runCommand();

  const truncation = truncateHead(output, {
    maxLines: DEFAULT_MAX_LINES,
    maxBytes: DEFAULT_MAX_BYTES,
  });

  let text = truncation.content;

  if (truncation.truncated) {
    // Write full output to a temp file
    const tempFile = await writeTempFile(output);
    text += `\n\n[Output truncated: ${truncation.outputLines} of ${truncation.totalLines} lines.`;
    text += ` Full output: ${tempFile}]`;
  }

  return { content: [{ type: "text", text }], details: {} };
}
```

| Utility | Use when |
|---------|----------|
| `truncateHead` | Search results, file reads (beginning matters) |
| `truncateTail` | Logs, command output (end matters) |
| `formatSize` | Human-readable sizes in truncation notices |

**Also document the truncation in the tool description** so the LLM knows:

```typescript
description: `Search code. Output truncated to ${DEFAULT_MAX_LINES} lines / ${formatSize(DEFAULT_MAX_BYTES)}. Full output saved to temp file when truncated.`
```

---

## 10. Custom UI — Keep It Lean

### Built-in dialogs (no TUI component needed)

```typescript
// Quick selections — prefer these when possible
const choice = await ctx.ui.select("Pick:", ["A", "B", "C"]);
const ok = await ctx.ui.confirm("Sure?", "Description");
const name = await ctx.ui.input("Name:", "placeholder");
const text = await ctx.ui.editor("Edit:", "default");
```

### Custom components — only when you need full control

Use `ctx.ui.custom()` for complex interactions that built-in dialogs can't handle (multi-step wizards, settings hubs, games). The factory receives `(tui, theme, keybindings, done)` and returns a `Component` — an object with `render(width): string[]` plus optional `invalidate()` and `handleInput(data)`. Call `done(value)` to close and resolve the promise.

The canonical shape (from the built-in `tools.ts` example) wraps a `Container`, delegates input to the interactive child, and calls `tui.requestRender()` after each keystroke:

```typescript
import { Container, SettingsList, type SettingItem } from "@earendil-works/pi-tui";
import { getSettingsListTheme } from "@earendil-works/pi-coding-agent";

await ctx.ui.custom((tui, theme, _kb, done) => {
  const items: SettingItem[] = [
    { id: "autocompact", label: "Auto-compact", currentValue: "true", values: ["true", "false"] },
    // `values` → cycles on Enter/Space; `submenu` → returns a Component picker
  ];
  const list = new SettingsList(items, 10, getSettingsListTheme(),
    (id, value) => { /* apply change immediately */ },
    () => done(undefined));              // Esc closes
  const c = new Container();
  c.addChild(new Text(theme.fg("accent", theme.bold("My settings")), 0, 0));
  c.addChild(list);
  return {
    render: (w) => c.render(w),
    invalidate: () => c.invalidate(),
    handleInput: (d) => { list.handleInput?.(d); tui.requestRender(); },
  };
});
```

### Reuse pi's own components for a native look

You don't have to reimplement the settings UI — pi exports its real components from `@earendil-works/pi-tui`, and matching theme helpers from `@earendil-works/pi-coding-agent`. Mount them inside `ctx.ui.custom()` and your hub looks and behaves like pi's own `/config`:

| Import | Use |
|--------|-----|
| `SettingsList`, `SettingItem` | Scrollable settings list — `values` cycles inline, `submenu` opens a picker |
| `SelectList`, `SelectItem` | Searchable picker (ideal as a `submenu`) |
| `Container`, `Text`, `Spacer`, `Box` | Layout primitives |
| `DynamicBorder` | The same bordered framing pi's panels use |
| `getSettingsListTheme()`, `getSelectListTheme()` | Theme fns closing over pi's *active* theme — pixel-matches pi's UI |

Persist on every change (**write-through** — the native settings list has no Save button), and guard with `if (ctx.mode !== "tui")` falling back to a `notify` summary otherwise (see [§11](#11-mode-awareness--headless-is-real)).

### Rendering rules

- Use `Text` with padding `(0, 0)` — the default `Box` wrapper handles padding
- Handle `isPartial` for streaming progress states
- Support `expanded` for detail-on-demand
- Keep default view compact; show details only when expanded
- Use `context.state` for shared data between `renderCall` and `renderResult`
- Reuse `context.lastComponent` to update in place instead of creating new objects
- Use `renderShell: "self"` only when the default box framing interferes

### Status, widgets, and footer

```typescript
// Footer status (persistent)
ctx.ui.setStatus("my-ext", "Processing...");
ctx.ui.setStatus("my-ext", undefined);  // Clear

// Widget above editor
ctx.ui.setWidget("my-ext", ["Line 1", "Line 2"]);
ctx.ui.setWidget("my-ext", undefined);  // Clear

// Custom footer (replaces built-in entirely)
ctx.ui.setFooter((tui, theme) => ({
  render(width) { return [theme.fg("dim", "Custom footer")]; },
  invalidate() {},
}));
ctx.ui.setFooter(undefined);  // Restore built-in
```

### Theme colors

```typescript
theme.fg("toolTitle", text)   // Tool names
theme.fg("accent", text)      // Highlights
theme.fg("success", text)     // Green / completed
theme.fg("error", text)       // Red / errors
theme.fg("warning", text)     // Yellow / caution
theme.fg("muted", text)       // Secondary text
theme.fg("dim", text)         // Tertiary text
theme.bold(text)              // Bold
theme.italic(text)            // Italic
theme.strikethrough(text)     // Strikethrough (completed items)
```

---

## 11. Mode Awareness — Headless Is Real

Pi runs in multiple modes. Your extension must not assume a terminal.

```typescript
const { mode, hasUI } = ctx;
```

| Mode | `mode` | `hasUI` | TUI? |
|------|--------|---------|------|
| Interactive | `"tui"` | `true` | ✅ Full TUI |
| RPC | `"rpc"` | `true` | ❌ `custom()` returns `undefined` |
| JSON | `"json"` | `false` | ❌ UI methods are no-ops |
| Print | `"print"` | `false` | ❌ No prompts |

### Guard patterns

```typescript
// Guard terminal-only features
if (ctx.mode !== "tui") {
  ctx.ui.notify("Feature requires interactive mode", "warning");
  return;
}

// Guard all UI features (works for both TUI and RPC)
if (!ctx.hasUI) {
  return { block: true, reason: "No UI for confirmation" };
}
```

**In gate extensions:** When `hasUI` is false and you need confirmation, **block by default**. This is the safe failure mode:

```typescript
if (!ctx.hasUI) {
  return { block: true, reason: "Dangerous command — no UI for confirmation" };
}
```

---

## 12. Blocking & Gate Patterns

Gates are the simplest valuable extension pattern. Three categories:

### Command gates (confirm before action)

```typescript
pi.on("tool_call", async (event, ctx) => {
  if (event.toolName !== "bash") return undefined;

  const command = event.input.command as string;
  const dangerous = [/\brm\s+(-rf?|--recursive)/i, /\bsudo\b/i];

  if (dangerous.some(p => p.test(command))) {
    if (!ctx.hasUI) return { block: true, reason: "Dangerous (no UI)" };
    const ok = await ctx.ui.select(`Allow?\n  ${command}`, ["Yes", "No"]);
    if (ok !== "Yes") return { block: true, reason: "Blocked by user" };
  }
});
```

### Path gates (protect specific files)

```typescript
const PROTECTED = [".env", ".git/", "node_modules/", "credentials.json"];

pi.on("tool_call", async (event, ctx) => {
  if (event.toolName !== "write" && event.toolName !== "edit") return undefined;
  const path = event.input.path as string;
  if (PROTECTED.some(p => path.includes(p))) {
    ctx.ui.notify?.(`Blocked: ${path}`, "warning");
    return { block: true, reason: `Protected path: ${path}` };
  }
});
```

### Session gates (confirm before session changes)

```typescript
pi.on("session_before_switch", async (event, ctx) => {
  if (event.reason === "new") {
    const ok = await ctx.ui.confirm("New Session", "Clear all messages?");
    if (!ok) return { cancel: true };
  }
});
```

### Composing gates

Keep each gate in its own extension for modularity. They compose automatically — if any gate blocks, the tool is blocked:

```
~/.pi/agent/extensions/
├── permission-gate.ts      # Blocks dangerous commands
├── protected-paths.ts      # Blocks writes to sensitive files
└── confirm-destructive.ts  # Confirms session changes
```

---

## 13. Session Replacement — Footgun Avoidance

Session replacement happens during `/new`, `/resume`, `/fork`, `/clone`, and `ctx.reload()`. The lifecycle is:

```
session_shutdown (old) → rebind extensions → session_start (new)
```

### The #1 footgun

After `await ctx.reload()` or `await ctx.newSession()`, your old closure variables are **stale**. The old `pi`, old `ctx.sessionManager`, old in-memory state are all invalidated:

```typescript
// ❌ UNSAFE — old pi and sessionManager are stale after replacement
const oldSM = ctx.sessionManager;
await ctx.newSession({ withSession: async (_ctx) => {
  oldSM.getSessionFile();  // STALE — will throw or return wrong data
}});

// ✅ SAFE — use only the fresh ctx inside withSession
await ctx.newSession({
  withSession: async (ctx) => {
    await ctx.sendUserMessage("Continue from replacement session");
  },
});
```

### Treat reload as terminal

```typescript
pi.registerCommand("reload-runtime", {
  handler: async (_args, ctx) => {
    await ctx.reload();
    return;  // Nothing after this is safe
  },
});
```

### Tools can't reload directly

Tools receive `ExtensionContext`, not `ExtensionCommandContext`. Bridge via a command:

```typescript
// Tool queues the command as a follow-up
pi.registerTool({
  name: "reload_runtime",
  label: "Reload Runtime",
  description: "Reload extensions and skills",
  parameters: Type.Object({}),
  async execute() {
    pi.sendUserMessage("/reload-runtime", { deliverAs: "followUp" });
    return {
      content: [{ type: "text", text: "Queued /reload-runtime as follow-up" }],
    };
  },
});
```

---

## 14. Composing Extensions

### Inter-extension communication via `pi.events`

```typescript
// Extension A — emits
pi.events.emit("my:notification", { message: "Build complete", from: "ci" });

// Extension B — listens
pi.events.on("my:notification", (data) => {
  ctx.ui.notify(`From ${data.from}: ${data.message}`, "info");
});
```

This is a simple in-process event bus. No serialization, no cross-process — perfect for loosely-coupled extensions within the same pi session.

### Convention: namespace your events

```typescript
// ✅ Namespaced — won't collide
pi.events.emit("herdr:blocked", { active: true, label: "Rate limited" });
pi.events.emit("my-ext:status", { phase: "compiling" });

// ❌ Generic — collision risk
pi.events.emit("blocked", data);
pi.events.emit("status", data);
```

### Convention: one concern per extension file

```
~/.pi/agent/extensions/
├── tps.ts                    # Tokens-per-second metrics
├── prompt-url-widget.ts      # PR/issue context widget
├── permission-gate.ts        # Dangerous command gates
└── statusline.ts             # Custom status line (symlinked)
```

Small, focused extensions compose better than large monolithic ones.

---

## 15. Distributing Extensions

### Via npm or git as pi packages

See the official [packages.md](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/packages.md) for full details.

```jsonc
// settings.json
{
  "packages": [
    "npm:@my-org/pi-extension@1.0.0",
    "git:github.com/my-org/pi-extension@v1"
  ]
}
```

### Distribution checklist

- [ ] `package.json` with `"pi"` field pointing to entry files
- [ ] Runtime deps in `dependencies` (not `devDependencies`)
- [ ] Types imported from `@earendil-works/pi-coding-agent` (not `@types/...` duplicates)
- [ ] No reliance on `tsconfig.json` paths — use relative imports
- [ ] README with setup instructions and example usage
- [ ] Test with `pi -e ./src/index.ts` before packaging

---

## 16. Testing Strategy

Pi extensions don't have a formal test framework, but you can:

### 1. Prototype with `-e`

```bash
pi -e ./my-extension.ts
```

Fastest feedback loop. Type, reload, test. Not suitable for CI.

### 2. Test tool schemas independently

```typescript
import { Value } from "@earendil-works/typebox";
import { myParams } from "./my-extension";

// Compile-time schema validation
const valid = Value.Check(myParams, { action: "list" });
```

### 3. Test state reconstruction

Write a test that feeds mock entries into your reconstruction logic:

```typescript
// Pseudo-test
const mockEntries = [
  { type: "message", message: { role: "toolResult", toolName: "todo", details: { todos: [{ id: 1, text: "Buy milk", done: false }], nextId: 2 } } },
];

// Verify reconstruction picks up the correct state
```

### 4. Use `pi --mode json` for integration testing

Run pi in JSON mode and parse the event stream to verify tool calls, blocks, and messages.

### 5. Typecheck against the installed SDK declarations

Pi loads extensions via **jiti** (transpile-only — no typecheck), so type errors *never surface at runtime*. Close that gap by running `tsc` against the exact `.d.ts` pi loads. Set `baseUrl` to pi's `node_modules` and `moduleResolution: "bundler"`:

```jsonc
{
  "compilerOptions": {
    "strict": true, "noEmit": true, "skipLibCheck": true,
    "moduleResolution": "bundler",
    "baseUrl": "<pi>/node_modules",
    "lib": ["ESNext", "DOM"], "types": ["node"]
  },
  "include": ["my-extension.ts"]
}
```

Find pi's `node_modules` under the pnpm store (e.g. `…/@earendil-works/pi-coding-agent/<ver>/<hash>/node_modules`). Treat **zero strict errors** as the bar — it catches misuse the runtime never will: wrong argument shapes, a missing `details` on a tool return (see [§4](#4-tool-registration--dos-and-donts)), a typo'd `ctx.ui.custom` factory, an import that doesn't exist.

### 6. Exercise logic headlessly via jiti + redirected config

You don't need a live TUI to test command / file-merge / reconstruction logic. Load the real module through jiti with a mocked `pi`/`ctx`, and redirect the agent dir so writes land in a temp sandbox:

```typescript
process.env.PI_CODING_AGENT_DIR = mkdtempSync(join(tmpdir(), "ext-"));   // getAgentDir() honors this
const jiti = createJiti(import.meta.url);
const mod = await jiti.import(/* copy of your .ts placed where @earendil-works/* resolve */);
const cmds = {}, events = {};
await mod.default({
  registerCommand: (n, d) => { cmds[n] = d; },
  on: (e, f) => { events[e] = f; },
  registerTool() {}, registerShortcut() {},
});
await events.session_start({}, mockCtx);                   // prime state from disk
await cmds["my-ext"].handler("set foo global", mockCtx);     // drive a command
assert(JSON.parse(readFileSync(cfgPath)).foo === "…");      // assert on real files
```

`mockCtx` only needs what your handler touches — typically `cwd`, `isProjectTrusted()`, `ui.{notify,setStatus,theme}`, `sessionManager.getEntries()`. This is how to cover two-tier merge, write-through, and reconstruction paths that static checks can't reach. (The copy-in-`node_modules` trick is because bare `@earendil-works/*` imports don't resolve from an arbitrary directory; the copy is byte-identical and removed after load.)

---

## 17. Security Considerations

### Extensions run with full system permissions

```typescript
// This is valid extension code — it can do anything
import { execSync } from "child_process";
execSync("rm -rf /");  // Extensions are not sandboxed
```

**Only install extensions from sources you trust.**

### Sanitize user input in commands

```typescript
// ❌ Command injection risk
const filename = params.filename;
await pi.exec("cat", [filename]);  // filename could be "; rm -rf /"

// ✅ Validate before passing to shell
if (!/^[a-zA-Z0-9._-]+$/.test(filename)) {
  throw new Error(`Invalid filename: ${filename}`);
}
```

### Don't log secrets

```typescript
// ❌ Leaks API keys to log
console.log(`API key: ${apiKey}`);

// ✅ Redact
console.log(`API key: ${apiKey.slice(0, 4)}...`);
```

### Check trust before reading project config

```typescript
pi.on("session_start", async (_event, ctx) => {
  if (!ctx.isProjectTrusted()) {
    return;  // Don't read .pi/extensions config from untrusted projects
  }
  // ... read project-specific config
});
```

---

## 18. Anti-Patterns

| Anti-pattern | Problem | Fix |
|---|---|---|
| State in module variables only | Breaks on `/fork`, `/tree` | Store in `details` or `appendEntry`, reconstruct from session |
| No output truncation | Context overflow, compaction failure | Use `truncateHead`/`truncateTail` with 50KB/2000 line limits |
| `Type.Union` for enums | Breaks Google's API | Use `StringEnum` from `@earendil-works/pi-ai` |
| Blocking with `{ block: false }` | Doesn't pass through — still blocks! | Return `undefined` to pass through |
| Using `ctx.newSession()` in event handler | Deadlock | Bridge via `pi.sendUserMessage("/command")` |
| Stale closure after `reload()` | Crashes or wrong state | Treat reload as terminal; capture only plain data |
| No `hasUI` check before dialog | Hangs in print/json mode | Guard with `if (!ctx.hasUI)` and pick safe default |
| Giant monolithic extension | Hard to maintain, test, compose | Split into focused single-concern extensions |
| `promptGuidelines` without tool name | LLM can't tell which tool "this" means | Write `Use my_tool when...` not `Use this tool when...` |
| External file state | Breaks branching, not portable | Use session entries |
| No `signal` handling | Ignores user cancellation | Pass `signal` to all async operations |

---

## 19. Gotchas — Real-World Pitfalls

Pitfalls discovered the hard way by extension authors in the wild. Each is a true story from production extensions or issue reports.

### 19.1 Stale Context Proxy After Session Replacement

**Symptom:** Your `session_compact` or `session_tree` handler throws `"stale after session replacement"` even though the extension was working fine.

**Cause:** Pi-core invalidates the extension runner during session replacement/reload. Event handlers that were already scheduled continue to fire, but their `ctx` is now a dead proxy. The `rpiv-todo` extension documents this exact pattern:

```typescript
// From rpiv-todo (juicesharp/rpiv-mono)
function isStaleCtxError(e: unknown): boolean {
  return /stale after session replacement/.test(String(e));
}

pi.on("session_compact", async (_event, ctx) => {
  try {
    replaceState(replayFromBranch(ctx));
  } catch (e) {
    if (!isStaleCtxError(e)) throw e;  // real bugs propagate
  }
});
```

**Fix:** Guard lifecycle event handlers that access `ctx` against the stale-proxy error. If the ctx is stale, the session is being discarded anyway — the replacement session's `session_start` will replay state.

**Applies to:** `session_compact`, `session_tree`, any handler that fires during session teardown.

---



### 19.3 `session_compact` Races Session Disposal

**Symptom:** Intermittent crashes during auto-compaction. Your state reconstruction handler accesses `ctx.sessionManager.getBranch()` and gets corrupted data or throws.

**Cause:** Auto-compaction can race session disposal. Pi-core may invalidate the extension runner while still emitting `session_compact`. The session being compacted is being discarded — the replacement gets a fresh `session_start`.

**Fix:** Same stale-ctx guard as §19.1. The `rpiv-todo` extension handles this specifically:

```typescript
pi.on("session_compact", async (_event, ctx) => {
  try {
    replaceState(replayFromBranch(ctx));
  } catch (e) {
    if (!isStaleCtxError(e)) throw e;
  }
  // Always reset display state — even if ctx was stale,
  // the overlay will rebind on the next session_start
  todoOverlay?.resetCompletedDisplayState();
  todoOverlay?.update();
});
```

---

### 19.4 `tool_execution_end` Fires Before `message_end`

**Symptom:** Your state reconstruction in `tool_execution_end` sees stale branch data — the new tool result isn't in the session yet.

**Cause:** `tool_execution_end` fires after the tool completes but before the final `toolResult` message is committed to the session. `ctx.sessionManager.getBranch()` won't include the just-completed tool result yet.

**Fix:** `rpiv-todo` documents this explicitly:

```typescript
// Reads getTodos() at render time; do NOT call replayFromBranch here
// (branch is stale — message_end runs after tool_execution_end).
pi.on("tool_execution_end", async (event) => {
  if (event.toolName !== TOOL_NAME || event.isError) return;
  todoOverlay?.update();  // reads from store, not session
});
```

**Pattern:** Read from your in-memory store (committed via `commitState()` in `execute()`), not from the session branch, in `tool_execution_end`. Only replay from the session branch in `session_start`, `session_compact`, and `session_tree`.

---

### 19.5 `devDependencies` Are Not Available at Runtime

**Symptom:** Your extension works locally with `pi -e` but fails when installed via `pi install` from npm.

**Cause:** `pi install` uses `npm install --omit=dev` for npm packages. Anything in `devDependencies` is not installed.

**Fix:** All runtime imports must be in `dependencies`:

```json
{
  "dependencies": {
    "zod": "^3.0.0"
    // NOT devDependencies — needed at runtime
  }
}
```

Git packages use plain `install` (no `--omit=dev`), so `devDependencies` are available there — but don't rely on this difference. Put runtime deps in `dependencies`.

---

### 19.6 Soft Optional Peer Dependencies

**Symptom:** Your extension crashes on load because an optional peer dependency isn't installed.

**Cause:** You import from a package that isn't in your dependencies. When it's missing, the import throws and pi may report the extension as broken.

**Fix:** Use dynamic `import()` with a try/catch so the extension degrades gracefully. The `rpiv-todo` and `rpiv-ask-user-question` extensions do this for their i18n SDK:

```typescript
// Dynamic import keeps @juicesharp/rpiv-i18n a soft optional peer:
// when installed, strings localize; when absent, English fallback kicks in.
try {
  const sdk = (await import("@juicesharp/rpiv-i18n/loader")) as I18nLoader;
  sdk.registerLocalesFromDir(I18N_NAMESPACE, import.meta.url);
} catch {
  // SDK absent — extension still loads with English-only UI.
}
```

**Pattern:** Use this for any optional integration (i18n, telemetry, analytics). The extension should always work standalone.

---

### 19.7 Naming Collision with Built-in Tools

**Symptom:** Registering a tool named `read`, `bash`, or `edit` works but logs a warning and may confuse users.

**Cause:** Pi's built-in tools can be overridden by name, but the interactive mode shows a warning. More subtly, `promptSnippet` and `promptGuidelines` are NOT inherited from the built-in tool — you must define them yourself.

**Fix:** If you override a built-in tool, you probably want to:
1. Set a different `label` to distinguish it in the TUI
2. Re-define `promptSnippet` and `promptGuidelines`
3. Omit `renderCall`/`renderResult` to inherit the built-in renderer (syntax highlighting etc.)
4. Match the exact return `details` shape — the UI depends on it

---

### 19.8 `context` Event Receives a Deep Copy — But It's Still Expensive

**Symptom:** Your `context` handler runs on every LLM call and slows down turns.

**Cause:** `event.messages` is a deep copy, which is safe to modify but still allocates on every call. If you're filtering messages, consider whether `before_agent_start` (runs once per prompt, not per turn) would be a better fit.

**Fix:** Use `context` only when you need to modify messages per-LLM-call. Use `before_agent_start` for per-prompt injections. Avoid allocating in hot paths.

---

### 19.9 Overlay Components Must Handle All Key Events

**Symptom:** Your `ctx.ui.custom()` overlay works but some keystrokes are silently swallowed or cause unexpected behavior.

**Cause:** Overlay components must return `true` from `handleInput` for every key they consume. Unhandled keys fall through to the parent component. If your component doesn't handle Escape, the user can't dismiss it.

**Fix:** Always handle at minimum: `escape` (dismiss), `return`/`enter` (confirm), and navigation keys. Return `true` to consume, `false` (or don't return) to pass through.

---

### 19.10 `pi.exec` Is Not the Same as Node's `child_process.exec`

**Symptom:** Code that uses `.stdout`, `.stderr`, `.code` on `pi.exec` result fails.

**Cause:** `pi.exec` returns `{ stdout, stderr, code, killed }` which is similar to `child_process.execSync` but is async and integrates with pi's signal handling. Don't confuse it with Node's callback-based `exec`.

```typescript
// ✅ Correct — pi.exec returns a promise
const result = await pi.exec("git", ["status"], { signal });
if (result.code !== 0) { /* ... */ }
console.log(result.stdout);
```

---

### 19.11 Compaction `firstKeptEntryId` Empty String Sentinel

**Symptom:** Your custom compaction handler returns `firstKeptEntryId: ""` and pi behaves unexpectedly.

**Cause:** In pi-vcc, an empty string `firstKeptEntryId` is a sentinel meaning "compact everything, keep no tail." Pi-core's `buildSessionContext` won't match it against any entry, so zero pre-compaction messages are kept. This is intentional but undocumented. On the next compaction, pi-vcc detects the orphan (no valid `firstKeptEntryId` in branch) and triggers recovery.

**Fix:** If implementing custom compaction, use a real entry ID for `firstKeptEntryId` unless you intentionally want to compact everything. If you do use the empty-string sentinel, handle the orphan recovery case in your next compaction.

---

### 19.12 Settings File Outside `.pi/` — Use `~/.pi/agent/`

**Symptom:** Your extension's settings file at `~/.config/my-ext/config.json` isn't in the standard location.

**Cause:** Pi extensions conventionally store their config inside `~/.pi/agent/` (the agent directory). Use `getAgentDir()` from `@earendil-works/pi-coding-agent` to resolve it.

```typescript
import { getAgentDir } from "@earendil-works/pi-coding-agent";
import { join } from "node:path";

const configPath = join(getAgentDir(), "my-ext-config.json");
```

pi-vcc uses this pattern (`~/.pi/agent/pi-vcc-config.json`). pi-permission-system also uses `getAgentDir()` for its log directory.

### 19.13 Round-Trip Config Writes Must Preserve Reserved Keys

**Symptom:** Editing one setting silently wipes another from the config file — e.g. saving a preset deletes your `_vision` block, or a settings hub edit removes internal/comment keys.

**Cause:** Your reader intentionally skips certain keys (reserved `_`-prefixed blocks, internal metadata) but your writer serializes the *filtered* object back over the file, clobbering everything the reader stripped.

```typescript
// ❌ readRaw() strips _-prefixed keys → save() wipes them
function readRaw(path) { /* skips keys starting with _ */ }
function save(cfg) { writeFileSync(path, JSON.stringify(cfg)); }   // _vision is gone!
```

**Fix:** Writers must read the *full* raw file, mutate, and preserve any key the reader skips. For single-field edits, merge-write just that field:

```typescript
function save(cfg: PresetsConfig) {
  let full = existsSync(path) ? JSON.parse(readFileSync(path, "utf-8")) : {};
  for (const k of Object.keys(full)) if (!k.startsWith("_")) delete full[k]; // drop stale presets
  for (const [k, v] of Object.entries(cfg)) full[k] = v;                     // add current
  writeFileSync(path, JSON.stringify(full, null, 2));                         // _-keys preserved
}
```

Every code path that rewrites the config (`/edit`, `/rm`, a settings hub) must round-trip the reserved keys. A regression test that sets a reserved key, runs a rewrite, and asserts the key survives is worth its weight (see [§16](#16-testing-strategy)).

### 19.14 Two-Tier Config — Global Canonical + Project Override

**Pattern:** Store config at two levels — global (`getAgentDir()`, the canonical default) and project (`<cwd>/.pi/`, an override) — and merge at the **field** level so a project override pins only what it sets, inheriting the rest from global. This mirrors pi's own `/config` editor (Tab switches scope).

```typescript
import { getAgentDir, CONFIG_DIR_NAME } from "@earendil-works/pi-coding-agent";
const globalPath = join(getAgentDir(), "my-ext.json");
const projectPath = (cwd) => join(cwd, CONFIG_DIR_NAME, "my-ext.json");

// field-level merge: project wins per key
function load(cwd: string, trusted: boolean) {
  return { ...defaults, ...read(globalPath), ...(trusted ? read(projectPath(cwd)) : {}) };
}
// single-field write to one tier, preserving every other key
function writeField(cwd: string, scope: "global" | "project", key: string, value: unknown) {
  const path = scope === "project" ? projectPath(cwd) : globalPath;
  const raw = existsSync(path) ? JSON.parse(readFileSync(path, "utf-8")) : {};
  if (value === undefined) delete raw[key]; else raw[key] = value;
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, JSON.stringify(raw, null, 2));
}
```

**Three rules:**

1. **Gate project reads/writes on `ctx.isProjectTrusted()`** — never read `.pi/` config from an untrusted project (see [§17](#17-security-considerations)).
2. **Merge per-field, not per-object** — a project override `{ vlm: "x" }` must not copy global's `mode`/`maxBrief` into the project file (that pins them and silently breaks future global edits).
3. **Show the source** — surface where each effective value came from (`· global` / `· project` / `· default`) so users know which tier to edit.

**Testability:** `getAgentDir()` honors `PI_CODING_AGENT_DIR`, so point it at a temp dir and drive real read/write logic against sandbox files (see [§16](#16-testing-strategy)).

---

## 20. Community Patterns — What Production Extensions Do

Patterns observed across the most popular extensions on [pi.dev/packages](https://pi.dev/packages) (3800+ packages as of June 2026).

### 20.1 Monorepo with Shared State Infrastructure (juicesharp/rpiv-mono)

The `rpiv-*` family (todo, ask-user-question, advisor, btw, web-tools) lives in a single monorepo. Shared patterns:

- **Pure reducer state management** — `state-reducer.ts` is a pure function `(state, action, ctx) → { state, Effect[] }`. Effects are a closed union type (no string-keyed escape hatch). Adding a new action variant is a compile-time error until a handler is registered.

- **External store cell** — A single `store.ts` module owns the mutable state variable. `replaceState()` for session replay, `commitState()` for tool mutations, `getState()` for read-only access. This is the single mutation seam.

- **Defensive replay** — `replayFromBranch()` walks `ctx.sessionManager.getBranch()` and takes the last matching `toolResult.details`. It uses a runtime type guard (`isTaskDetails`) to skip corrupt or older session entries silently.

- **Soft optional peers** — The i18n SDK is loaded via `await import()` + try/catch. When absent, an inline English fallback keeps the extension online.

- **Exhaustive dispatch tables** — Handler maps typed as `{ [K in ActionKind]: Handler<K> }` so TypeScript enforces that every union variant has a handler.

```typescript
// Pure reducer pattern (rpiv-ask-user-question)
const HANDLERS: { [K in QuestionnaireAction["kind"]]: Handler<K> } = {
  nav: navHandler,
  tab_switch: tabSwitchHandler,
  confirm: confirmHandler,
  cancel: cancelHandler,
  // Adding a new variant? Compiler enforces a handler here.
};

export function reduce(state, action, ctx): ApplyResult {
  const handler = HANDLERS[action.kind];
  return handler(state, action as never, ctx);
}
```

### 20.2 Deep Permission Systems (gotgenes/pi-permission-system)

The most sophisticated gate extension in the ecosystem. Key patterns:

- **Object-oriented decomposition** — Unlike most extensions that use procedural event handlers, pi-permission-system decomposes into ~25 classes: `PermissionManager`, `PermissionSession`, `PermissionResolver`, `ConfigStore`, `GateRunner`, `ToolCallGatePipeline`, `SkillInputGatePipeline`, etc.

- **CacheKeyGate utility** — A reusable class that encapsulates the `prev !== next` comparison pattern. Runs an effect only when a cached key changes, with `reset()` for session lifecycle:

```typescript
class CacheKeyGate {
  private previousKey: string | null = null;
  runIfChanged<T>(nextKey: string, effect: () => T): T | undefined {
    if (this.previousKey === nextKey) return undefined;
    const result = effect();
    this.previousKey = nextKey;
    return result;
  }
  reset(): void { this.previousKey = null; }
}
```

- **Subagent integration via events** — Cross-extension communication via `pi.events` with namespaced channels (`subagents:started`, `subagents:completed`, `subagents:failed`). A `Symbol.for()`-based service registry publishes typed interfaces across package boundaries.

- **Config normalization** — Raw JSON config is normalized through a `normalizePermissionSystemConfig()` function with explicit validation, not direct property access.

### 20.3 Algorithmic Compaction (sting8k/pi-vcc)

A compaction extension that replaces LLM-based summarization with structured extraction. Notable patterns:

- **Settings scaffolding** — On load, `scaffoldSettings()` creates the config file with defaults if missing, or merges in any new default keys if the file exists but is missing some. Never clobbers user edits:

```typescript
export function scaffoldSettings(): void {
  if (!existsSync(path)) {
    writeFileSync(path, JSON.stringify(DEFAULT_SETTINGS, null, 2));
    return;
  }
  const parsed = readJson(path);
  if (!parsed) return; // don't clobber invalid JSON
  let changed = false;
  const next = { ...parsed };
  for (const [key, value] of Object.entries(DEFAULT_SETTINGS)) {
    if (!(key in next)) { next[key] = value; changed = true; }
  }
   if (changed) writeFileSync(path, JSON.stringify(next, null, 2));
}
```

- **Peer dependencies, not regular deps** — Uses `peerDependencies` for `@earendil-works/pi-coding-agent` and `typebox`, avoiding version conflicts. This is the correct pattern for pi packages.

- **Orphan recovery** — Handles the case where `firstKeptEntryId` from a previous compaction no longer exists in the branch (due to truncation or corruption). Falls back to summarizing everything after the last compaction.

### 20.4 Sub-Agent Systems (gotgenes/pi-subagents, nicobailon/pi-subagents)

Multiple sub-agent implementations exist. Shared patterns:

- **`createAgentSession()` from SDK** — Sub-agents are spawned using pi's own session creation API, not `pi.exec()`. This gives them full tool access, proper session management, and model routing.

- **`pi.appendEntry()` for persistence** — Completed sub-agent results are persisted via `pi.appendEntry("subagents:record", { ... })` for cross-session history.

- **`pi.events` for lifecycle** — Parent ↔ child communication uses namespaced events (`subagents:started`, `subagents:completed`, `subagents:failed`, `subagents:compacted`).

- **Concurrency queue** — A `ConcurrencyQueue` class manages max concurrent agents, draining when slots open.

### 20.5 Common Package Structure

Across the ecosystem, pi packages follow a consistent structure:

```
my-extension/
├── package.json          # name, peerDependencies, "pi": { "extensions": [...] }
├── src/
│   ├── index.ts          # Entry point — exports default function
│   ├── config.ts         # Settings normalization & scaffolding
│   └── ...                # Feature modules
├── test/
│   └── *.test.ts         # Unit tests (vitest common)
└── vitest.config.ts
```

Key `package.json` patterns:

```json
{
  "main": "src/index.ts",
  "peerDependencies": {
    "@earendil-works/pi-coding-agent": ">=0.74.0 <1.0.0",
    "typebox": ">=1.1.24 <2.0.0"
  },
  "pi": {
    "extensions": ["./src/index.ts"]
  }
}
```

---

## 21. Checklist

Before shipping an extension, verify:

### Core
- [ ] Extension loads without errors (`pi -e ./ext.ts`)
- [ ] `/reload` works (not using `-e` for production)
- [ ] All tool parameters use `StringEnum` (not `Type.Union`/`Type.Literal`)
- [ ] All tools have `description`, `parameters`, and return `{ content, details }`
- [ ] Output truncation applied (50KB / 2000 lines)
- [ ] Errors thrown (not returned as content)
- [ ] Imports from `@earendil-works/pi-coding-agent`

### State
- [ ] State stored in tool `details` or `appendEntry`
- [ ] State reconstructed from session in `session_start`
- [ ] State reconstructed in `session_tree` and `session_compact` too
- [ ] Stale-ctx error guarded in compaction/tree handlers (§19.1)
- [ ] No reliance on module-level variables for critical state

### Mode
- [ ] `hasUI` checked before dialogs
- [ ] `mode` checked before TUI-only features
- [ ] Safe default chosen for non-interactive mode (usually "block")

### Composability
- [ ] One concern per extension file
- [ ] Events namespaced (`my-ext:event-name`)
- [ ] No hardcoded assumptions about other extensions
- [ ] Optional peers loaded via `await import()` + try/catch (§19.6)

### Config & UI
- [ ] Config in `~/.pi/agent/` via `getAgentDir()`; project override under `<cwd>/.pi/` gated on `isProjectTrusted()`
- [ ] Field-level merge for two-tier config (project pins only what it sets) (§19.14)
- [ ] Round-trip writes preserve reserved/internal keys (§19.13)
- [ ] Settings UI reuses pi components (`SettingsList`/`SelectList`) + theme helpers (§10)
- [ ] Logic covered by a jiti + redirected-config test (§16.6)

### Distribution
- [ ] `package.json` with `pi.extensions` entry
- [ ] `peerDependencies` for `@earendil-works/pi-coding-agent` and `typebox`
- [ ] Runtime deps in `dependencies` (not `devDependencies`)
- [ ] README with usage examples
- [ ] Settings scaffolding for first-run (create defaults if missing)

---

## 22. Further Reading

### Official docs

| Doc | Content |
|-----|---------|
| [extensions.md](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/extensions.md) | Full API reference — events, tools, UI, state |
| [tui.md](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/tui.md) | TUI component patterns — `CustomEditor`, overlays, widgets |
| [packages.md](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/packages.md) | Distributing extensions via npm/git |
| [custom-provider.md](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/custom-provider.md) | Registering custom model providers |
| [sessions.md](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/sessions.md) | Session format, branching, tree navigation |
| [compaction.md](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/compaction.md) | Custom compaction hooks |
| [keybindings.md](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/keybindings.md) | Keybinding ids for custom shortcuts |
| [rpc.md](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/rpc.md) | Extension behavior in RPC mode |

### Example extensions (in repo)

| Example | Category | Key pattern |
|---------|----------|-------------|
| `hello.ts` | Minimal tool | `registerTool` basics |
| `permission-gate.ts` | Gate | `tool_call` → block |
| `protected-paths.ts` | Gate | Path protection |
| `todo.ts` | Stateful tool | Session reconstruction from `details` |
| `plan-mode/` | Mode switcher | Commands + flags + `setActiveTools` + messages |
| `truncated-tool.ts` | Output hygiene | `truncateHead`, temp files |
| `tool-override.ts` | Override | Replace built-in tool, keep renderer |
| `custom-compaction.ts` | Compaction | Custom summary with different model |
| `git-checkpoint.ts` | Git integration | Stash per turn, restore on fork |
| `question.ts` | Interactive tool | `ui.custom()` for full control |
| `preset.ts` | Configuration | JSON config, model/tools/thinking presets |
| `dynamic-tools.ts` | Dynamic | Register tools at runtime |
| `input-transform.ts` | Input | Transform/handle before agent |
| `event-bus.ts` | Composition | `pi.events` for inter-extension comms |
| `ssh.ts` | Remote | Tool operations for remote execution |
| `custom-provider-gitlab-duo/` | Provider | OAuth provider registration |
| `overlay-test.ts` | Advanced UI | Overlay mode with positioning |
| `subagent/` | Agent | Spawn sub-agent processes |

### Community

- [GitHub: pi-coding-agent-extension topic](https://github.com/topics/pi-coding-agent-extension)
- [pi.dev/packages](https://pi.dev/packages) — 3800+ extensions, skills, themes, and prompts
- [pi-dev Discord](https://discord.gg/pi-dev) — ask questions, share extensions

### Notable open-source extensions

| Package | Downloads/mo | Pattern |
|--------|------------|--------|
| [context-mode](https://github.com/mksglu/context-mode) | 131K | MCP plugin, FTS5 knowledge base |
| [pi-subagents](https://github.com/nicobailon/pi-subagents) | 103K | Sub-agent delegation, TUI clarification |
| [pi-mcp-adapter](https://github.com/nicobailon/pi-mcp-adapter) | 99K | MCP protocol bridge |
| [rpiv-ask-user-question](https://github.com/juicesharp/rpiv-mono) | 52K | Structured questionnaire, pure reducer state |
| [rpiv-todo](https://github.com/juicesharp/rpiv-mono) | 46K | Stateful task list, session replay, overlay |
| [pi-permission-system](https://github.com/gotgenes/pi-packages) | 17K | Deep permission gates, OOP decomposition |
| [pi-vcc](https://github.com/sting8k/pi-vcc) | 9K | Algorithmic compaction, no LLM calls |
| [pi-subagents](https://github.com/gotgenes/pi-packages) | 17K | Full sub-agent system, Symbol service registry |

---

*This guide is a living document. Patterns evolve as the extension API matures. Last updated: July 2026.*
