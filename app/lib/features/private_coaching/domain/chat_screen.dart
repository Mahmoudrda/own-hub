/// What the coaching chat refuses before it sends (and what the server hides
/// after): phone numbers, emails, handles and outside apps, payment details,
/// links and a short insult list.
///
/// The Python twin is `functions/coaching/chat.py`. Both give the same verdict
/// for every case in `contracts/coaching_chat_screen_vectors.json`, and the
/// steps below follow it one for one. If you change one, change the other.
///
/// The text is first normalised: decimal digits of any script become 0-9,
/// full-width letters become plain, Arabic marks, tatweel and zero-width marks
/// go, Arabic letter variants fold (أ إ آ ٱ to ا, ى to ي, ة to ه, ؤ to و,
/// ئ to ي) and the rest is lower-cased. Then, in this order, so a text gets
/// one reason:
///  1. contact: a run of digits (split by spaces, dots, dashes, commas,
///     slashes or brackets; a clock time ends a run, a letter O between
///     digits is a zero) that reads as an Egyptian mobile number or holds ten
///     or more digits, or seven or more spelled-out digits in a row.
///  2. payment: a wallet or transfer app name, in English or Arabic.
///  3. link: `http(s)://`, `www.`, or a name ending in a common domain.
///  4. contact again: an email, an @handle, an app name (WhatsApp, Telegram,
///     Instagram) or a weaker app word (ig, fb, snap, tiktok) with a handle.
///  5. abuse: a whole word from the insult list.
library;

enum ChatScreenReason { contact, payment, link, abuse }

abstract final class ChatScreen {
  /// Why [text] may not be sent, or null when it may.
  static ChatScreenReason? screen(String text) {
    final cased = normaliseCased(text);
    final folded = cased.toLowerCase();
    if (_hasContact(folded)) return ChatScreenReason.contact;
    if (_payment.hasMatch(folded)) return ChatScreenReason.payment;
    if (_hasLink(cased)) return ChatScreenReason.link;
    if (_hasOutsideContact(folded)) return ChatScreenReason.contact;
    if (_abuse.hasMatch(folded)) return ChatScreenReason.abuse;
    return null;
  }

  /// First code point of each block of decimal digits (category Nd).
  static const List<int> _digitZeros = <int>[
    0x0660, 0x06F0, 0x07C0, 0x0966, 0x09E6, 0x0A66, 0x0AE6, 0x0B66, //
    0x0BE6, 0x0C66, 0x0CE6, 0x0D66, 0x0E50, 0x0ED0, 0x0F20, 0x1040,
    0x17E0, 0x1810, 0xFF10,
  ];

  static const Map<int, int> _letters = <int, int>{
    0x0623: 0x0627, 0x0625: 0x0627, 0x0622: 0x0627, 0x0671: 0x0627, //
    0x0649: 0x064A, 0x0629: 0x0647, 0x0624: 0x0648, 0x0626: 0x064A,
  };

  static bool _dropped(int c) =>
      (c >= 0x064B && c <= 0x065F) ||
      c == 0x0670 ||
      (c >= 0x200B && c <= 0x200F) ||
      (c >= 0x202A && c <= 0x202E) ||
      (c >= 0x2066 && c <= 0x2069) ||
      c == 0x0640 ||
      c == 0xFEFF ||
      c == 0xFE0F ||
      c == 0x20E3;

  /// The compatibility forms NFKC makes plain on the server: maths letters
  /// and digits, superscripts, subscripts and circled forms. Null when [c] is
  /// none of them.
  static String? _compat(int c) {
    if (c >= 0x1D7CE && c <= 0x1D7FF) return '${(c - 0x1D7CE) % 10}';
    if (c >= 0x1D400 && c <= 0x1D6A3) {
      final i = (c - 0x1D400) % 52;
      return String.fromCharCode(i < 26 ? 0x41 + i : 0x61 + i - 26);
    }
    if (c >= 0x2080 && c <= 0x2089) return '${c - 0x2080}';
    if (c >= 0x2074 && c <= 0x2079) return '${c - 0x2070}';
    if (c == 0x2070) return '0';
    if (c == 0xB9) return '1';
    if (c == 0xB2) return '2';
    if (c == 0xB3) return '3';
    if (c >= 0x2460 && c <= 0x2473) return '${c - 0x2460 + 1}';
    if (c == 0x24EA) return '0';
    if (c >= 0x24B6 && c <= 0x24CF) {
      return String.fromCharCode(0x41 + c - 0x24B6);
    }
    if (c >= 0x24D0 && c <= 0x24E9) {
      return String.fromCharCode(0x61 + c - 0x24D0);
    }
    return null;
  }

