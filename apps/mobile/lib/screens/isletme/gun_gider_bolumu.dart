// GÜNÜN GİDERLERİ — gün özetindeki "kasadan ne çıktı" bölümü (kullanıcı isteği 2026-08-25).
//
// TOPLAM HER ZAMAN GÖRÜNÜR, DÖKÜM AÇ/KAPA — "Günün Veresiyeleri" bölümüyle birebir aynı desen ve
// aynı gerekçe: rakamı görmek için dokunmak gerekseydi bölüm "gözükmüyor" sayılırdı; döküm ise
// uzun olduğunda özeti aşağı iter.
//
// SIFIR HÂLİ DE YAZILIR ("gider yazılmadı"): bölümü gizlemek, gidersiz bir günle özelliğin hiç
// olmadığı bir sürümü ayırt edilemez kılardı. Bölüm ayrıca EKLEME kapısıdır — gizlenirse yol da
// gizlenmiş olur.
//
// TOPLAM BU BÖLÜMDE HESAPLANMAZ: `KasaOzeti.gider`den gelir, yani kasa kartındaki net nakdi
// üreten AYNI sayıdır. Kendi listesini toplasaydı bölüm ile kart bir gün ayrışır ve bayi hangi
// rakama güveneceğini soramazdı (bu depoda gün sonu tanımında üç kez yaşandı).

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../repo/gider_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../orders/order_queries.dart' show saatBicimi;

/// Tek gider satırı: açıklama · saat · harcayan · tutar.
class GiderSatirKarti extends StatelessWidget {
  const GiderSatirKarti({super.key, required this.satir, this.onIptal, this.adYaz = true});

  final GiderSatiri satir;

  /// Satırın İPTAL eylemi; null ise satır DOKUNULAMAZ (yetkisiz kullanıcı ya da geçmiş gün).
  /// Dokunup "yetkiniz yok" görmek, olmayan bir yolu varmış gibi göstermektir.
  final VoidCallback? onIptal;

  /// Kişi kapsamında ad HER SATIRDA tekrarlanmaz — kimin olduğu zaten başlıkta yazıyor.
  final bool adYaz;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final iptal = satir.iptalEdildi;
    final ne = (satir.aciklama ?? '').trim();

    final govde = Padding(
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.md, vertical: SipSpace.md),
      child: Row(
        children: [
          SipIkonKutu(
            ikon: SipIcons.wallet,
            cap: 28,
            ikonBoyut: 14,
            kalinlik: 2.0,
            radius: SipRadius.hap,
            zemin: iptal ? t.surface2 : t.warnSoft,
            renk: iptal ? t.muted : t.warn,
          ),
          const SizedBox(width: SipSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  // AÇIKLAMA İSTEĞE BAĞLIDIR; boşken satır "Gider" der. Boş bir başlık basmak
                  // ya da satırı gizlemek, kasadan çıkmış gerçek bir parayı görünmez kılardı.
                  ne.isEmpty ? 'Gider' : ne,
                  style: SipText.metin(13.5, w: 700)
                      .copyWith(color: iptal ? t.muted : t.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    saatBicimi(satir.occurredAt),
                    if (adYaz && satir.harcayanAd.isNotEmpty) satir.harcayanAd,
                    if (iptal) 'iptal edildi',
                  ].join(', '),
                  style: SipText.metin(11, w: 600).copyWith(color: t.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: SipSpace.md),
          Text(
            '− ${sipTutar(satir.kurus)}',
            style: SipText.metin(14, w: 700).copyWith(
              color: iptal ? t.muted : t.warn,
              decoration: iptal ? TextDecoration.lineThrough : null,
              decorationColor: iptal ? t.muted : null,
              decorationThickness: iptal ? 1.6 : null,
            ),
          ),
          if (onIptal != null && !iptal) ...[
            const SizedBox(width: 6),
            // İŞARET `ban`, `trash` DEĞİL: bu ekranda hiçbir şey SİLİNMİYOR (BRIEF kırmızı
            // çizgi #2) — iptal, ters işaretli ikinci bir kayıttır (ara tahsilatla aynı kural).
            SipIcon(SipIcons.ban, boyut: 14, kalinlik: 2.2, renk: t.muted),
          ],
        ],
      ),
    );

    // İPTAL EDİLMİŞ SATIR TEKRAR DOKUNULAMAZ: ikinci bir iptal, parayı ikinci kez geri vermek
    // olurdu (ara tahsilat kartındaki kuralın aynısı).
    final dokunulur = onIptal != null && !iptal;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: SipDokun(
        onTap: dokunulur ? onIptal : null,
        zemin: t.surface,
        radius: SipRadius.br2,
        child: govde,
      ),
    );
  }
}

/// "Giderler" bölümü — toplam görünür, döküm aç/kapa, başlıkta ekleme kapısı.
class GunGiderBolumu extends StatefulWidget {
  const GunGiderBolumu({
    super.key,
    required this.db,
    required this.gun,
    required this.toplamKurus,
    required this.bugunMu,
    this.kuryeId,
    this.haric,
    this.adYaz = true,
    this.onEkle,
    this.onIptal,
    this.yenilemeAnahtari = 0,
  });

  final AppDatabase db;
  final DateTime gun;

  /// `KasaOzeti.gider` — kasa kartındaki net nakdi üreten AYNI sayı (bkz. dosya başlığı).
  final int toplamKurus;

