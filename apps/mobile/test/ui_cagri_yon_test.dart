// Çağrı YÖNÜ ve son sipariş DURUMU — 2026-07-27 saha bulgularının regresyon testleri.
//
// İki hata sahadan geldi:
//  1. Bayi birini aradığında uygulama bunu GELEN çağrı gibi gösteriyordu. Yön native tarafta
//     doğru okunuyordu ama hiçbir yüzeye ULAŞMIYORDU: kartın üst şeridi "GELEN ÇAĞRI"yı sabit
//     yazıyor, çağrı günlüğü yönü yalnız ikon glifiyle ima ediyor, cevapsız çağrı diye bir
//     kavram hiç oluşmuyordu.
//  2. Arayan tanınıyordu ama son siparişinin DURUMU kartta hiç görünmüyordu.
//
// KAPSAM NOTU: gerçek cihazda çizilen kart saf Kotlin'dir (android/.../CallerCard.kt) ve
// buradan test EDİLEMEZ — o tarafta JUnit kaynak kümesi yok. Bu dosya Flutter karşılığını,
// paylaşılan saf eşlemeleri ve native kuyruğun Dart ucunu çiviler.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/call_log_repository.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/repo/product_repository.dart';
import 'package:sipario/screens/cagri/cagri_cozumleyici.dart';
import 'package:sipario/screens/cagri/cagri_gunlugu.dart';
import 'package:sipario/screens/cagri/cagri_karti.dart';
import 'package:sipario/screens/cagri/cagri_kuyrugu.dart';
import 'package:sipario/screens/cagri/cagri_model.dart';
import 'package:sipario/theme/app_theme.dart';

Widget _kabuk(Widget govde) => MaterialApp(
      theme: SipTheme.acik(),
      home: Scaffold(body: govde),
    );

const _ahmet = CagriKisi(
  numara: '0532 415 22 90',
  musteriId: 'm1',
  ad: 'Ahmet Yılmaz',
  bakiyeKurus: 34000,
  adres: 'Cumhuriyet Mah. 5. Sk. No:12/4',
  sonHareket: 'Son sipariş: Damacana 19 L ×2 (10:24)',
  sonSiparisDurumu: 'Yolda',
);

