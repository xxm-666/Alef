import React, { useEffect, useMemo, useRef, useState } from 'react';
import {
  CONFUSABLE_GROUPS,
  HEBREW_LETTERS,
  NIQQUD_ITEMS,
} from './data/hebrewLetters';
import { HEBREW_WORDS } from './data/hebrewWords';
import {
  AlphabetOrder,
  CustomDisplayConfig,
  ElectronWindowState,
  MasteryLevel,
  StudyStats,
  StudyViewMode,
  ThemeMode,
  WordSrsRecord,
} from './types/hebrew';
import { DEFAULT_WINDOW_STATE, getElectronAPI } from './utils/electronBridge';
import { readStorage, writeStorage } from './utils/storage';
import { TitleBar } from './components/TitleBar';
import { AlphabetGridView } from './components/AlphabetGridView';
import { LetterDetailView } from './components/LetterDetailView';
import { FlashcardStudyView } from './components/FlashcardStudyView';
import { SpecialRulesView } from './components/SpecialRulesView';
import { MiniWidgetView } from './components/MiniWidgetView';
import { WordsStudyView } from './components/WordsStudyView';
import { SettingsView } from './components/SettingsView';
import { BackupModal } from './components/BackupModal';

const STORAGE_KEYS = {
  displayConfig: 'alef.displayConfig.v1',
  mastery: 'alef.mastery.v1',
  wordMastery: 'alef.wordMastery.v1',
  wordSrs: 'alef.wordSrs.v1',
  favoriteWords: 'alef.favoriteWords.v1',
  studyStats: 'alef.studyStats.v1',
  theme: 'alef.theme.v1',
  order: 'alef.order.v1',
  speechRate: 'alef.speechRate.v1',
  activeView: 'alef.activeView.v1',
  selectedLetterId: 'alef.selectedLetterId.v1',
};

const DEFAULT_DISPLAY_CONFIG: CustomDisplayConfig = {
  showBlock: true,
  showCursive: true,
  showSofit: true,
  showBegadkefat: true,
  showHebrewName: true,
  showEnglishName: true,
  showChineseName: true,
  showModernSound: true,
  showBiblicalDiff: false,
  showTransliteration: true,
  showGematria: true,
  showMastery: true,
  showCategoryBadges: false,
};

