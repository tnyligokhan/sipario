// Çağrı kartı + çağrı günlüğü UI testleri.
// Tasarım kaynağı: tasarım s-cagri.jsx (kart varyantları), s-veri.jsx (ARAMALAR),
// s-uygulama.jsx (muaf numara kuralı).
//
// KAPSAM NOTU: gerçek cihazda çağrı anında çizilen kart saf Kotlin'dir
// (android/.../CallerCard.kt) ve buradan test EDİLEMEZ. Bu dosya Flutter karşılığını
// (uygulama önplandayken ve Ayarlar'daki simülasyonda kullanılan kart) doğrular.

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/call_log_repository.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/ledger_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/repo/product_repository.dart';
import 'package:sipario/screens/cagri/cagri_cozumleyici.dart';
import 'package:sipario/screens/cagri/cagri_gunlugu.dart';
import 'package:sipario/screens/cagri/cagri_karti.dart';
import 'package:sipario/screens/cagri/cagri_kuyrugu.dart';
import 'package:sipario/screens/cagri/cagri_model.dart';
import 'package:sipario/theme/app_theme.dart';
import 'package:sipario/theme/components/atoms.dart';
import 'package:sipario/theme/tokens.dart';

Widget _kabuk(Widget govde, {bool koyu = false}) => MaterialApp(
      theme: koyu ? SipTheme.koyu() : SipTheme.acik(),
      home: Scaffold(body: govde),
    );

