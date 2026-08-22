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
      // EN ÜSTTEKİ MADDE DÖNGÜDEN ÖNCE sınanır: aşağıdaki tarama listeyi en alta kaydırıyor ve
      // ilk kaydın maddesi o noktada görünür alanın dışında kalıyor (liste tembel).
      expect(find.text(kSurumNotlari.first.maddeler.first), findsOneWidget);

      // ══ TEK GEÇİŞLİ TARAMA (2026-08-22'de yöntem DEĞİŞTİ) ═══════════════════════════════
      //
      // Önceki hâl her sürüm için ayrı ayrı `scrollUntilVisible` çağırıyordu ve 2026-08-22'de
      // liste 38'den 43 kayda çıkınca ORTADA (0.25.1) `Bad state: No element` ile düştü.
      //
      // SEBEP EKRANDA DEĞİL, YÖNTEMDEYDİ ve ölçüldü: liste tembeldir, dolayısıyla
      // `maxScrollExtent` bir TAHMİNDİR ve o tahmin yalnız ÇİZİLMİŞ kayıtların ortalamasından
      // üretilir. `scrollUntilVisible` her bulduğu hedefte `Scrollable.ensureVisible` ile
      // konumu yeniden ayarlıyor; kart yükseklikleri eşit olmadığı için tahmin her turda
      // oynuyor (ölçüldü: 8779 → 8058) ve bir noktada gerçek içerikten KÜÇÜK kalıyor —
      // liste o noktadan ileri kaydırılamaz hâle geliyor. Ekranın kendisi sağlamdı: düz bir
      // sürükleme döngüsü aynı listede 43/43 kaydı sorunsuz gösterdi.
      //
      // Yeni yöntem tam olarak bunu yapar: yukarıdan aşağıya SÜRÜKLER ve gördüklerini
      // biriktirir. Hedefe geri dönme (ensureVisible) yok, dolayısıyla tahmin churn'ü de yok.
      // Liste uzadıkça kırılmaz — 2026-08-13'te bir kez, 2026-08-22'de ikinci kez ödenen
      // bedelin kalıcı karşılığı budur.
      final gorulen = await _tumSurumleriTara(tester);

      expect(
        gorulen,
        hasLength(kSurumNotlari.length),
        reason: 'çizilmeyen sürüm(ler): '
            '${kSurumNotlari.map((n) => n.surum).where((s) => !gorulen.contains(s)).toList()}',
      );
    });

    testWidgets('koşan sürüm "Kullandığınız sürüm" rozetiyle işaretlenir — TEK BİR kayıtta',
        (tester) async {
      await _ekranaKoy(tester, surum: '0.13.0');
      // ROZETE KAYDIRARAK ULAŞILIR: liste her yayında uzuyor ve işaretli kayıt zamanla test
      // ekranının dışına düşüyor (tembel liste onu HİÇ çizmiyor). Sabit viewport'a güvenen
      // iddia, rozet gayet doğru çalışırken "yok" diye kırılır — 2026-08-13'te tam bu oldu.
      await tester.scrollUntilVisible(find.text('Sürüm 0.13.0'), 400,
          scrollable: find.byType(Scrollable).first);
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
      // Aynı sebeple TEK GEÇİŞLE taranır (gerekçe yukarıdaki testte): liste test ekranından
      // uzun ve tembel; `scrollUntilVisible` döngüsü ise tahmin edilen kaydırma sınırını
      // oynatıp listeyi ortada kilitliyor.
      expect(await _tumSurumleriTara(tester), hasLength(kSurumNotlari.length));
    });
  });
}

/// Listeyi yukarıdan aşağıya SÜRÜKLEYEREK tarar ve çizilen sürüm adlarını biriktirir.
///
/// Gerekçe "bütün sürümleri ve maddeleri çizer" testinin içinde yazılı; özeti: tembel listede
/// `maxScrollExtent` bir tahmindir ve `scrollUntilVisible`ın her hedefte yaptığı geri
/// konumlandırma o tahmini oynatıp listeyi ortada kilitliyor.
Future<Set<String>> _tumSurumleriTara(WidgetTester tester) async {
  final kaydirici = find.byType(Scrollable).first;
  final konum = tester.state<ScrollableState>(kaydirici).position;
  final gorulen = <String>{};

  // Üst sınır bir emniyet kemeri: sürükleme hiç ilerlemezse test asılmasın, DÜŞSÜN.
  for (var tur = 0; tur < 300; tur++) {
    for (final n in kSurumNotlari) {
      if (find.text('Sürüm ${n.surum}').evaluate().isNotEmpty) gorulen.add(n.surum);
    }
    if (konum.pixels >= konum.maxScrollExtent) break;
    await tester.drag(kaydirici, const Offset(0, -300));
    await tester.pump();
  }
  return gorulen;
}

/// `pubspec.yaml` → `version:` satırındaki SemVer adı (yapı numarası atılır).
Future<String> _pubspecSurumu() async {
  final metin = await File('pubspec.yaml').readAsString();
  final eslesme = RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)', multiLine: true)
      .firstMatch(metin);
  expect(eslesme, isNotNull, reason: 'pubspec.yaml içinde version: satırı bulunamadı');
  return eslesme!.group(1)!;
}
