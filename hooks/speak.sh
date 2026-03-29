#!/bin/bash
# Speak Claude's response summary aloud with viseme face animation

INPUT=$(cat)
echo "$(date): Hook invoked" >> /tmp/speak_hook.log
echo "INPUT: $INPUT" >> /tmp/speak_hook.log
# Strip markdown formatting so TTS doesn't read asterisks, hashes, etc.
# Filter markdown first, then truncate to avoid cutting mid-syntax.
SUMMARY=$(echo "$INPUT" | jq -r '.last_assistant_message // empty' \
  | sed 's/```[^`]*```//g' \
  | sed 's/`[^`]*`//g' \
  | sed 's/\*\*\*//g' \
  | sed 's/\*\*//g' \
  | sed 's/\*//g' \
  | sed 's/^##* //g' \
  | sed 's/^- /  /g' \
  | sed -E 's/^[0-9]+\. /  /g' \
  | sed -E 's/\[([^]]*)\]\([^)]*\)/\1/g' \
  | sed 's/^> //g' \
  | head -c 500 \
  )
echo "SUMMARY: $SUMMARY" >> /tmp/speak_hook.log

if [ -z "$SUMMARY" ]; then
  SUMMARY="Task completed."
fi

# Select voice based on instance name
case "$INSTANCE_NAME" in
  stan) VOICE="joe" ;;
  cabal) VOICE="cabal" ;;
  *)    VOICE="amy" ;;
esac
export PIPER_MODEL="${PIPER_VOICES}/${VOICE}/medium/en_US-${VOICE}-medium.onnx"

# Kill any previous speech and face animation before starting new one
pkill vlc 2>/dev/null
pkill face-speak 2>/dev/null

WAV_PATH="/tmp/tts-${INSTANCE_NAME}.wav"
JSON_PATH="/tmp/tts-${INSTANCE_NAME}.json"

# Generate WAV + phoneme timing via piper-speak.py
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ "$VOICE" = "cabal" ]; then
  # Cabal voice: generate raw WAV first, then apply SoX effects
  echo "$SUMMARY" | python3 "$HOOK_DIR/piper-speak.py" "/tmp/tts-raw-${INSTANCE_NAME}.wav" "$JSON_PATH"
  sox "/tmp/tts-raw-${INSTANCE_NAME}.wav" "$WAV_PATH" \
      phaser 0.7 0.7 3 0.5 0.5 -t \
      flanger 1 2 0 71 0.5 sine 25 linear \
      equalizer 200 1.0q +4 \
      equalizer 6000 1.0q -3 \
      reverb 15 50 70 \
      norm -1
else
  echo "$SUMMARY" | python3 "$HOOK_DIR/piper-speak.py" "$WAV_PATH" "$JSON_PATH"
fi

# Launch face animation (visual only, background)
face-speak "$JSON_PATH" &

# Play audio via cvlc
cvlc --play-and-exit --aout pulse --gain 0.05 "$WAV_PATH" 2>/dev/null

exit 0
