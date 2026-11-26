export type LetterCategory =
  | 'begadkefat'
  | 'sofit'
  | 'guttural'
  | 'mater'
  | 'sibilant';

export type MasteryLevel = 'unlearned' | 'learning' | 'mastered';

export type StudyViewMode = 'grid' | 'detail' | 'words' | 'flashcards' | 'rules' | 'settings';

export type WordCategory =
  | 'greetings'
  | 'family'
  | 'time'
  | 'daily'
  | 'nature'
  | 'verbs'
  | 'adjectives'
  | 'city'
  | 'body'
  | 'work'
  | 'biblical';

export interface WordSentenceExample {
  hebrew: string;
  transliteration: string;
  meaningZh: string;
}

export interface HebrewWord {
  id: string;
  hebrew: string;
  hebrewUnpointed: string;
  alternateSpellings?: string[];
  transliteration: string;
  ipa: string;
  meaningZh: string;
  partOfSpeech: string;
  grammarTag: string;
  category: WordCategory;
  root?: string;
  note: string;
  sentence?: WordSentenceExample;
}

export type WordFrequency = 'common' | 'regular' | 'extended';
export type WordDifficulty = 'beginner' | 'intermediate' | 'advanced';

export interface ClassifiedHebrewWord extends HebrewWord {
  frequency: WordFrequency;
  difficulty: WordDifficulty;
}

export type ThemeMode = 'dark' | 'parchment' | 'rose' | 'violet';

export type AlphabetOrder = 'rtl' | 'ltr';

export type GridFilter =
  | 'all'
  | 'sofit'
  | 'begadkefat'
  | 'guttural'
  | 'confusable'
  | 'needs_review';

export interface StrokePath {
  d: string;
  startX: number;
  startY: number;
  label?: string;
}

export interface StrokeGuide {
  blockSteps: string[];
  cursiveSteps: string[];
  blockStrokes: StrokePath[];
  cursiveStrokes: StrokePath[];
  cursiveMarks?: CursiveMark[];
  sofitBlockSteps?: string[];
  sofitCursiveSteps?: string[];
  sofitBlockStrokes?: StrokePath[];
  sofitCursiveStrokes?: StrokePath[];
}

export interface CursiveMark {
  glyph: string;
  label: string;
  step: string;
  stroke: StrokePath;
}

export interface BegadkefatVariant {
  glyph: string;
  name: string;
  modernSound: string;
  modernIpa: string;
  biblicalIpa: string;
}

export interface BegadkefatInfo {
  withDagesh: BegadkefatVariant;
  withoutDagesh: BegadkefatVariant;
  modernPreserved: boolean;
  note: string;
}

export interface WordExample {
  hebrew: string;
  transliteration: string;
  meaning: string;
  note?: string;
}

export interface SofitInfo {
  medialGlyph: string;
  finalGlyph: string;
  sofitGematria: number;
  rule: string;
  exampleWord: WordExample;
}

export interface HebrewLetter {
  id: string;
  order: number;
  hebrew: string;
  sofit: string | null;
  nameHebrew: string;
  nameEnglish: string;
  nameChinese: string;
  transliteration: string;
  modernSound: string;
  modernIpa: string;
  biblicalIpa: string;
  biblicalDiff: string;
  pronunciationDesc: string;
  gematria: number;
  categories: LetterCategory[];
  meaning: string;
  etymology: string;
  cursiveDesc: string;
  confusableWith: string[];
  begadkefat: BegadkefatInfo | null;
  sofitInfo: SofitInfo | null;
  strokeGuide: StrokeGuide;
  examples: WordExample[];
}

export interface CustomDisplayConfig {
  showBlock: boolean;
  showCursive: boolean;
  showSofit: boolean;
  showBegadkefat: boolean;
  showHebrewName: boolean;
  showEnglishName: boolean;
  showChineseName: boolean;
  showModernSound: boolean;
  showBiblicalDiff: boolean;
  showTransliteration: boolean;
  showGematria: boolean;
  showMastery: boolean;
  showCategoryBadges: boolean;
}

export interface ConfusableGroup {
  id: string;
  title: string;
  letterIds: string[];
  comparisonNotes: string[];
  tip: string;
}

export interface NiqqudItem {
  id: string;
  nameHebrew: string;
  nameEnglish: string;
  nameChinese: string;
  sample: string;
  vowelSound: string;
  ipa: string;
  note: string;
}

export interface ElectronWindowState {
  isAlwaysOnTop: boolean;
  isMiniMode: boolean;
  opacity: number;
  isMaximized: boolean;
  isElectron: boolean;
}

export interface WordSrsRecord {
  nextReviewAt: number;
  intervalDays: number;
}

export interface StudyStats {
  streakDays: number;
  lastActiveDate: string;
  todayReviews: number;
  totalReviews: number;
}

export interface GrammarExample {
  hebrew: string;
  transliteration: string;
  meaning: string;
  wordId?: string;
}

export interface GrammarAffixItem {
  id: string;
  kind: 'prefix' | 'suffix';
  hebrew: string;
  transliteration: string;
  meaning: string;
  rule: string;
  examples: GrammarExample[];
}

export interface GrammarBinyanItem {
  id: string;
  nameHebrew: string;
  nameEnglish: string;
  role: string;
  pattern: string;
  presentPrefix: string;
  tip: string;
  exampleWordIds: string[];
}

export interface MinimalPairItem {
  id: string;
  contrast: string;
  tip: string;
  firstWordId: string;
  secondWordId: string;
}

export interface LearningPathStage {
  id: string;
  stage: number;
  title: string;
  subtitle: string;
  goal: string;
  letterIds: string[];
  ruleTopic: string;
  wordIds: string[];
  readingId?: string;
}
