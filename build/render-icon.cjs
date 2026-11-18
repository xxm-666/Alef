// Renders build/icon.svg to build/icon.png using Electron. Run: npx electron build/render-icon.cjs
const { app, BrowserWindow } = require('electron');
const fs = require('fs');
const path = require('path');

app.disableHardwareAcceleration();
process.on('unhandledRejection', (e) => { console.error('ERR', e); app.exit(1); });
app.whenReady().then(async () => {
  console.log('ready');
  const svg = fs.readFileSync(path.join(__dirname, 'icon.svg'), 'utf8');
  const win = new BrowserWindow({ width: 1024, height: 1024, show: false, transparent: true, frame: false,
    useContentSize: true, webPreferences: { offscreen: true } });
  const html = `<html><body style="margin:0;background:transparent">${svg}</body></html>`;
  await win.loadURL('data:text/html;charset=utf-8,' + encodeURIComponent(html));
  await new Promise((r) => setTimeout(r, 500));
  const img = await win.webContents.capturePage({ x: 0, y: 0, width: 1024, height: 1024 });
  fs.writeFileSync(path.join(__dirname, 'icon.png'), img.toPNG());
  app.quit();
});