/// Kartın canlı noktası sonsuz nabız atar, yani ağaç HİÇ oturmaz — `pumpAndSettle`
/// zaman aşımına düşer. Geçişleri elle ilerletiyoruz.
Future<void> _gecis(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

const _ahmet = CagriKisi(
  numara: '0532 415 22 90',
  musteriId: 'm1',
  ad: 'Ahmet Yılmaz',
  bakiyeKurus: 34000,
  adres: 'Cumhuriyet Mah. 5. Sk. No:12/4',
  konumVar: true,
  not: 'Zil çalışmıyor, gelince arayın.',
  sonHareket: 'Son sipariş: Damacana 19 L ×2 · 10:24',
);

const _selin = CagriKisi(
  numara: '0533 220 78 41',
  musteriId: 'm2',
  ad: 'Selin Kaya',
);

const _murat = CagriKisi(
  numara: '0542 907 63 22',
  musteriId: 'm3',
  ad: 'Murat Öz',
  bakiyeKurus: -12000,
);

void main() {
  group('sonOnHane / numaraMuafMi', () {
    test('üç yazım biçimi de aynı son 10 haneye iner', () {
      expect(sonOnHane('+90 532 415 22 90'), '5324152290');
      expect(sonOnHane('0532 415 22 90'), '5324152290');
      expect(sonOnHane('5324152290'), '5324152290');
    });

    test('muaf listesi biçimden bağımsız eşleşir', () {
      expect(numaraMuafMi('+905331111111', ['0533 111 11 11']), isTrue);
      expect(numaraMuafMi('0533 111 11 11', ['5331111111']), isTrue);
      expect(numaraMuafMi('0532 415 22 90', ['0533 111 11 11']), isFalse);
      expect(numaraMuafMi('0532 415 22 90', const []), isFalse);
    });

    test('10 haneden kısa numara asla muaf sayılmaz', () {
      // Gizli numara / kısa servis numarası boş bir muaf kaydıyla eşleşip kartı susturmamalı.
      expect(numaraMuafMi('', ['']), isFalse);
      expect(numaraMuafMi('112', ['112']), isFalse);
    });
  });

  group('CagriKarti — kayıtlı müşteri', () {
    testWidgets('borçluda ad, kod, borç rozeti ve AÇIK BORÇ şeridi görünür', (tester) async {
      await tester.pumpWidget(_kabuk(const CagriKarti(kisi: _ahmet)));

      expect(find.text('GELEN ÇAĞRI'), findsOneWidget);
      expect(find.text('Ahmet Yılmaz'), findsOneWidget);
      expect(find.text('M-001'), findsOneWidget);
      expect(find.text('Borç'), findsOneWidget);
      expect(find.text('AÇIK BORÇ'), findsOneWidget);
      expect(find.text('340,00 ₺'), findsOneWidget);

      // Bilgi satırları: adres bölgeyle birleşir, not sarı satırda durur.
      // Bölge kaldırıldı (2026-07-28): kartta adres metni tek başına yazar.
      expect(find.text('Cumhuriyet Mah. 5. Sk. No:12/4'), findsOneWidget);
      expect(find.text('Son sipariş: Damacana 19 L ×2 · 10:24'), findsOneWidget);
      expect(find.text('Zil çalışmıyor, gelince arayın.'), findsOneWidget);

      // Kayıtlı varyantın eylemleri.
      expect(find.text('Sipariş Oluştur'), findsOneWidget);
      expect(find.text('Defteri Aç'), findsOneWidget);
      expect(find.text('Müşteri Olarak Kaydet'), findsNothing);
    });

    testWidgets('alacaklıda ALACAĞI VAR şeridi ve Alacak rozeti çıkar', (tester) async {
      await tester.pumpWidget(_kabuk(const CagriKarti(kisi: _murat)));

      expect(find.text('Alacak'), findsOneWidget);
      expect(find.text('ALACAĞI VAR'), findsOneWidget);
      expect(find.text('120,00 ₺'), findsOneWidget);
      expect(find.text('AÇIK BORÇ'), findsNothing);
    });

    testWidgets('bakiyesi temiz müşteride şerit hiç çizilmez, rozet Temiz olur', (tester) async {
      await tester.pumpWidget(_kabuk(const CagriKarti(kisi: _selin)));

      expect(find.text('Temiz'), findsOneWidget);
      expect(find.text('AÇIK BORÇ'), findsNothing);
      expect(find.text('ALACAĞI VAR'), findsNothing);
      expect(find.text('0,00 ₺'), findsNothing);
    });

    testWidgets('kartta AVATAR yok (tasarımın .cagri-kim\'i avatar çizmiyor)', (tester) async {
      await tester.pumpWidget(_kabuk(const CagriKarti(kisi: _ahmet)));

      // `.cagri-av` ölü CSS: ne baş harf rozeti ne de kayıtsız varyantın telefon ikon kutusu.
      expect(find.byType(SipAvatar), findsNothing);
      expect(find.text('AY'), findsNothing);
      expect(find.text('Ahmet Yılmaz'), findsOneWidget);

      await tester.pumpWidget(
        _kabuk(const CagriKarti(kisi: CagriKisi.kayitsiz('0216 555 01 88'))),
      );
      expect(find.byType(SipIkonKutu), findsNothing);
    });

    testWidgets('eylemler doğru geri çağrıyı tetikler', (tester) async {
      var siparis = 0;
      var defter = 0;
      await tester.pumpWidget(_kabuk(CagriKarti(
        kisi: _ahmet,
        onSiparis: () => siparis++,
        onDefter: () => defter++,
      )));

      await tester.tap(find.text('Sipariş Oluştur'));
      await tester.tap(find.text('Defteri Aç'));
      await tester.pump();

      expect(siparis, 1);
      expect(defter, 1);
    });
  });

  group('CagriKarti — kayıtsız numara', () {
    testWidgets('numara baskın, Kayıtsız rozeti ve tek kaydetme eylemi', (tester) async {
      await tester.pumpWidget(
        _kabuk(const CagriKarti(kisi: CagriKisi.kayitsiz('0216 555 01 88'))),
      );

      expect(find.text('0216 555 01 88'), findsOneWidget);
      expect(find.text('Bu numara defterinizde yok'), findsOneWidget);
      expect(find.text('Kayıtsız'), findsOneWidget);
      expect(find.text('Müşteri Olarak Kaydet'), findsOneWidget);

      // Kayıtsızda bakiye/defter dili hiç görünmez.
      expect(find.text('Sipariş Oluştur'), findsNothing);
      expect(find.text('Defteri Aç'), findsNothing);
      expect(find.text('Temiz'), findsNothing);
    });

    testWidgets('koyu temada da aynı içerik çizilir', (tester) async {
      await tester.pumpWidget(
        _kabuk(const CagriKarti(kisi: _ahmet), koyu: true),
      );
      expect(find.text('Ahmet Yılmaz'), findsOneWidget);
      expect(find.text('AÇIK BORÇ'), findsOneWidget);
    });
  });

  group('cagriKartiGoster — muaf numara', () {
    testWidgets('muaf numarada kart HİÇ açılmaz', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(_kabuk(Builder(builder: (c) {
        ctx = c;
        return const SizedBox.shrink();
      })));

      final sonuc = await cagriKartiGoster(
        ctx,
        kisi: const CagriKisi.kayitsiz('0533 111 11 11'),
        muafNumaralar: const ['+90 533 111 11 11'],
      );
      await tester.pumpAndSettle();

      expect(sonuc, isNull);
      expect(find.text('GELEN ÇAĞRI'), findsNothing);
    });

    testWidgets('muaf olmayan numarada kart açılır ve eylemle kapanır', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(_kabuk(Builder(builder: (c) {
        ctx = c;
        return const SizedBox.shrink();
      })));

      final bekleyen = cagriKartiGoster(
        ctx,
        kisi: _ahmet,
        muafNumaralar: const ['0533 111 11 11'],
      );
      await _gecis(tester);
      expect(find.text('GELEN ÇAĞRI'), findsOneWidget);

      await tester.tap(find.text('Defteri Aç'));
      await _gecis(tester);

      expect(await bekleyen, CagriEylemi.defter);
      expect(find.text('GELEN ÇAĞRI'), findsNothing);
    });
  });

  group('Çağrı günlüğü', () {
    const aramalar = [
      AramaKaydi(
        id: 'a1',
        musteriId: 'm1',
        ad: 'Ahmet Yılmaz',
        numara: '0532 415 22 90',
        saat: '10:24',
        tip: AramaTipi.gelen,
        sonuc: 'Sipariş alındı',
      ),
      AramaKaydi(
        id: 'a3',
        numara: '0216 555 01 88',
        saat: '09:47',
        tip: AramaTipi.cevapsiz,
        sonuc: 'Kayıtsız numara',
      ),
      AramaKaydi(
        id: 'a5',
        musteriId: 'm2',
        ad: 'Selin Kaya',
        numara: '0533 220 78 41',
        saat: 'Dün',
        tip: AramaTipi.giden,
      ),
    ];

    testWidgets('kayıtlı satır adı, kayıtsız satır numarayı gösterir', (tester) async {
      await tester.pumpWidget(
        _kabuk(const CagriGunluguEkrani(aramalar: aramalar)),
      );

      expect(find.text('Ahmet Yılmaz'), findsOneWidget);
      expect(find.text('0532 415 22 90 · Sipariş alındı'), findsOneWidget);

      // Kayıtsızda ad yok: numara üstte, altta yalnız sonuç.
      expect(find.text('0216 555 01 88'), findsOneWidget);
      expect(find.text('Kayıtsız numara'), findsOneWidget);

      // Sonucu olmayan satırda alt metin hiç çizilmez.
      expect(find.text('Selin Kaya'), findsOneWidget);
      expect(find.text('0533 220 78 41'), findsOneWidget);

      expect(find.text('10:24'), findsOneWidget);
      expect(find.text('Dün'), findsOneWidget);
    });

    testWidgets('cevapsız arama danger, diğerleri nötr ikon kutusu alır', (tester) async {
      await tester.pumpWidget(
        _kabuk(const CagriGunluguEkrani(aramalar: aramalar)),
      );

      // Renk ham değerden değil JETONDAN okunur: tokens.dart'ta dangerSoft değişirse bu test
      // kırılmamalı, yalnız "cevapsız satır danger zeminde" kuralı korunmalı.
      final jeton = SipTheme.acik().extension<SipTokens>();
      expect(jeton, isNotNull);

      final kutular = tester
          .widgetList<Container>(find.descendant(
            of: find.byType(AramaSatiri),
            matching: find.byType(Container),
          ))
          .map((c) => (c.decoration as BoxDecoration?)?.color)
          .whereType<Color>()
          .toList();
      expect(kutular, contains(jeton!.dangerSoft));
      // Cevapsız YALNIZCA bir tane; diğer iki satır nötr surface2 zeminde durur.
      expect(kutular.where((c) => c == jeton.dangerSoft).length, 1);
      expect(kutular, contains(jeton.surface2));
    });

    testWidgets('satıra dokunmak kaydı geri döndürür', (tester) async {
      AramaKaydi? acilan;
      await tester.pumpWidget(_kabuk(CagriGunluguEkrani(
        aramalar: aramalar,
        onAc: (a) => acilan = a,
      )));

      await tester.tap(find.text('Ahmet Yılmaz'));
      await tester.pump();

      expect(acilan?.id, 'a1');
      expect(acilan?.kayitli, isTrue);
    });

    testWidgets('boş listede boş durum çıkar', (tester) async {
      await tester.pumpWidget(
        _kabuk(const CagriGunluguEkrani(aramalar: [])),
      );
      expect(find.text('Henüz arama yok'), findsOneWidget);
    });
  });

  group('aramaTipiCoz', () {
    test('depo metinlerini enum\'a çevirir, bilinmeyeni gelen sayar', () {
      expect(aramaTipiCoz('cevapsiz'), AramaTipi.cevapsiz);
      expect(aramaTipiCoz('missed'), AramaTipi.cevapsiz);
      expect(aramaTipiCoz('giden'), AramaTipi.giden);
      expect(aramaTipiCoz('outgoing'), AramaTipi.giden);
      expect(aramaTipiCoz('gelen'), AramaTipi.gelen);
      expect(aramaTipiCoz(null), AramaTipi.gelen);
      expect(aramaTipiCoz('zort'), AramaTipi.gelen);
    });
  });

  group('cagriSaatMetni', () {
    final simdi = DateTime(2026, 7, 26, 14, 30);

    test('bugünkü çağrı saatiyle, dünkü "Dün" ile gösterilir', () {
      expect(cagriSaatMetni(DateTime(2026, 7, 26, 10, 24), simdi: simdi), '10:24');
      expect(cagriSaatMetni(DateTime(2026, 7, 26, 9, 5), simdi: simdi), '09:05');
      expect(cagriSaatMetni(DateTime(2026, 7, 25, 22, 0), simdi: simdi), 'Dün');
    });

    test('bu hafta gün adı, öncesi gün.ay', () {
      // 2026-07-23 Perşembe
      expect(cagriSaatMetni(DateTime(2026, 7, 23, 8, 0), simdi: simdi), 'Per');
      expect(cagriSaatMetni(DateTime(2026, 7, 2, 8, 0), simdi: simdi), '02.07');
    });

    test('okunamayan zaman boş metin verir', () {
      expect(cagriSaatMetni(null), '');
      expect(cagriSaatMetni(DateTime.tryParse('zort')), '');
    });
  });

  group('cagriKisiCoz — kartın DÖRT varyantı deftere bağlanır', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<String> musteriKur(
      String ad,
      String telefon, {
      String? not,
      String? adres,
      double? lat,
      double? lng,
    }) {
      return CustomerRepository(db).create(
        name: ad,
        note: not,
        phones: [PhoneInput(phoneE164: telefon, isPrimary: true)],
        addresses: [
          if (adres != null)
            AddressInput(
                addressText: adres, lat: lat, lng: lng, isPrimary: true),
        ],
      );
    }

    test('BORÇLU: ad, bakiye, birincil adres, konum ve not kartın modeline geçer', () async {
      final id = await musteriKur(
        'Ahmet Yılmaz',
        '+905324152290',
        not: 'Zil çalışmıyor, gelince arayın.',
        adres: 'Cumhuriyet Mah. 5. Sk. No:12/4',
        lat: 36.8969,
        lng: 30.7133,
      );
      await LedgerRepository(db).borcEkle(id, 34000);

      // Numara BAŞKA biçimde geliyor; eşleşme son 10 hane üzerinden tutmalı.
      final kisi = await cagriKisiCoz(db, '0532 415 22 90');

      expect(kisi.kayitli, isTrue);
      expect(kisi.musteriId, id);
      expect(kisi.ad, 'Ahmet Yılmaz');
      expect(kisi.bakiyeKurus, 34000);
      expect(kisi.adres, 'Cumhuriyet Mah. 5. Sk. No:12/4');
      expect(kisi.konumVar, isTrue);
      expect(kisi.not, 'Zil çalışmıyor, gelince arayın.');
      // Kartta gösterilen numara HAM gelen numaradır (eşleşme anahtarı değil).
      expect(kisi.numara, '0532 415 22 90');
    });

    test('TEMİZ: bakiye 0, adres/not yok → şerit ve bilgi satırları düşer', () async {
      await musteriKur('Selin Kaya', '+905332207841');

      final kisi = await cagriKisiCoz(db, '05332207841');

      expect(kisi.kayitli, isTrue);
      expect(kisi.bakiyeKurus, 0);
      expect(kisi.adres, isNull);
      expect(kisi.not, isNull);
      expect(kisi.sonHareket, isNull, reason: 'ne sipariş ne defter hareketi var');
      expect(kisi.konumVar, isFalse);
    });

    test('ALACAKLI: bakiye NEGATİF gelir', () async {
      final id = await musteriKur('Murat Öz', '+905429076322');
      await LedgerRepository(db).alacak(id, 12000);

      final kisi = await cagriKisiCoz(db, '+90 542 907 63 22');

      expect(kisi.bakiyeKurus, -12000);
      expect(kisi.ad, 'Murat Öz');
    });

    test('KAYITSIZ: defterde olmayan numara, kısa numara ve arşivli müşteri', () async {
      expect((await cagriKisiCoz(db, '0216 555 01 88')).kayitli, isFalse);
      expect((await cagriKisiCoz(db, '0216 555 01 88')).numara, '0216 555 01 88');

      // Gizli numara / kısa servis numarası hiç sorgulanmaz.
      expect((await cagriKisiCoz(db, '112')).kayitli, isFalse);

      // Arşivlenmiş müşterinin telefonu kalsa bile kart "kayıtsız"dır: silinmiş defteri açan
      // bir kart göstermek yanlış olur.
      final id = await musteriKur('Arşivli', '+905331111111');
      await CustomerRepository(db).archive(id);
      expect((await cagriKisiCoz(db, '0533 111 11 11')).kayitli, isFalse);
    });

    test('SON SİPARİŞ satırı: "Son sipariş: {özet} · {saat}" ve kutu ikonu', () async {
      final id = await musteriKur('Siparişli', '+905321112233');
      await LedgerRepository(db).borcEkle(id, 5000); // sipariş VARSA defter hareketi geri kalır
      // KATALOG satırı `productId` İLE kurulur: `×adet` yazımının koşulu bu (serbest satırın
      // ayırt edici ölçütü `isCustom || productId == null` — order_queries.serbestMi ile aynı
      // kural). productId verilmezse satır serbest sayılır ve adetsiz yazılır; aşağıdaki
      // "Kapı tamiri" bunu kanıtlıyor.
      final urunId = await ProductRepository(db)
          .create(name: 'Damacana 19 L', unitPriceKurus: 4500);
      await OrderRepository(db).create(customerId: id, lines: [
        LineInput(
            productId: urunId, productName: 'Damacana 19 L', unitPriceKurus: 4500, qty: 2),
        LineInput(productName: 'Kapı tamiri', unitPriceKurus: 3000, qty: 1, isCustom: true),
      ]);

      final kisi = await cagriKisiCoz(db, '+905321112233');

      expect(kisi.sonHareketTuru, SonHareketTuru.siparis);
      // Katalog kalemi "×adet" ile, serbest kalem adetsiz (s-veri.jsx `siparisOzet`).
      expect(
        kisi.sonHareket,
        matches(RegExp(r'^Son sipariş: Damacana 19 L ×2 · Kapı tamiri · \d{2}:\d{2}$')),
      );
    });

    test('cagriSiparisOzeti: adet YALNIZ katalog satırında yazılır', () async {
      // Kuralın tek başına sağlaması: iki satır AYNI siparişte, tek fark `productId`.
      final urunId = await ProductRepository(db)
          .create(name: 'Damacana 19 L', unitPriceKurus: 4500);
      final musteriId = await musteriKur('Özet', '+905321119999');
      final siparisId = await OrderRepository(db).create(customerId: musteriId, lines: [
        LineInput(
            productId: urunId, productName: 'Damacana 19 L', unitPriceKurus: 4500, qty: 2),
        // productId YOK, isCustom da FALSE: v8 öncesi yazılmış serbest satırların hâli.
        LineInput(productName: 'Eski serbest satır', unitPriceKurus: 1000, qty: 3),
      ]);
      // Adaptörün kendi sorgusuyla AYNI sıralama (id/uuid7 = eklenme sırası).
      final satirlar = await (db.select(db.orderLines)
            ..where((t) => t.orderId.equals(siparisId))
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();

      expect(
        cagriSiparisOzeti(satirlar),
        'Damacana 19 L ×2 · Eski serbest satır',
        reason: 'productId olmayan satır adetsiz yazılır (serbestMi yedek ölçütü)',
      );
    });

    test('SON HAREKET satırı: sipariş yoksa defterden, notu varsa NOT yazılır', () async {
      final id = await musteriKur('Defterli', '+905321112244');
      await LedgerRepository(db).borcEkle(id, 5000, note: 'Elden borç');

      final kisi = await cagriKisiCoz(db, '+905321112244');

      expect(kisi.sonHareketTuru, SonHareketTuru.defter);
      expect(kisi.sonHareket, matches(RegExp(r'^Son hareket: Elden borç · \d{2}:\d{2}$')));
    });

    test('SON HAREKET satırı: not yoksa HAREKET_META etiketi yazılır', () async {
      final id = await musteriKur('Notsuz', '+905321112255');
      await LedgerRepository(db).borcEkle(id, 5000);
      await LedgerRepository(db).tahsilat(id, 2000, 'nakit');

      final kisi = await cagriKisiCoz(db, '+905321112255');

      // En yeni hareket tahsilattır.
      expect(kisi.sonHareket, matches(RegExp(r'^Son hareket: Tahsilat · \d{2}:\d{2}$')));
    });

    test('saf yardımcılar: sipariş özeti · hareket etiketi · satır metni', () {
      expect(cagriHareketEtiketi('payment'), 'Tahsilat');
      expect(cagriHareketEtiketi('credit'), 'Alacak');
      expect(cagriHareketEtiketi('correction'), 'Düzeltme');
      expect(cagriHareketEtiketi('debit'), 'Borç');
      expect(cagriHareketEtiketi('zort'), 'Borç');

      expect(cagriSiparisOzeti(const []), '—');
      expect(
        cagriSonHareketMetni(onEk: 'Son sipariş', govde: 'Damacana ×2', saat: '10:24'),
        'Son sipariş: Damacana ×2 · 10:24',
      );
      // Saat okunamıyorsa ayraç da düşer (kartta yalnız ' · ' asılı kalmasın).
      expect(
        cagriSonHareketMetni(onEk: 'Son hareket', govde: 'Borç', saat: ''),
        'Son hareket: Borç',
      );
    });
  });

  group('CagriKuyrugu.e164', () {
    test('native\'in yazdığı haneleri Türkiye E.164 biçimine çevirir', () {
      expect(CagriKuyrugu.e164('5324152290'), '+905324152290');
      expect(CagriKuyrugu.e164('05324152290'), '+905324152290');
      expect(CagriKuyrugu.e164('905324152290'), '+905324152290');
      // Tanınmayan uzunluk olduğu gibi kalır; eşleşme zaten son 10 hane üzerinden.
      expect(CagriKuyrugu.e164('112'), '112');
    });
  });

  group('Çağrı günlüğü — DB', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('kayıt DB\'ye yazılır ve müşteri son 10 haneden çözülür', () async {
      final musteriId = await CustomerRepository(db).create(
        name: 'Ahmet Yılmaz',
        phones: [PhoneInput(phoneE164: '+905324152290')],
      );
      final gunluk = CallLogRepository(db);

      // Numara BAŞKA biçimde geliyor; eşleşme yine de tutmalı (son 10 hane kuralı).
      await gunluk.log(
        phoneE164: '05324152290',
        direction: CallDirection.incoming,
        occurredAtIso: '2026-07-26T07:24:00.000Z',
      );
      await gunluk.log(
        phoneE164: '+902165550188',
        direction: CallDirection.missed,
        occurredAtIso: '2026-07-26T06:47:00.000Z',
      );

      final kayitlar = await aramaKayitlariAkisi(db).first;

      expect(kayitlar.length, 2);
      // Yeni çağrı üstte.
      expect(kayitlar.first.ad, 'Ahmet Yılmaz');
      expect(kayitlar.first.musteriId, musteriId);
      expect(kayitlar.first.kayitli, isTrue);
      expect(kayitlar.first.tip, AramaTipi.gelen);

      // Kayıtsız numarada ad yok ve tasarımın varsayılan notu düşer.
      expect(kayitlar.last.kayitli, isFalse);
      expect(kayitlar.last.ad, isNull);
      expect(kayitlar.last.sonuc, 'Kayıtsız numara');
      expect(kayitlar.last.tip, AramaTipi.cevapsiz);
    });

    test('sonuç yazılınca akış tazelenir, çağrı saati DEĞİŞMEZ', () async {
      final gunluk = CallLogRepository(db);
      final id = await gunluk.log(
        phoneE164: '+905324152290',
        direction: CallDirection.incoming,
        occurredAtIso: '2026-07-26T07:24:00.000Z',
      );

      await gunluk.setOutcome(id, outcome: 'Sipariş alındı');

      final kayitlar = await aramaKayitlariAkisi(db).first;
      expect(kayitlar.single.sonuc, 'Sipariş alındı');

      final satir = await (db.select(db.callLogs)..where((t) => t.id.equals(id)))
          .getSingle();
      expect(satir.occurredAt, '2026-07-26T07:24:00.000Z');
    });

    test('akıştan gelen kayıt listede çizilecek metinleri taşır', () async {
      await CustomerRepository(db).create(
        name: 'Selin Kaya',
        phones: [PhoneInput(phoneE164: '+905332207841')],
      );
      await CallLogRepository(db).log(
        phoneE164: '+905332207841',
        direction: CallDirection.outgoing,
        occurredAtIso: DateTime.now().toUtc().toIso8601String(),
      );

      // NOT: bu testin widget karşılığı (CagriGunluguSayfasi) BİLEREK yok — `testWidgets`
      // FakeAsync bölgesinde çalışır ve gerçek SQLite beklemeleri orada çözülmez, test asılır.
      // Ekranın çizimi `CagriGunluguEkrani` testleriyle, veri yolu buradan doğrulanıyor.
      final kayit = (await aramaKayitlariAkisi(db).first).single;
      expect(kayit.ad, 'Selin Kaya');
      expect(kayit.tip, AramaTipi.giden);
      expect(kayit.saat, matches(RegExp(r'^\d{2}:\d{2}$')));
    });

    test('kayıt yokken akış boş liste verir (ekran boş duruma düşer)', () async {
      expect(await aramaKayitlariAkisi(db).first, isEmpty);
    });
  });
}
