/**
 * Shared chafa terminal-image renderer (used by imagegen + xmodel).
 *
 * Renders an image file as ANSI/ASCII text so the user can SEE it in terminals
 * without kitty/iTerm2 graphics support. `--format symbols` is mandatory —
 * without it chafa auto-detects the Kitty protocol (TERM_PROGRAM=ghostty leaks
 * through) and emits graphics escapes a plain terminal can't show.
 *
 * Contract: chafaPreview returns "" when rendering fails (or produces no
 * output) — callers decide their own fallback note (imagegen shows a path
 * hint, xmodel silently skips the ASCII variant).
 */

import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

/** Default preview geometry (cols × rows) — imagegen's tuned size. */
export const CHAFA_COLS = 64;
export const CHAFA_ROWS = 22;

/** Whether chafa can run (cached probe). Invoked directly — no shell, no
 *  `command -v` — so it works even without a login shell on PATH. */
let _chafaAvailable: Promise<boolean> | undefined;
export function chafaAvailable(): Promise<boolean> {
	if (!_chafaAvailable) {
		_chafaAvailable = execFileAsync("chafa", ["--version"], { encoding: "utf8", timeout: 3000 })
			.then(() => true)
			.catch(() => false);
	}
	return _chafaAvailable;
}

/** Render an image file to ANSI text via chafa. Color half-blocks first, plain
 *  ASCII second; "" when both fail. */
export async function chafaPreview(imgPath: string, cols = CHAFA_COLS, rows = CHAFA_ROWS): Promise<string> {
	const size = ["--size", `${cols}x${rows}`];
	try {
		const { stdout } = await execFileAsync(
			"chafa",
			["--format", "symbols", "--symbols", "block-half", "--color-space", "rgb", "--colors", "240", "--work", "5", ...size, imgPath],
			{ encoding: "utf8", timeout: 15000 },
		);
		return stdout.trim();
	} catch {
		try {
			const { stdout } = await execFileAsync(
				"chafa",
				["--format", "symbols", "--symbols", "ascii", "-c", "none", "--work", "5", ...size, imgPath],
				{ encoding: "utf8", timeout: 15000 },
			);
			return stdout.trim();
		} catch {
			return "";
		}
	}
}
