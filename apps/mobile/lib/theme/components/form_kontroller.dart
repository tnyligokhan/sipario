// FORM KONTROLLERİ — segment · anahtar (toggle) · onay kutusu · döner düğme (knob).
//
// NEDEN AYRI DOSYA: `form.dart` 512 satıra çıkmıştı (500 satır kuralı). Bölme çizgisi anlamlı:
// `form.dart`ta METİN GİRİŞİ kalanlar var (etiket · input · arama), burada ise DEĞER SEÇİMİ
// yapan kontroller. İkisi farklı sorulara cevap verir — "ne yazıyorsun?" ile "hangisi?".
//
// SÖZLEŞME KORUNDU: `form.dart` bu dosyayı yeniden dışa aktarır, yani mevcut
// `import '../theme/components/form.dart'` yolları ve testler aynen çalışır.

import 'package:flutter/material.dart';

import '../icons.dart';
import '../tokens.dart';
import '../typography.dart';
import 'dokunma.dart';
import 'form.dart' show SipInputOlcu;


/// CSS `.segtab` — surface-2 ray üzerinde hero dolgulu seçim.
class SipSegment extends StatelessWidget {
  const SipSegment({
    super.key,
    required this.secenekler,
    required this.secili,
    required this.onSec,
  });

  /// Sırayla gösterilecek etiketler.
  final List<String> secenekler;

  /// [secenekler] içindeki dizin.
  final int secili;

  final ValueChanged<int> onSec;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.surface2,
        borderRadius: SipRadius.brHap,
      ),
      child: Row(
        children: [
          for (var i = 0; i < secenekler.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSec(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == secili ? t.hero : Colors.transparent,
                      borderRadius: SipRadius.brHap,
                    ),
                    child: Text(
                      secenekler[i],
                      style: SipText.metin(
                        12.5,
                        w: i == secili ? 700 : 600,
                      ).copyWith(
                        color: i == secili ? SipTokens.onHero : t.muted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// CSS `.aktif-toggle` + `.aktif-knob` — etiketli açma/kapama satırı.
class SipToggle extends StatelessWidget {
  const SipToggle({
    super.key,
    required this.etiket,
    required this.acik,
    required this.onDegis,
    this.ikon,
    this.altEtiket,
  });

  final String etiket;
  final bool acik;
  final ValueChanged<bool> onDegis;
  final String? ikon;
  final String? altEtiket;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipDokun(
      onTap: () => onDegis(!acik),
      zemin: t.surface2,
      radius: SipRadius.br2,
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: SipSpace.xl),
      child: Row(
        children: [
          if (ikon != null) ...[
            SipIcon(ikon!, boyut: 18, kalinlik: 2, renk: t.ink2),
            const SizedBox(width: 11),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etiket, style: SipText.gsSatirEtiket.copyWith(color: t.ink2)),
                if (altEtiket != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      altEtiket!,
                      style: SipText.yardimci.copyWith(color: t.muted),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: SipSpace.lg),
          SipKnob(acik: acik),
        ],
      ),
    );
  }
}

/// Etiketli onay kutusu — kare kutu + tik, yanında metin.
///
/// NEDEN [SipToggle] DEĞİL: o, dolgulu bir SATIR (surface-2 zemin, 46 px, sağda ray-topuz) ve
/// bir AYAR ekranının dilidir — "bu özellik açık mı?". Giriş formunda aynı ağırlıkta bir blok,
/// yanındaki üç girdi kutusuyla görsel olarak yarışır ve "Giriş Yap" düğmesinden önce gözün
/// takıldığı en büyük öğe olurdu. Onay kutusu formun kendi diline aittir: tercihi TAŞIR ama
/// hiyerarşide girdilerin altında kalır.
///
/// Dokunma hedefi kutunun kendisi değil TÜM SATIRDIR (18 px'lik bir kareyi parmakla vurmak
/// erişilebilirlik eşiğinin altındadır); dikey dolgu hedefi ~40 px'e çıkarır.
class SipOnayKutusu extends StatelessWidget {
  const SipOnayKutusu({
    super.key,
    required this.etiket,
    required this.isaretli,
    required this.onDegis,
    this.aktif = true,
  });

  final String etiket;
  final bool isaretli;
  final ValueChanged<bool> onDegis;
  final bool aktif;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipDokun(
      onTap: aktif ? () => onDegis(!isaretli) : null,
      radius: SipRadius.br2,
      padding: const EdgeInsets.symmetric(vertical: SipSpace.md),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isaretli ? t.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isaretli ? t.accent : t.line2,
                width: SipInputOlcu.kenarKalinlik,
              ),
            ),
            // Tik İŞARETLİYKEN de ağaçta durur (opaklıkla gizlenir): kutunun boyutu
            // çocuğun varlığına göre değişmesin, satır işaretlenirken zıplamasın.
            child: Opacity(
              opacity: isaretli ? 1 : 0,
              child: SipIcon(SipIcons.check, boyut: 13, kalinlik: 3, renk: t.accentInk),
            ),
          ),
          const SizedBox(width: 9),
          Text(
            etiket,
            style: SipText.metin(13, w: 600).copyWith(color: aktif ? t.ink2 : t.muted),
          ),
        ],
      ),
    );
  }
}

/// CSS `.aktif-knob` — 40×24 ray, 20 topuz.
class SipKnob extends StatelessWidget {
  const SipKnob({super.key, required this.acik, this.kapaliZemin});

  final bool acik;

  /// KAPALI hâlin ray rengi; verilmezse `t.line2` (açık yüzey kartları için doğru olan).
  ///
  /// NEDEN GEREKLİ (2026-08-13): anahtar artık ÇEKMECEDE de çiziliyor ve orası koyu `hero`
  /// zeminidir. `line2` açık yüzeyler için ayarlanmış bir ayraç tonudur; koyu zeminde ray ile
  /// arka plan neredeyse aynı renge düşüyor ve KAPALI anahtar "yok" gibi okunuyordu — yani
  /// kullanıcı kapalı bir kontrolü değil, hiç olmayan bir kontrolü görüyordu. Çağıran kendi
  /// zeminine uygun tonu verir (çekmecede `SipTokens.onHeroFill2`).
  final Color? kapaliZemin;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 40,
      height: 24,
      decoration: BoxDecoration(
        color: acik ? t.accent : (kapaliZemin ?? t.line2),
        borderRadius: SipRadius.brHap,
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        alignment: acik ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: t.knob,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x38000000),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

