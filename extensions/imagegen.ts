/**
 * Image Generation Extension
 *
 * Registers a `generate_image` tool the LLM can call. The generated image is
 * returned as an **image content block** (so vision-capable models can iterate
 * on it) PLUS a compact ASCII preview (so text-only models still get a visual
 * signal, and the user sees something under terminal multiplexers that strip
 * graphics protocols).
 *
 * Backends are reached through the uniinfer proxy using the `provider@modelid`
 * convention — the extension has no backend branching:
 *
 *   POST <proxy>/v1/images/generations
 *   Authorization: Bearer <credgoo key for the provider>
 *   { model: "pollinations@flux" | "tu@z-image-turbo", prompt, size, n }
 *
 * See extensions/imagegen.md for the full design doc.
 */

import { execSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import process from "node:process";

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";

// ── Config ───────────────────────────────────────────────────────────────────

const PROXY_BASE =
	process.env.UNIINFER_PROXY_URL?.replace(/\/+$/, "") || "https://amd1.mooo.com:8123/v1";

const DEFAULT_MODEL = process.env.IMAGEGEN_MODEL || "pollinations@flux";
const DEFAULT_SIZE = process.env.IMAGEGEN_SIZE || "1024x1024";
const ASCII_COLS = 64;
const ASCII_ROWS = 22;

// Known image providers — first segment of the `provider@modelid` string.
const PROVIDER_KEYS: Record<string, { env: string; credgoo: string; authFile?: string }> = {
	pollinations: { env: "POLLINATIONS_API_KEY", credgoo: "pollinations" },
	tu: { env: "TU_API_KEY", credgoo: "tu", authFile: "tu-aqueduct" },
};

// ── Helpers ──────────────────────────────────────────────────────────────────

function splitProviderModel(model: string): { provider: string; modelId: string } {
	const idx = model.indexOf("@");
	if (idx === -1) {
		// No provider prefix: assume the default provider with the given id.
		const defaultProvider = DEFAULT_MODEL.split("@")[0];
		return { provider: defaultProvider, modelId: model };
	}
	return { provider: model.slice(0, idx), modelId: model.slice(idx + 1) };
}

/** Resolve the API key for a provider: env → credgoo → ~/.pi/agent/auth.json. */
function resolveKey(provider: string): string | null {
	const cfg = PROVIDER_KEYS[provider];
	if (!cfg) return null;

	// 1. Environment variable
	const fromEnv = process.env[cfg.env];
	if (fromEnv && fromEnv.trim()) return fromEnv.trim();

	// 2. credgoo (suppress its stdout chatter)
	for (const cmd of ["credgoo", path.join(os.homedir(), ".local", "bin", "credgoo")]) {
		try {
			const out = execSync(`${cmd} ${cfg.credgoo}`, {
				encoding: "utf8",
				timeout: 8000,
				stdio: ["ignore", "pipe", "ignore"],
			}).trim();
			if (out && !/^error/i.test(out)) return out;
		} catch {
			/* try next */
		}
	}

	// 3. ~/.pi/agent/auth.json (e.g. tu-aqueduct)
	if (cfg.authFile) {
		try {
			const authPath = path.join(os.homedir(), ".pi", "agent", "auth.json");
			const auth = JSON.parse(fs.readFileSync(authPath, "utf8"));
			const entry = auth[cfg.authFile];
			if (entry?.key) return entry.key;
		} catch {
			/* not present */
		}
	}

	return null;
}

/**
 * Whether to render inline pixel images (Kitty/iTerm2) in the TUI.
 *
 * We do NOT trust pi's getCapabilities() here: under terminal multiplexers
 * (herdr, tmux, screen) the outer TERM_PROGRAM (ghostty/kitty) leaks through,
 * so pi returns a false-positive `images: "kitty"` and emits graphics escapes
 * that the multiplexer strips — nothing renders. Detect the mux ourselves.
 */
function canRenderInline(): boolean {
	if (process.env.TMUX || process.env.SCREEN) return false;
	if (process.env.HERDR_PANE_ID) return false; // herdr is a multiplexer too
	return true;
}

/** True if chafa is on PATH (used for ASCII fallback / model signal). */
function hasChafa(): boolean {
	try {
		execSync("command -v chafa", { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] });
		return true;
	} catch {
		return false;
	}
}

function guessMime(b64: string): string {
	if (b64.startsWith("/9j/")) return "image/jpeg";
	if (b64.startsWith("UklGR")) return "image/webp";
	if (b64.startsWith("R0lGOD")) return "image/gif";
	// PNG base64 starts with iVBOR
	return "image/png";
}

