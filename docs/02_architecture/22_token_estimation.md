# 22 — Character-Based Usage Counting

This document explains how usage is measured across every ASR and translation engine in Omni Bridge — both on the Python server and the Flutter client side.

---

## Overview

Usage is tracked in **exact characters**, not estimated tokens. Every model reports the precise `len()` of its source and output text. This gives a 1:1 mapping to API billing (Google charges per source character) and is fully language-neutral — an English user and a Hindi user consuming the same number of characters incur the same API cost.

---

## How It Works

**Server side** — every model populates a `usage_stats` dict with exact char counts:

```python
"input_tokens":  len(source_text)    # exact source characters
"output_tokens": len(result_text)    # exact output characters
```

No estimation, no Unicode range checks, no BPE approximation. Just `len()`.

**Flutter side** — `logModelUsage()` in [`lib/core/data/datasources/usage_metrics_remote_datasource.dart:42`](../../lib/core/data/datasources/usage_metrics_remote_datasource.dart) accumulates these into Firebase RTDB under `users/{uid}/model_stats/{engine}`.

---

## Llama — System Prompt Overhead

Llama is the only engine that includes a system prompt in every API call. Since this is a real per-chunk cost, its character count is added to `input_tokens`.

**Source:** [`server/src/models/translation/llama_translation.py`](../../server/src/models/translation/llama_translation.py)

```python
system_prompt = self.build_system_prompt(target_lang)   # single source of truth

# ...

"input_tokens": len(text) + len(system_prompt),   # user text + prompt overhead
"output_tokens": len(result),
```

`build_system_prompt()` is a `@staticmethod` on `LlamaModel` — defined once, used in both the API call and the char count. If the prompt changes, the count updates automatically.

For a typical target language name (~5 chars), the system prompt is ~315 characters. Over 450 chunks in a 30-minute session that adds ~141,750 characters of overhead.

---

## Per-Engine Reference

### ASR Engines

All ASR engines output the recognized transcript only. `output_tokens` is always `0`.

| Engine | `input_tokens` | Source |
|---|---|---|
| **Riva ASR** ([`riva_asr.py:157`](../../server/src/models/asr/riva_asr.py)) | `len(transcript)` | Exact chars |
| **Whisper ASR** ([`whisper_asr.py:343`](../../server/src/models/asr/whisper_asr.py)) | `len(transcript)` | Exact chars |
| **Google ASR** ([`local_asr.py:88`](../../server/src/models/asr/local_asr.py)) | `len(transcript)` | Exact chars |

### Translation Engines

| Engine | `input_tokens` | `output_tokens` | System prompt? |
|---|---|---|---|
| **Riva NMT** ([`riva_nmt.py:93`](../../server/src/models/translation/riva_nmt.py)) | `len(text)` | `len(result)` | No |
| **Llama** ([`llama_translation.py:117`](../../server/src/models/translation/llama_translation.py)) | `len(text) + len(system_prompt)` | `len(result)` | Yes (~315 chars/chunk) |
| **Google Cloud** ([`google_api_translation.py:155`](../../server/src/models/translation/google_api_translation.py)) | `len(text)` | `len(result)` | No |
| **Google Free** ([`google_translation.py:60`](../../server/src/models/translation/google_translation.py)) | `len(text)` | `len(result)` | No |
| **MyMemory** ([`mymemory_translation.py:57`](../../server/src/models/translation/mymemory_translation.py)) | `len(text)` | `len(result)` | No |

---

## Character Budget for 30 Minutes of Usage

> **Assumptions:** ~450 VAD chunks over 30 min. English speech ~650 chars/min. Hindi speech ~400 chars/min.

### English → Hindi

| ASR | Translation | ASR chars | Translation chars | Total |
|---|---|---|---|---|
| Riva ASR | Riva NMT | ~19,500 | ~33,500 | **~53,000** |
| Riva ASR | Llama | ~19,500 | ~174,000 (incl. prompt) | **~193,500** |
| Whisper | Google Cloud | ~19,500 | ~33,500 | **~53,000** |
| Riva ASR | Google Free | ~19,500 | ~33,500 | **~53,000** |

### Hindi → English

| ASR | Translation | ASR chars | Translation chars | Total |
|---|---|---|---|---|
| Riva ASR | Riva NMT | ~12,000 | ~27,000 | **~39,000** |
| Riva ASR | Llama | ~12,000 | ~157,500 (incl. prompt) | **~169,500** |
| Whisper | Google Free | ~12,000 | ~27,000 | **~39,000** |

> ASR characters count toward `monthly_tokens` total but **not** against `engine_limits`. Only translation engines (`riva-nmt`, `llama`, `google_api`) have per-engine monthly caps.

> **Engine key note**: `engine_limits` keys in Firestore use **settings keys** (`google_api`, `riva-nmt`, `llama`, `whisper-asr`). RTDB `model_stats/` uses **RTDB stats keys** (`google-cloud-v3-grpc`, `riva-grpc-mt`, `llama-translate`, `whisper-asr`). The Flutter client resolves both via `EngineRegistry` — see [`lib/core/constants/engine_registry.dart`](../../lib/core/constants/engine_registry.dart).

---

## Quota Limits (Character Units)

| Tier | Daily | Monthly | Per engine (month) | ~30 min sessions/day |
|---|---|---|---|---|
| `free` | 40,000 | 750,000 | — | ~45 min (Google Free) |
| `trial` | 75,000 | 75,000 (one-time) | — | ~1.4 hrs in 24h |
| `pro` | 75,000 | 3,750,000 | 250,000 | ~1.4 hrs/day · ~37 hrs/month |
| `enterprise` | 250,000 | 9,000,000 | 750,000 | ~4.7 hrs/day · ~86 hrs/month |

---

## Cost Reference (Google API rate: $20 / 1M chars = ₹1,660 / 1M chars)

| Tier | Max engine chars/month | Max cost per engine | Max cost (3 engines) | Revenue |
|---|---|---|---|---|
| Pro | 250,000 | $5 → ₹415 | ₹1,245 | ₹799 |
| Enterprise | 750,000 | $15 → ₹1,245 | ₹3,735 | ₹2,499 |

> Cost is the same regardless of language — English and Hindi cost identically per character at Google rates. The old token-based system undercounted English (4 chars = 1 token) which gave English users disproportionate quota headroom.
