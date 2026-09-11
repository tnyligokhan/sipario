// REHBER — saf testler: depo · içerik sözleşmesi · görev ilerlemesi.
//
// Widget tarafı `ui_rehber_test.dart`ta. Ayrım bu depodaki yerleşik kural: sorgular ve saf
// mantık widget-test sahte zamanına sokulmaz (Dilim 1 dersi).

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/rehber/gorev_ilerlemesi.dart';
import 'package:sipario/rehber/rehber_deposu.dart';
import 'package:sipario/rehber/rehber_modeli.dart';
import 'package:sipario/rehber/rehber_nasil.dart';
import 'package:sipario/rehber/rehber_turlari.dart';

void main() {
  group('RehberDeposu', () {
    test('DURUM OKUNMADAN hiçbir tur kendiliğinden oynamaz', () {
      // Sessiz taraf seçimi: okunmadan oynatmak, dün kapatılan turu bugün geri açardı.
      final d = RehberDeposu.bellek();
      expect(d.hazir, isFalse);
      expect(d.otomatikOynarMi(RehberYuzey.ana), isFalse);
    });

    test('boş depoda hiçbir tur görülmemiştir ve görev kartı açıktır', () async {
      final d = RehberDeposu.bellek();
      await d.yukle();
      expect(d.gorulduMu(RehberYuzey.ana), isFalse);
      expect(d.tumuAtlandi, isFalse);
      expect(d.gorevKartiAcik, isTrue);
      expect(d.otomatikOynarMi(RehberYuzey.ana), isTrue);
    });

    test('görülen tur bir daha kendiliğinden oynamaz, DİĞERLERİ oynar', () async {
      final d = RehberDeposu.bellek();
      await d.yukle();
      await d.goruldu(RehberYuzey.ana);
      expect(d.otomatikOynarMi(RehberYuzey.ana), isFalse);
      expect(d.otomatikOynarMi(RehberYuzey.siparisler), isTrue);
    });

    test('TEK "atla" BÜTÜN turları kapatır', () async {
      final d = RehberDeposu.bellek();
      await d.yukle();
      await d.tumunuAtla();
      for (final y in RehberYuzey.values) {
        expect(d.otomatikOynarMi(y), isFalse, reason: '${y.anahtar} hâlâ kendiliğinden oynar');
      }
    });

    test('sıfırlama ilk kurulum hâline döndürür', () async {
      final d = RehberDeposu.bellek();
      await d.yukle();
      await d.goruldu(RehberYuzey.ana);
      await d.tumunuAtla();
      await d.gorevKartiniKapat();

      await d.sifirla();

      expect(d.gorulduMu(RehberYuzey.ana), isFalse);
      expect(d.tumuAtlandi, isFalse);
      expect(d.gorevKartiAcik, isTrue);
    });

    test('yüzey anahtarları çözülür ve tanınmayan ad null döner', () {
      expect(RehberYuzey.anahtardan('ana'), RehberYuzey.ana);
      expect(RehberYuzey.anahtardan('gun_sonu'), RehberYuzey.gunSonu);
      expect(RehberYuzey.anahtardan('artik-yok'), isNull);
    });
  });

  group('Tur içeriği — SÖZLEŞME', () {
    test('her yüzeyin turu vardır ve boş değildir', () {
      for (final y in RehberYuzey.values) {
        expect(rehberTuru(y), isNotEmpty, reason: '${y.anahtar} turu boş');
      }
    });

    test('her turun İLK adımı bağsızdır', () {
      // GEREKÇE: `?` düğmesi her koşulda bir şey göstermeli. Hedefler henüz monte olmamışsa
      // bağlı adımların hepsi elenir; bağsız bir giriş adımı turun boş kalmamasını garanti eder.
      for (final y in RehberYuzey.values) {
        expect(rehberTuru(y).first.bagsiz, isTrue,
            reason: '${y.anahtar} turu bağlı bir adımla başlıyor');
      }
    });

    test('hiçbir adım boş metinle gelmez', () {
      for (final y in RehberYuzey.values) {
        for (final a in rehberTuru(y)) {
          expect(a.baslik.trim(), isNotEmpty, reason: '${y.anahtar} · başlıksız adım');
          expect(a.metin.trim(), isNotEmpty, reason: '${y.anahtar} · ${a.baslik} metinsiz');
        }
      }
    });

    test('KAYNAK TARAMASI — her hedef gerçekten bir ekranda sarılmıştır', () async {
      // BU TEST BİR BEKÇİDİR: turda yazılan `hedef` adı hiçbir `RehberHedef(id: ...)` ile
      // eşleşmiyorsa o adım sahada SESSİZCE atlanır — hiçbir hata görünmez, yalnız rehber
      // eksik anlatır. Tek dosya adı yerine BÜTÜN `lib/` taranır (bu depoda yapısal kilitler
      // tek dosyaya bağlandığı için bölünmede susmuştu).
      final kayitli = <String>{};
      final aileler = <String>{};
      // İki sarmalama biçimi de taranır: doğrudan `RehberHedef(id: '...')` ve liste
      // kurucularındaki `rehberSar('...' , ...)`.
      final duz = RegExp(r"(?:RehberHedef\(|rehberSar\()[\s\S]{0,240}?'([a-z]+\.[a-zA-Z]+)'");
      // Ad çalışma anında kuruluyorsa (alt gezinme sekmeleri: `id: 'nav.${sekme.name}'`)
      // tek tek adlar kaynakta YAZMAZ; o durumda AİLE ÖNEKİ kaydedilir.
      final aile = RegExp(r"id: '([a-z]+)\.\$");
      await for (final e in Directory('lib').list(recursive: true)) {
        if (e is! File || !e.path.endsWith('.dart')) continue;
        final kaynak = await e.readAsString();
        for (final m in duz.allMatches(kaynak)) {
          kayitli.add(m.group(1)!);
        }
        for (final m in aile.allMatches(kaynak)) {
          aileler.add('${m.group(1)!}.');
        }
      }
      expect(kayitli, isNotEmpty, reason: 'hiç RehberHedef bulunamadı — tarama deseni bozuk');

      for (final y in RehberYuzey.values) {
        for (final a in rehberTuru(y)) {
          if (a.bagsiz) continue;
          final tanindi = kayitli.contains(a.hedef) ||
              aileler.any((o) => a.hedef.startsWith(o));
          expect(tanindi, isTrue,
              reason: '${y.anahtar} · "${a.baslik}" adımı "${a.hedef}" hedefini işaret ediyor '
                  'ama hiçbir ekran o adı RehberHedef ile sarmıyor');
        }
      }
    });

    test('TURLAR YÜZEYSEL DEĞİL — her ekran en az beş şey anlatır', () {
      // BU TEST BİR REGRESYON BEKÇİSİDİR (kullanıcı eleştirisi 2026-09-04: "çok yüzeysel
      // kalmış"). İlk sürümde bazı turlar iki adımlıktı ve ekranı anlatmıyor, özet geçiyordu.
      // Alt sınır keyfi değil: bir ekranın ne olduğu, neyi gösterdiği, neye dokunulduğunda
      // ne olduğu ve nerede yanlış gidebileceği en az dört ayrı cümledir.
      for (final y in RehberYuzey.values) {
        expect(rehberTuru(y).length, greaterThanOrEqualTo(5),
            reason: '${y.anahtar} turu yalnız ${rehberTuru(y).length} adım');
      }
      // Ana ekran uygulamanın yüzüdür ve en çok anlatılması gereken yerdir.
      expect(rehberTuru(RehberYuzey.ana).length, greaterThanOrEqualTo(12));
    });

    test('TURLAR GERÇEK BİR ŞEYİ İŞARET EDER — bağsız adım azınlıktadır', () {
      // Aynı eleştirinin ikinci yarısı: "sayfalara girdiğimde bir şeyleri işaretleyerek
      // gösteriyor olmalıydı". Ekranın ortasında duran kart bağlamı taşır ama hiçbir yeri
      // GÖSTERMEZ; turun ağırlığı işaretlenmiş adımlarda olmalı.
      var bagli = 0;
      var toplam = 0;
      for (final y in RehberYuzey.values) {
        for (final a in rehberTuru(y)) {
          toplam++;
          if (!a.bagsiz) bagli++;
        }
      }
      expect(bagli, greaterThanOrEqualTo(toplam ~/ 2),
          reason: 'adımların yarısından azı bir şeyi işaret ediyor ($bagli/$toplam)');
    });

    test('EKRAN DEĞİŞTİREN "dene" adımı yalnız turun SONUNDA olabilir', () {
      // Tur katmanı rotaların ÜSTÜNDE yaşıyor: ortada bir yerde sekme değiştiren bir adım,
      // turu yeni ekranın üstünde eski ekranın adımlarını anlatır hâlde bırakır. Son adımda
      // ise dokunuş turu BİTİRİR ve sıradaki ekranın turu kendiliğinden başlar (zincir).
      for (final y in RehberYuzey.values) {
        final adimlar = rehberTuru(y);
        for (var i = 0; i < adimlar.length; i++) {
          if (!adimlar[i].hedef.startsWith('nav.')) continue;
          if (!adimlar[i].etkilesimli) continue;
          expect(i, adimlar.length - 1,
              reason: '${y.anahtar} · "${adimlar[i].baslik}" ekran değiştiriyor '
                  'ama turun son adımı değil');
        }
      }
    });

    test('ETKİLEŞİMLİ adımın hedefi ve çağrısı birlikte bulunur', () {
      for (final y in RehberYuzey.values) {
        for (final a in rehberTuru(y)) {
          if (a.dene.isEmpty) continue;
          expect(a.hedef, isNotEmpty,
              reason: '${y.anahtar} · "${a.baslik}" dene diyor ama hedefi yok — '
                  'kullanıcıya neye dokunacağını söylemeyen bir çağrı');
          expect(a.etkilesimli, isTrue);
        }
      }
    });

    test('dört ana sekmenin turu birbirine ZİNCİRLENİR', () {
      // Rehber ekran ekran kopuk parçalar değil tek bir gezinti olmalı: her turun son adımı
      // kullanıcıyı bir sonrakine götürür.
      const zincir = {
        RehberYuzey.ana: 'nav.musteri',
        RehberYuzey.musteriler: 'nav.siparis',
        RehberYuzey.siparisler: 'nav.gunSonu',
      };
      zincir.forEach((yuzey, hedef) {
        final son = rehberTuru(yuzey).last;
        expect(son.hedef, hedef, reason: '${yuzey.anahtar} turu zinciri kopmuş');
        expect(son.etkilesimli, isTrue);
      });
    });

    test('gün sonu turu iki role AYRI cümleler söyler', () {
      // Aynı ekran, iki anlam: patron günü kapatır, kurye kasa devreder. Kitle filtresinin
      // gerçekten gerektiği tek yer burasıdır ve ikisi de dolu kalmalı.
      final adimlar = rehberTuru(RehberYuzey.gunSonu);
      final yonetici = adimlar.where((a) => a.kitle.kapsar(kuryeMi: false)).toList();
      final kurye = adimlar.where((a) => a.kitle.kapsar(kuryeMi: true)).toList();
      expect(yonetici, isNotEmpty);
      expect(kurye, isNotEmpty);
      expect(yonetici.map((a) => a.baslik), contains('Günü kapatmak'));
      expect(kurye.map((a) => a.baslik), contains('Kasa devri'));
      expect(kurye.map((a) => a.baslik), isNot(contains('Günü kapatmak')));
    });
  });

  group('Nasıl yapılır', () {
    test('arama AKSANA BAKMAZ', () {
      // Bayi klavyede "urun" yazıp "ürün" maddesini bulabilmeli.
      final a = nasilYapilirListesi(kuryeMi: false, arama: 'urun');
      expect(a.map((n) => n.baslik).join(' '), contains('Ürün'));
    });

    test('eş anlamlı etiketten bulunur', () {
      // "borç" başlıkta geçmez; "Veresiye tahsil etmek" maddesinin etiketindedir.
      final a = nasilYapilirListesi(kuryeMi: false, arama: 'borç');
      expect(a.map((n) => n.baslik), contains('Veresiye tahsil etmek'));
    });

    test('boş arama hepsini döner', () {
      expect(nasilYapilirListesi(kuryeMi: false).length,
          kNasilYapilir.where((n) => n.kitle != RehberKitle.kurye).length);
    });

    test('kurye YAPAMAYACAĞI işin tarifini görmez', () {
      final kurye = nasilYapilirListesi(kuryeMi: true).map((n) => n.baslik).toList();
      expect(kurye, isNot(contains('Kurye eklemek ve parola vermek')));
      expect(kurye, isNot(contains('Günü kapatmak')));
      expect(kurye, contains('Kasayı devretmek'));
    });

    test('yönetici kuryeye özel tarifi görmez', () {
      final yonetici = nasilYapilirListesi(kuryeMi: false).map((n) => n.baslik).toList();
      expect(yonetici, isNot(contains('Kasayı devretmek')));
      expect(yonetici, contains('Günü kapatmak'));
    });

    test('her tarifin en az iki adımı vardır', () {
      // Tek adımlık "tarif" bir tarif değil, bir cümledir — orası turun işi.
      for (final n in kNasilYapilir) {
        expect(n.adimlar.length, greaterThanOrEqualTo(2), reason: n.baslik);
        for (final a in n.adimlar) {
          expect(a.trim(), isNotEmpty, reason: '${n.baslik} · boş adım');
        }
      }
    });

    test('başlıklar tekildir', () {
      final adlar = kNasilYapilir.map((n) => n.baslik).toList();
      expect(adlar.toSet().length, adlar.length, reason: 'yinelenen tarif başlığı var');
    });
  });

  group('Görev kümeleri', () {
    test('yöneticiye beş, kuryeye üç madde gösterilir', () {
      expect(RehberGorev.kitleIcin(kuryeMi: false), hasLength(5));
      expect(RehberGorev.kitleIcin(kuryeMi: true), hasLength(3));
    });

    test('kurye kurulum maddelerini görmez', () {
      final k = RehberGorev.kitleIcin(kuryeMi: true);
      expect(k, isNot(contains(RehberGorev.arayanTanima)));
      expect(k, isNot(contains(RehberGorev.urun)));
      expect(k, contains(RehberGorev.kasaDevri));
    });

    test('İSTEĞE BAĞLI madde kartın bitmesini engellemez', () {
      // BRIEF: "tek kişilik bayi çoktur". Kurye satırı hiç bitmezse kart sonsuza kadar
      // ekranda kalırdı — yol gösterici değil sitem olurdu.
      final d = GorevDurumu(
        kitle: RehberGorev.kitleIcin(kuryeMi: false),
        bitenler: const {
          RehberGorev.arayanTanima,
          RehberGorev.urun,
          RehberGorev.musteri,
          RehberGorev.siparis,
        },
      );
      expect(d.tamamlandi, isTrue);
      expect(d.sayac, 4);
      expect(d.toplam, 5);
    });

    test('zorunlu madde eksikse kart bitmemiştir', () {
      final d = GorevDurumu(
        kitle: RehberGorev.kitleIcin(kuryeMi: false),
        bitenler: const {RehberGorev.arayanTanima, RehberGorev.kurye},
      );
      expect(d.tamamlandi, isFalse);
    });

    test('boş kitle "tamamlandı" saymaz', () {
      expect(const GorevDurumu().tamamlandi, isFalse);
    });
  });

  group('watchGorevDurumu — veriden okunur, elle işaretlenmez', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('boş veritabanında yöneticinin hiçbir maddesi bitmemiştir', () async {
      final d = await watchGorevDurumu(db, kuryeMi: false).first;
      expect(d.bitenler, isEmpty);
      expect(d.tamamlandi, isFalse);
    });

    test('ürün eklenince ürün maddesi kendiliğinden dolar', () async {
      await db.into(db.products).insert(UrunOrnegi(db).companion('p1', 'Tüp'));
      final d = await watchGorevDurumu(db, kuryeMi: false).first;
      expect(d.bitenler, contains(RehberGorev.urun));
      expect(d.bitenler, isNot(contains(RehberGorev.musteri)));
    });

    test('silinmiş ürün maddeyi doldurmaz', () async {
      await db.into(db.products).insert(
            UrunOrnegi(db).companion('p1', 'Tüp', silindi: '2026-09-01T00:00:00Z'),
          );
      final d = await watchGorevDurumu(db, kuryeMi: false).first;
      expect(d.bitenler, isNot(contains(RehberGorev.urun)));
    });

    test('kurulum damgası arayan tanıma maddesini doldurur', () async {
      await (db.update(db.syncMeta)..where((t) => t.id.equals(1))).write(
        const SyncMetaCompanion(setupCompletedAt: Value('2026-09-01T00:00:00Z')),
      );
      final d = await watchGorevDurumu(db, kuryeMi: false).first;
      expect(d.bitenler, contains(RehberGorev.arayanTanima));
    });

    test('PASİF kurye maddeyi doldurmaz', () async {
      await db.into(db.users).insert(UsersCompanion.insert(
            id: 'u1', name: 'Ali', role: 'kurye', status: 'disabled',
          ));
      final d = await watchGorevDurumu(db, kuryeMi: false).first;
      expect(d.bitenler, isNot(contains(RehberGorev.kurye)));
    });

    test('kurye maddeleri KENDİ işine bakar', () async {
      await db.into(db.orders).insert(OrdersCompanion.insert(
            id: 'o1',
            occurredAt: '2026-09-01T10:00:00Z',
            status: const Value('delivered'),
            deliveredByUserId: const Value('baskasi'),
          ));
      var d = await watchGorevDurumu(db, kuryeMi: true, kullaniciId: 'ben').first;
      expect(d.bitenler, isEmpty, reason: 'başkasının teslimatı benim maddemi dolduramaz');

      await db.into(db.orders).insert(OrdersCompanion.insert(
            id: 'o2',
            occurredAt: '2026-09-01T11:00:00Z',
            status: const Value('delivered'),
            deliveredByUserId: const Value('ben'),
          ));
      d = await watchGorevDurumu(db, kuryeMi: true, kullaniciId: 'ben').first;
      expect(d.bitenler, contains(RehberGorev.teslimat));
    });

    test('kimlik yoksa kuryenin hiçbir maddesi bitmiş sayılmaz', () async {
      await db.into(db.cashHandovers).insert(CashHandoversCompanion.insert(
            id: 'h1',
            fromUserId: 'ben',
            countedCashKurus: 100,
            expectedCashKurus: 100,
            diffKurus: 0,
            occurredAt: '2026-09-01T20:00:00Z',
          ));
      final d = await watchGorevDurumu(db, kuryeMi: true).first;
      expect(d.bitenler, isEmpty);
    });

    test('kasa devri maddesi devir kaydıyla dolar', () async {
      await db.into(db.cashHandovers).insert(CashHandoversCompanion.insert(
            id: 'h1',
            fromUserId: 'ben',
            countedCashKurus: 100,
            expectedCashKurus: 100,
            diffKurus: 0,
            occurredAt: '2026-09-01T20:00:00Z',
          ));
      final d = await watchGorevDurumu(db, kuryeMi: true, kullaniciId: 'ben').first;
      expect(d.bitenler, contains(RehberGorev.kasaDevri));
    });
  });
}

/// Ürün eklemenin dar yüzeyi — testlerin her birine kopyalanan kurulum kapanışı yerine
/// fikstür sınıfı (proje kuralı 2026-08-17: durum ve davranış aynı nesnede).
class UrunOrnegi {
  UrunOrnegi(this.db);

  final AppDatabase db;

  ProductsCompanion companion(String id, String ad, {String? silindi}) =>
      ProductsCompanion.insert(
        id: id,
        name: ad,
        unitPriceKurus: 10000,
        updatedOccurredAt: '2026-09-01T00:00:00Z',
        deletedAt: Value(silindi),
      );
}
