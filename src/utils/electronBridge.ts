import { ElectronWindowState } from '../types/hebrew';

interface ElectronAPI {
  minimize: () => Promise<void>;
  maximize: () => Promise<ElectronWindowState>;
  close: () => Promise<void>;
  toggleAlwaysOnTop: (forcedValue?: boolean) => Promise<ElectronWindowState>;
  setMiniMode: (enabled?: boolean) => Promise<ElectronWindowState>;
  setOpacity: (opacity: number) => Promise<ElectronWindowState>;
  getState: () => Promise<ElectronWindowState>;
  onStateChange: (callback: (state: ElectronWindowState) => void) => () => void;
}

declare global {
  interface Window {
    electronAPI?: ElectronAPI;
  }
}

export const DEFAULT_WINDOW_STATE: ElectronWindowState = {
  isAlwaysOnTop: false,
  isMiniMode: false,
  opacity: 1,
  isMaximized: false,
  isElectron: false,
};

export function getElectronAPI(): ElectronAPI | null {
  if (typeof window !== 'undefined' && window.electronAPI) {
    return window.electronAPI;
  }
  return null;
}
