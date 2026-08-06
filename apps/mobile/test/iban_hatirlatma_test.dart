import 'package:flutter/widgets.dart' show TextEditingValue, TextSelection;
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/screens/customers/borc_hatirlatma.dart';
import 'package:sipario/screens/isletme/hatirlatma_sablonu_alani.dart' show jetonEkle;
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

    test('VARSAYILAN METİN BİREBİR — şablona dokunmayan bayide bir karakter bile değişmez', () {
      // Bu beklenti 2026-08-06 şablon çalışmasının kilididir: düzenlenebilirlik, hiçbir şey
      // yapmayan bayinin gönderdiği metni DEĞİŞTİRMEMELİ.
      expect(
        borcHatirlatmaMesaji(
          musteriAd: 'Ahmet Yılmaz',
          borcKurus: 25000,
          iban: 'TR330006100519786457841326',
          isletmeAdi: 'Merkez Su Bayii',
        ),
        'Sayın Ahmet Yılmaz, merhaba.\n'
        'Merkez Su Bayii olarak hesabınızda 250,00 ₺ tutarında ödenmemiş bakiye görünüyor.\n'
        '\n'
        'Ödeme için IBAN:\n'
        'TR33 0006 1005 1978 6457 8413 26\n'
        'Alıcı: Merkez Su Bayii\n'
        '\n'
        'Teşekkür ederiz.',
      );
    });

    test('bayiye sunulan varsayılan ŞABLON, varsayılan metinle aynı sonucu verir', () {
      // "Varsayılanı yükle" düğmesi alanı bu metinle doldurur. Değerlendirmesi varsayılandan
      // ayrışsaydı bayi düzenlemeye başladığı anda mesajı sessizce değişirdi.
      const ad = 'Ahmet Yılmaz';
      const iban = 'TR330006100519786457841326';
      const isletme = 'Merkez Su Bayii';

      expect(
        borcHatirlatmaMesaji(
          musteriAd: ad,
          borcKurus: 25000,
          iban: iban,
          isletmeAdi: isletme,
          sablon: varsayilanHatirlatmaSablonu,
        ),
        borcHatirlatmaMesaji(
          musteriAd: ad,
          borcKurus: 25000,
          iban: iban,
          isletmeAdi: isletme,
        ),
      );
    });
  });

  group('IBAN alıcı adı', () {
    test('ayrı alan doluysa alıcı satırına O yazılır (işletme adı değil)', () {
      // Hesap sahibi çoğu zaman ŞAHIS adıdır; banka uygulaması havalede ad soyad ister.
      final mesaj = borcHatirlatmaMesaji(
        musteriAd: 'Ayşe',
        borcKurus: 5000,
        iban: 'TR330006100519786457841326',
        isletmeAdi: 'Merkez Su Bayii',
        ibanAliciAdi: 'Mehmet Yılmaz',
      );
      expect(mesaj, contains('Alıcı: Mehmet Yılmaz'));
      expect(mesaj, isNot(contains('Alıcı: Merkez Su Bayii')));
      // İşletme adı GÖVDEDE durmaya devam eder — alıcı adı onun yerine geçmez.
      expect(mesaj, contains('Merkez Su Bayii olarak hesabınızda'));
    });

    test('alıcı adı boşsa işletme adına düşülür — güncelleme kimseye satır kaybettirmez', () {
      for (final bos in [null, '', '   ']) {
        expect(
          borcHatirlatmaMesaji(
            musteriAd: 'Ayşe',
            borcKurus: 5000,
            iban: 'TR330006100519786457841326',
            isletmeAdi: 'Merkez Su Bayii',
            ibanAliciAdi: bos,
          ),
          contains('Alıcı: Merkez Su Bayii'),
        );
      }
    });

    test('ödeme bloğu IBAN yokken BOŞ dizedir', () {
      expect(ibanOdemeBlogu(iban: null, aliciAdi: 'Mehmet Yılmaz'), '');
      expect(ibanOdemeBlogu(iban: '  ', isletmeAdi: 'Merkez'), '');
    });
  });

  group('Düzenlenebilir hatırlatma şablonu', () {
    const iban = 'TR330006100519786457841326';

    test('yer tutucular çözülür; IBAN bloğu SABİT içerik olarak yerleşir', () {
      final mesaj = borcHatirlatmaMesaji(
        musteriAd: 'Ahmet',
        borcKurus: 25000,
        iban: iban,
        isletmeAdi: 'Merkez Su',
        ibanAliciAdi: 'Mehmet Yılmaz',
        sablon: 'Sayın *musteriadi*, *siparistutar* ödemeniz bize ulaşmadı.\n'
            'Hesap bilgilerimiz:\n*ibanodemebilgileri*\n*isletmeadi*',
      );

      expect(
        mesaj,
        'Sayın Ahmet, 250,00 ₺ ödemeniz bize ulaşmadı.\n'
        'Hesap bilgilerimiz:\n'
        'Ödeme için IBAN:\n'
        'TR33 0006 1005 1978 6457 8413 26\n'
        'Alıcı: Mehmet Yılmaz\n'
        'Merkez Su',
      );
    });

    test('BİLİNMEYEN yıldızlı diziler OLDUĞU GİBİ kalır (WhatsApp\'ta yıldız = kalın yazı)', () {
      final mesaj = borcHatirlatmaMesaji(
        musteriAd: 'Ahmet',
        borcKurus: 5000,
        iban: iban,
        sablon: '*Önemli*: *musteriadi* için *bilinmeyenalan* kaldı.',
      );

      expect(mesaj, '*Önemli*: Ahmet için *bilinmeyenalan* kaldı.');
    });

    test('IBAN tanımlı değilse blok boşalır ve ETRAFINDA çift boş satır kalmaz', () {
      final mesaj = borcHatirlatmaMesaji(
        musteriAd: 'Ayşe',
        borcKurus: 5000,
        isletmeAdi: 'Merkez Su',
        sablon: varsayilanHatirlatmaSablonu,
      );

      expect(
        mesaj,
        'Sayın Ayşe, merhaba.\n'
        'Merkez Su olarak hesabınızda 50,00 ₺ tutarında ödenmemiş bakiye görünüyor.\n'
        '\n'
        'Teşekkür ederiz.',
      );
      expect(mesaj, isNot(contains('\n\n\n')));
    });

    test('bayinin KENDİ boş satırları korunur — yutma yalnız boşalan yer tutucunun etrafındadır', () {
      final mesaj = borcHatirlatmaMesaji(
        musteriAd: 'Ayşe',
        borcKurus: 5000,
        sablon: 'Bir\n\nİki\n\n*ibanodemebilgileri*\n\nÜç',
      );
      expect(mesaj, 'Bir\n\nİki\n\nÜç');
    });

    test('şablon boşaltılırsa varsayılana döner', () {
      for (final bos in [null, '', '   \n  ']) {
        expect(
          borcHatirlatmaMesaji(musteriAd: 'Ayşe', borcKurus: 5000, sablon: bos),
          borcHatirlatmaMesaji(musteriAd: 'Ayşe', borcKurus: 5000),
        );
      }
    });

    test('şablonun TAMAMI boşa çözülürse BOŞ mesaj değil, varsayılan gönderilir', () {
      // İnceleme bulgusu 2026-08-06: aksi hâlde WhatsApp boş bir metin kutusuyla açılıyordu.
      final bosSablon = borcHatirlatmaMesaji(
        musteriAd: 'Ayşe',
        borcKurus: 5000,
        sablon: '*ibanodemebilgileri*', // IBAN tanımsız → şablon tamamen boşalır
      );
      expect(bosSablon, isNotEmpty);
      expect(bosSablon, borcHatirlatmaMesaji(musteriAd: 'Ayşe', borcKurus: 5000));

      // Aynı sınıf: tek yer tutucu müşteri adı ve ad boş.
      final adsiz = borcHatirlatmaMesaji(musteriAd: '  ', borcKurus: 5000, sablon: '*musteriadi*');
      expect(adsiz, isNotEmpty);
      expect(adsiz, contains('Teşekkür ederiz.'));
    });

    test('satır İÇİNDE boşa çözülen yer tutucu ASILI ETİKET bırakmaz', () {
      // İnceleme bulgusu 2026-08-06: "Ödeme: *ibanodemebilgileri*" IBAN yokken "Ödeme:" diye
      // anlamsız bir satır bırakıyordu. Etiket yalnız o değeri tanıtmak için yazılmıştır.
      final mesaj = borcHatirlatmaMesaji(
        musteriAd: 'Ayşe',
        borcKurus: 5000,
        sablon: 'Merhaba.\nÖdeme: *ibanodemebilgileri*\nTeşekkürler.',
      );
      expect(mesaj, 'Merhaba.\nTeşekkürler.');
      expect(mesaj, isNot(contains('Ödeme:')));
    });

    test('satırdaki yer tutuculardan BİRİ değer getiriyorsa satır DURUR, boşluk sadeleşir', () {
      // Kritik denge: "hepsi boşsa düş" kuralı, TUTAR taşıyan bir satırı düşürmemeli — yoksa
      // mesajdan para rakamı sessizce kaybolurdu.
      final mesaj = borcHatirlatmaMesaji(
        musteriAd: 'Ayşe',
        borcKurus: 5000,
        sablon: '*isletmeadi* olarak *siparistutar* bekliyoruz.',
      );
      expect(mesaj, 'olarak 50,00 ₺ bekliyoruz.');
      expect(mesaj, contains('50,00'));
    });

    test('TEK GEÇİŞ: çözülen değer ikinci kez taranmaz (iki yön de simetrik)', () {
      // İnceleme bulgusu 2026-08-06: sırayla replaceAll, müşteri adı `*isletmeadi*` olduğunda
      // onu işletme adına çeviriyordu; ters yön çevrilmiyordu. Davranış Map sırasına bağlıydı.
      expect(
        borcHatirlatmaMesaji(
          musteriAd: '*isletmeadi*',
          borcKurus: 5000,
          isletmeAdi: 'Merkez Su',
          sablon: '*musteriadi*',
        ),
        '*isletmeadi*',
      );
      expect(
        borcHatirlatmaMesaji(
          musteriAd: 'Ayşe',
          borcKurus: 5000,
          isletmeAdi: '*musteriadi*',
          sablon: '*isletmeadi*',
        ),
        '*musteriadi*',
      );
    });

    test('şablon uzunluk sınırı formda söylenir (sunucu sınırıyla aynı)', () {
      const temel = {
        'ad': 'Merkez Su',
        'sahip': 'Mehmet Usta',
        'telefon': '02421112233',
        'acilis': '08:00',
        'kapanis': '19:00',
      };
      // Sınır SUNUCUDAKİ kolonla aynı; formda söylenmezse hata senkron partisine kaçar.
      expect(
        isletmeProfilHatalari({...temel, 'sablon': 'ş' * hatirlatmaSablonuAzamiUzunluk}),
        isNot(contains('sablon')),
      );
      expect(
        isletmeProfilHatalari({...temel, 'sablon': 'ş' * (hatirlatmaSablonuAzamiUzunluk + 1)}),
        contains('sablon'),
      );
    });
  });

  group('Yer tutucu çipi imlece ekler', () {
    test('imleç konumuna eklenir ve imleç eklenen dizinin sonuna taşınır', () {
      final sonuc = jetonEkle(
        const TextEditingValue(
          text: 'Sayın , merhaba.',
          selection: TextSelection.collapsed(offset: 6),
        ),
        '*musteriadi*',
      );

      expect(sonuc.text, 'Sayın *musteriadi*, merhaba.');
      expect(sonuc.selection.baseOffset, 18);
    });

    test('SEÇİLİ metin varsa onun YERİNE geçer', () {
      final sonuc = jetonEkle(
        const TextEditingValue(
          text: 'Sayın XXX, merhaba.',
          selection: TextSelection(baseOffset: 6, extentOffset: 9),
        ),
        '*musteriadi*',
      );
      expect(sonuc.text, 'Sayın *musteriadi*, merhaba.');
    });

    test('alan hiç odaklanmadıysa (seçim geçersiz) SONA eklenir, başa değil', () {
      // `baseOffset` −1'dir; 0 kabul etmek jetonu bayinin cümlesinin BAŞINA sıkıştırırdı.
      final sonuc = jetonEkle(const TextEditingValue(text: 'Merhaba'), '*musteriadi*');
      expect(sonuc.text, 'Merhaba*musteriadi*');
      expect(sonuc.selection.baseOffset, 'Merhaba*musteriadi*'.length);
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

    test('BOŞLUK %20 kodlanır, "+" DEĞİL — Android ayrıştırıcısı "+"ı boşluğa çevirmez', () {
      // İnceleme bulgusu 2026-08-06. `Uri(queryParameters:)` boşluğu form kuralıyla `+` yazardı;
      // WhatsApp `whatsapp://send`i `Uri.getQueryParameter` ile okur ve o API yalnız
      // percent-decode yapar → müşteriye "Sayın+Ahmet,+merhaba." giderdi.
      final uriler = whatsappUriler('+905321112233', mesaj: 'Sayın Ahmet, merhaba.');

      for (final u in uriler) {
        expect(u.toString(), contains('Say%C4%B1n%20Ahmet'));
        expect(u.toString(), isNot(contains('+')),
            reason: 'kodlanmış metinde "+" HİÇ bulunmamalı');
        // Kodlama doğru olduğu için ayrıştırma geri döndüğünde metin BOZULMAMIŞ olmalı.
        expect(u.queryParameters['text'], 'Sayın Ahmet, merhaba.');
      }
    });

    test('özel karakterler kaçırılır: satır sonu · & · # · ₺ · literal +', () {
      // Eski elle `?text=` birleştirmesi bunları kaçıramadığı için mesajı SESSİZCE kırpıyordu;
      // `encodeComponent` hepsini kodlar, yani elle kurma o tuzağı geri getirmez.
      const metin = 'A\nB & C # D ₺ E+F';
      final uriler = whatsappUriler('+905321112233', mesaj: metin);

      for (final u in uriler) {
        final ham = u.toString();
        expect(ham, contains('%0A'), reason: 'satır sonu');
        expect(ham, contains('%26'), reason: '& — kaçırılmazsa sonraki parametre sanılır');
        expect(ham, contains('%23'), reason: '# — kaçırılmazsa fragment başlatır, metin KIRPILIR');
        expect(ham, contains('%E2%82%BA'), reason: '₺');
        expect(ham, contains('%2B'), reason: 'literal + kendisi olarak kalmalı');
        // Tur bitişi: ne yazdıysak onu okuyoruz.
        expect(u.queryParameters['text'], metin);
      }
    });

    test('numara ve şema korunur (elle kurma URI iskeletini bozmadı)', () {
      final uriler = whatsappUriler('+905321112233', mesaj: 'x y');
      expect(uriler.first.scheme, 'whatsapp');
      expect(uriler.first.host, 'send');
      expect(uriler.first.queryParameters['phone'], '905321112233');
      expect(uriler.last.scheme, 'https');
      expect(uriler.last.host, 'wa.me');
      expect(uriler.last.path, '/905321112233');
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
