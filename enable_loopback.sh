#!/usr/bin/env bash
#
# enable_loopback.sh — load ALSA loopback and restart PipeWire so Chrome
# sees “ALSA Loopback” as a mic.

set -e

# 1. Load the kernel loopback module
echo "Loading snd_aloop module…"
sudo modprobe snd_aloop

# 2. Restart PipeWire so it rescans devices
echo "Restarting PipeWire…"
systemctl --user restart pipewire

# 3. List the new sources
echo
echo "Available Loopback sources:"
pactl list short sources | grep -E 'Loopback|snd_aloop' || echo "  (none found)"

cat <<'EOF'

✅ Loopback enabled! In Google Meet → Settings → Audio → Microphone,
   select “ALSA Loopback” (or similar).

To play audio into Meet, pipe any PCM into the Loopback playback side, e.g.:

  mpg123 -q -s song.mp3 | aplay -D plughw:Loopback,0,0 -f S16_LE -r 48000 -

When you’re done, unload the loopback and restore normal audio:

  sudo modprobe -r snd_aloop
  systemctl --user restart pipewire

EOF
