// meetbot.js
import puppeteer from "puppeteer";
import { execSync } from "child_process";
import { join } from "path";
import "dotenv/config";

const { MEET_URL } = process.env;

(async () => {
  // 0️⃣  Convert song.mp3 → test_mic.wav (48 kHz mono PCM)
  const wavPath = join(process.cwd(), "test_mic.wav");
  console.log("[bot] Converting song.mp3 to fake-capture WAV…");
  execSync(
    `ffmpeg -y -hide_banner -loglevel error -i song.mp3 ` +
      `-ar 48000 -ac 1 "${wavPath}"`,
  );

  // 1️⃣  Launch Chromium with fake‑audio pointed at test_mic.wav
  console.log("[bot] Launching browser with fake-audio-capture…");
  const browser = await puppeteer.launch({
    headless: false, // set to true once you’ve verified it works
    executablePath: "/usr/bin/chromium",
    userDataDir: "./chrome-profile",
    args: [
      "--use-fake-ui-for-media-stream",
      "--use-fake-device-for-media-stream",
      `--use-file-for-fake-audio-capture=${wavPath}`,
      "--disable-gpu",
      "--mute-audio",
    ],
    defaultViewport: null,
  });
  const page = await browser.newPage();

  // 2️⃣  Navigate to the Meet URL
  console.log("[bot] Navigating to Meet and waiting for load…");
  await page.goto(MEET_URL, { waitUntil: "networkidle2", timeout: 120_000 });
  await page.waitForFunction(() => document.readyState === "complete");

  // 3️⃣  Click “Ask to join”
  console.log("[bot] Looking for “Ask to join” button…");
  await page.waitForFunction(
    () => {
      const btn = [...document.querySelectorAll("button")].find(
        (b) => b.offsetParent && b.innerText.trim() === "Ask to join",
      );
      if (!btn) return false;
      btn.click();
      return true;
    },
    { timeout: 120_000 },
  );

  console.log("[bot] Clicked “Ask to join” — waiting for admission…");

  // 4️⃣  Wait until admitted
  await page.waitForFunction(
    () =>
      !!document.querySelector('[data-is-present="true"]') ||
      !!document.querySelector("footer[data-panel-id]"),
    { timeout: 300_000 },
  );
  console.log("[bot] Admitted! Streaming song.mp3 as mic now.");

  // 5️⃣  Keep browser alive until you manually exit
  process.on("SIGINT", async () => {
    await browser.close();
    process.exit(0);
  });
})();