  // Arabic presentation forms (U+FB50-FDFF, U+FE70-FEFF) to the letters NFKC
  // gives, as "hex=letters;" pairs read once.
  static const String _presentationData =
      'FB50=ٱ;FB51=ٱ;FB52=ٻ;FB53=ٻ;FB54=ٻ;FB55=ٻ;FB56=پ;FB57=پ;FB58=پ;FB59=پ;FB5A=ڀ;FB5B=ڀ;FB5C=ڀ;FB5D=ڀ;FB5E=ٺ;FB5F=ٺ;FB60=ٺ;FB61=ٺ;FB62=ٿ;FB63=ٿ;FB64=ٿ;FB65=ٿ;FB66=ٹ;FB67=ٹ;FB68=ٹ;FB69=ٹ;FB6A=ڤ;FB6B=ڤ;FB6C=ڤ;FB6D=ڤ;FB6E=ڦ;FB6F=ڦ;FB70=ڦ;FB71=ڦ;FB72=ڄ;FB73=ڄ;FB74=ڄ;FB75=ڄ;FB76=ڃ;FB77=ڃ;FB78=ڃ;FB79=ڃ;FB7A=چ;FB7B=چ;FB7C=چ;FB7D=چ;FB7E=ڇ;FB7F=ڇ;FB80=ڇ;FB81=ڇ;FB82=ڍ;FB83=ڍ;FB84=ڌ;FB85=ڌ;FB86=ڎ;FB87=ڎ;FB88=ڈ;FB89=ڈ;FB8A=ژ;FB8B=ژ;FB8C=ڑ;FB8D=ڑ;FB8E=ک;FB8F=ک;FB90=ک;FB91=ک;FB92=گ;FB93=گ;FB94=گ;FB95=گ;FB96=ڳ;FB97=ڳ;FB98=ڳ;FB99=ڳ;FB9A=ڱ;FB9B=ڱ;FB9C=ڱ;FB9D=ڱ;FB9E=ں;FB9F=ں;FBA0=ڻ;FBA1=ڻ;FBA2=ڻ;FBA3=ڻ;FBA4=ۀ;FBA5=ۀ;FBA6=ہ;FBA7=ہ;FBA8=ہ;FBA9=ہ;FBAA=ھ;FBAB=ھ;FBAC=ھ;FBAD=ھ;FBAE=ے;FBAF=ے;FBB0=ۓ;FBB1=ۓ;FBD3=ڭ;FBD4=ڭ;FBD5=ڭ;FBD6=ڭ;FBD7=ۇ;FBD8=ۇ;FBD9=ۆ;FBDA=ۆ;FBDB=ۈ;FBDC=ۈ;FBDD=ۇٴ;FBDE=ۋ;FBDF=ۋ;FBE0=ۅ;FBE1=ۅ;FBE2=ۉ;FBE3=ۉ;FBE4=ې;FBE5=ې;FBE6=ې;FBE7=ې;FBE8=ى;FBE9=ى;FBEA=ئا;FBEB=ئا;FBEC=ئە;FBED=ئە;FBEE=ئو;FBEF=ئو;FBF0=ئۇ;FBF1=ئۇ;FBF2=ئۆ;FBF3=ئۆ;FBF4=ئۈ;FBF5=ئۈ;FBF6=ئې;FBF7=ئې;FBF8=ئې;FBF9=ئى;FBFA=ئى;FBFB=ئى;FBFC=ی;FBFD=ی;FBFE=ی;FBFF=ی;FC00=ئج;FC01=ئح;FC02=ئم;FC03=ئى;FC04=ئي;FC05=بج;FC06=بح;FC07=بخ;FC08=بم;FC09=بى;FC0A=بي;FC0B=تج;FC0C=تح;FC0D=تخ;FC0E=تم;FC0F=تى;FC10=تي;FC11=ثج;FC12=ثم;FC13=ثى;FC14=ثي;FC15=جح;FC16=جم;FC17=حج;FC18=حم;FC19=خج;FC1A=خح;FC1B=خم;FC1C=سج;FC1D=سح;FC1E=سخ;FC1F=سم;FC20=صح;FC21=صم;FC22=ضج;FC23=ضح;FC24=ضخ;FC25=ضم;FC26=طح;FC27=طم;FC28=ظم;FC29=عج;FC2A=عم;FC2B=غج;FC2C=غم;FC2D=فج;FC2E=فح;FC2F=فخ;FC30=فم;FC31=فى;FC32=في;FC33=قح;FC34=قم;FC35=قى;FC36=قي;FC37=كا;FC38=كج;FC39=كح;FC3A=كخ;FC3B=كل;FC3C=كم;FC3D=كى;FC3E=كي;FC3F=لج;FC40=لح;FC41=لخ;FC42=لم;FC43=لى;FC44=لي;FC45=مج;FC46=مح;FC47=مخ;FC48=مم;FC49=مى;FC4A=مي;FC4B=نج;FC4C=نح;FC4D=نخ;FC4E=نم;FC4F=نى;FC50=ني;FC51=هج;FC52=هم;FC53=هى;FC54=هي;FC55=يج;FC56=يح;FC57=يخ;FC58=يم;FC59=يى;FC5A=يي;FC5B=ذٰ;FC5C=رٰ;FC5D=ىٰ;FC5E= ٌّ;FC5F= ٍّ;FC60= َّ;FC61= ُّ;FC62= ِّ;FC63= ّٰ;FC64=ئر;FC65=ئز;FC66=ئم;FC67=ئن;FC68=ئى;FC69=ئي;FC6A=بر;FC6B=بز;FC6C=بم;FC6D=بن;FC6E=بى;FC6F=بي;FC70=تر;FC71=تز;FC72=تم;FC73=تن;FC74=تى;FC75=تي;FC76=ثر;FC77=ثز;FC78=ثم;FC79=ثن;FC7A=ثى;FC7B=ثي;FC7C=فى;FC7D=في;FC7E=قى;FC7F=قي;FC80=كا;FC81=كل;FC82=كم;FC83=كى;FC84=كي;FC85=لم;FC86=لى;FC87=لي;FC88=ما;FC89=مم;FC8A=نر;FC8B=نز;FC8C=نم;FC8D=نن;FC8E=نى;FC8F=ني;FC90=ىٰ;FC91=ير;FC92=يز;FC93=يم;FC94=ين;FC95=يى;FC96=يي;FC97=ئج;FC98=ئح;FC99=ئخ;FC9A=ئم;FC9B=ئه;FC9C=بج;FC9D=بح;FC9E=بخ;FC9F=بم;FCA0=به;FCA1=تج;FCA2=تح;FCA3=تخ;FCA4=تم;FCA5=ته;FCA6=ثم;FCA7=جح;FCA8=جم;FCA9=حج;FCAA=حم;FCAB=خج;FCAC=خم;FCAD=سج;FCAE=سح;FCAF=سخ;FCB0=سم;FCB1=صح;FCB2=صخ;FCB3=صم;FCB4=ضج;FCB5=ضح;FCB6=ضخ;FCB7=ضم;FCB8=طح;FCB9=ظم;FCBA=عج;FCBB=عم;FCBC=غج;FCBD=غم;FCBE=فج;FCBF=فح;FCC0=فخ;FCC1=فم;FCC2=قح;FCC3=قم;FCC4=كج;FCC5=كح;FCC6=كخ;FCC7=كل;FCC8=كم;FCC9=لج;FCCA=لح;FCCB=لخ;FCCC=لم;FCCD=له;FCCE=مج;FCCF=مح;FCD0=مخ;FCD1=مم;FCD2=نج;FCD3=نح;FCD4=نخ;FCD5=نم;FCD6=نه;FCD7=هج;FCD8=هم;FCD9=هٰ;FCDA=يج;FCDB=يح;FCDC=يخ;FCDD=يم;FCDE=يه;FCDF=ئم;FCE0=ئه;FCE1=بم;FCE2=به;FCE3=تم;FCE4=ته;FCE5=ثم;FCE6=ثه;FCE7=سم;FCE8=سه;FCE9=شم;FCEA=شه;FCEB=كل;FCEC=كم;FCED=لم;FCEE=نم;FCEF=نه;FCF0=يم;FCF1=يه;FCF2=ـَّ;FCF3=ـُّ;FCF4=ـِّ;FCF5=طى;FCF6=طي;FCF7=عى;FCF8=عي;FCF9=غى;FCFA=غي;FCFB=سى;FCFC=سي;FCFD=شى;FCFE=شي;FCFF=حى;FD00=حي;FD01=جى;FD02=جي;FD03=خى;FD04=خي;FD05=صى;FD06=صي;FD07=ضى;FD08=ضي;FD09=شج;FD0A=شح;FD0B=شخ;FD0C=شم;FD0D=شر;FD0E=سر;FD0F=صر;FD10=ضر;FD11=طى;FD12=طي;FD13=عى;FD14=عي;FD15=غى;FD16=غي;FD17=سى;FD18=سي;FD19=شى;FD1A=شي;FD1B=حى;FD1C=حي;FD1D=جى;FD1E=جي;FD1F=خى;FD20=خي;FD21=صى;FD22=صي;FD23=ضى;FD24=ضي;FD25=شج;FD26=شح;FD27=شخ;FD28=شم;FD29=شر;FD2A=سر;FD2B=صر;FD2C=ضر;FD2D=شج;FD2E=شح;FD2F=شخ;FD30=شم;FD31=سه;FD32=شه;FD33=طم;FD34=سج;FD35=سح;FD36=سخ;FD37=شج;FD38=شح;FD39=شخ;FD3A=طم;FD3B=ظم;FD3C=اً;FD3D=اً;FD50=تجم;FD51=تحج;FD52=تحج;FD53=تحم;FD54=تخم;FD55=تمج;FD56=تمح;FD57=تمخ;FD58=جمح;FD59=جمح;FD5A=حمي;FD5B=حمى;FD5C=سحج;FD5D=سجح;FD5E=سجى;FD5F=سمح;FD60=سمح;FD61=سمج;FD62=سمم;FD63=سمم;FD64=صحح;FD65=صحح;FD66=صمم;FD67=شحم;FD68=شحم;FD69=شجي;FD6A=شمخ;FD6B=شمخ;FD6C=شمم;FD6D=شمم;FD6E=ضحى;FD6F=ضخم;FD70=ضخم;FD71=طمح;FD72=طمح;FD73=طمم;FD74=طمي;FD75=عجم;FD76=عمم;FD77=عمم;FD78=عمى;FD79=غمم;FD7A=غمي;FD7B=غمى;FD7C=فخم;FD7D=فخم;FD7E=قمح;FD7F=قمم;FD80=لحم;FD81=لحي;FD82=لحى;FD83=لجج;FD84=لجج;FD85=لخم;FD86=لخم;FD87=لمح;FD88=لمح;FD89=محج;FD8A=محم;FD8B=محي;FD8C=مجح;FD8D=مجم;FD8E=مخج;FD8F=مخم;FD92=مجخ;FD93=همج;FD94=همم;FD95=نحم;FD96=نحى;FD97=نجم;FD98=نجم;FD99=نجى;FD9A=نمي;FD9B=نمى;FD9C=يمم;FD9D=يمم;FD9E=بخي;FD9F=تجي;FDA0=تجى;FDA1=تخي;FDA2=تخى;FDA3=تمي;FDA4=تمى;FDA5=جمي;FDA6=جحى;FDA7=جمى;FDA8=سخى;FDA9=صحي;FDAA=شحي;FDAB=ضحي;FDAC=لجي;FDAD=لمي;FDAE=يحي;FDAF=يجي;FDB0=يمي;FDB1=ممي;FDB2=قمي;FDB3=نحي;FDB4=قمح;FDB5=لحم;FDB6=عمي;FDB7=كمي;FDB8=نجح;FDB9=مخي;FDBA=لجم;FDBB=كمم;FDBC=لجم;FDBD=نجح;FDBE=جحي;FDBF=حجي;FDC0=مجي;FDC1=فمي;FDC2=بحي;FDC3=كمم;FDC4=عجم;FDC5=صمم;FDC6=سخي;FDC7=نجي;FDF0=صلے;FDF1=قلے;FDF2=الله;FDF3=اكبر;FDF4=محمد;FDF5=صلعم;FDF6=رسول;FDF7=عليه;FDF8=وسلم;FDF9=صلى;FDFA=صلى الله عليه وسلم;FDFB=جل جلاله;FDFC=ریال;FE70= ً;FE71=ـً;FE72= ٌ;FE74= ٍ;FE76= َ;FE77=ـَ;FE78= ُ;FE79=ـُ;FE7A= ِ;FE7B=ـِ;FE7C= ّ;FE7D=ـّ;FE7E= ْ;FE7F=ـْ;FE80=ء;FE81=آ;FE82=آ;FE83=أ;FE84=أ;FE85=ؤ;FE86=ؤ;FE87=إ;FE88=إ;FE89=ئ;FE8A=ئ;FE8B=ئ;FE8C=ئ;FE8D=ا;FE8E=ا;FE8F=ب;FE90=ب;FE91=ب;FE92=ب;FE93=ة;FE94=ة;FE95=ت;FE96=ت;FE97=ت;FE98=ت;FE99=ث;FE9A=ث;FE9B=ث;FE9C=ث;FE9D=ج;FE9E=ج;FE9F=ج;FEA0=ج;FEA1=ح;FEA2=ح;FEA3=ح;FEA4=ح;FEA5=خ;FEA6=خ;FEA7=خ;FEA8=خ;FEA9=د;FEAA=د;FEAB=ذ;FEAC=ذ;FEAD=ر;FEAE=ر;FEAF=ز;FEB0=ز;FEB1=س;FEB2=س;FEB3=س;FEB4=س;FEB5=ش;FEB6=ش;FEB7=ش;FEB8=ش;FEB9=ص;FEBA=ص;FEBB=ص;FEBC=ص;FEBD=ض;FEBE=ض;FEBF=ض;FEC0=ض;FEC1=ط;FEC2=ط;FEC3=ط;FEC4=ط;FEC5=ظ;FEC6=ظ;FEC7=ظ;FEC8=ظ;FEC9=ع;FECA=ع;FECB=ع;FECC=ع;FECD=غ;FECE=غ;FECF=غ;FED0=غ;FED1=ف;FED2=ف;FED3=ف;FED4=ف;FED5=ق;FED6=ق;FED7=ق;FED8=ق;FED9=ك;FEDA=ك;FEDB=ك;FEDC=ك;FEDD=ل;FEDE=ل;FEDF=ل;FEE0=ل;FEE1=م;FEE2=م;FEE3=م;FEE4=م;FEE5=ن;FEE6=ن;FEE7=ن;FEE8=ن;FEE9=ه;FEEA=ه;FEEB=ه;FEEC=ه;FEED=و;FEEE=و;FEEF=ى;FEF0=ى;FEF1=ي;FEF2=ي;FEF3=ي;FEF4=ي;FEF5=لآ;FEF6=لآ;FEF7=لأ;FEF8=لأ;FEF9=لإ;FEFA=لإ;FEFB=لا;FEFC=لا';

