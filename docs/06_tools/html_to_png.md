# 12 — HTML to PNG via Puppeteer

Convert any HTML file to a pixel-perfect PNG using Node.js + Puppeteer (headless Chrome). No screenshot tools needed.

## One-time setup

```bash
cd demo
npm install puppeteer --save-dev
```

## Script

```js
const puppeteer = require('puppeteer');
const path = require('path');

(async () => {
  const browser = await puppeteer.launch();
  const page = await browser.newPage();

  await page.setViewport({ width: 1280, height: 720 });
  await page.goto('file://' + path.resolve('linkedin_thumbnail.html'));
  await new Promise(r => setTimeout(r, 500)); // let animations/fonts settle

  await page.screenshot({
    path: 'linkedin_thumbnail.png',
    clip: { x: 0, y: 0, width: 1280, height: 720 },
  });

  await browser.close();
  console.log('done');
})();
```

Run it:

```bash
node convert.js
```

## Notes

- `file://` + `path.resolve(filename)` — loads local HTML with relative asset paths (images, CSS) working correctly
- `setViewport` controls the browser window size — match it to your HTML's fixed dimensions
- `clip` ensures the output is exactly the viewport size even if the page has scrollable overflow
- The 500 ms delay lets CSS animations and web fonts finish rendering before the screenshot fires
- Output is a lossless PNG — suitable for LinkedIn, GitHub READMEs, or any media upload
