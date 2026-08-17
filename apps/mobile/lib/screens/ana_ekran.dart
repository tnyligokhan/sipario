// ANA EKRAN — s-ana.jsx + Sipario.html `.ana-*`, `.bento*`, `.akt-*`.
//
// Koyu mürekkep hero (selam + SAHİP ADI + menü + senkron çipi) · bento özet ızgarası · birincil
// CTA · "Son aktivite" listesi. Rakamlar GERÇEK veriden gelir (bkz. shell/ana_ozet.dart) — demo
// sabiti yok.
//
// HERO'DA İŞLETME ADI DEĞİL SAHİP ADI YAZAR: `s-ana.jsx:21` `{ISLETME.sahip}` ('Mehmet Usta').
// CSS sınıfı `.ana-isletme` adını taşır ama içeriği sahiptir; işletme adı ÇEKMECEDE kullanılır
// (`s-bilesenler.jsx:100`). Selamın ("Günaydın") altına firma unvanı değil kişinin adı gelir.
//
// 4. bento kutusu "Son Arama" (`s-ana.jsx:45`): verisi `cagri/cagri_gunlugu.dart`taki
// [sonAramaAkisi]. Kutuya dokunmanın kuralı `s-uygulama.jsx:90` (`onAramaAc`) — numara
// KAYITLIYSA müşteri detayı, KAYITSIZSA çağrı kartı. Kararı bu ekran vermez, [onArama] ile
// kabuğa devreder (çağrı günlüğü ne müşteri ekranını ne çağrı kartını tanır).

import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../guncelleme/guncelleme_servisi.dart';
import '../sync/sync_service.dart';
import '../sync/yenileme.dart';
import '../theme/components/atoms.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'cagri/cagri_model.dart';
import 'shell/alt_nav.dart';
import 'shell/ana_bento.dart';
import 'shell/ana_ozet.dart';

// EKRAN İKİYE BÖLÜNDÜ (2026-08-17, 500 satır kuralı — 509 satırdı): hero ve çipler ayrı
// parçada. Ekranın özel widget'ları oldukları için `part`tır.
part 'ana_ekran_parcalari.dart';

class AnaEkran extends StatefulWidget {
  const AnaEkran({
    super.key,
    required this.db,
    required this.sahipAdi,
    required this.onMenu,
    required this.onSekme,
    required this.onYeniSiparis,
    required this.onArama,
    required this.onSiparisAc,
    required this.onBorclular,
    this.borclulariGoster = true,
    this.acikSiparisKullanicisi,
    this.sonSenkron,
    this.sonSenkronAt,
  });

  final AppDatabase db;

  /// Selamın altındaki ad — kullanıcının kendi adı (tasarım `ISLETME.sahip`).
  final String sahipAdi;

  final VoidCallback onMenu;
  final ValueChanged<SipSekme> onSekme;
  final VoidCallback onYeniSiparis;

  /// "Son Arama" kutusuna dokunulduğunda. Kayıtlı/kayıtsız ayrımını kabuk yapar.
  final ValueChanged<AramaKaydi> onArama;

  /// "Son aktivite" satırına dokunulduğunda: sipariş sekmesine geçilir VE detay açılır
  /// (`s-uygulama.jsx:89` — `setTab('siparis')` + `setSipDetay(veri)`). Detay sheet'i sipariş
  /// katmanının işi; bu ekran yalnız kimliği devreder.
  final ValueChanged<String> onSiparisAc;

  /// "Borçlular" bento kutusu — borçlu müşteriler ekranını kabuk açar (yazma yetkisi orada
  /// bilinir; bu ekran yalnız niyeti devreder, `onArama`/`onSiparisAc` deseninin aynısı).
  final VoidCallback onBorclular;

  /// Borçlular kutusu çizilsin mi (`yetkiler().toplamBorclulariGorme`). Kurye için kapalıdır:
  /// kutu çizilmezse toplam borç tutarı ve borçlu müşteri sayısı ekranda hiç görünmez.
  final bool borclulariGoster;

