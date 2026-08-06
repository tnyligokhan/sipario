// GÜN SONU ekranının kart parçaları — tasarım s-gunsonu.jsx + Sipario.html
// `.gs-veresiye`, `.gs-vtop`, `.gs-temiz`, `.gs-arow`, `.gs-engel`.
//
// Hepsi salt gösterimdir: gelen değeri çizer, hiçbir para hesabı yapmaz (hesap `gun_sonu_ozet.dart`
// üzerinden repo'lardadır).

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../repo/cash_handover_repository.dart';
import '../../repo/day_end_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'gun_kapatma_sheet.dart';
import 'isletme_atomlari.dart';

/// CSS `.gs-veresiye` — toplam açık borç + borçlu dökümü (çoktan aza).
class VeresiyeKarti extends StatelessWidget {
  const VeresiyeKarti({super.key, required this.borc});

  final BorcDurumu borc;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return DegerKarti(
      satirlar: [
        // CSS `.gs-vtop`
        DegerSatiri(
          etiket: 'Toplam açık borç',
          deger: sipTutar(borc.toplamAcikBorc),
          degerRengi: borc.toplamAcikBorc > 0 ? t.danger : t.ink,
        ),
        if (borc.borclular.isEmpty)
          // CSS `.gs-temiz`
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              children: [
                SipIcon(SipIcons.check, boyut: 16, kalinlik: 2.4, renk: t.ok),
                const SizedBox(width: SipSpace.md),
                Text(
                  'Borçlu müşteri yok',
                  style: SipText.metin(13, w: 700).copyWith(color: t.ok),
                ),
              ],
            ),
          )
        else
          for (final b in borc.borclular)
            DegerSatiri(
              etiket: b.name,
              deger: sipTutar(b.balanceKurus),
              degerRengi: t.danger,
            ),
      ],
    );
  }
}

/// ARA TAHSİLAT satırları (kullanıcı kararı 2026-08-06) — "kim · saat · tutar", eskiden yeniye.
///
/// NEDEN GÖRÜNÜR OLMAK ZORUNDA: kapanışta beklenen nakit artık KALAN nakittir. Bu kart olmasaydı
/// bayi her gün açıklanamayan bir eksik görürdü ("ciro 12.000, kasada 7.000") ve o farkın nereye
/// gittiğini uygulama hiçbir yerde söylemezdi.
///
/// Sıra ESKİDEN YENİYEDİR (repo öyle döner): bu bir arşiv değil, günün akışıdır.
class AraTahsilatKarti extends StatelessWidget {
  const AraTahsilatKarti({super.key, required this.kayitlar, this.kuryeAdiYaz = true});

  final List<AraTahsilatKaydi> kayitlar;

  /// Kurye kapsamında ad HER SATIRDA tekrarlanmaz — kimin olduğu zaten başlıkta yazıyor.
  final bool kuryeAdiYaz;

  @override
  Widget build(BuildContext context) {
    return DegerKarti(
      satirlar: [
        for (final k in kayitlar)
          DegerSatiri(
            etiket: kuryeAdiYaz && k.kuryeAdi.isNotEmpty
                ? '${k.kuryeAdi} · ${araTahsilatSaati(k.occurredAt)}'
                : araTahsilatSaati(k.occurredAt),
            deger: sipTutar(k.countedCashKurus),
          ),
        // Toplam satırı TEK kayıtta da çizilir: kapanış sheet'indeki "alınan ara tahsilat"
        // rakamıyla göz göze karşılaştırılan sayı budur.
        DegerSatiri(
          etiket: 'Alınan toplam · ${kayitlar.length} tahsilat',
          deger: sipTutar(kayitlar.fold<int>(0, (s, k) => s + k.countedCashKurus)),
          toplam: true,
        ),
      ],
    );
  }
}

/// UTC damgadan TR saati ("14:30"). Gün sınırı kuralıyla aynı sabit +03:00 kaydırması —
/// iki farklı saat tanımı, aynı tahsilatı iki farklı güne düşürürdü.
String araTahsilatSaati(DateTime utc) {
  final tr = utc.toUtc().add(const Duration(hours: 3));
  return '${tr.hour.toString().padLeft(2, '0')}:${tr.minute.toString().padLeft(2, '0')}';
}

