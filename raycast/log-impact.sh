#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Log Impact
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 📝
# @raycast.packageName Impact Capture
# @raycast.argument1 { "type": "text", "placeholder": "What happened?" }
# @raycast.argument2 { "type": "text", "placeholder": "category id", "optional": true }

# Documentation:
# @raycast.description Save a quick note to Impact Capture. Category ids are listed in Settings › Integrations.

encode() {
  /usr/bin/python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"
}

if open -g "impactcapture://log?text=$(encode "$1")&category=$(encode "${2:-}")"; then
  echo "Logged ✓"
else
  echo "Impact Capture isn't installed"
  exit 1
fi
