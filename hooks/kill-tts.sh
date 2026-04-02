#!/bin/bash
# Kill any running TTS speech when user submits a new prompt
pkill -f "play -t wav" 2>/dev/null
exit 0
