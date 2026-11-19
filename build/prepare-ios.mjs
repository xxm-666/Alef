import { copyFile, mkdir, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { build } from 'esbuild';

const root = new URL('../', import.meta.url);
const assets = new URL('ios/App/App/StudyAssets/', root);
const { outputFiles: [bundle] } = await build({
  stdin: {
    resolveDir: fileURLToPath(root),
    contents: `
      export { HEBREW_LETTERS as letters, NIQQUD_ITEMS as niqqud, CONFUSABLE_GROUPS as confusables } from './src/data/hebrewLetters';
      export { HEBREW_WORDS as words, WORD_CATEGORY_META as wordCategories } from './src/data/hebrewWords';
      export { HEBREW_PHRASES as phrases, PHRASE_SCENARIO_META as phraseCategories } from './src/data/hebrewPhrases';
      export { HEBREW_READINGS as readings, READING_CATEGORIES as readingCategories } from './src/data/hebrewReadings';
      export { WORD_INFLECTIONS as inflections } from './src/data/wordInflections';
      export { CONSONANT_OPTIONS as consonants, VOWEL_PATTERNS as vowels } from './src/data/syllables';
      export { AUDIO_FILE_MAP as audio } from './src/data/audioManifest';
    `,
  },
  bundle: true,
  format: 'esm',
  platform: 'node',
  write: false,
});

const content = await import(`data:text/javascript;base64,${Buffer.from(bundle.contents).toString('base64')}`);
const files = [...new Set(Object.values(content.audio))];
await mkdir(new URL('audio/', assets), { recursive: true });
await Promise.all(files.map(async (name) => {
  if (!/^audio\/he_[a-f0-9]{12}\.mp3$/.test(name)) throw new Error(`Invalid recording path ${name}`);
  await copyFile(new URL(`public/${name}`, root), new URL(name, assets));
}));
await copyFile(new URL('build/fonts/GveretLevin-Regular.ttf', root), new URL('GveretLevin-Regular.ttf', assets));
await copyFile(new URL('build/fonts/GveretLevin-OFL.txt', root), new URL('GveretLevin-OFL.txt', assets));
await writeFile(new URL('content.json', assets), JSON.stringify(content));
console.log(`Prepared ${content.letters.length} letters, ${content.words.length} words and ${files.length} recordings for iOS.`);
