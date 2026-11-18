export interface FourFormInflection {
  kind: 'four-form';
  ms: { hebrew: string; translit: string };
  fs: { hebrew: string; translit: string };
  mp: { hebrew: string; translit: string };
  fp: { hebrew: string; translit: string };
}

export interface NounPluralInflection {
  kind: 'noun-plural';
  singular: { hebrew: string; translit: string; label: string };
  plural: { hebrew: string; translit: string; label: string };
}

export type WordInflection = FourFormInflection | NounPluralInflection;

export const WORD_INFLECTIONS: Record<string, WordInflection> = {
  // 高频动词现在时四态
  lomed: {
    kind: 'four-form',
    ms: { hebrew: 'לוֹמֵד', translit: 'lomed' },
    fs: { hebrew: 'לוֹמֶדֶת', translit: 'lomedet' },
    mp: { hebrew: 'לוֹמְדִים', translit: 'lomdim' },
    fp: { hebrew: 'לוֹמְדוֹת', translit: 'lomdot' },
  },
  kotev: {
    kind: 'four-form',
    ms: { hebrew: 'כּוֹתֵב', translit: 'kotev' },
    fs: { hebrew: 'כּוֹתֶבֶת', translit: 'kotevet' },
    mp: { hebrew: 'כּוֹתְבִים', translit: 'kotvim' },
    fp: { hebrew: 'כּוֹתְבוֹת', translit: 'kotvot' },
  },
  kore: {
    kind: 'four-form',
    ms: { hebrew: 'קוֹרֵא', translit: 'kore' },
    fs: { hebrew: 'קוֹרֵאת', translit: 'koret' },
    mp: { hebrew: 'קוֹרְאִים', translit: 'korim' },
    fp: { hebrew: 'קוֹרְאוֹת', translit: 'korot' },
  },
  medaber: {
    kind: 'four-form',
    ms: { hebrew: 'מְדַבֵּר', translit: 'medaber' },
    fs: { hebrew: 'מְדַבֶּרֶת', translit: 'medaberet' },
    mp: { hebrew: 'מְדַבְּרִים', translit: 'medabrim' },
    fp: { hebrew: 'מְדַבְּרוֹת', translit: 'medabrot' },
  },
  ohev: {
    kind: 'four-form',
    ms: { hebrew: 'אוֹהֵב', translit: 'ohev' },
    fs: { hebrew: 'אוֹהֶבֶת', translit: 'ohevet' },
    mp: { hebrew: 'אוֹהֲבִים', translit: 'ohavim' },
    fp: { hebrew: 'אוֹהֲבוֹת', translit: 'ohavot' },
  },
  holech: {
    kind: 'four-form',
    ms: { hebrew: 'הוֹלֵךְ', translit: 'holech' },
    fs: { hebrew: 'הוֹלֶכֶת', translit: 'holechet' },
    mp: { hebrew: 'הוֹלְכִים', translit: 'holkhim' },
    fp: { hebrew: 'הוֹלְכוֹת', translit: 'holkhot' },
  },
  rotzeh: {
    kind: 'four-form',
    ms: { hebrew: 'רוֹצֶה', translit: 'rotzeh' },
    fs: { hebrew: 'רוֹצָה', translit: 'rotzah' },
    mp: { hebrew: 'רוֹצִים', translit: 'rotzim' },
    fp: { hebrew: 'רוֹצוֹת', translit: 'rotzot' },
  },
  shomea: {
    kind: 'four-form',
    ms: { hebrew: 'שׁוֹמֵעַ', translit: 'shomea' },
    fs: { hebrew: 'שׁוֹמַעַת', translit: 'shomaat' },
    mp: { hebrew: 'שׁוֹמְעִים', translit: 'shomim' },
    fp: { hebrew: 'שׁוֹמְעוֹת', translit: 'shomot' },
  },
  roeh: {
    kind: 'four-form',
    ms: { hebrew: 'רוֹאֶה', translit: 'roeh' },
    fs: { hebrew: 'רוֹאָה', translit: 'roah' },
    mp: { hebrew: 'רוֹאִים', translit: 'roim' },
    fp: { hebrew: 'רוֹאוֹת', translit: 'root' },
  },
  yodea: {
    kind: 'four-form',
    ms: { hebrew: 'יוֹדֵעַ', translit: 'yodea' },
    fs: { hebrew: 'יוֹדַעַת', translit: 'yodaat' },
    mp: { hebrew: 'יוֹדְעִים', translit: 'yodim' },
    fp: { hebrew: 'יוֹדְעוֹת', translit: 'yodot' },
  },
  'ochel-verb': {
    kind: 'four-form',
    ms: { hebrew: 'אוֹכֵל', translit: 'okhel' },
    fs: { hebrew: 'אוֹכֶלֶת', translit: 'okhelet' },
    mp: { hebrew: 'אוֹכְלִים', translit: 'okhlim' },
    fp: { hebrew: 'אוֹכְלוֹת', translit: 'okhlot' },
  },
  shoteh: {
    kind: 'four-form',
    ms: { hebrew: 'שׁוֹתֶה', translit: 'shoteh' },
    fs: { hebrew: 'שׁוֹתָה', translit: 'shotah' },
    mp: { hebrew: 'שׁוֹתִים', translit: 'shotim' },
    fp: { hebrew: 'שׁוֹתוֹת', translit: 'shotot' },
  },
  ba: {
    kind: 'four-form',
    ms: { hebrew: 'בָּא', translit: 'ba' },
    fs: { hebrew: 'בָּאָה', translit: 'baah' },
    mp: { hebrew: 'בָּאִים', translit: 'baim' },
    fp: { hebrew: 'בָּאוֹת', translit: 'baot' },
  },
  gar: {
    kind: 'four-form',
    ms: { hebrew: 'גָּר', translit: 'gar' },
    fs: { hebrew: 'גָּרָה', translit: 'garah' },
    mp: { hebrew: 'גָּרִים', translit: 'garim' },
    fp: { hebrew: 'גָּרוֹת', translit: 'garot' },
  },
  mevin: {
    kind: 'four-form',
    ms: { hebrew: 'מֵבִין', translit: 'mevin' },
    fs: { hebrew: 'מְבִינָה', translit: 'mevinah' },
    mp: { hebrew: 'מְבִינִים', translit: 'mevinim' },
    fp: { hebrew: 'מְבִינוֹת', translit: 'mevinot' },
  },
  yoshev: {
    kind: 'four-form',
    ms: { hebrew: 'יוֹשֵׁב', translit: 'yoshev' },
    fs: { hebrew: 'יוֹשֶׁבֶת', translit: 'yoshevet' },
    mp: { hebrew: 'יוֹשְׁבִים', translit: 'yoshvim' },
    fp: { hebrew: 'יוֹשְׁבוֹת', translit: 'yoshvot' },
  },
  omed: {
    kind: 'four-form',
    ms: { hebrew: 'עוֹמֵד', translit: 'omed' },
    fs: { hebrew: 'עוֹמֶדֶת', translit: 'omedet' },
    mp: { hebrew: 'עוֹמְדִים', translit: 'omdim' },
    fp: { hebrew: 'עוֹמְדוֹת', translit: 'omdot' },
  },
  oseh: {
    kind: 'four-form',
    ms: { hebrew: 'עוֹשֶׂה', translit: 'oseh' },
    fs: { hebrew: 'עוֹשָׂה', translit: 'osah' },
    mp: { hebrew: 'עוֹשִׂים', translit: 'osim' },
    fp: { hebrew: 'עוֹשׂוֹת', translit: 'osot' },
  },
  yachol: {
    kind: 'four-form',
    ms: { hebrew: 'יָכוֹל', translit: 'yachol' },
    fs: { hebrew: 'יְכוֹלָה', translit: 'yekholah' },
    mp: { hebrew: 'יְכוֹלִים', translit: 'yekholim' },
    fp: { hebrew: 'יְכוֹלוֹת', translit: 'yekholot' },
  },
  tzarich: {
    kind: 'four-form',
    ms: { hebrew: 'צָרִיךְ', translit: 'tzarich' },
    fs: { hebrew: 'צְרִיכָה', translit: 'tzerichah' },
    mp: { hebrew: 'צְרִיכִים', translit: 'tzerichim' },
    fp: { hebrew: 'צְרִיכוֹת', translit: 'tzerichot' },
  },

  // 高频形容词性数四态
  tov: {
    kind: 'four-form',
    ms: { hebrew: 'טוֹב', translit: 'tov' },
    fs: { hebrew: 'טוֹבָה', translit: 'tovah' },
    mp: { hebrew: 'טוֹבִים', translit: 'tovim' },
    fp: { hebrew: 'טוֹבוֹת', translit: 'tovot' },
  },
  gadol: {
    kind: 'four-form',
    ms: { hebrew: 'גָּדוֹל', translit: 'gadol' },
    fs: { hebrew: 'גְּדוֹלָה', translit: 'gedolah' },
    mp: { hebrew: 'גְּדוֹלִים', translit: 'gedolim' },
    fp: { hebrew: 'גְּדוֹלוֹת', translit: 'gedolot' },
  },
  katan: {
    kind: 'four-form',
    ms: { hebrew: 'קָטָן', translit: 'katan' },
    fs: { hebrew: 'קְטַנָּה', translit: 'ketanah' },
    mp: { hebrew: 'קְטַנִּים', translit: 'ketanim' },
    fp: { hebrew: 'קְטַנּוֹת', translit: 'ketanot' },
  },
  chadash: {
    kind: 'four-form',
    ms: { hebrew: 'חָדָשׁ', translit: 'chadash' },
    fs: { hebrew: 'חֲדָשָׁה', translit: 'chadashah' },
    mp: { hebrew: 'חֲדָשִׁים', translit: 'chadashim' },
    fp: { hebrew: 'חֲדָשׁוֹת', translit: 'chadashot' },
  },
  yafeh: {
    kind: 'four-form',
    ms: { hebrew: 'יָפֶה', translit: 'yafeh' },
    fs: { hebrew: 'יָפָה', translit: 'yafah' },
    mp: { hebrew: 'יָפִים', translit: 'yafim' },
    fp: { hebrew: 'יָפוֹת', translit: 'yafot' },
  },
  cham: {
    kind: 'four-form',
    ms: { hebrew: 'חַם', translit: 'cham' },
    fs: { hebrew: 'חַמָּה', translit: 'chamah' },
    mp: { hebrew: 'חַמִּים', translit: 'chamim' },
    fp: { hebrew: 'חַמּוֹת', translit: 'chamot' },
  },
  kar: {
    kind: 'four-form',
    ms: { hebrew: 'קָר', translit: 'kar' },
    fs: { hebrew: 'קָרָה', translit: 'karah' },
    mp: { hebrew: 'קָרִים', translit: 'karim' },
    fp: { hebrew: 'קָרוֹת', translit: 'karot' },
  },

  // 高频名词单复数（含不规则复数）
  ish: {
    kind: 'noun-plural',
    singular: { hebrew: 'אִישׁ', translit: 'ish', label: '单数（阳性）' },
    plural: { hebrew: 'אֲנָשִׁים', translit: 'anashim', label: '复数（不规则）' },
  },
  isha: {
    kind: 'noun-plural',
    singular: { hebrew: 'אִשָּׁה', translit: 'ishah', label: '单数（阴性）' },
    plural: { hebrew: 'נָשִׁים', translit: 'nashim', label: '复数（不规则）' },
  },
  yeled: {
    kind: 'noun-plural',
    singular: { hebrew: 'יֶלֶד', translit: 'yeled', label: '单数（阳性）' },
    plural: { hebrew: 'יְלָדִים', translit: 'yeladim', label: '复数' },
  },
  yom: {
    kind: 'noun-plural',
    singular: { hebrew: 'יוֹם', translit: 'yom', label: '单数（阳性）' },
    plural: { hebrew: 'יָמִים', translit: 'yamim', label: '复数（不规则）' },
  },
  lailah: {
    kind: 'noun-plural',
    singular: { hebrew: 'לַיְלָה', translit: 'lailah', label: '单数（阳性）' },
    plural: { hebrew: 'לֵילוֹת', translit: 'leilot', label: '复数（-ות 结尾）' },
  },
  shanah: {
    kind: 'noun-plural',
    singular: { hebrew: 'שָׁנָה', translit: 'shanah', label: '单数（阴性）' },
    plural: { hebrew: 'שָׁנִים', translit: 'shanim', label: '复数（-ים 结尾）' },
  },
  bayit: {
    kind: 'noun-plural',
    singular: { hebrew: 'בַּיִת', translit: 'bayit', label: '单数（阳性）' },
    plural: { hebrew: 'בָּתִּים', translit: 'batim', label: '复数（不规则）' },
  },
  sefer: {
    kind: 'noun-plural',
    singular: { hebrew: 'סֵפֶר', translit: 'sefer', label: '单数（阳性）' },
    plural: { hebrew: 'סְפָרִים', translit: 'sfarim', label: '复数' },
  },
  ir: {
    kind: 'noun-plural',
    singular: { hebrew: 'עִיר', translit: 'ir', label: '单数（阴性）' },
    plural: { hebrew: 'עָרִים', translit: 'arim', label: '复数（不规则）' },
  },
  ben: {
    kind: 'noun-plural',
    singular: { hebrew: 'בֵּן', translit: 'ben', label: '单数（阳性）' },
    plural: { hebrew: 'בָּנִים', translit: 'banim', label: '复数' },
  },
  bat: {
    kind: 'noun-plural',
    singular: { hebrew: 'בַּת', translit: 'bat', label: '单数（阴性）' },
    plural: { hebrew: 'בָּנוֹת', translit: 'banot', label: '复数' },
  },
  davar: {
    kind: 'noun-plural',
    singular: { hebrew: 'דָּבָר', translit: 'davar', label: '单数（阳性）' },
    plural: { hebrew: 'דְּבָרִים', translit: 'dvarim', label: '复数' },
  },
  melech: {
    kind: 'noun-plural',
    singular: { hebrew: 'מֶלֶךְ', translit: 'melech', label: '单数（阳性）' },
    plural: { hebrew: 'מְלָכִים', translit: 'melakhim', label: '复数' },
  },
};
