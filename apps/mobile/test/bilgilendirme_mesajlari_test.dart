// BİLGİLENDİRME MESAJLARI (kullanıcı isteği 2026-11-06).
//
// DÖRT SORU, DÖRT GRUP:
//   1. MODEL  — kayıt bozulmadan okunup yazılıyor mu, hangi durumda hangi mesaj sunuluyor.
//   2. METİN  — müşteriye giden çözülmüş metin doğru mu (gerçek veritabanıyla).
//   3. YÜZEY  — sipariş ayrıntısındaki bölüm, Mesajlar ekranı ve çekmece.
//   4. SÜRÜM  — ekrandaki yapı numarası ABI sapması taşımıyor.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/data/mesaj_sablonlari.dart';
import 'package:sipario/repo/tenant_settings_repository.dart';
import 'package:sipario/screens/customers/borc_hatirlatma.dart';
import 'package:sipario/screens/isletme/ayarlar/hakkinda_ekrani.dart';
import 'package:sipario/screens/isletme/ayarlar/mesaj_sablonlari_ekrani.dart';
import 'package:sipario/screens/isletme/whatsapp_bicim_cubugu.dart';
import 'package:sipario/screens/orders/bilgilendirme_mesaji.dart';
import 'package:sipario/screens/orders/musteri_eylemleri.dart';
import 'package:sipario/screens/orders/order_detail_screen.dart';
import 'package:sipario/screens/shell/cekmece.dart';

import 'support/ekran_yardimcilari.dart' as ekran;
import 'support/siparis_yardimci.dart';

/// Tek müşterili, tek siparişli bir bayi.
///
/// FİKSTÜR SINIFI (depo kuralı 2026-08-17): kurulum durumu ve onun üzerinde işleyen davranış tek
/// nesnede kapsüllenir.
class MesajTezgahi {
  MesajTezgahi() : db = AppDatabase(NativeDatabase.memory());

  final AppDatabase db;
  static const siparisId = 'sip-1';
  static const damga = '2026-11-06T09:00:00.000Z';

  Future<void> kur({
    String durum = 'open',
    String rol = 'patron',
    int bakiye = 0,
    String? odeme,
    bool iban = true,
    bool telefon = true,
  }) async {
    await db.syncState();
    await (db.update(db.syncMeta)..where((t) => t.id.equals(1)))
        .write(SyncMetaCompanion(userRole: Value(rol)));
    await db.into(db.users).insert(UsersCompanion.insert(
          id: 'k1',
          name: 'Ali Kurye',
          role: 'kurye',
          status: 'active',
        ));
    await db.into(db.customers).insert(CustomersCompanion.insert(
          id: 'm1',
          name: 'Ayşe Yılmaz',
          balanceKurus: Value(bakiye),
          updatedOccurredAt: damga,
        ));
    if (telefon) {
      await db.into(db.customerPhones).insert(CustomerPhonesCompanion.insert(
            id: 'p1',
            customerId: 'm1',
            phoneE164: '+905324152290',
            phoneLast10: '5324152290',
            isPrimary: const Value(true),
            updatedOccurredAt: damga,
          ));
    }
    await db.into(db.customerAddresses).insert(CustomerAddressesCompanion.insert(
          id: 'a1',
          customerId: 'm1',
          addressText: 'Lale Sokak 4',
          isPrimary: const Value(true),
          updatedOccurredAt: damga,
        ));
    await db.into(db.orders).insert(OrdersCompanion.insert(
          id: siparisId,
          customerId: const Value('m1'),
          code: const Value(42),
          assignedUserId: const Value('k1'),
          status: Value(durum),
          totalKurus: const Value(24000),
          paymentType: Value(odeme),
          occurredAt: damga,
        ));
    await db.into(db.orderLines).insert(OrderLinesCompanion.insert(
          id: 'l1',
          orderId: siparisId,
          productId: const Value('u1'),
          productName: '19 L Su',
          unitPriceKurus: 12000,
          qty: 2,
          lineTotalKurus: 24000,
        ));
    await depo.save(
      businessName: const Value('Merkez Su'),
      phone: const Value('02421234567'),
      iban: Value(iban ? 'TR330006100519786457841326' : null),
    );
  }

