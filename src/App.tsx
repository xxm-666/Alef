import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  CONFUSABLE_GROUPS,
  HEBREW_LETTERS,
  NIQQUD_ITEMS,
} from './data/hebrewLetters';
import { HEBREW_WORDS } from './data/hebrewWords';
import { DEFAULT_DISPLAY_CONFIG } from './data/letterDisplay';
import {
  acceptsWordSpelling, buildDailyPlan, DAILY_VOCABULARY_KEY, DailyVocabularyGroup,
  DailyVocabularyPlan, EMPTY_DAILY_PLAN, hasStartedDailyGroup, isDailyGroupComplete,
  isDailyVocabularyPlan, vocabularyDay,
} from './data/dailyVocabulary';
import {
  AlphabetOrder,
  CustomDisplayConfig,
  ElectronWindowState,
  HebrewWord,
  MasteryLevel,
  StudyStats,
  StudyViewMode,
  ThemeMode,
  WordSrsRecord,
} from './types/hebrew';
import { DEFAULT_WINDOW_STATE, getElectronAPI } from './utils/electronBridge';
import { readStorage, writeStorage, writeStorageBatch } from './utils/storage';
import { useSwipeBack } from './utils/useSwipeBack';
import { TitleBar } from './components/TitleBar';
import { AlphabetGridView } from './components/AlphabetGridView';
import { LetterDetailView } from './components/LetterDetailView';
import { FlashcardStudyView } from './components/FlashcardStudyView';
import { SpecialRulesView } from './components/SpecialRulesView';
import { MiniWidgetView } from './components/MiniWidgetView';
import { WordsStudyView } from './components/WordsStudyView';
import { SettingsView } from './components/SettingsView';
import { BackupModal } from './components/BackupModal';
import { DailyVocabularyEntry, DailyVocabularyView } from './components/DailyVocabularyView';

const NATIVE_TAB_VIEWS = ['words', 'flashcards', 'grid', 'rules', 'settings'] as const;
const iosWindow = window as Window & {
  alefNativeTabs?: boolean;
  webkit?: {
    messageHandlers?: {
      alefViewChanged?: { postMessage: (route: StudyViewMode) => void };
      alefThemeChanged?: { postMessage: (appearance: { background: string; dark: boolean }) => void };
    };
  };
};
const usesNativeTabs = iosWindow.alefNativeTabs === true;
const wordsById = new Map(HEBREW_WORDS.map((word) => [word.id, word]));

const STORAGE_KEYS = {
  displayConfig: 'alef.displayConfig.v1',
  mastery: 'alef.mastery.v1',
  wordMastery: 'alef.wordMastery.v1',
  wordSrs: 'alef.wordSrs.v1',
  favoriteWords: 'alef.favoriteWords.v1',
  studyStats: 'alef.studyStats.v1',
  theme: 'alef.theme.v1',
  dayTheme: 'alef.dayTheme.v1',
  order: 'alef.order.v1',
  speechRate: 'alef.speechRate.v1',
  activeView: 'alef.activeView.v1',
  selectedLetterId: 'alef.selectedLetterId.v1',
};

function shiftCalendarDate(date: Date, days: number): Date {
  const shifted = new Date(date);
  shifted.setDate(shifted.getDate() + days);
  return shifted;
}

function readDailyPlan(fallback = EMPTY_DAILY_PLAN): DailyVocabularyPlan {
  const value = readStorage<unknown>(DAILY_VOCABULARY_KEY, fallback);
  return isDailyVocabularyPlan(value) ? value : fallback;
}

function recordStudyOn(previous: StudyStats, date: Date): StudyStats {
  const today = vocabularyDay(date);
  const sameDay = previous.lastActiveDate === today;
  const consecutive = previous.lastActiveDate === vocabularyDay(shiftCalendarDate(date, -1));
  return {
    streakDays: sameDay ? Math.max(1, previous.streakDays) : consecutive ? previous.streakDays + 1 : 1,
    lastActiveDate: today,
    todayReviews: sameDay ? previous.todayReviews + 1 : 1,
    totalReviews: previous.totalReviews + 1,
  };
}

