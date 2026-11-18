export type PhraseScenario =
  | 'greetings'
  | 'dining'
  | 'directions'
  | 'shopping'
  | 'travel'
  | 'study';

export interface HebrewPhrase {
  id: string;
  scenario: PhraseScenario;
  hebrew: string;
  hebrewUnpointed: string;
  transliteration: string;
  meaningZh: string;
  note?: string;
}

export const PHRASE_SCENARIO_META: Record<PhraseScenario, { label: string }> = {
  greetings: { label: '打招呼与寒暄' },
  dining: { label: '餐厅与点餐' },
  directions: { label: '问路与交通' },
  shopping: { label: '购物与付款' },
  travel: { label: '酒店与机场' },
  study: { label: '学习与交流' },
};

export const HEBREW_PHRASES: HebrewPhrase[] = [
  // 打招呼与寒暄
  {
    id: 'p-greet-1',
    scenario: 'greetings',
    hebrew: 'שָׁלוֹם, מַה שְׁלוֹמְךָ?',
    hebrewUnpointed: 'שלום, מה שלומך?',
    transliteration: 'Shalom, ma shlomkha?',
    meaningZh: '你好，你最近怎么样？（对男性）',
    note: '对女性问候说 מַה שְׁלוֹמֵךְ? (ma shlomekh)。',
  },
  {
    id: 'p-greet-2',
    scenario: 'greetings',
    hebrew: 'הַכֹּל בְּסֵדֶר, תּוֹדָה!',
    hebrewUnpointed: 'הכול בסדר, תודה!',
    transliteration: 'Hakol beseder, todah!',
    meaningZh: '一切都好，谢谢！',
  },
  {
    id: 'p-greet-3',
    scenario: 'greetings',
    hebrew: 'נָעִים מְאֹד לְהַכִּיר אוֹתְךָ.',
    hebrewUnpointed: 'נעים מאוד להכיר אותך.',
    transliteration: 'Naim meod lehakir otkha.',
    meaningZh: '很高兴认识你。',
  },
  {
    id: 'p-greet-4',
    scenario: 'greetings',
    hebrew: 'קֹרְאִים לִי דָּוִד.',
    hebrewUnpointed: 'קוראים לי דוד.',
    transliteration: 'Korim li David.',
    meaningZh: '我叫大卫。',
  },
  {
    id: 'p-greet-5',
    scenario: 'greetings',
    hebrew: 'אֵיךְ קוֹרְאִים לְךָ?',
    hebrewUnpointed: 'איך קוראים לך?',
    transliteration: 'Eikh korim lekha?',
    meaningZh: '你叫什么名字？',
  },
  {
    id: 'p-greet-6',
    scenario: 'greetings',
    hebrew: 'אֲנִי מִסִּין.',
    hebrewUnpointed: 'אני מסין.',
    transliteration: 'Ani mi-Sin.',
    meaningZh: '我来自中国。',
  },
  {
    id: 'p-greet-7',
    scenario: 'greetings',
    hebrew: 'שֶׁיִּהְיֶה לְךָ יוֹם נִפְלָא!',
    hebrewUnpointed: 'שיהיה לך יום נפלא!',
    transliteration: 'She-yihyeh lekha yom nifla!',
    meaningZh: '祝你今天愉快！',
  },
  {
    id: 'p-greet-8',
    scenario: 'greetings',
    hebrew: 'לְהִתְרָאוֹת בְּקָרוֹב!',
    hebrewUnpointed: 'להתראות בקרוב!',
    transliteration: 'Lehitraot bekarov!',
    meaningZh: '回头见！',
  },

  // 餐厅与点餐
  {
    id: 'p-dine-1',
    scenario: 'dining',
    hebrew: 'אֶפְשָׁר לְקַבֵּל תַּפְרִיט בְּבַקָּשָׁה?',
    hebrewUnpointed: 'אפשר לקבל תפריט בבקשה?',
    transliteration: 'Efshar lekabel tafrit bevakasha?',
    meaningZh: '请问可以给我一份菜单吗？',
  },
  {
    id: 'p-dine-2',
    scenario: 'dining',
    hebrew: 'אֲנִי רוֹצֶה קָפֶה הָפוּךְ, בְּבַקָּשָׁה.',
    hebrewUnpointed: 'אני רוצה קפה הפוך, בבקשה.',
    transliteration: 'Ani rotzeh kafeh hafuch, bevakasha.',
    meaningZh: '我想要一杯拿铁咖啡，谢谢。',
    note: 'קָפֶה הָפוּךְ（倒过来的咖啡）是以色列咖啡馆最常用的拿铁叫法。',
  },
  {
    id: 'p-dine-3',
    scenario: 'dining',
    hebrew: 'אֶפְשָׁר כּוֹס מַיִם קָרִים?',
    hebrewUnpointed: 'אפשר כוס מים קרים?',
    transliteration: 'Efshar kos mayim karim?',
    meaningZh: '可以给我一杯冷水吗？',
  },
  {
    id: 'p-dine-4',
    scenario: 'dining',
    hebrew: 'זֶה טָעִים מְאֹד!',
    hebrewUnpointed: 'זה טעים מאוד!',
    transliteration: 'Zeh taim meod!',
    meaningZh: '这非常好吃！',
  },
  {
    id: 'p-dine-5',
    scenario: 'dining',
    hebrew: 'הַאִם יֵשׁ מָנָה צִמְחוֹנִית?',
    hebrewUnpointed: 'האם יש מנה צמחונית?',
    transliteration: 'Haim yesh manah tzimchonit?',
    meaningZh: '请问有素食菜品吗？',
  },
  {
    id: 'p-dine-6',
    scenario: 'dining',
    hebrew: 'בְּלִי סֻכָּר, בְּבַקָּשָׁה.',
    hebrewUnpointed: 'בלי סוכר, בבקשה.',
    transliteration: 'Bli sukar, bevakasha.',
    meaningZh: '请不要加糖。',
  },
  {
    id: 'p-dine-7',
    scenario: 'dining',
    hebrew: 'אֶפְשָׁר אֶת הַחֶשְׁבּוֹן בְּבַקָּשָׁה?',
    hebrewUnpointed: 'אפשר את החשבון בבקשה?',
    transliteration: 'Efshar et ha-cheshbon bevakasha?',
    meaningZh: '请问可以买单吗？',
  },
  {
    id: 'p-dine-8',
    scenario: 'dining',
    hebrew: 'בְּתֵאָבוֹן!',
    hebrewUnpointed: 'בתיאבון!',
    transliteration: 'Be-teavon!',
    meaningZh: '祝你好胃口（请慢用）！',
  },

  // 问路与交通
  {
    id: 'p-dir-1',
    scenario: 'directions',
    hebrew: 'סְלִיחָה, אֵיפֹה תַּחֲנַת הָרַכֶּבֶת?',
    hebrewUnpointed: 'סליחה, איפה תחנת הרכבת?',
    transliteration: 'Slicha, eifo tachanat ha-rakevet?',
    meaningZh: '打扰一下，火车站在哪里？',
  },
  {
    id: 'p-dir-2',
    scenario: 'directions',
    hebrew: 'אֵיךְ מַגִּיעִים לְשָׁם?',
    hebrewUnpointed: 'איך מגיעים לשם?',
    transliteration: 'Eikh magiim le-sham?',
    meaningZh: '请问怎么去那里？',
  },
  {
    id: 'p-dir-3',
    scenario: 'directions',
    hebrew: 'לֵךְ יָשָׁר וְאַחַר כָּךְ פְּנֵה יָמִינָה.',
    hebrewUnpointed: 'לך ישר ואחר כך פנה ימינה.',
    transliteration: 'Lech yashar ve-achar kach peneh yaminah.',
    meaningZh: '直走，然后向右转。',
  },
  {
    id: 'p-dir-4',
    scenario: 'directions',
    hebrew: 'הַאִם זֶה רָחוֹק מִכָּאן?',
    hebrewUnpointed: 'האם זה רחוק מכאן?',
    transliteration: 'Haim zeh rachok mikan?',
    meaningZh: '离这里远吗？',
  },
  {
    id: 'p-dir-5',
    scenario: 'directions',
    hebrew: 'לֹא, זֶה קָרוֹב מְאֹד, חָמֵשׁ דַּקּוֹת בְּרֶגֶל.',
    hebrewUnpointed: 'לא, זה קרוב מאוד, חמש דקות ברגל.',
    transliteration: 'Lo, zeh karov meod, chamesh dakot ba-regel.',
    meaningZh: '不远，很近，步行五分钟就到。',
  },
  {
    id: 'p-dir-6',
    scenario: 'directions',
    hebrew: 'אֵיפֹה הַשֵּׁרוּתִים בְּבַקָּשָׁה?',
    hebrewUnpointed: 'איפה השירותים בבקשה?',
    transliteration: 'Eifo ha-sherutim bevakasha?',
    meaningZh: '请问洗手间在哪里？',
  },
  {
    id: 'p-dir-7',
    scenario: 'directions',
    hebrew: 'אֲנִי צָרִיךְ לְהַגִּיעַ לִירוּשָׁלַיִם.',
    hebrewUnpointed: 'אני צריך להגיע לירושלים.',
    transliteration: 'Ani tzarich lehagia li-Yerushalayim.',
    meaningZh: '我需要去耶路撒冷。',
  },
  {
    id: 'p-dir-8',
    scenario: 'directions',
    hebrew: 'מָתַי יוֹצֵא הָאוֹטוֹבּוּס הַבָּא?',
    hebrewUnpointed: 'מתי יוצא האוטובוס הבא?',
    transliteration: 'Matai yotze ha-otobus ha-ba?',
    meaningZh: '下一班公交车什么时候发车？',
  },

  // 购物与付款
  {
    id: 'p-shop-1',
    scenario: 'shopping',
    hebrew: 'כַּמָּה זֶה עוֹלֶה?',
    hebrewUnpointed: 'כמה זה עולה?',
    transliteration: 'Kamah zeh oleh?',
    meaningZh: '这个多少钱？',
  },
  {
    id: 'p-shop-2',
    scenario: 'shopping',
    hebrew: 'אֶפְשָׁר לְשַׁלֵּם בְּכַרְטִיס אַשְׁרַאי?',
    hebrewUnpointed: 'אפשר לשלם בכרטיס אשראי?',
    transliteration: 'Efshar leshalem be-khartis ashrai?',
    meaningZh: '可以刷信用卡付款吗？',
  },
  {
    id: 'p-shop-3',
    scenario: 'shopping',
    hebrew: 'זֶה קְצָת יָקָר מִדַּי.',
    hebrewUnpointed: 'זה קצת יקר מדי.',
    transliteration: 'Zeh ktzat yakar midai.',
    meaningZh: '这有点太贵了。',
  },
  {
    id: 'p-shop-4',
    scenario: 'shopping',
    hebrew: 'אֲנִי רַק מִסְתַּכֵּל, תּוֹדָה.',
    hebrewUnpointed: 'אני רק מסתכל, תודה.',
    transliteration: 'Ani rak mistakel, todah.',
    meaningZh: '我只是随便看看，谢谢。',
  },
  {
    id: 'p-shop-5',
    scenario: 'shopping',
    hebrew: 'יֵשׁ לָכֶם מִדָּה גְּדוֹלָה יוֹתֵר?',
    hebrewUnpointed: 'יש לכם מידה גדולה יותר?',
    transliteration: 'Yesh lakhem midah gedolah yoter?',
    meaningZh: '你们有更大一号的尺码吗？',
  },
  {
    id: 'p-shop-6',
    scenario: 'shopping',
    hebrew: 'אֶפְשָׁר שַׂקִּית בְּבַקָּשָׁה?',
    hebrewUnpointed: 'אפשר שקית בבקשה?',
    transliteration: 'Efshar sakit bevakasha?',
    meaningZh: '请问可以给我一个袋子吗？',
  },
  {
    id: 'p-shop-7',
    scenario: 'shopping',
    hebrew: 'אֶפְשָׁר קַבָּלָה בְּבַקָּשָׁה?',
    hebrewUnpointed: 'אפשר קבלה בבקשה?',
    transliteration: 'Efshar kabalah bevakasha?',
    meaningZh: '请问可以给我收据/小票吗？',
  },
  {
    id: 'p-shop-8',
    scenario: 'shopping',
    hebrew: 'הַחֲנוּת פְּתוּחָה עַד שָׁעָה תֵּשַׁע.',
    hebrewUnpointed: 'החנות פתוחה עד שעה תשע.',
    transliteration: 'Ha-chanut petuchah ad shaah tesha.',
    meaningZh: '这家店营业到九点。',
  },

  // 酒店与机场
  {
    id: 'p-trav-1',
    scenario: 'travel',
    hebrew: 'יֵשׁ לִי הַזְמָנָה עַל שֵׁם...',
    hebrewUnpointed: 'יש לי הזמנה על שם...',
    transliteration: 'Yesh li hazmanah al shem...',
    meaningZh: '我有预订，预订姓名是……',
  },
  {
    id: 'p-trav-2',
    scenario: 'travel',
    hebrew: 'מָה הַסִּיסְמָה שֶׁל הַוַּויְיפַאי?',
    hebrewUnpointed: 'מה הסיסמה של הווייפאי?',
    transliteration: 'Ma ha-sismah shel ha-wifi?',
    meaningZh: 'Wi-Fi 密码是多少？',
  },
  {
    id: 'p-trav-3',
    scenario: 'travel',
    hebrew: 'הִנֵּה הַדַּרְכּוֹן שֶׁלִּי.',
    hebrewUnpointed: 'הנה הדרכון שלי.',
    transliteration: 'Hineh ha-darkon sheli.',
    meaningZh: '这是我的护照。',
  },
  {
    id: 'p-trav-4',
    scenario: 'travel',
    hebrew: 'מָתַי מֻגֶּשֶׁת אֲרוּחַת הַבֹּקֶר?',
    hebrewUnpointed: 'מתי מוגשת ארוחת הבוקר?',
    transliteration: 'Matai mugeshet aruchat ha-boker?',
    meaningZh: '早餐几点供应？',
  },
  {
    id: 'p-trav-5',
    scenario: 'travel',
    hebrew: 'אֵיפֹה שַׁעַר הָעֲלִיָּה לַמָּטוֹס?',
    hebrewUnpointed: 'איפה שער העלייה למטוס?',
    transliteration: 'Eifo shaar ha-aliyah la-matos?',
    meaningZh: '登机口在哪里？',
  },
  {
    id: 'p-trav-6',
    scenario: 'travel',
    hebrew: 'הַמִּזְוָדָה שֶׁלִּי לֹא הִגִּיעָה.',
    hebrewUnpointed: 'המזוודה שלי לא הגיעה.',
    transliteration: 'Ha-mizvadah sheli lo higiah.',
    meaningZh: '我的行李箱还没有到。',
  },

  // 学习与日常交流
  {
    id: 'p-study-1',
    scenario: 'study',
    hebrew: 'אֲנִי לוֹמֵד עִבְרִית לְאַט לְאַט.',
    hebrewUnpointed: 'אני לומד עברית לאט לאט.',
    transliteration: 'Ani lomed Ivrit leat leat.',
    meaningZh: '我正在一步步学希伯来语。',
  },
  {
    id: 'p-study-2',
    scenario: 'study',
    hebrew: 'אֶפְשָׁר לְדַבֵּר יוֹתֵר לְאַט, בְּבַקָּשָׁה?',
    hebrewUnpointed: 'אפשר לדבר יותר לאט, בבקשה?',
    transliteration: 'Efshar ledaber yoter leat, bevakasha?',
    meaningZh: '请问能说慢一点吗？',
  },
  {
    id: 'p-study-3',
    scenario: 'study',
    hebrew: 'לֹא הֵבַנְתִּי, אֶפְשָׁר שׁוּב?',
    hebrewUnpointed: 'לא הבנתי, אפשר שוב?',
    transliteration: 'Lo hevanti, efshar shuv?',
    meaningZh: '我没听懂，可以再说一遍吗？',
  },
  {
    id: 'p-study-4',
    scenario: 'study',
    hebrew: 'אֵיךְ אוֹמְרִים אֶת זֶה בְּעִבְרִית?',
    hebrewUnpointed: 'איך אומרים את זה בעברית?',
    transliteration: 'Eikh omrim et zeh be-Ivrit?',
    meaningZh: '这个用希伯来语怎么说？',
  },
  {
    id: 'p-study-5',
    scenario: 'study',
    hebrew: 'מָה זֹאת אוֹמֶרֶת?',
    hebrewUnpointed: 'מה זאת אומרת?',
    transliteration: 'Ma zot omeret?',
    meaningZh: '这是什么意思？',
  },
  {
    id: 'p-study-6',
    scenario: 'study',
    hebrew: 'כָּל הַכָּבוֹד! הָעִבְרִית שֶׁלְּךָ מְצֻיֶּנֶת.',
    hebrewUnpointed: 'כל הכבוד! העברית שלך מצוינת.',
    transliteration: 'Kol ha-kavod! Ha-Ivrit shelkha metzuyenet.',
    meaningZh: '太棒了！你的希伯来语真不错。',
  },
];
