// KURYE YETKİLERİ — Kuryeler ekranının üstündeki beş on/off anahtarı.
// Kullanıcı isteği (2026-08-04): "kuryenin hangi bilgilerde değişiklik yapabileceği … bir on-off
// şeklinde bir şey de olmalı."
//
// AYAR KİRACI DÜZEYİNDEDİR (kurye başına değil) — gerekçe sunucu migration'ında (004002):
// 1–3 kişilik bir bayide kişi bazlı yetki, her yeni kuryede unutulan bir kurulum adımıdır.
//
// YAZMA YOLU MEVCUT: `tenant_settings` LWW upsert'i (outbox → sunucu). Yeni bir senkron varlığı,
// yeni bir çakışma kuralı YOK. Ama bir TUZAK var ve `TenantSettingsRepository.save` sözleşmesi
// gereği burada karşılanıyor: o metot satırın TAMAMINI yazar, yani yalnız bir anahtarı
// değiştirirken profilin geri kalanını (unvan, IBAN, vergi no…) MEVCUT değerinden taşımak
// zorundayız — yoksa bayi bir anahtara dokununca işletme profili boşalırdı.
//
// ANAHTAR ANINDA YAZILIR (Kaydet düğmesi yok): tek bir boolean için form/kaydet döngüsü kurmak,
// esnafın "değişti mi değişmedi mi" diye ikinci kez bakmasına yol açardı. Yazma başarısız olursa
// akış eski değeri geri getirir (Drift satırı tek doğru kaynaktır, ekran onu dinler).

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../repo/tenant_settings_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../team.dart';
import 'isletme_atomlari.dart';

/// Salt-okunur kip uyarısı — Kuryeler ekranının diğer uyarılarıyla aynı dil.
const String yetkiSaltOkunurUyarisi = 'Salt-okunur kip: yetkiler değiştirilemez.';

/// Tek bir yetkinin ekrandaki kimliği: etiket + açıklama + satırdan okuma/yazma.
///
/// Açıklamalar bilerek SONUCU anlatır ("kapıda indirim yapabilir"), alan adını değil: bayi
/// `courier_can_discount` diye düşünmez, "çocuk fiyat kırabilsin mi" diye düşünür.
class KuryeYetkiSatiri {
  const KuryeYetkiSatiri({
    required this.etiket,
    required this.aciklama,
    required this.oku,
    required this.yaz,
  });

  final String etiket;
  final String aciklama;
  final bool Function(KuryeIzinleri) oku;
  final KuryeIzinleri Function(KuryeIzinleri, bool) yaz;
}

/// Ekranda görünen sıra: en sık kullanılan yetki üstte, para kırma en altta (tehlikeli olan
/// yanlışlıkla açılmasın diye göz onu en sonda görür).
const List<KuryeYetkiSatiri> kuryeYetkiSatirlari = [
  KuryeYetkiSatiri(
    etiket: 'Müşteri ekleyip düzenleyebilir',
    aciklama: 'Yeni müşteri kaydı ve adres/telefon düzeltmesi. Silme ve kara liste patrona özeldir.',
    oku: _musteriOku,
    yaz: _musteriYaz,
  ),
  KuryeYetkiSatiri(
    etiket: 'Sipariş oluşturabilir',
    aciklama: 'Sahadan yeni sipariş girer. Kapalıyken yalnız kendine atanan işi teslim eder.',
    oku: _siparisOku,
    yaz: _siparisYaz,
  ),
  KuryeYetkiSatiri(
    etiket: 'Tahsilat alabilir',
    aciklama: 'Borç tahsilatını deftere işler. Kapatırsanız parayı yalnız siz kaydedersiniz.',
    oku: _tahsilatOku,
    yaz: _tahsilatYaz,
  ),
  KuryeYetkiSatiri(
    etiket: 'Gün sonu özetini görebilir',
    aciklama: 'Günün kasa ve teslimat toplamları. Kapalıyken kendi kasa devrini yine yapar.',
    oku: _gunSonuOku,
    yaz: _gunSonuYaz,
  ),
  KuryeYetkiSatiri(
    etiket: 'Kapıda iskonto yapabilir',
    aciklama: 'Teslimde tutarı kırabilir. Kırılan para kasaya girmez, gün sonunda ayrı görünür.',
    oku: _iskontoOku,
    yaz: _iskontoYaz,
  ),
];

