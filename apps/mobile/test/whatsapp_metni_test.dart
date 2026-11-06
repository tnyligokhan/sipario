// WHATSAPP METİN BİÇİMLERİ (kullanıcı isteği 2026-11-06).
//
// ÜÇ SORU: düğme seçimi doğru sarıyor mu, önizleme WhatsApp'ın kurallarıyla mı çiziyor, biçim
// müşteriye giden metne bozulmadan ulaşıyor mu.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/whatsapp_metni.dart';
import 'package:sipario/screens/customers/borc_hatirlatma.dart';

/// Metin ve seçimi tek nesnede tutan tezgâh: düğme dokunuşlarını sırayla uygular.
class BicimTezgahi {
  BicimTezgahi(String metin, {int? bas, int? son})
      : deger = TextEditingValue(
          text: metin,
          selection: TextSelection(baseOffset: bas ?? 0, extentOffset: son ?? metin.length),
        );

  TextEditingValue deger;

  void bicimle(WhatsappBicim b) => deger = WhatsappDuzenleyici(deger).bicimle(b);
  void satirBicimle(WhatsappSatirBicimi b) => deger = WhatsappDuzenleyici(deger).satirBicimle(b);

  String get metin => deger.text;
  String get secili => deger.selection.textInside(deger.text);
}

/// Parçaları `[metin|biçimler]` olarak yazar; iddialar okunur kalsın.
String ozet(WhatsappSatiri s) => s.parcalar
    .map((p) => '[${p.metin}|${(p.bicimler.map((b) => b.name).toList()..sort()).join('+')}]')
    .join();

WhatsappSatiri tekSatir(String metin) => WhatsappSatiri.ayir(metin).single;

