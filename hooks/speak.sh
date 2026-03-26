#!/bin/bash
# Speak Claude's response summary aloud and display via cowsay

# Kill any previous speech first
pkill -f "piper --speaker" 2>/dev/null
pkill cvlc 2>/dev/null

INPUT=$(cat)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty')

# Extract summary from the last assistant message in the transcript
SUMMARY=""
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  # Get the last assistant text message from the JSONL transcript
  SUMMARY=$(tac "$TRANSCRIPT" | grep -m1 '"type":"assistant"' | jq -r '.message.content[] | select(.type=="text") | .text' 2>/dev/null | head -c 500)
fi

# Fallback if no summary extracted
if [ -z "$SUMMARY" ]; then
  SUMMARY="Task completed."
fi

# Random cowsay character and mood
cow_modes=("-b" "-d" "" "-g" "-p" "-s" "-t" "-w" "-y")
cowfiles=("vader-koala" "tux" "turtle" "kitty" "meow" "llama" "kosh"
          "flaming-sheep" "elephant-in-snake" "elephant" "cower" "bud-frogs" "blowfish")
rng=$((RANDOM % 9))
cow_rng=$((RANDOM % 13))

# Speak via piper + cvlc in background
(echo "$SUMMARY" | piper --speaker 1 -f - | cvlc --play-and-exit --aout pulse --gain 0.05 - 2>/dev/null) &

# Visual display to stderr
echo "$SUMMARY" | cowsay -W 35 ${cow_modes[$rng]} -f ${cowfiles[$cow_rng]} >&2

exit 0
