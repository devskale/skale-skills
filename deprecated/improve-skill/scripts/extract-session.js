#!/usr/bin/env node

/**
 * Extract session transcript from Claude Code, Pi, Codex, or OpenCode session files.
 *
 * Usage:
 *   ./extract-session.js [session-path]
 *   ./extract-session.js --agent claude|pi|codex|opencode [--cwd /path/to/dir]
 *
 * If no arguments, auto-detects based on current working directory.
 */

const fs = require("fs");
const path = require("path");
const os = require("os");

// Parse arguments
const args = process.argv.slice(2);
let sessionPath = null;
let agent = null;
let cwd = process.cwd();

for (let i = 0; i < args.length; i++) {
  if (args[i] === "--agent" && args[i + 1]) {
    agent = args[++i];
  } else if (args[i] === "--cwd" && args[i + 1]) {
    cwd = args[++i];
  } else if (!args[i].startsWith("-")) {
    sessionPath = args[i];
  }
}

/**
 * Encode CWD for session path lookup
 */
function encodeCwd(cwd, style) {
  if (style === "pi") {
    // Pi uses: --<cwd-without-leading-slash-with-slashes-as-dashes>--
    // e.g., /Users/mitsuhiko/Development/myproject -> --Users-mitsuhiko-Development-myproject--
    const safePath = `--${cwd.replace(/^[/\\]/, "").replace(/[/\\:]/g, "-")}--`;
    return safePath;
  }
  // Claude Code: just replace / with -
  return cwd.replace(/\//g, "-");
}

/**
 * Find the most recent session file in a directory
 */
function findMostRecentSession(dir) {
  if (!fs.existsSync(dir)) return null;

  const files = fs
    .readdirSync(dir)
    .filter((f) => f.endsWith(".jsonl"))
    .map((f) => ({
      name: f,
      path: path.join(dir, f),
      mtime: fs.statSync(path.join(dir, f)).mtime,
    }))
    .sort((a, b) => b.mtime - a.mtime);

  return files.length > 0 ? files[0].path : null;
}

/**
 * Find Codex session matching CWD
 */
function findCodexSession(targetCwd) {
  const baseDir = path.join(os.homedir(), ".codex", "sessions");
  if (!fs.existsSync(baseDir)) return null;

  // Find all session files, sorted by mtime
  const allSessions = [];

  function walkDir(dir) {
    if (!fs.existsSync(dir)) return;
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const fullPath = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        walkDir(fullPath);
      } else if (entry.name.endsWith(".jsonl")) {
        allSessions.push({
          path: fullPath,
          mtime: fs.statSync(fullPath).mtime,
        });
      }
    }
  }

  walkDir(baseDir);
  allSessions.sort((a, b) => b.mtime - a.mtime);

  // Find most recent matching CWD
  for (const session of allSessions.slice(0, 50)) {
    // Check last 50
    try {
      const firstLine = fs.readFileSync(session.path, "utf8").split("\n")[0];
      const data = JSON.parse(firstLine);
      if (data.payload?.cwd === targetCwd) {
        return session.path;
      }
    } catch (e) {
      // Skip invalid files
    }
  }

  return null;
}

/**
 * Find OpenCode session matching CWD
 */
function findOpenCodeSession(targetCwd) {
  const baseDir = path.join(os.homedir(), ".local", "share", "opencode");
  if (!fs.existsSync(baseDir)) return null;

  // Find all project directories
  const projects = fs
    .readdirSync(baseDir, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => path.join(baseDir, d.name));

  // Find all session info files, sorted by updated time
  const allSessions = [];

  for (const projectDir of projects) {
    const sessionInfoDir = path.join(
      projectDir,
      "global",
      "storage",
      "session",
      "info",
    );
    if (!fs.existsSync(sessionInfoDir)) continue;

    const files = fs
      .readdirSync(sessionInfoDir)
      .filter((f) => f.endsWith(".json"))
      .map((f) => ({
        project: path.basename(projectDir),
        sessionId: f.replace(".json", ""),
        path: path.join(sessionInfoDir, f),
        mtime: fs.statSync(path.join(sessionInfoDir, f)).mtime,
      }));

    allSessions.push(...files);
  }

  allSessions.sort((a, b) => b.mtime - a.mtime);

  // Find most recent session with messages matching CWD
  for (const session of allSessions.slice(0, 50)) {
    // Check last 50
    try {
      const messageDir = path.join(
        path.dirname(session.path).replace("info", "message"),
        session.sessionId,
      );
      if (!fs.existsSync(messageDir)) continue;

      const messageFiles = fs
        .readdirSync(messageDir)
        .filter((f) => f.endsWith(".json"))
        .sort((a, b) => {
          const statA = fs.statSync(path.join(messageDir, a));
          const statB = fs.statSync(path.join(messageDir, b));
          return statA.mtime - statB.mtime;
        });

      // Check first message for CWD match
      for (const msgFile of messageFiles.slice(0, 5)) {
        const msgPath = path.join(messageDir, msgFile);
        const msgContent = JSON.parse(fs.readFileSync(msgPath, "utf8"));
        if (
          msgContent.path?.root === targetCwd ||
          msgContent.path?.cwd === targetCwd
        ) {
          return {
            sessionId: session.sessionId,
            messageDir: messageDir,
          };
        }
      }
    } catch (e) {
      // Skip invalid sessions
    }
  }

  return null;
}

