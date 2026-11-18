const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  minimize: () => ipcRenderer.invoke('window:minimize'),
  maximize: () => ipcRenderer.invoke('window:maximize'),
  close: () => ipcRenderer.invoke('window:close'),
  toggleAlwaysOnTop: (forcedValue) =>
    ipcRenderer.invoke('window:toggle-always-on-top', forcedValue),
  setMiniMode: (enabled) => ipcRenderer.invoke('window:set-mini-mode', enabled),
  setOpacity: (opacity) => ipcRenderer.invoke('window:set-opacity', opacity),
  getState: () => ipcRenderer.invoke('window:get-state'),
  onStateChange: (callback) => {
    const handler = (_event, state) => callback(state);
    ipcRenderer.on('window:state-changed', handler);
    return () => {
      ipcRenderer.removeListener('window:state-changed', handler);
    };
  },
});
