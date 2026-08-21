// GÜN SINIRI EKRAN KATMANINDA — "hangi gün" sorusunu her yüzey AYNI saatten cevaplamalı.
//
// Bu depoda gün sınırı kuralı `data/tr_gun.dart`ta TEK yerde toplandı ve kayıtlar DÜZELTİLMİŞ
// sunucu saatiyle (`correctedNowIso`) damgalanıyor. Ekran katmanında iki yer o toplamada
// ATLANMIŞTI ve ikisi de cihaz saatinden gün türetiyordu:
//
//  1. Ana ekranın "Bugün Kasa" bento kutusu (`shell/ana_ozet.dart`) — kendi `+3` sabiti ve kendi
//     `bugunTrGunu()`sü vardı. Telefon 40 dk ileriyken 23:40'ta kutu "0,00 ₺" derken, kutuya
//     dokununca açılan Gün Özeti "12.000,00 ₺" diyordu: aynı büyüklük, bir dokunuş arayla iki
//     farklı gerçek.
//  2. Arşiv satırlarındaki "Bugün/Dün" kelimesi (`gunSaatBicimi`) — kaydın GÜNÜ düzeltilmiş
//     saatten çıkarken kelime cihaz saatinden çıkıyordu.
//
// TESTİN HİLESİ: `serverTimeOffsetMs` −24 saate kurulur. O zaman düzeltilmiş "bugün", cihazın
// dünüdür ve kayıtlar da oraya damgalanır. Sapma TAM BİR GÜN olduğu için sonuç saatten bağımsız
// deterministiktir — "şimdi − 40 dakika" ile kurulan bir test gün sınırına yakın koştuğunda
// yazı-turaya döner ve bu depoda daha önce döndü.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/data/tr_gun.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/day_closing_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/screens/ana_ekran.dart';
import 'package:sipario/screens/day_end_screen.dart';
import 'package:sipario/screens/shell/ana_ozet.dart';
import 'package:sipario/theme/components/atoms.dart';

import 'support/ekran_yardimcilari.dart';

/// Cihaz saatini 24 saat İLERİ göstertir: düzeltilmiş "şimdi" artık cihazın dünüdür.
Future<void> saatiBirGunIleriKur(AppDatabase db) => db
    .update(db.syncMeta)
    .write(const SyncMetaCompanion(serverTimeOffsetMs: Value(-86400000)));

/// Nakit tahsilatlı bir teslimat (damgayı repo düzeltilmiş saatle kendi koyar).
Future<void> nakitSiparis(AppDatabase db, {int tutarKurus = 9000}) async {
  final cid = await CustomerRepository(db).create(name: 'Ayşe');
  final oid = await OrderRepository(db).create(
    customerId: cid,
    lines: [LineInput(productName: 'Damacana', unitPriceKurus: tutarKurus, qty: 1)],
  );
  await OrderRepository(db).deliver(oid, paymentType: 'nakit');
}

void main() {
  group('Bugün Kasa ile Gün Özeti AYNI günü konuşur', () {
    test('bento rakamı DÜZELTİLMİŞ günden gelir — Gün Özeti\'nin kasasıyla birebir', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await saatiBirGunIleriKur(db);
      await nakitSiparis(db);

      final gun = await bugunTrDuzeltilmis(db);
      final ozet = await gunSonuOzeti(db, gun);
      final bento = await watchAnaOzet(db).first;

      // ASIL İDDİA: iki yüzey aynı parayı sayıyor. Rakamı elle yazmıyoruz — kasa özetinin tanımı
      // repo'nun ve değişebilir; kilitlenen şey İKİSİNİN AYNI OLMASI.
      expect(bento.bugunTahsilatKurus, ozet.kasa.toplam);
      expect(bento.bugunTahsilatKurus, 9000, reason: 'kayıt düzeltilmiş güne düştü');

      // KONTROL: test boşa dönmesin. Cihaz günü gerçekten BAŞKA bir gün ve orada kasa boş —
      // yani yukarıdaki eşitlik "iki taraf da tesadüfen aynı günü buldu" demek değil.
      final cihazGunu = trGunu(DateTime.now());
      expect(cihazGunu, isNot(gun));
      final cihazBentosu = await watchAnaOzet(db, gun: cihazGunu).first;
      expect(cihazBentosu.bugunTahsilatKurus, 0,
          reason: 'cihaz saatiyle bakan eski kod tam olarak bunu gösteriyordu');
    });

    testWidgets('bento KUTUSU da düzeltilmiş günün tutarını basar', (tester) async {
      // Veri katmanı doğru olup ekranın kendi gününü geçirmesi mümkündü; kutu okunarak kapatılır.
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await saatiBirGunIleriKur(db);
        await nakitSiparis(db);
      });

      await ekranaKoy(
        tester,
        AnaEkran(
          db: db,
          sahipAdi: 'Mehmet Usta',
          onMenu: () {},
          onSekme: (_) {},
          onYeniSiparis: () {},
          onBorclular: () {},
          onBildirimler: () {},
          onArama: (_) {},
          onSiparisAc: (_) {},
        ),
      );

      final kasaKutusu =
          find.ancestor(of: find.text('Bugün Kasa'), matching: find.byType(SipDokun));
      expect(
        find.descendant(of: kasaKutusu, matching: find.text(sipTutar(9000))),
        findsOneWidget,
      );
      expect(
        find.descendant(of: kasaKutusu, matching: find.text(sipTutar(0))),
        findsNothing,
        reason: 'cihaz saatinden bakan kutu "0,00 ₺" yazıyordu',
      );

      await kapat(tester);
    });
  });

  group('"Bugün/Dün" etiketi düzeltilmiş saatten türer', () {
    testWidgets('bugün kapatılan hesap arşiv satırında "Bugün" yazar', (tester) async {
      // Kapanış damgası düzeltilmiş saatle yazılır; kelime cihaz saatinden çıksaydı bayi az önce
      // kapattığı hesabın altında "Dün 09:20" okurdu — kapanış append-only olduğu için de o satır
      // kalıcı biçimde yanlış anlaşılırdı.
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await saatiBirGunIleriKur(db);
        await nakitSiparis(db);
        await DayClosingRepository(db)
            .kapat(scope: ClosingScope.day, countedCashKurus: 9000);
      });

      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));

      expect(find.text('Bugünün Kapanışları'), findsOneWidget);
      // Satır metni "Bugün 18:05 · 1 teslimat" biçimindedir. Başlıktaki tek başına "Bugün"
      // (üst çubuğun alt satırı) bu desene UYMAZ, yani iddia gerçekten arşiv satırını tutuyor.
      expect(find.textContaining(RegExp(r'^Bugün \d{2}:\d{2} saatinde kapatıldı, ')), findsOneWidget);
      expect(find.textContaining('Dün '), findsNothing,
          reason: 'cihaz saatinden bakan eski kod burada "Dün" yazıyordu');

      await kapat(tester);
    });
  });
}
