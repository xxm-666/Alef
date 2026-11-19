export interface ConsonantItem {
  id: string;
  glyph: string;
  label: string;
  roman: string;
  ipa: string;
  isSilent?: boolean;
}

export const CONSONANT_OPTIONS: ConsonantItem[] = [
  { id: 'alef', glyph: 'א', label: 'Alef', roman: '', ipa: '∅', isSilent: true },
  { id: 'bet', glyph: 'בּ', label: 'Bet', roman: 'b', ipa: 'b' },
  { id: 'vet', glyph: 'ב', label: 'Vet', roman: 'v', ipa: 'v' },
  { id: 'gimel', glyph: 'ג', label: 'Gimel', roman: 'g', ipa: 'ɡ' },
  { id: 'dalet', glyph: 'ד', label: 'Dalet', roman: 'd', ipa: 'd' },
  { id: 'he', glyph: 'ה', label: 'He', roman: 'h', ipa: 'h' },
  { id: 'vav', glyph: 'ו', label: 'Vav', roman: 'v', ipa: 'v' },
  { id: 'zayin', glyph: 'ז', label: 'Zayin', roman: 'z', ipa: 'z' },
  { id: 'chet', glyph: 'ח', label: 'Chet', roman: 'ch', ipa: 'χ' },
  { id: 'tet', glyph: 'ט', label: 'Tet', roman: 't', ipa: 't' },
  { id: 'yod', glyph: 'י', label: 'Yod', roman: 'y', ipa: 'j' },
  { id: 'kaf', glyph: 'כּ', label: 'Kaf', roman: 'k', ipa: 'k' },
  { id: 'khaf', glyph: 'כ', label: 'Khaf', roman: 'kh', ipa: 'χ' },
  { id: 'lamed', glyph: 'ל', label: 'Lamed', roman: 'l', ipa: 'l' },
  { id: 'mem', glyph: 'מ', label: 'Mem', roman: 'm', ipa: 'm' },
  { id: 'nun', glyph: 'נ', label: 'Nun', roman: 'n', ipa: 'n' },
  { id: 'samekh', glyph: 'ס', label: 'Samekh', roman: 's', ipa: 's' },
  { id: 'ayin', glyph: 'ע', label: 'Ayin', roman: '', ipa: '∅', isSilent: true },
  { id: 'pe', glyph: 'פּ', label: 'Pe', roman: 'p', ipa: 'p' },
  { id: 'fe', glyph: 'פ', label: 'Fe', roman: 'f', ipa: 'f' },
  { id: 'tsadi', glyph: 'צ', label: 'Tsadi', roman: 'ts', ipa: 'ts' },
  { id: 'qof', glyph: 'ק', label: 'Qof', roman: 'k', ipa: 'k' },
  { id: 'resh', glyph: 'ר', label: 'Resh', roman: 'r', ipa: 'ʁ' },
  { id: 'shin', glyph: 'שׁ', label: 'Shin', roman: 'sh', ipa: 'ʃ' },
  { id: 'sin', glyph: 'שׂ', label: 'Sin', roman: 's', ipa: 's' },
  { id: 'tav', glyph: 'ת', label: 'Tav', roman: 't', ipa: 't' },
];

export interface VowelPattern {
  id: string;
  name: string;
  nameZh: string;
  mark: string;
  suffix?: string;
  vowelRoman: string;
  vowelIpa: string;
  tip: string;
}

export const VOWEL_PATTERNS: VowelPattern[] = [
  {
    id: 'kamatz',
    name: 'Kamatz (קָמָץ)',
    nameZh: 'a 音',
    mark: '\u05B8',
    vowelRoman: 'a',
    vowelIpa: 'a',
    tip: '下方 T 形符号，现代音读作 /a/（无重音闭音节的 Kamatz Katan 读 /o/）。',
  },
  {
    id: 'patach',
    name: 'Patach (פַּתַח)',
    nameZh: 'a 音',
    mark: '\u05B7',
    vowelRoman: 'a',
    vowelIpa: 'a',
    tip: '下方一横，现代固定读作 /a/。',
  },
  {
    id: 'tzere',
    name: 'Tzere (צֵירֵי)',
    nameZh: 'e 音',
    mark: '\u05B5',
    vowelRoman: 'e',
    vowelIpa: 'e',
    tip: '下方横向两点，现代读作 e 类单元音 /e/（类似「诶」）。',
  },
  {
    id: 'segol',
    name: 'Segol (סֶגּוֹל)',
    nameZh: 'e 音',
    mark: '\u05B6',
    vowelRoman: 'e',
    vowelIpa: 'e',
    tip: '下方倒三角三点，现代读作 e 类单元音 /e/（与 Tzere 同音）。',
  },
  {
    id: 'chirik',
    name: 'Chirik (חִירִיק)',
    nameZh: 'i 音',
    mark: '\u05B4',
    suffix: 'י',
    vowelRoman: 'i',
    vowelIpa: 'i',
    tip: '下方单点（常配 י），读作 /i/（类似「衣」）。',
  },
  {
    id: 'cholam',
    name: 'Cholam (חוֹלָם)',
    nameZh: 'o 音',
    mark: '',
    suffix: 'וֹ',
    vowelRoman: 'o',
    vowelIpa: 'o',
    tip: '字母上方或 ו 上方的圆点，读作 /o/（类似「喔」）。',
  },
  {
    id: 'shuruk',
    name: 'Shuruk (שׁוּרוּק)',
    nameZh: 'u 音',
    mark: '',
    suffix: 'וּ',
    vowelRoman: 'u',
    vowelIpa: 'u',
    tip: '字母 ו 中间带点（或下方斜三点 Kubutz），读作 /u/（类似「乌」）。',
  },
  {
    id: 'shva',
    name: 'Shva (שְׁוָא)',
    nameZh: '轻音 / 静音',
    mark: '\u05B0',
    vowelRoman: 'e',
    vowelIpa: 'ə / ∅',
    tip: '下方竖排两点：在音节尾静音；在词首既可静音（如 סְלִיחָה slicha），也可轻读 /e/（如 מְדַבֵּר medaber）。',
  },
];
