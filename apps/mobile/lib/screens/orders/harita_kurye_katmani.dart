// CANLI KURYE KATMANI — sipariş haritasının üstünde, hareket eden kurye pinleri.
//
// NEDEN AYRI DOSYA: `siparis_harita.dart` açık siparişlerin DURAKLARINI çiziyor; bunlar ise
// tamamen başka bir veri kaynağından (sunucudan, 25 sn'de bir) gelen ve zamanla BAYATLAYAN
// noktalar. Ayrı durunca 500 satır sınırı korunuyor ve haritanın kendi testleri bu katmandan
// etkilenmiyor.
//
// KAPI ROLDEDİR: yalnız PATRON kurye pinlerini görür. Rol `sync_meta` AKIŞINDAN okunur, açılışta
// TEK ATIŞ okunmaz — o satırın alanları sunucu sahiplidir ve senkron tamamlanınca değişir; tek
// atış okuma bu depoda kanıtlanmış bir tuzaktır (ekran, rol daha gelmeden "kurye" sanıp katmanı
// hiç kurmuyordu). Rol patron değilse zamanlayıcı KURULMAZ ve `/locations/live` HİÇ çağrılmaz.
//
// KATMAN KOŞULSUZ MOUNT EDİLİR (`siparis_harita.dart` onu `if` ile sarmaz): kapıyı çağıranın
// içine koymak, özelliğin ağaca hiç bağlanmadığı bir dünyayı testlerden gizlerdi.
//
// KENDİ PİNİN ÇİZİLMEZ: "Konumum" düğmesi zaten cihazın kendi noktasını taze okuyor; aynı kişiyi
// iki ayrı işaretle göstermek, patronun kendini kurye sanmasından başka bir şey üretmez.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../auth/session.dart';
import '../../data/app_database.dart';
import '../../sync/konum_api.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Lucide `bike` — iki tekerlek + kadro, tek seferlik path (`harita_kontrolleri.dart` deseni).
///
/// Material'ın `Icons.delivery_dining` motosikleti KULLANILMADI: ikon setinin kuralı bu depoda
/// açıkça yazılı (`icons.dart` — "Material ikonlarına DÖNÜLMEDİ"), dolu Material glifi haritadaki
/// çizgi dilli mor pinlerin yanında sırıtırdı. Anlatılan şey aynı: motorlu paket servis.
const String kKuryeMotorYolu =
    'M18.5 21a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7z|M5.5 21a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7z|'
    'M15 6a1 1 0 1 0 0-2 1 1 0 0 0 0 2z|M12 17.5V14l-3-3 4-3 2 3h2';

/// Rolün ekran etiketi (veri değeri değişmez — sunucuda 'kurye'/'patron' durur).
String kuryeRolEtiketi(String rol) => switch (rol) {
      'kurye' => 'Kurye',
      'patron' => 'Patron',
      'operator' => 'Operatör',
      _ => 'Kullanıcı',
    };

/// "az önce" · "7 dk önce" · "3 sa önce" · "2 gün önce".
///
/// `gecenSure` ile AYRI: orada "yeni" ve "1 sa 5 dk" gibi biçimler var ve bunlar bir siparişin
/// bekleme süresi için doğru. Burada soru başka — bir noktanın NE KADAR ESKİ olduğu; dakika
/// çözünürlüğünden sonrası gürültüdür ("3 sa 12 dk önce" hiç kimseye bir şey söylemez).
///
/// İLERİ tarihli damga "az önce" sayılır: cihaz saati sunucudan ileri olabilir ve "−4 dk önce"
/// yazmak veriye güveni sarsar.
String kuryeSonGorulme(String iso, {DateTime? simdi}) {
  final t = DateTime.tryParse(iso);
  if (t == null) return '';
  final fark = (simdi ?? DateTime.now()).difference(t.toLocal());
  if (fark.inMinutes < 1) return 'az önce';
  if (fark.inMinutes < 60) return '${fark.inMinutes} dk önce';
  if (fark.inHours < 24) return '${fark.inHours} sa önce';
  return '${fark.inDays} gün önce';
}

/// Haritanın canlı kurye katmanı. `FlutterMap` çocuğu olarak mount edilir; kapıyı KENDİ açar.
class KuryeKatmani extends StatefulWidget {
  const KuryeKatmani({
    super.key,
    required this.db,
    this.aralik = const Duration(seconds: 25),
  });