  static final Map<int, List<int>> _presentation = () {
    final map = <int, List<int>>{};
    for (final pair in _presentationData.split(';')) {
      final cut = pair.indexOf('=');
      map[int.parse(pair.substring(0, cut), radix: 16)] = pair
          .substring(cut + 1)
          .runes
          .toList();
    }
    return map;
  }();

  /// [text] folded as in the class comment, but with its letters' case kept
  /// (a capital after a full stop starts a sentence, not a web address).
  static String normaliseCased(String text) {
    final out = StringBuffer();
    final runes = <int>[
      for (final r in text.runes) ...(_presentation[r] ?? <int>[r]),
    ];
    for (var c in runes) {
      // Full-width forms are plain ASCII under NFKC.
      if (c >= 0xFF01 && c <= 0xFF5E) c = c - 0xFF01 + 0x21;
      if (c == 0x3000) c = 0x20;
      final plain = _compat(c);
      if (plain != null) {
        out.write(plain);
        continue;
      }
      for (final zero in _digitZeros) {
        if (c >= zero && c <= zero + 9) {
          c = 0x30 + c - zero;
          break;
        }
      }
      if (_dropped(c)) continue;
      out.writeCharCode(_letters[c] ?? c);
    }
    return out.toString();
  }

  static String normalise(String text) => normaliseCased(text).toLowerCase();