// Üst düzey fonksiyonlar: `const` listedeki alanlar sabit olmak zorunda (kapanış/lambda olamaz).
bool _musteriOku(KuryeIzinleri i) => i.musteri;
bool _siparisOku(KuryeIzinleri i) => i.siparis;
bool _tahsilatOku(KuryeIzinleri i) => i.tahsilat;
bool _gunSonuOku(KuryeIzinleri i) => i.gunSonu;
bool _iskontoOku(KuryeIzinleri i) => i.iskonto;

KuryeIzinleri _musteriYaz(KuryeIzinleri i, bool v) => KuryeIzinleri(
    musteri: v, siparis: i.siparis, tahsilat: i.tahsilat, iskonto: i.iskonto, gunSonu: i.gunSonu);
KuryeIzinleri _siparisYaz(KuryeIzinleri i, bool v) => KuryeIzinleri(
    musteri: i.musteri, siparis: v, tahsilat: i.tahsilat, iskonto: i.iskonto, gunSonu: i.gunSonu);
KuryeIzinleri _tahsilatYaz(KuryeIzinleri i, bool v) => KuryeIzinleri(
    musteri: i.musteri, siparis: i.siparis, tahsilat: v, iskonto: i.iskonto, gunSonu: i.gunSonu);
KuryeIzinleri _gunSonuYaz(KuryeIzinleri i, bool v) => KuryeIzinleri(
    musteri: i.musteri, siparis: i.siparis, tahsilat: i.tahsilat, iskonto: i.iskonto, gunSonu: v);
KuryeIzinleri _iskontoYaz(KuryeIzinleri i, bool v) => KuryeIzinleri(
    musteri: i.musteri, siparis: i.siparis, tahsilat: i.tahsilat, iskonto: v, gunSonu: i.gunSonu);

class KuryeYetkiBolumu extends StatelessWidget {
  const KuryeYetkiBolumu({super.key, required this.db, this.writable = true});

  final AppDatabase db;
  final bool writable;

  Future<void> _degistir(
    BuildContext context,
    KuryeIzinleri mevcut,
    KuryeYetkiSatiri satir,
    bool yeni,
  ) async {
    if (!writable) {
      SipToast.goster(context, yetkiSaltOkunurUyarisi);
      return;
    }
    await TenantSettingsRepository(db).kuryeIzinleriKaydet(satir.yaz(mevcut, yeni));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return StreamBuilder<KuryeIzinleri>(
      stream: watchKuryeIzinleri(db),
      initialData: KuryeIzinleri.varsayilan,
      builder: (context, snap) {
        final izin = snap.data ?? KuryeIzinleri.varsayilan;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SipBolumBaslik('Kuryeler Ne Yapabilir', ustBosluk: 0),
            Padding(
              padding: const EdgeInsets.only(top: SipSpace.xs, bottom: SipSpace.sm),
              child: Text(
                'Bu ayarlar TÜM kuryeler için geçerlidir. Patron ve operatör bunlardan etkilenmez.',
                style: SipText.metin(12, w: 600).copyWith(color: t.muted),
              ),
            ),
            for (final satir in kuryeYetkiSatirlari)
              Padding(
                padding: const EdgeInsets.only(top: SipSpace.sm),
                child: AktifToggle(
                  acik: satir.oku(izin),
                  etiket: satir.etiket,
                  altEtiket: satir.aciklama,
                  onDegis: (v) => _degistir(context, izin, satir, v),
                ),
              ),
            const SizedBox(height: SipSpace.xl),
          ],
        );
      },
    );
  }
}