  final AppDatabase db;

  /// Tazeleme aralığı. 25 sn: bildirici 30 sn'de bir yazıyor, biraz daha sık okumak pinin
  /// bir tur boyunca donmuş kalmasını engeller.
  final Duration aralik;

  @override
  State<KuryeKatmani> createState() => _KuryeKatmaniState();
}

class _KuryeKatmaniState extends State<KuryeKatmani> {
  StreamSubscription<SyncMetaData>? _metaAbone;
  Timer? _zamanlayici;

  List<CanliKonum> _konumlar = const [];
  String? _kendiId;
  String? _token;
  String? _baseUrl;
  bool _patron = false;

  @override
  void initState() {
    super.initState();
    _metaAbone = widget.db.watchSyncState().listen(_metaUygula);
  }

  @override
  void dispose() {
    _metaAbone?.cancel();
    _zamanlayici?.cancel();
    super.dispose();
  }

  /// Rol/oturum değiştikçe katman kendini AÇAR ya da KAPATIR. Patronluktan çıkan bir oturumda
  /// (çıkış yapıldı, rol düştü) eldeki pinler de silinir — ekranda kalan bir pin, kapının
  /// kapandığını gizlerdi.
  void _metaUygula(SyncMetaData meta) {
    if (!mounted) return;
    final token = meta.authToken;
    _kendiId = meta.userId;
    _token = token;
    _baseUrl = Session.baseUrlOf(meta);
    _patron = meta.userRole == 'patron';

    final acik = _patron && token != null;
    if (acik && _zamanlayici == null) {
      _zamanlayici = Timer.periodic(widget.aralik, (_) => unawaited(_tazele()));
      unawaited(_tazele());
      return;
    }
    if (!acik && _zamanlayici != null) {
      _zamanlayici?.cancel();
      _zamanlayici = null;
      setState(() => _konumlar = const []);
    }
  }

  /// Canlı listeyi çeker. HATA SESSİZ: ağ yoksa ELDEKİ pinler durur ve "X dk önce" etiketleri
  /// kendiliğinden bayatlar — pinleri silmek, kuryelerin ortadan kaybolduğunu söylemek olurdu.
  Future<void> _tazele() async {
    final token = _token;
    final baseUrl = _baseUrl;
    if (!_patron || token == null || baseUrl == null) return;
    try {
      final liste = await konumApiUret(baseUrl, token).canliKonumlar();
      if (!mounted) return;
      setState(() => _konumlar = [
            for (final k in liste)
              if (k.userId != _kendiId) k,
          ]);
    } on Object {
      // Sessiz — bu katmanın kullanıcıya dönük bir hata yüzeyi yok.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_konumlar.isEmpty) return const SizedBox.shrink();
    return MarkerLayer(
      markers: [
        for (final k in _konumlar)
          Marker(
            point: LatLng(k.lat, k.lng),
            width: 108,
            height: 66,
            child: KuryePini(
              konum: k,
              onTap: () => kuryeOzetSheetAc(context, konum: k),
            ),
          ),
      ],
    );
  }
}

/// Tek kurye işaretçisi — motor ikonu + altında ad.
///
/// BAYAT (is_fresh=false) pin SOLUK GRİ çizilir ve adın altına "X dk önce" yazar. Taze pinle
/// aynı görünseydi patron 40 dakika önceki bir noktaya bakıp kuryenin orada olduğunu sanırdı;
/// pini gizlemek ise kuryenin hiç çalışmadığını söylerdi. İkisi de yalan, bu ise gerçek.
class KuryePini extends StatelessWidget {
  const KuryePini({super.key, required this.konum, required this.onTap});

  final CanliKonum konum;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final taze = konum.taze;
    final zemin = taze ? t.accent : t.muted;
    final etiketRenk = taze ? t.ink : t.muted;
    final gecen = kuryeSonGorulme(konum.bildirilenIso);

