import { HebrewWord, MasteryLevel, WordSrsRecord } from '../types/hebrew';

export const DAILY_VOCABULARY_KEY = 'alef.dailyVocabulary.v1';
export const DAILY_GROUP_OPTIONS = [1, 2, 3] as const;
export const DAILY_GROUP_SIZE = 5;

export interface DailySpellingAnswer {
  input: string;
  correct: boolean;
}

export interface DailyVocabularyGroup {
  wordIds: string[];
  studied: number;
  answers: DailySpellingAnswer[];
  feedbackPending: boolean;
}

export interface DailyVocabularyPlan {
  day: string;
  groupsPerDay: number;
  groups: DailyVocabularyGroup[];
}

export const EMPTY_DAILY_PLAN: DailyVocabularyPlan = { day: '', groupsPerDay: 2, groups: [] };

export function vocabularyDay(date = new Date()): string {
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${date.getFullYear()}-${month}-${day}`;
}

export function canPracticeSpelling(word: HebrewWord): boolean {
  return /^[\u05D0-\u05EA]{2,8}$/.test(word.hebrewUnpointed);
}

export function acceptsWordSpelling(word: HebrewWord, input: string): boolean {
  const normalize = (value: string) => value.trim().replace(/\s+/g, ' ').replace(/"/g, '״').normalize('NFC');
  const answer = normalize(input);
  return [word.hebrew, word.hebrewUnpointed, ...(word.alternateSpellings ?? [])]
    .some((form) => normalize(form) === answer);
}

export function isDailyGroupComplete(group: DailyVocabularyGroup): boolean {
  return group.answers.length === group.wordIds.length && !group.feedbackPending;
}

export function hasStartedDailyGroup(group: DailyVocabularyGroup): boolean {
  return group.studied > 0;
}

export function dailyGroupStatus(group: DailyVocabularyGroup): string {
  if (isDailyGroupComplete(group)) return `拼对 ${group.answers.filter((answer) => answer.correct).length} / ${group.wordIds.length}`;
  if (group.studied === group.wordIds.length) return `拼写 ${group.answers.length} / ${group.wordIds.length}`;
  return hasStartedDailyGroup(group) ? `认读 ${group.studied} / ${group.wordIds.length}` : '先认读，再拼写';
}

export function buildDailyPlan(
  previous: DailyVocabularyPlan,
  words: HebrewWord[],
  mastery: Record<string, MasteryLevel>,
  schedule: Record<string, WordSrsRecord>,
  day: string,
): DailyVocabularyPlan {
  const available = new Set(words.map((word) => word.id));
  const validGroups = previous.groups.filter((group) => group.wordIds.every((id) => available.has(id)));
  if (previous.day === day && validGroups.length === previous.groups.length) return previous;

  const groups = validGroups.filter((group) => previous.day === day ||
    (hasStartedDailyGroup(group) && !isDailyGroupComplete(group)));
  const assigned = new Set(groups.flatMap((group) => group.wordIds));
  const newIds = words.filter(({ id }) => !assigned.has(id) && mastery[id] !== 'mastered' && !schedule[id])
    .map(({ id }) => id);
  for (let offset = 0; groups.length < previous.groupsPerDay && offset < newIds.length; offset += DAILY_GROUP_SIZE) {
    groups.push({ wordIds: newIds.slice(offset, offset + DAILY_GROUP_SIZE), studied: 0, answers: [], feedbackPending: false });
  }
  return { ...previous, day, groups };
}

export function isDailyVocabularyPlan(value: unknown): value is DailyVocabularyPlan {
  if (!value || typeof value !== 'object') return false;
  const { day, groupsPerDay, groups } = value as Partial<DailyVocabularyPlan>;
  if (typeof day !== 'string' || (day !== '' && !/^\d{4}-\d{2}-\d{2}$/.test(day))
      || !(groupsPerDay === 1 || groupsPerDay === 2 || groupsPerDay === 3)
      || !Array.isArray(groups) || groups.length > DAILY_GROUP_OPTIONS.length
      || (day === '' && groups.length > 0)) return false;
  const ids = new Set<string>();
  let foundIncomplete = false;
  for (const group of groups) {
    if (!group || !Array.isArray(group.wordIds) || group.wordIds.length === 0 || group.wordIds.length > DAILY_GROUP_SIZE
      || !Number.isInteger(group.studied) || group.studied < 0 || group.studied > group.wordIds.length
      || !Array.isArray(group.answers) || group.answers.length > group.wordIds.length
      || (group.studied < group.wordIds.length && group.answers.length > 0)
      || typeof group.feedbackPending !== 'boolean' || (group.feedbackPending && !group.answers.length)) return false;
    if (group.answers.some((answer) => !answer || typeof answer.input !== 'string' || !answer.input.trim() || typeof answer.correct !== 'boolean')) return false;
    if (foundIncomplete && hasStartedDailyGroup(group)) return false;
    if (!isDailyGroupComplete(group)) foundIncomplete = true;
    for (const id of group.wordIds) {
      if (typeof id !== 'string' || !id || ids.has(id)) return false;
      ids.add(id);
    }
  }
  return true;
}
