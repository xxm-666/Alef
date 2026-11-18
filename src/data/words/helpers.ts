import { HebrewWord, WordCategory } from '../../types/hebrew';

export type CompactWordEntry = [
  id: string,
  hebrew: string,
  hebrewUnpointed: string,
  transliteration: string,
  ipa: string,
  meaningZh: string,
  partOfSpeech: string,
  grammarTag: string,
  category: WordCategory,
  root?: string,
  note?: string
];

const SOFIT_MAP: Record<string, string> = {
  'ך': 'ך (Kaf Sofit)',
  'ם': 'ם (Mem Sofit)',
  'ן': 'ן (Nun Sofit)',
  'ף': 'ף (Pe Sofit)',
  'ץ': 'ץ (Tsadi Sofit)',
};

function buildAutoNote(hebrew: string, unpointed: string, pos: string, root?: string): string {
  const notes: string[] = [];
  if (root) {
    notes.push(`词根为 ${root}`);
  }
  const sofitHits: string[] = [];
  for (const ch of Array.from(unpointed)) {
    if (SOFIT_MAP[ch] && !sofitHits.includes(SOFIT_MAP[ch])) {
      sofitHits.push(SOFIT_MAP[ch]);
    }
  }
  if (sofitHits.length > 0) {
    notes.push(`包含词尾形 ${sofitHits.join('、')}`);
  }
  if (unpointed.includes('ח') || unpointed.includes('ע')) {
    notes.push('注意喉音字母 ח / ע 的发音位置');
  }
  if (hebrew !== unpointed && /[\u0591-\u05C7]/.test(hebrew)) {
    notes.push(`无元音点日常拼写为「${unpointed}」`);
  }
  if (notes.length === 0) {
    notes.push(`现代希伯来语常用${pos}，建议结合朗读记忆重音位置`);
  }
  return notes.join('；') + '。';
}

export function expandWordBatch(entries: CompactWordEntry[]): HebrewWord[] {
  return entries.map(([
    id,
    hebrew,
    hebrewUnpointed,
    transliteration,
    ipa,
    meaningZh,
    partOfSpeech,
    grammarTag,
    category,
    root,
    note,
  ]) => ({
    id,
    hebrew,
    hebrewUnpointed,
    transliteration,
    ipa,
    meaningZh,
    partOfSpeech,
    grammarTag,
    category,
    ...(root ? { root } : {}),
    note: note ?? buildAutoNote(hebrew, hebrewUnpointed, partOfSpeech, root),
  }));
}