/** Render an image file to ANSI/ASCII text via chafa. `--format symbols` is mandatory. */
function chafaPreview(imgPath: string, mime: string, cols = ASCII_COLS, rows = ASCII_ROWS): string {
	try {
		// --format symbols forces text output. Without it, chafa auto-detects
		// the Kitty protocol (TERM_PROGRAM=ghostty leaks through herdr) and
		// emits graphics escapes that the multiplexer strips.
		const out = execSync(
			`chafa --format symbols --symbols block-half --color-space rgb --colors 240 ` +
				`--work 5 --size ${cols}x${rows} ${JSON.stringify(imgPath)}`,
			{ encoding: "utf8", stdio: ["ignore", "pipe", "ignore"], timeout: 15000 },
		).trim();
		return out || "(chafa produced no output)";
	} catch {
		// Fall back to plain ASCII if color symbols fail.
		try {
			return execSync(
				`chafa --format symbols --symbols ascii -c none --work 5 --size ${cols}x${rows} ${JSON.stringify(imgPath)}`,
				{ encoding: "utf8", stdio: ["ignore", "pipe", "ignore"], timeout: 15000 },
			).trim();
		} catch {
			return `(unable to render preview; see ${imgPath})`;
		}
	}
}

/** Choose output dir: uploads/ if it exists (web-served in πui), else generated/. */
function outputDir(cwd: string): { dir: string; webUrl: boolean } {
	const uploads = path.join(cwd, "uploads");
	try {
		if (fs.statSync(uploads).isDirectory()) return { dir: uploads, webUrl: true };
	} catch {
		/* not present */
	}
	const generated = path.join(cwd, "generated");
	return { dir: generated, webUrl: false };
}

// ── Types ────────────────────────────────────────────────────────────────────

interface ImageItem {
	b64: string;
	url?: string;
	mime: string;
	path: string;
	webUrl?: string;
}

// ── Extension ────────────────────────────────────────────────────────────────

