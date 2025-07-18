#!/usr/bin/env bash
#
# play_tone.sh — generate a sine wave at a given frequency and send it
# into the PipeWire loopback sink so Meet hears it as your mic.

if [ -z "$1" ]; then
  echo "Usage: $0 <frequency_hz> [duration_s]"
  echo "Example: $0 1000 3   # 1 kHz tone for 3 seconds"
  exit 1
fi

FREQ="$1"
DUR="${2:-2}" # default duration = 2 s

ffmpeg -hide_banner -loglevel error \
  -f lavfi -i "sine=frequency=${FREQ}:duration=${DUR}" \
  -f s16le -ar 48000 -ac 1 pipe:1 |
  pw-cat --playback --raw \
    --format s16 --rate 48000 --channels 1 \
    --target alsa_output.platform-snd_aloop.0.analog-stereo \
    -