  // ---------------------------------------------------------------- contact

  static const String _sep = r'[\s.\-–—,/():;]';
  static final RegExp _numberRun = RegExp('\\+?\\d(?:$_sep*\\d)*');
  static final RegExp _separators = RegExp('$_sep+');
  static final RegExp _clock = RegExp(r'(?<!\d)\d{1,2}:\d{2}(?::\d{2})?(?!\d)');
  // Dates and thousands-grouped figures are not phone digits; they break a run.
  static final RegExp _date = RegExp(
    r'(?<![\d/])\d{1,2}/\d{1,2}(?:/\d{2,4})?(?![\d/])'
    r'|(?<![\d./-])\d{1,2}[.-]\d{1,2}[.-]\d{2,4}(?![\d./-])'
    r'|(?<![\d.-])\d{4}[.-]\d{1,2}[.-]\d{1,2}(?![\d.-])',
  );
  static final RegExp _thousands = RegExp(
    r'(?<![\d,])[1-9]\d{0,2}(?:,\d{3})+(?!\d)',
  );
  static final RegExp _letterO = RegExp(r'(?<=\d)o|o(?=\d)');
  static final RegExp _mobile = RegExp(r'^1[0125]\d{8}$');
  static final RegExp _mobileAny = RegExp(r'^(?:20|0020|0)?1[0125]\d{8}$');
  static final RegExp _symbol = RegExp(r'[\p{S}*_·•]', unicode: true);