/**
 * Auto-detect session based on CWD
 */
function autoDetectSession(cwd) {
  // Try Claude Code first
  const claudePath = path.join(
    os.homedir(),
    ".claude",
    "projects",
    encodeCwd(cwd, "claude"),
  );
  let session = findMostRecentSession(claudePath);
  if (session) return { agent: "claude", path: session };

  // Try Pi
  const piPath = path.join(
    os.homedir(),
    ".pi",
    "agent",
    "sessions",
    encodeCwd(cwd, "pi"),
  );
  session = findMostRecentSession(piPath);
  if (session) return { agent: "pi", path: session };

  // Try Codex
  session = findCodexSession(cwd);
  if (session) return { agent: "codex", path: session };

  // Try OpenCode
  session = findOpenCodeSession(cwd);
  if (session)
    return {
      agent: "opencode",
      path: session.messageDir,
      sessionId: session.sessionId,
    };

  return null;
}

/**
 * Parse Claude Code session format
 */
function parseClaudeSession(content) {
  const messages = [];
  const lines = content.trim().split("\n");

  for (const line of lines) {
    try {
      const entry = JSON.parse(line);
      if (entry.message?.role && entry.message?.content) {
        const msg = entry.message;
        messages.push({
          role: msg.role,
          content: extractContent(msg.content),
          timestamp: entry.timestamp,
        });
      }
    } catch (e) {
      // Skip invalid lines
    }
  }

  return messages;
}

/**
 * Parse Pi session format
 */
function parsePiSession(content) {
  const messages = [];
  const lines = content.trim().split("\n");

  for (const line of lines) {
    try {
      const entry = JSON.parse(line);
      if (entry.type === "message" && entry.message?.role) {
        messages.push({
          role: entry.message.role,
          content: extractContent(entry.message.content),
          timestamp: entry.timestamp,
        });
      }
    } catch (e) {
      // Skip invalid lines
    }
  }

  return messages;
}

/**
 * Parse Codex session format
 */
function parseCodexSession(content) {
  const messages = [];
  const lines = content.trim().split("\n");

  for (const line of lines) {
    try {
      const entry = JSON.parse(line);
      if (entry.type === "response_item" && entry.payload?.role) {
        const payload = entry.payload;
        messages.push({
          role: payload.role,
          content: extractContent(payload.content),
          timestamp: entry.timestamp,
        });
      }
    } catch (e) {
      // Skip invalid lines
    }
  }

  return messages;
}

/**
 * Parse OpenCode session format (directory-based JSON message files)
 */
function parseOpenCodeSession(messageDir) {
  const messages = [];

  if (!fs.existsSync(messageDir)) return messages;

  const messageFiles = fs
    .readdirSync(messageDir)
    .filter((f) => f.endsWith(".json"))
    .sort((a, b) => {
      const statA = fs.statSync(path.join(messageDir, a));
      const statB = fs.statSync(path.join(messageDir, b));
      return statA.mtime - statB.mtime;
    });

  for (const msgFile of messageFiles) {
    try {
      const msgPath = path.join(messageDir, msgFile);
      const msgContent = JSON.parse(fs.readFileSync(msgPath, "utf8"));

      if (msgContent.role) {
        messages.push({
          role: msgContent.role,
          content: extractOpenCodeContent(msgContent),
          timestamp: msgContent.time?.created || Date.now(),
        });
      }
    } catch (e) {
      // Skip invalid files
    }
  }

  return messages;
}

/**
 * Extract text content from OpenCode message format
 */
function extractOpenCodeContent(msg) {
  const parts = [];

  // Add system context if present
  if (msg.system && msg.system.length > 0) {
    parts.push("[System Context]");
    for (const sys of msg.system) {
      if (typeof sys === "string") {
        parts.push(sys);
      }
    }
  }

  // Add mode if present
  if (msg.mode) {
    parts.push(`[Mode: ${msg.mode}]`);
  }

  // Add model info if present
  if (msg.modelID) {
    parts.push(`[Model: ${msg.modelID}]`);
  }

  // Add content if present
  if (msg.content) {
    parts.push(extractContent(msg.content));
  }

  return parts.join("\n");
}

/**
 * Extract text content from various content formats
 */
