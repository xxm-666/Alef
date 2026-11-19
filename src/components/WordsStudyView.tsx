import React, { useEffect, useMemo, useRef, useState } from 'react';
import {
  ArrowDown,
  ArrowUp,
  ArrowUpDown,
  BookOpen,
  CheckCircle2,
  ChevronLeft,
  ChevronRight,
  Circle,
  Clock,
  Delete,
  Eye,
  EyeOff,
  HelpCircle,
  LayoutGrid,
  Layers,
  MessageSquare,
  Search,
  Sparkles,
  Star,
  Volume2,
} from 'lucide-react';
import {
  HebrewLetter,
  HebrewWord,
  MasteryLevel,
  WordCategory,
  WordSrsRecord,
} from '../types/hebrew';
import { WORD_CATEGORY_META } from '../data/hebrewWords';
import { WORD_INFLECTIONS } from '../data/wordInflections';
import { HEBREW_PHRASES, PHRASE_SCENARIO_META, PhraseScenario } from '../data/hebrewPhrases';
import { playFeedbackTone, speakHebrew } from '../utils/audio';
import { readStorage, writeStorage } from '../utils/storage';

interface WordsStudyViewProps {
  words: HebrewWord[];
  letters: HebrewLetter[];
  wordMasteryMap: Record<string, MasteryLevel>;
  wordSrsMap: Record<string, WordSrsRecord>;
  favoriteWordIds: string[];
  onToggleFavoriteWord: (wordId: string) => void;
  onSetWordMastery: (wordId: string, level: MasteryLevel) => void;
  onRecordActivity: () => void;
  onOpenLetterDetail: (letterId: string) => void;
  speechRate: number;
}

type WordFilter = 'all' | 'favorites' | 'needs_review' | 'due_srs' | WordCategory;
type WordsMode = 'browse' | 'cards' | 'phrases' | 'quiz';
type WordQuizKind = 'meaning' | 'listening' | 'spelling';
type WordSortOrder = 'default' | 'alpha';

const HEBREW_KEYBOARD_LETTERS = [
  'א', 'ב', 'ג', 'ד', 'ה', 'ו', 'ז', 'ח', 'ט', 'י', 'כ', 'ך',
  'ל', 'מ', 'ם', 'נ', 'ן', 'ס', 'ע', 'פ', 'ף', 'צ', 'ץ', 'ק', 'ר', 'ש', 'ת',
];

const ROW_HEIGHT = 72;
const ROW_GAP = 6;
const ROW_STRIDE = ROW_HEIGHT + ROW_GAP;
const OVERSCAN = 6;
const CARDS_PAGE_SIZE = 24;

const MASTERY_OPTIONS: { level: MasteryLevel; label: string; icon: React.ReactNode }[] = [
  { level: 'unlearned', label: '未学', icon: <Circle size={14} /> },
  { level: 'learning', label: '学习中', icon: <Clock size={14} /> },
  { level: 'mastered', label: '已掌握', icon: <CheckCircle2 size={14} /> },
];

const SOFIT_TO_MEDIAL: Record<string, string> = {
  'ך': 'כ',
  'ם': 'מ',
  'ן': 'נ',
  'ף': 'פ',
  'ץ': 'צ',
};

function getInitialHebrewChar(word: HebrewWord): string {
  for (const ch of Array.from(word.hebrewUnpointed)) {
    if (/[\u05D0-\u05EA]/.test(ch)) {
      return SOFIT_TO_MEDIAL[ch] ?? ch;
    }
  }
  return '';
}

interface BreakdownChar {
  char: string;
  isSofit: boolean;
  letter?: HebrewLetter;
}

function buildLetterBreakdown(hebrewText: string, letters: HebrewLetter[]): BreakdownChar[] {
  const result: BreakdownChar[] = [];
  for (const ch of Array.from(hebrewText)) {
    if (!/[\u05D0-\u05EA]/.test(ch)) continue;
    const matched = letters.find((l) => l.hebrew === ch || l.sofit === ch);
    result.push({
      char: ch,
      isSofit: Boolean(matched && matched.sofit === ch),
      letter: matched,
    });
  }
  return result;
}

function pickQuizOptions(target: HebrewWord, pool: HebrewWord[]): HebrewWord[] {
  const distractors = pool
    .filter((w) => w.id !== target.id)
    .sort(() => Math.random() - 0.5)
    .slice(0, 3);
  return [target, ...distractors].sort(() => Math.random() - 0.5);
}

interface PersistedWordsState {
  searchQuery: string;
  activeFilter: WordFilter;
  initialLetter: string;
  sortOrder: WordSortOrder;
  showNiqqud: boolean;
  showCursive: boolean;
  mode: WordsMode;
  mobileSubView: 'list' | 'detail';
  selectedWordId: string;
  cardsPage: number;
  scrollTop: number;
}

const WORDS_STATE_KEY = 'alef.wordsState.v1';