  static const Map<String, String> _wordDigits = <String, String>{
    'zero': '0', 'one': '1', 'two': '2', 'three': '3', 'four': '4', //
    'five': '5', 'six': '6', 'seven': '7', 'eight': '8', 'nine': '9',
    'صفر': '0', 'واحد': '1', 'اتنين': '2', 'اثنين': '2', 'اثنان': '2',
    'تلاته': '3', 'تلات': '3', 'ثلاثه': '3', 'ثلاث': '3', 'اربعه': '4',
    'اربع': '4', 'خمسه': '5', 'خمس': '5', 'سته': '6', 'ست': '6',
    'سبعه': '7', 'سبع': '7', 'تمانيه': '8', 'ثمانيه': '8', 'تمن': '8',
    'تسعه': '9', 'تسع': '9',
    // English digit words written in Arabic letters
    'زيرو': '0', 'وان': '1', 'تو': '2', 'فور': '4', 'ثري': '3', 'فايف': '5',
    'سيكس': '6', 'سفن': '7', 'ايت': '8', 'ناين': '9',
  };

  // "010 then 12345678": a word between two digit groups is a separator.
  static final RegExp _filler = RegExp(
    r'(?<=\d)[\s,]+(?:(?:then|and|dash|space|ثم|وبعدين|بعدين|بعد|و)[\s,]+)+(?=\d)',
    unicode: true,
  );

