// GÜNÜN VERESİYELERİ — gün özetindeki "bugün ne kadar borç yazdım" bölümü.
//
// NEDEN VAR (saha isteği 2026-08-18: "gün özetinde veresiye işlemleri gözükmüyor"): ekranda
// veresiye adına tek bir kart vardı ve o kart ANLIK TOPLAM BAKİYEYİ gösteriyordu (aylardır
// birikmiş borç). Bugün verilen veresiye o yığının içinde eriyordu — bayi akşam "bugün kasaya
// şu kadar girdi" diyebiliyor ama "bugün şu kadarını da borca yazdım" diyemiyordu. Günün
// mutabakatının eksik yarısıydı.
//
// TOPLAM HER ZAMAN GÖRÜNÜR, DÖKÜM AÇ/KAPA: rakamı görmek için dokunmak gerekseydi bölüm yine
// "gözükmüyor" sayılırdı — şikâyetin kendisi buydu. Döküm ise `GunTeslimatlariBolumu` ile aynı
// gerekçeyle kapalı başlar: özet bir ÖZETTİR ve uzun liste kartları erişilemez derinliğe iter.
//
// SIFIR HÂLİ DE YAZILIR ("Bugün veresiye yazılmadı"): bölümü gizlemek, veresiyesiz bir günle
// bölümün hiç olmadığı bir sürümü ayırt edilemez kılardı — ki şikâyetin doğduğu yer tam olarak
// "bir şeyin yokluğu mu, yoksa gösterilmemesi mi?" belirsizliğiydi.

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../repo/gun_veresiye_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../orders/order_queries.dart' show saatBicimi;

/// Tek veresiye satırı: müşteri · adres · saat · borçta kalan tutar.
class VeresiyeSatirKarti extends StatelessWidget {
  const VeresiyeSatirKarti({super.key, required this.satir});

  final VeresiyeSatiri satir;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
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
                style: SipText.metin(14, w: 700).copyWith(color: t.danger),
              ),
              // ELLE GİRİLEN BORÇ rozetlenir, sipariş veresiyesi ROZETSİZ kalır: olağan hâl
              // rozet taşımaz (aynı kural tahsilat satırında da geçerli). Elle giriş bir satış
              // değil bir defter düzeltmesidir ve ciro sanılmamalıdır.
              if (satir.elle) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: t.surface2, borderRadius: SipRadius.brHap),
                  child: Text(
                    'Elle borç',
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

/// "Günün Veresiyeleri" bölümü — toplam görünür, döküm aç/kapa.
class GunVeresiyeBolumu extends StatefulWidget {
  const GunVeresiyeBolumu({
    super.key,
    required this.db,
    required this.gun,
    required this.toplamKurus,
    this.kuryeId,
    this.haric,
    this.bugunMu = true,
  });

  final AppDatabase db;
  final DateTime gun;
  final String? kuryeId;

  /// "Elemanlar" kapsamı (bu kişi HARİÇ herkes) — kasa kartıyla AYNI süzgeç. Biri geçilip
  /// diğeri unutulursa başlıktaki toplam ile dökümün toplamı ayrışır.
  final String? haric;

  /// Görüntülenen gün bugün mü? Yalnız KELİMEYİ değiştirir ("Bugün" / "Bu gün"); rakamların
  /// hiçbirine dokunmaz. Gün Özeti 2026-08-25'te gün gezinmesi kazandı ve aynı bölüm artık
  /// geçmiş bir günü de gösteriyor — orada "Bugün yazılan veresiye" yazmak yanlış olurdu.
  final bool bugunMu;

  /// Gün özetinin ZATEN hesapladığı toplam. Bölüm kendi toplamını ÇIKARMAZ: aynı sayının iki
  /// yerde hesaplanması, bu depoda gün sonu tanımında üç kez ayrışma üretti.
  final int toplamKurus;

  @override
  State<GunVeresiyeBolumu> createState() => _GunVeresiyeBolumuState();
}

class _GunVeresiyeBolumuState extends State<GunVeresiyeBolumu> {
  bool _acik = false;
  Future<List<VeresiyeSatiri>>? _veri;

  Future<List<VeresiyeSatiri>> _oku() => GunVeresiyeRepository(widget.db)
      .gununVeresiyeleri(widget.gun, userId: widget.kuryeId, haric: widget.haric);

  void _degistir(bool acik) {
    setState(() {
      _acik = acik;
      _veri ??= _oku();
    });
  }

  @override
  void didUpdateWidget(GunVeresiyeBolumu eski) {
    super.didUpdateWidget(eski);
    // GÜN/KAPSAM DEĞİŞTİYSE AÇIK DÖKÜM BAYATTIR (2026-08-25 gün gezinmesi): aynı widget artık
    // dün ile bugün arasında gidip geliyor ve liste bir kez okunup duruyordu.
    if (eski.gun != widget.gun ||
        eski.kuryeId != widget.kuryeId ||
        eski.haric != widget.haric) {
      _veri = _acik ? _oku() : null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final varMi = widget.toplamKurus > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SipBolumBaslik('Günün Veresiyeleri', ustBosluk: 18),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: SipSpace.md, vertical: SipSpace.md),
          decoration: BoxDecoration(color: t.surface, borderRadius: SipRadius.br2),
          child: SipDokun(
            // Veresiye yoksa açılacak bir döküm de yoktur — dokunuş YUTULMAZ, düğme hiç
            // etkin olmaz ve anahtar çizilmez.
            onTap: varMi ? () => _degistir(!_acik) : null,
            radius: SipRadius.br1,
            child: Row(
              children: [
                SipIkonKutu(
                  ikon: SipIcons.book,
                  cap: 28,
                  ikonBoyut: 14,
                  kalinlik: 2.0,
                  radius: SipRadius.hap,
                  zemin: varMi ? t.dangerSoft : t.surface2,
                  renk: varMi ? t.danger : t.muted,
                ),
                const SizedBox(width: SipSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        varMi
                            ? '${widget.bugunMu ? 'Bugün' : 'Bu gün'} yazılan veresiye'
                            : '${widget.bugunMu ? 'Bugün' : 'Bu gün'} veresiye yazılmadı',
                        style: SipText.metin(13, w: 700).copyWith(color: t.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        varMi
                            ? 'Kasaya girmedi, müşterinin borcuna eklendi'
                            : '${widget.bugunMu ? 'Bugünkü' : 'Bu günkü'} satışların tamamı tahsil edildi',
                        style: SipText.metin(11, w: 500).copyWith(color: t.muted),
                      ),
                    ],
                  ),
                ),
                if (varMi) ...[
                  Text(
                    sipTutar(widget.toplamKurus),
                    style: SipText.metin(14, w: 700).copyWith(color: t.danger),
                  ),
                  const SizedBox(width: SipSpace.md),
                  SipKnob(acik: _acik),
                ],
              ],
            ),
          ),
        ),
        if (_acik)
          FutureBuilder<List<VeresiyeSatiri>>(
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
                  for (final s in satirlar) VeresiyeSatirKarti(satir: s),
                  // Liste toplamı ÜSTTEKİ rakamla aynı olmak zorunda; bayi bunu gözüyle
                  // doğrulayabilmeli (tahsilat dökümündeki kuralın aynısı).
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
                          sipTutar(satirlar.fold<int>(0, (a, s) => a + s.kurus)),
                          style: SipText.metin(14, w: 700).copyWith(color: t.danger),
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