export const WordsStudyView: React.FC<WordsStudyViewProps> = ({
  words,
  letters,
  wordMasteryMap,
  wordSrsMap,
  favoriteWordIds,
  onToggleFavoriteWord,
  onSetWordMastery,
  onRecordActivity,
  onOpenLetterDetail,
  speechRate,
}) => {
  const initialSaved = useMemo(
    () =>
      readStorage<PersistedWordsState>(WORDS_STATE_KEY, {
        searchQuery: '',
        activeFilter: 'all',
        initialLetter: 'all',
        sortOrder: 'default',
        showNiqqud: true,
        showCursive: true,
        mode: 'browse',
        mobileSubView: 'list',
        selectedWordId: words[0]?.id ?? '',
        cardsPage: 1,
        scrollTop: 0,
      }),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    []
  );

  const [searchQuery, setSearchQuery] = useState(initialSaved.searchQuery);
  const [activeFilter, setActiveFilter] = useState<WordFilter>(initialSaved.activeFilter);
  const [initialLetter, setInitialLetter] = useState<string>(initialSaved.initialLetter);
  const [sortOrder, setSortOrder] = useState<WordSortOrder>(initialSaved.sortOrder);
  const [showNiqqud, setShowNiqqud] = useState(initialSaved.showNiqqud);
  const [showCursive, setShowCursive] = useState(initialSaved.showCursive);
  const [mode, setMode] = useState<WordsMode>(initialSaved.mode);
  const [mobileSubView, setMobileSubView] = useState<'list' | 'detail'>(
    initialSaved.mobileSubView ?? 'list'
  );
  const [selectedWordId, setSelectedWordId] = useState<string>(initialSaved.selectedWordId);
  const [cardsPage, setCardsPage] = useState(initialSaved.cardsPage);

  // Virtual list state
  const listScrollRef = useRef<HTMLDivElement | null>(null);
  const [scrollTop, setScrollTop] = useState(initialSaved.scrollTop);
  const [viewportHeight, setViewportHeight] = useState(520);
  const didMountFiltersRef = useRef(false);

  // Quiz state
  const [quizKind, setQuizKind] = useState<WordQuizKind>('meaning');
  const [quizTargetId, setQuizTargetId] = useState<string>(words[0]?.id ?? '');
  const [quizOptions, setQuizOptions] = useState<HebrewWord[]>(() =>
    words.length >= 4 ? pickQuizOptions(words[0], words) : words
  );
  const [selectedOptionId, setSelectedOptionId] = useState<string | null>(null);
  const [quizScore, setQuizScore] = useState({ correct: 0, total: 0 });
  const [spellingInput, setSpellingInput] = useState('');
  const [spellingSubmitted, setSpellingSubmitted] = useState(false);

  // Phrases state
  const [phraseScenario, setPhraseScenario] = useState<'all' | PhraseScenario>('all');
  const [hidePhraseZh, setHidePhraseZh] = useState(false);

  const dueSrsCount = useMemo(() => {
    const now = Date.now();
    return words.filter((w) => {
      const rec = wordSrsMap[w.id];
      return Boolean(rec && rec.nextReviewAt <= now);
    }).length;
  }, [words, wordSrsMap]);

  const categoryCounts = useMemo(() => {
    const counts: Record<string, number> = {};
    for (const w of words) {
      counts[w.category] = (counts[w.category] ?? 0) + 1;
    }
    return counts;
  }, [words]);

  const favoriteSet = useMemo(() => new Set(favoriteWordIds), [favoriteWordIds]);

  const filteredWords = useMemo(() => {
    const q = searchQuery.trim().toLowerCase();
    const list = words.filter((word) => {
      const mastery = wordMasteryMap[word.id] ?? 'unlearned';
      if (activeFilter === 'favorites' && !favoriteSet.has(word.id)) return false;
      if (activeFilter === 'needs_review' && mastery === 'mastered') return false;
      if (activeFilter === 'due_srs') {
        const rec = wordSrsMap[word.id];
        if (!rec || rec.nextReviewAt > Date.now()) return false;
      }
      if (
        activeFilter !== 'all' &&
        activeFilter !== 'favorites' &&
        activeFilter !== 'needs_review' &&
        activeFilter !== 'due_srs' &&
        word.category !== activeFilter
      ) {
        return false;
      }
      if (initialLetter !== 'all' && getInitialHebrewChar(word) !== initialLetter) {
        return false;
      }

      if (!q) return true;
      return (
        word.hebrew.includes(q) ||
        word.hebrewUnpointed.includes(q) ||
        word.transliteration.toLowerCase().includes(q) ||
        word.meaningZh.toLowerCase().includes(q) ||
        (word.root && word.root.includes(q))
      );
    });

    if (sortOrder === 'alpha') {
      return [...list].sort((a, b) =>
        a.hebrewUnpointed.localeCompare(b.hebrewUnpointed, 'he')
      );
    }
    return list;
  }, [words, activeFilter, initialLetter, searchQuery, wordMasteryMap, wordSrsMap, favoriteSet, sortOrder]);

  useEffect(() => {
    if (!didMountFiltersRef.current) {
      didMountFiltersRef.current = true;
      return;
    }
    setCardsPage(1);
    setScrollTop(0);
    if (listScrollRef.current) {
      listScrollRef.current.scrollTop = 0;
    }
  }, [activeFilter, initialLetter, searchQuery, sortOrder]);

  // Restore saved virtual list scrollTop when entering browse mode
  useEffect(() => {
    if (mode !== 'browse') return;
    const el = listScrollRef.current;
    if (!el) return;
    requestAnimationFrame(() => {
      if (listScrollRef.current) {
        listScrollRef.current.scrollTop = scrollTop;
      }
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [mode]);

  // Persist view state across tab switches and restarts (debounce scrollTop to keep scrolling smooth)
  const scrollTopRef = useRef(scrollTop);
  scrollTopRef.current = scrollTop;

  useEffect(() => {
    writeStorage<PersistedWordsState>(WORDS_STATE_KEY, {
      searchQuery,
      activeFilter,
      initialLetter,
      sortOrder,
      showNiqqud,
      showCursive,
      mode,
      mobileSubView,
      selectedWordId,
      cardsPage,
      scrollTop: scrollTopRef.current,
    });
  }, [
    searchQuery,
    activeFilter,
    initialLetter,
    sortOrder,
    showNiqqud,
    showCursive,
    mode,
    mobileSubView,
    selectedWordId,
    cardsPage,
  ]);

  useEffect(() => {
    const timer = window.setTimeout(() => {
      writeStorage<PersistedWordsState>(WORDS_STATE_KEY, {
        searchQuery,
        activeFilter,
        initialLetter,
        sortOrder,
        showNiqqud,
        showCursive,
        mode,
        mobileSubView,
        selectedWordId,
        cardsPage,
        scrollTop,
      });
    }, 250);
    return () => window.clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [scrollTop]);

  useEffect(() => {
    const el = listScrollRef.current;
    if (!el) return;
    const updateSize = () => setViewportHeight(el.clientHeight || 520);
    updateSize();
    const observer = new ResizeObserver(updateSize);
    observer.observe(el);
    return () => observer.disconnect();
  }, [mode, filteredWords.length]);

  const selectedWord = useMemo(() => {
    const inFiltered = filteredWords.find((w) => w.id === selectedWordId);
    if (inFiltered) return inFiltered;
    return filteredWords[0] ?? words.find((w) => w.id === selectedWordId) ?? words[0];
  }, [filteredWords, selectedWordId, words]);

  const masteredWordsCount = useMemo(
    () => words.filter((w) => wordMasteryMap[w.id] === 'mastered').length,
    [words, wordMasteryMap]
  );

  const selectedIndex = filteredWords.findIndex((w) => w.id === selectedWord?.id);

  function selectAndScrollToIndex(idx: number) {
    if (filteredWords.length === 0) return;
    const safeIdx = Math.max(0, Math.min(filteredWords.length - 1, idx));
    setSelectedWordId(filteredWords[safeIdx].id);
    const el = listScrollRef.current;
    if (!el) return;
    const itemTop = safeIdx * ROW_STRIDE;
    const itemBottom = itemTop + ROW_HEIGHT;
    if (itemTop < el.scrollTop) {
      el.scrollTop = itemTop;
    } else if (itemBottom > el.scrollTop + el.clientHeight) {
      el.scrollTop = itemBottom - el.clientHeight;
    }
  }

  useEffect(() => {
    if (mode !== 'browse' || filteredWords.length === 0) return;
    function handleKeyDown(e: KeyboardEvent) {
      if (
        e.target instanceof HTMLInputElement ||
        e.target instanceof HTMLTextAreaElement
      ) {
        return;
      }
      if (e.key === 'ArrowDown') {
        e.preventDefault();
        const nextIdx = selectedIndex < filteredWords.length - 1 ? selectedIndex + 1 : 0;
        selectAndScrollToIndex(nextIdx);
      } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        const prevIdx = selectedIndex > 0 ? selectedIndex - 1 : filteredWords.length - 1;
        selectAndScrollToIndex(prevIdx);
      }
    }
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  });

  const breakdown = useMemo(
    () => (selectedWord ? buildLetterBreakdown(selectedWord.hebrewUnpointed, letters) : []),
    [selectedWord, letters]
  );

  const rootSiblings = useMemo(() => {
    if (!selectedWord?.root) return [];
    return words.filter((w) => w.id !== selectedWord.id && w.root === selectedWord.root);
  }, [selectedWord, words]);

  const wordInflection = selectedWord ? WORD_INFLECTIONS[selectedWord.id] : undefined;

  const filteredPhrases = useMemo(() => {
    if (phraseScenario === 'all') return HEBREW_PHRASES;
    return HEBREW_PHRASES.filter((p) => p.scenario === phraseScenario);
  }, [phraseScenario]);

  // Virtual window calculation
  const totalHeight = filteredWords.length * ROW_STRIDE;
  const startIndex = Math.max(0, Math.floor(scrollTop / ROW_STRIDE) - OVERSCAN);
  const endIndex = Math.min(
    filteredWords.length,
    Math.ceil((scrollTop + viewportHeight) / ROW_STRIDE) + OVERSCAN
  );
  const visibleSlice = filteredWords.slice(startIndex, endIndex);

  // Pagination for Cards Wall
  const totalPages = Math.max(1, Math.ceil(filteredWords.length / CARDS_PAGE_SIZE));
  const safePage = Math.min(cardsPage, totalPages);
  const pagedCards = filteredWords.slice(
    (safePage - 1) * CARDS_PAGE_SIZE,
    safePage * CARDS_PAGE_SIZE
  );

  const quizTarget = useMemo(
    () => words.find((w) => w.id === quizTargetId) ?? words[0],
    [words, quizTargetId]
  );

  function loadNextQuiz(
    pool: HebrewWord[] = filteredWords.length >= 4 ? filteredWords : words,
    targetKind: WordQuizKind = quizKind
  ) {
    const effectivePool =
      targetKind === 'spelling'
        ? pool.filter((w) => /^[\u05D0-\u05EA]{2,8}$/.test(w.hebrewUnpointed))
        : pool;
    const safePool = effectivePool.length > 0 ? effectivePool : words;
    const next = safePool[Math.floor(Math.random() * safePool.length)];
    setQuizTargetId(next.id);
    setQuizOptions(pickQuizOptions(next, words));
    setSelectedOptionId(null);
    setSpellingInput('');
    setSpellingSubmitted(false);
    if (targetKind === 'listening') {
      speakHebrew(next.hebrew, next.transliteration, speechRate);
    }
  }

  function handleCheckSpelling() {
    if (spellingSubmitted || !spellingInput.trim()) return;
    setSpellingSubmitted(true);
    onRecordActivity();
    const isCorrect = spellingInput.trim() === quizTarget.hebrewUnpointed;
    playFeedbackTone(isCorrect ? 'correct' : 'wrong');
    setQuizScore((prev) => ({
      correct: prev.correct + (isCorrect ? 1 : 0),
      total: prev.total + 1,
    }));
  }

  function handleAnswerQuiz(optionId: string) {
    if (selectedOptionId) return;
    setSelectedOptionId(optionId);
    onRecordActivity();
    const isCorrect = optionId === quizTarget.id;
    playFeedbackTone(isCorrect ? 'correct' : 'wrong');
    setQuizScore((prev) => ({
      correct: prev.correct + (isCorrect ? 1 : 0),
      total: prev.total + 1,
    }));
  }

  function handleJumpToWord(wordId: string) {
    const inCurrent = filteredWords.some((w) => w.id === wordId);
    if (!inCurrent) {
      setActiveFilter('all');
      setInitialLetter('all');
      setSearchQuery('');
    }
    setSelectedWordId(wordId);
  }

  function handleCycleMastery(wordId: string) {
    const curr = wordMasteryMap[wordId] ?? 'unlearned';
    const next: MasteryLevel =
      curr === 'unlearned' ? 'learning' : curr === 'learning' ? 'mastered' : 'unlearned';
    onSetWordMastery(wordId, next);
  }

  return (
    <div
      className={`view-container words-view ${
        mode === 'browse' && mobileSubView === 'list' && filteredWords.length > 0
          ? 'words-mobile-list-lock'
          : ''
      }`}
    >
      {/* Top Toolbar */}
      <div
        className={`toolbar-card ${
          mode === 'browse' && mobileSubView === 'detail' ? 'mobile-hide-toolbar' : ''
        }`}
      >
        <div className="toolbar-top-row">
          <div className="search-box">
            <Search size={15} />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder={`搜索 ${words.length} 个词库（希伯来语 / 中文释义 / 转写 / 词根）...`}
            />
          </div>

          <div className="toolbar-right-controls">
            <button
              type="button"
              className={`btn-secondary btn-sm ${sortOrder === 'alpha' ? 'active-btn' : ''}`}
              onClick={() => setSortOrder((s) => (s === 'default' ? 'alpha' : 'default'))}
              title="切换排序方式"
            >
              <ArrowUpDown size={14} />
              <span>{sortOrder === 'alpha' ? '按 א-ת 排序' : '按主题排序'}</span>
            </button>

            <button
              type="button"
              className={`btn-secondary btn-sm ${showNiqqud ? 'active-btn' : ''}`}
              onClick={() => setShowNiqqud((v) => !v)}
              title="切换是否显示元音符号 (Niqqud)"
            >
              {showNiqqud ? <Eye size={14} /> : <EyeOff size={14} />}
              <span>{showNiqqud ? '元音点' : '无点拼写'}</span>
            </button>

            <button
              type="button"
              className={`btn-secondary btn-sm ${showCursive ? 'active-btn' : ''}`}
              onClick={() => setShowCursive((v) => !v)}
            >
              <Sparkles size={14} />
              <span>手写体</span>
            </button>

            <div className="segmented-control">
              <button
                type="button"
                className={mode === 'browse' ? 'active' : ''}
                onClick={() => setMode('browse')}
              >
                <BookOpen size={13} style={{ marginRight: 4, verticalAlign: '-2px' }} />
                工作台 ({masteredWordsCount}/{words.length})
              </button>
              <button
                type="button"
                className={mode === 'cards' ? 'active' : ''}
                onClick={() => setMode('cards')}
              >
                <LayoutGrid size={13} style={{ marginRight: 4, verticalAlign: '-2px' }} />
                卡片墙
              </button>
              <button
                type="button"
                className={mode === 'phrases' ? 'active' : ''}
                onClick={() => setMode('phrases')}
              >
                <MessageSquare size={13} style={{ marginRight: 4, verticalAlign: '-2px' }} />
                情景短句
              </button>
              <button
                type="button"
                className={mode === 'quiz' ? 'active' : ''}
                onClick={() => {
                  setMode('quiz');
                  loadNextQuiz();
                }}
              >
                <HelpCircle size={13} style={{ marginRight: 4, verticalAlign: '-2px' }} />
                自测
              </button>
            </div>
          </div>
        </div>

        {/* Category filter pills (hidden in phrases mode) */}
        {mode !== 'phrases' && (
          <div className="filter-pills-row">
            <button
              type="button"
              className={`filter-pill ${activeFilter === 'all' ? 'active' : ''}`}
              onClick={() => setActiveFilter('all')}
            >
              全部 ({words.length})
            </button>
            <button
              type="button"
              className={`filter-pill ${activeFilter === 'favorites' ? 'active' : ''}`}
              onClick={() => setActiveFilter('favorites')}
            >
              ★ 重点收藏 ({favoriteWordIds.length})
            </button>
            {(Object.keys(WORD_CATEGORY_META) as WordCategory[]).map((cat) => (
              <button
                key={cat}
                type="button"
                className={`filter-pill ${activeFilter === cat ? 'active' : ''}`}
                onClick={() => setActiveFilter(cat)}
              >
                {WORD_CATEGORY_META[cat].label} ({categoryCounts[cat] ?? 0})
              </button>
            ))}
            <button
              type="button"
              className={`filter-pill ${activeFilter === 'needs_review' ? 'active' : ''}`}
              onClick={() => setActiveFilter('needs_review')}
            >
              待掌握
            </button>
            <button
              type="button"
              className={`filter-pill ${activeFilter === 'due_srs' ? 'active' : ''}`}
              onClick={() => setActiveFilter('due_srs')}
            >
              今日待复习 ({dueSrsCount})
            </button>
          </div>
        )}

        {/* Alef-Bet Initial Letter Jump Strip */}
        {(mode === 'browse' || mode === 'cards') && (
          <div className="alefbet-jump-row" aria-label="按希伯来首字母筛选">
            <span className="muted-caption" style={{ flexShrink: 0 }}>
              首字母索引：
            </span>
            <button
              type="button"
              className={`initial-chip ${initialLetter === 'all' ? 'active' : ''}`}
              onClick={() => setInitialLetter('all')}
            >
              全部
            </button>
            <div className="initial-chips-scroll" dir="rtl">
              {letters.map((l) => (
                <button
                  key={l.id}
                  type="button"
                  className={`initial-chip hebrew-init ${initialLetter === l.hebrew ? 'active' : ''}`}
                  onClick={() =>
                    setInitialLetter((prev) => (prev === l.hebrew ? 'all' : l.hebrew))
                  }
                  title={`筛选以 ${l.hebrew} (${l.nameEnglish}) 开头的单词`}
                >
                  {l.hebrew}
                </button>
              ))}
            </div>
          </div>
        )}
      </div>

      {mode === 'browse' ? (
        filteredWords.length === 0 ? (
          <div className="empty-state">
            <p>没有匹配当前条件的希伯来语单词。</p>
            <button
              type="button"
              className="btn-secondary btn-sm"
              onClick={() => {
                setSearchQuery('');
                setActiveFilter('all');
                setInitialLetter('all');
              }}
            >
              重置筛选条件
            </button>
          </div>
        ) : (
          <div className={`words-workbench ${mobileSubView === 'detail' ? 'mobile-detail-active' : 'mobile-list-active'}`}>
            {/* Left Virtualized Word List */}
            <aside className="words-list-pane" aria-label="单词列表">
              <div className="words-list-header">
                <span>匹配 {filteredWords.length} 个单词</span>
                <span className="muted-caption">↑ / ↓ 切换</span>
              </div>
              <div
                ref={listScrollRef}
                className="words-list-scroll virtual-scroll"
                onScroll={(e) => setScrollTop(e.currentTarget.scrollTop)}
              >
                <div
                  className="virtual-spacer"
                  style={{ height: Math.max(ROW_HEIGHT, totalHeight), position: 'relative' }}
                >
                  {visibleSlice.map((word, offsetIdx) => {
                    const actualIdx = startIndex + offsetIdx;
                    const mastery = wordMasteryMap[word.id] ?? 'unlearned';
                    const isActive = word.id === selectedWord?.id;
                    return (
                      <div
                        key={word.id}
                        role="button"
                        tabIndex={0}
                        className={`word-list-item virtual-row ${isActive ? 'active' : ''}`}
                        style={{
                          position: 'absolute',
                          top: actualIdx * ROW_STRIDE,
                          left: 0,
                          right: 0,
                          height: ROW_HEIGHT,
                        }}
                        onClick={() => {
                          setSelectedWordId(word.id);
                          setMobileSubView('detail');
                        }}
                        onKeyDown={(e) => {
                          if (e.key === 'Enter' || e.key === ' ') {
                            e.preventDefault();
                            setSelectedWordId(word.id);
                            setMobileSubView('detail');
                          }
                        }}
                      >
                        <div className="word-item-main">
                          <div className="word-item-hebrew" dir="rtl">
                            {showNiqqud ? word.hebrew : word.hebrewUnpointed}
                          </div>
                          <div className="word-item-meta">
                            <span className="word-item-zh">{word.meaningZh}</span>
                            <span className="word-item-translit">{word.transliteration}</span>
                          </div>
                        </div>
                        <div className="word-item-actions">
                          <button
                            type="button"
                            className={`card-mini-icon-btn ${
                              favoriteSet.has(word.id) ? 'star-active' : ''
                            }`}
                            title={favoriteSet.has(word.id) ? '取消收藏' : '加入重点收藏'}
                            onClick={(e) => {
                              e.stopPropagation();
                              onToggleFavoriteWord(word.id);
                            }}
                          >
                            <Star
                              size={12}
                              fill={favoriteSet.has(word.id) ? 'currentColor' : 'none'}
                            />
                          </button>
                          <button
                            type="button"
                            className="card-mini-icon-btn"
                            title="朗读单词"
                            onClick={(e) => {
                              e.stopPropagation();
                              speakHebrew(word.hebrew, word.transliteration, speechRate);
                            }}
                          >
                            <Volume2 size={13} />
                          </button>
                          <button
                            type="button"
                            className={`word-mastery-dot m-${mastery}`}
                            title="点击切换熟练度"
                            onClick={(e) => {
                              e.stopPropagation();
                              handleCycleMastery(word.id);
                            }}
                          />
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            </aside>

            {/* Right Detail Workspace */}
            {selectedWord && (
              <section className="word-detail-pane">
                <div className="mobile-detail-topbar">
                  <button
                    type="button"
                    className="btn-secondary btn-sm"
                    onClick={() => setMobileSubView('list')}
                  >
                    <ChevronLeft size={15} />
                    <span>返回词表</span>
                  </button>
                  <div className="word-nav-arrows">
                    <span className="muted-caption">
                      {selectedIndex + 1} / {filteredWords.length}
                    </span>
                    <button
                      type="button"
                      className="btn-secondary btn-sm"
                      onClick={() => {
                        const prevIdx =
                          selectedIndex > 0 ? selectedIndex - 1 : filteredWords.length - 1;
                        selectAndScrollToIndex(prevIdx);
                      }}
                    >
                      <ChevronLeft size={14} />
                    </button>
                    <button
                      type="button"
                      className="btn-secondary btn-sm"
                      onClick={() => {
                        const nextIdx =
                          selectedIndex < filteredWords.length - 1 ? selectedIndex + 1 : 0;
                        selectAndScrollToIndex(nextIdx);
                      }}
                    >
                      <ChevronRight size={14} />
                    </button>
                  </div>
                </div>

                <div className="word-detail-header">
                  <div className="word-badges-row">
                    <span className="meta-badge gematria">
                      {WORD_CATEGORY_META[selectedWord.category].label}
                    </span>
                    <span className="meta-badge">{selectedWord.partOfSpeech}</span>
                    <span className="meta-badge">{selectedWord.grammarTag}</span>
                    {selectedWord.root && (
                      <button
                        type="button"
                        className="meta-badge root-badge clickable-root-badge"
                        dir="rtl"
                        onClick={() => setSearchQuery(selectedWord.root ?? '')}
                        title="点击筛选所有同词根单词"
                      >
                        词根: {selectedWord.root}
                      </button>
                    )}
                  </div>

                  <div className="word-nav-arrows">
                    <span className="muted-caption">
                      {selectedIndex + 1} / {filteredWords.length}
                    </span>
                    <button
                      type="button"
                      className="btn-secondary btn-sm"
                      onClick={() => {
                        const prevIdx =
                          selectedIndex > 0 ? selectedIndex - 1 : filteredWords.length - 1;
                        selectAndScrollToIndex(prevIdx);
                      }}
                      title="上一个单词 (↑)"
                    >
                      <ArrowUp size={14} />
                      <span>上一词</span>
                    </button>
                    <button
                      type="button"
                      className="btn-secondary btn-sm"
                      onClick={() => {
                        const nextIdx =
                          selectedIndex < filteredWords.length - 1 ? selectedIndex + 1 : 0;
                        selectAndScrollToIndex(nextIdx);
                      }}
                      title="下一个单词 (↓)"
                    >
                      <span>下一词</span>
                      <ArrowDown size={14} />
                    </button>
                  </div>
                </div>

                {/* Big Display Stage */}
                <div className={`word-glyph-stage ${showCursive ? 'two-col' : ''}`}>
                  <div className="word-stage-card">
                    <span className="stage-label">
                      印刷体 {showNiqqud ? '(带元音点 Niqqud)' : '(日常无元音点)'}
                    </span>
                    <div className="word-hero-block" dir="rtl">
                      {showNiqqud ? selectedWord.hebrew : selectedWord.hebrewUnpointed}
                    </div>
                    {!showNiqqud && (
                      <span className="muted-caption" dir="rtl">
                        带点参考：{selectedWord.hebrew}
                      </span>
                    )}
                  </div>

                  {showCursive && (
                    <div className="word-stage-card">
                      <span className="stage-label">现代手写体 (Ktav)</span>
                      <div className="word-hero-cursive" dir="rtl">
                        {selectedWord.hebrewUnpointed}
                      </div>
                      <span className="muted-caption">手写日常通常省略元音点</span>
                    </div>
                  )}
                </div>

                {/* Meaning + Pronunciation + Mastery */}
                <div className="word-meaning-bar">
                  <div className="word-meaning-text">
                    <h2>{selectedWord.meaningZh}</h2>
                    <div className="word-phonetics-row">
                      <span>
                        转写：<strong>{selectedWord.transliteration}</strong>
                      </span>
                      <span className="ipa-chip">{selectedWord.ipa}</span>
                    </div>
                  </div>

                  <div className="word-cta-group">
                    <button
                      type="button"
                      className={`btn-secondary ${
                        favoriteSet.has(selectedWord.id) ? 'star-active-btn' : ''
                      }`}
                      onClick={() => onToggleFavoriteWord(selectedWord.id)}
                      title={favoriteSet.has(selectedWord.id) ? '取消重点收藏' : '加入重点收藏'}
                    >
                      <Star
                        size={16}
                        fill={favoriteSet.has(selectedWord.id) ? 'currentColor' : 'none'}
                      />
                      <span>{favoriteSet.has(selectedWord.id) ? '已收藏' : '收藏'}</span>
                    </button>

                    <button
                      type="button"
                      className="btn-primary"
                      onClick={() =>
                        speakHebrew(selectedWord.hebrew, selectedWord.transliteration, speechRate)
                      }
                    >
                      <Volume2 size={16} />
                      <span>朗读单词</span>
                    </button>

                    <div className="mastery-segmented">
                      {MASTERY_OPTIONS.map((opt) => {
                        const active =
                          (wordMasteryMap[selectedWord.id] ?? 'unlearned') === opt.level;
                        return (
                          <button
                            key={opt.level}
                            type="button"
                            className={`${active ? 'active' : ''} m-${opt.level}`}
                            onClick={() => onSetWordMastery(selectedWord.id, opt.level)}
                          >
                            {opt.icon}
                            <span>{opt.label}</span>
                          </button>
                        );
                      })}
                    </div>
                  </div>
                </div>

                {/* Letter-by-letter breakdown */}
                <div className="word-section-box">
                  <div className="word-section-header">
                    <h4>逐字母拆解（从右向左拼读，点击字母可查看笔顺）</h4>
                    <span className="muted-caption">共 {breakdown.length} 个辅音字母</span>
                  </div>
                  <div className="word-breakdown-strip" dir="rtl">
                    {breakdown.map((item, idx) => (
                      <button
                        key={`${item.char}-${idx}`}
                        type="button"
                        className="breakdown-letter-chip"
                        dir="ltr"
                        disabled={!item.letter}
                        onClick={() => item.letter && onOpenLetterDetail(item.letter.id)}
                        title={
                          item.letter
                            ? `点击查看 ${item.letter.nameEnglish} (${item.letter.nameChinese}) 的笔顺与发音`
                            : undefined
                        }
                      >
                        <span className="breakdown-char" dir="rtl">
                          {item.char}
                        </span>
                        <span className="breakdown-name">
                          {item.letter ? item.letter.nameEnglish : ''}
                        </span>
                        {item.isSofit && <span className="breakdown-sofit-tag">词尾</span>}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Grammar / Reading Note */}
                <div className="word-section-box">
                  <h4>拼读与词根解析</h4>
                  <p className="word-note-text">{selectedWord.note}</p>
                </div>

                {/* Shoresh Root Family */}
                {rootSiblings.length > 0 && (
                  <div className="word-section-box">
                    <div className="word-section-header">
                      <h4>同词根词汇家族 ({selectedWord.root})</h4>
                      <span className="muted-caption">共 {rootSiblings.length + 1} 个同源词</span>
                    </div>
                    <div className="root-family-chips">
                      {rootSiblings.map((sib) => (
                        <button
                          key={sib.id}
                          type="button"
                          className="root-sibling-chip"
                          onClick={() => handleJumpToWord(sib.id)}
                        >
                          <span className="root-sib-hebrew" dir="rtl">
                            {showNiqqud ? sib.hebrew : sib.hebrewUnpointed}
                          </span>
                          <span className="root-sib-zh">{sib.meaningZh}</span>
                        </button>
                      ))}
                    </div>
                  </div>
                )}

                {/* Gender / Number Inflections */}
                {wordInflection && (
                  <div className="word-section-box">
                    <h4>性数变形速查（点击即可发音）</h4>
                    {wordInflection.kind === 'four-form' ? (
                      <>
                        <div className="inflection-four-grid">
                          {(
                            [
                              ['阳性单数', wordInflection.ms],
                              ['阴性单数', wordInflection.fs],
                              ['阳性复数', wordInflection.mp],
                              ['阴性复数', wordInflection.fp],
                            ] as const
                          ).map(([label, form]) => (
                            <button
                              key={label}
                              type="button"
                              className="inflection-cell-btn"
                              onClick={() => speakHebrew(form.hebrew, form.translit, speechRate)}
                            >
                              <span className="inflection-label">{label}</span>
                              <span className="inflection-hebrew" dir="rtl">
                                {form.hebrew}
                              </span>
                              <span className="inflection-translit">{form.translit}</span>
                            </button>
                          ))}
                        </div>
                        {(wordInflection.infinitive || wordInflection.past3ms) && (
                          <div className="inflection-two-grid" style={{ marginTop: 8 }}>
                            {wordInflection.infinitive && (
                              <button
                                type="button"
                                className="inflection-cell-btn"
                                onClick={() =>
                                  speakHebrew(
                                    wordInflection.infinitive!.hebrew,
                                    wordInflection.infinitive!.translit,
                                    speechRate
                                  )
                                }
                              >
                                <span className="inflection-label">不定式 (原形)</span>
                                <span className="inflection-hebrew" dir="rtl">
                                  {wordInflection.infinitive.hebrew}
                                </span>
                                <span className="inflection-translit">
                                  {wordInflection.infinitive.translit}
                                </span>
                              </button>
                            )}
                            {wordInflection.past3ms && (
                              <button
                                type="button"
                                className="inflection-cell-btn"
                                onClick={() =>
                                  speakHebrew(
                                    wordInflection.past3ms!.hebrew,
                                    wordInflection.past3ms!.translit,
                                    speechRate
                                  )
                                }
                              >
                                <span className="inflection-label">过去时 (他)</span>
                                <span className="inflection-hebrew" dir="rtl">
                                  {wordInflection.past3ms.hebrew}
                                </span>
                                <span className="inflection-translit">
                                  {wordInflection.past3ms.translit}
                                </span>
                              </button>
                            )}
                          </div>
                        )}
                      </>
                    ) : (
                      <div className="inflection-two-grid">
                        {[wordInflection.singular, wordInflection.plural].map((form) => (
                          <button
                            key={form.label}
                            type="button"
                            className="inflection-cell-btn"
                            onClick={() => speakHebrew(form.hebrew, form.translit, speechRate)}
                          >
                            <span className="inflection-label">{form.label}</span>
                            <span className="inflection-hebrew" dir="rtl">
                              {form.hebrew}
                            </span>
                            <span className="inflection-translit">{form.translit}</span>
                          </button>
                        ))}
                      </div>
                    )}
                  </div>
                )}

                {/* Optional Example Sentence */}
                {selectedWord.sentence && (
                  <div className="word-section-box word-sentence-box">
                    <div className="word-section-header">
                      <h4>实用例句</h4>
                      <button
                        type="button"
                        className="btn-secondary btn-sm"
                        onClick={() =>
                          speakHebrew(
                            selectedWord.sentence!.hebrew,
                            selectedWord.sentence!.transliteration,
                            speechRate
                          )
                        }
                      >
                        <Volume2 size={14} />
                        <span>朗读例句</span>
                      </button>
                    </div>
                    <div className="sentence-hebrew" dir="rtl">
                      {selectedWord.sentence.hebrew}
                    </div>
                    <div className="sentence-translit">
                      {selectedWord.sentence.transliteration}
                    </div>
                    <div className="sentence-zh">{selectedWord.sentence.meaningZh}</div>
                  </div>
                )}
              </section>
            )}
          </div>
        )
      ) : mode === 'cards' ? (
        /* Paginated Cards Wall Mode */
        filteredWords.length === 0 ? (
          <div className="empty-state">
            <p>没有匹配当前条件的希伯来语单词。</p>
          </div>
        ) : (
          <div className="words-cards-wall-wrapper">
            <div className="words-pagination-bar">
              <span className="muted-caption">
                共 {filteredWords.length} 个单词 · 第 {safePage} / {totalPages} 页
              </span>
              <div className="pagination-controls">
                <button
                  type="button"
                  className="btn-secondary btn-sm"
                  disabled={safePage <= 1}
                  onClick={() => setCardsPage((p) => Math.max(1, p - 1))}
                >
                  <ChevronLeft size={14} />
                  <span>上一页</span>
                </button>
                <button
                  type="button"
                  className="btn-secondary btn-sm"
                  disabled={safePage >= totalPages}
                  onClick={() => setCardsPage((p) => Math.min(totalPages, p + 1))}
                >
                  <span>下一页</span>
                  <ChevronRight size={14} />
                </button>
              </div>
            </div>

            <div className="words-cards-wall">
              {pagedCards.map((word) => {
                const mastery = wordMasteryMap[word.id] ?? 'unlearned';
                return (
                  <div
                    key={word.id}
                    role="button"
                    tabIndex={0}
                    className={`word-wall-card m-${mastery}`}
                    onClick={() => {
                      setSelectedWordId(word.id);
                      setMode('browse');
                      setMobileSubView('detail');
                    }}
                    onKeyDown={(e) => {
                      if (e.key === 'Enter' || e.key === ' ') {
                        e.preventDefault();
                        setSelectedWordId(word.id);
                        setMode('browse');
                        setMobileSubView('detail');
                      }
                    }}
                  >
                    <div className="word-wall-top">
                      <span className="meta-badge">
                        {WORD_CATEGORY_META[word.category].badge}
                      </span>
                      <div className="word-item-actions">
                        <button
                          type="button"
                          className="card-mini-icon-btn"
                          title="朗读单词"
                          onClick={(e) => {
                            e.stopPropagation();
                            speakHebrew(word.hebrew, word.transliteration, speechRate);
                          }}
                        >
                          <Volume2 size={13} />
                        </button>
                        <button
                          type="button"
                          className={`word-mastery-dot m-${mastery}`}
                          title="切换熟练度"
                          onClick={(e) => {
                            e.stopPropagation();
                            handleCycleMastery(word.id);
                          }}
                        />
                      </div>
                    </div>

                    <div className="word-wall-glyphs">
                      <span className="word-wall-hebrew" dir="rtl">
                        {showNiqqud ? word.hebrew : word.hebrewUnpointed}
                      </span>
                      {showCursive && (
                        <span className="word-wall-cursive" dir="rtl">
                          {word.hebrewUnpointed}
                        </span>
                      )}
                    </div>

                    <div className="word-wall-meaning">{word.meaningZh}</div>
                    <div className="word-wall-phonetics">
                      <span>{word.transliteration}</span>
                      <span>{word.ipa}</span>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        )
      ) : mode === 'phrases' ? (
        /* Situational Phrases Mode */
        <div className="phrases-section">
          <div className="toolbar-card phrases-toolbar">
            <div className="filter-pills-row">
              <button
                type="button"
                className={`filter-pill ${phraseScenario === 'all' ? 'active' : ''}`}
                onClick={() => setPhraseScenario('all')}
              >
                全部短句 ({HEBREW_PHRASES.length})
              </button>
              {(Object.keys(PHRASE_SCENARIO_META) as PhraseScenario[]).map((sc) => (
                <button
                  key={sc}
                  type="button"
                  className={`filter-pill ${phraseScenario === sc ? 'active' : ''}`}
                  onClick={() => setPhraseScenario(sc)}
                >
                  {PHRASE_SCENARIO_META[sc].label}
                </button>
              ))}
            </div>
            <button
              type="button"
              className={`btn-secondary btn-sm ${hidePhraseZh ? 'active-btn' : ''}`}
              onClick={() => setHidePhraseZh((v) => !v)}
            >
              {hidePhraseZh ? <EyeOff size={14} /> : <Eye size={14} />}
              <span>{hidePhraseZh ? '显示中文释义' : '隐藏中文自测'}</span>
            </button>
          </div>

          <div className="phrases-grid">
            {filteredPhrases.map((phrase) => (
              <div key={phrase.id} className="phrase-card">
                <div className="phrase-card-top">
                  <span className="meta-badge">
                    {PHRASE_SCENARIO_META[phrase.scenario].label}
                  </span>
                  <div className="phrase-audio-btns">
                    <button
                      type="button"
                      className="btn-secondary btn-xs"
                      onClick={() => speakHebrew(phrase.hebrew, phrase.transliteration, 0.68)}
                      title="慢速跟读"
                    >
                      0.7x 慢读
                    </button>
                    <button
                      type="button"
                      className="btn-primary btn-xs"
                      onClick={() =>
                        speakHebrew(phrase.hebrew, phrase.transliteration, speechRate)
                      }
                    >
                      <Volume2 size={12} />
                      <span>朗读</span>
                    </button>
                  </div>
                </div>
                <div className="phrase-hebrew" dir="rtl">
                  {showNiqqud ? phrase.hebrew : phrase.hebrewUnpointed}
                </div>
                <div className="phrase-translit">{phrase.transliteration}</div>
                <div className={`phrase-zh ${hidePhraseZh ? 'masked-zh' : ''}`}>
                  {hidePhraseZh ? '点击上方「显示中文释义」核对翻译' : phrase.meaningZh}
                </div>
                {phrase.note && <p className="phrase-note">{phrase.note}</p>}
              </div>
            ))}
          </div>
        </div>
      ) : (
        /* Word Quiz Mode */
        <div className="quiz-stage">
          <div className="quiz-card">
            <div className="quiz-prompt-header">
              <div className="segmented-control">
                <button
                  type="button"
                  className={quizKind === 'meaning' ? 'active' : ''}
                  onClick={() => {
                    setQuizKind('meaning');
                    loadNextQuiz(undefined, 'meaning');
                  }}
                >
                  看词选义
                </button>
                <button
                  type="button"
                  className={quizKind === 'listening' ? 'active' : ''}
                  onClick={() => {
                    setQuizKind('listening');
                    loadNextQuiz(undefined, 'listening');
                  }}
                >
                  听音辨词
                </button>
                <button
                  type="button"
                  className={quizKind === 'spelling' ? 'active' : ''}
                  onClick={() => {
                    setQuizKind('spelling');
                    loadNextQuiz(undefined, 'spelling');
                  }}
                >
                  拼写练习
                </button>
              </div>

              <div className="quiz-score-badge">
                <Layers size={14} />
                <span>
                  得分 {quizScore.correct} / {quizScore.total}
                </span>
              </div>
            </div>

            {quizKind === 'spelling' ? (
              <div className="spelling-quiz-body">
                <div className="spelling-prompt-box">
                  <h3>{quizTarget.meaningZh}</h3>
                  <div className="word-phonetics-row">
                    <span>提示转写：{quizTarget.transliteration}</span>
                    <button
                      type="button"
                      className="btn-secondary btn-xs"
                      onClick={() =>
                        speakHebrew(quizTarget.hebrew, quizTarget.transliteration, speechRate)
                      }
                    >
                      <Volume2 size={13} />
                      <span>听发音</span>
                    </button>
                  </div>
                </div>

                <div className="spelling-display-box" dir="rtl">
                  {spellingInput || (
                    <span className="muted-caption" dir="ltr">
                      请点击下方希伯来字母从右向左拼写...
                    </span>
                  )}
                </div>

                <div className="hebrew-keyboard-grid" dir="rtl">
                  {HEBREW_KEYBOARD_LETTERS.map((ch) => (
                    <button
                      key={ch}
                      type="button"
                      className="hebrew-key-btn"
                      disabled={spellingSubmitted}
                      onClick={() => setSpellingInput((prev) => prev + ch)}
                    >
                      {ch}
                    </button>
                  ))}
                </div>

                <div className="spelling-actions-row">
                  <button
                    type="button"
                    className="btn-secondary btn-sm"
                    disabled={spellingSubmitted || spellingInput.length === 0}
                    onClick={() => setSpellingInput((prev) => prev.slice(0, -1))}
                  >
                    <Delete size={14} />
                    <span>退格</span>
                  </button>
                  <button
                    type="button"
                    className="btn-ghost btn-sm"
                    disabled={spellingSubmitted || spellingInput.length === 0}
                    onClick={() => setSpellingInput('')}
                  >
                    清空
                  </button>
                  {!spellingSubmitted ? (
                    <button
                      type="button"
                      className="btn-primary btn-sm"
                      disabled={spellingInput.length === 0}
                      onClick={handleCheckSpelling}
                    >
                      提交拼写
                    </button>
                  ) : (
                    <button
                      type="button"
                      className="btn-primary btn-sm"
                      onClick={() => loadNextQuiz(undefined, 'spelling')}
                    >
                      下一题
                    </button>
                  )}
                </div>

                {spellingSubmitted && (
                  <div
                    className={`quiz-feedback-box ${
                      spellingInput.trim() === quizTarget.hebrewUnpointed ? 'correct' : 'wrong'
                    }`}
                  >
                    <div className="feedback-text">
                      <strong>
                        {spellingInput.trim() === quizTarget.hebrewUnpointed
                          ? '拼写完全正确！'
                          : '再核对一下拼写：'}
                      </strong>
                      <span>
                        正确拼写：{quizTarget.hebrew}（无点：{quizTarget.hebrewUnpointed}）
                      </span>
                    </div>
                  </div>
                )}
              </div>
            ) : (
              <>
                <div className="quiz-stimulus-box word-quiz-stimulus">
                  {quizKind === 'meaning' ? (
                    <div className="word-quiz-prompt">
                      <span className="quiz-big-hebrew" dir="rtl">
                        {showNiqqud ? quizTarget.hebrew : quizTarget.hebrewUnpointed}
                      </span>
                      <button
                        type="button"
                        className="btn-secondary btn-sm"
                        onClick={() =>
                          speakHebrew(quizTarget.hebrew, quizTarget.transliteration, speechRate)
                        }
                      >
                        <Volume2 size={14} />
                        <span>朗读</span>
                      </button>
                    </div>
                  ) : (
                    <button
                      type="button"
                      className="btn-primary"
                      onClick={() =>
                        speakHebrew(quizTarget.hebrew, quizTarget.transliteration, speechRate)
                      }
                    >
                      <Volume2 size={18} />
                      <span>播放单词发音</span>
                    </button>
                  )}
                </div>

                <div className="quiz-options-grid">
                  {quizOptions.map((opt) => {
                    const isPicked = selectedOptionId === opt.id;
                    const isRight = opt.id === quizTarget.id;
                    let cls = 'quiz-option-btn';
                    if (selectedOptionId) {
                      if (isRight) cls += ' correct';
                      else if (isPicked) cls += ' wrong';
                      else cls += ' dimmed';
                    }
                    return (
                      <button
                        key={opt.id}
                        type="button"
                        className={cls}
                        onClick={() => handleAnswerQuiz(opt.id)}
                      >
                        <span className="opt-main">
                          {quizKind === 'listening' ? opt.hebrew : opt.meaningZh}
                        </span>
                        <span className="opt-sub">
                          {quizKind === 'listening'
                            ? `${opt.transliteration} · ${opt.meaningZh}`
                            : opt.transliteration}
                        </span>
                      </button>
                    );
                  })}
                </div>

                {selectedOptionId && (
                  <div
                    className={`quiz-feedback-box ${
                      selectedOptionId === quizTarget.id ? 'correct' : 'wrong'
                    }`}
                  >
                    <div className="feedback-text">
                      <strong>
                        {selectedOptionId === quizTarget.id ? '回答正确！' : '再记一下：'}
                      </strong>
                      <span>
                        {quizTarget.hebrew} ({quizTarget.transliteration}) — {quizTarget.meaningZh}
                      </span>
                    </div>
                    <div style={{ display: 'flex', gap: 8 }}>
                      <button
                        type="button"
                        className="btn-secondary btn-sm"
                        onClick={() =>
                          onSetWordMastery(
                            quizTarget.id,
                            selectedOptionId === quizTarget.id ? 'mastered' : 'learning'
                          )
                        }
                      >
                        {selectedOptionId === quizTarget.id ? '标为已掌握' : '加入学习中'}
                      </button>
                      <button
                        type="button"
                        className="btn-primary btn-sm"
                        onClick={() => loadNextQuiz()}
                      >
                        下一题
                      </button>
                    </div>
                  </div>
                )}
              </>
            )}
          </div>
        </div>
      )}
    </div>
  );
};
