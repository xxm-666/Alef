import { access, readFile, stat } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { build } from 'esbuild';

const AUDIO_FILE_PATTERN = /^audio\/he_[a-f0-9]{12}\.mp3$/;

export async function loadStudyContent(rootUrl = new URL('../', import.meta.url)) {
  const { outputFiles: [bundle] } = await build({
    stdin: {
      resolveDir: fileURLToPath(rootUrl),
      contents: `
        export { HEBREW_LETTERS as letters, NIQQUD_ITEMS as niqqud, CONFUSABLE_GROUPS as confusables } from './src/data/hebrewLetters';
        export { HEBREW_WORDS as words, WORD_CATEGORY_META as wordCategories } from './src/data/hebrewWords';
        export { HEBREW_PHRASES as phrases, PHRASE_SCENARIO_META as phraseCategories } from './src/data/hebrewPhrases';
        export { HEBREW_READINGS as readings, READING_CATEGORIES as readingCategories } from './src/data/hebrewReadings';
        export { WORD_INFLECTIONS as inflections } from './src/data/wordInflections';
        export { CONSONANT_OPTIONS as consonants, VOWEL_PATTERNS as vowels } from './src/data/syllables';
        export { DEFAULT_DISPLAY_CONFIG as defaultDisplay, DISPLAY_PRESETS as displayPresets } from './src/data/letterDisplay';
        export { AUDIO_FILE_MAP as audio } from './src/data/audioManifest';
        export { GRAMMAR_AFFIXES as grammarAffixes, GRAMMAR_BINYANIM as grammarBinyanim } from './src/data/hebrewGrammar';
        export { MINIMAL_PAIRS as minimalPairs } from './src/data/minimalPairs';
        export { LEARNING_PATH as learningPath } from './src/data/learningPath';
      `,
    },
    bundle: true,
    format: 'esm',
    platform: 'node',
    write: false,
  });

  const moduleNs = await import(`data:text/javascript;base64,${Buffer.from(bundle.contents).toString('base64')}`);
  return { ...moduleNs };
}

