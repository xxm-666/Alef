// Renders build/icon.svg to build/icon.png, electron/icon.png, and public/icons/*.png using Electron.
const { app, BrowserWindow, nativeImage } = require('electron');
const fs = require('fs');
const path = require('path');

app.disableHardwareAcceleration();
process.on('unhandledRejection', (e) => { console.error('ERR', e); app.exit(1); });

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

  const html = `<html><body style="margin:0;background:transparent">${svg}</body></html>`;
  await win.loadURL('data:text/html;charset=utf-8,' + encodeURIComponent(html));
  await new Promise((r) => setTimeout(r, 500));

  const captured = await win.webContents.capturePage({ x: 0, y: 0, width: 1024, height: 1024 });
  const png1024 = captured.toPNG();

  // Desktop & build icons (1024x1024 transparent squircle)
  fs.writeFileSync(path.join(__dirname, 'icon.png'), png1024);
  fs.writeFileSync(path.join(root, 'electron', 'icon.png'), png1024);

  // PWA icons (512x512 and 192x192)
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

  // iOS apple-touch-icon (180x180 full-bleed dark background so iOS never shows black corners)
  const iosHtml = `<html><body style="margin:0;width:1024px;height:1024px;background:linear-gradient(135deg,#1e3a6e 0%,#0f1c38 48%,#080e1d 100%)">${svg}</body></html>`;
  await win.loadURL('data:text/html;charset=utf-8,' + encodeURIComponent(iosHtml));
  await new Promise((r) => setTimeout(r, 300));
  const iosCaptured = await win.webContents.capturePage({ x: 0, y: 0, width: 1024, height: 1024 });
  fs.writeFileSync(
    path.join(iconsDir, 'apple-touch-icon.png'),
    nativeImage.createFromBuffer(iosCaptured.toPNG()).resize({ width: 180, height: 180, quality: 'best' }).toPNG()
  );

  console.log('Rendered all icons cleanly.');
  app.quit();
});