export default function imagegenExtension(pi: ExtensionAPI) {
	const chafaAvailable = hasChafa();

	pi.registerTool({
		name: "generate_image",
		label: "Generate Image",
		description:
			"Generate an image from a text prompt. Returns the image inline (the model can see it and iterate) plus an ASCII preview. " +
			'Model is "provider@modelid", e.g. "pollinations@flux" (fast, default) or "tu@z-image-turbo" (high quality). ' +
			"Images are saved to ./generated/ (or ./uploads/ if present).",
		promptSnippet: "Generate an image from a text prompt; model sees the result and can iterate",
		promptGuidelines: [
			"Use generate_image when the user asks to create, draw, or generate an image/picture/illustration/logo. " +
				"After generating, review the returned image and, if needed, call generate_image again with a refined prompt.",
		],
		parameters: Type.Object({
			prompt: Type.String({ description: "Text-to-image prompt. Be vivid: subject, style, composition, lighting, mood." }),
			model: Type.Optional(
				Type.String({
					description: `provider@modelid (default: ${DEFAULT_MODEL}). Providers: pollinations (flux, kontext, nanobanana, seedream, ideogram-v4…), tu (z-image-turbo).`,
				}),
			),
			size: Type.Optional(Type.String({ description: `Image size WxH (default: ${DEFAULT_SIZE}).` })),
			n: Type.Optional(Type.Number({ description: "Number of images 1–4 (default 1)." })),
			seed: Type.Optional(Type.Number({ description: "Optional reproducibility seed." })),
		}),

		async execute(_toolCallId, params, _signal, onUpdate, ctx) {
			const prompt = (params.prompt || "").trim();
			if (!prompt) {
				return {
					content: [{ type: "text" as const, text: "Error: prompt is required." }],
					isError: true,
				};
			}

			const model = (params.model || DEFAULT_MODEL).trim();
			const { provider, modelId } = splitProviderModel(model);
			if (!PROVIDER_KEYS[provider]) {
				return {
					content: [
						{
							type: "text" as const,
							text: `Error: unknown provider "${provider}". Known: ${Object.keys(PROVIDER_KEYS).join(", ")}.`,
						},
					],
					isError: true,
				};
			}

			const size = (params.size || DEFAULT_SIZE).trim();
			const n = Math.max(1, Math.min(4, Math.floor(params.n ?? 1)));

			// Resolve credentials
			const key = resolveKey(provider);
			if (!key) {
				const cfg = PROVIDER_KEYS[provider];
				return {
					content: [
						{
							type: "text" as const,
							text:
								`Error: no API key for provider "${provider}". Set ${cfg.env} env var, ` +
								`run \`credgoo ${cfg.credgoo}\`${cfg.authFile ? `, or log in via pi (${cfg.authFile})` : ""}.`,
						},
					],
					isError: true,
				};
			}

			onUpdate?.({ content: [{ type: "text", text: `Generating with ${provider}@${modelId} (${size})…` }] });

			// Call the proxy
			let data: { data?: Array<{ b64_json?: string; url?: string }> };
			try {
				const resp = await fetch(`${PROXY_BASE}/images/generations`, {
					method: "POST",
					headers: {
						"Content-Type": "application/json",
						Authorization: `Bearer ${key}`,
					},
					body: JSON.stringify({ model: `${provider}@${modelId}`, prompt, size, n, ...(params.seed != null ? { seed: params.seed } : {}) }),
					signal: ctx.signal,
				});
				if (!resp.ok) {
					const detail = await resp.text().catch(() => "");
					return {
						content: [{ type: "text" as const, text: `Error: proxy returned ${resp.status} ${resp.statusText}${detail ? ` — ${detail}` : ""}` }],
						isError: true,
					};
				}
				data = (await resp.json()) as typeof data;
			} catch (e) {
				const msg = e instanceof Error ? e.message : String(e);
				return {
					content: [{ type: "text" as const, text: `Error: request failed — ${msg.split("Authorization")[0]}` }],
					isError: true,
				};
			}

			const items = data.data ?? [];
			if (!items.length) {
				return {
					content: [{ type: "text" as const, text: "Error: no images returned." }],
					isError: true,
				};
			}

			// Persist to disk
			const { dir, webUrl } = outputDir(ctx.cwd);
			fs.mkdirSync(dir, { recursive: true });
			const ts = Date.now();
			const saved: ImageItem[] = [];

			for (let i = 0; i < items.length; i++) {
				const it = items[i];
				let b64 = it.b64_json;
				if (!b64 && it.url) {
					try {
						const r = await fetch(it.url, { signal: ctx.signal });
						if (r.ok) b64 = Buffer.from(await r.arrayBuffer()).toString("base64");
					} catch {
						/* leave undefined */
					}
				}
				if (!b64) continue;
				const mime = guessMime(b64);
				const ext = mime === "image/jpeg" ? "jpg" : mime.split("/")[1] || "png";
				const file = items.length === 1 ? `generated-${ts}.${ext}` : `generated-${ts}-${i}.${ext}`;
				const abs = path.resolve(dir, file);
				fs.writeFileSync(abs, Buffer.from(b64, "base64"));
				saved.push({ b64, url: it.url, mime, path: abs, webUrl: webUrl ? `/uploads/${file}` : undefined });
			}

			if (!saved.length) {
				return {
					content: [{ type: "text" as const, text: "Error: generated images had no usable data." }],
					isError: true,
				};
			}

			// Build the result content blocks.
			// - A text summary (paths) — always
			// - An image block per image — lets vision models iterate
			// - An ASCII preview — helps text-only models AND users under multiplexers
			const content: Array<{ type: "text"; text: string } | { type: "image"; source: { type: "base64"; mediaType: string; data: string } }> = [];

			const locationLines = saved.map((s) => `  • ${s.webUrl ?? s.path}`).join("\n");
			content.push({
				type: "text",
				text: `Generated ${saved.length} image${saved.length > 1 ? "s" : ""} via ${provider}@${modelId} (${size}):\n${locationLines}`,
			});

			for (const s of saved) {
				content.push({
					type: "image",
					source: { type: "base64", mediaType: s.mime, data: s.b64 },
				});
			}

			// ASCII preview: only under multiplexers (inline pixels won't render)
			// OR always (as a model signal). We include it whenever chafa is
			// available — it's compact and gives text-only models a visual cue.
			if (chafaAvailable && !canRenderInline()) {
				const previews = saved.map((s) => chafaPreview(s.path, s.mime)).join("\n\n");
				content.push({
					type: "text",
					text: `\nASCII preview (terminal can't render inline images here):\n\`\`\`\n${previews}\n\`\`\``,
				});
			}

			return {
				content,
				details: {
					provider,
					model: modelId,
					size,
					paths: saved.map((s) => s.path),
					asciiPreview: chafaAvailable && !canRenderInline(),
				},
			};
		},

		renderResult(result, { isPartial }, theme) {
			if (isPartial) {
				return new Text(theme.fg("warning", "🖼 generating…"), 0, 0);
			}
			const details = (
				result as { details?: { provider?: string; model?: string; size?: string; paths?: string[] } }
			).details;
			if (result.isError || !details) {
				const txt = result.content?.[0] && "text" in result.content[0] ? result.content[0].text : "error";
				return new Text(theme.fg("error", `✗ ${txt}`), 0, 0);
			}
			const count = details.paths?.length ?? 0;
			const where = details.paths?.[0] ?? "";
			const label = `🖼 ${details.provider}@${details.model} • ${count} image${count > 1 ? "s" : ""} → ${where}`;
			return new Text(theme.fg("success", label), 0, 0);
			},
	});
}
