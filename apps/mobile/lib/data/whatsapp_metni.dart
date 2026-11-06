// WHATSAPP METİN BİÇİMLERİ (kullanıcı isteği 2026-11-06, 1.17.0) — SAF kurallar.
//
// Mesajlar WhatsApp'a düz metin olarak gider ve biçimi WhatsApp kendi işaretlerinden çizer:
// `*kalın*`, `_italik_`, `~üstü çizili~`, ```tek aralıklı```, `- madde`, `1. numaralı`, `> alıntı`.
// Yani saklanan şey işaretli metnin kendisidir; sunucuda ya da şemada biçim diye bir alan yoktur.
//
// ⚠️ YER TUTUCU DA YILDIZ TAŞIR: `*musteriadi*` kalın yazı değildir. İkisi şöyle ayrışır:
// `hatirlatmaSablonuUygula` bilinen jetonu değerle değiştirir, bilinmeyen `*…*` dizisine dokunmaz.
// Kalın yer tutucu `**musteriadi**` yazılır ve çözülünce `*Ayşe*` olur. Önizleme bu yüzden metni
// yer tutucular çözüldükten SONRA ayrıştırır, yoksa her yer tutucuyu kalın gösterirdi.
//
// WhatsApp işareti satır aşırı tanımaz: seçim birden çok satırı kapsıyorsa her satır ayrı sarılır.
// İşaretin içi boşlukla başlayıp bitemez: seçimin kenar boşlukları işaretin dışında bırakılır.

import 'package:flutter/services.dart' show TextEditingValue, TextSelection;

/// Satır içi biçim. [isaret] metnin iki yanına yazılır.
enum WhatsappBicim {
  kalin('*', 'Kalın'),
  italik('_', 'İtalik'),
  ustuCizili('~', 'Üstü Çizili'),
  tekAralikli('```', 'Tek Aralıklı');

  const WhatsappBicim(this.isaret, this.etiket);

  final String isaret;
  final String etiket;
}

/// Satırın başına yazılan biçim.
enum WhatsappSatirBicimi {
  madde('Madde', r'^- '),
  numarali('Numaralı', r'^\d+\. '),
  alinti('Alıntı', r'^> ');

  const WhatsappSatirBicimi(this.etiket, this._desen);

  final String etiket;
  final String _desen;

  RegExp get desen => RegExp(_desen);

  /// [sira] 1'den başlar; yalnız numaralı listede kullanılır.
  String onek(int sira) => switch (this) {
        WhatsappSatirBicimi.madde => '- ',
        WhatsappSatirBicimi.numarali => '$sira. ',
        WhatsappSatirBicimi.alinti => '> ',
      };
}

/// Düzenleme alanındaki seçime biçim uygular. Değişmez değer alır, yenisini döner.
class WhatsappDuzenleyici {
  const WhatsappDuzenleyici(this.deger);

  final TextEditingValue deger;

  String get _metin => deger.text;

  /// Alan hiç odaklanmadıysa seçim geçersizdir; o zaman metnin sonu sayılır.
  (int, int) get _aralik {
    final s = deger.selection;
    final gecerli = s.isValid && s.start >= 0 && s.end <= _metin.length;
    return gecerli ? (s.start, s.end) : (_metin.length, _metin.length);
  }

  /// Seçimi [bicim] ile sarar. Seçim zaten sarılıysa işareti kaldırır, seçim yoksa imleci işaret
  /// çiftinin arasına koyar.
  TextEditingValue bicimle(WhatsappBicim bicim) {
    final (bas, son) = _aralik;
    final isaret = bicim.isaret;
    final n = isaret.length;

    if (bas == son) {
      return TextEditingValue(
        text: _metin.replaceRange(bas, son, '$isaret$isaret'),
        selection: TextSelection.collapsed(offset: bas + n),
      );
    }

    // İşaret seçimin DIŞINA bakılarak aranır, içine değil: seçili `*musteriadi*` yer tutucusunun
    // kendi yıldızları kalın işareti sanılıp silinseydi yer tutucu bozulurdu.
    final sarili = bas >= n &&
        son + n <= _metin.length &&
        _metin.substring(bas - n, bas) == isaret &&
        _metin.substring(son, son + n) == isaret;
    if (sarili) {
      return TextEditingValue(
        text: _metin.replaceRange(bas - n, son + n, _metin.substring(bas, son)),
        selection: TextSelection(baseOffset: bas - n, extentOffset: son - n),
      );
    }

    final satirlar = _metin.substring(bas, son).split('\n');
    if (satirlar.length == 1) {
      final parca = _KenarAyrimi(satirlar.single);
      if (parca.oz.isEmpty) return deger;
      final ozBas = bas + parca.bas.length + n;
      return TextEditingValue(
        text: _metin.replaceRange(bas, son, parca.sar(isaret)),
        selection: TextSelection(baseOffset: ozBas, extentOffset: ozBas + parca.oz.length),
      );
    }

    final yeni = satirlar.map((s) => _KenarAyrimi(s).sar(isaret)).join('\n');
    return TextEditingValue(
      text: _metin.replaceRange(bas, son, yeni),
      selection: TextSelection(baseOffset: bas, extentOffset: bas + yeni.length),
    );
  }