void main() {
  group('saf yön eşlemeleri', () {
    test('kart başlığı üç yönü de ayrı yazar', () {
      expect(cagriYonEtiketi(AramaTipi.gelen), 'GELEN ÇAĞRI');
      expect(cagriYonEtiketi(AramaTipi.giden), 'GİDEN ÇAĞRI');
      expect(cagriYonEtiketi(AramaTipi.cevapsiz), 'CEVAPSIZ ÇAĞRI');
    });

    test('günlük satırının yön sözcüğü', () {
      expect(aramaTipiSozcugu(AramaTipi.gelen), 'Gelen');
      expect(aramaTipiSozcugu(AramaTipi.giden), 'Giden');
      expect(aramaTipiSozcugu(AramaTipi.cevapsiz), 'Cevapsız');
    });

    test('depo metinleri enum\'a çevrilirken giden GELEN sayılmaz', () {
      // Native `CagriYonu.kuyrukKodu` ile aynı sözcükler; biri değişirse burası kırılır.
      expect(aramaTipiCoz('outgoing'), AramaTipi.giden);
      expect(aramaTipiCoz('missed'), AramaTipi.cevapsiz);
      expect(aramaTipiCoz('incoming'), AramaTipi.gelen);
    });
  });

  group('siparisDurumEtiketi', () {
    test('açık sipariş kuryeye atanmışsa YOLDA, değilse hazırlanıyor', () {
      expect(siparisDurumEtiketi('open'), 'Hazırlanıyor');
      expect(siparisDurumEtiketi('open', kuryede: true), 'Yolda');
    });

    test('teslim ve iptal cümle içinde okunacak biçimde yazılır', () {
      expect(siparisDurumEtiketi('delivered'), 'Teslim edildi');
      expect(siparisDurumEtiketi('delivered', kuryede: true), 'Teslim edildi');
      expect(siparisDurumEtiketi('cancelled'), 'İptal edildi');
    });

    test('tanınmayan durum açık sayılır (yeni bir statü sessizce "teslim" görünmesin)', () {
      expect(siparisDurumEtiketi('zort'), 'Hazırlanıyor');
    });
  });

  group('CagriKarti — üst şerit yönü', () {
    testWidgets('gelen çağrıda GELEN ÇAĞRI yazar', (tester) async {
      await tester.pumpWidget(_kabuk(const CagriKarti(kisi: _ahmet)));
      expect(find.text('GELEN ÇAĞRI'), findsOneWidget);
      expect(find.text('GİDEN ÇAĞRI'), findsNothing);
    });

    testWidgets('GİDEN çağrıda kart gelen çağrı DEMEZ', (tester) async {
      await tester.pumpWidget(
        _kabuk(const CagriKarti(kisi: _ahmet, yon: AramaTipi.giden)),
      );
      // Saha hatasının ta kendisi: bayi kendi aradığında "GELEN ÇAĞRI" görüyordu.
      expect(find.text('GELEN ÇAĞRI'), findsNothing);
      expect(find.text('GİDEN ÇAĞRI'), findsOneWidget);
      // Kartın geri kalanı yönden etkilenmez.
      expect(find.text('Ahmet Yılmaz'), findsOneWidget);
      expect(find.text('AÇIK BORÇ'), findsOneWidget);
    });

    testWidgets('cevapsız çağrıda başlık değişir ve nabız DURUR', (tester) async {
      await tester.pumpWidget(
        _kabuk(const CagriKarti(kisi: _ahmet, yon: AramaTipi.cevapsiz)),
      );
      expect(find.text('CEVAPSIZ ÇAĞRI'), findsOneWidget);
      // Nabız kapalı olduğu için ağaç OTURUR; sonsuz animasyonda bu çağrı zaman aşımına düşer.
      await tester.pumpAndSettle();
      expect(find.text('CEVAPSIZ ÇAĞRI'), findsOneWidget);
    });
  });

  group('Geçmişten açılan kart — yön korunur', () {
    // Ayarlar → Çağrı Geçmişi → satıra dokun akışının açtığı YÜZEY budur
    // (`ayarlar_ekrani.dart` `_aramayiAc` → `cagriKartiGoster`). Kayıtsız numarada kart açılır;
    // kayıtlıda müşteri defterine gidilir, kart hiç çizilmez.
    testWidgets('GİDEN çağrının kartı gelen çağrı DEMEZ', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(_kabuk(Builder(builder: (c) {
        ctx = c;
        return const SizedBox.shrink();
      })));

      final bekleyen = cagriKartiGoster(
        ctx,
        kisi: const CagriKisi.kayitsiz('0216 555 01 88'),
        yon: AramaTipi.giden,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('GELEN ÇAĞRI'), findsNothing);
      expect(find.text('GİDEN ÇAĞRI'), findsOneWidget);

      await tester.tap(find.text('Müşteri Olarak Kaydet'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(await bekleyen, CagriEylemi.kaydet);
    });

    testWidgets('yön verilmezse eski davranış (gelen) korunur', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(_kabuk(Builder(builder: (c) {
        ctx = c;
        return const SizedBox.shrink();
      })));

      cagriKartiGoster(ctx, kisi: const CagriKisi.kayitsiz('0216 555 01 88'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('GELEN ÇAĞRI'), findsOneWidget);
    });

    // YAPISAL KİLİT: yukarıdaki test kartın yönü ONURLANDIRDIĞINI kanıtlar, çağrı geçmişi
    // ekranının yönü GEÇTİĞİNİ değil. O akışın uçtan uca widget testi gerçek SQLite bekliyor ve
    // `testWidgets`in FakeAsync bölgesinde asılıyor (bkz. `ui_cagri_test.dart`daki aynı not),
    // yani davranışla kilitlenemiyor. Argümanın silinmesi sessiz bir gerileme olurdu: kart yine
    // açılır, yalnız yanlış yönü yazar. Kaynak taraması bu deseni yakalayan tek ucuz kapı —
    // ekran metni taramalarıyla (mağaza-kuralı testleri) aynı gerekçe.
    // AKIŞ KABUĞA TAŞINDI (2026-08-13): çağrı geçmişinden kart açma mantığı ayarlar
    // ekranından `HomeShell`e geçti (çağrı geçmişinin girişi artık çekmecede). Taranan dosya
    // değişti, KORUNAN KURAL AYNI: yön geçilmezse kart "GELEN ÇAĞRI" varsayar ve bayi kendi
    // yaptığı aramanın kartında gelen çağrı görür (2026-07-27 saha bulgusu).
    // KABUK DÖRDE BÖLÜNDÜ (2026-08-17, 500 satır kuralı): çağrı yüzeyi
    // `home_shell_cagri.dart`a taşındı. Tek dosya adı yazmak yerine kabuğun TÜM parçaları
    // taranıyor — bir sonraki bölme bu testi yine kırmasın diye. Korunan kural değişmedi.
    test('home_shell çağrı kartını AÇARKEN yönü geçirir', () {
      final kaynak = Directory('lib/screens')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('home_shell'))
          .map((f) => f.readAsStringSync())
          .join('\n');
      final cagri = kaynak.indexOf('cagriKartiGoster(');
      expect(cagri, isNot(-1), reason: 'çağrı kartı bu ekrandan açılıyor olmalı');

      final kapanis = kaynak.indexOf(');', cagri);
      final argumanlar = kaynak.substring(cagri, kapanis);
      expect(
        argumanlar,
        contains('yon:'),
        reason: 'yön geçilmezse geçmişten açılan giden çağrı "GELEN ÇAĞRI" yazar',
      );
    });
  });

  group('CagriKarti — son siparişin durumu', () {
    testWidgets('durum rozeti son hareket satırının yanında görünür', (tester) async {
      await tester.pumpWidget(_kabuk(const CagriKarti(kisi: _ahmet)));

      expect(find.text('Son sipariş: Damacana 19 L ×2 (10:24)'), findsOneWidget);
      expect(find.text('Yolda'), findsOneWidget);
    });

    testWidgets('durum yoksa (defter hareketi) rozet hiç çizilmez', (tester) async {
      await tester.pumpWidget(_kabuk(const CagriKarti(
        kisi: CagriKisi(
          numara: '0532 415 22 90',
          musteriId: 'm1',
          ad: 'Defterli',
          sonHareket: 'Son hareket: Elden borç (10:24)',
          sonHareketTuru: SonHareketTuru.defter,
        ),
      )));

      expect(find.text('Son hareket: Elden borç (10:24)'), findsOneWidget);
      expect(find.text('Yolda'), findsNothing);
      expect(find.text('Teslim edildi'), findsNothing);
    });
  });

  group('Çağrı günlüğü — yön satırda YAZILI', () {
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
        id: 'a2',
        numara: '0216 555 01 88',
        saat: '09:47',
        tip: AramaTipi.cevapsiz,
      ),
      AramaKaydi(
        id: 'a3',
        musteriId: 'm2',
        ad: 'Selin Kaya',
        numara: '0533 220 78 41',
        saat: 'Dün',
        tip: AramaTipi.giden,
      ),
    ];

    testWidgets('her satır yönünü sözcükle söyler', (tester) async {
      await tester.pumpWidget(_kabuk(const CagriGunluguEkrani(aramalar: aramalar)));

      expect(find.text('Gelen'), findsOneWidget);
      expect(find.text('Cevapsız'), findsOneWidget);
      expect(find.text('Giden'), findsOneWidget);
    });

    testWidgets('yön sözcüğü alt metnin YERİNE geçmez', (tester) async {
      await tester.pumpWidget(_kabuk(const CagriGunluguEkrani(aramalar: aramalar)));

      // Numara ve sonuç eskisi gibi tek metinde durur (yön ayrı bir metindir).
      expect(find.text('0532 415 22 90, Sipariş alındı'), findsOneWidget);
      expect(find.text('0533 220 78 41'), findsOneWidget);
    });
  });

  group('CagriKuyrugu — aynı çağrının iki satırı TEK kayıttır', () {
    test('anahtarsız satırlar birleşmez, kayıt kimliği depoya bırakılır', () {
      final kayitlar = CagriKuyrugu.birlestir([
        '2026-07-27T07:24:00.000Z|incoming|5324152290',
        '2026-07-27T07:30:00.000Z|incoming|5324152290',
      ]);

      expect(kayitlar.length, 2, reason: 'anahtar yoksa iki ayrı çağrıdır');
      expect(kayitlar.every((k) => k.kayitId == null), isTrue);
      expect(kayitlar.first.numara, '+905324152290');
      expect(kayitlar.first.yon, CallDirection.incoming);
    });

    test('aynı anahtarlı gelen+cevapsız tek kayda iner, SON yön kazanır', () {
      final kayitlar = CagriKuyrugu.birlestir([
        '2026-07-27T07:24:00.000Z|incoming|5324152290|5324152290-1000',
        '2026-07-27T07:24:00.000Z|missed|5324152290|5324152290-1000',
      ]);

      expect(kayitlar.length, 1, reason: 'bir çağrı günlükte iki satır olamaz');
      expect(kayitlar.single.yon, CallDirection.missed);
      // Çağrı SAATİ başlangıç anıdır, cevapsıza dönüldüğü an değil.
      expect(kayitlar.single.zaman, '2026-07-27T07:24:00.000Z');
      expect(kayitlar.single.kayitId, CagriKuyrugu.cagriKayitId('5324152290-1000'));
    });

    test('farklı anahtarlar ayrı çağrıdır, kimlikler deterministik ve farklıdır', () {
      final kayitlar = CagriKuyrugu.birlestir([
        '2026-07-27T07:24:00.000Z|incoming|5324152290|5324152290-1000',
        '2026-07-27T08:00:00.000Z|outgoing|5324152290|5324152290-2000',
      ]);

      expect(kayitlar.length, 2);
      expect(kayitlar.last.yon, CallDirection.outgoing);
      expect(kayitlar.first.kayitId, isNot(kayitlar.last.kayitId));
      // Aynı anahtar HER ZAMAN aynı kimliği verir (iki boşaltma arasında da).
      expect(
        CagriKuyrugu.cagriKayitId('5324152290-1000'),
        CagriKuyrugu.cagriKayitId('5324152290-1000'),
      );
    });

    test('bozuk satır atlanır, kuyruğun geri kalanı işlenir', () {
      final kayitlar = CagriKuyrugu.birlestir([
        'zort',
        '|incoming|5324152290|k1',
        '2026-07-27T07:24:00.000Z|incoming||k2',
        '2026-07-27T07:24:00.000Z|incoming|5324152290|k3',
      ]);

      expect(kayitlar.length, 1);
      expect(kayitlar.single.kayitId, CagriKuyrugu.cagriKayitId('k3'));
    });
  });

  group('CallLogRepository — deterministik kimlikle upsert', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('aynı id ile ikinci yazım YENİ satır açmaz, yönü günceller', () async {
      final gunluk = CallLogRepository(db);
      final id = CagriKuyrugu.cagriKayitId('5324152290-1000');

      await gunluk.log(
        id: id,
        phoneE164: '+905324152290',
        direction: CallDirection.incoming,
        occurredAtIso: '2026-07-27T07:24:00.000Z',
      );
      await gunluk.log(
        id: id,
        phoneE164: '+905324152290',
        direction: CallDirection.missed,
        occurredAtIso: '2026-07-27T07:24:00.000Z',
      );

      final kayitlar = await aramaKayitlariAkisi(db).first;
      expect(kayitlar.length, 1, reason: 'cevapsıza dönen çağrı ikinci satır üretmemeli');
      expect(kayitlar.single.tip, AramaTipi.cevapsiz);
      expect(kayitlar.single.id, id);
    });

    test('id verilmezse eskisi gibi her çağrı ayrı satırdır', () async {
      final gunluk = CallLogRepository(db);
      await gunluk.log(
        phoneE164: '+905324152290',
        direction: CallDirection.incoming,
        occurredAtIso: '2026-07-27T07:24:00.000Z',
      );
      await gunluk.log(
        phoneE164: '+905324152290',
        direction: CallDirection.incoming,
        occurredAtIso: '2026-07-27T07:30:00.000Z',
      );

      expect((await aramaKayitlariAkisi(db).first).length, 2);
    });
  });

  group('cagriKisiCoz — son siparişin durumu karta geçer', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<(String musteriId, String siparisId)> siparisliMusteri(String telefon) async {
      final musteriId = await CustomerRepository(db).create(
        name: 'Siparişli',
        phones: [PhoneInput(phoneE164: telefon, isPrimary: true)],
      );
      final urunId = await ProductRepository(db)
          .create(name: 'Damacana 19 L', unitPriceKurus: 4500);
      final siparisId = await OrderRepository(db).create(customerId: musteriId, lines: [
        LineInput(
            productId: urunId, productName: 'Damacana 19 L', unitPriceKurus: 4500, qty: 2),
      ]);
      return (musteriId, siparisId);
    }

    test('yeni sipariş HAZIRLANIYOR', () async {
      await siparisliMusteri('+905321112233');

      final kisi = await cagriKisiCoz(db, '+905321112233');

      expect(kisi.sonSiparisDurumu, 'Hazırlanıyor');
      expect(kisi.sonHareketTuru, SonHareketTuru.siparis);
    });

    test('kuryeye atanmış sipariş YOLDA', () async {
      final (_, siparisId) = await siparisliMusteri('+905321112244');
      await OrderRepository(db).assign(siparisId, 'kurye-1');

      expect((await cagriKisiCoz(db, '+905321112244')).sonSiparisDurumu, 'Yolda');
    });

    test('teslim edilmiş sipariş TESLİM EDİLDİ', () async {
      final (_, siparisId) = await siparisliMusteri('+905321112255');
      await OrderRepository(db).deliver(siparisId, paymentType: 'nakit');

      expect((await cagriKisiCoz(db, '+905321112255')).sonSiparisDurumu, 'Teslim edildi');
    });

    test('iptal edilmiş sipariş İPTAL EDİLDİ', () async {
      final (_, siparisId) = await siparisliMusteri('+905321112266');
      await OrderRepository(db).cancel(siparisId);

      expect((await cagriKisiCoz(db, '+905321112266')).sonSiparisDurumu, 'İptal edildi');
    });

    test('siparişi olmayan müşteride durum NULL kalır (rozet çizilmez)', () async {
      await CustomerRepository(db).create(
        name: 'Siparişsiz',
        phones: [PhoneInput(phoneE164: '+905321112277', isPrimary: true)],
      );

      final kisi = await cagriKisiCoz(db, '+905321112277');
      expect(kisi.sonSiparisDurumu, isNull);
      expect(kisi.sonHareket, isNull);
    });
  });
}
