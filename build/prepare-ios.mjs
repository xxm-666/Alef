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
      export { DEFAULT_DISPLAY_CONFIG as defaultDisplay, DISPLAY_PRESETS as displayPresets } from './src/data/letterDisplay';
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
await copyFile(new URL('public/audio/CREDITS.md', root), new URL('audio/CREDITS.md', assets));
await copyFile(new URL('build/fonts/GveretLevin-Regular.ttf', root), new URL('GveretLevin-Regular.ttf', assets));
await copyFile(new URL('build/fonts/GveretLevin-OFL.txt', root), new URL('GveretLevin-OFL.txt', assets));
await Promise.all([
  ['correct', 0.22, 523.25, 783.99, 0.12, 0.08, false],
  ['wrong', 0.2, 240, 175, 0.18, 0.07, true],
  ['flip', 0.08, 420, 420, 0.08, 0.03, false],
].map(([name, duration, start, end, sweep, volume, triangle]) =>
  writeFile(new URL(`audio/${name}.wav`, assets), feedbackWave(duration, start, end, sweep, volume, triangle))));
await writeFile(new URL('content.json', assets), JSON.stringify(content));
console.log(`Prepared ${content.letters.length} letters, ${content.words.length} words and ${files.length} recordings for iOS.`);

function feedbackWave(duration, startFrequency, endFrequency, sweep, volume, triangle) {
  const sampleRate = 24_000;
  const frames = Math.round(duration * sampleRate);
  const wave = Buffer.alloc(44 + frames * 2);
  wave.write('RIFF', 0);
  wave.writeUInt32LE(wave.length - 8, 4);
  wave.write('WAVEfmt ', 8);
  wave.writeUInt32LE(16, 16);
  wave.writeUInt16LE(1, 20);
  wave.writeUInt16LE(1, 22);
  wave.writeUInt32LE(sampleRate, 24);
  wave.writeUInt32LE(sampleRate * 2, 28);
  wave.writeUInt16LE(2, 32);
  wave.writeUInt16LE(16, 34);
  wave.write('data', 36);
  wave.writeUInt32LE(frames * 2, 40);

  let phase = 0;
  for (let index = 0; index < frames; index += 1) {
    const time = index / sampleRate;
    const frequency = startFrequency * (endFrequency / startFrequency) ** Math.min(1, time / sweep);
    phase += 2 * Math.PI * frequency / sampleRate;
    const sine = Math.sin(phase);
    const sample = triangle ? Math.asin(sine) * 2 / Math.PI : sine;
    const envelope = volume * (0.001 / volume) ** (time / duration) * Math.min(1, time / 0.004);
    wave.writeInt16LE(Math.round(sample * envelope * 32_767), 44 + index * 2);
  }
  return wave;
}
