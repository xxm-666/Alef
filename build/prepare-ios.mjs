import { copyFile, mkdir, readFile, readdir, rm, writeFile } from 'node:fs/promises';
import { loadStudyContent, validateStudyContent } from './validate-content.mjs';

const root = new URL('../', import.meta.url);
const assets = new URL('ios/App/App/StudyAssets/', root);
const audioDir = new URL('audio/', assets);
const args = process.argv.slice(2);
const appStore = args.length === 1 && args[0] === '--app-store';
if (args.length && !appStore) throw new Error('Usage: npm run prepare:ios -- [--app-store]');

const content = await loadStudyContent(root);
const summary = await validateStudyContent(content, { rootUrl: root });
const audioSources = new Map(
  Array.from(new Set(Object.values(content.audio)), (name) => [name, new URL(`public/${name}`, root)]),
);
if (appStore) await selectAppStoreAudio(content, audioSources);
const expectedMp3Names = new Set(Array.from(audioSources.keys(), (name) => name.slice('audio/'.length)));

await mkdir(audioDir, { recursive: true });
const existingAudioEntries = await readdir(audioDir, { withFileTypes: true });
await Promise.all(
  existingAudioEntries
    .filter((entry) => entry.isFile() && entry.name.endsWith('.mp3') && !expectedMp3Names.has(entry.name))
    .map((entry) => rm(new URL(entry.name, audioDir))),
);

await Promise.all(Array.from(audioSources, ([name, source]) => copyFile(source, new URL(name, assets))));
await copyFile(new URL('public/audio/CREDITS.md', root), new URL('audio/CREDITS.md', assets));
await copyFile(new URL('public/privacy.txt', root), new URL('privacy.txt', assets));
await copyFile(new URL('build/fonts/GveretLevin-Regular.ttf', root), new URL('GveretLevin-Regular.ttf', assets));
await copyFile(new URL('build/fonts/GveretLevin-OFL.txt', root), new URL('GveretLevin-OFL.txt', assets));
await Promise.all([
  ['correct', 0.22, 523.25, 783.99, 0.12, 0.08, false],
  ['wrong', 0.2, 240, 175, 0.18, 0.07, true],
  ['flip', 0.08, 420, 420, 0.08, 0.03, false],
].map(([name, duration, start, end, sweep, volume, triangle]) =>
  writeFile(new URL(`audio/${name}.wav`, assets), feedbackWave(duration, start, end, sweep, volume, triangle))));
await writeFile(new URL('content.json', assets), JSON.stringify(content));
const widgetWords = content.words.map(({ id, hebrew, transliteration, meaningZh }) =>
  ({ id, hebrew, transliteration, meaningZh }));
await writeFile(new URL('widget-words.json', assets), JSON.stringify(widgetWords));
console.log(
  `Prepared ${summary.letters} letters, ${summary.words} words, ${summary.phrases} phrases, ` +
    `${summary.readings} readings and ${audioSources.size} recordings for iOS (${appStore ? 'App Store' : 'sideload'}).`,
);

async function selectAppStoreAudio(content, audioSources) {
  const credits = await readFile(new URL('public/audio/CREDITS.md', root), 'utf8');
  const documentedRecordings = new Set(Array.from(
    credits.matchAll(/^\| `(he_[a-f0-9]{12}\.mp3)` \|/gm),
    ([, filename]) => `audio/${filename}`,
  ));
  const originals = new URL('app-store-audio/', import.meta.url);
  const originalNames = new Set(await readdir(originals));
  for (const [name, source] of audioSources) {
    if (documentedRecordings.has(name) || await hasDocumentedSynthesis(source)) continue;
    const filename = name.slice('audio/'.length);
    if (originalNames.has(filename)) {
      const original = new URL(filename, originals);
      if (await hasDocumentedSynthesis(original)) {
        audioSources.set(name, original);
        continue;
      }
    }
    audioSources.delete(name);
  }
  content.audio = Object.fromEntries(Object.entries(content.audio).filter(([, name]) => audioSources.has(name)));
  const availableText = new Set(Object.keys(content.audio).map((text) => text.normalize('NFC')));
  for (const reading of content.readings) {
    for (const sentence of reading.sentences) {
      if (sentence.audio && !availableText.has(sentence.hebrew.normalize('NFC'))) delete sentence.audio;
    }
  }
}

async function hasDocumentedSynthesis(source) {
  const file = await readFile(source);
  if (file.subarray(0, 3).toString() !== 'ID3') return false;
  const tagLength = file.subarray(6, 10).reduce((length, byte) => length * 128 + byte, 0);
  const tags = file.subarray(10, 10 + tagLength).toString('utf8');
  return (tags.includes('thewh1teagle (Piper Noa)') && tags.includes('creativecommons.org/licenses/by/4.0/')) ||
    tags.includes('Synthesized by eSpeak NG') || tags.includes('Synthesized with eSpeak NG 1.52');
}

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
