#!/usr/bin/env python3
"""Tests for piper-align.py phoneme alignment extraction."""
import json
import os
import struct
import sys
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock

# Import the module under test (same directory)
sys.path.insert(0, os.path.dirname(__file__))
from importlib import import_module
piper_align = import_module("piper-align")


def make_voice(sample_rate, alignments):
    """Build a mock PiperVoice that returns given alignments.

    The mock writes valid WAV frames so wave.open doesn't choke.
    """
    voice = MagicMock()
    voice.config.sample_rate = sample_rate
    voice.config.num_speakers = 0

    def fake_synthesize(text, wav_file, include_alignments=False):
        # wave.open expects proper setup before close
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        # Write a few silent frames so the WAV is valid
        total_samples = sum(a.num_samples for a in alignments)
        wav_file.writeframes(b"\x00\x00" * total_samples)
        if include_alignments:
            return alignments
        return None

    voice.synthesize_wav = fake_synthesize
    return voice


def make_alignment(phoneme, num_samples):
    """Create a mock PhonemeAlignment object."""
    return SimpleNamespace(phoneme=phoneme, num_samples=num_samples)


class TestExtractAlignments(unittest.TestCase):

    def test_filters_bos_eos_markers(self):
        alignments = [
            make_alignment("^", 100),
            make_alignment("h", 2000),
            make_alignment("ɛ", 3000),
            make_alignment("l", 1500),
            make_alignment("$", 100),
        ]
        voice = make_voice(22050, alignments)
        sample_rate, phonemes = piper_align.extract_alignments(voice, "hello")

        self.assertEqual(sample_rate, 22050)
        # BOS and EOS should be gone
        result_phonemes = [p["phoneme"] for p in phonemes]
        self.assertNotIn("^", result_phonemes)
        self.assertNotIn("$", result_phonemes)
        self.assertEqual(result_phonemes, ["h", "ɛ", "l"])

    def test_preserves_sample_counts(self):
        alignments = [
            make_alignment("^", 50),
            make_alignment("t", 1200),
            make_alignment("ɛ", 2400),
            make_alignment("s", 1800),
            make_alignment("t", 1100),
            make_alignment("$", 50),
        ]
        voice = make_voice(16000, alignments)
        _, phonemes = piper_align.extract_alignments(voice, "test")

        samples = [p["samples"] for p in phonemes]
        self.assertEqual(samples, [1200, 2400, 1800, 1100])

    def test_empty_alignments_returns_empty_list(self):
        voice = make_voice(22050, [])
        # synthesize_wav returns None when no alignments
        voice.synthesize_wav = lambda text, wav_file, include_alignments=False: None
        # Need to set up the wav file manually since our mock won't
        original_synthesize = voice.synthesize_wav
        def fake_synth(text, wav_file, include_alignments=False):
            wav_file.setnchannels(1)
            wav_file.setsampwidth(2)
            wav_file.setframerate(22050)
            wav_file.writeframes(b"\x00\x00")
            return None
        voice.synthesize_wav = fake_synth

        sample_rate, phonemes = piper_align.extract_alignments(voice, "hi")

        self.assertEqual(sample_rate, 22050)
        self.assertEqual(phonemes, [])

    def test_only_bos_eos_returns_empty(self):
        alignments = [
            make_alignment("^", 100),
            make_alignment("$", 100),
        ]
        voice = make_voice(22050, alignments)
        _, phonemes = piper_align.extract_alignments(voice, ".")

        self.assertEqual(phonemes, [])

    def test_json_output_format(self):
        """End-to-end: extract_alignments result writes correct JSON."""
        alignments = [
            make_alignment("^", 50),
            make_alignment("w", 1500),
            make_alignment("ɜː", 3000),
            make_alignment("l", 1200),
            make_alignment("d", 900),
            make_alignment("$", 50),
        ]
        voice = make_voice(22050, alignments)
        sample_rate, phonemes = piper_align.extract_alignments(voice, "world")

        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            json.dump({"sample_rate": sample_rate, "phonemes": phonemes}, f)
            tmp_path = f.name

        try:
            with open(tmp_path) as f:
                data = json.load(f)

            self.assertEqual(data["sample_rate"], 22050)
            self.assertEqual(len(data["phonemes"]), 4)
            self.assertEqual(data["phonemes"][0]["phoneme"], "w")
            self.assertEqual(data["phonemes"][0]["samples"], 1500)
            # Total samples should match
            total = sum(p["samples"] for p in data["phonemes"])
            self.assertEqual(total, 1500 + 3000 + 1200 + 900)
        finally:
            os.unlink(tmp_path)


if __name__ == "__main__":
    unittest.main()
