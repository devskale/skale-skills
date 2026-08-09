/**
 * session-state — shared session-lifecycle primitives for pi extensions.
 *
 * Several extensions (xmodel, heartbeat) persist per-session state via
 * `pi.appendEntry()` (a `custom` entry) and reconstruct it on session
 * lifecycle events (`session_start` / `session_tree` / `session_compact`).
 * The two mechanics they share are:
 *
 *   1. Read the LAST `custom` entry of a given type from the session — this
 *      is the "reconstruct" primitive. Each extension decides what to DO with
 *      the reconstructed data (apply to its own state), so the wiring stays
 *      per-extension.
 *   2. The stale-ctx guard — when pi replaces a session (tree navigation /
 *      compaction / branching), handlers that were bound to the old session
 *      throw "stale after session replacement". Extensions swallow that
 *      specific error and rethrow anything else.
 *
 * Deliberately NOT here: the `pi.on("session_*")` handler wiring itself. The
 * extensions differ enough (heartbeat adds `session_shutdown`, xmodel reloads
 * presets in `session_start`) that a shared wiring helper would have an
 * interface as wide as the code it replaces — shallow. Share the mechanics,
 * keep the wiring local.
 */
import type { ExtensionContext } from "@earendil-works/pi-coding-agent";

/** True when an error is pi's "session was replaced" signal (tree/compact/branch). */
export function isStaleCtxError(e: unknown): boolean {
	return /stale after session replacement/i.test(String(e));
}

/**
 * Read the last `custom` session entry of `entryType` and return its `data`.
 *
 * Tolerant of a missing/optional `sessionManager` (some contexts guard it),
 * and returns `undefined` when there is no matching entry. This is the
 * shared "reconstruct" primitive — callers apply the returned data to their
 * own state.
 */
export function reconstructLastCustomEntry(
	ctx: ExtensionContext,
	entryType: string,
): any {
	try {
		const entries = (ctx as any)?.sessionManager?.getEntries?.() ?? [];
		let last: any = null;
		for (const entry of entries) {
			if (entry?.type === "custom" && entry?.customType === entryType) last = entry.data;
		}
		return last;
	} catch {
		return undefined;
	}
}
