#!/bin/bash

# uStreamer Camera Selection Script
# Displays available cameras and starts ustreamer with user selection

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USTREAMER="$SCRIPT_DIR/ustreamer"

# Check if ustreamer exists
if [[ ! -f "$USTREAMER" ]]; then
    echo "Error: ustreamer not found at $USTREAMER"
    echo "Make sure you've compiled ustreamer first with: make apps"
    exit 1
fi

# Default settings
PORT=8080
HOST="0.0.0.0"
RESOLUTION="640x480"
FPS=15
QUALITY=80

echo "═══════════════════════════════════════════════════"
echo "            uStreamer Camera Selection              "
echo "═══════════════════════════════════════════════════"
echo

# Get camera list by running ustreamer briefly and parsing output
echo "Detecting available cameras..."
TEMP_LOG=$(mktemp)

# Start ustreamer with device 0, capture logs, then kill it
timeout 5s "$USTREAMER" --device 0 --port 9999 >/dev/null 2>"$TEMP_LOG" || true

# Parse camera list from logs
CAMERAS=$(grep "MACOS_CAM:   [0-9]" "$TEMP_LOG" | sed 's/.*MACOS_CAM:   //')

if [[ -z "$CAMERAS" ]]; then
    echo "Error: No cameras detected or failed to parse camera list"
    echo "Raw log output:"
    cat "$TEMP_LOG"
    rm -f "$TEMP_LOG"
    exit 1
fi

echo "Available cameras:"
echo "$CAMERAS"
echo

# Get camera count
CAMERA_COUNT=$(echo "$CAMERAS" | wc -l | tr -d ' ')

# Prompt user for camera selection
while true; do
    echo -n "Select camera (0-$((CAMERA_COUNT-1))) [default: 0]: "
    read -r CAMERA_CHOICE
    
    # Default to 0 if empty
    if [[ -z "$CAMERA_CHOICE" ]]; then
        CAMERA_CHOICE=0
    fi
    
    # Validate input
    if [[ "$CAMERA_CHOICE" =~ ^[0-9]+$ ]] && [[ "$CAMERA_CHOICE" -ge 0 ]] && [[ "$CAMERA_CHOICE" -lt "$CAMERA_COUNT" ]]; then
        break
    else
        echo "Invalid selection. Please enter a number between 0 and $((CAMERA_COUNT-1))"
    fi
done

# Get selected camera info
SELECTED_CAMERA=$(echo "$CAMERAS" | sed -n "$((CAMERA_CHOICE+1))p" | sed 's/^[0-9]*: //')
echo
echo "Selected camera: $SELECTED_CAMERA"

# Prompt for additional settings
echo
echo "Configure settings (press Enter for defaults):"

echo -n "Port [$PORT]: "
read -r USER_PORT
if [[ -n "$USER_PORT" ]]; then
    PORT="$USER_PORT"
fi

echo -n "Host [$HOST]: "
read -r USER_HOST
if [[ -n "$USER_HOST" ]]; then
    HOST="$USER_HOST"
fi

echo -n "Resolution [$RESOLUTION]: "
read -r USER_RESOLUTION
if [[ -n "$USER_RESOLUTION" ]]; then
    RESOLUTION="$USER_RESOLUTION"
fi

echo -n "FPS [$FPS]: "
read -r USER_FPS
if [[ -n "$USER_FPS" ]]; then
    FPS="$USER_FPS"
fi

echo -n "JPEG Quality [$QUALITY]: "
read -r USER_QUALITY
if [[ -n "$USER_QUALITY" ]]; then
    QUALITY="$USER_QUALITY"
fi

# Clean up temp file
rm -f "$TEMP_LOG"

# Build command
CMD=(
    "$USTREAMER"
    --device "$CAMERA_CHOICE"
    --port "$PORT"
    --host "$HOST"
    --resolution "$RESOLUTION"
    --quality "$QUALITY"
    --drop-same-frames=10
)

echo
echo "═══════════════════════════════════════════════════"
echo "Starting uStreamer with the following settings:"
echo "Camera: $SELECTED_CAMERA"
echo "Device: $CAMERA_CHOICE"
echo "Port: $PORT"
echo "Host: $HOST"
echo "Resolution: $RESOLUTION"
echo "FPS: $FPS"
echo "Quality: $QUALITY"
echo "URL: http://$HOST:$PORT"
echo "═══════════════════════════════════════════════════"
echo
echo "Press Ctrl+C to stop the stream"
echo

# Execute ustreamer
exec "${CMD[@]}"