function getLocalDateKey(offsetDays = 0): string {
  const d = new Date(Date.now() + offsetDays * 86_400_000);
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

export const App: React.FC = () => {
  const [activeView, setActiveView] = useState<StudyViewMode>(() =>
    readStorage<StudyViewMode>(STORAGE_KEYS.activeView, 'grid')
  );
  const [selectedLetterId, setSelectedLetterId] = useState<string>(() =>
    readStorage<string>(STORAGE_KEYS.selectedLetterId, HEBREW_LETTERS[0].id)
  );
  const mainScrollRef = useRef<HTMLElement | null>(null);
  const viewScrollPositionsRef = useRef<Partial<Record<StudyViewMode, number>>>({});

  const [displayConfig, setDisplayConfig] = useState<CustomDisplayConfig>(() =>
    readStorage(STORAGE_KEYS.displayConfig, DEFAULT_DISPLAY_CONFIG)
  );
  const [masteryMap, setMasteryMap] = useState<Record<string, MasteryLevel>>(() =>
    readStorage(STORAGE_KEYS.mastery, {})
  );
  const [wordMasteryMap, setWordMasteryMap] = useState<Record<string, MasteryLevel>>(() =>
    readStorage(STORAGE_KEYS.wordMastery, {})
  );
  const [wordSrsMap, setWordSrsMap] = useState<Record<string, WordSrsRecord>>(() =>
    readStorage(STORAGE_KEYS.wordSrs, {})
  );
  const [favoriteWordIds, setFavoriteWordIds] = useState<string[]>(() =>
    readStorage<string[]>(STORAGE_KEYS.favoriteWords, [])
  );
  const [studyStats, setStudyStats] = useState<StudyStats>(() =>
    readStorage<StudyStats>(STORAGE_KEYS.studyStats, {
      streakDays: 0,
      lastActiveDate: '',
      todayReviews: 0,
      totalReviews: 0,
    })
  );
  const [isBackupOpen, setIsBackupOpen] = useState(false);
  const [theme, setTheme] = useState<ThemeMode>(() =>
    readStorage(STORAGE_KEYS.theme, 'dark')
  );
  const [order, setOrder] = useState<AlphabetOrder>(() =>
    readStorage(STORAGE_KEYS.order, 'rtl')
  );
  const [speechRate, setSpeechRate] = useState<number>(() =>
    readStorage(STORAGE_KEYS.speechRate, 1)
  );

  const [windowState, setWindowState] = useState<ElectronWindowState>(DEFAULT_WINDOW_STATE);

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem(STORAGE_KEYS.theme, JSON.stringify(theme));
    const themeMeta = document.querySelector('meta[name="theme-color"]');
    if (themeMeta) {
      themeMeta.setAttribute('content', theme === 'dark' ? '#0b1120' : '#fbf8f1');
    }
  }, [theme]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.displayConfig, JSON.stringify(displayConfig));
  }, [displayConfig]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.mastery, JSON.stringify(masteryMap));
  }, [masteryMap]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.wordMastery, JSON.stringify(wordMasteryMap));
  }, [wordMasteryMap]);

  useEffect(() => {
    writeStorage(STORAGE_KEYS.wordSrs, wordSrsMap);
  }, [wordSrsMap]);

  useEffect(() => {
    writeStorage(STORAGE_KEYS.favoriteWords, favoriteWordIds);
  }, [favoriteWordIds]);

  useEffect(() => {
    writeStorage(STORAGE_KEYS.studyStats, studyStats);
  }, [studyStats]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.order, JSON.stringify(order));
  }, [order]);

  useEffect(() => {
    writeStorage(STORAGE_KEYS.speechRate, speechRate);
  }, [speechRate]);

  useEffect(() => {
    writeStorage(STORAGE_KEYS.activeView, activeView);
    const el = mainScrollRef.current;
    if (!el) return;
    const savedTop = viewScrollPositionsRef.current[activeView] ?? 0;
    requestAnimationFrame(() => {
      if (mainScrollRef.current) {
        mainScrollRef.current.scrollTop = savedTop;
      }
    });
  }, [activeView]);

  useEffect(() => {
    writeStorage(STORAGE_KEYS.selectedLetterId, selectedLetterId);
  }, [selectedLetterId]);

  useEffect(() => {
    const api = getElectronAPI();
    if (!api) return;
    let active = true;
    void api.getState().then((state) => {
      if (active) setWindowState(state);
    });
    const unsubscribe = api.onStateChange((state) => {
      setWindowState(state);
    });
    return () => {
      active = false;
      unsubscribe();
    };
  }, []);

  const selectedLetter = useMemo(
    () => HEBREW_LETTERS.find((l) => l.id === selectedLetterId) ?? HEBREW_LETTERS[0],
    [selectedLetterId]
  );

  const masteredCount = useMemo(
    () =>
      HEBREW_LETTERS.filter((l) => masteryMap[l.id] === 'mastered').length,
    [masteryMap]
  );

  function recordStudyActivity() {
    const today = getLocalDateKey(0);
    const yesterday = getLocalDateKey(-1);
    setStudyStats((prev) => {
      const isSameDay = prev.lastActiveDate === today;
      const isConsecutive = prev.lastActiveDate === yesterday;
      const nextStreak = isSameDay
        ? Math.max(1, prev.streakDays)
        : isConsecutive
        ? prev.streakDays + 1
        : 1;
      return {
        streakDays: nextStreak,
        lastActiveDate: today,
        todayReviews: isSameDay ? prev.todayReviews + 1 : 1,
        totalReviews: prev.totalReviews + 1,
      };
    });
  }

  function handleToggleFavoriteWord(wordId: string) {
    setFavoriteWordIds((prev) =>
      prev.includes(wordId) ? prev.filter((id) => id !== wordId) : [...prev, wordId]
    );
  }

  function handleCycleMastery(letterId: string) {
    recordStudyActivity();
    setMasteryMap((prev) => {
      const curr = prev[letterId] ?? 'unlearned';
      const next: MasteryLevel =
        curr === 'unlearned'
          ? 'learning'
          : curr === 'learning'
          ? 'mastered'
          : 'unlearned';
      return { ...prev, [letterId]: next };
    });
  }

  function handleSetMastery(letterId: string, level: MasteryLevel) {
    recordStudyActivity();
    setMasteryMap((prev) => ({ ...prev, [letterId]: level }));
  }

  function handleSetWordMastery(wordId: string, level: MasteryLevel) {
    recordStudyActivity();
    setWordMasteryMap((prev) => ({ ...prev, [wordId]: level }));
    const now = Date.now();
    const DAY_MS = 86_400_000;
    setWordSrsMap((prev) => {
      if (level === 'unlearned') {
        const next = { ...prev };
        delete next[wordId];
        return next;
      }
      if (level === 'learning') {
        return {
          ...prev,
          [wordId]: { intervalDays: 1, nextReviewAt: now + DAY_MS },
        };
      }
      const prevDays = prev[wordId]?.intervalDays ?? 1;
      const nextDays = prevDays < 3 ? 3 : prevDays < 7 ? 7 : prevDays < 14 ? 14 : 30;
      return {
        ...prev,
        [wordId]: { intervalDays: nextDays, nextReviewAt: now + nextDays * DAY_MS },
      };
    });
  }

  function handleSelectView(nextView: StudyViewMode) {
    if (mainScrollRef.current) {
      viewScrollPositionsRef.current[activeView] = mainScrollRef.current.scrollTop;
    }
    setActiveView(nextView);
  }

  function handleOpenDetail(letterId: string) {
    if (mainScrollRef.current) {
      viewScrollPositionsRef.current[activeView] = mainScrollRef.current.scrollTop;
    }
    setSelectedLetterId(letterId);
    setActiveView('detail');
  }

  async function handleToggleAlwaysOnTop() {
    const api = getElectronAPI();
    if (api) {
      const state = await api.toggleAlwaysOnTop();
      setWindowState(state);
    } else {
      setWindowState((prev) => ({ ...prev, isAlwaysOnTop: !prev.isAlwaysOnTop }));
    }
  }

  async function handleToggleMiniMode() {
    const api = getElectronAPI();
    if (api) {
      const state = await api.setMiniMode(!windowState.isMiniMode);
      setWindowState(state);
    } else {
      setWindowState((prev) => ({ ...prev, isMiniMode: !prev.isMiniMode }));
    }
  }

  async function handleChangeOpacity(opacity: number) {
    const api = getElectronAPI();
    if (api) {
      const state = await api.setOpacity(opacity);
      setWindowState(state);
    } else {
      setWindowState((prev) => ({ ...prev, opacity }));
    }
  }

  function handleMinimize() {
    void getElectronAPI()?.minimize();
  }

  async function handleMaximize() {
    const state = await getElectronAPI()?.maximize();
    if (state) setWindowState(state);
  }

  function handleClose() {
    void getElectronAPI()?.close();
  }

  if (windowState.isMiniMode) {
    return (
      <div
        className={`app-root mini-mode ${!windowState.isElectron ? 'web-mini-frame' : ''}`}
        style={!windowState.isElectron ? { opacity: windowState.opacity } : undefined}
      >
        <MiniWidgetView
          letters={HEBREW_LETTERS}
          selectedLetter={selectedLetter}
          onSelectLetter={setSelectedLetterId}
          order={order}
          windowState={windowState}
          onExitMiniMode={handleToggleMiniMode}
          onToggleAlwaysOnTop={handleToggleAlwaysOnTop}
          onChangeOpacity={handleChangeOpacity}
          onClose={handleClose}
          speechRate={speechRate}
        />
      </div>
    );
  }

  return (
    <div
      className="app-root"
      style={!windowState.isElectron && windowState.opacity < 1 ? { opacity: windowState.opacity } : undefined}
    >
      <TitleBar
        activeView={activeView}
        onSelectView={handleSelectView}
        theme={theme}
        onToggleTheme={() => setTheme((t) => (t === 'dark' ? 'parchment' : 'dark'))}
        windowState={windowState}
        onToggleAlwaysOnTop={handleToggleAlwaysOnTop}
        onToggleMiniMode={handleToggleMiniMode}
        onChangeOpacity={handleChangeOpacity}
        onMinimize={handleMinimize}
        onMaximize={handleMaximize}
        onClose={handleClose}
        onOpenBackup={() => setIsBackupOpen(true)}
      />

      <main ref={mainScrollRef} className="main-scroll-area">
        {activeView === 'grid' && (
          <AlphabetGridView
            letters={HEBREW_LETTERS}
            displayConfig={displayConfig}
            onUpdateDisplayConfig={setDisplayConfig}
            order={order}
            onToggleOrder={() => setOrder((o) => (o === 'rtl' ? 'ltr' : 'rtl'))}
            masteryMap={masteryMap}
            onCycleMastery={handleCycleMastery}
            onSelectLetter={handleOpenDetail}
            speechRate={speechRate}
            onChangeSpeechRate={setSpeechRate}
          />
        )}

        {activeView === 'detail' && (
          <LetterDetailView
            letters={HEBREW_LETTERS}
            selectedLetter={selectedLetter}
            onSelectLetter={setSelectedLetterId}
            order={order}
            masteryMap={masteryMap}
            onSetMastery={handleSetMastery}
            speechRate={speechRate}
          />
        )}

        {activeView === 'words' && (
          <WordsStudyView
            words={HEBREW_WORDS}
            letters={HEBREW_LETTERS}
            wordMasteryMap={wordMasteryMap}
            wordSrsMap={wordSrsMap}
            favoriteWordIds={favoriteWordIds}
            onToggleFavoriteWord={handleToggleFavoriteWord}
            onSetWordMastery={handleSetWordMastery}
            onRecordActivity={recordStudyActivity}
            onOpenLetterDetail={handleOpenDetail}
            speechRate={speechRate}
          />
        )}

        {activeView === 'flashcards' && (
          <FlashcardStudyView
            letters={HEBREW_LETTERS}
            masteryMap={masteryMap}
            onSetMastery={handleSetMastery}
            onOpenDetail={handleOpenDetail}
            speechRate={speechRate}
          />
        )}

        {activeView === 'rules' && (
          <SpecialRulesView
            letters={HEBREW_LETTERS}
            confusableGroups={CONFUSABLE_GROUPS}
            niqqudList={NIQQUD_ITEMS}
            onSelectLetter={handleOpenDetail}
            speechRate={speechRate}
          />
        )}

        {activeView === 'settings' && (
          <SettingsView
            theme={theme}
            onSelectTheme={setTheme}
            order={order}
            onToggleOrder={() => setOrder((o) => (o === 'rtl' ? 'ltr' : 'rtl'))}
            speechRate={speechRate}
            onChangeSpeechRate={setSpeechRate}
            displayConfig={displayConfig}
            onUpdateDisplayConfig={setDisplayConfig}
            onResetDisplayConfig={() => setDisplayConfig(DEFAULT_DISPLAY_CONFIG)}
            onOpenBackup={() => setIsBackupOpen(true)}
            masteredLettersCount={masteredCount}
            totalLettersCount={HEBREW_LETTERS.length}
            masteredWordsCount={Object.values(wordMasteryMap).filter((v) => v === 'mastered').length}
            totalWordsCount={HEBREW_WORDS.length}
            studyStats={studyStats}
            windowState={windowState}
            onToggleAlwaysOnTop={handleToggleAlwaysOnTop}
            onToggleMiniMode={handleToggleMiniMode}
            onChangeOpacity={handleChangeOpacity}
          />
        )}
      </main>

      <BackupModal
        isOpen={isBackupOpen}
        onClose={() => setIsBackupOpen(false)}
        lettersMastered={masteredCount}
        wordsMastered={Object.values(wordMasteryMap).filter((v) => v === 'mastered').length}
        srsCount={Object.keys(wordSrsMap).length}
      />
    </div>
  );
};

export default App;
