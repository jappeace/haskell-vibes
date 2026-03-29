#!/usr/bin/env python3
"""Wrapper around Piper TTS that outputs WAV + phoneme timing JSON.

Usage: echo "text" | python3 piper-speak.py /tmp/tts.wav /tmp/tts.json

Requires a patched Piper voice model (with alignment output enabled).
Set PIPER_MODEL env var to the .onnx model path.
"""
import sys
import os
import json
import wave
from piper import PiperVoice

def main():
    if len(sys.argv) != 3:
        print("Usage: echo 'text' | piper-speak.py <wav_path> <json_path>", file=sys.stderr)
        sys.exit(1)

    wav_path = sys.argv[1]
    json_path = sys.argv[2]

    text = sys.stdin.read().strip()
    if not text:
        print("No input text", file=sys.stderr)
        sys.exit(1)

    model_path = os.environ.get("PIPER_MODEL")
    if not model_path:
        print("PIPER_MODEL env var not set", file=sys.stderr)
        sys.exit(1)

    voice = PiperVoice.load(model_path)

    with wave.open(wav_path, "wb") as wav_file:
        alignments = voice.synthesize_wav(
            text, wav_file, include_alignments=True
        )

    sample_rate = voice.config.sample_rate
    phonemes = []

    if alignments:
        for a in alignments:
            # Skip BOS (^) and EOS ($) markers
            if a.phoneme in ("^", "$"):
                continue
            phonemes.append({
                "phoneme": a.phoneme,
                "samples": a.num_samples
            })

    with open(json_path, "w") as f:
        json.dump({"sample_rate": sample_rate, "phonemes": phonemes}, f)


if __name__ == "__main__":
    main()
