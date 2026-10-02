/**
 * image-slim — keep images inline in the chat, keep them OUT of the model payload.
 *
 * WHY (the 338KB timeout):
 *   pi stores images two ways, and only ONE of them is filtered before a normal
 *   request goes to the provider:
 *
 *   1. `read` on an image → xmodel's read handover moves the pixels into a
 *      session DISPLAY entry (`appendCustomMessageEntry`, display:true) and the
 *      model-visible tool result keeps only a routing note. Inline in the chat,
 *      ~free for the model.
 *
 *   2. An image ATTACHED to the prompt (drag&drop, `@file`, paste) → a plain
 *      `role:"user"` message carrying the full base64 payload. xmodel never sees
 *      these (they are not tool results), so they ride along with every request.
 *
 *   pi's `images.blockImages` (settings.json) replaces image blocks in user and
 *   toolResult messages with a text placeholder at LLM-conversion time — so on
 *   the NORMAL path the pixels are dropped. That is the first line of defence
 *   and this extension does not change it.
 *
 *   BUT compaction does NOT go through that filter. `compaction.js` calls the raw
 *   `convertToLlm(messages)` (no blockImages wrapper), so every stored base64
 *   image is serialised into the summarization prompt in full. A handful of
 *   attachments turn a small summary request into a 338KB payload, which the
 *   provider cannot answer inside the timeout:
 *
 *     Error: tu timeout error: upstream timeout: no response within 90s
 *            (model=glm-5.3-744b-experimental, payload=338KB) — likely wedged
 *
 *   This extension closes that hole at `session_before_compact`, which fires
 *   BEFORE the summarizer runs and receives the exact `preparation` that will be
 *   sent. We swap image blocks in `messagesToSummarize` / `turnPrefixMessages`
 *   for a compact text placeholder — on COPIES, so no live session state and no
 *   rendered chat entry is modified.
 *
 * WHAT THIS DOES NOT TOUCH:
 *   - The chat / TUI. Display entries are rendered from the session file, not
 *     from `messagesToSummarize`. Every image stays visible inline, forever.
 *   - pi's `images.blockImages` setting. Normal requests keep using it.
 *   - xmodel's read handover and its `_vision` pipeline.
 *
 * In short: images stay on screen; they stop costing tokens at the only place
 * they still leaked through.
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const VERSION = "1.0.0";

interface ImageishBlock {
	type?: unknown;
	mimeType?: unknown;
	text?: unknown;
	data?: unknown;
}

/** Approximate serialized size of one content block (base64 counts in full). */
function blockSize(block: unknown): number {
	if (!block || typeof block !== "object") return 0;
	const b = block as ImageishBlock;
	if (b.type === "text") return String(b.text ?? "").length;
	if (b.type === "image") return String(b.data ?? "").length;
	return 0;
}

/** Approximate serialized size of a message list — this is what the provider sees. */
function messagesSize(messages: unknown): number {
	if (!Array.isArray(messages)) return 0;
	let total = 0;
	for (const msg of messages) {
		if (!msg || typeof msg !== "object") continue;
		const content = (msg as { content?: unknown }).content;
		if (typeof content === "string") total += content.length;
		else if (Array.isArray(content)) for (const b of content) total += blockSize(b);
	}
	return total;
}

/**
 * Return a copy of `messages` with every image block replaced by a short text
 * placeholder. Purely functional: the input messages are never mutated, so the
 * live session keeps the real image content.
 */
function stripImages(messages: any[]): { messages: any[]; stripped: number } {
	let stripped = 0;
	const next = messages.map((msg) => {
		if (!msg || typeof msg !== "object") return msg;
		const content = (msg as { content?: unknown }).content;
		if (!Array.isArray(content)) return msg;
		const imageCount = content.filter((b) => b && typeof b === "object" && (b as ImageishBlock).type === "image").length;
		if (imageCount === 0) return msg;

		let imgIdx = 0;
		const rewritten = content.map((block) => {
			if (block && typeof block === "object" && (block as ImageishBlock).type === "image") {
				stripped++;
				const mime = String((block as ImageishBlock).mimeType ?? "");
				const label = mime.startsWith("image/") ? mime.slice(6) : "image";
				const where = imageCount > 1 ? ` (${imgIdx + 1}/${imageCount})` : "";
				imgIdx++;
				return {
					type: "text",
					text:
						`[image omitted from summary: ${label}${where} — still visible in the chat, ` +
						`this summary just does not repeat it]`,
				};
			}
			return block;
		});
		return { ...msg, content: rewritten };
	});
	return { messages: next, stripped };
}

export default function imageSlimExtension(pi: ExtensionAPI) {
	/**
	 * `session_before_compact` fires in `AgentSession.compact()` BEFORE
	 * `_runDefaultCompaction(preparation, …)` runs, and receives the very same
	 * `preparation` object that is then handed to the summarizer — so replacing
	 * `preparation.messagesToSummarize` here directly shrinks the payload that
	 * `compaction.js` serialises with the unfiltered `convertToLlm()`.
	 */
	pi.on("session_before_compact", async (event, ctx: ExtensionContext) => {
		const preparation = event.preparation as unknown as {
			messagesToSummarize?: any[];
			turnPrefixMessages?: any[];
		};
		if (!preparation) return;

		const before = messagesSize(preparation.messagesToSummarize) + messagesSize(preparation.turnPrefixMessages);
		if (before === 0) return;

		let stripped = 0;
		if (Array.isArray(preparation.messagesToSummarize)) {
			const r = stripImages(preparation.messagesToSummarize);
			preparation.messagesToSummarize = r.messages;
			stripped += r.stripped;
		}
		if (Array.isArray(preparation.turnPrefixMessages)) {
			const r = stripImages(preparation.turnPrefixMessages);
			preparation.turnPrefixMessages = r.messages;
			stripped += r.stripped;
		}
		if (stripped === 0) return;

		const after = messagesSize(preparation.messagesToSummarize) + messagesSize(preparation.turnPrefixMessages);
		const savedKB = Math.max(0, before - after) / 1024;
		ctx.ui.notify(
			`image-slim v${VERSION}: ${stripped} image${stripped > 1 ? "s" : ""} stripped from the summary payload ` +
				`(saved ~${savedKB.toFixed(0)}KB) — images stay visible inline in the chat.`,
			"info",
		);
	});
}