  TenantSettingsRepository get depo => TenantSettingsRepository(db);

  Future<SiparisMesajHazirlayici> hazirlayici() async {
    final siparis =
        await (db.select(db.orders)..where((t) => t.id.equals(siparisId))).getSingle();
    final satirlar = await db.select(db.orderLines).get();
    return SiparisMesajHazirlayici(
      db: db,
      order: siparis,
      satirlar: satirlar,
      simdi: DateTime(2026, 11, 6),
    );
  }

  Future<MesajSablonlari> sablonlar() async =>
      MesajSablonlari.coz((await depo.get())?.messageTemplatesJson);
}

/// `uriAcici` dikişinin sahtesi: hangi metnin WhatsApp'a gittiğini tutar.
class SahteWhatsapp {
  final List<Uri> acilanlar = [];

  Future<bool> ac(Uri uri) async {
    acilanlar.add(uri);
    return true;
  }

  String? get sonMetin =>
      acilanlar.isEmpty ? null : acilanlar.last.queryParameters['text'];
}

MesajTuru _tur(String anahtar) => kMesajTurleri.firstWhere((t) => t.anahtar == anahtar);

const _dugme = 'Bilgilendirme Mesajı Gönder';

/// Tek düğmeye dokunup mesaj listesini açar.
Future<void> _listeyiAc(WidgetTester tester) async {
  await tester.ensureVisible(find.text(_dugme));
  await tester.tap(find.text(_dugme));
  await akisiBekle(tester);
}

Future<void> _detayiAc(WidgetTester tester, MesajTezgahi tezgah) async {
  genisYuzey(tester);
  await tester.pumpWidget(sipKabuk(OrderDetailScreen(
    db: tezgah.db,
    orderId: MesajTezgahi.siparisId,
    writable: true,
  )));
  await akisiBekle(tester);
}

