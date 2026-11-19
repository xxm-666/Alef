import React, { lazy, Suspense, useEffect, useState } from 'react';
import {
  BookOpen,
  CreditCard,
  Database,
  Grid,
  Languages,
  Layers,
  Maximize2,
  Minimize2,
  Minus,
  Moon,
  PictureInPicture2,
  Pin,
  PinOff,
  Settings,
  Square,
  Sun,
  X,
} from 'lucide-react';
import {
  ElectronWindowState,
  StudyViewMode,
  ThemeMode,
} from '../types/hebrew';

interface TitleBarProps {
  activeView: StudyViewMode;
  onSelectView: (view: StudyViewMode) => void;
  theme: ThemeMode;
  onToggleTheme: () => void;
  windowState: ElectronWindowState;
  onToggleAlwaysOnTop: () => void;
  onToggleMiniMode: () => void;
  onChangeOpacity: (opacity: number) => void;
  onMinimize: () => void;
  onMaximize: () => void;
  onClose: () => void;
  onOpenBackup: () => void;
}

const GlassLetterLens = lazy(() => import('./GlassLetterLens'));

const NAV_ITEMS: { id: StudyViewMode; label: string; shortLabel: string; icon: React.ReactNode }[] = [
  { id: 'grid', label: '全字母表', shortLabel: '字母', icon: <Grid size={15} /> },
  { id: 'detail', label: '单字卡片', shortLabel: '单字', icon: <CreditCard size={15} /> },
  { id: 'words', label: '高频单词', shortLabel: '单词', icon: <Languages size={15} /> },
  { id: 'flashcards', label: '闪卡自测', shortLabel: '闪卡', icon: <Layers size={15} /> },
  { id: 'rules', label: '规则对比', shortLabel: '规则', icon: <BookOpen size={15} /> },
  { id: 'settings', label: '设置', shortLabel: '设置', icon: <Settings size={15} /> },
];

const MOBILE_NAV_ORDER: StudyViewMode[] = ['words', 'flashcards', 'grid', 'rules', 'settings'];
const MOBILE_NAV_ITEMS = MOBILE_NAV_ORDER.flatMap((id) => NAV_ITEMS.filter((item) => item.id === id));

export const TitleBar: React.FC<TitleBarProps> = ({
  activeView,
  onSelectView,
  theme,
  onToggleTheme,
  windowState,
  onToggleAlwaysOnTop,
  onToggleMiniMode,
  onChangeOpacity,
  onMinimize,
  onMaximize,
  onClose,
  onOpenBackup,
}) => {
  const [isBottomNav, setIsBottomNav] = useState(
    () => window.matchMedia('(max-width: 768px)').matches
  );

  useEffect(() => {
    const query = window.matchMedia('(max-width: 768px)');
    const update = () => setIsBottomNav(query.matches);
    update();
    query.addEventListener('change', update);
    return () => query.removeEventListener('change', update);
  }, []);

  const items = isBottomNav ? MOBILE_NAV_ITEMS : NAV_ITEMS;
  const activeItem = isBottomNav && activeView === 'detail' ? 'grid' : activeView;

  return (
    <header className="titlebar">
      <nav className="titlebar-nav" aria-label="主视图切换">
        {items.map((item) => {
          const isCenter = isBottomNav && item.id === 'grid';
          const button = (
            <button
              key={item.id}
              type="button"
              className={`nav-pill ${isCenter ? 'nav-pill-center' : ''} ${activeItem === item.id ? 'active' : ''}`}
              aria-label={item.label}
              aria-current={activeItem === item.id ? 'page' : undefined}
              onClick={() => onSelectView(item.id)}
            >
              {isCenter ? <span className="nav-center-glyph" aria-hidden="true">א</span> : item.icon}
              <span className="nav-label-desktop">{item.label}</span>
              <span className="nav-label-mobile">{item.shortLabel}</span>
            </button>
          );
          return isCenter ? (
            <div className="nav-center-slot" key={item.id}>
              {/* Chromium renders displacement. Other browsers use the CSS lens below. */}
              {CSS.supports('appearance', 'base-select') && (
                <Suspense fallback={null}>
                  <GlassLetterLens />
                </Suspense>
              )}
              {button}
            </div>
          ) : button;
        })}
      </nav>

      <div className="titlebar-actions">
        <div className="opacity-control desktop-only-control" title="窗口透明度">
          <span className="opacity-label">{Math.round(windowState.opacity * 100)}%</span>
          <input
            type="range"
            min={0.45}
            max={1}
            step={0.05}
            value={windowState.opacity}
            onChange={(e) => onChangeOpacity(Number(e.target.value))}
            aria-label="调节窗口透明度"
          />
        </div>

        <button
          type="button"
          className={`icon-action-btn desktop-only-control ${windowState.isAlwaysOnTop ? 'active-pin' : ''}`}
          onClick={onToggleAlwaysOnTop}
          title={windowState.isAlwaysOnTop ? '取消窗口置顶' : '窗口常驻置顶'}
        >
          {windowState.isAlwaysOnTop ? <Pin size={15} /> : <PinOff size={15} />}
          <span className="btn-label-desktop">置顶</span>
        </button>

        <button
          type="button"
          className="icon-action-btn desktop-only-control"
          onClick={onToggleMiniMode}
          title="切换桌面迷你悬浮小窗"
        >
          <PictureInPicture2 size={15} />
          <span className="btn-label-desktop">迷你窗</span>
        </button>

        <button
          type="button"
          className="icon-action-btn"
          onClick={onOpenBackup}
          title="学习进度备份与同步"
        >
          <Database size={15} />
        </button>

        <button
          type="button"
          className="icon-action-btn"
          onClick={onToggleTheme}
          title={theme === 'dark' ? '切换为日间主题' : '切换为深邃夜间主题'}
        >
          {theme === 'dark' ? <Sun size={15} /> : <Moon size={15} />}
        </button>

        {windowState.isElectron && (
          <div className="window-controls">
            <button
              type="button"
              className="win-btn"
              onClick={onMinimize}
              title="最小化"
            >
              <Minus size={14} />
            </button>
            <button
              type="button"
              className="win-btn"
              onClick={onMaximize}
              title={windowState.isMaximized ? '还原窗口' : '最大化'}
            >
              {windowState.isMaximized ? <Minimize2 size={13} /> : <Square size={12} />}
            </button>
            <button
              type="button"
              className="win-btn win-close"
              onClick={onClose}
              title="关闭"
            >
              <X size={14} />
            </button>
          </div>
        )}

        {!windowState.isElectron && (
          <span className="preview-tag desktop-only-control" title="当前在浏览器中运行，桌面打包或 npm start 可使用原生无边框置顶">
            <Maximize2 size={12} />
            <span>Web</span>
          </span>
        )}
      </div>
    </header>
  );
};
