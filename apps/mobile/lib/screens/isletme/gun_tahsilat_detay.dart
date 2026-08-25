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
///
/// [bugunMu] false iken "Bugün" yerine "Bu gün" yazılır: Gün Özeti 2026-08-25'te gün gezinmesi
/// kazandı ve aynı sheet artık üç gün önceki günü de gösteriyor. "Bugün havale tahsilat yok"
/// cümlesi orada düpedüz yanlış olurdu — bayi geçmişe bakarken bugünün bilgisini okuduğunu
/// sanırdı.
String tahsilatBosMetni(String? odemeTuru, {bool bugunMu = true}) {
  final ne = bugunMu ? 'Bugün' : 'Bu gün';
  return odemeTuru == null
      ? '$ne kasaya giren bir tahsilat yok'
      : '$ne ${odemeTuruAdi(odemeTuru).toLowerCase()} tahsilat yok';
}

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
                Row(
                  children: [
                    Text(
                      saatBicimi(satir.occurredAt),
                      style: SipText.metin(11, w: 600).copyWith(color: t.ink2),
                    ),
                    // KAYNAK ROZETİ (saha isteği 2026-08-18): "borç tahsilatı kasaya işliyor
                    // fakat sipariş gibi gözüküyor". Para doğruydu, ANLAMI yanlıştı — dün
                    // teslim edilmiş bir siparişin bugün ödenmesi, bugün yapılmış bir satışla
                    // aynı satırda ayırt edilemiyordu.
                    //
                    // ROZET SAATİN YANINDA, TUTARIN DEĞİL: tutar sütununda ödeme türü rozeti
                    // zaten var; ikisini alt alta koymak satırı iki rozetli bir bulmacaya
                    // çevirirdi. Kaynak bir ZAMAN bilgisidir ("hangi güne ait iş"), o yüzden
                    // saatin komşusudur.
                    if (satir.kaynak.etiket != null) ...[
                      const SizedBox(width: SipSpace.sm),
                      _KaynakRozeti(kaynak: satir.kaynak),
                    ],
                  ],
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

/// Tahsilatın kaynağını söyleyen küçük rozet.
///
/// RENK ANLAM TAŞIR ama UYARI DEĞİLDİR: bu satırların hiçbiri hata değil, sadece bugünün
/// satışından gelmeyen paradır. `warn` tonu kullanılsaydı bayi her eski borç tahsilatında bir
/// sorun aradı — nötr `ink2` doğru olan.
class _KaynakRozeti extends StatelessWidget {
  const _KaynakRozeti({required this.kaynak});

  final TahsilatKaynagi kaynak;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final ters = kaynak == TahsilatKaynagi.duzeltme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: ters ? t.warnSoft : t.surface2,
        borderRadius: SipRadius.brHap,
      ),
      child: Text(
        kaynak.etiket!,
        style: SipText.metin(10, w: 700).copyWith(color: ters ? t.warn : t.ink2),
      ),
    );
  }
}

/// Satır listesi + toplam. Boşsa tek satırlık açıklama çizer.
class TahsilatListesi extends StatelessWidget {
  const TahsilatListesi({
    super.key,
    required this.satirlar,
    this.odemeTuru,
    this.bugunMu = true,
  });

  final List<TahsilatSatiri> satirlar;

  /// Tür süzgeci uygulandıysa hangi tür (rozet gizlenir, boş metni ona göre yazılır).
  final String? odemeTuru;

  /// Gösterilen gün bugün mü — yalnız BOŞ DURUM cümlesini etkiler.
  final bool bugunMu;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    if (satirlar.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: SipSpace.md),
        child: Text(
          tahsilatBosMetni(odemeTuru, bugunMu: bugunMu),
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
                '${satirlar.length} kayıt, toplam ',
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
  String? haric,
  String? kapsamAdi,
  bool bugunMu = true,
}) {
  return sipSheet<void>(
    context,
    baslik: kapsamAdi == null
        ? '${odemeTuruAdi(odemeTuru)} Tahsilatlar'
        : '$kapsamAdi için ${odemeTuruAdi(odemeTuru).toLowerCase()} tahsilat',
    govde: (ctx) => FutureBuilder<List<TahsilatSatiri>>(
      // KAPSAM SÜZGECİ TAM GEÇİLİR ([haric] dahil, 2026-08-25): "Elemanlar" kapsamındayken
      // kartta 3 satır, dökümde 12 satır görünüyordu — sheet yalnız `userId`yi taşıdığı için
      // "ben hariç herkes" süzgeci yolda düşüyordu. Kartın rakamı ile listenin toplamı
      // birbirini tutmak ZORUNDA; dökümün tek varlık sebebi budur.
      future: DayEndRepository(db)
          .tahsilatDetaylari(gun, userId: kuryeId, haric: haric, odemeTuru: odemeTuru),
      builder: (ctx, snap) {
        if (!snap.hasData) return const SipIskelet(adet: 3);
        return TahsilatListesi(
          satirlar: snap.data!,
          odemeTuru: odemeTuru,
          bugunMu: bugunMu,
        );
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
    this.haric,
    this.bugunMu = true,
  });

  final AppDatabase db;
  final DateTime gun;
  final String? kuryeId;

  /// "Elemanlar" kapsamı (bu kişi HARİÇ herkes). Kasa kartıyla aynı süzgeç — biri geçilip
  /// diğeri unutulursa kartın rakamı ile listenin toplamı ayrışır.
  final String? haric;

  /// Yalnız boş durum cümlesini etkiler ("Bugün" / "Bu gün").
  final bool bugunMu;

  @override
  State<GunTeslimatlariBolumu> createState() => _GunTeslimatlariBolumuState();
}

class _GunTeslimatlariBolumuState extends State<GunTeslimatlariBolumu> {
  bool _acik = false;
  Future<List<TahsilatSatiri>>? _veri;

  Future<List<TahsilatSatiri>> _oku() => DayEndRepository(widget.db)
      .tahsilatDetaylari(widget.gun, userId: widget.kuryeId, haric: widget.haric);

  void _degistir(bool acik) {
    setState(() {
      _acik = acik;
      _veri ??= _oku();
    });
  }

  @override
  void didUpdateWidget(GunTeslimatlariBolumu eski) {
    super.didUpdateWidget(eski);
    // GÜN/KAPSAM DEĞİŞTİYSE AÇIK DÖKÜM BAYATTIR (2026-08-25 gün gezinmesi). Eskiden bu ekran tek
    // bir günü gösteriyordu ve liste bir kez okunup duruyordu; artık aynı widget dün ile bugün
    // arasında gidip geliyor. Tazelemeseydik bayi dünün gününde bugünün dökümünü okurdu.
    if (eski.gun != widget.gun ||
        eski.kuryeId != widget.kuryeId ||
        eski.haric != widget.haric) {
      _veri = _acik ? _oku() : null;
    }
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
              return TahsilatListesi(satirlar: snap.data!, bugunMu: widget.bugunMu);
            },
          ),
      ],
    );
  }
}
