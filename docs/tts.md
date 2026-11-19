# TTS — Text-to-Speech über den sttts-Stack

> Voice-Stack auf der DGX (`hab`-Fleet): Qwen3-TTS als Standard, Voxtral als TU-Alternative.
> Alles OpenAI-kompatibel — kein SDK nötig, curl/python reicht.

## Quickstart (Mac)

```bash
~/code/sttts/bin/speak.sh "Hallo Welt"              # vorlesen (Default: sohee, Deutsch)
~/code/sttts/bin/speak.sh -v dylan "Hello"          # andere Stimme
~/code/sttts/bin/speak.sh -l English "Text"         # Sprache
~/code/sttts/bin/speak.sh -i "ruhig, sachlich" "Text"  # Stil/Emotion
~/code/sttts/bin/speak.sh -s "Langer Text …"        # LIVE-Streaming (Ton sofort)
~/code/sttts/bin/speak.sh -o out.wav "Text"         # nur speichern
echo "Text" | ~/code/sttts/bin/speak.sh             # stdin
```

Config via Env: `SPEAK_URL`, `SPEAK_MODEL`, `SPEAK_TOKEN`, `SPEAK_VOICE`, `SPEAK_LANG`, `SPEAK_STYLE`.
Token kommt automatisch aus `~/.pi/agent/auth.json` (unii-Key).

## Provider & Modelle

| Modell | Stimme | Streaming | Bemerkung |
|---|---|---|---|
| `hab@qwen3-tts-customvoice` | 10 Presets: sohee (Default), dylan, vivian, serena, ono_anna, aiden, eric, ryan, sohee, uncle_fu, default | ✅ **live** (first-byte ~0.1s) | DGX vLLM-Omni; Standard |
| `tu@voxtral-4b-tts` | de_female, de_male 🇦🇹 + 18 weitere (9 Sprachen) | ❌ gepuffert (~1.5-12s) | TU Aqueduct; Alternative mit anderem Klang |

Sprachen Qwen3-TTS: Auto, Chinese, English, Japanese, Korean, **German**, French, Russian, Portuguese, Spanish, Italian.
Voxtral: 9 Sprachen (u.a. DE/EN/FR/ES/IT/PT/NL/AR/HI).

## API direkt (ohne speak.sh)

```bash
# Gepuffert
curl -s -X POST https://uniinfer.skale.dev/v1/audio/speech \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $UNII_KEY" \
  -d '{"model":"hab@qwen3-tts-customvoice","input":"Hallo","voice":"sohee",
       "language":"German","response_format":"wav"}' -o out.wav

# Live-Streaming (stream:true + stream_format:"audio", rohe WAV-Bytes)
curl -sN -X POST https://uniinfer.skale.dev/v1/audio/speech \
  -H "Content-Type: application/json" -H "Authorization: Bearer $UNII_KEY" \
  -d '{"model":"hab@qwen3-tts-customvoice","input":"…","voice":"sohee",
       "stream":true,"stream_format":"audio"}' | ffplay -autoexit -loglevel error -
```

Request-Felder: `model`, `input`, `voice`, `language`, `instructions` (Stil/Emotion),
`response_format` (wav/mp3/flac/opus/pcm), `speed` (0.25-4.0), `stream`, `stream_format` (audio|sse).

## STT (Gegenrichtung: Sprache → Text)

```bash
curl -s -X POST https://uniinfer.skale.dev/v1/audio/transcriptions \
  -H "Authorization: Bearer $UNII_KEY" \
  -F "file=@audio.wav" -F "language=de"
# → {"text": "…", "language": "de", …}
```
Modell: `hab@nemotron-3.5-asr-streaming-0.6b` (DGX, sherpa-onnx) — auch als WS-Streaming.
Rig: `~/code/sttts/bin/say.sh` (Mikrofon → Text → Zwischenablage).

## Gotchas (live gelernt, 2026-11)

- **Streaming nur über `hab@`** — der unii-Proxy streamt TTS nativ (seit 2026-11-19, `stream:true`);
  `tu@` puffert komplett (Aqueduct kennt kein stream-Flag).
- **Sprache explizit setzen** — ohne `language` rät Qwen3-TTS (Auto) und liegt bei
  gemischtem Text daneben. Immer `language: "German"` / `"English"` mitschicken.
- **kokoro ist tot** (TU, abgeschaltet 2026-11-24) — TU-Default ist jetzt `voxtral-4b-tts` + `de_female`.
- **Stimmen ändern sich** — `GET https://uniinfer.skale.dev/v1/audio/voices` listet live.
- **Stil geht über `instructions`** — wirkt bei Qwen3-TTS gut ("ruhig, professionell",
  "laid-back Rapper" — siehe Spaß-Tests), Voxtral ignoriert es teilweise.
- **JSON-Bodies via `json.dumps` bauen**, nie String-Interpolation (Umlaute!).

## Wiring (wer routet wohin)

```
speak.sh / curl ──► uniinfer.skale.dev/v1/audio/speech
                     ├─ hab@…  → DGX model-proxy :3001 → vLLM-Omni :8091 (Qwen3-TTS, streamt)
                     └─ tu@…   → Aqueduct (TU Wien, gepuffert)
                  /v1/audio/transcriptions → DGX :3001 → sherpa Nemotron-ASR :8010
```
Details: `~/code/sttts/` (Stack, `bin/speak.sh`, `bin/say.sh`),
python-openutils `packages/uniinfer/` (Proxy-Implementierung, `proxy_routers/audio.py`).