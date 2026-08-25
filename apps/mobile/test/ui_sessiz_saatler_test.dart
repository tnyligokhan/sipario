// SESSİZ SAATLER — artık düzenlenebilir (2026-08-13).
//
// KAPATILAN BOŞLUK: `BildirimAyarlari.sessizYaz()` yazılmış, diske kalıcılanıyor ve bildirim
// servisi tarafından UYGULANIYORDU — ama onu çağıran TEK BİR EKRAN YOKTU. Ekranda yalnız
// "22:00 – 08:00" yazan salt bilgi satırı duruyordu. Yani ürün özelliği taşıyordu, kullanıcı
// ona hiç erişemiyordu: kod hazır, kapı yok.
//
// BU DOSYANIN KİLİTLEDİĞİ ŞEY, ekranın bir şey ÇİZMESİ değil DEPOYA YAZMASIDIR. Görünümü
// sınayıp yazmayı sınamayan bir test, tam da kapatmaya çalıştığımız hatayı (çalışır görünen
// ama hiçbir şeyi kalıcılaştırmayan kontrol) yeniden mümkün kılardı.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/bildirim/bildirim_ayar_bolumu.dart';
import 'package:sipario/bildirim/bildirim_ayarlari.dart';
import 'package:sipario/bildirim/bildirim_sozlesmesi.dart';

import 'support/ekran_yardimcilari.dart';

/// İzin/kanal sormayan sahte servis — gerçek servis platform eklentisine uzanıyor ve widget
/// testinde çöküyor (dosya başlığındaki 2026-07-27 dersi).
class _SahteServis implements BildirimServisi {
  @override
  Future<bool> izinDurumu() async => true;

  @override
  Future<bool> izinIste() async => true;

  @override
  Future<void> iptal(String kimlik) async {}

  @override
  Future<void> goster(BildirimTaslagi t) async {}

  @override
  Future<void> zamanla(BildirimTaslagi t, DateTime neZaman) async {}

  @override
  Future<bool> kategoriAcikMi(BildirimKategori k) async => true;
}

void main() {
  late BildirimAyarlari ayarlar;

  /// Belirli bir ŞERİTTEKİ saat hapını bulur.
  ///
  /// İki şerit de aynı 24 metni taşıyor; sıraya (`.first`/`.last`) güvenen bir seçici sessizce
  /// yanlış şeridi hedefleyebiliyor — ilk koşumda tam bu oldu (başlangıç 6 beklenirken 11
  /// çıktı). Kimlik ürüne yazıldı, test artık tahmin etmiyor.
  Finder saat(String seritAnahtari, String deger) => find.descendant(
        of: find.byKey(Key(seritAnahtari)),
        matching: find.text(deger),
      );

  setUp(() async {
    ayarlar = BildirimAyarlari.bellek();
    await ayarlar.yukle();
  });

  Future<void> bolumuKur(WidgetTester tester) => ekranaKoy(
        tester,
        BildirimAyarBolumu(servis: _SahteServis(), ayarlar: ayarlar),
      );

  testWidgets('satır varsayılan aralığı gösterir ve DOKUNULABİLİR', (tester) async {
    // Dokunulabilirlik iddiası önemsiz görünür ama kapatılan hata tam olarak buydu: satır
    // vardı, aralığı doğru yazıyordu, yalnız hiçbir şey açmıyordu.
    await bolumuKur(tester);

    expect(find.text('Sessiz saatler'), findsOneWidget);

    await dokun(tester, find.text('Sessiz saatler'));
    await sheetAnimasyonu(tester);

    expect(find.text('BAŞLANGIÇ'), findsOneWidget);
    expect(find.text('BİTİŞ'), findsOneWidget);

    await kapat(tester);
  });

  testWidgets('seçilen aralık DEPOYA yazılır', (tester) async {
    await bolumuKur(tester);
    await dokun(tester, find.text('Sessiz saatler'));
    await sheetAnimasyonu(tester);

    // Şeritler 24 saatlik YATAY ve TEMBEL listelerdir: ekranın sağında kalan saatler hiç
    // çizilmez, yani `find.text('23')` boş döner. Bu, ürün hatası değil liste davranışıdır —
    // test görünür aralıktan saat seçer (ilk koşumda tam buraya takıldı).
    await dokun(tester, saat('sessiz-baslangic', '06'));
    await dokun(tester, saat('sessiz-bitis', '09'));
    await akislariBekle(tester);

    await dokun(tester, find.text('Kaydet'));
    await sheetAnimasyonu(tester);

    expect(ayarlar.sessizSaatler.baslangicSaat, 6);
    expect(ayarlar.sessizSaatler.bitisSaat, 9);

    await kapat(tester);
  });

  testWidgets('VAZGEÇİLİRSE depo değişmez', (tester) async {
    // Sheet'i kapatmak bir tercih değildir; yazan bir "iptal" yolu, kullanıcının hiç
    // istemediği bir aralığı kalıcılaştırırdı.
    final once = ayarlar.sessizSaatler;

    await bolumuKur(tester);
    await dokun(tester, find.text('Sessiz saatler'));
    await sheetAnimasyonu(tester);
    await dokun(tester, saat('sessiz-baslangic', '06'));
    await akislariBekle(tester);

    // Kaydet'e BASMADAN sheet'i kapat: perdeye (scrim) dokunmak sheet'i kapatır.
    // `pageBack()` burada işe yaramaz — sipSheet bir Material rotası değil, geri düğmesi yok.
    await tester.tapAt(const Offset(10, 10));
    await sheetAnimasyonu(tester);

    expect(ayarlar.sessizSaatler.baslangicSaat, once.baslangicSaat);
    expect(ayarlar.sessizSaatler.bitisSaat, once.bitisSaat);

    await kapat(tester);
  });

  testWidgets('AYNI SAAT seçilirse kapalı olduğu SÖYLENİR', (tester) async {
    // `baslangic == bitis` modelde "kapalı" demektir (`SessizSaatler.kapali`). Kullanıcı bunu
    // ancak ekran söylerse anlar; sessizce "22:00 – 22:00" yazmak hiçbir şey anlatmayan bir
    // aralık gösterirdi.
    await bolumuKur(tester);
    await dokun(tester, find.text('Sessiz saatler'));
    await sheetAnimasyonu(tester);

    await dokun(tester, saat('sessiz-baslangic', '09'));
    await dokun(tester, saat('sessiz-bitis', '09'));
    await akislariBekle(tester);

    expect(find.textContaining('sessiz saatler kapalı'), findsOneWidget);

    await kapat(tester);
  });
}
