# Pi Architecture Deep Dive

> **Reference version:** pi `0.78.1` (monorepo `0.0.3`), commit `89a92207` dated 2026-06-05
> Cross-referenced against the pi source at `~/code/agents/pis/pi/`
> Based on the "PI Architecture EXPLAINED" video transcript (2026-06-05), verified and corrected against the actual codebase.

---

## 1. Package Structure

Pi is a TypeScript monorepo with four packages:

```
packages/
├── agent/            # @earendil-works/pi-agent-core — the agent loop, session tree, compaction
├── ai/               # @earendil-works/pi-ai — LLM providers, streaming, model registry
├── coding-agent/     # @earendil-works/pi-coding-agent — CLI, tools, extensions, TUI glue
└── tui/              # @earendil-works/pi-tui — custom terminal UI framework (components, editor)
```

**Key distinction:** The `agent` package is the agentic core (loop + session + compaction). The `coding-agent` package is the full coding agent built on top (CLI entry point, built-in tools, extension system, interactive mode).

---

## 2. The Agent Loop

**Source:** `packages/agent/src/agent-loop.ts`

The agent loop is written from scratch — no external agentic framework (no LangChain, no OpenAI Agents SDK). It is a pure TypeScript implementation.

### 2.1 Flow per user message

```
User sends message
       │
       ▼
  ┌─────────────────────────┐
  │ 1. Initialize context   │  systemPrompt + tools + message history + new user message
  └────────────┬────────────┘
               │
               ▼
  ┌─────────────────────────┐
  │ 2. Transform context    │  optional transformContext() hook (compaction, pruning, injection)
  └────────────┬────────────┘
               │
               ▼
  ┌─────────────────────────┐
  │ 3. Convert to LLM msgs  │  convertToLlm() maps AgentMessage[] → provider Message[]
  └────────────┬────────────┘
               │
               ▼
  ┌─────────────────────────┐
  │ 4. Stream LLM response  │  streamSimple(model, context, options) → EventStream
  └────────────┬────────────┘
               │
         ┌─────┴─────┐
         │ Tool calls?│
         └─────┬─────┘
          Yes  │  No
          ┌────┘  └──→ Return response to user
          ▼
  ┌─────────────────────────┐
  │ 5. Execute tool calls   │  parallel or sequential (configurable per-tool)
  │    beforeToolCall hook  │
  │    tool.execute()       │
  │    afterToolCall hook   │
  └────────────┬────────────┘
               │
               ▼
         Loop back to step 4 (tool results become context for next LLM call)
```

### 2.2 Key design decisions

- **AgentMessage abstraction:** Internally, the loop works with `AgentMessage` (a union of LLM messages + custom app messages). Conversion to provider-specific `Message[]` happens only at the LLM call boundary via `convertToLlm()`.
- **Tool execution modes:** Parallel by default. Individual tools can opt into sequential execution via `executionMode: "sequential"`. Sequential tools execute one-at-a-time with all other tool calls in the batch.
- **Steering messages:** `getSteeringMessages()` injects user input mid-loop (user types while agent is working). Injected before next LLM call, not mid-tool-execution.
- **Follow-up messages:** `getFollowUpMessages()` queues messages that arrive after the agent would otherwise stop. Re-enters the loop.
- **Termination:** A tool batch can signal `terminate: true` to stop the loop after the current turn. Also `shouldStopAfterTurn()` hook.
- **Events:** Every step emits typed events (`agent_start`, `turn_start`, `message_start`, `message_update`, `message_end`, `tool_execution_start`, `tool_execution_end`, `turn_end`, `agent_end`). Extensions subscribe to these.

### 2.3 AgentContext

The loop receives an `AgentContext` snapshot:

```typescript
interface AgentContext {
  systemPrompt: string;
  messages: AgentMessage[];
  tools?: AgentTool<any>[];
}
```

This is immutable per-invocation — the loop builds new arrays rather than mutating the input.

---

## 3. Tools

**Source:** `packages/coding-agent/src/core/tools/`

### 3.1 Built-in tools (7, not 4)

The video says Pi has "only four tools" (read, bash, edit, write) plus two disabled ones (grep, find). The code tells a slightly different story:

| Tool | File | Default? |
|------|------|----------|
| `read` | `read.ts` | ✅ Always active |
| `bash` | `bash.ts` | ✅ Always active |
| `edit` | `edit.ts` | ✅ Always active |
| `write` | `write.ts` | ✅ Always active |
| `grep` | `grep.ts` | ❌ Available but not default |
| `find` | `find.ts` | ❌ Available but not default |
| `ls` | `ls.ts` | ❌ Available but not default |

