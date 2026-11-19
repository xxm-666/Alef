// Renders build/icon.svg to build/icon.png, electron/icon.png, and public/icons/*.png using Electron.
const { app, BrowserWindow, nativeImage } = require('electron');
const fs = require('fs');
const path = require('path');

app.disableHardwareAcceleration();
process.on('unhandledRejection', (e) => { console.error('ERR', e); app.exit(1); });

async function renderSvgToBuffer(win, html) {
  await win.loadURL('data:text/html;charset=utf-8,' + encodeURIComponent(html));
  await win.webContents.executeJavaScript(
    'new Promise(r => requestAnimationFrame(() => requestAnimationFrame(() => setTimeout(r, 250))))'
  );
  const img = await win.webContents.capturePage({ x: 0, y: 0, width: 1024, height: 1024 });
  return img.toPNG();
}

app.whenReady().then(async () => {
  const root = path.resolve(__dirname, '..');
  const svg = fs.readFileSync(path.join(__dirname, 'icon.svg'), 'utf8');
  const win = new BrowserWindow({
    width: 1024,
    height: 1024,
    show: false,
    transparent: true,
    frame: false,
    useContentSize: true,
    webPreferences: { offscreen: true },
  });

  // Warm-up load so Chromium offscreen compositor is initialized
  await renderSvgToBuffer(win, `<html><body style="margin:0;background:transparent">${svg}</body></html>`);

  // 1. Desktop & Electron icon (1024x1024 transparent-corner squircle)
  const png1024 = await renderSvgToBuffer(
    win,
    `<html><body style="margin:0;background:transparent">${svg}</body></html>`
  );

  fs.writeFileSync(path.join(__dirname, 'icon.png'), png1024);
  fs.writeFileSync(path.join(root, 'electron', 'icon.png'), png1024);

  const iconsDir = path.join(root, 'public', 'icons');
  fs.mkdirSync(iconsDir, { recursive: true });
  fs.writeFileSync(
    path.join(iconsDir, 'icon-512.png'),
    nativeImage.createFromBuffer(png1024).resize({ width: 512, height: 512, quality: 'best' }).toPNG()
  );
  fs.writeFileSync(
    path.join(iconsDir, 'icon-192.png'),
    nativeImage.createFromBuffer(png1024).resize({ width: 192, height: 192, quality: 'best' }).toPNG()
  );

  // 2. iOS apple-touch-icon (full-bleed 0..1024 background without outer squircle inset so iOS native mask has no double border)
  const fullBleedSvg = svg
    .replace(/<rect class="outer-box" x="40" y="40" width="944" height="944" rx="226"/g, '<rect x="0" y="0" width="1024" height="1024"')
    .replace(/<rect class="outer-rim"[^>]*\/>/g, '');

  const iosPng1024 = await renderSvgToBuffer(
    win,
    `<html><body style="margin:0;background:#040712">${fullBleedSvg}</body></html>`
  );
  fs.writeFileSync(
    path.join(iconsDir, 'apple-touch-icon.png'),
    nativeImage.createFromBuffer(iosPng1024).resize({ width: 180, height: 180, quality: 'best' }).toPNG()
  );

  console.log('Rendered all iOS 26 icons cleanly.');
  app.quit();
});
