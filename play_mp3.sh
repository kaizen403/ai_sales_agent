#!/usr/bin/env bash
#
# play_mp3.sh — decode an MP3 and send it into ALSA Loopback sub‑device 1

if [ -z "$1" ]; then
  echo "Usage: $0 <file.mp3>"
  exit 1
fi

FILE="$1"

# Decode MP3 → raw PCM → loopback sub-device 1
mpg123 -q -s "$FILE" |
  aplay -D plughw:Loopback,0,1 -f S16_LE -r 48000 -
