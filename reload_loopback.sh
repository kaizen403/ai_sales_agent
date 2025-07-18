#!/usr/bin/env bash
#
# reload_loopback.sh — load snd_aloop and restart PipeWire so you get
# your loopback sink + source back after a reboot.

set -e

echo "1) Loading snd_aloop…"
sudo modprobe snd_aloop

echo "2) Restarting PipeWire…"
systemctl --user restart pipewire

echo "3) Available Loopback devices:"
pactl list short sinks | grep loopback || echo "  (no loopback sink found)"
pactl list short sources | grep loopback || echo "  (no loopback source found)"

cat <<'EOF'

✅ Loopback reloaded. 

➜ To use as your mic in Meet, in Fish run:
    set -x PULSE_SOURCE loopback_out.monitor

  or point directly at the hardware:
    set -x PULSE_SOURCE alsa_input.platform-snd_aloop.0.analog-stereo

➜ Then launch your bot:
    node meetbot.js

➜ And in another terminal play audio:
    ./play_mp3.sh song.mp3    # or
    ./play_tone.sh 440 2

EOF