/// CSS `.gs-arow` — arşiv satırı. [kapsamAdi] gün hesabında "Gün hesabı", kuryede kuryenin adı.
class ArsivSatiri extends StatelessWidget {
  const ArsivSatiri({super.key, required this.kapanis, required this.kapsamAdi, this.onTap});

  final DayClosing kapanis;
  final String kapsamAdi;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final k = kapanis;
    final farkli = k.countedCashKurus != null && k.diffKurus != 0;
    return SipDokun(
      onTap: onTap,
      zemin: t.surface,
      radius: SipRadius.br2,
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: SipSpace.xl),
      child: Row(
        children: [
          SipIkonKutu(
            ikon: SipIcons.lock,
            cap: 30,
            ikonBoyut: 15,
            zemin: t.surface2,
            renk: t.muted,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  kapsamAdi,
                  style: SipText.metin(13.5, w: 700).copyWith(color: t.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    '${gunSaatBicimi(k.occurredAt)} · ${k.deliveryCount} teslimat'
                    '${farkli ? ' · fark ${sipTutar(k.diffKurus)}' : ''}',
                    style: SipText.yardimci.copyWith(color: t.muted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: SipSpace.md),
          Text(
            sipTutar(k.totalCollectedKurus),
            style: SipText.tutar(13.5).copyWith(color: t.ink),
          ),
          const SizedBox(width: SipSpace.sm),
          SipIcon(SipIcons.chevR, boyut: 16, kalinlik: 2, renk: t.line2),
        ],
      ),
    );
  }
}

/// CSS `.gs-engel` — kapatmayı durduran uyarı.
///
/// ÜÇ engel vardır ve hepsi aynı kutuyu kullanır (en temelden başlayarak):
///  1. [rolEngeli] — kullanıcının bu kapsamı kapatma yetkisi yok (K2): kurye gün hesabını ya da
///     başka bir kuryenin hesabını kapatamaz.
///  2. [acikSiparis] > 0 — o kapsamda hâlâ teslim edilmemiş sipariş var.
///  3. [acikKuryeler] dolu — GÜN hesabı kapatılmak isteniyor ama kuryelerin bir kısmı
///     hesabını kapatmış, bir kısmı kapatmamış (tasarım `gunEngel`). Yarım kalmış devir.
class KapatmaEngeli extends StatelessWidget {
  const KapatmaEngeli({
    super.key,
    this.rolEngeli = false,
    this.acikSiparis = 0,
    this.acikKuryeler = const [],
  });

  final bool rolEngeli;
  final int acikSiparis;
  final List<String> acikKuryeler;

  @override
  Widget build(BuildContext context) {
    final metin = rolEngeli
        ? 'Bu hesabı yönetici kapatır; siz yalnız kendi kurye hesabınızı kapatabilirsiniz.'
        : acikSiparis > 0
            ? 'Önce açık siparişleri kapatın: $acikSiparis açık sipariş var.'
            : 'Önce açık kurye hesaplarını kapatın: ${acikKuryeler.join(', ')}';
    return _EngelKutusu(metin: metin);
  }
}

/// CSS `.ys-alt` — Gün Özeti'nin alt çubuğu: kapatma engeli · toplam · eylem düğmeleri
/// (ya da kapsam kapalıysa `.gs-alt-kapali` mührü).
///
/// NEDEN EKRANDAN AYRI DOSYADA: `day_end_screen.dart` ara tahsilat akışıyla 500 satırı aşıyordu.
/// Çubuk salt gösterimdir — hiçbir yetki KARARI vermez, yalnız verilen kararı çizer. İki eylem
/// düğmesinin de görünürlüğü/etkinliği ekranın hesapladığı kapılardan gelir (K2 çift kapı: ekran
/// düğmeyi kapatır VE eylem fonksiyonu yetkiyi yeniden sorar).
class GunOzetiAltCubugu extends StatelessWidget {
  const GunOzetiAltCubugu({
    super.key,
    required this.kapsamKapali,
    required this.gunKapali,
    required this.kuryeAdi,
    required this.kapatabilir,
    required this.acikSiparis,
    required this.gunEngeli,
    required this.acikKuryeAdlari,
    required this.toplam,
    required this.onKapat,
    this.onAraTahsilat,
  });