  /// "Açık Sipariş" kutusunun kapsamı. Kurye kısıtlıysa onun kullanıcı kimliği verilir ve
  /// kutu yalnız ona atananları sayar; yönetici için `null` (dükkân geneli).
  ///
  /// ⚠️ 2026-08-09: bu alan olmadan ana ekran "12 açık" derken sipariş listesi 2 gösteriyordu —
  /// aynı uygulamanın iki yüzeyi farklı sayı konuşuyordu.
  final String? acikSiparisKullanicisi;

  final SyncOutcome? sonSenkron;
  final DateTime? sonSenkronAt;

  /// Saate göre selam (kullanıcı isteği 2026-07-29: dört kuşak).
  ///
  /// Kuşaklar su bayisinin gününe göre biçildi, saat diliminin ortasına değil:
  ///  • 06–11 **Günaydın** — dükkân açılır, günün siparişleri girilir.
  ///  • 12–17 **Kolay gelsin** — teslimatın en yoğun olduğu bant; "iyi günler" burada
  ///    fazla resmî kalıyordu, esnaf birbirine "kolay gelsin" der.
  ///  • 18–21 **İyi akşamlar** — son teslimatlar ve gün sonu kapanışı.
  ///  • 22–05 **İyi geceler** — dükkân kapalı; uygulama bu saatte açılıyorsa ya gün sonu
  ///    hesabı yapılıyordur ya da gece nöbeti vardır, ikisinde de "günaydın" yanlış olur.
  static String selam(DateTime simdi) {
    final s = simdi.hour;
    if (s >= 6 && s < 12) return 'Günaydın';
    if (s >= 12 && s < 18) return 'Kolay gelsin';
    if (s >= 18 && s < 22) return 'İyi akşamlar';
    return 'İyi geceler';
  }

  @override
  State<AnaEkran> createState() => _AnaEkranState();
}

class _AnaEkranState extends State<AnaEkran> {
  /// Bento özet akışı — BİR KEZ kurulur, build'de YENİDEN YARATILMAZ.
  ///
  /// ⚠️ 2026-08-09: `stream: watchAnaOzet(...)` doğrudan build'in içindeydi. Her build yeni bir
  /// Stream nesnesi demekti; StreamBuilder akışı "değişmiş" sayıp aboneliği koparıyor, o karede
  /// `snap.data` null oluyor ve `const AnaOzet()` çiziliyordu — "Açık Sipariş" kutusu ara ara
  /// 0'a düşüp geri doluyordu. Kabuk senkron/kontör/sync_meta tiklerinde setState ettiği için
  /// sık oluyordu. Aynı hata sipariş listesinde de vardı ve orada bu desenle kapatılmıştı
  /// (`orders/order_list_screen.dart` `_siparisleriIzle`); ikinci bir mekanizma icat edilmiyor.
  ///
  /// KAPSAM DEĞİŞİNCE YENİDEN KURULUR: `acikSiparisKullanicisi` kabuğa ASENKRON iner (yetki +
  /// `sync_meta.user_id`), yani ilk karede null'dır. `initState`te tek atış kurulsaydı kurye
  /// kutusu dükkân genelinde donardı — sipariş başlığı sayacının kapattığı arızanın ta kendisi.
  Stream<AnaOzet>? _ozetAkisi;
  String? _akisKullanici;