  static final RegExp _digitWord = RegExp(
    '(?<!\\p{L})(${(_wordDigits.keys.toList()..sort((a, b) => b.length.compareTo(a.length))).join('|')})(?!\\p{L})',
    unicode: true,
  );

  /// Sets, reps or kilos written in a row ("12 10 10 8 8 6", "22.5 25 27.5"):
  /// every number one or two digits and none starting with 0, which no phone
  /// number looks like.
  static bool _looksLikeCounts(List<String> g) =>
      g.length >= 2 && g.every((x) => x.length <= 2 && !x.startsWith('0'));

  /// 0 10 20 30 40 50: steps of five and ten, not digits someone chose.
  static bool _listy(List<String> g) =>
      g.every((x) => x.length <= 2 && '05'.contains(x[x.length - 1]));

  /// Whether these consecutive groups of digits read as one phone number.
  static bool _phoneWindow(List<String> g) {
    final d = g.join();
    if (g.length == 1) return d.length >= 10;
    if (g.length > 5 || g.any((x) => x.length > 8) || _looksLikeCounts(g)) {
      return false;
    }
    if (d.startsWith('0')) return g.length <= 4 && d.length >= 9;
    final rest = g[0] == '20' ? g.sublist(1) : g;
    if (!_mobile.hasMatch(rest.join())) return false;
    return rest.length == 1 ||
        (rest.length <= 4 && rest.every((x) => x.length <= 4));
  }

  /// One run of digits as written. A plus sign makes nine digits a number.
  /// Otherwise some stretch of its groups must read as one: ten digits in a
  /// row, a leading 0 with nine or more, 20 then a mobile, or a mobile without
  /// its 0. A short number in front ("Day 5 0101...") is skipped over, and a
  /// list ("100, 120, 140, 160") matches none of these.
  static bool _isPhone(String raw) {
    final groups = raw
        .replaceFirst(RegExp(r'^\++'), '')
        .split(_separators)
        .where((x) => x.isNotEmpty)
        .toList();
    if (raw.startsWith('+')) return groups.join().length >= 9;
    if (groups.length >= 10 && groups.every((x) => x.length == 1)) return true;
    for (var i = 0; i < groups.length; i++) {
      final last = groups.length < i + 12 ? groups.length : i + 12;
      for (var j = i + 1; j <= last; j++) {
        final w = groups.sublist(i, j);
        if (j - i <= 5 && _phoneWindow(w)) return true;
        // Pairs and single digits that add up to a mobile ("01 01 23 45 67 8").
        if (j - i >= 2 &&
            w.where((x) => x.length <= 2).length >= 2 &&
            w.every((x) => x.length <= 8) &&
            _mobileAny.hasMatch(w.join()) &&
            !_looksLikeCounts(w) &&
            !_listy(w)) {
          return true;
        }
      }
    }
    return false;
  }

