// inspect-buttons.js
import puppeteer from "puppeteer";
import "dotenv/config";

const { MEET_URL } = process.env;

(async () => {
  const browser = await puppeteer.launch({
    headless: false, // leave visible
    executablePath: "/usr/bin/chromium",
    userDataDir: "./chrome-profile", // ← reuse cookies
    args: ["--use-fake-ui-for-media-stream"],
    defaultViewport: null,
  });
  const page = await browser.newPage();

  /* land on Meet pre-join directly */
  await page.goto(MEET_URL, { waitUntil: "networkidle2" });
  await page.waitForFunction(() => document.readyState === "complete");

  /* dump all visible buttons */
  const buttons = await page.$$eval("button", (btns) =>
    btns
      .filter((b) => b.offsetParent !== null)
      .map((b) => ({
        text: b.innerText.trim(),
        html: b.outerHTML.slice(0, 160) + "…",
      })),
  );

  console.log("\n=== VISIBLE BUTTONS ===\n");
  buttons.forEach((b, i) => {
    console.log(`${i}. "${b.text}"\n   ${b.html}\n`);
  });

  console.log(
    "\nCopy the entry whose text is “Ask to join” and paste it here.",
  );
  await browser.close();
})();