  Stream<AnaOzet> _ozetiIzle() {
    if (_ozetAkisi == null || _akisKullanici != widget.acikSiparisKullanicisi) {
      _akisKullanici = widget.acikSiparisKullanicisi;
      _ozetAkisi = watchAnaOzet(widget.db, assignedTo: _akisKullanici);
    }
    return _ozetAkisi!;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Hero(
          sahipAdi: widget.sahipAdi,
          onMenu: widget.onMenu,
          sonSenkron: widget.sonSenkron,
          sonSenkronAt: widget.sonSenkronAt,
        ),
        Expanded(
          child: StreamBuilder<AnaOzet>(
            stream: _ozetiIzle(),
            builder: (context, snap) {
              final o = snap.data ?? const AnaOzet();
              return RefreshIndicator(
                // Ana ekranda yenileme SENKRON + GÜNCELLEME kontrolü yapar (kullanıcı isteği
                // 2026-07-29). Gösterge, gerçek turun bitişini bekler — hemen kapanan bir
                // spinner "yapıldı" der ama hiçbir şeyi kanıtlamaz.
                onRefresh: anaEkranYenile,
                child: ListView(
                // AlwaysScrollable: içerik kısa olsa da (yeni kurulum, boş liste) jest
                // çalışmalı; aksi hâlde yenileme tam da en çok gerektiği kurulumda ölürdü.
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                    SipSpace.govde, SipSpace.x3, SipSpace.govde, SipSpace.x4),
                children: [
                  AnaBento(
                    db: widget.db,
                    ozet: o,
                    onSekme: widget.onSekme,
                    onArama: widget.onArama,
                    onBorclular: widget.onBorclular,
                    borclulariGoster: widget.borclulariGoster,
                  ),
                  const SizedBox(height: SipSpace.xl),
                  _Cta(onTap: widget.onYeniSiparis),
                  SipBolumBaslik('Son aktivite', ustBosluk: SipSpace.x4),
                  _SonAktivite(db: widget.db, onSiparisAc: widget.onSiparisAc),
                ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// CSS `.akt-list` / `.ana-bos` — son teslim edilen siparişler.
class _SonAktivite extends StatefulWidget {
  const _SonAktivite({required this.db, required this.onSiparisAc});

  final AppDatabase db;
  final ValueChanged<String> onSiparisAc;

  @override
  State<_SonAktivite> createState() => _SonAktiviteState();
}

class _SonAktiviteState extends State<_SonAktivite> {
  /// Akış BİR KEZ kurulur — bento özetiyle aynı gerekçe (bkz. [_AnaEkranState._ozetiIzle]).
  /// Build'de kurulduğunda kabuğun her setState'i aboneliği koparıyor ve liste o karede boş
  /// snapshot'a düşüp "Bugün henüz hareket yok." yazıyordu. Kapsam girdisi yok (`db` sabittir),
  /// bu yüzden önbellek karşılaştırmasına da gerek kalmaz.
  late final Stream<List<SonHareket>> _hareketler = watchSonHareketler(widget.db);

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return StreamBuilder<List<SonHareket>>(
      stream: _hareketler,
      builder: (context, snap) {
        final list = snap.data ?? const <SonHareket>[];
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(2, SipSpace.md, 2, SipSpace.md),
            child: Text(
              'Bugün henüz hareket yok.',
              style: SipText.metin(13).copyWith(color: t.muted),
            ),
          );
        }
        return Column(
          children: [
            for (final h in list)
              Padding(
                padding: const EdgeInsets.only(bottom: SipSpace.sm),
                child: SipDokun(
                  onTap: () => widget.onSiparisAc(h.siparisId),
                  zemin: t.surface,
                  radius: SipRadius.br2,
                  padding: const EdgeInsets.symmetric(
                      horizontal: SipSpace.x2, vertical: SipSpace.xl),
                  child: Row(
                    children: [
                      SipIkonKutu(
                        ikon: SipIcons.check,
                        cap: 30,
                        ikonBoyut: 15,
                        kalinlik: 2.4,
                        zemin: t.okSoft,
                        renk: t.ok,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              h.musteriAd,
                              style: SipText.metin(13.5, w: 700).copyWith(color: t.ink),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            // Alt satır ÜRÜN DÖKÜMÜ + ödeme tipidir (`s-ana.jsx:67`
                            // `{siparisOzet(o)} · {ODEME_TIPLERI[o.odeme].label}`), saat DEĞİL:
                            // "bugün ne sattım"ın cevabı saatte değil kalemde.
                            Text(
                              [h.satirOzeti, odemeEtiketi(h.odemeTipi)]
                                  .where((s) => s.isNotEmpty)
                                  .join(' · '),
                              style: SipText.metin(11.5).copyWith(color: t.muted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: SipSpace.lg),
                      Text(
                        sipTutar(h.tutarKurus),
                        style: SipText.tutar(13).copyWith(color: t.ink),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
