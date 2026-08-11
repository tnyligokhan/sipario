// GÜNÜN TAHSİLAT DÖKÜMÜ — gün özetindeki rakamların satır satır karşılığı
// (kullanıcı isteği 2026-08-11: "altta günlük teslimatları on off butonuyla detaylı görsün"
// + "havalelere tıklayınca o günkü havale siparişlerin detayları açılacak").
//
// İKİ YÜZEY, TEK SATIR BİLEŞENİ ve TEK SORGU:
//   • Alttaki "Günün Teslimatları" bölümü (aç/kapa) — günün TAMAMI.
//   • Ödeme türü sheet'i — kasa kartındaki Nakit/Kart/Havale satırına dokununca o tür.
// İkisi de `DayEndRepository.tahsilatDetaylari` çağırır ve o da kasa kartıyla AYNI süzgeci
// paylaşır. Ayrı yazılsalardı liste ile kartın toplamı ayrışır, bayi ikisine de güvenmezdi.
//
// LİSTE TAHSİLAT TAŞIR, SİPARİŞ DEĞİL: veresiye teslim edilen sipariş o gün kasaya girmediği
// için burada YOKTUR. Sipariş listesi sanılıp "teslimatım eksik görünüyor" denmesin diye
// bölüm başlığı ve boş durum metni bunu açıkça söyler.

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../repo/day_end_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../orders/order_queries.dart' show saatBicimi;

/// Ödeme türünün ekranda okunan adı. Tek yerde durur: sheet başlığı, satır rozeti ve kasa
/// kartı aynı sözcüğü kullanmalı — iki yazım, bayiye iki ayrı kalem gibi görünürdü.
String odemeTuruAdi(String tur) => switch (tur) {
      'nakit' => 'Nakit',
      'kart' => 'Kart',
      'havale' => 'Havale',
      _ => tur,
    };

/// Boş durum metni — hem sheet hem bölüm bunu kullanır.
String tahsilatBosMetni(String? odemeTuru) => odemeTuru == null
    ? 'Bugün kasaya giren bir tahsilat yok.'
    : 'Bugün ${odemeTuruAdi(odemeTuru).toLowerCase()} tahsilat yok.';

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Satır
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Tek tahsilat satırı: müşteri · adres · saat · tutar + ödeme türü rozeti.
class TahsilatSatirKarti extends StatelessWidget {
  const TahsilatSatirKarti({super.key, required this.satir, this.turuGoster = true});

  final TahsilatSatiri satir;

