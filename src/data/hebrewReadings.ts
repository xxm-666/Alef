interface ReadingSentence {
  hebrew: string;
  unpointed: string;
  transliteration: string;
  chinese: string;
}

export interface HebrewReading {
  id: string;
  title: string;
  category: 'modern' | 'classic';
  source?: string;
  sentences: ReadingSentence[];
  glosses: Record<string, string>;
  question: {
    prompt: string;
    choices: [string, string, string];
    correctIndex: 0 | 1 | 2;
  };
}

export const READING_CATEGORIES = {
  modern: '现代希伯来语',
  classic: '经典选读',
} as const;

export const HEBREW_READINGS: HebrewReading[] = [
  {
    id: 'introduction',
    title: '自我介绍',
    category: 'modern',
    sentences: [
      {
        hebrew: 'שָׁלוֹם! קוֹרְאִים לִי דָּנִי.',
        unpointed: 'שלום! קוראים לי דני.',
        transliteration: "Shalom! Kor'im li Dani.",
        chinese: '你好！我叫达尼。',
      },
      {
        hebrew: 'אֲנִי מִסִּין, וַאֲנִי גָּר בְּחֵיפָה.',
        unpointed: 'אני מסין, ואני גר בחיפה.',
        transliteration: 'Ani mi-Sin, va-ani gar be-Kheifa.',
        chinese: '我来自中国，住在海法。',
      },
      {
        hebrew: 'אֲנִי לוֹמֵד עִבְרִית כָּל יוֹם.',
        unpointed: 'אני לומד עברית כל יום.',
        transliteration: 'Ani lomed ivrit kol yom.',
        chinese: '我每天学希伯来语。',
      },
    ],
    glosses: {
      קוראים: '叫。在「קוֹרְאִים לִי…」里表示“我叫……”。',
      גר: '住。男性说 גָּר，女性说 גָּרָה。',
      בחיפה: '在海法。前缀 בְּ 表示“在”。',
      לומד: '学习。男性说 לוֹמֵד，女性说 לוֹמֶדֶת。',
      עברית: '希伯来语。',
    },
    question: { prompt: '达尼住在哪里？', choices: ['海法', '北京', '特拉维夫'], correctIndex: 0 },
  },
  {
    id: 'cafe',
    title: '在咖啡馆',
    category: 'modern',
    sentences: [
      {
        hebrew: 'אֶפְשָׁר כּוֹס קָפֶה בְּבַקָּשָׁה?',
        unpointed: 'אפשר כוס קפה בבקשה?',
        transliteration: 'Efshar kos kafe bevakasha?',
        chinese: '请问，可以来一杯咖啡吗？',
      },
      {
        hebrew: 'כֵּן. עִם חָלָב אוֹ בְּלִי חָלָב?',
        unpointed: 'כן. עם חלב או בלי חלב?',
        transliteration: 'Ken. Im khalav o bli khalav?',
        chinese: '可以。加奶还是不加奶？',
      },
      {
        hebrew: 'בְּלִי חָלָב, תּוֹדָה.',
        unpointed: 'בלי חלב, תודה.',
        transliteration: 'Bli khalav, toda.',
        chinese: '不加奶，谢谢。',
      },
    ],
    glosses: {
      אפשר: '可以。用在问句开头可以礼貌地提出请求。',
      כוס: '杯。一杯咖啡是 כּוֹס קָפֶה。',
      בבקשה: '请。',
      בלי: '没有，不加。',
      חלב: '牛奶。',
    },
    question: { prompt: '客人点了什么？', choices: ['加奶的咖啡', '不加奶的咖啡', '一杯热茶'], correctIndex: 1 },
  },
  {
    id: 'library',
    title: '去图书馆',
    category: 'modern',
    sentences: [
      {
        hebrew: 'אֲנִי הוֹלֵךְ לַסִּפְרִיָּה.',
        unpointed: 'אני הולך לספרייה.',
        transliteration: 'Ani holekh la-sifriya.',
        chinese: '我去图书馆。',
      },
      {
        hebrew: 'יֵשׁ שָׁם סֵפֶר בְּעִבְרִית.',
        unpointed: 'יש שם ספר בעברית.',
        transliteration: 'Yesh sham sefer be-ivrit.',
        chinese: '那里有一本希伯来语书。',
      },
      {
        hebrew: 'אֲנִי קוֹרֵא שְׁנֵי עַמּוּדִים.',
        unpointed: 'אני קורא שני עמודים.',
        transliteration: 'Ani kore shnei amudim.',
        chinese: '我读两页。',
      },
    ],
    glosses: {
      הולך: '走，去。男性说 הוֹלֵךְ，女性说 הוֹלֶכֶת。',
      לספריה: '去图书馆。',
      לספרייה: '去图书馆。',
      ספר: '书。',
      קורא: '阅读。男性说 קוֹרֵא，女性说 קוֹרֵאת。',
      עמודים: '页。单数是 עַמּוּד。',
    },
    question: { prompt: '说话的人读几页？', choices: ['一页', '三页', '两页'], correctIndex: 2 },
  },
  {
    id: 'rainy-day',
    title: '下雨的一天',
    category: 'modern',
    sentences: [
      {
        hebrew: 'הַיּוֹם יוֹרֵד גֶּשֶׁם.',
        unpointed: 'היום יורד גשם.',
        transliteration: 'Hayom yored geshem.',
        chinese: '今天下雨了。',
      },
      {
        hebrew: 'מַיָּה פּוֹתַחַת אֶת הַחַלּוֹן.',
        unpointed: 'מאיה פותחת את החלון.',
        transliteration: 'Maya potakhat et ha-khalon.',
        chinese: '玛雅打开窗户。',
      },
      {
        hebrew: 'הִיא שׁוֹמַעַת אֶת הַגֶּשֶׁם וְשׁוֹתָה תֵּה חַם.',
        unpointed: 'היא שומעת את הגשם ושותה תה חם.',
        transliteration: 'Hi shoma’at et ha-geshem ve-shota te kham.',
        chinese: '她听着雨声，喝着热茶。',
      },
    ],
    glosses: {
      היום: '今天。',
      גשם: '雨。יוֹרֵד גֶּשֶׁם 的意思是“下雨”。',
      החלון: '窗户。前缀 הַ 是定冠词，这里指特定的窗户。',
      שומעת: '听见。这里用的是阴性单数形式。',
      תה: '茶。',
    },
    question: { prompt: '玛雅在喝什么？', choices: ['热茶', '咖啡', '牛奶'], correctIndex: 0 },
  },
  {
    id: 'genesis',
    title: '起初，要有光',
    category: 'classic',
    source: '《创世记》1:1、1:3',
    sentences: [
      {
        hebrew: 'בְּרֵאשִׁית בָּרָא אֱלֹהִים אֵת הַשָּׁמַיִם וְאֵת הָאָרֶץ.',
        unpointed: 'בראשית ברא אלוהים את השמיים ואת הארץ.',
        transliteration: 'Bereshit bara Elohim et ha-shamayim ve-et ha-aretz.',
        chinese: '起初，上帝创造了天地。',
      },
      {
        hebrew: 'וַיֹּאמֶר אֱלֹהִים יְהִי אוֹר, וַיְהִי אוֹר.',
        unpointed: 'ויאמר אלוהים יהי אור, ויהי אור.',
        transliteration: 'Vayomer Elohim, yehi or, vayehi or.',
        chinese: '上帝说：“要有光。”就有了光。',
      },
    ],
    glosses: {
      בראשית: '起初，最初。',
      ברא: '创造了。',
      יהי: '要有。这里表示命令，属于经典希伯来语的用法。',
      אור: '光。',
    },
    question: { prompt: '第一节说，上帝创造了什么？', choices: ['青草和树木', '天地', '海洋和鱼群'], correctIndex: 1 },
  },
  {
    id: 'psalm-23',
    title: '青草地与安静的水边',
    category: 'classic',
    source: '《诗篇》23:2–3',
    sentences: [
      {
        hebrew: 'בִּנְאוֹת דֶּשֶׁא יַרְבִּיצֵנִי, עַל־מֵי מְנֻחוֹת יְנַהֲלֵנִי.',
        unpointed: 'בנאות דשא ירביצני, על־מי מנוחות ינהלני.',
        transliteration: "Bin'ot deshe yarbitzeni, al mei menukhot yenahaleni.",
        chinese: '他让我躺在青草地上，领我到安静的水边。',
      },
      {
        hebrew: 'נַפְשִׁי יְשׁוֹבֵב, יַנְחֵנִי בְמַעְגְּלֵי־צֶדֶק לְמַעַן שְׁמוֹ.',
        unpointed: 'נפשי ישובב, ינחני במעגלי־צדק למען שמו.',
        transliteration: "Nafshi yeshovev, yankheni vema'gelei tzedek lema'an shemo.",
        chinese: '他使我的心复苏，为了他的名，引我走正直的路。',
      },
    ],
    glosses: {
      דשא: '草，青草。',
      ינהלני: '他领我。词尾 ־נִי 表示“我”。',
      מנוחות: '安歇。מֵי מְנֻחוֹת 指可以在旁安歇的水域。',
      נפשי: '我的心灵。词尾 ־ִי 表示“我的”。',
      צדק: '正直，公义。',
    },
    question: { prompt: '他后来引我走什么样的路？', choices: ['陡峭的山路', '回城的路', '正直的路'], correctIndex: 2 },
  },
];
