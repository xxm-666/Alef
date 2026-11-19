import { WORD_CATEGORY_META } from '../data/hebrewWords';
import { HEBREW_LETTERS } from '../data/hebrewLetters';

type Validator = (value: unknown) => boolean;
type RestoreEntry = [key: string, value: string | null];

const RESTORE_POINT_KEY = 'alef-restore-point.v1';
const isRecord = (value: unknown): value is Record<string, unknown> =>
  value !== null && typeof value === 'object' && !Array.isArray(value);
const string: Validator = (value) => typeof value === 'string';
const boolean: Validator = (value) => typeof value === 'boolean';
const integer: Validator = (value) => typeof value === 'number' && Number.isSafeInteger(value) && value >= 0;
const oneOf = (...options: string[]): Validator => (value) => typeof value === 'string' && options.includes(value);
const recordOf = (check: Validator): Validator =>
  (value) => isRecord(value) && Object.values(value).every(check);
const fields = (schema: Record<string, Validator>): Validator =>
  (value) => isRecord(value) && Object.entries(schema).every(([key, check]) => check(value[key]));

const mastery = recordOf(oneOf('unlearned', 'learning', 'mastered'));
const dayTheme = oneOf('parchment', 'rose', 'violet');

const rules: Record<string, [label: string, check: Validator]> = {
  'alef.mastery.v1': ['字母掌握度', mastery],
  'alef.wordMastery.v1': ['单词掌握度', mastery],
  'alef.wordSrs.v1': ['单词复习排期', recordOf(fields({ nextReviewAt: integer, intervalDays: integer }))],
  'alef.favoriteWords.v1': ['收藏单词', (value) => Array.isArray(value) && value.every(string)],
  'alef.studyStats.v1': ['学习统计', fields({
    streakDays: integer, lastActiveDate: string, todayReviews: integer, totalReviews: integer,
  })],
  'alef.theme.v1': ['主题', (value) => value === 'dark' || dayTheme(value)],
  'alef.dayTheme.v1': ['日间主题', dayTheme],
  'alef.order.v1': ['阅读方向', oneOf('rtl', 'ltr')],
  'alef.speechRate.v1': ['朗读速度', (value) => typeof value === 'number' && value >= 0.5 && value <= 1.5],
  'alef.activeView.v1': ['上次打开的页面', oneOf('grid', 'detail', 'words', 'flashcards', 'rules', 'settings')],
  'alef.selectedLetterId.v1': ['上次查看的字母', oneOf(...HEBREW_LETTERS.map(({ id }) => id))],
  'alef.displayConfig.v1': ['字母表显示选项', recordOf(boolean)],
  'alef.rulesTab.v1': ['规则页选项', oneOf('syllables', 'sofit', 'begadkefat', 'confusable', 'guttural', 'niqqud')],
  'alef.gridState.v1': ['字母表筛选', fields({
    searchQuery: string, activeFilter: oneOf('all', 'sofit', 'begadkefat', 'guttural', 'confusable', 'needs_review'),
  })],
  'alef.wordsState.v1': ['词表选项', fields({
    searchQuery: string, activeFilter: oneOf('all', 'favorites', 'needs_review', 'due_srs', ...Object.keys(WORD_CATEGORY_META)),
    initialLetter: string, sortOrder: oneOf('default', 'alpha'), showNiqqud: boolean, showCursive: boolean,
    mode: oneOf('browse', 'cards', 'phrases', 'reading', 'quiz'),
    mobileSubView: (value) => value === undefined || oneOf('list', 'detail')(value),
    selectedWordId: string, cardsPage: (value) => integer(value) && value !== 0,
    scrollTop: (value) => typeof value === 'number' && Number.isFinite(value) && value >= 0,
  })],
  'alef.flashcardState.v1': ['闪卡选项', fields({
    subMode: oneOf('flip', 'quiz'), frontType: oneOf('block', 'cursive', 'both', 'sofit'),
    deckScope: oneOf('all', 'needs_review', 'sofit', 'begadkefat'), cardIndex: integer,
    quizType: oneOf('block-to-sound', 'cursive-to-block', 'sofit-match', 'dagesh-quiz'),
  })],
};

export interface BackupPreview {
  entries: RestoreEntry[];
  labels: string[];
  ignored: number;
  restorePoint: boolean;
}

export function parseBackup(raw: string): BackupPreview {
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new Error('JSON 格式无效，请检查备份文件是否完整。');
  }
  if (!isRecord(parsed) || parsed.app !== 'Alef' || !isRecord(parsed.data)) {
    throw new Error('请选择 Alef 导出的 JSON 备份。');
  }
  if (parsed.version !== 1) {
    throw new Error('此备份版本暂不支持。');
  }

  const preview: BackupPreview = { entries: [], labels: [], ignored: 0, restorePoint: false };
  for (const [key, value] of Object.entries(parsed.data)) {
    if (!Object.prototype.hasOwnProperty.call(rules, key)) {
      preview.ignored++;
      continue;
    }
    const [label, check] = rules[key];
    if (!check(value)) throw new Error(`「${label}」格式无效，请检查原备份。`);
    const serialized = JSON.stringify(value);
    preview.entries.push([key, serialized]);
    if (localStorage.getItem(key) !== serialized) preview.labels.push(label);
  }
  if (!preview.entries.length) throw new Error('此备份没有可恢复的数据。');
  return preview;
}

export function readRestorePoint(): BackupPreview | null {
  try {
    const raw = localStorage.getItem(RESTORE_POINT_KEY);
    if (!raw) return null;
    const previous: unknown = JSON.parse(raw);
    if (!isRecord(previous)) return null;
    const entries = Object.entries(previous).filter(
      (item): item is RestoreEntry =>
        Object.prototype.hasOwnProperty.call(rules, item[0]) && (item[1] === null || typeof item[1] === 'string')
    );
    const labels = entries.filter(([key, value]) => localStorage.getItem(key) !== value)
      .map(([key]) => rules[key][0]);
    return entries.length ? { entries, labels, ignored: 0, restorePoint: true } : null;
  } catch {
    return null;
  }
}

function writeEntries(entries: RestoreEntry[]) {
  for (const [key, value] of entries) {
    if (value === null) localStorage.removeItem(key);
    else localStorage.setItem(key, value);
  }
}

export function applyBackup(preview: BackupPreview) {
  const keys = new Set(preview.entries.map(([key]) => key));
  // Loading a restored day theme also updates the remembered day theme.
  if (keys.has('alef.theme.v1')) keys.add('alef.dayTheme.v1');
  const previous = Array.from(keys, (key): RestoreEntry => [key, localStorage.getItem(key)]);
  const oldRestorePoint = localStorage.getItem(RESTORE_POINT_KEY);

  // Save a restore point before any learning data is overwritten.
  localStorage.setItem(RESTORE_POINT_KEY, JSON.stringify(Object.fromEntries(previous)));
  try {
    writeEntries(preview.entries);
  } catch (error) {
    localStorage.removeItem(RESTORE_POINT_KEY);
    writeEntries(previous.filter(([, value]) => value === null));
    writeEntries(previous.filter(([, value]) => value !== null));
    writeEntries([[RESTORE_POINT_KEY, oldRestorePoint]]);
    throw error;
  }
}
