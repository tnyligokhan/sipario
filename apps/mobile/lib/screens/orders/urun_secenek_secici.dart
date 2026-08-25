// SİPARİŞ ALIRKEN SEÇENEK SEÇİMİ — "soğansız olsun" (kullanıcı isteği 2026-08-18).
//
// NEDEN AYRI DOSYA: `pos_catalog.dart` 455 satırdı (depo sınırı 500) ve bu yüzey oraya sığmıyordu.
// Bölme çizgisi de doğal: katalog ÜRÜN SEÇTİRİR, burası seçilen ürünü TARİF ETTİRİR.
//
// ══ ARAYÜZ KARARLARI — bunlar özelliğin değerinin tamamı ═══════════════════════════════════
//
// 1. TEK DOKUNUŞ, İKİ YÖN. Malzeme çipine dokunmak durumu ters çevirir. "İçinde" olan bir
//    malzeme dokununca ÜSTÜ ÇİZİLİR (çıkarıldı), "ekstra" olan dokununca DOLAR (eklendi).
//    Ayrı "çıkar" ve "ekle" listeleri denenebilirdi; denenmedi — sipariş tezgâhta, telefon tek
//    elle tutulurken alınıyor ve iki listeyi tarayıp doğru olana dokunmak, tek bir çipe
//    dokunmaktan yavaştır.
//
// 2. MÜŞTERİNİN TERCİHİ ÖNCEDEN UYGULANIR. Kullanıcının cümlesi buydu: "işletmede her seferinde
//    bunu sormak istemeyebilir". Sheet açıldığında müşterinin kayıtlı tercihi ZATEN seçili gelir
//    ve üstte bir satır bunu SÖYLER. Sessizce uygulamak kabul edilemezdi: sipariş alan kişi
//    ekranda gördüğü şeyin nereden geldiğini bilmeli, yoksa "ben bunu seçmedim" der.
//
// 3. HATIRLAMA ANAHTARI SEÇİM YAPILINCA BELİRİR. Boş bir seçimde "bu müşteri için hatırla"
//    göstermek, hiçbir şeyi hatırlamayı teklif etmek olurdu. Anahtar yalnız müşterili siparişte
//    ve yalnız seçim varken çizilir.
//
// 4. FİYAT ANINDA GÜNCELLENİR. Ekstra eklenince üstteki tutar değişir. Ücretin sipariş
//    kaydedildikten sonra ortaya çıkması, bayinin müşteriye yanlış rakam söylemesi demekti.

import 'package:flutter/material.dart';

import '../../data/urun_secenekleri.dart';
import '../../theme/components/atoms.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Ürünün seçenek listesini çipler hâlinde çizer ve seçimi [onDegis] ile bildirir.
class UrunSecenekSecici extends StatelessWidget {
  const UrunSecenekSecici({
    super.key,
    required this.secenekler,
    required this.secim,
    required this.onDegis,
  });

  final List<UrunSecenegi> secenekler;
  final SecenekSecimi secim;
  final ValueChanged<SecenekSecimi> onDegis;

  bool _cikarildi(UrunSecenegi s) =>
      secim.cikarilan.any((a) => a.toLowerCase() == s.ad.toLowerCase());

  bool _eklendi(UrunSecenegi s) =>
      secim.eklenen.any((e) => e.ad.toLowerCase() == s.ad.toLowerCase());

  void _cevir(UrunSecenegi s) {
    if (s.varsayilan) {
      final yeni = [...secim.cikarilan];
      if (_cikarildi(s)) {
        yeni.removeWhere((a) => a.toLowerCase() == s.ad.toLowerCase());
      } else {
        yeni.add(s.ad);
      }
      onDegis(SecenekSecimi(cikarilan: yeni, eklenen: secim.eklenen));
    } else {
      final yeni = [...secim.eklenen];
      if (_eklendi(s)) {
        yeni.removeWhere((e) => e.ad.toLowerCase() == s.ad.toLowerCase());
      } else {
        // EKLENEN, ÜRÜNÜN BUGÜNKÜ FİYATIYLA kopyalanır: satır kendi kendine yetmeli
        // (`order_lines.optionsJson` gerekçesi).
        yeni.add(s);
      }
      onDegis(SecenekSecimi(cikarilan: secim.cikarilan, eklenen: yeni));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (secenekler.isEmpty) return const SizedBox.shrink();
    final t = context.sip;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: SipSpace.x2),
        Row(
          children: [
            Text(
              'İçindekiler',
              style: SipText.metin(12, w: 700).copyWith(color: t.muted),
            ),
            const SizedBox(width: SipSpace.md),
            Expanded(
              child: Text(
                'dokunarak çıkarın / ekleyin',
                style: SipText.yardimci.copyWith(color: t.line2),
              ),
            ),
          ],
        ),
        const SizedBox(height: SipSpace.md),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final s in secenekler)
              _SecenekCipi(
                secenek: s,
                cikarildi: _cikarildi(s),
                eklendi: _eklendi(s),
                onTap: () => _cevir(s),
              ),
          ],
        ),
      ],
    );
  }
}

