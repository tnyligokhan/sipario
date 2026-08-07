import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/screens/team.dart';

/// KURYE YETKİLERİ — bayinin açıp kapattığı beş anahtarın karar matrisi (kullanıcı isteği
/// 2026-08-04). K2 matrisinin devamı: ekrandan bağımsız, tek saf fonksiyonda.
void main() {
  group('yetkiler() — kurye anahtarları', () {
    test('varsayılan: kurye müşteri/sipariş/tahsilat yapar, iskonto ve gün sonu KAPALI', () {
      // Varsayılanlar saha gerçeğinden gelir: işini yapamayan kurye ürünü kullanılmaz kılar;
      // para kırma ve kasa özeti ise patron kararıdır.
      final k = yetkiler(rol: 'kurye', kuryeVar: true);
      expect(k.musteriDuzenleme, isTrue);
      expect(k.siparisAcma, isTrue);
      expect(k.tahsilat, isTrue);
      expect(k.iskonto, isFalse);
      expect(k.gunSonu, isFalse);
    });

    test('bayi kapatınca kurye o işi yapamaz', () {
      const kapali = KuryeIzinleri(
        musteri: false,
        siparis: false,
        tahsilat: false,
        iskonto: false,
        gunSonu: false,
      );
      final k = yetkiler(rol: 'kurye', kuryeVar: true, izin: kapali);
      expect(k.musteriDuzenleme, isFalse);
      expect(k.siparisAcma, isFalse);
      expect(k.tahsilat, isFalse);
      expect(k.iskonto, isFalse);
      expect(k.gunSonu, isFalse);
    });

    test('bayi açınca kurye iskonto ve gün sonu görebilir', () {
      const acik = KuryeIzinleri(iskonto: true, gunSonu: true);
      final k = yetkiler(rol: 'kurye', kuryeVar: true, izin: acik);
      expect(k.iskonto, isTrue);
      expect(k.gunSonu, isTrue);
    });

    test('YÖNETİCİ ayardan ETKİLENMEZ — bayi kendini kilitleyemez', () {
      // Kapıyı yöneticiye de uygulasaydık, bayi tüm anahtarları kapatıp yetkileri geri açacağı
      // ekranı da kendine kapatabilirdi (ve o ekran kilidin arkasında kalırdı).
      const hepsiKapali = KuryeIzinleri(
        musteri: false,
        siparis: false,
        tahsilat: false,
        iskonto: false,
        gunSonu: false,
      );
      for (final rol in ['patron', 'operator']) {
        final y = yetkiler(rol: rol, kuryeVar: true, izin: hepsiKapali);
        expect(y.musteriDuzenleme, isTrue, reason: '$rol müşteri düzenleyebilmeli');
        expect(y.siparisAcma, isTrue, reason: '$rol sipariş açabilmeli');
        expect(y.tahsilat, isTrue, reason: '$rol tahsilat alabilmeli');
        expect(y.iskonto, isTrue, reason: '$rol iskonto yapabilmeli');
        expect(y.gunSonu, isTrue, reason: '$rol gün sonunu görebilmeli');
      }
    });

    test('eski K2 kuralları bozulmadı: ürün/defter düzeltme/atama yalnız yöneticide', () {
      const hepsiAcik = KuryeIzinleri(
        musteri: true,
        siparis: true,
        tahsilat: true,
        iskonto: true,
        gunSonu: true,
      );
      // Anahtarların HEPSİ açık olsa bile bunlar kuryeye AÇILMAZ: on/off kümesi bilinçli olarak
      // dardır (ayar felci) ve bu üçü patronun kendi işidir.
      final k = yetkiler(rol: 'kurye', kuryeVar: true, izin: hepsiAcik);
      expect(k.urunYonetimi, isFalse);
      expect(k.defterDuzeltme, isFalse);
      expect(k.musteriYonetimi, isFalse, reason: 'silme/kara liste kuryeye açılmaz');
      expect(k.atama, isFalse);
    });

    test('izin null geçilirse varsayılan kullanılır (ayar henüz senkronla gelmedi)', () {
      // O karede kuryeyi işinden etmek yanlış olurdu.
      expect(yetkiler(rol: 'kurye', kuryeVar: true, izin: null).tahsilat, isTrue);
    });
  });

  group('kuryeIzinleriOku', () {
    test('ayar satırı yoksa varsayılana düşer', () {
      final i = kuryeIzinleriOku(null);
      expect(i.musteri, isTrue);
      expect(i.siparis, isTrue);
      expect(i.tahsilat, isTrue);
      expect(i.iskonto, isFalse);
      expect(i.gunSonu, isFalse);
    });
  });
}
