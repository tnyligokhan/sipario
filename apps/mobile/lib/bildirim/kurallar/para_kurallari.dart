// PARA / VERESİYE bildirim kuralları. Tek kural kaldı: GÜN SONU ÖZETİ.
//
// ⚠️ KALDIRILANLAR (kullanıcı kararı 2026-08-14): borç eşiği aşımı · vadesi geçen borçlar.
// Bunlar teknik olarak çalışıyordu (FIFO alacak yaşlandırması dahil) ama ürünün istemediği
// bildirimlerdi. Gerekçe DECISIONS'ta; kod SİLİNDİ, bayrak arkasına alınmadı — çağrılmayan
// bir dalı testin yeşil tutması, bu depoda daha önce ölü kod olarak adlandırıldı.
//
// BU DOSYA SAFTIR: veritabanı okumaz, saat okumaz, bildirim göstermez. Girdi olarak değer alır,
// çıktı olarak taslak döner. Okuma katmanı `DayEndRepository`dedir.
//
// PARA: her yerde int kuruş; gösterime çevirme YALNIZ `formatKurus` üzerinden (DECISIONS: kayan
// nokta yok, kuruş farkı ürüne güveni öldürür). Bildirimdeki rakam bayinin gün sonu EKRANINDA
// gördüğü rakamla aynı kaynaktan gelir (DayEndRepository) — iki yüzey farklı sayı konuşamaz.
//
// KİLİT EKRANI: `govde` GİZLENİR, `baslik` GÖRÜNÜR. Para tutarı yalnız GÖVDEDE geçer; başlık
// nötrdür ("Gün özeti"), çünkü kilit ekranını başkası görebilir.

import '../../theme/components/bicim.dart' show sipTutar;
import '../bildirim_sozlesmesi.dart';

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Varsayılan zamanlama
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Gün sonu özeti saati. 20:00 önerisi: su/tüp bayiinde akşam teslimatları biter, kasa sayılır;
/// bildirim bayinin elindeki defterle karşılaştırma yapacağı ana denk gelmeli. Daha erken atarsa
/// akşam teslimatları rakamın dışında kalır ve "tutmuyor" hissi doğar — bu üründe en pahalı his.
const int kGunSonuSaati = 20;

// ═══════════════════════════════════════════════════════════════════════════════════════════
// GÜN SONU ÖZETİ
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Gün sonu kuralının girdisi — üç rakam, hepsi TR takvim gününe göre (`DayEndRepository`).
class GunSonuVerisi {
  const GunSonuVerisi({
    required this.gun,
    required this.tahsilatKurus,
    required this.teslimatSayisi,
    required this.veresiyeKurus,
  });

  /// TR takvim günü (yerel tarih; saat kısmı kullanılmaz).
  final DateTime gun;

  /// KASAYA GİREN para (nakit+kart+havale). Bayinin fiziksel olarak sayacağı tutar budur —
  /// eski borç tahsilatı da dâhildir, çünkü o para da bugün kasaya girdi.
  final int tahsilatKurus;

  /// Teslim edilen sipariş sayısı (iptaller hariç).
  final int teslimatSayisi;

  /// BUGÜN YAZILAN net yeni borç: günün `debit` toplamı − günün SİPARİŞ BAĞLI tahsilatı.
  /// Sipariş dışı tahsilat (eski borcun ödenmesi) buradan DÜŞÜLMEZ; o bugün yazılmış bir
  /// veresiyeyi kapatmaz ve düşülseydi "bugün ne kadar veresiye verdim" sorusu yanlış cevaplanırdı.
  final int veresiyeKurus;

  /// Hiç hareket yoksa bildirim atılmaz — boş bildirim gürültüdür ve bir sonrakinin okunma
  /// ihtimalini düşürür.
  bool get bosGun => tahsilatKurus == 0 && teslimatSayisi == 0 && veresiyeKurus == 0;
}

/// Gün sonu özeti bildirimi. Boş günde `null`.
///
/// HANGİ ÜÇ RAKAM VE NEDEN: bayinin akşam yaptığı iş üç sorunun cevabıdır — (1) kasada ne kadar
/// para olmalı, (2) kaç iş yaptım, (3) ne kadarını veresiye verdim. Dördüncü bir rakam (toplam
/// açık borç) eklenmedi: o günlük değil BİRİKİMLİ bir büyüklüktür ve her akşam tekrarlanınca
/// anlamını yitirir.
BildirimTaslagi? gunSonuOzeti(GunSonuVerisi v) {
  if (v.bosGun) return null;
  return BildirimTaslagi(
    kategori: BildirimKategori.gunSonuOzeti,
    // Nötr başlık: rakamlar kilit ekranında görünmesin. Ad EKRANLA AYNI olmak zorunda
    // (kullanıcı kararı 2026-08-06): çekmece "Gün Özeti" derken bildirim başka bir ad söylerse
    // bayi iki ayrı özellik olduğunu sanar. Kanal kimliği (`wire`) DEĞİŞMEDİ.
    baslik: 'Gün özeti',
    govde: 'Bugün ${v.teslimatSayisi} teslimat yaptınız, '
        '${sipTutar(v.tahsilatKurus)} tahsil ettiniz ve '
        '${sipTutar(v.veresiyeKurus)} veresiye yazdınız.',
    // Günde TEK özet: ayırt edici TR takvim günü. İki kez tetiklense (yeniden başlatma,
    // zamanlayıcı çakışması) aynı kimlik üzerine yazılır, ikinci bildirim doğmaz.
    kimlik: bildirimKimligi(BildirimKategori.gunSonuOzeti, bildirimGunAnahtari(v.gun)),
    yol: 'gunsonu',
  );
}
