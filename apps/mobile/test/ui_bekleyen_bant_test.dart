// ERTELENEN KAYITLAR GÖRÜNÜR OLMALI — "hesaplanıyor ama kimse okumuyor" kapısı.
//
// BORÇ (2026-08-09, aynı gün kapatıldı): `PushOzeti.beklemede` motorda doğru hesaplanıyor ve
// `sync_karantina_test.dart` onu motor düzeyinde kilitliyordu — ama `lib/` içinde tek bir
// OKUYUCUSU yoktu. `SyncService` tur sonucunu yalnız `kaliciRed` ve okunamayan satır sayısından
// türetiyordu; sonuç: sunucu 12 kaydı bilerek ertelemişken tur "başarılı" sayılıyor ve senkron
// çipi "güncel" diyordu. Kayıt kaybolmuyordu, ama kullanıcı biriktiğini HİÇ öğrenemiyordu.
//
// Bu dosya boru hattının OKUNAN ucunu kilitler: motor → `SyncOutcome` → kabuk bandı.
// Motor ucu zaten kilitli; kırılan halka hep sonuncusu oluyor (bkz. güncelleme bandı 2026-07-28:
// servis çalışıyordu, bandı hiçbir ekran mount etmemişti).
//
// ASIL KORUNAN SENARYO ABONELİK DEĞİL SÜRÜM ÇARPIKLIĞIDIR: kilitli bayide zaten kilit ekranı var,
// yani ikinci bir sinyal. Sunucu yarın tanımadığımız bir durum döndürürse (beyaz liste onu
// `beklet`e düşürür) ortada BAŞKA hiçbir sinyal yoktur — bant o gün tek uyarıdır.

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/auth/session.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/screens/home_shell.dart';
import 'package:sipario/sync/sync_service.dart';
import 'package:sipario/theme/components/states.dart';

import 'support/kabuk_yardimcilari.dart';

/// Durum akışını testin sürdüğü sahte servis (kabuk yalnız bu akışı dinler).
class _AkisliSync extends SyncService {
  _AkisliSync(super.db);

  final _kanal = StreamController<SyncOutcome>.broadcast();

  @override
  Stream<SyncOutcome> get status => _kanal.stream;

  @override
  Future<SyncOutcome> syncNow() async => const SyncOutcome(ok: true);

  /// Durumu yayınlar VE kabuğun onu çizmesini bekler.
  ///
  /// ⚠️ `add` + tek `pump()` YETMEZ (ölçüldü: bant 0, ikinci turda 1). Broadcast akışının olayı
  /// dinleyiciye ulaştırması GERÇEK bir olay döngüsü turu ister; widget testinin sahte saati
  /// mikro görev kuyruğunu tek başına döndürmüyor. `ekranaKoy`un `runAsync` kullanmasının sebebi
  /// de tam olarak budur — aynı desen burada da geçerli.
  Future<void> yayinla(WidgetTester tester, SyncOutcome o) async {
    _kanal.add(o);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }

  @override
  void dispose() {
    _kanal.close();
    super.dispose();
  }
}

Future<_AkisliSync> _kabuguKur(WidgetTester tester) async {
  final db = AppDatabase(NativeDatabase.memory());
  final sync = _AkisliSync(db);
  addTearDown(sync.dispose);
  await ekranaKoy(
    tester,
    HomeShell(db: db, session: Session(db), sync: sync, onLoggedOut: () {}),
  );
  return sync;
}

void main() {
  group('Bekleyen kayıt bandı — sunucunun BİLEREK ertelediği kayıtlar', () {
    testWidgets('beklemede > 0 iken bant çizilir (tur BAŞARILI olsa bile)', (tester) async {
      final sync = await _kabuguKur(tester);

      await sync.yayinla(tester, const SyncOutcome(ok: true, pushed: 0, beklemede: 3));

      expect(find.textContaining('sırada bekliyor'), findsOneWidget,
          reason: 'BORCUN TA KENDİSİ: tur `ok:true` döndüğü için eskiden hiçbir şey çizilmiyor, '
              'çip "güncel" diyordu. Erteleme başarısızlık değildir ama SESSİZ de olamaz');

      await kapat(tester);
    });

    testWidgets('beklemede == 0 iken bant ÇİZİLMEZ', (tester) async {
      final sync = await _kabuguKur(tester);

      await sync.yayinla(tester, const SyncOutcome(ok: true, pushed: 5));

      expect(find.textContaining('sırada bekliyor'), findsNothing,
          reason: 'temiz turda bant kalmamalı — kalıcı bir uyarı gürültüye dönüşür');

      await kapat(tester);
    });

    testWidgets('canlı tur HATASI bekleyen bandını EZER (öncelik)', (tester) async {
      final sync = await _kabuguKur(tester);

      await sync.yayinla(
        tester,
        const SyncOutcome(
          ok: false,
          beklemede: 3,
          tur: SyncHataTuru.oturum,
          error: 'Oturum yok',
        ),
      );

      expect(find.textContaining('sırada bekliyor'), findsNothing);
      expect(find.textContaining('yeniden girin'), findsOneWidget,
          reason: 'oturum ölmüşken kullanıcıya söylenecek şey "bekle" değil "giriş yap"tır; '
              'iki bandı üst üste çizmek yerleşimi de bozardı');

      await kapat(tester);
    });
  });

  group('Bant metni SÖZLEŞMEDİR', () {
    test('bekleyen metni "bağlanınca gönderilecek" sözü VERMEZ', () {
      const metin = SipCevrimdisiBant(tur: SipBantTuru.bekleyen);

      expect(metin.metin, contains('bekliyor'));
      expect(metin.metin, contains('güvende'),
          reason: 'kullanıcı önce veri kaybetmediğini bilmeli (kırmızı çizgi #3)');
      expect(metin.metin.toLowerCase(), isNot(contains('bağlanınca')),
          reason: 'AĞ ZATEN VAR — engel abonelik ya da sürüm. Verilemeyecek bir söz vermek, bu '
              'bandın 2026-07-27\'de düzeltilen kuruluş hatasının aynısı olurdu');
      expect(metin.metin.toLowerCase(), isNot(contains('destek')),
          reason: 'karantinadan AYRI: orada çare destek, burada abonelik/güncelleme. Aynı metni '
              'kullanmak kullanıcıyı gereksiz yere telefona sarılmaya yollardı');
    });

    test('bekleyen ile karantina AYNI metni paylaşmaz', () {
      const bekleyen = SipCevrimdisiBant(tur: SipBantTuru.bekleyen);
      const karantina = SipCevrimdisiBant(tur: SipBantTuru.karantina);

      expect(bekleyen.metin, isNot(karantina.metin),
          reason: 'reddedilmiş kayıt ile ertelenmiş kayıt aynı şey değildir: biri elle inceleme '
              'ister, öbürü kendiliğinden akar');
    });
  });
}
