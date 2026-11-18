const { app, BrowserWindow, ipcMain, screen } = require('electron');
const path = require('path');

let mainWindow = null;

const windowState = {
  isAlwaysOnTop: false,
  isMiniMode: false,
  opacity: 1,
  normalBounds: null,
  miniBounds: null,
  wasAlwaysOnTopBeforeMini: false,
};

function getSerializableState() {
  return {
    isAlwaysOnTop: windowState.isAlwaysOnTop,
    isMiniMode: windowState.isMiniMode,
    opacity: windowState.opacity,
    isMaximized: mainWindow ? mainWindow.isMaximized() : false,
    isElectron: true,
  };
}

function broadcastState() {
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send('window:state-changed', getSerializableState());
  }
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1240,
    height: 840,
    minWidth: 960,
    minHeight: 640,
    frame: false,
    titleBarStyle: 'hidden',
    backgroundColor: '#0f172a',
    show: false,
    icon: path.join(__dirname, 'icon.png'),
    webPreferences: {
      preload: path.join(__dirname, 'preload.cjs'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  mainWindow.once('ready-to-show', () => {
    mainWindow.show();
  });

  mainWindow.on('maximize', broadcastState);
  mainWindow.on('unmaximize', broadcastState);

  const isDev = process.argv.includes('--dev') || Boolean(process.env.VITE_DEV_SERVER_URL);
  if (isDev) {
    mainWindow.loadURL(process.env.VITE_DEV_SERVER_URL || 'http://localhost:5173');
  } else {
    mainWindow.loadFile(path.join(__dirname, '../dist/index.html'));
  }
}

ipcMain.handle('window:minimize', () => {
  mainWindow?.minimize();
});

ipcMain.handle('window:maximize', () => {
  if (!mainWindow) return getSerializableState();
  if (windowState.isMiniMode) return getSerializableState();
  if (mainWindow.isMaximized()) {
    mainWindow.unmaximize();
  } else {
    mainWindow.maximize();
  }
  return getSerializableState();
});

ipcMain.handle('window:close', () => {
  mainWindow?.close();
});

ipcMain.handle('window:toggle-always-on-top', (_event, forcedValue) => {
  if (!mainWindow) return getSerializableState();
  windowState.isAlwaysOnTop =
    typeof forcedValue === 'boolean' ? forcedValue : !windowState.isAlwaysOnTop;
  mainWindow.setAlwaysOnTop(windowState.isAlwaysOnTop, 'floating');
  broadcastState();
  return getSerializableState();
});

ipcMain.handle('window:set-mini-mode', (_event, forcedValue) => {
  if (!mainWindow) return getSerializableState();
  const nextMini = typeof forcedValue === 'boolean' ? forcedValue : !windowState.isMiniMode;
  if (nextMini === windowState.isMiniMode) return getSerializableState();

  if (nextMini) {
    if (mainWindow.isMaximized()) {
      mainWindow.unmaximize();
    }
    windowState.normalBounds = mainWindow.getBounds();
    windowState.wasAlwaysOnTopBeforeMini = windowState.isAlwaysOnTop;
    windowState.isMiniMode = true;
    mainWindow.setResizable(true);
    mainWindow.setMinimumSize(340, 480);

    let targetBounds = windowState.miniBounds;
    if (!targetBounds) {
      const display = screen.getDisplayMatching(mainWindow.getBounds());
      const { x, y, width } = display.workArea;
      targetBounds = {
        x: x + width - 416,
        y: y + 48,
        width: 390,
        height: 560,
      };
    }
    mainWindow.setBounds(targetBounds, true);
    windowState.isAlwaysOnTop = true;
    mainWindow.setAlwaysOnTop(true, 'floating');
  } else {
    windowState.miniBounds = mainWindow.getBounds();
    windowState.isMiniMode = false;
    mainWindow.setMinimumSize(960, 640);

    const restoreBounds = windowState.normalBounds || {
      width: 1240,
      height: 840,
      x: undefined,
      y: undefined,
    };
    if (typeof restoreBounds.x === 'number' && typeof restoreBounds.y === 'number') {
      mainWindow.setBounds(restoreBounds, true);
    } else {
      mainWindow.setSize(1240, 840, true);
      mainWindow.center();
    }

    windowState.isAlwaysOnTop = windowState.wasAlwaysOnTopBeforeMini;
    mainWindow.setAlwaysOnTop(windowState.isAlwaysOnTop, 'floating');
  }

  broadcastState();
  return getSerializableState();
});

ipcMain.handle('window:set-opacity', (_event, value) => {
  if (!mainWindow) return getSerializableState();
  const clamped = Math.min(1, Math.max(0.4, Number(value) || 1));
  windowState.opacity = Number(clamped.toFixed(2));
  mainWindow.setOpacity(windowState.opacity);
  broadcastState();
  return getSerializableState();
});

ipcMain.handle('window:get-state', () => {
  return getSerializableState();
});

app.whenReady().then(() => {
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});
