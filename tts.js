import { WebSocketServer } from "ws";
import { spawn } from "child_process";
import ElevenLabs from "elevenlabs";
import "dotenv/config.js"; // loads .env

const eleven = new ElevenLabs({ apiKey: process.env.ELEVEN_API_KEY });
const VOICE = process.env.ELEVEN_VOICE_ID;
const MODEL = "eleven_monolingual_v1";

const wss = new WebSocketServer({ port: 4000 }, () =>
  console.log("TTS WebSocket listening ▶  ws://localhost:4000"),
);

wss.on("connection", (ws) => {
  ws.on("message", async (msg) => {
    const text = msg.toString().trim();
    if (!text) return;

    /* play to Loopback 0 (playback side) */
    const aplay = spawn("aplay", [
      "-D",
      "plughw:Loopback,0", // device name
      "-f",
      "S16_LE",
      "-r",
      "22050",
    ]);

    try {
      const stream = await eleven.textToSpeech.stream({
        model: MODEL,
        voice: VOICE,
        input: text,
        format: "wav",
      });
      stream.pipe(aplay.stdin);
      stream.on("end", () => {
        aplay.stdin.end();
        ws.send("done");
      });
    } catch (err) {
      console.error(err);
      ws.send(JSON.stringify({ error: err.message }));
      aplay.stdin.end();
    }
  });
});