  /// Görüntülenen gün bugün mü? Ekleme yalnız bugün mümkündür ve bölüm sebebini yazar.
  final bool bugunMu;

  final String? kuryeId;
  final String? haric;
  final bool adYaz;

  /// "Ekle" kapısı; null ise düğme HİÇ çizilmez (yetkisiz kullanıcı, geçmiş gün ya da kapanmış
  /// kapsam). Yetki kararı EKRANDADIR — bölüm onu yalnız taşır.
  final VoidCallback? onEkle;

  /// Bir satırın İPTAL eylemini üreten yapıcı; null ise satırlar dokunulamaz.
  final VoidCallback Function(GiderSatiri)? onIptal;

  /// Artınca döküm yeniden okunur — ekleme/iptal sonrası açık listeyi tazelemenin tek yolu.
  final int yenilemeAnahtari;

  @override
  State<GunGiderBolumu> createState() => _GunGiderBolumuState();
}

class _GunGiderBolumuState extends State<GunGiderBolumu> {
  bool _acik = false;
  Future<List<GiderSatiri>>? _veri;

  Future<List<GiderSatiri>> _oku() => GiderRepository(widget.db)
      .gunGiderleri(widget.gun, userId: widget.kuryeId, haric: widget.haric);

  void _degistir(bool acik) {
    setState(() {
      _acik = acik;
      _veri ??= _oku();
    });
  }

  @override
  void didUpdateWidget(GunGiderBolumu eski) {
    super.didUpdateWidget(eski);
    // Gün/kapsam değiştiyse ya da yeni bir kayıt yazıldıysa açık döküm BAYATTIR. Kapatıp
    // yeniden açmayı beklemek, az önce eklediği gideri listede göremeyen bayiye kaydın
    // yazılmadığını düşündürürdü.
    if (eski.gun != widget.gun ||
        eski.kuryeId != widget.kuryeId ||
        eski.haric != widget.haric ||
        eski.yenilemeAnahtari != widget.yenilemeAnahtari) {
      _veri = _acik ? _oku() : null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final varMi = widget.toplamKurus != 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SipBolumBaslik(
          'Giderler',
          ustBosluk: 18,
          sag: widget.onEkle == null
              ? null
              : SipMetinButon(
                  etiket: 'Gider Ekle',
                  ikon: SipIcons.plus,
                  onTap: widget.onEkle,
                ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: SipSpace.md, vertical: SipSpace.md),
          decoration: BoxDecoration(color: t.surface, borderRadius: SipRadius.br2),
          child: SipDokun(
            // Gider yoksa açılacak döküm de yoktur — dokunuş YUTULMAZ, anahtar hiç çizilmez.
            onTap: varMi ? () => _degistir(!_acik) : null,
            radius: SipRadius.br1,
            child: Row(
              children: [
                SipIkonKutu(
                  ikon: SipIcons.wallet,
                  cap: 28,
                  ikonBoyut: 14,
                  kalinlik: 2.0,
                  radius: SipRadius.hap,
                  zemin: varMi ? t.warnSoft : t.surface2,
                  renk: varMi ? t.warn : t.muted,
                ),
                const SizedBox(width: SipSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        varMi ? 'Kasadan çıkan' : 'Gider yazılmadı',
                        style: SipText.metin(13, w: 700).copyWith(color: t.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        varMi
                            ? 'Sayılacak nakitten düşüldü'
                            : (widget.bugunMu
                                ? 'Benzin, tamir gibi masrafları buraya yazın'
                                : 'Bu gün kasadan para çıkmamış'),
                        style: SipText.metin(11, w: 500).copyWith(color: t.muted),
                      ),
                    ],
                  ),
                ),
                if (varMi) ...[
                  Text(
                    '− ${sipTutar(widget.toplamKurus)}',
                    style: SipText.metin(14, w: 700).copyWith(color: t.warn),
                  ),
                  const SizedBox(width: SipSpace.md),
                  SipKnob(acik: _acik),
                ],
              ],
            ),
          ),
        ),
        if (_acik)
          FutureBuilder<List<GiderSatiri>>(
            future: _veri,
            builder: (ctx, snap) {
              final satirlar = snap.data;
              if (satirlar == null) {
                return const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: SipIskelet(adet: 2),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final s in satirlar)
                    GiderSatirKarti(
                      satir: s,
                      adYaz: widget.adYaz,
                      onIptal: s.iptalEdildi ? null : widget.onIptal?.call(s),
                    ),
                  // Liste toplamı ÜSTTEKİ rakamla aynı olmak zorunda; bayi bunu gözüyle
                  // doğrulayabilmeli (tahsilat ve veresiye dökümündeki kuralın aynısı).
                  // İPTALLİ SATIRLAR TOPLAMA GİRMEZ: parası kasaya geri döndü.
                  Padding(
                    padding: const EdgeInsets.only(top: SipSpace.md, right: SipSpace.xs),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${satirlar.where((s) => !s.iptalEdildi).length} kayıt, toplam ',
                          style: SipText.metin(12, w: 600).copyWith(color: t.muted),
                        ),
                        Text(
                          '− ${sipTutar(satirlar.where((s) => !s.iptalEdildi).fold<int>(0, (a, s) => a + s.kurus))}',
                          style: SipText.metin(14, w: 700).copyWith(color: t.warn),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}