    return Semantics(
      button: true,
      label: '${kuryeRolEtiketi(konum.rol)} · ${konum.ad}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: zemin,
                shape: BoxShape.circle,
                // İnce açık halka: koyu karoların üstünde pin kaybolmasın (durak pininin kuralı).
                border: Border.all(color: t.accentInk, width: 2),
              ),
              child: SipIcon.yolIle(kKuryeMotorYolu,
                  boyut: 17, kalinlik: 2.2, renk: t.accentInk),
            ),
            const SizedBox(height: 2),
            // Ad ve süre KIRPILIR (ellipsis): uzun bir ad pinin kutusunu taşırsa harita
            // taşma çizgileriyle dolar. Metin ağaçta tam durur, yalnız görüntüsü kısalır.
            Flexible(
              child: _Etiket(
                metin: konum.ad,
                stil: SipText.metin(10.5, w: 700).copyWith(color: etiketRenk),
                zemin: t.surface.withValues(alpha: 0.86),
              ),
            ),
            if (!taze && gecen.isNotEmpty) ...[
              const SizedBox(height: 1),
              Flexible(
                child: _Etiket(
                  metin: gecen,
                  stil: SipText.metin(9.5, w: 600).copyWith(color: t.muted),
                  zemin: t.surface.withValues(alpha: 0.86),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pinin altındaki yazı — karoların üstünde okunabilmesi için yarı saydam yüzeyin üstünde
/// durur (`HaritaAtfi` ile aynı gerekçe: çıplak gri metin açık/koyu bölgelerde kayboluyordu).
class _Etiket extends StatelessWidget {
  const _Etiket({required this.metin, required this.stil, required this.zemin});

  final String metin;
  final TextStyle stil;
  final Color zemin;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: zemin, borderRadius: SipRadius.brHap),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SipSpace.sm, vertical: 1),
        child: Text(
          metin,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: stil,
        ),
      ),
    );
  }
}

/// Pine dokununca açılan küçük özet (`durakOzetSheetAc` ile aynı aile).
///
/// Bir DURAK ÖZETİ DEĞİLDİR: burada gidilecek bir kapı yok, dolayısıyla "Yol Tarifi"/"Ara" gibi
/// eylemler de yok. Patronun sorduğu tek soru şu — bu kim, ne zamandır orada, ne kadar kesin?
Future<void> kuryeOzetSheetAc(BuildContext context, {required CanliKonum konum}) =>
    sipSheet<void>(
      context,
      baslik: konum.ad,
      govde: (ctx) => KuryeOzetGovde(konum: konum),
    );

/// Özet gövdesi — sheet'ten ayrı widget: tek başına (sahte konumla) test edilebilir.
class KuryeOzetGovde extends StatelessWidget {
  const KuryeOzetGovde({super.key, required this.konum});

  final CanliKonum konum;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final gecen = kuryeSonGorulme(konum.bildirilenIso);
    final dogruluk = konum.dogrulukM;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Satir(
          ikon: SipIcons.user,
          etiket: 'Rol',
          deger: kuryeRolEtiketi(konum.rol),
          renk: t.ink,
        ),
        const SizedBox(height: SipSpace.xl),
        _Satir(
          ikon: SipIcons.clock,
          etiket: 'Son görülme',
          deger: gecen.isEmpty ? 'bilinmiyor' : gecen,
          // Bayat konum SÖNÜK yazılır: sayfada da pinle aynı şeyi söylemeli.
          renk: konum.taze ? t.ink : t.muted,
        ),
        const SizedBox(height: SipSpace.xl),
        _Satir(
          ikon: SipIcons.pin,
          etiket: 'Doğruluk',
          // "±800 m" bir konum değil bir bölgedir; gizlenirse pine olduğundan fazla güvenilir.
          // Cihaz doğruluğu BİLDİRMEDİYSE "±0 m" yazılmaz: sıfır hata payı, elimizdeki en
          // kesin ölçüm demektir — yokluğu kusursuzluk diye okumak gizlemekten beterdir.
          deger: dogruluk == null ? 'bilinmiyor' : '±${dogruluk.round()} m',
          renk: t.ink,
        ),
      ],
    );
  }
}

class _Satir extends StatelessWidget {
  const _Satir({
    required this.ikon,
    required this.etiket,
    required this.deger,
    required this.renk,
  });

  final String ikon;
  final String etiket;
  final String deger;
  final Color renk;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Row(
      children: [
        SipIcon(ikon, boyut: 15, kalinlik: 2, renk: t.muted),
        const SizedBox(width: SipSpace.lg),
        Expanded(
          child: Text(etiket, style: SipText.metin(12.5, w: 600).copyWith(color: t.ink2)),
        ),
        Text(deger, style: SipText.metin(13, w: 700).copyWith(color: renk)),
      ],
    );
  }
}
