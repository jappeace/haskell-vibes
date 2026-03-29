#!/bin/bash
# Kill any running TTS speech and face animation when user submits a new prompt
pkill vlc 2>/dev/null
pkill face-speak 2>/dev/null
exit 0
