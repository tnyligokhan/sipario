// SÜRÜM NOTLARI — veri disiplini + ekran.
//
// Bu dosyanın ASIL işi ekranı denemek değil, LİSTENİN KENDİSİNİ denetlemektir. Sürüm notu
// elle yazılan bir metindir ve elle yazılan her şey gibi bayatlar: en sık görülen üç bozulma
// (yayınlanan sürümün listede olmaması · teknik dilin sızması · mağaza yasağının ihlali)
// hiçbir derleme hatası vermez ve yalnız bayi okurken fark edilir — yani hiç fark edilmez.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/guncelleme/surum_notlari.dart';
import 'package:sipario/screens/isletme/surum_notlari_ekrani.dart';
import 'package:sipario/theme/app_theme.dart';

Future<void> _ekranaKoy(WidgetTester tester, {String? surum}) async {
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: SipTheme.acik(),
    home: SurumNotlariEkrani(surumOkuyucu: () async => surum),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('surumNotuBul (saf kural)', () {
    test('tam eşleşmeyi bulur', () {
      expect(surumNotuBul('0.13.0')?.surum, '0.13.0');
    });

    test('yapı numarası eklenmiş sürümü de bulur', () {
      // `package_info_plus` bazı yollarda "0.13.0 (412)" biçiminde döner.
      expect(surumNotuBul('0.13.0 (412)')?.surum, '0.13.0');
      expect(surumNotuBul('  0.13.0  ')?.surum, '0.13.0');
    });

    test('bilinmeyen ya da okunamayan sürümde null — hiçbir kayıt işaretlenmez', () {
      // Yanlış sürümü "kullandığınız" diye işaretlemektense hiçbirini işaretlememek doğrudur.
      expect(surumNotuBul('9.9.9'), isNull);
      expect(surumNotuBul(null), isNull);
      expect(surumNotuBul(''), isNull);
    });
  });

  group('Liste disiplini (bayatlama bekçisi)', () {
    test('liste boş değil ve her kaydın maddesi var', () {
      expect(kSurumNotlari, isNotEmpty);
      for (final n in kSurumNotlari) {
        expect(n.maddeler, isNotEmpty, reason: '${n.surum}: maddesiz sürüm notu yazılmaz');
        expect(n.tarih.trim(), isNotEmpty, reason: '${n.surum}: tarih boş olamaz');
      }
    });

    test('sürüm adları BENZERSİZ', () {
      final adlar = kSurumNotlari.map((n) => n.surum).toList();
      expect(adlar.toSet().length, adlar.length, reason: 'aynı sürüm iki kez yazılmış');
    });

    test('sürüm adı SemVer biçiminde ("v" ya da boşluk YOK)', () {
      // Eşleşme metin karşılaştırmasıyla yapılıyor; "v0.14.0" yazmak "kullandığınız sürüm"
      // rozetini sessizce kaybettirirdi.
      for (final n in kSurumNotlari) {
        expect(n.surum, matches(RegExp(r'^\d+\.\d+\.\d+$')), reason: 'bozuk sürüm: ${n.surum}');
      }
    });

    test('EN ÜSTTEKİ kayıt pubspec.yaml sürümüyle AYNI', () async {
      // ASIL BEKÇİ BU. Sürümü artırıp not yazmayı unutmak, bu ekranı sessizce yalancı yapar:
      // bayi güncelleme alır, "Yenilikler"i açar ve orada kendi sürümünü BULAMAZ.
      final pubspec = await _pubspecSurumu();
      expect(kSurumNotlari.first.surum, pubspec,
          reason: 'pubspec.yaml $pubspec sürümünde ama sürüm notu yazılmamış '
              '(lib/guncelleme/surum_notlari.dart)');
    });

    test('TEKNİK DİL SIZMAMIŞ — okuru bayidir, geliştirici değil', () {
      // Liste bir değişiklik günlüğü değildir. Bu sözcükler ekranda görünürse madde
      // yeniden yazılmalıdır (yasak olan şey KAVRAM değil, kavramın ham adıdır).
      const yasak = [
        'migration', 'şema', 'endpoint', 'uç nokta', 'refactor', 'commit', 'API',
        'LWW', 'outbox', 'null', 'JSON', 'SQL', 'kolon', 'sınıf', 'fonksiyon',
      ];
      for (final n in kSurumNotlari) {
        for (final m in n.maddeler) {
          for (final k in yasak) {
            expect(m.toLowerCase(), isNot(contains(k.toLowerCase())),
                reason: '${n.surum} · "$k" bayi diline ait değil: $m');
          }
        }
      }
    });

    test('MAĞAZA KURALI — fiyat/abonelik/satın alma dili YOK', () {
      const yasak = ['abone', 'satın', 'fiyat', 'ücret', 'ödeme', 'üyelik', '₺'];
      // "TL" KELİME SINIRIYLA aranır, alt dize olarak DEĞİL: düz `contains('tl')` masum
      // Türkçe sözcüklerin içine düşüyor ("işare-tl-erseniz") ve testi yanlış alarm
      // üreten bir şeye çevirir. Bu depoda yazılı ders: yanlış alarm zararsız değildir,
      // gerçek alarmı görünmez yapar (DECISIONS 2026-08-10, "YAYIN BORCU 384").
      final tl = RegExp(r'\bTL\b');
      for (final n in kSurumNotlari) {
        for (final m in n.maddeler) {
          for (final k in yasak) {
            expect(m.toLowerCase(), isNot(contains(k.toLowerCase())),
                reason: '${n.surum} · "$k" mağaza kuralını ihlal eder: $m');
          }
          expect(tl.hasMatch(m), isFalse, reason: '${n.surum} · para birimi yazılamaz: $m');
        }
      }
    });
  });

  group('SurumNotlariEkrani', () {
    testWidgets('bütün sürümleri ve maddeleri çizer', (tester) async {
      await _ekranaKoy(tester);

      expect(find.text('Yenilikler'), findsOneWidget);
      for (final n in kSurumNotlari) {
        expect(find.text('Sürüm ${n.surum}'), findsOneWidget);
      }
      expect(find.text(kSurumNotlari.first.maddeler.first), findsOneWidget);
    });

    testWidgets('koşan sürüm "Kullandığınız sürüm" rozetiyle işaretlenir — TEK BİR kayıtta',
        (tester) async {
      await _ekranaKoy(tester, surum: '0.13.0');
      expect(find.text('Kullandığınız sürüm'), findsOneWidget);
    });

    testWidgets('sürüm OKUNAMAZSA liste yine çizilir, yalnız rozet yoktur', (tester) async {
      // Platform kanalı yoksa (test ortamı, eksik kayıt) ekran çökmez ve boşalmaz:
      // notlar bir sürüm etiketi yüzünden okunamaz hâle gelemez.
      await _ekranaKoy(tester);
      expect(find.text('Kullandığınız sürüm'), findsNothing);
      expect(find.text('Sürüm ${kSurumNotlari.first.surum}'), findsOneWidget);
    });

    testWidgets('AĞA ÇIKMAZ — çevrimdışı bayide de eksiksiz açılır', (tester) async {
      // Ekranın hiçbir ağ bağımlılığı olmadığının kanıtı: `HttpClient` testte her isteği
      // 400 ile reddeder, yani gizli bir istek olsaydı liste eksik ya da boş çizilirdi.
      await _ekranaKoy(tester, surum: '0.13.0');
      for (final n in kSurumNotlari) {
        expect(find.text('Sürüm ${n.surum}'), findsOneWidget);
      }
    });
  });
}

/// `pubspec.yaml` → `version:` satırındaki SemVer adı (yapı numarası atılır).
Future<String> _pubspecSurumu() async {
  final metin = await File('pubspec.yaml').readAsString();
  final eslesme = RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)', multiLine: true)
      .firstMatch(metin);
  expect(eslesme, isNotNull, reason: 'pubspec.yaml içinde version: satırı bulunamadı');
  return eslesme!.group(1)!;
}