  /// Seçimin dokunduğu satırların başına [bicim] ekler. Dolu satırların hepsi zaten o biçimdeyse
  /// kaldırır. Boş satır atlanır: işaretli boş satır müşteriye tek başına bir tire olarak gider.
  TextEditingValue satirBicimle(WhatsappSatirBicimi bicim) {
    final (bas, son) = _aralik;
    final satirBasi = bas == 0 ? 0 : _metin.lastIndexOf('\n', bas - 1) + 1;
    final sonrakiSatir = _metin.indexOf('\n', son);
    final satirSonu = sonrakiSatir < 0 ? _metin.length : sonrakiSatir;

    final satirlar = _metin.substring(satirBasi, satirSonu).split('\n');
    final dolu = satirlar.where((s) => s.trim().isNotEmpty);
    final kaldir = dolu.isNotEmpty && dolu.every(bicim.desen.hasMatch);

    var sira = 0;
    final yeni = satirlar.map((s) {
      if (s.trim().isEmpty) return s;
      if (kaldir) return s.replaceFirst(bicim.desen, '');
      sira++;
      return '${bicim.onek(sira)}$s';
    }).join('\n');

    return TextEditingValue(
      text: _metin.replaceRange(satirBasi, satirSonu, yeni),
      selection: TextSelection.collapsed(offset: satirBasi + yeni.length),
    );
  }
}

/// Bir satırı kenar boşlukları ve özü olarak ayırır.
class _KenarAyrimi {
  factory _KenarAyrimi(String satir) {
    final oz = satir.trim();
    if (oz.isEmpty) return _KenarAyrimi._(satir, '', '');
    final bas = satir.indexOf(oz);
    return _KenarAyrimi._(satir.substring(0, bas), oz, satir.substring(bas + oz.length));
  }

  const _KenarAyrimi._(this.bas, this.oz, this.son);

  final String bas;
  final String oz;
  final String son;

  String sar(String isaret) => oz.isEmpty ? '$bas$son' : '$bas$isaret$oz$isaret$son';
}

/// Aynı biçimi taşıyan metin parçası.
class WhatsappParca {
  const WhatsappParca(this.metin, this.bicimler);

  final String metin;
  final Set<WhatsappBicim> bicimler;
}

/// Önizlemenin tek satırı.
class WhatsappSatiri {
  const WhatsappSatiri({required this.parcalar, this.tur, this.onek = ''});

  final List<WhatsappParca> parcalar;

  /// Satır başı biçimi; düz satırda null.
  final WhatsappSatirBicimi? tur;

  /// Satırın başında gösterilecek işaret: madde imi ya da numara.
  final String onek;

  /// [metin]i WhatsApp'ın çizeceği satırlara ayırır.
  static List<WhatsappSatiri> ayir(String metin) =>
      [for (final satir in metin.split('\n')) _satir(satir)];

  static WhatsappSatiri _satir(String satir) {
    for (final tur in WhatsappSatirBicimi.values) {
      final eslesme = tur.desen.firstMatch(satir);
      if (eslesme == null) continue;
      return WhatsappSatiri(
        parcalar: _parcala(satir.substring(eslesme.end), const {}),
        tur: tur,
        onek: switch (tur) {
          WhatsappSatirBicimi.madde => '•  ',
          WhatsappSatirBicimi.numarali => eslesme.group(0)!,
          WhatsappSatirBicimi.alinti => '',
        },
      );
    }
    return WhatsappSatiri(parcalar: _parcala(satir, const {}));
  }

  static final RegExp _harf = RegExp(r'[\p{L}\p{N}]', unicode: true);

  /// Sözcüğün ortasındaki işaret biçim değildir: `dosya_adi_yeni` italik olmaz.
  static bool _sinir(String s, int i) => i < 0 || i >= s.length || !_harf.hasMatch(s[i]);

  static bool _bosluk(String c) => c.trim().isEmpty;

  /// [i] konumundaki işareti kapatan konum; yoksa -1.
  static int _kapanis(String s, int i, String isaret) {
    final n = isaret.length;
    final icBas = i + n;
    if (icBas >= s.length || _bosluk(s[icBas]) || !_sinir(s, i - 1)) return -1;

    var j = s.indexOf(isaret, icBas + 1);
    while (j >= 0) {
      if (!_bosluk(s[j - 1]) && _sinir(s, j + n)) return j;
      j = s.indexOf(isaret, j + 1);
    }
    return -1;
  }

  static List<WhatsappParca> _parcala(String s, Set<WhatsappBicim> etkin) {
    final sonuc = <WhatsappParca>[];
    var duz = 0;
    var i = 0;

    while (i < s.length) {
      final bicim = WhatsappBicim.values.where((b) => s.startsWith(b.isaret, i)).firstOrNull;
      final kapanis = bicim == null ? -1 : _kapanis(s, i, bicim.isaret);
      if (bicim == null || kapanis < 0) {
        i++;
        continue;
      }

      if (i > duz) sonuc.add(WhatsappParca(s.substring(duz, i), etkin));
      final ic = s.substring(i + bicim.isaret.length, kapanis);
      final yeni = {...etkin, bicim};
      // Tek aralıklı metnin içi harfi harfine gösterilir, başka biçim aranmaz.
      sonuc.addAll(bicim == WhatsappBicim.tekAralikli
          ? [WhatsappParca(ic, yeni)]
          : _parcala(ic, yeni));

      i = kapanis + bicim.isaret.length;
      duz = i;
    }

    if (duz < s.length) sonuc.add(WhatsappParca(s.substring(duz), etkin));
    return sonuc;
  }
}