function extractContent(content) {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return JSON.stringify(content);

  const parts = [];
  for (const item of content) {
    if (typeof item === "string") {
      parts.push(item);
    } else if (item.type === "text") {
      parts.push(item.text);
    } else if (item.type === "input_text") {
      parts.push(item.text);
    } else if (item.type === "tool_use") {
      parts.push(
        `[Tool: ${item.name}]\n${JSON.stringify(item.input, null, 2)}`,
      );
    } else if (item.type === "tool_result") {
      const result =
        typeof item.content === "string"
          ? item.content
          : JSON.stringify(item.content);
      // Truncate long tool results
      const truncated =
        result.length > 500
          ? result.slice(0, 500) + "\n[... truncated ...]"
          : result;
      parts.push(`[Tool Result]\n${truncated}`);
    } else {
      parts.push(`[${item.type}]`);
    }
  }

  return parts.join("\n");
}

/**
 * Format messages as readable transcript
 */
function formatTranscript(messages, maxMessages = 100) {
  const recent = messages.slice(-maxMessages);
  const lines = [];

  for (const msg of recent) {
    const role = msg.role.toUpperCase();
    lines.push(`\n### ${role}:\n`);
    lines.push(msg.content);
  }

  if (messages.length > maxMessages) {
    lines.unshift(
      `\n[... ${messages.length - maxMessages} earlier messages omitted ...]\n`,
    );
  }

  return lines.join("\n");
}

// Main
async function main() {
  let result;

  if (sessionPath) {
    // Explicit path provided
    if (!fs.existsSync(sessionPath)) {
      console.error(`Session file not found: ${sessionPath}`);
      process.exit(1);
    }
    // Guess agent from path
    if (sessionPath.includes(".claude")) {
      result = { agent: "claude", path: sessionPath };
    } else if (sessionPath.includes(".pi")) {
      result = { agent: "pi", path: sessionPath };
    } else if (sessionPath.includes(".codex")) {
      result = { agent: "codex", path: sessionPath };
    } else if (
      sessionPath.includes("opencode") ||
      sessionPath.includes("message")
    ) {
      result = { agent: "opencode", path: sessionPath };
    } else {
      // Default to Claude format
      result = { agent: "claude", path: sessionPath };
    }
  } else if (agent) {
    // Agent specified, find session for that agent
    if (agent === "claude") {
      const dir = path.join(
        os.homedir(),
        ".claude",
        "projects",
        encodeCwd(cwd, "claude"),
      );
      const session = findMostRecentSession(dir);
      if (!session) {
        console.error(`No Claude Code session found for: ${cwd}`);
        process.exit(1);
      }
      result = { agent: "claude", path: session };
    } else if (agent === "pi") {
      const dir = path.join(
        os.homedir(),
        ".pi",
        "agent",
        "sessions",
        encodeCwd(cwd, "pi"),
      );
      const session = findMostRecentSession(dir);
      if (!session) {
        console.error(`No Pi session found for: ${cwd}`);
        process.exit(1);
      }
      result = { agent: "pi", path: session };
    } else if (agent === "codex") {
      const session = findCodexSession(cwd);
      if (!session) {
        console.error(`No Codex session found for: ${cwd}`);
        process.exit(1);
      }
      result = { agent: "codex", path: session };
    } else if (agent === "opencode") {
      const session = findOpenCodeSession(cwd);
      if (!session) {
        console.error(`No OpenCode session found for: ${cwd}`);
        process.exit(1);
      }
      result = {
        agent: "opencode",
        path: session.messageDir,
        sessionId: session.sessionId,
      };
    } else {
      console.error(`Unknown agent: ${agent}`);
      process.exit(1);
    }
  } else {
    // Auto-detect
    result = autoDetectSession(cwd);
    if (!result) {
      console.error(`No session found for: ${cwd}`);
      console.error(
        "Try specifying --agent claude|pi|codex or provide a session path directly.",
      );
      process.exit(1);
    }
  }

  // Read and parse session
  let messages;

  if (result.agent === "opencode") {
    // OpenCode uses directory-based message files
    messages = parseOpenCodeSession(result.path);
  } else {
    // Other agents use single file format
    const content = fs.readFileSync(result.path, "utf8");

    switch (result.agent) {
      case "claude":
        messages = parseClaudeSession(content);
        break;
      case "pi":
        messages = parsePiSession(content);
        break;
      case "codex":
        messages = parseCodexSession(content);
        break;
    }
  }

  // Output metadata and transcript
  console.log(`# Session Transcript`);
  console.log(`Agent: ${result.agent}`);
  console.log(`File: ${result.path}`);
  if (result.sessionId) {
    console.log(`Session ID: ${result.sessionId}`);
  }
  console.log(`Messages: ${messages.length}`);
  console.log("");
  console.log(formatTranscript(messages));
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