export function extractDailyLetterIds(swiftSource) {
  const blockMatch = swiftSource.match(/static\s+let\s+alphabet\s*:\s*\[DailyLetter\]\s*=\s*\[([\s\S]*?)\]/);
  if (!blockMatch) {
    throw new Error('DailyLetter.swift is missing `static let alphabet: [DailyLetter]`');
  }
  return Array.from(blockMatch[1].matchAll(/\.init\(\s*id:\s*"([^"]+)"/g), (match) => match[1]);
}

function isNonEmptyString(value) {
  return typeof value === 'string' && value.trim().length > 0;
}

async function ensureNonEmptyFile(fileUrl, label, errors) {
  try {
    await access(fileUrl);
    const info = await stat(fileUrl);
    if (!info.isFile() || info.size <= 0) {
      errors.push(`${label} is empty or not a regular file`);
    }
  } catch {
    errors.push(`${label} is missing`);
  }
}

export async function validateStudyContent(
  content,
  { rootUrl = new URL('../', import.meta.url), dailyLetterSwiftPath } = {},
) {
  const errors = [];
  const letters = Array.isArray(content?.letters) ? content.letters : [];
  const words = Array.isArray(content?.words) ? content.words : [];
  const phrases = Array.isArray(content?.phrases) ? content.phrases : [];
  const readings = Array.isArray(content?.readings) ? content.readings : [];
  const wordCategories = content?.wordCategories ?? {};
  const phraseCategories = content?.phraseCategories ?? {};
  const readingCategories = content?.readingCategories ?? {};
  const inflections = content?.inflections ?? {};
  const audioMap = content?.audio ?? {};
  const grammarAffixes = Array.isArray(content?.grammarAffixes) ? content.grammarAffixes : [];
  const grammarBinyanim = Array.isArray(content?.grammarBinyanim) ? content.grammarBinyanim : [];
  const minimalPairs = Array.isArray(content?.minimalPairs) ? content.minimalPairs : [];
  const learningPath = Array.isArray(content?.learningPath) ? content.learningPath : [];

  // Build NFC-normalized lookup of audio recordings
  const audioNfc = new Set();
  const uniqueRecordings = new Set();
  for (const [key, value] of Object.entries(audioMap)) {
    audioNfc.add(key.normalize('NFC'));
    if (typeof value !== 'string' || !AUDIO_FILE_PATTERN.test(value)) {
      errors.push(`Invalid audio path for "${key}": ${String(value)}`);
    } else {
      uniqueRecordings.add(value);
    }
  }

  // Validate letters
  if (letters.length !== 22) {
    errors.push(`Expected 22 Hebrew letters, found ${letters.length}`);
  }
  const letterIds = new Set();
  const validConfusableIds = new Set();
  for (const letter of letters) {
    if (!isNonEmptyString(letter?.id)) {
      errors.push('Encountered a letter with an empty id');
      continue;
    }
    if (letterIds.has(letter.id)) {
      errors.push(`Duplicate letter id: ${letter.id}`);
    }
    letterIds.add(letter.id);
    validConfusableIds.add(letter.id);
    if (letter.sofit) {
      validConfusableIds.add(`${letter.id}_sofit`);
    }
    if (letter.sofit && !letter.sofitInfo) {
      errors.push(`Letter "${letter.id}" defines sofit "${letter.sofit}" without sofitInfo`);
    }
    if (letter.begadkefat && (!letter.begadkefat.withDagesh || !letter.begadkefat.withoutDagesh)) {
      errors.push(`Letter "${letter.id}" has incomplete begadkefat variants`);
    }
  }
  for (const letter of letters) {
    for (const refId of letter?.confusableWith ?? []) {
      if (!validConfusableIds.has(refId)) {
        errors.push(`Letter "${letter.id}" references unknown confusableWith id "${refId}"`);
      }
    }
  }

  // Validate DailyLetter.swift synchronization
  const dailyPath = dailyLetterSwiftPath ?? new URL('ios/App/Shared/DailyLetter.swift', rootUrl);
  try {
    const swiftSource = await readFile(dailyPath, 'utf8');
    const widgetIds = extractDailyLetterIds(swiftSource);
    const contentIds = letters.map((l) => l.id);
    if (widgetIds.length !== contentIds.length || widgetIds.some((id, idx) => id !== contentIds[idx])) {
      errors.push(
        `DailyLetter.swift alphabet IDs (${widgetIds.join(', ')}) do not match content.letters (${contentIds.join(', ')})`,
      );
    }
  } catch (err) {
    errors.push(`Failed to validate DailyLetter.swift: ${err.message}`);
  }

  // Validate words
  if (words.length === 0) {
    errors.push('Expected at least 1 word in content.words');
  }
  const wordIds = new Set();
  const wordById = new Map();
  for (const word of words) {
    if (!isNonEmptyString(word?.id)) {
      errors.push('Encountered a word with an empty id');
      continue;
    }
    if (wordIds.has(word.id)) {
      errors.push(`Duplicate word id: ${word.id}`);
    }
    wordIds.add(word.id);
    wordById.set(word.id, word);

    for (const field of ['hebrew', 'hebrewUnpointed', 'transliteration', 'meaningZh']) {
      if (!isNonEmptyString(word[field])) {
        errors.push(`Word "${word.id}" is missing required field "${field}"`);
      }
    }
    if (!Object.prototype.hasOwnProperty.call(wordCategories, word.category)) {
      errors.push(`Word "${word.id}" has unknown category "${word.category}"`);
    }
    if (!['common', 'regular', 'extended'].includes(word.frequency)) {
      errors.push(`Word "${word.id}" has unknown frequency "${word.frequency}"`);
    }
    if (!['beginner', 'intermediate', 'advanced'].includes(word.difficulty)) {
      errors.push(`Word "${word.id}" has unknown difficulty "${word.difficulty}"`);
    }
    if (isNonEmptyString(word.hebrew) && !audioNfc.has(word.hebrew.normalize('NFC'))) {
      errors.push(`Word "${word.id}" (${word.hebrew}) is missing an entry in audioManifest`);
    }
  }

  // Validate phrases
  if (phrases.length === 0) {
    errors.push('Expected at least 1 phrase in content.phrases');
  }
  const phraseIds = new Set();
  for (const phrase of phrases) {
    if (!isNonEmptyString(phrase?.id)) {
      errors.push('Encountered a phrase with an empty id');
      continue;
    }
    if (phraseIds.has(phrase.id)) {
      errors.push(`Duplicate phrase id: ${phrase.id}`);
    }
    phraseIds.add(phrase.id);
    if (!Object.prototype.hasOwnProperty.call(phraseCategories, phrase.scenario)) {
      errors.push(`Phrase "${phrase.id}" has unknown scenario "${phrase.scenario}"`);
    }
    if (!isNonEmptyString(phrase.hebrew) || !audioNfc.has(phrase.hebrew.normalize('NFC'))) {
      errors.push(`Phrase "${phrase.id}" (${phrase.hebrew}) is missing an entry in audioManifest`);
    }
  }

  // Validate readings
  if (readings.length === 0) {
    errors.push('Expected at least 1 reading in content.readings');
  }
  const readingIds = new Set();
  let totalSentences = 0;
  for (const reading of readings) {
    if (!isNonEmptyString(reading?.id)) {
      errors.push('Encountered a reading with an empty id');
      continue;
    }
    if (readingIds.has(reading.id)) {
      errors.push(`Duplicate reading id: ${reading.id}`);
    }
    readingIds.add(reading.id);
    if (!Object.prototype.hasOwnProperty.call(readingCategories, reading.category)) {
      errors.push(`Reading "${reading.id}" has unknown category "${reading.category}"`);
    }
    const sentences = Array.isArray(reading.sentences) ? reading.sentences : [];
    if (sentences.length < 1) {
      errors.push(`Reading "${reading.id}" has no sentences`);
    }
    for (const [idx, sentence] of sentences.entries()) {
      totalSentences += 1;
      if (!isNonEmptyString(sentence?.hebrew) || !audioNfc.has(sentence.hebrew.normalize('NFC'))) {
        errors.push(`Reading "${reading.id}" sentence #${idx + 1} is missing an entry in audioManifest`);
      }
    }
    const q = reading.question;
    const choicesLen = Array.isArray(q?.choices) ? q.choices.length : 0;
    if (!q || !Number.isInteger(q.correctIndex) || q.correctIndex < 0 || q.correctIndex >= choicesLen) {
      errors.push(`Reading "${reading.id}" has invalid question.correctIndex (${q?.correctIndex}) for ${choicesLen} choices`);
    }
  }

  // Validate inflections
  for (const wordId of Object.keys(inflections)) {
    if (!wordIds.has(wordId)) {
      errors.push(`Inflection entry "${wordId}" does not reference a known word id`);
    }
  }

  // Validate grammar affixes & binyanim
  if (grammarAffixes.length === 0) {
    errors.push('Expected at least 1 grammar affix item');
  }
  const affixIds = new Set();
  for (const affix of grammarAffixes) {
    if (!isNonEmptyString(affix?.id)) {
      errors.push('Encountered a grammar affix with an empty id');
      continue;
    }
    if (affixIds.has(affix.id)) {
      errors.push(`Duplicate grammar affix id: ${affix.id}`);
    }
    affixIds.add(affix.id);
    for (const example of affix.examples ?? []) {
      if (example.wordId && !wordIds.has(example.wordId)) {
        errors.push(`Grammar affix "${affix.id}" references unknown wordId "${example.wordId}"`);
      }
    }
  }

  if (grammarBinyanim.length === 0) {
    errors.push('Expected at least 1 grammar binyan item');
  }
  const binyanIds = new Set();
  for (const binyan of grammarBinyanim) {
    if (!isNonEmptyString(binyan?.id)) {
      errors.push('Encountered a grammar binyan with an empty id');
      continue;
    }
    if (binyanIds.has(binyan.id)) {
      errors.push(`Duplicate grammar binyan id: ${binyan.id}`);
    }
    binyanIds.add(binyan.id);
    for (const wordId of binyan.exampleWordIds ?? []) {
      if (!wordIds.has(wordId)) {
        errors.push(`Grammar binyan "${binyan.id}" references unknown wordId "${wordId}"`);
      }
    }
  }

  // Validate minimal pairs
  if (minimalPairs.length === 0) {
    errors.push('Expected at least 1 minimal pair item');
  }
  const minimalPairIds = new Set();
  for (const pair of minimalPairs) {
    if (!isNonEmptyString(pair?.id)) {
      errors.push('Encountered a minimal pair with an empty id');
      continue;
    }
    if (minimalPairIds.has(pair.id)) {
      errors.push(`Duplicate minimal pair id: ${pair.id}`);
    }
    minimalPairIds.add(pair.id);
    if (pair.firstWordId === pair.secondWordId) {
      errors.push(`Minimal pair "${pair.id}" uses identical wordId "${pair.firstWordId}"`);
    }
    const w1 = wordById.get(pair.firstWordId);
    const w2 = wordById.get(pair.secondWordId);
    if (!w1) errors.push(`Minimal pair "${pair.id}" references unknown firstWordId "${pair.firstWordId}"`);
    if (!w2) errors.push(`Minimal pair "${pair.id}" references unknown secondWordId "${pair.secondWordId}"`);
    if (w1 && w2) {
      if (w1.ipa === w2.ipa) {
        errors.push(`Minimal pair "${pair.id}" (${w1.id} / ${w2.id}) shares identical IPA "${w1.ipa}"`);
      }
      if (!audioNfc.has(w1.hebrew.normalize('NFC'))) {
        errors.push(`Minimal pair "${pair.id}" firstWord "${w1.id}" is missing audio`);
      }
      if (!audioNfc.has(w2.hebrew.normalize('NFC'))) {
        errors.push(`Minimal pair "${pair.id}" secondWord "${w2.id}" is missing audio`);
      }
    }
  }

  // Validate learning path
  if (learningPath.length === 0) {
    errors.push('Expected at least 1 learning path stage');
  }
  const pathIds = new Set();
  const coveredLetters = new Set();
  let lastStageNumber = 0;
  for (const stage of learningPath) {
    if (!isNonEmptyString(stage?.id)) {
      errors.push('Encountered a learning path stage with an empty id');
      continue;
    }
    if (pathIds.has(stage.id)) {
      errors.push(`Duplicate learning path stage id: ${stage.id}`);
    }
    pathIds.add(stage.id);
    if (!Number.isInteger(stage.stage) || stage.stage <= lastStageNumber) {
      errors.push(`Learning path stage "${stage.id}" has non-increasing stage number ${stage.stage}`);
    }
    lastStageNumber = stage.stage;
    for (const lid of stage.letterIds ?? []) {
      if (!letterIds.has(lid)) {
        errors.push(`Learning path stage "${stage.id}" references unknown letterId "${lid}"`);
      }
      coveredLetters.add(lid);
    }
    for (const wid of stage.wordIds ?? []) {
      if (!wordIds.has(wid)) {
        errors.push(`Learning path stage "${stage.id}" references unknown wordId "${wid}"`);
      }
    }
    if (stage.readingId && !readingIds.has(stage.readingId)) {
      errors.push(`Learning path stage "${stage.id}" references unknown readingId "${stage.readingId}"`);
    }
  }
  if (coveredLetters.size !== letterIds.size) {
    const missingLetters = [...letterIds].filter((id) => !coveredLetters.has(id));
    errors.push(`Learning path does not cover all 22 letters (missing: ${missingLetters.join(', ')})`);
  }

  // Validate referenced recording files and static assets on disk
  await Promise.all([
    ...[...uniqueRecordings].map((relPath) =>
      ensureNonEmptyFile(new URL(`public/${relPath}`, rootUrl), `Recording public/${relPath}`, errors),
    ),
    ensureNonEmptyFile(new URL('public/audio/CREDITS.md', rootUrl), 'public/audio/CREDITS.md', errors),
    ensureNonEmptyFile(new URL('build/fonts/GveretLevin-Regular.ttf', rootUrl), 'build/fonts/GveretLevin-Regular.ttf', errors),
    ensureNonEmptyFile(new URL('build/fonts/GveretLevin-OFL.txt', rootUrl), 'build/fonts/GveretLevin-OFL.txt', errors),
  ]);

  if (errors.length > 0) {
    throw new Error(`Study content validation failed (${errors.length} issue(s)):\n- ${errors.join('\n- ')}`);
  }

  return {
    letters: letters.length,
    words: words.length,
    phrases: phrases.length,
    readings: readings.length,
    sentences: totalSentences,
    recordings: uniqueRecordings.size,
  };
}
