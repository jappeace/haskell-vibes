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

# Kill any previous speech before starting new one
pkill vlc 2>/dev/null

# Speak via piper + cvlc
echo "$SUMMARY" | piper --speaker 1 -f - | cvlc --play-and-exit --aout pulse --gain 0.05 - 2>/dev/null

exit 0
