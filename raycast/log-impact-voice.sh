#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Log Impact by Voice
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🎙️
# @raycast.packageName Impact Capture

# Documentation:
# @raycast.description Open the Impact Capture panel and start listening.

if open -g "impactcapture://voice"; then
  echo "Listening…"
else
  echo "Impact Capture isn't installed — run make install"
  exit 1
fi
