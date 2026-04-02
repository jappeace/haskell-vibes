#!/bin/bash
# Speak Claude's response summary aloud

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
  stan)  VOICE="joe" ;;
  cabal) VOICE="cabal" ;;
  morag) VOICE="morag" ;;
  *)     VOICE="amy" ;;
esac
export PIPER_MODEL="${PIPER_VOICES}/${VOICE}/medium/en_US-${VOICE}-medium.onnx"

# Kill any previous speech before starting new one
pkill -f "play -t wav" 2>/dev/null

# Speak via piper + sox play (CABAL voice gets SoX DSP post-processing)
if [ "$VOICE" = "cabal" ]; then
  echo "$SUMMARY" | piper -f - \
    | play -t wav - \
        phaser 0.7 0.7 3 0.5 0.5 -t \
        flanger 1 2 0 71 0.5 sine 25 linear \
        equalizer 200 1.0q +4 \
        equalizer 6000 1.0q -3 \
        reverb 15 50 70 \
        norm -1 \
        vol 0.05 \
        2>/dev/null
else
  echo "$SUMMARY" | piper -f - | play -t wav - vol 0.05 2>/dev/null
fi

exit 0
