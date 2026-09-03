// REHBER — widget testleri: görev kartı (A) · spot turu (B) · nasıl yapılır (C).
//
// Saf mantık `rehber_test.dart`ta. Buradaki her test AÇIK KALMIŞ SAHNEYİ DÜŞÜRÜR
// (`rehberSahnesiniSifirla`) — sahne bir `OverlayEntry`dir, ağaçla birlikte yıkılmaz ve
// modül kilidi açık kalırsa sonraki test sebepsiz boş ekran görür.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/rehber/gorev_karti.dart';
import 'package:sipario/rehber/nasil_yapilir_ekrani.dart';
import 'package:sipario/rehber/rehber_deposu.dart';
import 'package:sipario/rehber/rehber_hedef.dart';
import 'package:sipario/rehber/rehber_modeli.dart';
import 'package:sipario/rehber/rehber_sahne.dart';
import 'package:sipario/theme/app_theme.dart';

import 'support/ekran_yardimcilari.dart';

void main() {
  setUp(() async {
    // Her test TEMİZ bir depoyla başlar; disk yok, sıra bağımlılığı yok.
    rehberDeposu = RehberDeposu.bellek();
    // `yukle` ŞART: durum okunmadan hiçbir tur kendiliğinden oynamaz (`otomatikOynarMi`).
    // Bu satırın olmaması, turun sahada değil yalnız testte ölmesi demek olurdu.
    await rehberDeposu.yukle();
    rehberGecikmesi = Duration.zero;
    rehberKuryeKipi = false;
    RehberKayit.temizle();
  });

  tearDown(rehberSahnesiniSifirla);

  group('Katman A — görev kartı', () {
    testWidgets('boş dükkânda çizilir ve maddeleri işaretsizdir', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await ekranaKoy(tester, _KartOrtami(db: db));

      expect(find.text('İlk adımlar'), findsOneWidget);
      expect(find.text('0/5 tamam'), findsOneWidget);
      expect(find.text('Arayan tanımayı aç'), findsOneWidget);
      expect(find.text('İlk müşterini kaydet'), findsOneWidget);
      // İsteğe bağlı satır GİZLENMEZ, etiketiyle söylenir (BRIEF: tek kişilik bayi çoktur).
      expect(find.textContaining('isteğe bağlı'), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('veri girildikçe sayaç kendiliğinden ilerler', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() => db.into(db.products).insert(
            ProductsCompanion.insert(
              id: 'p1',
              name: 'Tüp',
              unitPriceKurus: 10000,
              updatedOccurredAt: '2026-09-01T00:00:00Z',
            ),
          ));
      await ekranaKoy(tester, _KartOrtami(db: db));

      expect(find.text('1/5 tamam'), findsOneWidget);
      await kapat(tester);
    });

    testWidgets('kapat düğmesi kartı kaldırır ve depoya yazar', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await ekranaKoy(tester, _KartOrtami(db: db));
      expect(find.text('İlk adımlar'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('İlk adımlar listesini kapat'));
      await akislariBekle(tester);

      expect(find.text('İlk adımlar'), findsNothing);
      expect(rehberDeposu.gorevKartiAcik, isFalse);
      await kapat(tester);
    });

    testWidgets('zorunlu maddeler bitince kart HİÇ çizilmez', (tester) async {
      // Güncellemeyle gelen mevcut bayi bu kartı görmemeli: çalışan bir dükkâna
      // "ilk müşterini kaydet" demek ürünü küçültür.
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await (db.update(db.syncMeta)..where((t) => t.id.equals(1))).write(
          const SyncMetaCompanion(setupCompletedAt: Value('2026-09-01T00:00:00Z')),
        );
        await db.into(db.products).insert(ProductsCompanion.insert(
              id: 'p1', name: 'Tüp', unitPriceKurus: 100,
              updatedOccurredAt: '2026-09-01T00:00:00Z',
            ));
        await db.into(db.customers).insert(CustomersCompanion.insert(
              id: 'c1', name: 'Ali', updatedOccurredAt: '2026-09-01T00:00:00Z',
            ));
        await db.into(db.orders).insert(OrdersCompanion.insert(
              id: 'o1', occurredAt: '2026-09-01T00:00:00Z',
            ));
      });
      await ekranaKoy(tester, _KartOrtami(db: db));

      expect(find.text('İlk adımlar'), findsNothing);
      await kapat(tester);
    });

    testWidgets('maddeye dokununca niyet KABUĞA devredilir', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      RehberGorev? secilen;
      await ekranaKoy(tester, _KartOrtami(db: db, onGorev: (g) => secilen = g));

      await tester.tap(find.text('Ürünlerini ekle'));
      await akislariBekle(tester);

      expect(secilen, RehberGorev.urun);
      await kapat(tester);
    });

    testWidgets('kuryeye kendi maddeleri gösterilir', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await ekranaKoy(tester, _KartOrtami(db: db, kuryeMi: true, kullaniciId: 'ben'));

      expect(find.text('0/3 tamam'), findsOneWidget);
      expect(find.text('Kasanı devret'), findsOneWidget);
      expect(find.text('Ürünlerini ekle'), findsNothing);
      await kapat(tester);
    });
  });

  // Turlar ÜRÜN İÇERİĞİDİR (`rehber_turlari.dart`) ve testte taklit edilmez: sahte bir tur,
  // gerçek metnin sözleşmesini değil test kurgusunu doğrulardı. Ana ekranın turu kullanılır ve
  // hedefleri seçerek monte edilir — filtrenin gerçek adımlar üzerinde işlediği görülür.
  group('Katman B — spot turu', () {
    testWidgets('ekran açılınca tur kendiliğinden oynar', (tester) async {
      await _turuKoy(tester);

      expect(find.text('Adım 1/3'), findsOneWidget);
      expect(find.text('Sipario kullanmaya başlıyorsun'), findsOneWidget);
      expect(find.text('Sonraki'), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('sonraki adıma geçer ve BİTTİ görüldü olarak yazar', (tester) async {
      await _turuKoy(tester);

      await tester.tap(find.text('Sonraki'));
      await tester.pump();
      expect(find.text('Adım 2/3'), findsOneWidget);
      expect(find.text('Günün özeti'), findsOneWidget);

      await tester.tap(find.text('Sonraki'));
      await tester.pump();
      expect(find.text('Adım 3/3'), findsOneWidget);
      expect(find.text('Dükkânı kim aradı'), findsOneWidget);
      // Son adımda düğme "Bitti" olur — kaç adım kaldığı düğmeden de okunur.
      expect(find.text('Bitti'), findsOneWidget);

      await tester.tap(find.text('Bitti'));
      await akislariBekle(tester);

      expect(find.text('Adım 3/3'), findsNothing);
      expect(rehberDeposu.gorulduMu(RehberYuzey.ana), isTrue);
      await kapat(tester);
    });

    testWidgets('"Rehberi kapat" BÜTÜN turları kapatır', (tester) async {
      await _turuKoy(tester);

      await tester.tap(find.text('Rehberi kapat'));
      await akislariBekle(tester);

      expect(rehberDeposu.tumuAtlandi, isTrue);
      for (final y in RehberYuzey.values) {
        expect(rehberDeposu.otomatikOynarMi(y), isFalse);
      }
      await kapat(tester);
    });

    testWidgets('HEDEFİ AĞAÇTA OLMAYAN ADIM ATLANIR', (tester) async {
      // Rol ve özellik görünürlüğü filtresi bu davranıştan BEDAVA gelir: kuryede çizilmeyen
      // kutuyu anlatan adım kendiliğinden düşer. Turda ayrıca rol koşulu yazmak gerekmez.
      //
      // Burada `ana.cta` monte EDİLMİYOR: altı adımlık ana turundan yalnız giriş + bento kalır.
      await _turuKoy(tester, ctaCiz: false);

      expect(find.text('Adım 1/2'), findsOneWidget);
      await tester.tap(find.text('Sonraki'));
      await tester.pump();

      expect(find.text('Günün özeti'), findsOneWidget);
      expect(find.text('Dükkânı kim aradı'), findsNothing);
      expect(find.text('Bitti'), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('hiç hedef yoksa bile GİRİŞ adımı oynar', (tester) async {
      // `?` düğmesi her koşulda bir şey göstermeli — turun ilk adımının bağsız olmasının sebebi.
      await _turuKoy(tester, bentoCiz: false, ctaCiz: false);

      expect(find.text('Adım 1/1'), findsOneWidget);
      expect(find.text('Bitti'), findsOneWidget);
      await kapat(tester);
    });

    testWidgets('görülmüş tur kendiliğinden AÇILMAZ, ? düğmesi yine açar', (tester) async {
      await rehberDeposu.goruldu(RehberYuzey.ana);
      await _turuKoy(tester);
      expect(find.text('Adım 1/3'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Yardım'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Adım 1/3'), findsOneWidget);
      await kapat(tester);
    });

    testWidgets('atlanmış rehberde de ? düğmesi çalışır', (tester) async {
      // Kapanan yalnız KENDİLİĞİNDEN açılmadır — atlanan şey kaybolmaz.
      await rehberDeposu.tumunuAtla();
      await _turuKoy(tester);
      expect(find.text('Adım 1/3'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Yardım'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Adım 1/3'), findsOneWidget);
      await kapat(tester);
    });

    testWidgets('aktif olmayan ekranda tur oynamaz', (tester) async {
      // Abonelik kilitliyken kullanamayacağı bir şeyi tarif etmek yanlış olurdu.
      await _turuKoy(tester, aktif: false);
      expect(find.text('Adım 1/3'), findsNothing);
      await kapat(tester);
    });
  });

  group('Katman C — nasıl yapılır', () {
    testWidgets('tarifler listelenir ve dokununca adımları açılır', (tester) async {
      await ekranaKoy(tester, const NasilYapilirEkrani(kuryeMi: false));

      expect(find.text('Yardım'), findsOneWidget);
      expect(find.text('Yeni sipariş girmek'), findsOneWidget);
      // Kapalıyken adımlar görünmez — liste uzun, hepsi açık olsa tarama imkânsızlaşır.
      expect(find.text('Sipariş Ekle satırını seç'), findsNothing);

      await tester.tap(find.text('Yeni sipariş girmek'));
      await tester.pump();
      expect(find.text('Sipariş Ekle satırını seç'), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('arama listeyi süzer', (tester) async {
      await ekranaKoy(tester, const NasilYapilirEkrani(kuryeMi: false));

      await tester.enterText(find.byType(TextField).first, 'veresiye');
      await tester.pump();

      expect(find.text('Veresiye yazmak'), findsOneWidget);
      expect(find.text('Koyu temayı açmak'), findsNothing);

      await kapat(tester);
    });

    testWidgets('eşleşme yoksa sebebini söyler', (tester) async {
      await ekranaKoy(tester, const NasilYapilirEkrani(kuryeMi: false));

      await tester.enterText(find.byType(TextField).first, 'zzzz');
      await tester.pump();

      expect(find.text('"zzzz" için bir tarif yok'), findsOneWidget);
      await kapat(tester);
    });

    testWidgets('kurye yapamayacağı işin tarifini görmez', (tester) async {
      await ekranaKoy(tester, const NasilYapilirEkrani(kuryeMi: true));

      expect(find.text('Kasayı devretmek'), findsOneWidget);
      expect(find.text('Kurye eklemek ve parola vermek'), findsNothing);

      await kapat(tester);
    });
  });
}

/// Görev kartını tek başına, tema ve akışlarıyla birlikte kuran fikstür.
class _KartOrtami extends StatelessWidget {
  const _KartOrtami({
    required this.db,
    this.kuryeMi = false,
    this.kullaniciId,
    this.onGorev,
  });

  final AppDatabase db;
  final bool kuryeMi;
  final String? kullaniciId;
  final ValueChanged<RehberGorev>? onGorev;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SingleChildScrollView(
          child: GorevKarti(
            db: db,
            kuryeMi: kuryeMi,
            kullaniciId: kullaniciId,
            onGorev: onGorev ?? (_) {},
          ),
        ),
      );
}

/// Ana ekranın GERÇEK turunu, seçilen hedefleri monte ederek kurar.
///
/// Ana turu altı adımdır; burada yalnız `ana.bento` ve `ana.cta` ağaca konur, kalan üç bağlı
/// adım (görev kartı, menü, alt gezinme) hedefsiz kaldığı için elenir. Kalan üç adım:
/// giriş (bağsız) → "Günün özeti" → "Dükkânı kim aradı".
Future<void> _turuKoy(
  WidgetTester tester, {
  bool bentoCiz = true,
  bool ctaCiz = true,
  bool aktif = true,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: SipTheme.acik(),
    home: _TurOrtami(bentoCiz: bentoCiz, ctaCiz: ctaCiz, aktif: aktif),
  ));
  // postFrame + `rehberGecikmesi` (sıfır) + sahnenin ilk karesi.
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

class _TurOrtami extends StatelessWidget {
  const _TurOrtami({
    required this.bentoCiz,
    required this.ctaCiz,
    required this.aktif,
  });

  final bool bentoCiz;
  final bool ctaCiz;
  final bool aktif;

  @override
  Widget build(BuildContext context) => RehberSahne(
        yuzey: RehberYuzey.ana,
        kuryeMi: false,
        aktif: aktif,
        child: Scaffold(
          appBar: AppBar(
            actions: const [RehberYardimDugmesi(yuzey: RehberYuzey.ana)],
          ),
          body: Column(
            children: [
              if (bentoCiz)
                const RehberHedef(
                  id: 'ana.bento',
                  child: SizedBox(width: 200, height: 90),
                ),
              const SizedBox(height: 40),
              if (ctaCiz)
                const RehberHedef(
                  id: 'ana.cta',
                  child: SizedBox(width: 200, height: 50),
                ),
            ],
          ),
        ),
      );
}
