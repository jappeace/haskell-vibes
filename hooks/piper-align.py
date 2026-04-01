#!/usr/bin/env python3
"""Extract phoneme alignment timing from Piper TTS.

Usage: echo "hello world" | python3 piper-align.py /tmp/phonemes.json

Runs Piper synthesis to obtain per-phoneme sample counts, then writes
timing JSON. Audio is discarded — use alongside speak.sh for playback.

Requires:
  - PIPER_MODEL env var pointing to a patched .onnx voice model
  - piper-tts Python package (not just the CLI binary)
"""
import sys
import os
import json
import io
import wave


def extract_alignments(voice, text):
    """Synthesize text and return (sample_rate, phoneme_list).

    Phoneme list contains dicts with 'phoneme' and 'samples' keys.
    BOS (^) and EOS ($) markers are filtered out.
    """
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wav_file:
        alignments = voice.synthesize_wav(
            text, wav_file, include_alignments=True
        )

    sample_rate = voice.config.sample_rate
    phonemes = []

    if alignments:
        for a in alignments:
            if a.phoneme in ("^", "$"):
                continue
            phonemes.append({
                "phoneme": a.phoneme,
                "samples": a.num_samples,
            })

    return sample_rate, phonemes


def main():
    from piper import PiperVoice

    if len(sys.argv) < 2:
        print("Usage: echo 'text' | piper-align.py <json_path>", file=sys.stderr)
        sys.exit(1)

    json_path = sys.argv[1]

    text = sys.stdin.read().strip()
    if not text:
        print("No input text", file=sys.stderr)
        sys.exit(1)

    model_path = os.environ.get("PIPER_MODEL")
    if not model_path:
        print("PIPER_MODEL env var not set", file=sys.stderr)
        sys.exit(1)

    voice = PiperVoice.load(model_path)
    sample_rate, phonemes = extract_alignments(voice, text)

    with open(json_path, "w") as f:
        json.dump({"sample_rate": sample_rate, "phonemes": phonemes}, f)

    total_phonemes = len(phonemes)
    total_samples = sum(p["samples"] for p in phonemes)
    duration_s = total_samples / sample_rate if sample_rate > 0 else 0
    print(f"Wrote {total_phonemes} phonemes ({duration_s:.2f}s) to {json_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
