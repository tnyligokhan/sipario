import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/screens/customers/borc_hatirlatma.dart';
import 'package:sipario/screens/isletme/iban.dart';
import 'package:sipario/screens/isletme/isletme_profili_ekrani.dart' show isletmeProfilHatalari;
import 'package:sipario/screens/orders/musteri_eylemleri.dart' show whatsappUriler;
import 'package:sipario/screens/orders/siparis_tarih_seridi.dart' show tarihEtiketi;

/// IBAN + BORÇ HATIRLATMA + GÜN GEZİNMESİ — kullanıcı isteği 2026-08-04.
/// Üçü de saf: widget kurmadan, ağa çıkmadan sınanır.
void main() {
  group('IBAN biçimi ve geçerliliği', () {
    test('normalleştirme boşlukları atar ve büyütür; boş metin null olur', () {
      expect(ibanNormal(' tr33 0006 1005 1978 6457 8413 26 '), 'TR330006100519786457841326');
      expect(ibanNormal(''), isNull);
      expect(ibanNormal('   '), isNull);
      expect(ibanNormal(null), isNull);
    });

    test('okunur biçim dörderli gruplar hâlinde yazar', () {
      expect(ibanOkunur('TR330006100519786457841326'), 'TR33 0006 1005 1978 6457 8413 26');
      expect(ibanOkunur(null), '');
    });

    test('mod-97 sağlaması tek hane hatasını yakalar', () {
      const dogru = 'TR330006100519786457841326';
      expect(ibanGecerliMi(dogru), isTrue);

      // Son hane bozulunca sağlama tutmaz — yanlış IBAN'ın SESSİZ hata olmasını engelleyen tek şey.
      expect(ibanGecerliMi('TR330006100519786457841327'), isFalse);
      expect(ibanGecerliMi('abc'), isFalse);
      expect(ibanGecerliMi('TR33 0006 1005 1978 6457 8413 26'), isTrue, reason: 'boşluk sorun değil');
    });

    test('form hatası: boş serbest, TR uzunluğu ayrıca söylenir', () {
      // IBAN zorunlu alan DEĞİL, yalnız hatırlatma özelliğinin ön koşulu.
      expect(ibanHatasi(''), isNull);
      expect(ibanHatasi(null), isNull);
      expect(ibanHatasi('TR33000610051978645784132'), contains('26 karakter'));
      expect(ibanHatasi('TR330006100519786457841327'), contains('geçersiz'));
      expect(ibanHatasi('TR330006100519786457841326'), isNull);
    });

    test('işletme profili formu bozuk IBANı reddeder, boşu kabul eder', () {
      const temel = {
        'ad': 'Merkez Su',
        'sahip': 'Mehmet Usta',
        'telefon': '02421112233',
        'acilis': '08:00',
        'kapanis': '19:00',
      };
      expect(isletmeProfilHatalari({...temel, 'iban': ''}), isNot(contains('iban')));
      expect(isletmeProfilHatalari({...temel, 'iban': 'TR33'}), contains('iban'));
      expect(
        isletmeProfilHatalari({...temel, 'iban': 'TR33 0006 1005 1978 6457 8413 26'}),
        isNot(contains('iban')),
      );
    });
  });

  group('Borç hatırlatma mesajı', () {
    test('ad, tutar, IBAN ve alıcı adı metinde geçer', () {
      final mesaj = borcHatirlatmaMesaji(
        musteriAd: 'Ahmet Yılmaz',
        borcKurus: 25000,
        iban: 'TR330006100519786457841326',
        isletmeAdi: 'Merkez Su Bayii',
      );

      expect(mesaj, contains('Ahmet Yılmaz'));
      expect(mesaj, contains('250,00'));
      expect(mesaj, contains('Merkez Su Bayii'));
      // IBAN OKUNUR biçimde yazılır: müşteri bankada gördüğü gruplamayla karşılaştırır.
      expect(mesaj, contains('TR33 0006 1005 1978 6457 8413 26'));
      // Alıcı adı ŞART — banka uygulamaları IBAN'ın yanında ad ister.
      expect(mesaj, contains('Alıcı: Merkez Su Bayii'));
    });

    test('IBAN yoksa mesaj yine kurulur ama IBAN bloğu yazılmaz', () {
      final mesaj = borcHatirlatmaMesaji(musteriAd: 'Ayşe', borcKurus: 5000);
      expect(mesaj, contains('Ayşe'));
      expect(mesaj, contains('50,00'));
      expect(mesaj, isNot(contains('IBAN')));
      expect(mesaj, isNot(contains('Alıcı:')));
    });

    test('işletme adı yoksa uydurma ad yazılmaz', () {
      final mesaj = borcHatirlatmaMesaji(
        musteriAd: 'Ayşe',
        borcKurus: 5000,
        iban: 'TR330006100519786457841326',
      );
      expect(mesaj, contains('IBAN'));
      expect(mesaj, isNot(contains('Alıcı:')));
    });
  });

  group('WhatsApp bağlantısı', () {
    test('mesaj metni kodlanarak eklenir, numara sadeleşir', () {
      final uriler = whatsappUriler('+905321112233', mesaj: 'Sayın Ahmet, 250,00 ₺ borcunuz var');

      // İki aday: önce uygulamanın kendi şeması, sonra wa.me.
      expect(uriler, hasLength(2));
      expect(uriler.first.scheme, 'whatsapp');
      expect(uriler.first.queryParameters['phone'], '905321112233');
      // Türkçe harf ve ₺ işareti kodlanmış olmalı — elle birleştirilen bir `?text=` bunları
      // sessizce kırpardı. `queryParameters` çözülmüş hâli verir, kodlama `toString`de görünür.
      expect(uriler.first.queryParameters['text'], contains('Sayın Ahmet'));
      expect(uriler.first.toString(), isNot(contains(' ')));

      expect(uriler.last.host, 'wa.me');
      expect(uriler.last.path, '/905321112233');
      expect(uriler.last.queryParameters['text'], contains('250,00'));
    });

    test('mesajsız çağrıda text parametresi HİÇ eklenmez', () {
      final uriler = whatsappUriler('+905321112233');
      expect(uriler.first.queryParameters.containsKey('text'), isFalse);
      expect(uriler.last.queryParameters.containsKey('text'), isFalse);
    });
  });

  group('Teslim sekmesi gün etiketi', () {
    final bugun = DateTime(2026, 8, 4); // Salı

    test('bugün ve dün ANLAMIYLA yazılır, diğerleri gün adıyla', () {
      expect(tarihEtiketi(bugun, bugun: bugun), 'Bugün · 4 Ağustos');
      expect(tarihEtiketi(DateTime(2026, 8, 3), bugun: bugun), 'Dün · 3 Ağustos');
      expect(tarihEtiketi(DateTime(2026, 8, 1), bugun: bugun), '1 Ağustos Cumartesi');
      expect(tarihEtiketi(DateTime(2026, 7, 30), bugun: bugun), '30 Temmuz Perşembe');
    });

    test('etiket saat farkından etkilenmez (aynı gün, farklı saat)', () {
      expect(tarihEtiketi(bugun, bugun: DateTime(2026, 8, 4, 23, 59)), startsWith('Bugün'));
    });
  });
}
