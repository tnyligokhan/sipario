// BİLDİRİM ALTYAPISI — sözleşmenin ve politikaların regresyon kilidi.
//
// Kapsam SAF katmandır: sessiz saat, günlük bütçe, kimlik üretimi, tercih deposu ve sahte
// servis. Gerçek `YerelBildirimServisi` platform kanalı istediği için buradan test EDİLEMEZ
// (kanal kurulumu, izin ve zamanlama cihazda doğrulanır) — ama kararların TAMAMI saf
// fonksiyonlara çekildi, o yüzden kurallar burada çivileniyor.

import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/bildirim/bildirim_ayarlari.dart';
import 'package:sipario/bildirim/bildirim_servisi.dart';
import 'package:sipario/bildirim/bildirim_tetikleyici.dart';
import 'package:sipario/bildirim/bildirim_sozlesmesi.dart';

void main() {
  group('BildirimKategori.wire — MAĞAZADA DEĞİŞMEZ', () {
    test('kanal kimlikleri sabittir', () {
      // Bu değerler sistem bildirim kanalının kimliğidir. Değişirse bayinin KAPATTIĞI kanal
      // yeni bir kanal olarak geri açılır ve kapattığı bildirimi yeniden almaya başlar.
      expect(BildirimKategori.gunSonuOzeti.wire, 'gun_sonu_ozeti');
      expect(BildirimKategori.sistem.wire, 'sistem');
    });

    test('wire → kategori geri çevrimi', () {
      for (final k in BildirimKategori.values) {
        expect(BildirimKategori.wiredan(k.wire), k);
      }
      expect(BildirimKategori.wiredan('zort'), isNull);
      expect(BildirimKategori.wiredan(null), isNull);
    });

    test('her kategorinin ekranda görünen adı ve açıklaması var', () {
      for (final k in BildirimKategori.values) {
        expect(k.ad, isNotEmpty);
        expect(k.aciklama, isNotEmpty);
      }
    });
  });

  group('Kimlik üretimi', () {
    test('kimlik kategori önekini taşır — bütçe sayacı kategoriyi ondan çözer', () {
      expect(bildirimKimligi(BildirimKategori.siparisAtandi, 'm1'), 'siparis_atandi:m1');
      expect(
        bildirimKimligi(BildirimKategori.gunSonuOzeti, bildirimGunAnahtari(DateTime(2026, 7, 27))),
        'gun_sonu_ozeti:2026-07-27',
      );
    });

    test('gün anahtarı sıfır dolgulu', () {
      expect(bildirimGunAnahtari(DateTime(2026, 1, 5)), '2026-01-05');
      expect(bildirimGunAnahtari(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('sayısal kimlik KARARLI, pozitif ve ayrışıyor', () {
      // Android bildirim id'si int'tir; aynı kimlik HER ZAMAN aynı sayıyı vermeli, yoksa
      // "aynı kimlik üzerine yazar" sözleşmesi kırılır ve bayi iki kopya görür.
      expect(bildirimSayisalKimlik('siparis_atandi:m1'), bildirimSayisalKimlik('siparis_atandi:m1'));
      expect(bildirimSayisalKimlik('siparis_atandi:m1'), isNot(bildirimSayisalKimlik('borc_esigi:m2')));
      for (final k in ['a', 'siparis_atandi:m1', 'gun_sonu_ozeti:2026-07-27', 'çğüşiö']) {
        expect(bildirimSayisalKimlik(k), greaterThanOrEqualTo(0));
      }
    });
  });

  group('bildirimYoluCoz — dokunma sözlüğü', () {
    test('Faz 1 sözlüğü çözülür', () {
      expect(bildirimYoluCoz('gunsonu'), (tur: 'gunsonu', id: null));
      expect(bildirimYoluCoz('musteri/m1'), (tur: 'musteri', id: 'm1'));
      // Kimlikler UUID; içinde tire var, ilk `/`den sonrası olduğu gibi alınmalı.
      expect(bildirimYoluCoz('musteri/019fa40a-986c-7000-adef-8f3953e64487'),
          (tur: 'musteri', id: '019fa40a-986c-7000-adef-8f3953e64487'));
    });

    test('TANINMAYAN yol null döner, İSTİSNA ATMAZ', () {
      // Sözlük Faz 2'de büyüyecek; zamanlanmış eski bir bildirim yeni bir yol taşıyabilir ya da
      // tersi. Bilinmeyen hedef bir hata değil — kullanıcı bulunduğu yerde kalır.
      expect(bildirimYoluCoz('musteriler?suzgec=gecikmis'), isNull);
      expect(bildirimYoluCoz('siparis/s1'), isNull, reason: 'Faz 1de bağlı değil');
      expect(bildirimYoluCoz('zort'), isNull);
      expect(bildirimYoluCoz('musteri/'), isNull, reason: 'kimliksiz müşteri yolu');
    });

    test('boş ve null yol null döner', () {
      expect(bildirimYoluCoz(null), isNull);
      expect(bildirimYoluCoz(''), isNull);
      expect(bildirimYoluCoz('   '), isNull);
    });
  });

  group('SessizSaatler — gece bildirim yok, ATILMAZ ertelenir', () {
    const s = SessizSaatler(); // 22:00 – 08:00

    test('gece yarısını aşan aralık doğru hesaplanır', () {
      expect(s.icindeMi(DateTime(2026, 7, 27, 22)), isTrue, reason: 'sınır dahil');
      expect(s.icindeMi(DateTime(2026, 7, 27, 23, 30)), isTrue);
      expect(s.icindeMi(DateTime(2026, 7, 28, 3)), isTrue);
      expect(s.icindeMi(DateTime(2026, 7, 28, 7, 59)), isTrue);
      expect(s.icindeMi(DateTime(2026, 7, 28, 8)), isFalse, reason: 'bitiş saati dahil DEĞİL');
      expect(s.icindeMi(DateTime(2026, 7, 28, 12)), isFalse);
      expect(s.icindeMi(DateTime(2026, 7, 28, 21, 59)), isFalse);
    });

    test('akşam doğan bildirim ERTESİ SABAH 08:00e ertelenir', () {
      expect(s.ertelenmisAn(DateTime(2026, 7, 27, 23, 30)), DateTime(2026, 7, 28, 8));
    });

    test('gece yarısından sonrası AYNI GÜN 08:00e ertelenir', () {
      expect(s.ertelenmisAn(DateTime(2026, 7, 28, 3)), DateTime(2026, 7, 28, 8));
    });

    test('sessiz saat dışındaki an DEĞİŞMEZ', () {
      final an = DateTime(2026, 7, 28, 14, 12);
      expect(s.ertelenmisAn(an), an);
    });

    test('gündüz aralığı (kapalı olmayan, gece yarısını aşmayan) da desteklenir', () {
      const gunduz = SessizSaatler(baslangicSaat: 13, bitisSaat: 15);
      expect(gunduz.icindeMi(DateTime(2026, 7, 28, 14)), isTrue);
      expect(gunduz.icindeMi(DateTime(2026, 7, 28, 16)), isFalse);
      expect(gunduz.ertelenmisAn(DateTime(2026, 7, 28, 14)), DateTime(2026, 7, 28, 15));
    });

    test('başlangıç == bitiş → sessiz saat KAPALI', () {
      const kapali = SessizSaatler(baslangicSaat: 0, bitisSaat: 0);
      expect(kapali.kapali, isTrue);
      expect(kapali.icindeMi(DateTime(2026, 7, 28, 3)), isFalse);
    });
  });

  group('GunlukSinir — bildirim yorgunluğuna karşı', () {
    const sinir = GunlukSinir(); // toplam 6, kategori başına 2

    test('boş günde yer var', () {
      expect(sinir.yerVarMi(BildirimKategori.siparisAtandi, {}, 'borc_esigi:a'), isTrue);
    });

    test('kategori başına sınır dolunca YENİ kimlik geçmez', () {
      final gunluk = {
        BildirimKategori.siparisAtandi: {'borc_esigi:a', 'borc_esigi:b'},
      };
      expect(sinir.yerVarMi(BildirimKategori.siparisAtandi, gunluk, 'borc_esigi:c'), isFalse);
      // Ama BAŞKA kategori hâlâ geçer — tek kategori bütçeyi tek başına tüketmez.
      expect(sinir.yerVarMi(BildirimKategori.sistem, gunluk, 'sistem:a'), isTrue);
    });

    test('ZATEN GÖSTERİLMİŞ kimliğin tazelenmesi her zaman serbest', () {
      final gunluk = {
        BildirimKategori.siparisAtandi: {'borc_esigi:a', 'borc_esigi:b'},
      };
      // Sınır dolu olsa bile aynı bildirimin güncellenmesi geçer: üzerine yazılır, yeni
      // satır açmaz, bütçe yemez.
      expect(sinir.yerVarMi(BildirimKategori.siparisAtandi, gunluk, 'borc_esigi:a'), isTrue);
    });

    test('toplam sınır kategori sınırından ÖNCE devreye girebilir', () {
      final gunluk = {
        BildirimKategori.siparisAtandi: {'borc_esigi:a', 'borc_esigi:b'},
        BildirimKategori.gunSonuOzeti: {'gun_sonu_ozeti:a', 'gun_sonu_ozeti:b'},
        BildirimKategori.sistem: {'sistem:a', 'sistem:b'},
      };
      // Toplam 6 doldu; dördüncü kategorinin İLK bildirimi bile geçmez.
      expect(sinir.yerVarMi(BildirimKategori.siparisTeslim, gunluk, 'musteri_gecikti:a'), isFalse);
    });
  });

  group('BildirimAyarlari.bellek — tercih ve sayaç', () {
    late BildirimAyarlari ayarlar;

    setUp(() async {
      ayarlar = BildirimAyarlari.bellek();
      await ayarlar.yukle();
    });

    test('varsayılan: TÜM kategoriler AÇIK — istisna yok', () {
      // Borç eşiğinin "eşik girilmeden pasif" istisnası, kategoriyle birlikte 2026-08-14'te
      // kaldırıldı. Artık tek kural geçerli: bayi kapatmadıysa bildirim gelir.
      for (final k in BildirimKategori.values) {
        expect(ayarlar.kategoriAcik(k), isTrue, reason: '${k.wire} varsayılanı');
      }
    });

    test('kapatılan kategori kapalı kalır, diğerleri etkilenmez', () async {
      await ayarlar.kategoriYaz(BildirimKategori.siparisTeslim, false);
      expect(ayarlar.kategoriAcik(BildirimKategori.siparisTeslim), isFalse);
      expect(ayarlar.kategoriAcik(BildirimKategori.gunSonuOzeti), isTrue);

      await ayarlar.kategoriYaz(BildirimKategori.siparisTeslim, true);
      expect(ayarlar.kategoriAcik(BildirimKategori.siparisTeslim), isTrue);
    });

    test('varsayılan sessiz saat 22–08', () {
      expect(ayarlar.sessizSaatler.baslangicSaat, 22);
      expect(ayarlar.sessizSaatler.bitisSaat, 8);
    });

    test('işaretlenen kimlik günlük sayaca girer, kategorisi önekten çözülür', () async {
      final an = DateTime(2026, 7, 27, 10);
      await ayarlar.kimlikIsaretle('siparis_atandi:m1', an);
      await ayarlar.kimlikIsaretle('siparis_atandi:m2', an);
      await ayarlar.kimlikIsaretle('sistem:x', an);

      final gunluk = ayarlar.gunlukKimlikler(an);
      expect(gunluk[BildirimKategori.siparisAtandi], {'siparis_atandi:m1', 'siparis_atandi:m2'});
      expect(gunluk[BildirimKategori.sistem], {'sistem:x'});
    });

    test('aynı kimlik iki kez işaretlenirse sayaç ARTMAZ', () async {
      final an = DateTime(2026, 7, 27, 10);
      await ayarlar.kimlikIsaretle('siparis_atandi:m1', an);
      await ayarlar.kimlikIsaretle('siparis_atandi:m1', an);
      expect(ayarlar.gunlukKimlikler(an)[BildirimKategori.siparisAtandi], hasLength(1));
    });

    test('gün değişince sayaç KENDİLİĞİNDEN sıfırlanır', () async {
      await ayarlar.kimlikIsaretle('siparis_atandi:m1', DateTime(2026, 7, 27, 23));
      // Ertesi gün sorulduğunda dünün kayıtları sayılmaz — ayrı bir temizlik işi yok.
      expect(ayarlar.gunlukKimlikler(DateTime(2026, 7, 28, 9)), isEmpty);
    });

    test('tanınmayan önekli kimlik sayaca girmez, çökertmez', () async {
      final an = DateTime(2026, 7, 27, 10);
      await ayarlar.kimlikIsaretle('zort:m1', an);
      expect(ayarlar.gunlukKimlikler(an), isEmpty);
    });
  });

  group('SahteBildirimServisi — kural yazanların test ikizi', () {
    test('gösterilen taslak kaydedilir', () async {
      final servis = SahteBildirimServisi();
      const t = BildirimTaslagi(
        kategori: BildirimKategori.siparisAtandi,
        baslik: 'Borç eşiği aşıldı',
        govde: 'Ahmet Yılmaz · 12.340,00 ₺',
        kimlik: 'siparis_atandi:m1',
        yol: 'musteri/m1',
      );
      await servis.goster(t);
      expect(servis.gosterilenler, [t]);
    });

    test('AYNI KİMLİK üzerine yazar, yeni satır AÇMAZ', () async {
      final servis = SahteBildirimServisi();
      const ilk = BildirimTaslagi(
        kategori: BildirimKategori.siparisAtandi,
        baslik: 'Borç eşiği aşıldı',
        govde: 'eski',
        kimlik: 'siparis_atandi:m1',
      );
      await servis.goster(ilk);
      await servis.goster(ilk.kopyala(govde: 'yeni'));

      expect(servis.gosterilenler, hasLength(1));
      expect(servis.gosterilenler.single.govde, 'yeni');
    });

    test('izin yoksa sessizce atlanır', () async {
      final servis = SahteBildirimServisi(izinVar: false);
      await servis.goster(const BildirimTaslagi(
        kategori: BildirimKategori.sistem,
        baslik: 'a',
        govde: 'b',
        kimlik: 'sistem:a',
      ));
      expect(servis.gosterilenler, isEmpty);
    });

    test('kapalı kategori sessizce atlanır', () async {
      final servis = SahteBildirimServisi(
        kapaliKategoriler: {BildirimKategori.siparisAtandi},
      );
      await servis.goster(const BildirimTaslagi(
        kategori: BildirimKategori.siparisAtandi,
        baslik: 'a',
        govde: 'b',
        kimlik: 'siparis_atandi:m1',
      ));
      expect(servis.gosterilenler, isEmpty);
      expect(await servis.kategoriAcikMi(BildirimKategori.siparisAtandi), isFalse);
      expect(await servis.kategoriAcikMi(BildirimKategori.sistem), isTrue);
    });

    test('zamanlama an ile birlikte kaydedilir, aynı kimlik yenilenir', () async {
      final servis = SahteBildirimServisi();
      const t = BildirimTaslagi(
        kategori: BildirimKategori.gunSonuOzeti,
        baslik: 'Gün sonu',
        govde: 'özet',
        kimlik: 'gun_sonu_ozeti:2026-07-27',
      );
      await servis.zamanla(t, DateTime(2026, 7, 27, 20));
      await servis.zamanla(t, DateTime(2026, 7, 27, 21));

      expect(servis.zamanlananlar, hasLength(1));
      expect(servis.zamanlananlar.single.$2, DateTime(2026, 7, 27, 21));
    });

    test('iptal hem gösterileni hem zamanlananı düşürür', () async {
      final servis = SahteBildirimServisi();
      const t = BildirimTaslagi(
        kategori: BildirimKategori.sistem,
        baslik: 'a',
        govde: 'b',
        kimlik: 'rutin_teslim_gunu:m1',
      );
      await servis.goster(t);
      await servis.zamanla(t, DateTime(2026, 7, 27, 9));
      await servis.iptal(t.kimlik);

      expect(servis.gosterilenler, isEmpty);
      expect(servis.zamanlananlar, isEmpty);
      expect(servis.iptaller, ['rutin_teslim_gunu:m1']);
    });

    test('izin istenince verilir ve sonraki gösterim geçer', () async {
      final servis = SahteBildirimServisi(izinVar: false);
      expect(await servis.izinDurumu(), isFalse);
      expect(await servis.izinIste(), isTrue);
      await servis.goster(const BildirimTaslagi(
        kategori: BildirimKategori.sistem,
        baslik: 'a',
        govde: 'b',
        kimlik: 'sistem:a',
      ));
      expect(servis.gosterilenler, hasLength(1));
    });
  });

  group('BildirimTetikleyici — zamanlama hesapları', () {
    BildirimTaslagi taslak(BildirimKategori k, String kimlik) =>
        BildirimTaslagi(kategori: k, baslik: 'x', govde: 'y', kimlik: kimlik);

    ZamanlanmisIs is_(String ad, int saat, TaslakUretici u) => ZamanlanmisIs(
          ad: ad,
          uretici: u,
          an: (simdi) => BildirimTetikleyici.gunlukAn(simdi, saat),
        );

    test('günlük an: saat GEÇMEDİYSE bugün, geçtiyse yarın', () {
      expect(BildirimTetikleyici.gunlukAn(DateTime(2026, 7, 27, 9), 20),
          DateTime(2026, 7, 27, 20));
      // 21:00'de açılışta GEÇMİŞ bir ana zamanlamak bildirimi ANINDA ateşlerdi.
      expect(BildirimTetikleyici.gunlukAn(DateTime(2026, 7, 27, 21), 20),
          DateTime(2026, 7, 28, 20));
      // Sabah hatırlatması (09:00) aynı hesabı kullanır — saat parametre olduğu için
      // her zamanlanmış iş bu tek dalı paylaşır.
      expect(BildirimTetikleyici.gunlukAn(DateTime(2026, 7, 27, 21), 9),
          DateTime(2026, 7, 28, 9));
    });

    test('anlık taramalar GÖSTERİLİR, zamanlananlar KURULUR', () async {
      final servis = SahteBildirimServisi();
      final anlik = taslak(BildirimKategori.sistem, 'sistem:2026-07-27');
      final gunSonu = taslak(BildirimKategori.gunSonuOzeti, 'gun_sonu_ozeti:2026-07-27');

      await BildirimTetikleyici(
        servis: servis,
        anlik: [() async => anlik],
        zamanlanan: [is_('gunSonu', 20, () async => gunSonu)],
      ).acilistaKos(simdi: DateTime(2026, 7, 27, 9));

      expect(servis.gosterilenler, [anlik]);
      expect(servis.zamanlananlar.single.$2, DateTime(2026, 7, 27, 20));
    });

    test('BİR üretici patlarsa diğerleri koşmaya DEVAM eder', () async {
      // İstisna DIŞARI SIZMAMALI: bu çağrı `main`de açılış yolunda koşuyor. Ayrıca bir
      // kuralın patlaması diğerlerini düşüremez — üçü de aynı listede.
      final servis = SahteBildirimServisi();
      final saglam = taslak(BildirimKategori.kullanimHakki, 'kullanim_hakki:2026-07-27');

      await BildirimTetikleyici(
        servis: servis,
        anlik: [
          () async => throw StateError('defter okunamadı'),
          () async => saglam,
        ],
        zamanlanan: [
          is_('patlak', 20, () async => throw StateError('bozuk')),
          is_(
            'saglam',
            21,
            () async => taslak(BildirimKategori.gunKapanisHatirlatma, 'gun_kapanis:x'),
          ),
        ],
      ).acilistaKos(simdi: DateTime(2026, 7, 27, 9));

      expect(servis.gosterilenler, [saglam]);
      expect(servis.zamanlananlar.single.$2, DateTime(2026, 7, 27, 21));
    });

    test('kural null dönerse bildirim ÜRETİLMEZ (sessizlik de bir cevaptır)', () async {
      final servis = SahteBildirimServisi();
      await BildirimTetikleyici(
        servis: servis,
        anlik: [() async => null],
        zamanlanan: [is_('gunSonu', 20, () async => null)],
      ).acilistaKos(simdi: DateTime(2026, 7, 27, 9));

      expect(servis.gosterilenler, isEmpty);
      expect(servis.zamanlananlar, isEmpty);
    });
  });
}