/// Tek malzeme çipi. Dört görünüm, dört ANLAM:
///  · içinde + dokunulmamış → nötr yüzey ("var")
///  · içinde + dokunulmuş   → ÜSTÜ ÇİZİLİ, uyarı tonu ("çıkarıldı")
///  · ekstra + dokunulmamış → kesikli/soluk ("eklenebilir", fiyatıyla)
///  · ekstra + dokunulmuş   → accent dolu ("eklendi")
class _SecenekCipi extends StatelessWidget {
  const _SecenekCipi({
    required this.secenek,
    required this.cikarildi,
    required this.eklendi,
    required this.onTap,
  });

  final UrunSecenegi secenek;
  final bool cikarildi;
  final bool eklendi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final ekstra = !secenek.varsayilan;
    final secili = ekstra ? eklendi : !cikarildi;

    final (zemin, yazi) = switch ((ekstra, secili)) {
      (false, true) => (t.surface2, t.ink),
      (false, false) => (t.warnSoft, t.warn),
      (true, true) => (t.accentSoft, t.accent),
      (true, false) => (t.surface2, t.muted),
    };

    // Ücret ETİKETTE görünür, yalnız eklenebilir ve ücretli olanda: ücretsiz bir ekstranın
    // yanına "0,00 ₺" yazmak, bayiye para alıyormuş gibi görünen bir çip verirdi.
    final ucret = ekstra && secenek.ekKurus > 0 ? ' +${sipTutar(secenek.ekKurus)}' : '';

    return Semantics(
      button: true,
      selected: secili,
      label: ekstra
          ? '${secenek.ad}${eklendi ? ' eklendi' : ' ekle'}'
          : '${secenek.ad}${cikarildi ? ' çıkarıldı' : ''}',
      child: SipDokun(
        onTap: onTap,
        zemin: zemin,
        radius: SipRadius.brHap,
        padding: const EdgeInsets.symmetric(horizontal: SipSpace.xl, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ekstra)
              SipIcon(eklendi ? SipIcons.check : SipIcons.plus,
                  boyut: 12, kalinlik: 2.6, renk: yazi),
            if (ekstra) const SizedBox(width: 5),
            Text(
              '${secenek.ad}$ucret',
              style: SipText.metin(12.5, w: 700).copyWith(
                color: yazi,
                // ÜSTÜ ÇİZİLİ = ÇIKARILDI. Renkle de anlatılıyor ama tek başına renk yetmez:
                // kırmızı/yeşil ayrımını görmeyen bir kullanıcı çizgiyi görür.
                decoration: cikarildi ? TextDecoration.lineThrough : null,
                decorationColor: yazi,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Bu müşteri için hatırla" anahtarı + uygulanan tercihin bildirimi.
///
/// İKİSİ TEK BİLEŞENDE: aynı sorunun iki yüzü — "bu tercih nereden geldi" ve "bir dahakine de
/// böyle olsun mu". Ayrı çizilseler ekranın iki ayrı yerinde birbirine atıfta bulunan iki kutu
/// olurdu.
class MusteriTercihSeridi extends StatelessWidget {
  const MusteriTercihSeridi({
    super.key,
    required this.musteriAdi,
    required this.tercihUygulandi,
    required this.hatirla,
    required this.onHatirla,
    required this.secimVar,
  });

  /// Müşteri adı — metin kişiselleşsin ("Ayşe Hanım'ın tercihi"). Boşsa genel dil kullanılır.
  final String? musteriAdi;

  /// Sheet açılırken kayıtlı tercih UYGULANDI mı? (Sessiz uygulama kabul edilemez — dosya başlığı.)
  final bool tercihUygulandi;

  final bool hatirla;
  final ValueChanged<bool> onHatirla;

  /// Seçim yapılmış mı — anahtar yalnız o zaman anlamlıdır.
  final bool secimVar;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final ad = (musteriAdi ?? '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (tercihUygulandi) ...[
          const SizedBox(height: SipSpace.md),
          Row(
            children: [
              SipIcon(SipIcons.check, boyut: 13, kalinlik: 2.6, renk: t.ok),
              const SizedBox(width: SipSpace.sm),
              Expanded(
                child: Text(
                  ad.isEmpty
                      ? 'Bu müşterinin kayıtlı tercihi uygulandı'
                      : '$ad için kayıtlı tercih uygulandı',
                  style: SipText.metin(11.5, w: 600).copyWith(color: t.ok),
                ),
              ),
            ],
          ),
        ],
        if (secimVar) ...[
          const SizedBox(height: SipSpace.md),
          SipDokun(
            onTap: () => onHatirla(!hatirla),
            zemin: t.surface2,
            radius: SipRadius.br2,
            padding: const EdgeInsets.symmetric(
                horizontal: SipSpace.xl, vertical: SipSpace.lg),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Bu müşteri için hatırla',
                        style: SipText.metin(13, w: 700).copyWith(color: t.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Bir dahaki siparişte kendiliğinden uygulanır',
                        style: SipText.yardimci.copyWith(color: t.muted),
                      ),
                    ],
                  ),
                ),
                SipKnob(acik: hatirla),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
