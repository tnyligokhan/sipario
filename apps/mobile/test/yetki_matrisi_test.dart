import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/screens/team.dart';

/// GENEL YETKİ MATRİSİ — 26 yetki × 3 rol × 13 anahtarın TAM tablosu (kod borcu #9).
///
/// NEDEN AYRI BİR DOSYA — ölçüldü (2026-08-17): matrisin testi "yok" değil, EKSİKTİ ve eksiğin
/// yeri tam olarak burasıydı.
///   • `kurye_yetkileri_test.dart` 13 anahtarın YALNIZ BEŞİNE dokunuyordu (musteri, siparis,
///     tahsilat, iskonto, gunSonu). Kalan sekiz anahtarın (`tumSiparisler`,
///     `gecmisTeslimatlar`, `sahaGideri`, `telefonMaskeleme`, `musteriGecmisDefteri`,
///     `borcHatirlatma`, `stokPasifleme`, `cagriGunlugu`) `yetkiler()` çıktısına ULAŞTIĞINI
///     hiçbir test kanıtlamıyordu — anahtar yanlış alana bağlansa suite yeşil kalırdı.
///   • `kurye_kisisel_yetki_test.dart` DEVRALMA mekanizmasını (13 alan) iyi kilitliyor ama
///     rol × yetki tablosuna hiç bakmıyor.
///   • `patron` ile `operator` arasındaki TEK farkın (`isletmeAbonelikAyarlari`) testi yoktu.
///   • Rol tanınmadığında (`null`, senkron öncesi) ne olduğunun testi yoktu.
///
/// Bu dosya tabloyu VERİ olarak yazar: her satır bir yetki, her sütun bir rol/izin senaryosu.
/// Kural değişirse tek bir hücre kırmızı yanar ve neyin değiştiği okunur — 26 ayrı `expect`
/// yazmanın aksine, "hangi hücreyi kimse yazmamış" sorusu da cevaplanabilir olur.
void main() {
  // ═════════════════════════════════════════════════════════════════════════════════════════
  // TAM TABLO
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('yetkiler() — 26 yetki × 5 senaryonun tam tablosu', () {
    /// Senaryolar. `atamaHedefiVar: true` sabittir (tek kişilik bayi ayrı grupta sınanır).
    final patron = yetkiler(rol: 'patron', atamaHedefiVar: true);
    final operatorRol = yetkiler(rol: 'operator', atamaHedefiVar: true);
    final kuryeVarsayilan = yetkiler(rol: 'kurye', atamaHedefiVar: true);
    final kuryeKapali = yetkiler(rol: 'kurye', atamaHedefiVar: true, izin: _hepsiKapali);
    final kuryeAcik = yetkiler(rol: 'kurye', atamaHedefiVar: true, izin: _hepsiAcik);

    for (final satir in _matris) {
      test(satir.ad, () {
        final oku = _okuyucular[satir.ad]!;
        expect(oku(patron), satir.patron, reason: 'patron');
        expect(oku(operatorRol), satir.operatorRol, reason: 'operator');
        expect(oku(kuryeVarsayilan), satir.kuryeVarsayilan, reason: 'kurye · varsayılan izinler');
        expect(oku(kuryeKapali), satir.kuryeKapali, reason: 'kurye · 13 anahtar KAPALI');
        expect(oku(kuryeAcik), satir.kuryeAcik, reason: 'kurye · 13 anahtar AÇIK');
      });
    }

    test('tablo TAM — 26 yetkinin hepsi tabloda ve okuyucu sözlüğünde', () {
      // `RolYetkileri`ye yeni alan eklendiğinde bu test kırmızı YANMAZ (Dart'ta yansıma yok);
      // sayıyı burada kilitlemek en azından "tabloyu güncellemeyi unuttum" durumunu, alan
      // eklenirken bu dosyaya bakılmasını zorunlu kılacak kadar görünür yapar.
      expect(_matris.length, 26);
      expect(_okuyucular.length, 26);
      expect(_matris.map((s) => s.ad).toSet(), _okuyucular.keys.toSet());
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // ANAHTAR → YETKİ EŞLEMESİ (13 anahtarın hiçbiri ölü değil, hiçbiri fazladan bir şey açmıyor)
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('13 anahtarın her biri TEK bir yetkiye bağlı', () {
    for (final e in _anahtarEslemesi.entries) {
      test('${e.key} anahtarı yalnız ${e.value} yetkisini açar', () {
        // Hepsi kapalı tabandan TEK anahtarı açıyoruz. Yalnız eşlendiği yetki değişmeli:
        // • hiç değişmemesi → anahtar ÖLÜ (ekranda kutucuk var, arkasında kural yok),
        // • birden fazlası değişmesi → kopyala-yapıştır ile iki satır aynı anahtarı okuyor.
        final taban = _kume(yetkiler(rol: 'kurye', atamaHedefiVar: true, izin: _hepsiKapali));
        final acik = _kume(yetkiler(rol: 'kurye', atamaHedefiVar: true, izin: _tekAnahtar(e.key)));

        final degisenler = {
          for (final ad in _okuyucular.keys)
            if (taban[ad] != acik[ad]) ad,
        };
        expect(degisenler, {e.value});
        expect(acik[e.value], isTrue);
      });

      test('${e.key} anahtarı KAPATILINCA yalnız ${e.value} kapanır', () {
        // Ters yön: hepsi açık tabandan tek anahtarı kapatmak. Bu yön ayrı bir tuzağı yakalar —
        // `yonetici || k.x` yerine yanlışlıkla `yonetici || true` yazılmış bir satır ileri
        // yönde farkı üretir ama geri yönde ÜRETMEZ.
        final taban = _kume(yetkiler(rol: 'kurye', atamaHedefiVar: true, izin: _hepsiAcik));
        final kapali = _kume(yetkiler(rol: 'kurye', atamaHedefiVar: true, izin: _tekAnahtarHaric(e.key)));

        final degisenler = {
          for (final ad in _okuyucular.keys)
            if (taban[ad] != kapali[ad]) ad,
        };
        expect(degisenler, {e.value});
        expect(kapali[e.value], isFalse);
      });
    }

    test('13 anahtarın hepsi eşlemede', () {
      expect(_anahtarEslemesi.length, 13);
      // Eşlenen yetkiler BİRBİRİNDEN FARKLI olmalı — iki anahtarın aynı yetkiye bakması,
      // bayinin ekranda ayrı sandığı iki kutucuğun aslında tek kural olması demektir.
      expect(_anahtarEslemesi.values.toSet().length, 13);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // ROL TAVANI — anahtarlar yöneticiye özel yetkileri kuryeye AÇAMAZ
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('rol tavanı — 13 anahtarın hepsi açık olsa da kuryeye geçmeyenler', () {
    test('yalnız-yönetici 11 yetki kuryede KAPALI kalır', () {
      final k = _kume(yetkiler(rol: 'kurye', atamaHedefiVar: true, izin: _hepsiAcik));
      for (final ad in _yalnizYonetici) {
        expect(k[ad], isFalse, reason: '$ad kuryeye açılamaz — anahtar kümesi bilinçli olarak dar');
      }
      expect(_yalnizYonetici.length, 11);
    });

    test('isletmeAbonelikAyarlari YALNIZ patronda — operatör de göremez', () {
      // Patron/tezgâh farklarından biri — tam listesi aşağıdaki testte kilitli. Kaybolursa
      // tezgâh faturayı ve aboneliği yönetebilir hâle gelir; ayrıca sınanmasının sebebi bu
      // yetkinin PARA KONTROLÜ kümesinde değil, HESAP SAHİPLİĞİ kümesinde olmasıdır.
      expect(yetkiler(rol: 'patron', atamaHedefiVar: true).isletmeAbonelikAyarlari, isTrue);
      expect(yetkiler(rol: 'operator', atamaHedefiVar: true).isletmeAbonelikAyarlari, isFalse);
      expect(yetkiler(rol: 'kurye', atamaHedefiVar: true, izin: _hepsiAcik).isletmeAbonelikAyarlari,
          isFalse);
    });

    test('RolYetkileri.tumu, PATRON satırının aynısıdır (elle tutulan kopya kaymasın)', () {
      // `tumu` elle yazılmış 26 satırlık bir sabittir ve altı widget testi ona yaslanıyor
      // (`ui_kara_liste_test.dart`). `yetkiler()` değişip `tumu` değişmezse o testler artık
      // var olmayan bir dünyayı sınar — kopya kayması sessizdir, çünkü hiçbiri kırılmaz.
      expect(_kume(RolYetkileri.tumu), _kume(yetkiler(rol: 'patron', atamaHedefiVar: true)));
    });

    test('PATRON ile TEZGÂH arasındaki fark TAM OLARAK para kontrolü + abonelik (2026-08-20)',
        () {
      // TEZGÂH ARTIK "MİNİ PATRON" DEĞİL. Bu test, farkın TAM listesini kilitler: yeni bir yetki
      // eklendiğinde onu hangi tarafa koyduğumuz bilinçli bir karar olmak zorunda kalsın —
      // varsayılan tarafa kayması sessiz bir yetki genişlemesi/daralmasıdır.
      final p = _kume(yetkiler(rol: 'patron', atamaHedefiVar: true, izin: _hepsiKapali));
      final o = _kume(yetkiler(rol: 'operator', atamaHedefiVar: true, izin: _hepsiKapali));
      final fark = {
        for (final ad in _okuyucular.keys)
          if (p[ad] != o[ad]) ad,
      };
      expect(fark, {
        // Defterin ve katalogun sahibi tektir.
        'gunuKapatma',
        'gecmisHesapArsivi',
        'defterDuzeltme',
        'musteriBorcSilme',
        'musteriYonetimi',
        'urunYonetimi',
        'muafTelefonYonetimi',
        // Hesabın sahibi tektir.
        'isletmeAbonelikAyarlari',
      });
    });

    test('YÖNETİCİ anahtarlardan ETKİLENMEZ — bayi kendini kilitleyemez', () {
      // Kapıyı yöneticiye de uygulasaydık, bayi tüm anahtarları kapatıp yetkileri geri açacağı
      // ekranı da kendine kapatırdı (ve o ekran kilidin arkasında kalırdı).
      for (final rol in ['patron', 'operator']) {
        final kapali = _kume(yetkiler(rol: rol, atamaHedefiVar: true, izin: _hepsiKapali));
        final acik = _kume(yetkiler(rol: rol, atamaHedefiVar: true, izin: _hepsiAcik));
        expect(kapali, acik, reason: '$rol için anahtarlar hiçbir farkı üretmemeli');
      }
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // MASKELEME — ters kutuplu tek alan
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('telefonMaskeleme — matrisin tek TERS kutuplu alanı', () {
    test('bir YETKİ değil KISIT: yöneticide her zaman KAPALI', () {
      // `!yonetici && k.telefonMaskeleme` — diğer 25 alanın hepsi `yonetici || ...` biçiminde.
      // Kutup yanlışlıkla düzleştirilirse patronun telefon listesi maskelenir; hiçbir ekran
      // testi bunu "yetki kaybı" olarak okumaz, sessiz bir gerileme olur.
      for (final rol in ['patron', 'operator']) {
        expect(yetkiler(rol: rol, atamaHedefiVar: true, izin: _hepsiAcik).telefonMaskeleme, isFalse,
            reason: '$rol maskeleme görmemeli');
      }
    });

    test('kuryede VARSAYILAN AÇIK — KVKK tarafı güvenli yön', () {
      expect(yetkiler(rol: 'kurye', atamaHedefiVar: true).telefonMaskeleme, isTrue);
      expect(KuryeIzinleri.varsayilan.telefonMaskeleme, isTrue);
    });

    test('bayi kapatınca kurye tam numarayı görür', () {
      expect(yetkiler(rol: 'kurye', atamaHedefiVar: true, izin: _hepsiKapali).telefonMaskeleme, isFalse);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // TANINMAYAN ROL — senkron öncesi / bozuk değer
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('tanınmayan rol EN DAR kümeye düşer', () {
    test('null / boş / uydurma rol, kurye kümesinin AYNISINI verir', () {
      // `sync_meta.user_role` daha inmemişse veya sunucu ileride yeni bir rol adı gönderirse
      // istemci onu YETKİLİ sanmamalı. Testin kilitlediği şey bu güvenli-yön varsayılanıdır.
      final kurye = _kume(yetkiler(rol: 'kurye', atamaHedefiVar: true));
      for (final rol in <String?>[null, '', 'admin', 'sahip', 'PATRON', 'Operator']) {
        expect(_kume(yetkiler(rol: rol, atamaHedefiVar: true)), kurye,
            reason: '${rol ?? "null"} rolü kurye kadar yetkili olmalı, fazlası değil');
      }
    });

    test('rol büyük harfle gelirse YETKİ VERİLMEZ (eşleşme birebir)', () {
      // Sözleşmenin küçük harf olduğunu açıkça yazıyoruz: sunucu bir gün 'Patron' gönderirse
      // uygulama sessizce yetkisiz kalır — bu bir arıza olur ama GÜVENLİ yönde bir arızadır.
      expect(yetkiler(rol: 'PATRON', atamaHedefiVar: true).urunYonetimi, isFalse);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // TEK KİŞİLİK İŞLETME (kuryeVar)
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('kuryeVar — tek kişilik işletmede gizlenen yüzey', () {
    test('kurye yoksa YALNIZ atama kapanır, başka hiçbir yetki etkilenmez', () {
      final varken = _kume(yetkiler(rol: 'patron', atamaHedefiVar: true));
      final yokken = _kume(yetkiler(rol: 'patron', atamaHedefiVar: false));
      final fark = {
        for (final ad in _okuyucular.keys)
          if (varken[ad] != yokken[ad]) ad,
      };
      expect(fark, {'atama'});
      expect(yokken['atama'], isFalse, reason: 'atanacak kimse yokken atama yüzeyi anlamsız');
    });

    test('kurye rolünde kuryeVar hiçbir şeyi değiştirmez', () {
      // `atama: yonetici && kuryeVar` — kuryede zaten `yonetici` false olduğu için ikinci
      // koşulun tek başına bir etkisi olmamalı.
      expect(_kume(yetkiler(rol: 'kurye', atamaHedefiVar: true, izin: _hepsiAcik)),
          _kume(yetkiler(rol: 'kurye', atamaHedefiVar: false, izin: _hepsiAcik)));
    });

    test('oturumYetkileri yolu atamaHedefiVar: false geçer — atama ORADAN gelmez', () {
      // Tek atış yol (`oturumYetkileri`) kurye listesini okumaz; atama yetkisini o yoldan alan
      // bir ekran patronda bile kapalı görür. Davranış bilinçli, ama YAZILI olsun: atamayı
      // kabuk (`home_shell`) kendi kurye listesiyle hesaplar.
      expect(yetkiler(rol: 'patron', atamaHedefiVar: false).atama, isFalse);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // KİŞİSEL EZME MATRİSİ EZMEZ
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('kişisel ezme (2026-08-10) matrisin TAVANINI değiştirmez', () {
    test('hepsi true ezilmiş bir kurye yine yalnız-yönetici yetkilerini alamaz', () {
      const hepsiEzildi = KuryeIzinEzmeleri(
        musteri: true,
        siparis: true,
        tahsilat: true,
        iskonto: true,
        gunSonu: true,
        tumSiparisler: true,
        gecmisTeslimatlar: true,
        sahaGideri: true,
        telefonMaskeleme: true,
        musteriGecmisDefteri: true,
        borcHatirlatma: true,
        stokPasifleme: true,
        cagriGunlugu: true,
      );
      final k = _kume(yetkiler(
        rol: 'kurye',
        atamaHedefiVar: true,
        izin: kuryeIzinleriCoz(_hepsiKapali, hepsiEzildi),
      ));
      for (final ad in _yalnizYonetici) {
        expect(k[ad], isFalse, reason: '$ad kişisel ezmeyle de açılamaz');
      }
      expect(k['isletmeAbonelikAyarlari'], isFalse);
    });

    test('ÇÖZÜLMÜŞ izin ile ELLE kurulmuş izin aynı yetki kümesini verir', () {
      // Devralma yalnız `kuryeIzinleriCoz` içinde yaşar; `yetkiler()` çözülmüş değeri alır.
      // İkinci bir çözüm yolu doğsa bu eşitlik bozulurdu.
      const ezme = KuryeIzinEzmeleri(iskonto: true, tahsilat: false);
      final cozulmus = yetkiler(
        rol: 'kurye',
        atamaHedefiVar: true,
        izin: kuryeIzinleriCoz(KuryeIzinleri.varsayilan, ezme),
      );
      final elle = yetkiler(
        rol: 'kurye',
        atamaHedefiVar: true,
        izin: const KuryeIzinleri(iskonto: true, tahsilat: false),
      );
      expect(_kume(cozulmus), _kume(elle));
    });

    test('yöneticinin kişisel ezmesi ONU bağlamaz', () {
      const hepsiKapatildi = KuryeIzinEzmeleri(
        musteri: false,
        siparis: false,
        tahsilat: false,
        iskonto: false,
        gunSonu: false,
        tumSiparisler: false,
        gecmisTeslimatlar: false,
        sahaGideri: false,
        telefonMaskeleme: false,
        musteriGecmisDefteri: false,
        borcHatirlatma: false,
        stokPasifleme: false,
        cagriGunlugu: false,
      );
      final p = _kume(yetkiler(
        rol: 'patron',
        atamaHedefiVar: true,
        izin: kuryeIzinleriCoz(KuryeIzinleri.varsayilan, hepsiKapatildi),
      ));
      expect(p, _kume(yetkiler(rol: 'patron', atamaHedefiVar: true)));
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // ÇEKMECE GÖRÜNÜRLÜĞÜ ile MATRİSİN TUTARLILIĞI
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('çekmece yüzeyleri matristen besleniyor', () {
    // `home_shell.dart` çekmeceye üç görünürlük bayrağı geçiyor ve üçü de doğrudan bir matris
    // alanıdır: urunlerGorunur=urunYonetimi, borclularGorunur=toplamBorclulariGorme,
    // cagriGunluguGorunur=cagriGunlugu. Buradaki test o EŞLEMENİN sonucunu kilitler — bayrağın
    // hangi alandan geldiği değişirse kuryede görünmemesi gereken bir giriş açılır.
    test('kuryede Ürünler ve Borçlular girişleri KAPALI kalır (anahtarlar açıkken bile)', () {
      final k = yetkiler(rol: 'kurye', atamaHedefiVar: true, izin: _hepsiAcik);
      expect(k.urunYonetimi, isFalse);
      expect(k.toplamBorclulariGorme, isFalse);
    });

    test('Çağrı Geçmişi kuryede ANAHTARA bağlıdır — varsayılan kapalı, bayi açabilir', () {
      expect(yetkiler(rol: 'kurye', atamaHedefiVar: true).cagriGunlugu, isFalse);
      expect(yetkiler(rol: 'kurye', atamaHedefiVar: true, izin: _tekAnahtar('cagriGunlugu')).cagriGunlugu,
          isTrue);
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// TABLO VERİSİ
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Matrisin bir satırı: bir yetkinin beş senaryodaki beklenen değeri.
class _Satir {
  const _Satir(
    this.ad, {
    required this.patron,
    required this.operatorRol,
    required this.kuryeVarsayilan,
    required this.kuryeKapali,
    required this.kuryeAcik,
  });

  final String ad;
  final bool patron;
  final bool operatorRol;

  /// Kurye · `izin` verilmemiş (senkron öncesi veya ayar satırı yok).
  final bool kuryeVarsayilan;

  /// Kurye · 13 anahtarın hepsi kapalı.
  final bool kuryeKapali;

  /// Kurye · 13 anahtarın hepsi açık (bayinin verebileceği EN GENİŞ küme).
  final bool kuryeAcik;
}

/// Yalnız-yönetici yetkiler: hiçbir anahtar ve hiçbir kişisel ezme bunları kuryeye açamaz.
const _yalnizYonetici = <String>[
  'siparisIptal',
  'rotaCalistir',
  'atama',
  'musteriBorcSilme',
  'toplamBorclulariGorme',
  'gunuKapatma',
  'gecmisHesapArsivi',
  'defterDuzeltme',
  'musteriYonetimi',
  'urunYonetimi',
  'muafTelefonYonetimi',
];

/// 26 satırlık TAM tablo. `t`/`f` kısaltmaları bilinçli: sütunlar hizalı kalınca yanlış bir
/// hücre gözle de görülür.
const _t = true;
const _f = false;

const _matris = <_Satir>[
  // 1. Sipariş & Teslimat
  _Satir('tumSiparisleriGorme',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _t),
  _Satir('siparisAcma',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _t, kuryeKapali: _f, kuryeAcik: _t),
  _Satir('siparisIptal',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _f),
  _Satir('gecmisTeslimatlariGorme',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _t),
  _Satir('rotaCalistir',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _f),
  _Satir('atama',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _f),

  // 2. Kasa & Tahsilat
  _Satir('tahsilat',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _t, kuryeKapali: _f, kuryeAcik: _t),
  _Satir('iskonto',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _t),
  _Satir('musteriBorcSilme',
      patron: _t, operatorRol: _f, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _f),
  _Satir('sahaGideri',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _t),
  _Satir('toplamBorclulariGorme',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _f),

  // 3. Gün Sonu & Kasa Devri
  _Satir('gunSonu',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _t),
  _Satir('gunuKapatma',
      patron: _t, operatorRol: _f, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _f),
  _Satir('gecmisHesapArsivi',
      patron: _t, operatorRol: _f, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _f),
  _Satir('defterDuzeltme',
      patron: _t, operatorRol: _f, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _f),

  // 4. Müşteri & KVKK
  _Satir('musteriDuzenleme',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _t, kuryeKapali: _f, kuryeAcik: _t),
  _Satir('musteriYonetimi',
      patron: _t, operatorRol: _f, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _f),
  // TERS KUTUP: yetki değil KISIT — yöneticide hep kapalı, kuryede varsayılan AÇIK.
  _Satir('telefonMaskeleme',
      patron: _f, operatorRol: _f, kuryeVarsayilan: _t, kuryeKapali: _f, kuryeAcik: _t),
  _Satir('musteriGecmisDefteri',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _t),
  _Satir('borcHatirlatma',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _t),

  // 5. Ürün & Stok
  _Satir('urunYonetimi',
      patron: _t, operatorRol: _f, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _f),
  _Satir('stokPasifleme',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _t, kuryeKapali: _f, kuryeAcik: _t),

  // 6. Çağrı & Ayarlar
  _Satir('cagriGunlugu',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _t),
  _Satir('muafTelefonYonetimi',
      patron: _t, operatorRol: _f, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _f),
  // Matristeki TEK patron/operatör ayrımı.
  _Satir('isletmeAbonelikAyarlari',
      patron: _t, operatorRol: _f, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _f),
  // Herkese açık — cihazın kendi ayarı, bayiyi ilgilendirmez.
  _Satir('cihazAyarlari',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _t, kuryeKapali: _t, kuryeAcik: _t),
];

/// Ada göre alan okuyucuları — tabloyu veriyle gezebilmenin tek yolu (Dart'ta yansıma yok).
final Map<String, bool Function(RolYetkileri)> _okuyucular = {
  'tumSiparisleriGorme': (y) => y.tumSiparisleriGorme,
  'siparisAcma': (y) => y.siparisAcma,
  'siparisIptal': (y) => y.siparisIptal,
  'gecmisTeslimatlariGorme': (y) => y.gecmisTeslimatlariGorme,
  'rotaCalistir': (y) => y.rotaCalistir,
  'atama': (y) => y.atama,
  'tahsilat': (y) => y.tahsilat,
  'iskonto': (y) => y.iskonto,
  'musteriBorcSilme': (y) => y.musteriBorcSilme,
  'sahaGideri': (y) => y.sahaGideri,
  'toplamBorclulariGorme': (y) => y.toplamBorclulariGorme,
  'gunSonu': (y) => y.gunSonu,
  'gunuKapatma': (y) => y.gunuKapatma,
  'gecmisHesapArsivi': (y) => y.gecmisHesapArsivi,
  'defterDuzeltme': (y) => y.defterDuzeltme,
  'musteriDuzenleme': (y) => y.musteriDuzenleme,
  'musteriYonetimi': (y) => y.musteriYonetimi,
  'telefonMaskeleme': (y) => y.telefonMaskeleme,
  'musteriGecmisDefteri': (y) => y.musteriGecmisDefteri,
  'borcHatirlatma': (y) => y.borcHatirlatma,
  'urunYonetimi': (y) => y.urunYonetimi,
  'stokPasifleme': (y) => y.stokPasifleme,
  'cagriGunlugu': (y) => y.cagriGunlugu,
  'muafTelefonYonetimi': (y) => y.muafTelefonYonetimi,
  'isletmeAbonelikAyarlari': (y) => y.isletmeAbonelikAyarlari,
  'cihazAyarlari': (y) => y.cihazAyarlari,
};

/// Bayi anahtarı → açtığı yetki. Ekrandaki 13 kutucuğun ürün karşılığı.
const _anahtarEslemesi = <String, String>{
  'musteri': 'musteriDuzenleme',
  'siparis': 'siparisAcma',
  'tahsilat': 'tahsilat',
  'iskonto': 'iskonto',
  'gunSonu': 'gunSonu',
  'tumSiparisler': 'tumSiparisleriGorme',
  'gecmisTeslimatlar': 'gecmisTeslimatlariGorme',
  'sahaGideri': 'sahaGideri',
  'telefonMaskeleme': 'telefonMaskeleme',
  'musteriGecmisDefteri': 'musteriGecmisDefteri',
  'borcHatirlatma': 'borcHatirlatma',
  'stokPasifleme': 'stokPasifleme',
  'cagriGunlugu': 'cagriGunlugu',
};

Map<String, bool> _kume(RolYetkileri y) =>
    {for (final e in _okuyucular.entries) e.key: e.value(y)};

const _hepsiKapali = KuryeIzinleri(
  musteri: false,
  siparis: false,
  tahsilat: false,
  iskonto: false,
  gunSonu: false,
  tumSiparisler: false,
  gecmisTeslimatlar: false,
  sahaGideri: false,
  telefonMaskeleme: false,
  musteriGecmisDefteri: false,
  borcHatirlatma: false,
  stokPasifleme: false,
  cagriGunlugu: false,
);

const _hepsiAcik = KuryeIzinleri(
  musteri: true,
  siparis: true,
  tahsilat: true,
  iskonto: true,
  gunSonu: true,
  tumSiparisler: true,
  gecmisTeslimatlar: true,
  sahaGideri: true,
  telefonMaskeleme: true,
  musteriGecmisDefteri: true,
  borcHatirlatma: true,
  stokPasifleme: true,
  cagriGunlugu: true,
);

/// Hepsi kapalı + [anahtar] açık.
KuryeIzinleri _tekAnahtar(String anahtar) => _kur((a) => a == anahtar);

/// Hepsi açık + [anahtar] kapalı.
KuryeIzinleri _tekAnahtarHaric(String anahtar) => _kur((a) => a != anahtar);

/// 13 anahtarı adına bakan bir yüklemle kurar — 13 ayrı `copyWith` yazmadan tek yerde.
KuryeIzinleri _kur(bool Function(String anahtar) deger) => KuryeIzinleri(
      musteri: deger('musteri'),
      siparis: deger('siparis'),
      tahsilat: deger('tahsilat'),
      iskonto: deger('iskonto'),
      gunSonu: deger('gunSonu'),
      tumSiparisler: deger('tumSiparisler'),
      gecmisTeslimatlar: deger('gecmisTeslimatlar'),
      sahaGideri: deger('sahaGideri'),
      telefonMaskeleme: deger('telefonMaskeleme'),
      musteriGecmisDefteri: deger('musteriGecmisDefteri'),
      borcHatirlatma: deger('borcHatirlatma'),
      stokPasifleme: deger('stokPasifleme'),
      cagriGunlugu: deger('cagriGunlugu'),
    );
