// usage:  node playfile.js song.mp3   (defaults to song.mp3)
import { spawn } from "child_process";
const file = process.argv[2] ?? "song.mp3";

spawn(
  "bash",
  [
    "-c",
    `mpg123 -q -s "${file}" | ` +
      `aplay -D plughw:Loopback,0,0 -f S16_LE -r 48000 -`,
  ],
  { stdio: "inherit" },
);
