#!/bin/bash
# Kill any running TTS speech when user submits a new prompt
pkill -f "piper --speaker" 2>/dev/null
pkill cvlc 2>/dev/null
exit 0