void main() {
  group('Düğme', () {
    test('dört biçim seçimi kendi işaretiyle sarar', () {
      for (final (b, beklenen) in [
        (WhatsappBicim.kalin, 'Sayın *Ayşe* Hanım'),
        (WhatsappBicim.italik, 'Sayın _Ayşe_ Hanım'),
        (WhatsappBicim.ustuCizili, 'Sayın ~Ayşe~ Hanım'),
        (WhatsappBicim.tekAralikli, 'Sayın ```Ayşe``` Hanım'),
      ]) {
        final t = BicimTezgahi('Sayın Ayşe Hanım', bas: 6, son: 10)..bicimle(b);
        expect(t.metin, beklenen);
        expect(t.secili, 'Ayşe', reason: 'ikinci dokunuş aynı metni bulabilmeli');
      }
    });

    test('ikinci dokunuş işareti kaldırır', () {
      final t = BicimTezgahi('Sayın Ayşe', bas: 6, son: 10)
        ..bicimle(WhatsappBicim.kalin)
        ..bicimle(WhatsappBicim.kalin);
      expect(t.metin, 'Sayın Ayşe');
      expect(t.secili, 'Ayşe');
    });

    test('iki biçim üst üste binebilir', () {
      final t = BicimTezgahi('Ayşe')
        ..bicimle(WhatsappBicim.kalin)
        ..bicimle(WhatsappBicim.italik);
      expect(t.metin, '*_Ayşe_*');
    });

    test('seçim yoksa imleç işaretlerin arasına gelir', () {
      final t = BicimTezgahi('Merhaba ', bas: 8, son: 8)..bicimle(WhatsappBicim.kalin);
      expect(t.metin, 'Merhaba **');
      expect(t.deger.selection.baseOffset, 9);
    });

    test('kenar boşluğu işaretin dışında kalır, yoksa WhatsApp biçimi çizmez', () {
      final t = BicimTezgahi('Sayın Ayşe Hanım', bas: 5, son: 11)..bicimle(WhatsappBicim.kalin);
      expect(t.metin, 'Sayın *Ayşe* Hanım');
    });

    test('çok satırlı seçimde her satır ayrı sarılır, boş satır boş kalır', () {
      final t = BicimTezgahi('bir\n\niki')..bicimle(WhatsappBicim.italik);
      expect(t.metin, '_bir_\n\n_iki_');
    });

    test('yalnız boşluk seçiliyse metin değişmez', () {
      final t = BicimTezgahi('a  b', bas: 1, son: 3)..bicimle(WhatsappBicim.kalin);
      expect(t.metin, 'a  b');
    });

    test('seçili yer tutucu kalın yapılınca jeton bozulmaz, geri alınınca da bozulmaz', () {
      const jeton = '*musteriadi*';
      final t = BicimTezgahi('Sayın $jeton', bas: 6, son: 6 + jeton.length)
        ..bicimle(WhatsappBicim.kalin);
      expect(t.metin, 'Sayın **musteriadi**');

      t.bicimle(WhatsappBicim.kalin);
      expect(t.metin, 'Sayın $jeton');
    });

    test('hiç odaklanmamış alanda metnin sonuna yazar', () {
      final d = WhatsappDuzenleyici(const TextEditingValue(text: 'abc'))
          .bicimle(WhatsappBicim.kalin);
      expect(d.text, 'abc**');
    });

    test('satır biçimi seçimin dokunduğu bütün satırlara yazılır, numara artar', () {
      final t = BicimTezgahi('elma\narmut\n\nkiraz', bas: 2, son: 15)
        ..satirBicimle(WhatsappSatirBicimi.numarali);
      expect(t.metin, '1. elma\n2. armut\n\n3. kiraz');
    });

    test('satır biçimi ikinci dokunuşta kalkar', () {
      final t = BicimTezgahi('elma\narmut')..satirBicimle(WhatsappSatirBicimi.madde);
      expect(t.metin, '- elma\n- armut');

      t.deger = t.deger.copyWith(
        selection: TextSelection(baseOffset: 0, extentOffset: t.metin.length),
      );
      t.satirBicimle(WhatsappSatirBicimi.madde);
      expect(t.metin, 'elma\narmut');
    });
  });

  group('Önizleme', () {
    test('biçimler çözülür, işaretler görünmez', () {
      expect(ozet(tekSatir('a *b* c')), '[a |][b|kalin][ c|]');
      expect(ozet(tekSatir('_i_ ~u~')), '[i|italik][ |][u|ustuCizili]');
    });

    test('iç içe biçim iki biçimi de taşır', () {
      expect(ozet(tekSatir('*_x_*')), '[x|italik+kalin]');
    });

    test('tek aralıklı metnin içi harfi harfine kalır', () {
      expect(ozet(tekSatir('```*x*```')), '[*x*|tekAralikli]');
    });

    test('sözcük ortasındaki işaret biçim değildir', () {
      expect(ozet(tekSatir('dosya_adi_yeni')), '[dosya_adi_yeni|]');
      expect(ozet(tekSatir('2*3*4')), '[2*3*4|]');
    });

    test('Türkçe harf de sözcük sınırını bozmaz', () {
      expect(ozet(tekSatir('çiğ_öz_ünlü')), '[çiğ_öz_ünlü|]');
    });

    test('kapanmayan ya da boşlukla bitişen işaret düz metindir', () {
      expect(ozet(tekSatir('*yarım')), '[*yarım|]');
      expect(ozet(tekSatir('* boşluk *')), '[* boşluk *|]');
    });

    test('işaret satır aşmaz', () {
      final s = WhatsappSatiri.ayir('*bir\niki*');
      expect(ozet(s[0]), '[*bir|]');
      expect(ozet(s[1]), '[iki*|]');
    });

    test('noktalama sınır sayılır', () {
      expect(ozet(tekSatir('(*x*).')), '[(|][x|kalin][).|]');
    });

    test('satır biçimleri tanınır ve içleri biçimlenir', () {
      final madde = tekSatir('- *x*');
      expect(madde.tur, WhatsappSatirBicimi.madde);
      expect(madde.onek, '•  ');
      expect(ozet(madde), '[x|kalin]');

      expect(tekSatir('2. y').onek, '2. ');
      expect(tekSatir('> z').tur, WhatsappSatirBicimi.alinti);
      expect(tekSatir('düz').tur, isNull);
    });
  });

  group('Müşteriye giden metin', () {
    const degerler = {'*musteriadi*': 'Ayşe', '*kuryeadi*': ''};

    test('biçim işaretleri çözümden sağ çıkar', () {
      expect(
        hatirlatmaSablonuUygula('*Dikkat* _lütfen_ ~eski~ ```kod```', degerler: degerler),
        '*Dikkat* _lütfen_ ~eski~ ```kod```',
      );
    });

    test('kalın yer tutucu değeri kalın yapar', () {
      final m = hatirlatmaSablonuUygula('Sayın **musteriadi**', degerler: degerler);
      expect(m, 'Sayın *Ayşe*');
      expect(ozet(tekSatir(m)), '[Sayın |][Ayşe|kalin]');
    });

    test('değeri boş kalın yer tutucunun satırı düşer, asılı yıldız kalmaz', () {
      expect(
        hatirlatmaSablonuUygula('Merhaba\nGörevli: **kuryeadi**\nİyi günler', degerler: degerler),
        'Merhaba\nİyi günler',
      );
    });
  });
}