The tool set is defined in `packages/coding-agent/src/core/tools/index.ts`:

- **`createCodingToolDefinitions()`** → `[read, bash, edit, write]` — the default coding set
- **`createReadOnlyToolDefinitions()`** → `[read, grep, find, ls]` — the read-only set (no bash, no write, no edit)
- **`createAllToolDefinitions()`** → all 7 tools

Users can select specific tools via `--tools` CLI flag. The video correctly describes the read-only mode use case (safe for RPC/programmatic access).

### 3.2 Tool interface

```typescript
interface AgentTool<TParameters> extends Tool<TParameters> {
  label: string;
  prepareArguments?: (args: unknown) => TParameters;
  execute: (toolCallId, params, signal?, onUpdate?) => Promise<AgentToolResult>;
  executionMode?: "sequential" | "parallel";
}
```

Extensions can register additional tools via `pi.registerTool()` with the same interface.

---

## 4. Sessions & Tree Structure

**Source:** `packages/agent/src/harness/session/`

### 4.1 Storage format: JSONL

Sessions are stored as **JSONL** files (one JSON object per line). This is a deliberate design choice:

- **Append-only:** New messages just append a line — no need to parse/rewrite the entire file
- **Efficient:** No array wrapper, no trailing commas, no full-file serialization

Location: `~/.pi/agent/sessions/<path-encoded-cwd>/<session-id>.jsonl`

### 4.2 Tree structure (not a list!)

The video gets this exactly right. Each entry has:

```typescript
interface SessionTreeEntryBase {
  type: string;
  id: string;         // UUIDv7 (shortened to 8 chars)
  parentId: string | null;  // creates the tree
  timestamp: string;
}
```

Entry types (from `packages/agent/src/harness/types.ts`):

| Type | Purpose |
|------|---------|
| `message` | User/assistant/toolResult messages |
| `thinking_level_change` | Tracks thinking level changes |
| `model_change` | Tracks model switches |
| `active_tools_change` | Tracks tool enable/disable |
| `compaction` | Compaction summary (replaces old history) |
| `branch_summary` | Summary when navigating/forking |
| `custom` | Extension state persistence |
| `custom_message` | Extension messages visible to LLM |
| `label` | User bookmarks on entries |
| `leaf` | Points to current active node |

### 4.3 Forking and navigation

Because of the `parentId` tree structure:
- **Forking:** Writing a new message with the same `parentId` as an existing message creates a sibling — a forked conversation branch
- **Navigation:** The `leaf` entry points to the active branch tip. Changing the leaf navigates to a different part of the tree
- **Tree view** (`tree` command in the TUI): Renders the full tree with branches

### 4.4 Session context reconstruction

`buildSessionContext()` (in `session.ts`) walks from root to leaf, reconstructing:
- Message history (respecting compaction boundaries)
- Current thinking level (last `thinking_level_change` wins)
- Current model (last `model_change` or last assistant message wins)
- Active tools (last `active_tools_change` wins)

---

## 5. Compaction

**Source:** `packages/agent/src/harness/compaction/compaction.ts`

### 5.1 When compaction triggers

Compaction is checked at two points (as the video states):
1. **After agent turn ends** — the assistant finishes and tool results are in
2. **Before user prompt** — before sending the next message

The decision is based on token count vs. context window:

```typescript
function shouldCompact(contextTokens, contextWindow, settings): boolean {
  return contextTokens > contextWindow - settings.reserveTokens;
}
```

Defaults: `reserveTokens: 16384`, `keepRecentTokens: 20000`.

### 5.2 Token counting

The video says Pi relies on LLM response `usage` data rather than character estimation. The code confirms this with a fallback:

1. **Primary:** Use `usage.totalTokens` from the LLM response (or sum of `input + output + cacheRead + cacheWrite`)
2. **Fallback:** If no usage data exists (e.g., no assistant response yet), estimate by counting characters ÷ 4 per message

### 5.3 Compaction algorithm

1. Find the previous compaction boundary (or root)
2. Calculate current token count
3. Find a **cut point** — walk backwards from the end, accumulating tokens until `keepRecentTokens` is hit
4. Cut points are only at user messages or safe boundaries (not mid-turn)
5. Summarize everything before the cut point using the LLM
6. If the cut splits a turn, summarize the turn prefix separately
7. Store as a `compaction` entry with summary + `firstKeptEntryId`

### 5.4 Summarization prompts

The summarization prompt follows the exact format shown in the video:

```
## Goal
## Constraints & Preferences
## Progress
### Done / In Progress / Blocked
## Key Decisions
## Next Steps
## Critical Context
```

There's a separate `UPDATE_SUMMARIZATION_PROMPT` for iterative compaction (updating an existing summary with new messages).