void main() {
  group('Model', () {
    test('yazılan kayıt aynen okunur, hiç dokunulmamış kayıt null yazılır', () {
      final m = MesajSablonlari.bos
          .sistemIle(_tur('yola_cikti'), 'Yoldayız')
          .ozelIle(const OzelMesaj(id: 'o1', baslik: 'Kampanya', metin: 'İndirim var'));

      final geri = MesajSablonlari.coz(m.yaz());
      expect(geri.metin(_tur('yola_cikti')), 'Yoldayız');
      expect(geri.ozel.single.baslik, 'Kampanya');
      expect(MesajSablonlari.bos.yaz(), isNull);
    });

    test('bozuk kayıt ekranı düşürmez, boş PHP dizisi de boş sayılır', () {
      for (final bozuk in ['{', '[1]', '"metin"', '', '{"sistem":[],"ozel":[{"id":1}]}']) {
        final m = MesajSablonlari.coz(bozuk);
        expect(m.ozel, isEmpty, reason: bozuk);
        expect(m.metin(_tur('gecikme')), _tur('gecikme').varsayilan, reason: bozuk);
      }
    });

    test('siparişin durumuna uymayan mesaj sunulmaz, bayinin mesajı her durumda sunulur', () {
      final m = MesajSablonlari.bos
          .ozelIle(const OzelMesaj(id: 'o1', baslik: 'Kampanya', metin: 'x'));
      List<String> adlar(String durum) => [for (final s in m.siparisIcin(durum)) s.baslik];

      expect(adlar('open'), [
        'Sipariş Alındı',
        'Yola Çıktı',
        'Gecikme Bilgisi',
        'Adreste Ulaşılamadı',
        'Kampanya',
      ]);
      expect(adlar('delivered'), ['Teslim Edildi', 'Ödeme Alındı', 'Kampanya']);
      expect(adlar('cancelled'), ['Sipariş İptali', 'Kampanya']);
    });

    test('varsayılana dönen metin kayıttan silinir: iyileşen varsayılanı bayi de alır', () {
      final tur = _tur('gecikme');
      final ozel = MesajSablonlari.bos.sistemIle(tur, 'Geciktik');
      expect(ozel.ozelMetin(tur), 'Geciktik');
      expect(ozel.sistemIle(tur, tur.varsayilan).ozelMetin(tur), isNull);
      expect(ozel.sistemIle(tur, '  ').ozelMetin(tur), isNull);
    });

    test('güncelleme yerinde olur, silme yalnız o mesajı götürür', () {
      final m = MesajSablonlari.bos
          .ozelIle(const OzelMesaj(id: 'a', baslik: 'A', metin: '1'))
          .ozelIle(const OzelMesaj(id: 'b', baslik: 'B', metin: '2'))
          .ozelIle(const OzelMesaj(id: 'a', baslik: 'A2', metin: '3'));
      expect([for (final o in m.ozel) o.baslik], ['A2', 'B']);
      expect([for (final o in m.ozelHaric('a').ozel) o.id], ['b']);
    });

    test('mesaj adı boş, uzun ya da hazır bir türle aynı olamaz; kendi adıyla çakışmaz', () {
      final m = MesajSablonlari.bos
          .ozelIle(const OzelMesaj(id: 'a', baslik: 'Kampanya', metin: '1'));
      expect(m.adHatasi(' '), isNotNull);
      expect(m.adHatasi('x' * 41), isNotNull);
      expect(m.adHatasi('YOLA ÇIKTI'), isNotNull);
      expect(m.adHatasi('kampanya'), isNotNull);
      expect(m.adHatasi('Kampanya', id: 'a'), isNull);
      expect(m.adHatasi('Duyuru'), isNull);
    });

    test('varsayılan metinler sunucu sınırına sığar: bayi yükleyip kaydedebilmeli', () {
      for (final t in kMesajTurleri) {
        expect(t.varsayilan.length, lessThanOrEqualTo(MesajSablonlari.azamiMetin),
            reason: t.anahtar);
      }
      expect(varsayilanHatirlatmaSablonu.length, lessThanOrEqualTo(MesajSablonlari.azamiMetin));
    });

    test('hazır metinlerdeki her yer tutucu çip listesinde vardır', () {
      final bilinen = {for (final y in bilgilendirmeYerTutuculari) y.jeton};
      for (final t in kMesajTurleri) {
        final kullanilan = RegExp(r'\*[a-z]+\*').allMatches(t.varsayilan).map((e) => e.group(0)!);
        expect(bilinen, containsAll(kullanilan), reason: t.anahtar);
      }
    });
  });

  group('Kayıt', () {
    test('başka bir ayar yazımı mesajları silmez ve yük senkrona gider', () async {
      final t = MesajTezgahi();
      addTearDown(t.db.close);
      await t.depo.mesajSablonlariGuncelle(
        (m) => m.ozelIle(const OzelMesaj(id: 'o1', baslik: 'Kampanya', metin: 'İndirim')),
      );
      await t.depo.save(businessName: const Value('Yeni Ad'));

      expect((await t.sablonlar()).ozel.single.id, 'o1');
      final son = (await t.db.select(t.db.outbox).get()).last;
      expect(son.payload, contains('"message_templates"'));
      expect(son.payload, contains('Kampanya'));
    });
  });

  group('Müşteriye giden metin', () {
    test('Sipariş Alındı siparişin gerçek bilgileriyle dolar', () async {
      final t = MesajTezgahi();
      addTearDown(t.db.close);
      await t.kur();

      final h = await t.hazirlayici();
      expect(
        await h.bilgilendirme(_tur('siparis_alindi').varsayilan),
        'Sayın Ayşe Yılmaz,\n'
        '\n'
        'Siparişiniz tarafımıza ulaşmış ve işleme alınmıştır.\n'
        '\n'
        'Sipariş numarası: #42\n'
        'Sipariş içeriği:\n'
        '2 adet 19 L Su\n'
        'Toplam tutar: 240,00 ₺\n'
        'Teslimat adresi: Lale Sokak 4\n'
        '\n'
        'Bizi tercih ettiğiniz için teşekkür ederiz.\n'
        '\n'
        'Saygılarımızla,\n'
        'Merkez Su',
      );
    });

    test('Yola Çıktı görevlinin adını yazar, Teslim Edildi ödeme şeklini', () async {
      final t = MesajTezgahi();
      addTearDown(t.db.close);
      await t.kur(durum: 'delivered', odeme: 'nakit');

      final h = await t.hazirlayici();
      expect(await h.bilgilendirme(_tur('yola_cikti').varsayilan),
          contains('Teslim edecek görevli: Ali Kurye'));
      expect(await h.bilgilendirme(_tur('teslim_edildi').varsayilan),
          contains('Ödeme şekli: Nakit'));
    });

    test('bilgisi olmayan satır düşer, ham yer tutucu müşteriye gitmez', () async {
      final t = MesajTezgahi();
      addTearDown(t.db.close);
      await t.kur();

      final m = await (await t.hazirlayici()).bilgilendirme(_tur('odeme_alindi').varsayilan);
      expect(m, isNot(contains('Son ödemeniz')), reason: 'hiç ödeme kaydı yok');
      expect(m, contains('Güncel bakiyeniz: 0,00 ₺'));

      for (final tur in kMesajTurleri) {
        final cozulmus = await (await t.hazirlayici()).bilgilendirme(tur.varsayilan);
        expect(cozulmus, isNot(matches(RegExp(r'\*[a-z]+\*'))), reason: tur.anahtar);
      }
    });

    test('borç hatırlatma: borç yoksa ve IBAN yoksa gerekçe döner, mesaj kurulmaz', () async {
      final borcsuz = MesajTezgahi();
      addTearDown(borcsuz.db.close);
      await borcsuz.kur();
      expect((await (await borcsuz.hazirlayici()).borcHatirlatma()).gerekce,
          'Bu müşterinin açık borcu yok');

      final ibansiz = MesajTezgahi();
      addTearDown(ibansiz.db.close);
      await ibansiz.kur(bakiye: 5000, iban: false);
      expect((await (await ibansiz.hazirlayici()).borcHatirlatma()).gerekce, ibanEksikUyarisi);
    });

    test('borç hatırlatma kurumsal metinle kurulur', () async {
      final t = MesajTezgahi();
      addTearDown(t.db.close);
      await t.kur(bakiye: 25000);

      final m = (await (await t.hazirlayici()).borcHatirlatma()).mesaj!;
      expect(m, startsWith('Sayın Ayşe Yılmaz,\n\nMerkez Su olarak bize duyduğunuz güven'));
      expect(m, contains('06.11.2026 tarihi itibarıyla cari hesabınızda 250,00 ₺ tutarında'));
      expect(m, contains('TR33 0006 1005 1978 6457 8413 26'));
      expect(m, endsWith('Saygılarımızla,\nMerkez Su'));
    });
  });

  group('Sipariş ayrıntısı', () {
    late SahteWhatsapp whatsapp;
    setUp(() {
      whatsapp = SahteWhatsapp();
      uriAcici = whatsapp.ac;
    });
    tearDown(() => uriAcici = (_) async => false);

    testWidgets('mesajlar ekranda durmaz, tek düğme listeyi açar', (tester) async {
      final t = MesajTezgahi();
      await tester.runAsync(() => t.kur());
      await _detayiAc(tester, t);

      expect(find.text(_dugme), findsOneWidget);
      expect(find.text('Yola Çıktı'), findsNothing);

      await _listeyiAc(tester);
      expect(find.text('Yola Çıktı'), findsOneWidget);

      await ekraniKapat(tester);
    });

    testWidgets('düğme Teslim Et düğmesinin üstünde, eylemlerin yanında durur', (tester) async {
      final t = MesajTezgahi();
      await tester.runAsync(() => t.kur());
      await _detayiAc(tester, t);

      final mesaj = tester.getCenter(find.text(_dugme)).dy;
      expect(mesaj, lessThan(tester.getCenter(find.text('Teslim Et')).dy));
      expect(mesaj, greaterThan(tester.getCenter(find.text('Teslimat Adresi')).dy));

      await ekraniKapat(tester);
    });

    testWidgets('açık siparişte uygun mesajlar sunulur, teslim mesajı sunulmaz',
        (tester) async {
      final t = MesajTezgahi();
      await tester.runAsync(() => t.kur());
      await _detayiAc(tester, t);
      await _listeyiAc(tester);

      expect(find.text('Bilgilendirme Mesajı'), findsOneWidget);
      expect(find.text('Yola Çıktı'), findsOneWidget);
      expect(find.text('Borç Hatırlatma'), findsOneWidget);
      expect(find.text('Teslim Edildi'), findsNothing);

      await ekraniKapat(tester);
    });

    testWidgets('mesaja dokununca sipariş bilgileriyle dolu metin WhatsApp\'ta açılır',
        (tester) async {
      final t = MesajTezgahi();
      await tester.runAsync(() => t.kur());
      await _detayiAc(tester, t);
      await _listeyiAc(tester);

      await tester.tap(find.text('Adreste Ulaşılamadı'));
      await ekran.akislariBekle(tester, tur: 12);

      expect(whatsapp.acilanlar, hasLength(1));
      expect(whatsapp.acilanlar.single.scheme, 'whatsapp');
      expect(whatsapp.sonMetin, contains('Sayın Ayşe Yılmaz'));
      expect(whatsapp.sonMetin, contains('Sipariş numarası: #42'));

      await ekraniKapat(tester);
    });

    testWidgets('bayinin eklediği mesaj görünür ve kendi metniyle gider', (tester) async {
      final t = MesajTezgahi();
      await tester.runAsync(() async {
        await t.kur();
        await t.depo.mesajSablonlariGuncelle((m) => m.ozelIle(const OzelMesaj(
              id: 'o1',
              baslik: 'Kampanya',
              metin: 'Sayın *musteriadi*, indirim başladı',
            )));
      });
      await _detayiAc(tester, t);
      await _listeyiAc(tester);

      await tester.tap(find.text('Kampanya'));
      await ekran.akislariBekle(tester, tur: 12);
      expect(whatsapp.sonMetin, 'Sayın Ayşe Yılmaz, indirim başladı');

      await ekraniKapat(tester);
    });

    testWidgets('borçsuz müşteride Borç Hatırlatma nedenini söyler, WhatsApp açılmaz',
        (tester) async {
      final t = MesajTezgahi();
      await tester.runAsync(() => t.kur());
      await _detayiAc(tester, t);
      await _listeyiAc(tester);

      await tester.tap(find.text('Borç Hatırlatma'));
      await akisiBekle(tester);
      expect(find.text('Bu müşterinin açık borcu yok'), findsOneWidget);
      expect(whatsapp.acilanlar, isEmpty);

      await ekraniKapat(tester);
    });

    testWidgets('hatırlatma yetkisi olmayan kurye Borç Hatırlatma görmez, ötekiler görünür',
        (tester) async {
      final t = MesajTezgahi();
      await tester.runAsync(() => t.kur(rol: 'kurye', bakiye: 5000));
      await _detayiAc(tester, t);
      await _listeyiAc(tester);

      expect(find.text('Borç Hatırlatma'), findsNothing);
      expect(find.text('Yola Çıktı'), findsOneWidget);

      await ekraniKapat(tester);
    });

    testWidgets('müşterisiz siparişte düğme hiç çizilmez', (tester) async {
      final t = MesajTezgahi();
      await tester.runAsync(() async {
        await t.kur();
        await (t.db.update(t.db.orders)..where((o) => o.id.equals(MesajTezgahi.siparisId)))
            .write(const OrdersCompanion(customerId: Value(null)));
      });
      await _detayiAc(tester, t);

      expect(find.text(_dugme), findsNothing);

      await ekraniKapat(tester);
    });
  });

  group('Mesajlar ekranı', () {
    testWidgets('biçim düğmesi seçimi sarar, önizleme işaretsiz gösterir, metin kaydedilir',
        (tester) async {
      final t = MesajTezgahi();
      await tester.runAsync(() => t.kur());
      genisYuzey(tester);
      await tester.pumpWidget(sipKabuk(MesajSablonlariEkrani(db: t.db)));
      await akisiBekle(tester);

      await tester.tap(find.text('Yeni Mesaj Ekle'));
      await akisiBekle(tester);
      await tester.enterText(find.byType(TextField).first, 'Kampanya');
      final metin = find.byType(TextField).last;
      await tester.enterText(metin, 'Sayın **musteriadi**');
      await tester.pump();

      final alan = tester.widget<TextField>(metin);
      alan.controller!.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.tap(find.text('İtalik'));
      await tester.pump();

      expect(alan.controller!.text, '_Sayın_ **musteriadi**');
      final onizleme = find.byType(WhatsappOnizleme);
      await tester.ensureVisible(onizleme);
      expect(find.text('Önizleme'), findsOneWidget);
      expect(
        find.descendant(of: onizleme, matching: find.textContaining('Sayın Müşteri', findRichText: true)),
        findsOneWidget,
        reason: 'işaretler önizlemede görünmez, yer tutucu adıyla çözülür',
      );

      await tester.ensureVisible(find.text('Kaydet'));
      await tester.tap(find.text('Kaydet'));
      await akisiBekle(tester);

      final kayit = await tester.runAsync(t.sablonlar);
      expect(kayit!.ozel.single.metin, '_Sayın_ **musteriadi**');

      await ekraniKapat(tester);
    });

    testWidgets('yeni mesaj eklenir, listede görünür, düzenlenir ve silinir', (tester) async {
      final t = MesajTezgahi();
      await ekran.ekranaKoy(tester, MesajSablonlariEkrani(db: t.db));

      await ekran.dokun(tester, find.text('Yeni Mesaj Ekle'));
      final alanlar = find.byType(TextField);
      await tester.enterText(alanlar.at(0), 'Kampanya');
      await tester.enterText(alanlar.at(1), 'Sayın ');
      await tester.pump();
      await ekran.dokun(tester, find.text('Müşteri adı'));
      await ekran.dokun(tester, find.text('Kaydet'));
      await tester.pump(const Duration(milliseconds: 600));
      await ekran.akislariBekle(tester);

      final eklenen = (await tester.runAsync(() => t.sablonlar()))!.ozel.single;
      expect(eklenen.metin, 'Sayın *musteriadi*');
      expect(find.text('Kampanya'), findsOneWidget, reason: 'liste akışla okur, bayat kalmaz');

      await ekran.dokun(tester, find.text('Kampanya'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.enterText(find.byType(TextField).at(1), 'Yeni metin');
      await tester.pump();
      await ekran.dokun(tester, find.text('Kaydet'));
      await tester.pump(const Duration(milliseconds: 600));
      await ekran.akislariBekle(tester);
      final guncel = (await tester.runAsync(() => t.sablonlar()))!.ozel.single;
      expect(guncel.id, eklenen.id);
      expect(guncel.metin, 'Yeni metin');

      await ekran.dokun(tester, find.text('Kampanya'));
      await tester.pump(const Duration(milliseconds: 600));
      await ekran.dokun(tester, find.text('Mesajı Sil'));
      await tester.pump(const Duration(milliseconds: 400));
      await ekran.dokun(tester, find.text('Sil'));
      await tester.pump(const Duration(milliseconds: 600));
      await ekran.akislariBekle(tester);
      expect((await tester.runAsync(() => t.sablonlar()))!.ozel, isEmpty);

      await ekran.kapat(tester);
    });

    testWidgets('adı ve metni boş mesaj kaydedilmez, sebep formda söylenir', (tester) async {
      final t = MesajTezgahi();
      await ekran.ekranaKoy(tester, MesajSablonlariEkrani(db: t.db));

      await ekran.dokun(tester, find.text('Yeni Mesaj Ekle'));
      await tester.pump(const Duration(milliseconds: 600));
      await ekran.dokun(tester, find.text('Kaydet'));

      expect(find.text('Mesaj adı yazın'), findsOneWidget);
      expect(find.text('Mesaj metnini yazın'), findsOneWidget);
      expect(await tester.runAsync(() => t.depo.get()), isNull);

      await ekran.kapat(tester);
    });

    testWidgets('hazır mesaj varsayılan metniyle açılır, değiştirmeden kaydetmek kayıt yazmaz',
        (tester) async {
      final t = MesajTezgahi();
      await ekran.ekranaKoy(tester, MesajSablonlariEkrani(db: t.db));

      await ekran.dokun(tester, find.text('Yola Çıktı'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text,
          _tur('yola_cikti').varsayilan);

      await ekran.dokun(tester, find.text('Kaydet'));
      await tester.pump(const Duration(milliseconds: 600));
      await ekran.akislariBekle(tester);
      expect((await tester.runAsync(() => t.depo.get()))!.messageTemplatesJson, isNull);

      await ekran.kapat(tester);
    });
  });

  group('Çekmece', () {
    Future<List<CekmeceGiris>> kur(WidgetTester tester, {required bool isletmeGorunur}) async {
      final gidilen = <CekmeceGiris>[];
      await ekran.ekranaKoy(
        tester,
        SipCekmece(
          acik: true,
          onKapat: () {},
          isletmeAdi: 'Merkez Su',
          rol: 'patron',
          onGiris: gidilen.add,
          onCikis: () {},
          onDestek: () {},
          isletmeGorunur: isletmeGorunur,
        ),
      );
      return gidilen;
    }

    testWidgets('patronda İşletme ve Mesajlar Yönetim altındadır ve hedefe gider', (tester) async {
      final gidilen = await kur(tester, isletmeGorunur: true);

      final yonetimY = tester.getTopLeft(find.text('YÖNETİM')).dy;
      expect(tester.getTopLeft(find.text('İşletme')).dy, greaterThan(yonetimY));
      expect(tester.getTopLeft(find.text('Mesajlar')).dy, greaterThan(yonetimY));

      await tester.tap(find.text('İşletme'));
      await tester.tap(find.text('Mesajlar'));
      expect(gidilen, [CekmeceGiris.isletme, CekmeceGiris.mesajlar]);

      await ekran.kapat(tester);
    });

    testWidgets('ölçüt kapalıyken ikisi de çizilmez', (tester) async {
      await kur(tester, isletmeGorunur: false);

      expect(find.text('İşletme'), findsNothing);
      expect(find.text('Mesajlar'), findsNothing);

      await ekran.kapat(tester);
    });
  });

  group('Sürüm satırı', () {
    test('ABI sapmalı paket numarası değil gerçek yapım yazılır', () {
      // Ölçüldü: yayındaki arm64 APK'da versionCode 2618, surum.json'da yapim 618.
      expect(surumMetni(ad: '1.15.0', paketYapisi: '2618', yapim: 618), 'Sipario 1.15.0 (618)');
    });

    test('yerel derlemede paket numarasına, numara da yoksa yalnız ada düşülür', () {
      expect(surumMetni(ad: '1.15.0', paketYapisi: '12', yapim: 0), 'Sipario 1.15.0 (12)');
      expect(surumMetni(ad: '1.15.0', paketYapisi: ' ', yapim: 0), 'Sipario 1.15.0');
      expect(surumMetni(ad: ' ', paketYapisi: '12', yapim: 618), 'Sipario');
    });
  });
}