function scheduleWordReview(previous: Record<string, WordSrsRecord>, wordId: string, level: MasteryLevel, date: Date) {
  const updated = { ...previous };
  if (level === 'unlearned') {
    delete updated[wordId];
  } else {
    const previousInterval = previous[wordId]?.intervalDays ?? 1;
    const intervalDays = level === 'learning' ? 1 : [3, 7, 14, 30].find((days) => days > previousInterval) ?? 30;
    updated[wordId] = { intervalDays, nextReviewAt: shiftCalendarDate(date, intervalDays).getTime() };
  }
  return updated;
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
  const letterDetailReturnView = useRef<StudyViewMode>('grid');
  const letterSwipeBack = useSwipeBack(
    activeView === 'detail' ? () => handleSelectView(letterDetailReturnView.current) : undefined
  );

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
  const [dailyPlan, setDailyPlan] = useState(readDailyPlan);
  const [today, setToday] = useState(vocabularyDay);
  const [dailyOrigin, setDailyOrigin] = useState<'words' | 'flashcards'>();
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
    readStorage(STORAGE_KEYS.theme, 'parchment')
  );
  const lastDayTheme = useRef(readStorage<Exclude<ThemeMode, 'dark'>>(STORAGE_KEYS.dayTheme, 'parchment'));
  const [order, setOrder] = useState<AlphabetOrder>(() =>
    readStorage(STORAGE_KEYS.order, 'rtl')
  );
  const [speechRate, setSpeechRate] = useState<number>(() =>
    readStorage(STORAGE_KEYS.speechRate, 1)
  );

  const [windowState, setWindowState] = useState<ElectronWindowState>(DEFAULT_WINDOW_STATE);

  useEffect(() => {
    const refreshDay = () => setToday(vocabularyDay());
    const timer = window.setInterval(refreshDay, 30_000);
    const syncPlan = (event: StorageEvent) => {
      if (event.key === DAILY_VOCABULARY_KEY || event.key === null) setDailyPlan(readDailyPlan());
      if (event.key === STORAGE_KEYS.wordSrs || event.key === null) setWordSrsMap(readStorage(STORAGE_KEYS.wordSrs, {}));
      if (event.key === STORAGE_KEYS.wordMastery || event.key === null) setWordMasteryMap(readStorage(STORAGE_KEYS.wordMastery, {}));
      if (event.key === STORAGE_KEYS.studyStats) {
        setStudyStats((previous) => readStorage(STORAGE_KEYS.studyStats, previous));
      }
    };
    document.addEventListener('visibilitychange', refreshDay);
    window.addEventListener('storage', syncPlan);
    return () => {
      window.clearInterval(timer);
      document.removeEventListener('visibilitychange', refreshDay);
      window.removeEventListener('storage', syncPlan);
    };
  }, []);

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
    writeStorage(STORAGE_KEYS.theme, theme);
    if (theme !== 'dark') {
      lastDayTheme.current = theme;
      writeStorage(STORAGE_KEYS.dayTheme, theme);
    }
    const background = getComputedStyle(document.documentElement).getPropertyValue('--bg-app').trim();
    document.querySelector('meta[name="theme-color"]')?.setAttribute('content', background);
    if (usesNativeTabs) {
      iosWindow.webkit?.messageHandlers?.alefThemeChanged?.postMessage({ background, dark: theme === 'dark' });
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
    const frame = requestAnimationFrame(() => {
      el.scrollTop = savedTop;
    });
    return () => cancelAnimationFrame(frame);
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
    const date = new Date();
    setStudyStats((previous) => recordStudyOn(previous, date));
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
    const date = new Date();
    setWordSrsMap((previous) => scheduleWordReview(previous, wordId, level, date));
  }

  const plannedToday = useMemo(
    () => buildDailyPlan(dailyPlan, HEBREW_WORDS, wordMasteryMap, wordSrsMap, today),
    [dailyPlan, wordMasteryMap, wordSrsMap, today]
  );

  function saveDailyPlan(plan: DailyVocabularyPlan) {
    writeStorage(DAILY_VOCABULARY_KEY, plan);
    setDailyPlan(plan);
  }

  function refreshDailyPlan() {
    const day = vocabularyDay();
    setToday(day);
    const saved = readDailyPlan(dailyPlan);
    const plan = buildDailyPlan(saved, HEBREW_WORDS, wordMasteryMap, wordSrsMap, day);
    if (plan !== saved) saveDailyPlan(plan);
    else setDailyPlan(plan);
  }

  function openDailyVocabulary(from: 'words' | 'flashcards') {
    refreshDailyPlan();
    handleSelectView('words');
    setDailyOrigin(from);
    requestAnimationFrame(() => {
      mainScrollRef.current?.scrollTo({ top: 0 });
      document.getElementById('daily-vocabulary-heading')?.focus({ preventScroll: true });
    });
  }

  function changeDailyLimit(groupsPerDay: number) {
    const saved = readDailyPlan(dailyPlan);
    const day = vocabularyDay();
    const current = buildDailyPlan(saved, HEBREW_WORDS, wordMasteryMap, wordSrsMap, day);
    if (current.groupsPerDay === groupsPerDay) return;
    const adjusted = { ...current, groupsPerDay };
    saveDailyPlan(current.groups.some(hasStartedDailyGroup) ? adjusted : buildDailyPlan(
      { ...adjusted, day: '', groups: [] }, HEBREW_WORDS, wordMasteryMap, wordSrsMap, day
    ));
  }

  function updatedDailyPlan(expected: DailyVocabularyGroup, change: (group: DailyVocabularyGroup) => DailyVocabularyGroup | null) {
    const current = readDailyPlan(dailyPlan);
    const index = current.groups.findIndex((group) => !isDailyGroupComplete(group));
    const group = current.groups[index];
    if (current.day !== dailyPlan.day || !group || group.wordIds.length !== expected.wordIds.length ||
        !group.wordIds.every((id, index) => id === expected.wordIds[index]) ||
        group.studied !== expected.studied || group.answers.length !== expected.answers.length ||
        group.feedbackPending !== expected.feedbackPending) {
      setDailyPlan(current);
      return null;
    }
    const updated = change(group);
    return updated ? { ...current, groups: current.groups.map((item, offset) => offset === index ? updated : item) } : null;
  }

  function advanceDailyGroup(expected: DailyVocabularyGroup) {
    const updated = updatedDailyPlan(expected, (group) => {
      if (group.studied < group.wordIds.length) return { ...group, studied: group.studied + 1 };
      return group.feedbackPending ? { ...group, feedbackPending: false } : null;
    });
    if (!updated) return false;
    saveDailyPlan(updated);
    return true;
  }

  function answerDailyWord(expected: DailyVocabularyGroup, word: HebrewWord, input: string) {
    const answer = { input: input.trim(), correct: acceptsWordSpelling(word, input) };
    if (!answer.input) return null;
    const updated = updatedDailyPlan(expected, (group) =>
      !group.feedbackPending && group.studied === group.wordIds.length && group.wordIds[group.answers.length] === word.id
        ? { ...group, answers: [...group.answers, answer], feedbackPending: true } : null
    );
    if (!updated) return null;
    const date = new Date();
    const level = answer.correct ? 'mastered' : 'learning';
    const mastery: Record<string, MasteryLevel> = { ...readStorage(STORAGE_KEYS.wordMastery, wordMasteryMap), [word.id]: level };
    const schedule = scheduleWordReview(readStorage(STORAGE_KEYS.wordSrs, wordSrsMap), word.id, level, date);
    const stats = recordStudyOn(readStorage(STORAGE_KEYS.studyStats, studyStats), date);
    if (!writeStorageBatch([
      [STORAGE_KEYS.wordMastery, mastery], [STORAGE_KEYS.wordSrs, schedule],
      [STORAGE_KEYS.studyStats, stats], [DAILY_VOCABULARY_KEY, updated],
    ])) throw new Error('Daily vocabulary storage write failed.');
    setWordMasteryMap(mastery);
    setWordSrsMap(schedule);
    setStudyStats(stats);
    setDailyPlan(updated);
    return answer;
  }

  const handleSelectView = useCallback((nextView: StudyViewMode) => {
    setDailyOrigin(undefined);
    if (nextView === 'detail' && activeView !== 'detail') {
      letterDetailReturnView.current = activeView;
    }
    if (mainScrollRef.current) {
      viewScrollPositionsRef.current[activeView] = mainScrollRef.current.scrollTop;
    }
    setActiveView(nextView);
  }, [activeView]);

  useEffect(() => {
    if (!usesNativeTabs) return;
    function handleNativeTab(event: Event) {
      const route: unknown = (event as CustomEvent).detail;
      const tab = NATIVE_TAB_VIEWS.find((view) => view === route);
      if (tab) handleSelectView(tab);
    }
    window.addEventListener('alef-native-tab', handleNativeTab);
    return () => window.removeEventListener('alef-native-tab', handleNativeTab);
  }, [handleSelectView]);

  useEffect(() => {
    if (usesNativeTabs) {
      iosWindow.webkit?.messageHandlers?.alefViewChanged?.postMessage(activeView);
    }
  }, [activeView]);

  function handleOpenDetail(letterId: string) {
    viewScrollPositionsRef.current.detail = 0;
    setSelectedLetterId(letterId);
    handleSelectView('detail');
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
      className={usesNativeTabs ? 'app-root native-ios-tabs' : 'app-root'}
      style={!windowState.isElectron && windowState.opacity < 1 ? { opacity: windowState.opacity } : undefined}
    >
      {!usesNativeTabs && <TitleBar
        activeView={activeView}
        onSelectView={handleSelectView}
        theme={theme}
        onToggleTheme={() => setTheme((t) => (t === 'dark' ? lastDayTheme.current : 'dark'))}
        windowState={windowState}
        onToggleAlwaysOnTop={handleToggleAlwaysOnTop}
        onToggleMiniMode={handleToggleMiniMode}
        onChangeOpacity={handleChangeOpacity}
        onMinimize={handleMinimize}
        onMaximize={handleMaximize}
        onClose={handleClose}
        onOpenBackup={() => setIsBackupOpen(true)}
      />}

      <main ref={mainScrollRef} className="main-scroll-area" {...letterSwipeBack}>
        {activeView === 'grid' && (
          <AlphabetGridView
            letters={HEBREW_LETTERS}
            displayConfig={displayConfig}
            order={order}
            masteryMap={masteryMap}
            onCycleMastery={handleCycleMastery}
            onSelectLetter={handleOpenDetail}
            speechRate={speechRate}
          />
        )}

        {activeView === 'detail' && (
          <LetterDetailView
            letters={HEBREW_LETTERS}
            selectedLetter={selectedLetter}
            onSelectLetter={setSelectedLetterId}
            onBackToGrid={() => handleSelectView('grid')}
            order={order}
            masteryMap={masteryMap}
            onSetMastery={handleSetMastery}
            speechRate={speechRate}
          />
        )}

        {activeView === 'words' && dailyOrigin && (
          <DailyVocabularyView
            plan={dailyPlan}
            words={wordsById}
            speechRate={speechRate}
            onExit={() => handleSelectView(dailyOrigin)}
            onReturnToPlan={refreshDailyPlan}
            onSetLimit={changeDailyLimit}
            onAdvance={advanceDailyGroup}
            onAnswer={answerDailyWord}
          />
        )}

        {activeView === 'words' && !dailyOrigin && (
          <WordsStudyView
            dailyEntry={<DailyVocabularyEntry plan={plannedToday} onOpen={() => openDailyVocabulary('words')} />}
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
            dailyEntry={<DailyVocabularyEntry plan={plannedToday} onOpen={() => openDailyVocabulary('flashcards')} />}
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