  final bool kapsamKapali;
  final bool gunKapali;

  /// null ise gün hesabı kapsamı.
  final String? kuryeAdi;

  /// K2: kurye gün hesabını (ve başkasının hesabını) kapatamaz. false ise düğme kapalı çizilir
  /// ve NEDENİ yazılır — sessizce devre dışı bir düğme kullanıcıya hiçbir şey söylemiyordu.
  final bool kapatabilir;

  final int acikSiparis;
  final bool gunEngeli;
  final List<String> acikKuryeAdlari;
  final int toplam;
  final VoidCallback onKapat;

  /// null ise ara tahsilat düğmesi HİÇ ÇİZİLMEZ (tek kişilik bayi, gün kapsamı, yetkisiz kullanıcı
  /// ya da kapatılmış kapsam). Pasif çizmek yerine hiç çizmemek bilinçli: bu ekranın çoğu
  /// kullanıcısı tek kişilik bayidir ve onlar için "kuryeden ara tahsilat" diye bir kavram yoktur.
  final VoidCallback? onAraTahsilat;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;

    if (kapsamKapali) {
      return AltCubuk(children: [
        SizedBox(
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SipIcon(SipIcons.check, boyut: 17, kalinlik: 2.6, renk: t.ok),
              const SizedBox(width: SipSpace.md),
              Flexible(
                child: Text(
                  gunKapali
                      ? 'Gün kapatıldı — arşivde'
                      : '$kuryeAdi hesabı kapatıldı — arşivde',
                  style: SipText.metin(13.5, w: 800).copyWith(color: t.ok),
                ),
              ),
            ],
          ),
        ),
      ]);
    }

    // ÜÇ bağımsız kapı, en temelden başlayarak: rol (bu kapsamı kapatma yetkisi), açık sipariş
    // (her kapsamda) ve yarım kalmış kurye devri (yalnız gün hesabında).
    final engel = !kapatabilir || acikSiparis > 0 || gunEngeli;
    return AltCubuk(children: [
      if (engel)
        SizedBox(
          width: double.infinity,
          child: KapatmaEngeli(
            rolEngeli: !kapatabilir,
            acikSiparis: kapatabilir ? acikSiparis : 0,
            acikKuryeler:
                !kapatabilir || acikSiparis > 0 ? const [] : acikKuryeAdlari,
          ),
        ),
      // Toplam, ara tahsilat düğmesi varken DARALIR: üç öğe 150 punto etiketle yan yana
      // sığmıyordu ve tutar kırpılıyordu (para asla kırpılmaz).
      SizedBox(
        width: onAraTahsilat == null ? 150 : 108,
        child: AltCubukToplam(
          etiket: kuryeAdi == null ? 'Bugün tahsilat' : '$kuryeAdi · tahsilat',
          deger: sipTutar(toplam),
        ),
      ),
      // Ara tahsilat İKİNCİLDİR: günün asıl eylemi kapatmaktır ve iki birincil düğme
      // hangisinin "doğru" olduğunu belirsizleştirirdi.
      if (onAraTahsilat != null)
        SipButon(
          etiket: 'Ara Tahsilat',
          ikon: SipIcons.hand,
          tur: SipButonTuru.ikincil,
          genisle: false,
          yatayPadding: SipSpace.xl,
          onTap: onAraTahsilat,
        ),
      SipButon(
        etiket: kuryeAdi == null ? 'Günü Kapat' : 'Hesabı Kapat',
        ikon: SipIcons.lock,
        genisle: false,
        yatayPadding: onAraTahsilat == null ? SipSpace.x5 : SipSpace.xl,
        onTap: engel ? null : onKapat,
      ),
    ]);
  }
}

class _EngelKutusu extends StatelessWidget {
  const _EngelKutusu({required this.metin});

  final String metin;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.xl, vertical: SipSpace.lg),
      decoration: BoxDecoration(color: t.warnSoft, borderRadius: SipRadius.br1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: SipIcon(SipIcons.alert, boyut: 14, kalinlik: 2.2, renk: t.warn),
          ),
          const SizedBox(width: SipSpace.md),
          Expanded(
            child: Text(
              metin,
              style: SipText.metin(12, w: 600, h: 1.45).copyWith(color: t.warn),
            ),
          ),
        ],
      ),
    );
  }
}
