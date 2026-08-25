// ÜRÜN İÇERİKLERİ — "bu işletmede hazırlanan ürün var mı?" (kullanıcı eleştirisi 2026-08-18).
//
// ══ NEDEN VAR ══════════════════════════════════════════════════════════════════════════════
// Bu uygulamayı ÇOK FARKLI işletmeler kullanır: su bayii, tüp bayii, market, dönerci, tostçu.
// "İçindekiler" özelliği ilk sürümde HER ürün formunda koşulsuz çiziliyordu ve kullanıcı haklı
// olarak itiraz etti: *"su bayisinde içindekiler göstermek çok mantıklı değil"*. Bu satır o
// özelliğin kiracı düzeyindeki anahtarıdır.
//
// ══ NEDEN "İŞLETME TÜRÜ" SEÇİMİ DEĞİL ══════════════════════════════════════════════════════
// Tek bir tür etiketi ("market" / "dönerci") bu ürünü tarif EDEMEZ. Kullanıcının kendi örneği
// bunu kanıtlıyor: *"küçük bir bakkal olabilir ama aynı zamanda tost yapıyor olabilir"*. Tür bir
// ETİKETTİR; ekranların davranışını belirleyen şey YETENEKTİR. İleride gelecek kurulum sihirbazı
// "işletmen ne, neler satıyorsun?" diye soracak ve cevaptan bu yeteneği TÜRETECEK — ekranlar
// yine türü değil yeteneği okuyacak. Türü doğrudan okuyan bir ekran, bakkal-tost hâlinde
// kaçınılmaz olarak yanlış karar verirdi.
//
// ⚠️ SİHİRBAZ GELDİĞİNDE BU SATIR KALDIRILMAZ. Sihirbaz ilk girişte BİR KEZ sorar; bu satır
// fikir değiştiren bayinin dönebileceği yerdir. Yalnız sihirbazda sorulan bir ayar, kurulumdan
// altı ay sonra tost yapmaya başlayan bakkal için ulaşılamaz olurdu.

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../repo/tenant_settings_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import 'isletme_atomlari.dart';

/// Ayarlar → İşletme → "Ürün içerikleri" satırı.
class HazirlananUrunSatiri extends StatelessWidget {
  const HazirlananUrunSatiri({super.key, required this.db, this.writable = true});

  final AppDatabase db;
  final bool writable;

  Future<void> _degistir(BuildContext context, bool mevcut) async {
    if (!writable) {
      SipToast.goster(context, 'Aboneliğiniz sona erdiği için ayar değiştirilemiyor');
      return;
    }

    // KAPATMA ONAY İSTER, AÇMA İSTEMEZ. Açmak bir şey kaybettirmez (yeni bir bölüm belirir);
    // kapatmak ise bayinin girdiği malzeme listelerini EKRANDAN kaldırır ve "sildim mi?"
    // sorusunu doğurur. Cevabı onay metninde yazılı: silinmez.
    if (mevcut) {
      final onay = await sipOnay(
        context,
        baslik: 'Ürün içerikleri kapatılsın mı?',
        mesaj: 'Ürün formundaki "İçindekiler" bölümü ve sipariş alırken çıkan malzeme '
            'seçenekleri gizlenir. Girdiğiniz listeler silinmez, yeniden açtığınızda '
            'hepsi geri gelir.',
        onayEtiketi: 'Kapat',
        tehlike: true,
      );
      if (!onay || !context.mounted) return;
    }

    await TenantSettingsRepository(db).hazirlananUrunKaydet(!mevcut);
    if (!context.mounted) return;
    SipToast.goster(
      context,
      mevcut
          ? 'Ürün içerikleri kapatıldı'
          : 'Ürün içerikleri açıldı. Ürünü düzenlerken malzeme ekleyebilirsiniz.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: watchHazirlananUrun(db),
      initialData: false,
      builder: (context, snap) {
        final acik = snap.data ?? false;
        return AyarSatiri(
          ikon: SipIcons.box,
          baslik: 'Ürün içerikleri',
          // ALT BAŞLIK DURUMU DEĞİL KİMİN İŞİNE YARADIĞINI söyler (2026-08-18): durumu sağdaki
          // anahtar zaten gösteriyor. Örnek işletmeler bilerek yazıldı — su bayisi bu satırı
          // okuyup kendisine ait olmadığını tek bakışta anlamalı.
          altBaslik: 'Dönerci, tostçu gibi hazırlanan ürünler için',
          onTap: () => _degistir(context, acik),
          // AÇ/KAPA AYARI ANAHTARLA GÖSTERİLİR (kullanıcı isteği 2026-08-18). Chevron, satırın
          // bir sayfa açtığını söyler; oysa burada dokunuş ayarı ÇEVİRİYOR. Yanlış ikon,
          // kullanıcıya yanlış bir söz vermektir.
          sag: SipKnob(acik: acik),
        );
      },
    );
  }
}
