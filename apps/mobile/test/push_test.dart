// PUSH — sunucudan gelen dürtünün çözümü ve ön plan davranışı.
//
// Bu dosya Firebase'e HİÇ DOKUNMAZ: `PushServisi` bağımlılıklarını kanca olarak alır ve
// `onPlandaMesaj` doğrudan çağrılabilir. Platform kanalına uzanan bir widget'ın dosyanın
// TÜM testlerini düşürdüğü bu depoda ödenmiş bir derstir (bkz. `bildirim_ayar_bolumu.dart`
// başlığı); push katmanı o yüzden baştan kancalı tasarlandı.

import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/bildirim/bildirim_sozlesmesi.dart';
import 'package:sipario/bildirim/push/push_servisi.dart';
import 'package:sipario/bildirim/push/push_sozlesmesi.dart';

void main() {
  group('pushMesajiCoz — yükün çözümü', () {
    test('geçerli yük çözülür', () {
      final m = pushMesajiCoz({
        'olay': 'siparis_atandi',
        'id': 'sip-1',
        'kategori': 'siparis_atandi',
      });

      expect(m, isNotNull);
      expect(m!.kategori, BildirimKategori.siparisAtandi);
      expect(m.varlikId, 'sip-1');
    });

    test('bozuk/eksik yük null döner, ATMAZ', () {
      // Bu kod arka planda, kullanıcının göremeyeceği bir bağlamda koşar. Çökmek yerine
      // sessizce atlamak doğrudur: dürtüyü anlamayan istemci veriyi senkronla yine alır.
      expect(pushMesajiCoz(null), isNull);
      expect(pushMesajiCoz({}), isNull);
      expect(pushMesajiCoz({'kategori': 'siparis_atandi'}), isNull, reason: 'id yok');
      expect(pushMesajiCoz({'id': 'x'}), isNull, reason: 'kategori yok');
      expect(pushMesajiCoz({'kategori': 'zort', 'id': 'x'}), isNull);
      expect(pushMesajiCoz({'kategori': 'siparis_atandi', 'id': '   '}), isNull);
    });

    test('YEREL kategoriler sunucudan gelemez (beyaz liste)', () {
      // Gün sonu özeti, borç eşiği … telefonun KENDİ kurallarınındır. Sunucudan böyle bir
      // dürtü gelmesi ya bir hatadır ya kötü niyetli bir yüktür; ikisinde de doğru davranış
      // yok saymaktır.
      for (final k in [
        BildirimKategori.gunSonuOzeti,
        BildirimKategori.sistem,
      ]) {
        expect(pushMesajiCoz({'kategori': k.wire, 'id': 'x'}), isNull,
            reason: '${k.wire} sunucudan itilemez');
        expect(pushIleGelebilir(k), isFalse);
      }
    });
  });

  group('pushTaslagi — bildirim metni TELEFONDA üretilir', () {
    test('ayrıntı yoksa jenerik ama doğru metin çıkar', () {
      final t = pushTaslagi(
        const PushMesaji(kategori: BildirimKategori.siparisAtandi, varlikId: 's1'),
      );

      expect(t.baslik, 'Yeni sipariş');
      expect(t.govde, 'Size bir sipariş atandı');
      expect(t.yol, 'siparisler');
    });

    test('ayrıntı varsa gövdeye girer, BAŞLIK NÖTR kalır', () {
      // Bildirim rafında bir bakışta okunan şey başlıktır ve telefon birine uzatıldığında
      // yanındaki onu görür; müşteri adı gövdede kalmalı.
      final t = pushTaslagi(
        const PushMesaji(kategori: BildirimKategori.siparisAtandi, varlikId: 's1'),
        ayrinti: 'Ayşe Yılmaz',
      );

      expect(t.baslik, 'Yeni sipariş', reason: 'başlıkta müşteri adı OLMAMALI');
      expect(t.govde, contains('Ayşe Yılmaz'));
    });

    test('aynı varlığın ikinci dürtüsü aynı kimliği taşır (üzerine yazar)', () {
      // Sunucu aynı siparişi iki kez atarsa bayi iki satır değil bir satır görmeli; ayrıca
      // günlük bütçeden ikinci kez düşülmemeli.
      final a = pushTaslagi(
        const PushMesaji(kategori: BildirimKategori.siparisAtandi, varlikId: 's1'),
      );
      final b = pushTaslagi(
        const PushMesaji(kategori: BildirimKategori.siparisAtandi, varlikId: 's1'),
        ayrinti: 'Ayşe Yılmaz',
      );

      expect(a.kimlik, b.kimlik);
      expect(a.kimlik, bildirimKimligi(BildirimKategori.siparisAtandi, 's1'));
    });

    test('kasa devri gün sonuna götürür', () {
      final t = pushTaslagi(
        const PushMesaji(kategori: BildirimKategori.kasaDevri, varlikId: 'k1'),
      );

      expect(t.yol, 'gunsonu');
      expect(bildirimYoluCoz(t.yol), (tur: 'gunsonu', id: null));
    });

    test('sipariş yolu kabuk tarafından çözülebilir', () {
      // Taşınan ama tüketilemeyen `yol` bu depoda bir kez yaşandı (bildirime dokunmak ana
      // ekranı açıyordu). Sözlük ile kabuk aynı tanıma bakmalı.
      expect(bildirimYoluCoz('siparisler'), (tur: 'siparisler', id: null));
    });
  });

  group('PushServisi.onPlandaMesaj — sıra ve bağımsızlık', () {
    test('ÖNCE senkron, SONRA bildirim', () async {
      final sira = <String>[];
      final bildirim = SahteBildirimServisi();

      final servis = PushServisi(
        senkronKos: () async => sira.add('senkron'),
        jetonBildir: (_) async {},
        bildirim: bildirim,
      );

      await servis.onPlandaMesaj({'kategori': 'siparis_atandi', 'id': 's1'});

      expect(sira, ['senkron']);
      expect(bildirim.gosterilenler, hasLength(1));
      expect(bildirim.gosterilenler.single.kategori, BildirimKategori.siparisAtandi);
    });

    test('kategori KAPALIYSA bildirim çizilmez ama SENKRON YİNE KOŞAR', () async {
      // "Bu bildirimi istemiyorum" ile "verim gelmesin" aynı şey değildir. İkisini birbirine
      // bağlamak, bildirimi kısan bayinin siparişlerinin de geç gelmesi demekti.
      var senkronKostu = false;
      final bildirim = SahteBildirimServisi(
        kapaliKategoriler: {BildirimKategori.siparisAtandi},
      );

      final servis = PushServisi(
        senkronKos: () async => senkronKostu = true,
        jetonBildir: (_) async {},
        bildirim: bildirim,
      );

      await servis.onPlandaMesaj({'kategori': 'siparis_atandi', 'id': 's1'});

      expect(senkronKostu, isTrue);
      expect(bildirim.gosterilenler, isEmpty);
    });

    test('senkron patlarsa bildirim YİNE gösterilir', () async {
      // Dürtünün haber verdiği olay GERÇEKTİR; yalnız ayrıntısı eksik kalır.
      final bildirim = SahteBildirimServisi();

      final servis = PushServisi(
        senkronKos: () async => throw Exception('ağ yok'),
        jetonBildir: (_) async {},
        bildirim: bildirim,
      );

      await servis.onPlandaMesaj({'kategori': 'siparis_teslim', 'id': 's9'});

      expect(bildirim.gosterilenler, hasLength(1));
      expect(bildirim.gosterilenler.single.baslik, 'Teslim edildi');
    });

    test('ayrıntı okuma patlarsa bildirim jenerik metinle çıkar', () async {
      final bildirim = SahteBildirimServisi();

      final servis = PushServisi(
        senkronKos: () async {},
        jetonBildir: (_) async {},
        ayrintiOku: (_) async => throw Exception('db kilitli'),
        bildirim: bildirim,
      );

      await servis.onPlandaMesaj({'kategori': 'siparis_atandi', 'id': 's1'});

      expect(bildirim.gosterilenler.single.govde, 'Size bir sipariş atandı');
    });

    test('tanınmayan yükte hiçbir şey yapılmaz — senkron bile', () async {
      // Bozuk/yabancı yük bir iş sinyali değildir; senkron koşturmak, kötü niyetli bir
      // yükün cihazı meşgul etmesine kapı açardı.
      var senkronKostu = false;
      final bildirim = SahteBildirimServisi();

      final servis = PushServisi(
        senkronKos: () async => senkronKostu = true,
        jetonBildir: (_) async {},
        bildirim: bildirim,
      );

      await servis.onPlandaMesaj({'kategori': 'gun_sonu_ozeti', 'id': 'x'});

      expect(senkronKostu, isFalse);
      expect(bildirim.gosterilenler, isEmpty);
    });
  });

  group('sipariş iptali — kurye yolda olabilir', () {
    test('BAŞLIK burada nötr DEĞİL: kurye ne olduğunu görmeli', () {
      // Diğer bildirimlerde başlık nötrdür (kilit ekranı kuralı). Burada nötr bir başlık
      // kuryeye hiçbir şey söylemez ve o yola çıkar; "iptal" sözcüğü müşteri adı taşımadığı
      // için kural da çiğnenmiş olmaz.
      final t = pushTaslagi(
        const PushMesaji(kategori: BildirimKategori.siparisIptal, varlikId: 's1'),
      );

      expect(t.baslik, 'Sipariş iptal edildi');
      expect(t.detay, contains('gitmeyin'));
    });

    test('müşteri adı ve adres varsa ikisi de kullanılır', () {
      final t = pushTaslagi(
        const PushMesaji(kategori: BildirimKategori.siparisIptal, varlikId: 's1'),
        ayrinti: 'Ayşe Yılmaz',
        detaySatiri: 'Bahçelievler Mah. 12/4',
      );

      // Ad GÖVDEDE (daraltılmış hâlde görünür), adres yalnız DETAYDA (genişletilince).
      expect(t.govde, contains('Ayşe Yılmaz'));
      expect(t.govde, isNot(contains('Bahçelievler')));
      expect(t.detay, contains('Bahçelievler'));
    });
  });

  group('yeni cihaz — güvenlik bildirimi', () {
    test('ne yapılacağını SÖYLER ve cihazlar ekranına götürür', () {
      // Uyarıp yalnız bırakmak işe yaramaz: bayi "ne yapacağım?" diye kalırsa uyarı
      // endişeden başka bir şey üretmez.
      final t = pushTaslagi(
        const PushMesaji(kategori: BildirimKategori.yeniCihaz, varlikId: 'c1'),
      );

      expect(t.detay, contains('parolanızı değiştirin'));
      expect(bildirimYoluCoz(t.yol), (tur: 'cihazlar', id: null));
    });

    test('ayrıntı verilse bile metin DEĞİŞMEZ — cihaz bilgisi yükte taşınmaz', () {
      final a = pushTaslagi(
        const PushMesaji(kategori: BildirimKategori.yeniCihaz, varlikId: 'c1'),
      );
      final b = pushTaslagi(
        const PushMesaji(kategori: BildirimKategori.yeniCihaz, varlikId: 'c1'),
        ayrinti: 'Redmi Note 12',
      );

      expect(a.govde, b.govde);
    });
  });

  group('kanal ayarları — ilk doğuşta donar, o yüzden testle kilitli', () {
    test('heads-up YALNIZ üç kategoride', () {
      // Cömert değil cimri dağıtılır: heads-up işi böler. Bu listeyi büyütmek, bayinin bir
      // hafta içinde bildirimlerin TAMAMINI kapatmasına giden yoldur.
      final acik = BildirimKategori.values.where((k) => k.headsUp).toSet();

      expect(acik, {
        BildirimKategori.siparisAtandi,
        BildirimKategori.siparisIptal,
        BildirimKategori.yeniCihaz,
      });
    });

    test('HER kategorinin sesi var ve DOKUZU DA FARKLI', () {
      // 2026-08-18 (kullanıcı isteği): önceden yalnız atama ve iptal ayırt ediliyordu, kalan
      // yedi kategori sistem varsayılanını çalıyordu — yani "sipariş iptal edildi" ile "gün
      // özeti hazır" kulakta AYNI sesti. Sesin var olma sebebi bildirimi GÖRMEMEK olduğuna
      // göre, ayırt etmeyen ses hiç ses olmamasıyla aynı kapıya çıkar.
      //
      // ⚠️ BU TEST BENZERSİZLİĞİ KİLİTLER, GÜZELLİĞİ DEĞİL: iki kategoriye aynı dosyayı
      // vermek (kopyala-yapıştır sırasında en olası hata) burada düşer.
      final sesler = {for (final k in BildirimKategori.values) k: k.ses};

      for (final girdi in sesler.entries) {
        expect(girdi.value, isNotEmpty, reason: '${girdi.key.wire} sessiz kalmış');
        expect(girdi.value, matches(RegExp(r'^[a-z0-9_]+$')),
            reason: 'res/raw kuralı: yalnız küçük harf, rakam, alt çizgi — '
                'büyük harf ya da tire Android kaynak derleyicisini kırar');
      }

      expect(sesler.values.toSet().length, BildirimKategori.values.length,
          reason: 'iki kategori aynı dosyayı paylaşıyor — ayırt edicilik kaybolur');
    });

    test('kanal kimliği SÜRÜMLÜ, wire ise ÇIPLAK — ikisi karıştırılamaz', () {
      // Sesi değiştirmenin tek yolu yeni kanal kimliğidir (Android var olan kanalın sesini
      // uygulamanın değiştirmesine izin vermez). `wire` ise sunucu sözleşmesidir ve
      // sürümlenemez. İkisi tek alana indirgenirse, ses değiştirmenin bedeli push
      // sözleşmesini kırmak olur.
      for (final k in BildirimKategori.values) {
        expect(k.kanalKimligi, '${k.wire}_v2');
        expect(k.kanalKimligiV1, k.wire, reason: 'v1 yalnız SİLİNMEK için durur');
        expect(k.kanalKimligi, isNot(k.kanalKimligiV1));
      }
    });
  });

  group('kategori sözleşmesi', () {
    test('wire değerleri SUNUCUYLA aynı — değişmez', () {
      // `app/Bildirim/PushOlayi.php` ile birebir. Değiştirmek, sahadaki eski istemcinin
      // dürtüyü tanımaması demektir (telefonlar günlerce eski sürümde kalır).
      expect(BildirimKategori.siparisAtandi.wire, 'siparis_atandi');
      expect(BildirimKategori.siparisIptal.wire, 'siparis_iptal');
      expect(BildirimKategori.siparisTeslim.wire, 'siparis_teslim');
      expect(BildirimKategori.kasaDevri.wire, 'kasa_devri');
      expect(BildirimKategori.yeniCihaz.wire, 'yeni_cihaz');
    });

    test('teslim ve kasa devri YALNIZ yöneticiye anlamlı', () {
      // Ayar ekranı bununla süzülür: kuryede kapatınca da açınca da hiçbir şey değişmeyen
      // bir anahtar, ayarların tamamına olan güveni bozar.
      expect(BildirimKategori.siparisTeslim.yalnizYonetici, isTrue);
      expect(BildirimKategori.kasaDevri.yalnizYonetici, isTrue);
      expect(BildirimKategori.siparisAtandi.yalnizYonetici, isFalse,
          reason: 'atama bildiriminin ASIL alıcısı kuryedir');
    });
  });
}
