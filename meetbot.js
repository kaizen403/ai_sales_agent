import puppeteer from 'puppeteer';
import 'dotenv/config';

const { MEET_URL } = process.env;

(async () => {
  const browser = await puppeteer.launch({
    headless: false,                       // TRUE after testing
    executablePath: '/usr/bin/chromium',
    userDataDir: './chrome-profile',       // profile already logged in
    env: { ...process.env, PULSE_SOURCE: 'MeetMic' },
    args: ['--use-fake-ui-for-media-stream',
           '--disable-gpu', '--mute-audio'],   // lighter Chrome
    defaultViewport: null
  });
  const page = await browser.newPage();

  await page.goto(MEET_URL, { waitUntil: 'networkidle2' });
  await page.waitForFunction(() => document.readyState === 'complete');

  await page.waitForFunction(() => {
    const b = [...document.querySelectorAll('button')]
      .find(x => x.offsetParent && x.innerText.trim() === 'Ask to join');
    return b ? (b.click(), true) : false;
  }, { timeout: 120_000 });

  console.log('[bot] Clicked Ask to join — waiting…');

  await page.waitForFunction(
    () => document.querySelector('[data-is-present="true"]') ||
         document.querySelector('footer[data-panel-id]'),
    { timeout: 5 * 60_000 }
  );
  console.log('[bot] Admitted!');

  process.on('SIGINT', async () => { await browser.close(); process.exit(0); });
})();
