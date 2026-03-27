#!/bin/bash
# Speak Claude's response summary aloud

INPUT=$(cat)
echo "$(date): Hook invoked" >> /tmp/speak_hook.log
echo "INPUT: $INPUT" >> /tmp/speak_hook.log
SUMMARY=$(echo "$INPUT" | jq -r '.last_assistant_message // empty' | head -c 500)
echo "SUMMARY: $SUMMARY" >> /tmp/speak_hook.log

if [ -z "$SUMMARY" ]; then
  SUMMARY="Task completed."
fi

# Select voice based on instance name
case "$INSTANCE_NAME" in
  stan) VOICE="joe" ;;
  kyle) VOICE="cabal" ;;
  *)    VOICE="amy" ;;
esac
export PIPER_MODEL="${PIPER_VOICES}/${VOICE}/medium/en_US-${VOICE}-medium.onnx"

# Kill any previous speech before starting new one
pkill vlc 2>/dev/null

# Speak via piper + cvlc (CABAL voice gets SoX DSP post-processing)
if [ "$VOICE" = "cabal" ]; then
  echo "$SUMMARY" | piper -f - \
    | sox -t wav - -t wav - \
        phaser 0.7 0.7 3 0.5 0.5 -t \
        flanger 1 2 0 71 0.5 sine 25 linear \
        equalizer 200 1.0q +4 \
        equalizer 6000 1.0q -3 \
        reverb 15 50 70 \
        norm -1 \
    | cvlc --play-and-exit --aout pulse --gain 0.05 - 2>/dev/null
else
  echo "$SUMMARY" | piper -f - | cvlc --play-and-exit --aout pulse --gain 0.05 - 2>/dev/null
fi

exit 0
