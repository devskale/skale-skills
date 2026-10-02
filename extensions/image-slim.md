# image-slim

Keep images inline in the chat — and keep them OUT of the model payload where pi 1.0
still leaks them.

## The hole it closes

pi's `images.blockImages` (settings.json) filters image blocks on **normal** requests.
But **compaction does not go through that filter**: `compaction.js` calls the raw
`convertToLlm()`, so every stored base64 image is serialised into the summarization
prompt in full. A handful of attachments turn a small summary request into a 338KB+
payload — which the provider cannot answer inside the timeout.

`image-slim` hooks `session_before_compact` (fires before the summarizer, receives the
exact `preparation`) and replaces image blocks in `messagesToSummarize` /
`turnPrefixMessages` with a short text placeholder — **on copies**. Observed: 636KB →
0.4KB per compaction.

## What it does not touch

- The chat/TUI — display entries render from the session file, not from
  `messagesToSummarize`. Images stay visible inline, forever.
- pi's `images.blockImages` — normal requests keep using it (first line of defence).
- xmodel's read handover and `_vision` pipeline.

## Notes

- Load order irrelevant; stateless; no commands. Ships in the skale-skills package.
- Session-file bloat is a separate axis: xmodel ≥0.5.10 stores display-entry pixels
  once (in `details.images`); older sessions were scrubbed manually (backup:
  `/tmp/pi-session-backup`).
- Tests: `bash tests/image-slim/test.sh` — strip logic runs the real extension against
  a mocked `session_before_compact` with a 300KB image and asserts placeholders +
  non-mutation.
