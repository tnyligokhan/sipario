// Çağrı kartı + çağrı günlüğü UI testleri.
// Tasarım kaynağı: tasarım s-cagri.jsx (kart varyantları), s-veri.jsx (ARAMALAR),
// s-uygulama.jsx (muaf numara kuralı).
//
// KAPSAM NOTU: gerçek cihazda çağrı anında çizilen kart saf Kotlin'dir
// (android/.../CallerCard.kt) ve buradan test EDİLEMEZ. Bu dosya Flutter karşılığını
// (uygulama önplandayken ve Ayarlar'daki simülasyonda kullanılan kart) doğrular.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/screens/cagri/cagri_gunlugu.dart';
import 'package:sipario/screens/cagri/cagri_model.dart';
import 'package:sipario/theme/app_theme.dart';
import 'package:sipario/theme/tokens.dart';

Widget _kabuk(Widget govde, {bool koyu = false}) => MaterialApp(
      theme: koyu ? SipTheme.koyu() : SipTheme.acik(),
      home: Scaffold(body: govde),
    );

/// Kartın canlı noktası sonsuz nabız atar, yani ağaç HİÇ oturmaz — `pumpAndSettle`
/// zaman aşımına düşer. Geçişleri elle ilerletiyoruz.


/// ÇAĞRI GÜNLÜĞÜ + saf kurallar (`aramaTipiCoz`, `cagriSaatMetni`).
///
/// Bölme gerekçesi: `ui_cagri_test.dart` başlığı.
void main() {
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
      expect(find.text('0532 415 22 90, Sipariş alındı'), findsOneWidget);

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

  // Native karttaki `CallerCard.siparisZamanMetni` ile AYNI kurallar — iki kart aynı
  // siparişte aynı metni yazmak zorunda (Kotlin tarafında birim test altyapısı yok,
  // sözleşmeyi burası kilitler).
  group('cagriSiparisZamanMetni — açık siparişte YAŞ, kapanmışta saat', () {
    final simdi = DateTime(2026, 7, 26, 14, 30);
    String yas(DateTime an) => cagriSiparisZamanMetni(an, acik: true, simdi: simdi);

    test('1 dakikadan yeni sipariş "az önce"dir', () {
      expect(yas(DateTime(2026, 7, 26, 14, 30)), 'az önce');
      expect(yas(DateTime(2026, 7, 26, 14, 29, 1)), 'az önce');
    });

    test('60 dakikaya kadar dakika yazılır', () {
      expect(yas(DateTime(2026, 7, 26, 14, 29)), '1 dk önce');
      expect(yas(DateTime(2026, 7, 26, 14, 7)), '23 dk önce');
      expect(yas(DateTime(2026, 7, 26, 13, 31)), '59 dk önce');
    });

    test('60 dakikadan sonra saat + dakika (gecikme dakikası ÖNEMLİDİR)', () {
      expect(yas(DateTime(2026, 7, 26, 13, 30)), '1 sa önce');
      expect(yas(DateTime(2026, 7, 26, 13, 25)), '1 sa 5 dk önce');
      expect(yas(DateTime(2026, 7, 26, 12, 35)), '1 sa 55 dk önce');
      expect(yas(DateTime(2026, 7, 25, 15, 0)), '23 sa 30 dk önce');
    });

    test('24 saati geçen açık siparişte gün gösterimine düşülür', () {
      // Tam 24 saat: artık "Dün".
      expect(yas(DateTime(2026, 7, 25, 14, 30)), 'Dün');
      expect(yas(DateTime(2026, 7, 23, 8, 0)), 'Per');
      expect(yas(DateTime(2026, 7, 2, 8, 0)), '02.07');
    });

    test('İLERİ tarihli damga "az önce" sayılır, "−3 dk önce" yazılmaz', () {
      expect(yas(DateTime(2026, 7, 26, 14, 33)), 'az önce');
      expect(yas(DateTime(2026, 7, 28, 9, 0)), 'az önce');
    });

    test('KAPANMIŞ siparişte cagriSaatMetni davranışı aynen sürer', () {
      String kapali(DateTime an) =>
          cagriSiparisZamanMetni(an, acik: false, simdi: simdi);

      expect(kapali(DateTime(2026, 7, 26, 10, 24)), '10:24');
      expect(kapali(DateTime(2026, 7, 26, 14, 7)), '14:07',
          reason: 'teslim edilmiş siparişte 23 dakika önce olması bir şey değiştirmez');
      expect(kapali(DateTime(2026, 7, 25, 22, 0)), 'Dün');
      expect(kapali(DateTime(2026, 7, 2, 8, 0)), '02.07');
    });

    test('okunamayan zaman iki durumda da boş metin verir', () {
      expect(cagriSiparisZamanMetni(null, acik: true, simdi: simdi), '');
      expect(cagriSiparisZamanMetni(null, acik: false, simdi: simdi), '');
    });

    test('siparisAcikMi: yalnız teslim/iptal kapalıdır', () {
      expect(siparisAcikMi('open'), isTrue);
      expect(siparisAcikMi('delivered'), isFalse);
      expect(siparisAcikMi('cancelled'), isFalse);
      // Tanınmayan durum açık sayılır: kart bir siparişi yok saymaktansa yaşını yazar.
      expect(siparisAcikMi('zort'), isTrue);
    });
  });

}