### 5.5 File operation tracking

Compaction entries store `details: { readFiles, modifiedFiles }` — a running list of files read/modified in the compacted history. This is appended to the summary so the agent knows which files it has already touched.

---

## 6. System Prompt Construction

**Source:** `packages/coding-agent/src/core/system-prompt.ts` + `packages/coding-agent/src/core/skills.ts`

### 6.1 Structure

The system prompt is assembled in this order:

1. **Base identity:** `"You are an expert coding assistant operating inside pi, a coding agent harness..."`
2. **Available tools list:** One-line snippets for each active tool
3. **Guidelines:** Collapsible list including tool-specific rules + extension-added guidelines
4. **Pi documentation paths:** Links to README, docs, examples (for self-referencing)
5. **Appended system prompt:** From `append-load-system.md` or `--append-system-prompt` flag
6. **Project context:** `AGENTS.md`, `CLAUDE.md`, etc. from working directory and home
7. **Skills block:** XML-formatted `<available_skills>` with name, description, location
8. **Current date** and **working directory**

Override paths: `--system-prompt` (full replacement) or `system.md` in `.pi/` directory.

### 6.2 Skills in the system prompt

Skills use XML format per the [agentskills.io](https://agentskills.io) spec:

```xml
<available_skills>
  <skill>
    <name>fetch-url</name>
    <description>Fetch and extract readable text from web pages...</description>
    <location>/Users/.../.pi/agent/skills/fetch-url/SKILL.md</location>
  </skill>
</available_skills>
```

### 6.3 Skill invocation flow

The video describes this accurately:

1. Skills are listed in the system prompt with name + description + **location** (file path)
2. When the user types a skill invocation (e.g., the TUI intercepts this), the interactive layer injects a message referencing the skill
3. The system prompt instructs the LLM: "Use the read tool to load a skill's file when the task matches its description"
4. The LLM calls `read` on the skill's file path → gets full instructions → continues

This is **lazy loading** — skill content is not bloating the initial context. The LLM reads it on demand.

---

## 7. Extensions

**Source:** `packages/coding-agent/src/core/extensions/`

Extensions are TypeScript modules loaded at runtime. They can:

| Capability | API |
|-----------|-----|
| Register tools | `pi.registerTool(def)` |
| Subscribe to events | `pi.on("tool_call", handler)` |
| Register commands | `pi.registerCommand(name, opts)` |
| Add keyboard shortcuts | `pi.registerShortcut(key, opts)` |
| Add CLI flags | `pi.registerFlag(name, opts)` |
| Modify system prompt | Via `before_agent_start` event → `systemPrompt` override |
| Custom message rendering | `pi.registerMessageRenderer(type, renderer)` |
| Register providers | `pi.registerProvider(name, config)` |
| Send messages | `pi.sendMessage()`, `pi.sendUserMessage()` |
| Execute shell commands | `ctx.exec()` |
| Trigger compaction | `ctx.compact()` |
| Session control | `ctx.newSession()`, `ctx.fork()`, `ctx.navigateTree()` |

### 7.1 Extension events (full list)

Session events: `session_start`, `session_before_switch`, `session_before_fork`, `session_before_compact`, `session_compact`, `session_shutdown`, `session_before_tree`, `session_tree`

Agent events: `context`, `before_provider_request`, `after_provider_response`, `before_agent_start`, `agent_start`, `agent_end`, `turn_start`, `turn_end`, `message_start`, `message_update`, `message_end`

Tool events: `tool_execution_start`, `tool_execution_update`, `tool_execution_end`, `tool_call`, `tool_result`

Model events: `model_select`, `thinking_level_select`

Other: `user_bash`, `input`, `resources_discover`

### 7.2 Extension context

Extensions receive an `ExtensionContext` with:
- `ctx.ui` — TUI dialogs (select, confirm, input, notify, custom components)
- `ctx.cwd` — working directory
- `ctx.sessionManager` — read-only session access
- `ctx.model` — current model
- `ctx.abort()` — abort current operation
- `ctx.mode` — "tui" | "rpc" | "json" | "print"
- `ctx.getContextUsage()` — token count and window size
- `ctx.getSystemPrompt()` — current effective system prompt

---

## 8. TUI (Terminal User Interface)

**Source:** `packages/tui/`

### 8.1 Custom-built, no framework

The TUI is completely custom — no Ink, no Textual, no Blessed. It renders directly to the terminal via ANSI escape codes.

### 8.2 Component-based architecture

```
TUI (root)
├── HeaderComponent
├── MessageListComponent
│   ├── UserMessageComponent
│   ├── AssistantMessageComponent
│   └── ToolExecutionComponent
├── EditorComponent (input)
└── FooterComponent
```

Each component owns its rendering, input handling, and state. Components can be dynamically added/removed by extensions.

### 8.3 TUI features

- Component lifecycle: render → handle input → invalidate → re-render
- Flicker-free rendering (double buffering)
- Image display in terminal (via `terminal-image.ts`)
- Autocomplete system (`autocomplete.ts`) with fuzzy matching (`fuzzy.ts`)
- Custom editor with undo stack, kill ring, word navigation
- Theme support with hot-reload watching
- Overlay system for modals/selectors

---

## 9. CLI Entry Point & Modes

**Source:** `packages/coding-agent/src/main.ts`

### 9.1 Entry point flow

```
cli.ts  →  main.ts  →  parseArgs()
                    →  resolveProjectTrust()
                    →  createSessionManager()
                    →  createAgentSessionRuntime()
                    →  run in selected mode
```

### 9.2 Three modes

| Mode | When | Description |
|------|------|-------------|
| **Interactive** | Default (TTY stdin) | Full TUI with editor, messages, footer |
| **Print** | `--print` or piped stdin | Stream response to stdout, then exit |
| **JSON** | `--json` | Same as print but JSON output |
| **RPC** | `--rpc` | JSON-RPC server over stdin/stdout (for IDE/tool integration) |

### 9.3 Session management flags

- `--continue` / `-c` — resume most recent session
- `--resume` — interactive session picker
- `--session <id>` — open specific session
- `--fork <id>` — fork from a session/entry
- `--no-session` — in-memory only
- `--name <name>` — label a session

---

## 10. Model & Provider System

**Source:** `packages/ai/`

- **Provider-agnostic:** Works with any LLM via a streaming interface (`streamSimple`)
- **Model registry:** Extensions and built-in config register models with metadata (context window, cost, capabilities)
- **Auth:** API keys from environment variables, `~/.pi/auth.json`, OAuth, or `--api-key` flag
- **Model cycling:** `Ctrl+P` cycles through scoped models
- **Thinking levels:** `off | minimal | low | medium | high | xhigh` — model-specific mapping via `thinkingLevelMap`
- **Context window awareness:** Model's `contextWindow` drives compaction thresholds

---

## 11. Corrections to the Video

| Video claim | Actual code |
|-------------|-------------|
| "4 tools + 2 disabled (grep, find)" | 7 built-in tools: read, bash, edit, write + grep, find, **ls**. Ls was missed. |
| "System prompt is ~20 lines" | The base identity is short, but the full system prompt includes tool list, guidelines, documentation paths, project context, skills, date, and cwd — typically 40-80+ lines. |
| "Tools: --tools read, grep, find" for read-only | Correct, but the read-only set is `[read, grep, find, ls]` (includes ls too). |
| "client.ts calls main.ts" | The entry is `main.ts` which handles everything. `cli.ts` exists in `packages/ai/` as a separate concern. |
| "Compaction happens before user prompt" | Correct — checked after agent turn ends AND before next user prompt. |
| Skills "are not automatically replaced" | Correct — skills are lazy-loaded. The LLM sees the skill metadata in the system prompt and uses the `read` tool to load full content on demand. |
| "No library helping Pi build the agent loop" | Confirmed — `agent-loop.ts` is a from-scratch implementation with no agentic framework dependency. |

---

## 12. Key File Map

| Concern | File |
|---------|------|
| Agent loop | `packages/agent/src/agent-loop.ts` |
| Agent types | `packages/agent/src/types.ts` |
| Session tree types | `packages/agent/src/harness/types.ts` |
| Session context | `packages/agent/src/harness/session/session.ts` |
| JSONL storage | `packages/agent/src/harness/session/jsonl-storage.ts` |
| Compaction | `packages/agent/src/harness/compaction/compaction.ts` |
| System prompt (harness) | `packages/agent/src/harness/system-prompt.ts` |
| System prompt (coding-agent) | `packages/coding-agent/src/core/system-prompt.ts` |
| Skills loading | `packages/coding-agent/src/core/skills.ts` |
| Tool definitions | `packages/coding-agent/src/core/tools/index.ts` |
| Extension types | `packages/coding-agent/src/core/extensions/types.ts` |
| CLI main | `packages/coding-agent/src/main.ts` |
| Interactive mode | `packages/coding-agent/src/modes/interactive/interactive-mode.ts` |
| RPC mode | `packages/coding-agent/src/modes/rpc/` |
| TUI framework | `packages/tui/src/tui.ts` |
| TUI components | `packages/tui/src/components/` |
| AI providers | `packages/ai/src/providers/` |
| Model registry | `packages/ai/src/models.ts` |