  /// Ödeme türü rozeti çizilsin mi. Tür sheet'inde KAPALI: başlıkta zaten yazıyor ve her
  /// satırda tekrarlamak listeyi okunmaz yapardı.
  final bool turuGoster;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    // TERS KAYIT (correction) negatif gelir ve öyle GÖSTERİLİR: kartın toplamı onu içerdiği
    // için gizlemek listeyi toplamla çelişkiye düşürürdü.
    final ters = satir.kurus < 0;

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.md, vertical: SipSpace.md),
      decoration: BoxDecoration(color: t.surface, borderRadius: SipRadius.br2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  satir.musteriAd,
                  style: SipText.metin(13.5, w: 700).copyWith(color: t.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // ADRES VARSA çizilir. Yoksa satır KISALIR, boş bir yer tutucu konmaz:
                // tezgâh satışının adresi yoktur ve "—" yazmak eksik veri izlenimi verirdi.
                if ((satir.adres ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    satir.adres!.trim(),
                    style: SipText.metin(11.5, w: 500).copyWith(color: t.muted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 3),
                Text(
                  saatBicimi(satir.occurredAt),
                  style: SipText.metin(11, w: 600).copyWith(color: t.ink2),
                ),
              ],
            ),
          ),
          const SizedBox(width: SipSpace.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                sipTutar(satir.kurus),
                style: SipText.metin(14, w: 700)
                    .copyWith(color: ters ? t.warn : t.ink),
              ),
              if (turuGoster) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: t.surface2, borderRadius: SipRadius.brHap),
                  child: Text(
                    odemeTuruAdi(satir.odemeTuru),
                    style: SipText.metin(10.5, w: 700).copyWith(color: t.ink2),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Satır listesi + toplam. Boşsa tek satırlık açıklama çizer.
class TahsilatListesi extends StatelessWidget {
  const TahsilatListesi({super.key, required this.satirlar, this.odemeTuru});

  final List<TahsilatSatiri> satirlar;

  /// Tür süzgeci uygulandıysa hangi tür (rozet gizlenir, boş metni ona göre yazılır).
  final String? odemeTuru;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    if (satirlar.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: SipSpace.md),
        child: Text(
          tahsilatBosMetni(odemeTuru),
          style: SipText.metin(12.5, w: 600).copyWith(color: t.muted),
        ),
      );
    }

    final toplam = satirlar.fold<int>(0, (a, s) => a + s.kurus);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in satirlar) TahsilatSatirKarti(satir: s, turuGoster: odemeTuru == null),
        // TOPLAM LİSTENİN ALTINDA: kasa kartındaki rakamla aynı olmalı ve bayi bunu gözüyle
        // doğrulayabilmeli. Ayrışırlarsa hata GÖRÜNÜR olur — sessiz kalmasındansa iyidir.
        Padding(
          padding: const EdgeInsets.only(top: SipSpace.md, right: SipSpace.xs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${satirlar.length} kayıt · ',
                style: SipText.metin(12, w: 600).copyWith(color: t.muted),
              ),
              Text(
                sipTutar(toplam),
                style: SipText.metin(14, w: 700).copyWith(color: t.accent),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Ödeme türü sheet'i
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Kasa kartındaki bir ödeme türü satırına dokununca açılır: o günün, o kapsamın, o türdeki
/// tahsilatları. [kuryeId] ekranın seçili kapsamıdır — kurye kendi kapsamı dışını göremez.
Future<void> tahsilatTuruSheetAc(
  BuildContext context, {
  required AppDatabase db,
  required DateTime gun,
  required String odemeTuru,
  String? kuryeId,
  String? kapsamAdi,
}) {
  return sipSheet<void>(
    context,
    baslik: kapsamAdi == null
        ? '${odemeTuruAdi(odemeTuru)} Tahsilatlar'
        : '${odemeTuruAdi(odemeTuru)} · $kapsamAdi',
    govde: (ctx) => FutureBuilder<List<TahsilatSatiri>>(
      future: DayEndRepository(db)
          .tahsilatDetaylari(gun, userId: kuryeId, odemeTuru: odemeTuru),
      builder: (ctx, snap) {
        if (!snap.hasData) return const SipIskelet(adet: 3);
        return TahsilatListesi(satirlar: snap.data!, odemeTuru: odemeTuru);
      },
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Alttaki aç/kapa bölümü
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// "Günün Teslimatları" — anahtarla açılıp kapanan detaylı döküm.
///
/// VARSAYILAN KAPALI: gün özeti bir ÖZETTİR ve 60 teslimatlı bir günde liste kartların hepsini
/// erişilemez derinliğe iterdi. Anahtar açık kaldığı sürece (ekran ömrü boyunca) liste durur.
///
/// SORGU YALNIZ AÇILINCA KOŞAR: kapalıyken veri çekmek, bayinin hiç bakmadığı bir liste için
/// her gün özeti açılışında adres/müşteri çözümü yapmak demekti.
class GunTeslimatlariBolumu extends StatefulWidget {
  const GunTeslimatlariBolumu({
    super.key,
    required this.db,
    required this.gun,
    this.kuryeId,
  });

  final AppDatabase db;
  final DateTime gun;
  final String? kuryeId;

  @override
  State<GunTeslimatlariBolumu> createState() => _GunTeslimatlariBolumuState();
}

class _GunTeslimatlariBolumuState extends State<GunTeslimatlariBolumu> {
  bool _acik = false;
  Future<List<TahsilatSatiri>>? _veri;

  void _degistir(bool acik) {
    setState(() {
      _acik = acik;
      _veri ??= DayEndRepository(widget.db)
          .tahsilatDetaylari(widget.gun, userId: widget.kuryeId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SipBolumBaslik('Günün Teslimatları', ustBosluk: 18),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: SipSpace.md, vertical: SipSpace.md),
          decoration: BoxDecoration(color: t.surface, borderRadius: SipRadius.br2),
          child: SipDokun(
            onTap: () => _degistir(!_acik),
            radius: SipRadius.br1,
            child: Row(
              children: [
                SipIkonKutu(
                  ikon: SipIcons.truck,
                  cap: 28,
                  ikonBoyut: 14,
                  kalinlik: 2.0,
                  radius: SipRadius.hap,
                  zemin: t.accentSoft,
                  renk: t.accent,
                ),
                const SizedBox(width: SipSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Detaylı döküm',
                        style: SipText.metin(13, w: 700).copyWith(color: t.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Müşteri, adres, tutar ve ödeme türü',
                        style: SipText.metin(11, w: 500).copyWith(color: t.muted),
                      ),
                    ],
                  ),
                ),
                SipKnob(acik: _acik),
              ],
            ),
          ),
        ),
        if (_acik)
          FutureBuilder<List<TahsilatSatiri>>(
            future: _veri,
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: SipIskelet(adet: 2),
                );
              }
              return TahsilatListesi(satirlar: snap.data!);
            },
          ),
      ],
    );
  }
}
