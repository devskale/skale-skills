/**
 * Heartbeat parsing/formatting — pure functions, zero imports.
 *
 * Kept dependency-free on purpose: tests/heartbeat/test.sh runs this file
 * directly via node's native type stripping, without the pi runtime.
 */

/** Parse a human duration into ms. Units: s, m, h, d (bare = seconds). null if invalid. */
export function parseDuration(str: string): number | null {
	const m = str.match(/^(\d+)\s*([smhd])?$/i);
	if (!m) return null;
	const num = parseInt(m[1], 10);
	if (!Number.isFinite(num) || num <= 0) return null;
	const unit = (m[2] ?? "s").toLowerCase();
	const mult =
		unit === "d" ? 86_400_000
		: unit === "h" ? 3_600_000
		: unit === "m" ? 60_000
		: 1_000;
	return num * mult;
}

/** Human-readable duration, e.g. 90_000 → "1m 30s", 90_061_000 → "1d 1h 1m 1s". */
export function humanDuration(ms: number): string {
	const s = Math.floor(ms / 1000);
	const d = Math.floor(s / 86400);
	const h = Math.floor((s % 86400) / 3600);
	const m = Math.floor((s % 3600) / 60);
	const sec = s % 60;
	const parts: string[] = [];
	if (d) parts.push(`${d}d`);
	if (h) parts.push(`${h}h`);
	if (m) parts.push(`${m}m`);
	if (sec || parts.length === 0) parts.push(`${sec}s`);
	return parts.join(" ");
}

/** Options for starting a heartbeat via the slash command. */
export interface ParsedCommand {
	action:
		| "start"
		| "status"
		| "stop"
		| "message"
		| "time"
		| "pause"
		| "resume"
		| "help";
	duration?: string;
	message?: string;
	maxCount?: number;
	once?: boolean;
	file?: string;
	lines?: number;
}

/** Raw-string parser for the /heartbeat slash command. */
export function parseCommand(raw: string): ParsedCommand {
	const first = raw.match(/^\s*(\S+)/)?.[1] ?? "";

	if (first === "help" || first === "?") return { action: "help" };
	if (first === "") return { action: "help" }; // bare /heartbeat -> help, not start

	if (first === "status") return { action: "status" };
	if (first === "off" || first === "stop") return { action: "stop" };
	if (first === "pause") return { action: "pause" };
	if (first === "resume") return { action: "resume" };

	if (first === "message") {
		const rest = raw.slice("message".length).trim();
		return rest
			? { action: "message", message: rest.replace(/^["']|["']$/g, "") }
			: { action: "message" };
	}

	if (first === "time") {
		const rest = raw.slice("time".length).trim();
		const dur = rest.match(/^(\S+)/)?.[1] ?? "";
		return dur ? { action: "time", duration: dur } : { action: "time" };
	}

	// start: optional duration, optional "message", optional -f, optional --limit, optional --once
	const opts: ParsedCommand = { action: "start" };
	const durTok = parseDuration(first);
	if (durTok) opts.duration = first;
	else {
		// duration can appear anywhere (e.g. "--once 10s"): take the first
		// token that parses as a duration, skipping flags and their values
		const tokens = raw.trim().split(/\s+/);
		for (let i = 0; i < tokens.length; i++) {
			const t = tokens[i];
			if (t.startsWith("-")) {
				if (t === "--limit" || t === "--lines" || t === "-f") i++; // skip flag value
				continue;
			}
			if (parseDuration(t)) {
				opts.duration = t;
				break;
			}
		}
	}

	const quoteMatch = raw.match(/["'](.+?)["']/);
	if (quoteMatch) opts.message = quoteMatch[1];

	const fileMatch = raw.match(/(?:^|\s)-f\s+(\S+)/);
	if (fileMatch) opts.file = fileMatch[1];
	const linesMatch = raw.match(/--lines\s+(\d+)/);
	if (linesMatch) opts.lines = parseInt(linesMatch[1], 10);

	const limitMatch = raw.match(/--limit\s+(\d+)/);
	if (limitMatch) opts.maxCount = parseInt(limitMatch[1], 10);

	const onceMatch = raw.match(/--once/);
	if (onceMatch) opts.once = true;

	return opts;
}
