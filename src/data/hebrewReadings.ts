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
  {
    id: 'first-meeting',
    title: '初次见面',
    category: 'modern',
    sentences: [
      {
        hebrew: 'שָׁלוֹם, מַה שְׁלוֹמְךָ?',
        unpointed: 'שלום, מה שלומך?',
        transliteration: 'Shalom, ma shlomkha?',
        chinese: '你好，你最近怎么样？（对男性）',
      },
      {
        hebrew: 'הַכֹּל בְּסֵדֶר, תּוֹדָה!',
        unpointed: 'הכול בסדר, תודה!',
        transliteration: 'Hakol beseder, todah!',
        chinese: '一切都好，谢谢！',
      },
      {
        hebrew: 'קֹרְאִים לִי דָּוִד.',
        unpointed: 'קוראים לי דוד.',
        transliteration: 'Korim li David.',
        chinese: '我叫大卫。',
      },
      {
        hebrew: 'נָעִים מְאֹד לְהַכִּיר אוֹתְךָ.',
        unpointed: 'נעים מאוד להכיר אותך.',
        transliteration: 'Naim meod lehakir otkha.',
        chinese: '很高兴认识你。',
      },
    ],
    glosses: {
      שלומך: '你的平安/近况（对女性读作 shlomekh）。',
      הכול: '全部，一切（含定冠词 הַ־）。',
      בסדר: '没问题，很好（来自 בְּ + סֵדֶר）。',
      קוראים: '叫作；קֹרְאִים לִי 意为“人们叫我……”。',
      להכיר: '认识，结识（动词不定式）。',
    },
    question: { prompt: '说话人叫什么名字？', choices: ['达尼', '大卫', '玛雅'], correctIndex: 1 },
  },
  {
    id: 'ordering-lunch',
    title: '餐厅点餐',
    category: 'modern',
    sentences: [
      {
        hebrew: 'אֶפְשָׁר לְקַבֵּל תַּפְרִיט בְּבַקָּשָׁה?',
        unpointed: 'אפשר לקבל תפריט בבקשה?',
        transliteration: 'Efshar lekabel tafrit bevakasha?',
        chinese: '请问可以给我一份菜单吗？',
      },
      {
        hebrew: 'הַאִם יֵשׁ מָנָה צִמְחוֹנִית?',
        unpointed: 'האם יש מנה צמחונית?',
        transliteration: 'Haim yesh manah tzimchonit?',
        chinese: '请问有素食菜品吗？',
      },
      {
        hebrew: 'אֶפְשָׁר כּוֹס מַיִם קָרִים?',
        unpointed: 'אפשר כוס מים קרים?',
        transliteration: 'Efshar kos mayim karim?',
        chinese: '可以给我一杯冷水吗？',
      },
      {
        hebrew: 'זֶה טָעִים מְאֹד!',
        unpointed: 'זה טעים מאוד!',
        transliteration: 'Zeh taim meod!',
        chinese: '这非常好吃！',
      },
    ],
    glosses: {
      תפריט: '菜单。',
      האם: '是否（用于正式或礼貌的一般疑问句开头）。',
      מנה: '一份菜，菜品（阴性名词）。',
      קרים: '冷的、凉的（修饰复数名词 מַיִם 水）。',
      טעים: '美味的，好吃的。',
    },
    question: { prompt: '客人想确认餐厅里有没有什么？', choices: ['素食菜品', '热茶', '甜点'], correctIndex: 0 },
  },
  {
    id: 'asking-way',
    title: '问路去火车站',
    category: 'modern',
    sentences: [
      {
        hebrew: 'סְלִיחָה, אֵיפֹה תַּחֲנַת הָרַכֶּבֶת?',
        unpointed: 'סליחה, איפה תחנת הרכבת?',
        transliteration: 'Slicha, eifo tachanat ha-rakevet?',
        chinese: '打扰一下，火车站在哪里？',
      },
      {
        hebrew: 'לֵךְ יָשָׁר וְאַחַר כָּךְ פְּנֵה יָמִינָה.',
        unpointed: 'לך ישר ואחר כך פנה ימינה.',
        transliteration: 'Lech yashar ve-achar kach pne yaminah.',
        chinese: '直走，然后向右转。',
      },
      {
        hebrew: 'לֹא, זֶה קָרוֹב מְאֹד, חָמֵשׁ דַּקּוֹת בְּרֶגֶל.',
        unpointed: 'לא, זה קרוב מאוד, חמש דקות ברגל.',
        transliteration: 'Lo, zeh karov meod, chamesh dakot be-regel.',
        chinese: '不远，很近，步行五分钟就到。',
      },
    ],
    glosses: {
      תחנת: '……的车站（תַּחֲנָה 的构造态）。',
      הרכבת: '火车（定冠词 הָ־ 加在 ר 前不变加强点）。',
      ישר: '笔直地，直走。',
      ימינה: '向右（方向副词后缀 ־ָה）。',
      ברגל: '步行，走路（前缀 בְּ + רֶגֶל 脚）。',
    },
    question: { prompt: '步行到火车站大约需要多久？', choices: ['十五分钟', '五分钟', '半小时'], correctIndex: 1 },
  },
  {
    id: 'at-the-market',
    title: '逛店购物',
    category: 'modern',
    sentences: [
      {
        hebrew: 'כַּמָּה זֶה עוֹלֶה?',
        unpointed: 'כמה זה עולה?',
        transliteration: 'Kamah zeh oleh?',
        chinese: '这个多少钱？',
      },
      {
        hebrew: 'זֶה קְצָת יָקָר מִדַּי.',
        unpointed: 'זה קצת יקר מדי.',
        transliteration: 'Zeh ktzat yakar midai.',
        chinese: '这有点太贵了。',
      },
      {
        hebrew: 'אֶפְשָׁר לְשַׁלֵּם בְּכַרְטִיס אַשְׁרַאי?',
        unpointed: 'אפשר לשלם בכרטיס אשראי?',
        transliteration: 'Efshar leshalem be-khartis ashrai?',
        chinese: '可以刷信用卡付款吗？',
      },
      {
        hebrew: 'אֶפְשָׁר קַבָּלָה בְּבַקָּשָׁה?',
        unpointed: 'אפשר קבלה בבקשה?',
        transliteration: 'Efshar kabalah bevakasha?',
        chinese: '请问可以给我收据/小票吗？',
      },
    ],
    glosses: {
      עולה: '价格为、花费（来自 עוֹלֶה 上升/花费）。',
      יקר: '昂贵的，贵的。',
      לשלם: '付款（Pi\'el 不定式，来自词根 ש-ל-ם）。',
      אשראי: '信用（כַּרְטִיס אַשְׁרַאי 即信用卡）。',
      קבלה: '收据，小票。',
    },
    question: { prompt: '顾客最后向店员要了什么？', choices: ['袋子', '更大尺码', '收据'], correctIndex: 2 },
  },
  {
    id: 'hotel-airport',
    title: '酒店与机场',
    category: 'modern',
    sentences: [
      {
        hebrew: 'יֵשׁ לִי הַזְמָנָה עַל שֵׁם...',
        unpointed: 'יש לי הזמנה על שם...',
        transliteration: 'Yesh li hazmanah al shem...',
        chinese: '我有预订，预订姓名是……',
      },
      {
        hebrew: 'הִנֵּה הַדַּרְכּוֹן שֶׁלִּי.',
        unpointed: 'הנה הדרכון שלי.',
        transliteration: 'Hineh ha-darkon sheli.',
        chinese: '这是我的护照。',
      },
      {
        hebrew: 'מָה הַסִּיסְמָה שֶׁל הַוַּויְיפַאי?',
        unpointed: 'מה הסיסמה של הווייפאי?',
        transliteration: 'Ma ha-sismah shel ha-wifi?',
        chinese: 'Wi-Fi 密码是多少？',
      },
      {
        hebrew: 'מָתַי מֻגֶּשֶׁת אֲרוּחַת הַבֹּקֶר?',
        unpointed: 'מתי מוגשת ארוחת הבוקר?',
        transliteration: 'Matai mugeshet aruchat ha-boker?',
        chinese: '早餐几点供应？',
      },
    ],
    glosses: {
      הזמנה: '预订，订单。',
      הדרכון: '护照（前缀 הַ־ + דַּרְכּוֹן）。',
      שלי: '我的（独立所有格 שֶׁלִּי）。',
      הסיסמה: '密码。',
      מוגשת: '被供应、端上（Huf\'al 被动分词，来自词根 נ-ג-ש）。',
    },
    question: { prompt: '客人询问了哪两件事？', choices: ['退房时间与行李', 'Wi-Fi 密码与早餐时间', '登机口与出租车'], correctIndex: 1 },
  },
  {
    id: 'learning-hebrew',
    title: '聊聊学希伯来语',
    category: 'modern',
    sentences: [
      {
        hebrew: 'אֲנִי לוֹמֵד עִבְרִית לְאַט לְאַט.',
        unpointed: 'אני לומד עברית לאט לאט.',
        transliteration: 'Ani lomed Ivrit leat leat.',
        chinese: '我正在一步步学希伯来语。',
      },
      {
        hebrew: 'לֹא הֵבַנְתִּי, אֶפְשָׁר שׁוּב?',
        unpointed: 'לא הבנתי, אפשר שוב?',
        transliteration: 'Lo hevanti, efshar shuv?',
        chinese: '我没听懂，可以再说一遍吗？',
      },
      {
        hebrew: 'אֵיךְ אוֹמְרִים אֶת זֶה בְּעִבְרִית?',
        unpointed: 'איך אומרים את זה בעברית?',
        transliteration: 'Eikh omrim et zeh be-Ivrit?',
        chinese: '这个用希伯来语怎么说？',
      },
      {
        hebrew: 'כָּל הַכָּבוֹד! הָעִבְרִית שֶׁלְּךָ מְצֻיֶּנֶת.',
        unpointed: 'כל הכבוד! העברית שלך מצוינת.',
        transliteration: 'Kol ha-kavod! Ha-Ivrit shelkha metzuyenet.',
        chinese: '太棒了！你的希伯来语真不错。',
      },
    ],
    glosses: {
      לאט: '慢地；לְאַט לְאַט 表示“慢慢地、一步一步”。',
      הבנתי: '我明白了（Hif\'il 第一人称过去时）。',
      אומרים: '人们说（用来表达“……怎么说？”）。',
      בעברית: '用希伯来语（前缀 בְּ + עִבְרִית）。',
      מצוינת: '极好的，出色的（修饰阴性名词 הָעִבְרִית）。',
    },
    question: { prompt: '想请对方再重复一遍时怎么说？', choices: ['אֶפְשָׁר שׁוּב?', 'מָה זֹאת אוֹמֶרֶת?', 'כַּמָּה זֶה עוֹלֶה?'], correctIndex: 0 },
  },
];