  static bool _hasNumber(String folded) {
    // Digit words become digits; clock times, dates and 1,200 style figures
    // break a run; a letter O typed for a zero reads as one.
    final apart = folded.replaceAllMapped(
      _symbol,
      (m) => m[0] == '+' ? '+' : ' ',
    );
    final text = apart
        .replaceAllMapped(_digitWord, (m) => ' ${_wordDigits[m[1]]} ')
        .replaceAll(_filler, ' ')
        .replaceAll(_clock, ' t ')
        .replaceAll(_date, ' d ')
        .replaceAll(_thousands, ' n ')
        .replaceAll(_letterO, '0');
    return _numberRun.allMatches(text).any((r) => _isPhone(r.group(0)!));
  }

  static const String _digitWords =
      'zero|one|two|three|four|five|six|seven|eight|nine|'
      'صفر|واحد|اتنين|اثنين|اثنان|تلاته|تلات|ثلاثه|ثلاث|اربعه|اربع|خمسه|خمس|سته|ست|'
      'سبعه|سبع|تمانيه|ثمانيه|تمن|تسعه|تسع|زيرو|وان|تو|فور|ثري|فايف|سيكس|سفن|ايت|ناين';

  static final RegExp _spelled = RegExp(
    '(?:(?<!$_word)(?:$_digitWords)(?!$_word)[\\s,.\\-]*){7,}',
    unicode: true,
  );

  static bool _hasContact(String folded) =>
      _hasNumber(folded) || _spelled.hasMatch(folded);

  static final RegExp _email = RegExp(
    r'[a-z][a-z0-9._%+-]*@[a-z0-9-]+(?:\.[a-z0-9-]+)*\.[a-z]{2,}',
  );
  static final RegExp _emailSpoken = RegExp(
    '[a-z0-9._%+-]+\\s*(?:\\(at\\)|\\[at\\]|(?<!$_word)at(?!$_word))\\s*[a-z0-9-]+\\s*'
    '(?:\\(dot\\)|\\[dot\\]|(?<!$_word)dot(?!$_word))\\s*[a-z]{2,}',
    unicode: true,
  );
  // "r a h m a @ gmail . com": letters one at a time, or a well-known mail host.
  static final RegExp _emailSpaced = RegExp(
    r'(?:[a-z0-9]\s){3,}[a-z0-9]\s*@\s*[a-z0-9-]+\s*\.\s*[a-z]{2,}'
    r'|[a-z0-9._%+-]+\s*@\s*(?:gmail|yahoo|hotmail|outlook|icloud|proton\w*)(?![a-z0-9])'
    r'|[a-z0-9._%+-]+\s*@\s*(?:live|msn)\s*\.\s*[a-z]{2,}',
  );
  // An @name is a handle with a dot, underscore or digit in it, or the whole message.
  static final RegExp _handle = RegExp(
    '(?<!$_word)@[a-z][a-z0-9]*[._0-9][a-z0-9_.]*|^\\s*@[a-z][a-z0-9_.]{2,}\\s*\$',
    unicode: true,
  );

  static const Map<String, String> _leet = <String, String>{
    'a': '[a@4]', 'e': '[e3]', 'i': '[i1!]', 'o': '[o0]', 's': '[s5\$]', //
  };

