import type { ClassifiedHebrewWord, HebrewWord, WordDifficulty, WordFrequency } from '../../types/hebrew';
import { COMMON_FORMS, REGULAR_FORMS } from './frequencyForms';

function frequencyFor(forms: string[]): WordFrequency {
  if (forms.every((form) => COMMON_FORMS.has(form))) return 'common';
  if (forms.every((form) => COMMON_FORMS.has(form) || REGULAR_FORMS.has(form))) return 'regular';
  return 'extended';
}

function difficultyFor(word: HebrewWord, forms: string[]): WordDifficulty {
  const letters = word.hebrewUnpointed.match(/[א-ת]/gu)?.length ?? 0;
  const vowels = word.ipa.match(/[aeiou]/g)?.length ?? 0;
  const phonemes = word.ipa.replace(/[/ˈ]/g, '').replace(/ts/g, 't');
  const startsWithCluster = /^[^aeiou ]{2}/.test(phonemes);
  if (forms.length === 1 && letters <= 4 && vowels <= 2 && !startsWithCluster) return 'beginner';
  if (forms.length >= 3 || letters >= 9 || vowels >= 5 || (letters >= 7 && vowels >= 4)) return 'advanced';
  return 'intermediate';
}

export function classifyWord(word: HebrewWord): ClassifiedHebrewWord {
  const forms = word.hebrewUnpointed.normalize('NFC').trim().split(/[\s־]+/u);
  return { ...word, frequency: frequencyFor(forms), difficulty: difficultyFor(word, forms) };
}