  /// The word with spaces, dots, apostrophes or look-alike symbols in it:
  /// "what's app", "wh@tsapp", "tel3gram".
  static String _spaced(String word) =>
      '(?<!$_word)${word.split('').map((c) => _leet[c] ?? c).join("[\\s'’._-]*")}(?!$_word)';

  // Apps she must not move to, however the word is placed ("tele gram" too).
  static final RegExp _appStrong = RegExp(
    '(?<!$_word)(?:whats\\s?app|whatsap+|telegram|instagram|insta(?!\\s*pay))(?!$_word)'
    '|${<String>['whatsapp', 'watsapp', 'telegram', 'instagram'].map(_spaced).join('|')}'
    '|واتس|وتساب|تليجرام|تيليجرام|تلجرام|تلغرام|تيليغرام|تليغرام'
    '|(?<!$_word)(?:ال|ب|ل|ع|و)?(?:انستا(?!\\s*باي)|انستجرام|انستاجرام|انستغرام)(?!$_word)',
    unicode: true,
  );

  static const String _appWeak =
      '(?<!$_word)(?:ig|fb|snap|snapchat|tiktok|tik\\s?tok|facebook|tg)(?!$_word)'
      '|سناب|فيسبوك|فيس|تيك\\s?توك|تيكتوك';

  // A weaker app word counts only with a handle after it ("snap back" is fine).
  static final RegExp _appHandle = RegExp(
    '(?:$_appWeak)(?:\\s*[:=]\\s*@?\\s*[a-z0-9_.]{2,}|\\s*@\\s*[a-z0-9_.]{2,}'
    '|\\s+@?[a-z0-9]+[._][a-z0-9_.]+|\\s+@?[a-z]{2,}[0-9]{2,}[a-z0-9_.]*)'
    // "dm me on ig", "follow me on fb": the app named after a request to reach her
    '|(?<!$_word)(?:dm|msg|message|text|follow|add|find|contact)(?!$_word)[^.!?\\n]{0,14}?'
    '(?<!$_word)(?:ig|fb|snap|snapchat|tiktok|tg|facebook)(?!$_word)'
    // "find me rahmafit on ig": further away, but only with on / via / at in front of the app
    '|(?<!$_word)(?:dm|msg|message|text|follow|add|find|contact)(?!$_word)[^.!?\\n]{0,40}?'
    '(?<!$_word)(?:on|via|at|through)\\s+(?:my\\s+)?(?:ig|fb|snap|snapchat|tiktok|tg|facebook)(?!$_word)',
    unicode: true,
  );

  /// An email, a handle or an app to move to.
  static bool _hasOutsideContact(String folded) =>
      _email.hasMatch(folded) ||
      _emailSpoken.hasMatch(folded) ||
      _emailSpaced.hasMatch(folded) ||
      _handle.hasMatch(folded) ||
      _appStrong.hasMatch(folded) ||
      _appHandle.hasMatch(folded);

  // ------------------------------------------------------------------ rest

  static const String _word = r'[\p{L}\p{N}_]';

  static const List<String> _paymentNames = <String>[
    'instapay', 'insta pay', 'vodafone cash', 'vodafonecash', //
    'etisalat cash', 'orange cash', 'we pay', 'wepay', 'fawry',
    'فودافون كاش', 'فودافون كش', 'انستاباي', 'انستا باي', 'اتصالات كاش',
    'اورنج كاش', 'فوري',
  ];

  static final RegExp _payment = RegExp(
    '(?<!$_word)(?:${_paymentNames.map((n) => RegExp.escape(n).replaceAll(' ', r'\s+')).join('|')})(?!$_word)',
    unicode: true,
  );

  // Only endings that are not everyday words ("Done.Me", "Good.Fit" are
  // sentences). Short-link and social hosts are named in _linkHosts instead.
  static const String _tlds =
      'com|net|org|io|co|eg|biz|ly|gl|tv|xyz|ae|sa|uk|cc|ws|gg';

  static final RegExp _linkScheme = RegExp(
    'https?://|(?<!$_word|\\.)www\\.',
    unicode: true,
  );

  static final RegExp _linkHosts = RegExp(
    '(?<!$_word|[@.\\-])(?:wa\\.me|t\\.me|instagram\\.com|bit\\.ly|linktr\\.ee|tiktok\\.com|facebook\\.com|fb\\.me|snapchat\\.com|telegram\\.me)(?!$_word|-)',
    unicode: true,
  );

  // Matched on the text as typed: the ending must be all lower or all upper
  // case ("EXAMPLE.COM"), so a capital after a full stop never makes a link.
  // Everyday-word endings count only lower case with a path: "rahmafit.site/plan".
  static const String _pathTlds =
      'site|shop|store|online|link|app|page|bio|me|fit|info|dev|ai|to|us|ee';

  static final RegExp _linkBare = RegExp(
    '(?<!$_word|[@.\\-])[A-Za-z0-9][A-Za-z0-9\\-]*(?:\\.[A-Za-z0-9\\-]+)*\\.(?:$_tlds|${_tlds.toUpperCase()})(?!$_word|-)'
    '|(?<!$_word|[@.\\-])[A-Za-z0-9][A-Za-z0-9\\-]*(?:\\.[A-Za-z0-9\\-]+)*\\.(?:$_pathTlds)/\\S',
    unicode: true,
  );

  static bool _hasLink(String cased) {
    final lower = cased.toLowerCase();
    return _linkScheme.hasMatch(lower) ||
        _linkHosts.hasMatch(lower) ||
        _linkBare.hasMatch(cased);
  }

  static const List<String> _abuseWords = <String>[
    'stupid', 'idiot', 'moron', 'bitch', 'slut', 'whore', 'fuck', //
    'fucking', 'shit',
    'غبيه', 'غبي', 'حمار', 'حماره', 'شرموطه', 'قحبه', 'عرص', 'متخلفه',
    'متخلف', 'زباله',
  ];

  static final RegExp _abuse = RegExp(
    '(?<!$_word)(?:${_abuseWords.join('|')})(?!$_word)',
    unicode: true,
  );
}
