// SİPARİŞ HARİTASININ GÖRÜNÜMÜ — tuval + kontroller + "Oto Sırala" yuvası.
//
// `siparis_harita.dart` 500 satır sınırını aştığı için ayrıldı (2026-09-29, kişi grupları
// eklenirken). Ekranın DURUMU (veri akışı, oto sıralama, kişi şeridi) orada, çizim burada.
// Dış yüzey değişmedi: `siparis_harita.dart` bu sınıfı yeniden dışa aktarır.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../sync/konum_api.dart';
import '../../theme/tokens.dart';
import 'harita_gruplari.dart';
import 'harita_icerigi.dart';
import 'harita_kontrolleri.dart';
import 'harita_kurye_katmani.dart';
import 'harita_sorgulari.dart';
import 'harita_tuvali.dart';
import 'siparis_gruplari.dart';

/// Haritanın kendisi — tuval (Yandex MapKit) + üstündeki kontroller ve "Oto Sırala".
///
/// Ekranın DURUMUNDAN ayrı bir widget: böylece harita tek başına (sahte duraklarla) test
/// edilebilir ve veri akışı ile çizim birbirine karışmaz. Görünüm motoru tanımaz; içeriği
/// [HaritaIcerigi] olarak kurar ve kamerayı [HaritaKamerasi] üzerinden sürer.
class SiparisHaritaGorunumu extends StatefulWidget {
  const SiparisHaritaGorunumu({
    super.key,
    required this.duraklar,
    required this.onDurak,
    this.cihaz,
    this.kuryeler = const [],
    this.onKurye,
    this.onKonumum,
    this.otoDugmesi,
    this.yol,
    this.gruplar,
    this.grupRenkleri = const {},
    this.kuryeRengi,
    this.grupYollari = const {},
  });

  /// Grup anahtarı → o kişinin gerçek yol çizgisi (gelenler; gelmeyen grup kuş uçuşuna düşer).
  final Map<String, List<HaritaNoktasi>> grupYollari;

  /// Kişi grupları (2026-09-29). null = tek renk, tek sıra (eski davranış); verilirse her
  /// grup kendi renginde ve kendi numarasıyla çizilir (`harita_gruplari.dart`).
  final List<SiparisGrubu<HaritaDuragi>>? gruplar;

  /// Grup anahtarı → renk.
  final Map<String, Color> grupRenkleri;

  /// Kurye kimliği → pin rengi (grubunun rengi). null = temanın vurgusu.
  final Color Function(String kullaniciId)? kuryeRengi;

  /// Durakları gerçek yollardan bağlayan çizgi — [YolCizgisiKatmani] sağlar; yoksa null ve
  /// harita kuş uçuşu kesikli çizgiye düşer.
  final List<HaritaNoktasi>? yol;

  final List<HaritaDuragi> duraklar;
  final HaritaNoktasi? cihaz;

  /// Canlı kuryeler — kapıyı [KuryeKatmani] açar; kapalıysa liste boştur.
  final List<CanliKonum> kuryeler;

  /// Alt ORTADAKİ birincil eylem ("Oto Sırala"). Widget olarak alınır ki bu görünüm ne kontörü
  /// ne de rota API'sini tanısın — çizim ile eylem ayrı kalır.
  final Widget? otoDugmesi;

  /// Dokunulan durak ve GÖRÜNEN numarası (1'den başlar) — özet sayfası başlığında aynı sayı
  /// yazar, kullanıcı hangi pine dokunduğunu doğrulayabilsin. Dönen iş bitene (özet kapanana)
  /// dek durak haritada VURGULU kalır.
  final Future<void> Function(HaritaDuragi durak, int sira) onDurak;

  final void Function(CanliKonum kurye)? onKurye;

  /// "Konumum" düğmesi: TAZE konum okur, bulduğunu döner. Kamerayı bu widget taşır, konumu
  /// okumak ve pini güncellemek ekranın işi — iki sorumluluk ayrı kalsın. `null` dönerse kamera
  /// OYNAMAZ.
  final Future<HaritaNoktasi?> Function()? onKonumum;

  /// Kadraja sığdırırken üstteki düğmelerin payı: sağda kontrol sütunu (12 + 40 çap), altta
  /// "Oto Sırala" ve gerekçesi. Pin bir düğmenin altında kalırsa dokunulamaz.
  static const EdgeInsets kenarBoslugu = EdgeInsets.fromLTRB(48, 56, 72, 120);

  /// Durak özetinin ekranın altından örttüğü pay (yaklaşık; sayfa içeriğe göre boylanır).
  /// Dokunulan pin bunun ÜSTÜNE kaydırılır.
  static const double ozetOrtusu = 0.55;

  @override
  State<SiparisHaritaGorunumu> createState() => _SiparisHaritaGorunumuState();
}

class _SiparisHaritaGorunumuState extends State<SiparisHaritaGorunumu> {
  /// Tuval hazır olunca gelir; o ana dek düğmeler sessizce hiçbir şey yapmaz (motor stilini
  /// yüklerken kamerayı oynatmak kayıp bir komuttur).
  HaritaKamerasi? _kamera;

  /// Özeti açık olan durak — pini büyür ve halelenir.
  String? _seciliId;

  List<KuryeIsareti> get _kuryeIsaretleri => [
        for (final k in widget.kuryeler)
          kuryeIsareti(k, renk: widget.kuryeRengi?.call(k.userId)),
      ];

  HaritaIcerigi _icerik() {
    final gruplar = widget.gruplar;
    if (gruplar != null) {
      return grupluIcerik(
        gruplar: gruplar,
        renkler: widget.grupRenkleri,
        cihaz: widget.cihaz,
        kuryeler: _kuryeIsaretleri,
        seciliDurakId: _seciliId,
        yol: widget.yol,
        yollar: widget.grupYollari,
      );
    }
    return _tekIcerik();
  }

  HaritaIcerigi _tekIcerik() => HaritaIcerigi(
        duraklar: [
          for (var i = 0; i < widget.duraklar.length; i++)
            DurakIsareti(
              id: widget.duraklar[i].orderId,
              no: i + 1,
              nokta: HaritaNoktasi(widget.duraklar[i].lat, widget.duraklar[i].lng),
              ad: widget.duraklar[i].baslik,
            ),
        ],
        cihaz: widget.cihaz,
        kuryeler: _kuryeIsaretleri,
        seciliDurakId: _seciliId,
        yol: widget.yol,
      );

  Future<void> _dokunuldu(HaritaDokunusu dokunus) async {
    switch (dokunus) {
      case DurakDokunusu(:final id):
        final i = widget.duraklar.indexWhere((d) => d.orderId == id);
        if (i < 0 || _seciliId != null) return; // bayat dokunuş ya da özet zaten açık
        // Özetin başlığındaki sayı PİNDE YAZAN sayıdır: gruplu haritada grubun içindeki sıra.
        final isaret = _icerik().duraklar.where((d) => d.id == id).firstOrNull;
        setState(() => _seciliId = id);
        // Özet alttan açılır; pin onun arkasında kalırsa vurgu hiç görünmez.
        final durak = widget.duraklar[i];
        unawaited(_kamera?.gorunurAlanaAl(HaritaNoktasi(durak.lat, durak.lng),
            ortulenOran: SiparisHaritaGorunumu.ozetOrtusu));
        try {
          await widget.onDurak(widget.duraklar[i], isaret?.no ?? i + 1);
        } finally {
          if (mounted) setState(() => _seciliId = null);
        }
      case KuryeDokunusu(:final id):
        for (final k in widget.kuryeler) {
          if (k.userId == id) return widget.onKurye?.call(k);
        }
    }
  }

  /// "Duraklara sığdır" — ŞU ANKİ duraklar + cihaz. Açılıştan bu yana yeni sipariş geldiyse
  /// o da kadraja girer.
  void _sigdir() {
    final kadraj = _icerik().kadraj;
    if (kadraj != null) unawaited(_kamera?.kadrajla(kadraj));
  }

  Future<void> _konumum() async {
    final nokta = await widget.onKonumum?.call();
    if (nokta == null || !mounted) return;
    // Sokak ölçeği: kurye "ben neredeyim" derken kapı numarası değil, çevresindeki birkaç sokak
    // görmek ister.
    await _kamera?.odakla(nokta, 15);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: haritaTuvaliUret(
            HaritaTuvaliAyari(
              icerik: _icerik(),
              koyu: context.sip.koyu,
              kenarBoslugu: SiparisHaritaGorunumu.kenarBoslugu,
              onDokunus: (d) => unawaited(_dokunuldu(d)),
              onHazir: (k) => _kamera = k,
            ),
          ),
        ),
        Positioned(
          right: SipSpace.xl,
          bottom: SipSpace.x4,
          child: HaritaKontrolleri(
            onYakinlas: () => unawaited(_kamera?.yakinlastir(1)),
            onUzaklas: () => unawaited(_kamera?.yakinlastir(-1)),
            onSigdir: _sigdir,
            onKonumum: () => unawaited(_konumum()),
          ),
        ),
        // Atıf ayrı bir şerit DEĞİL: Yandex logosu (lisans gereği) haritanın kendisinde, sol
        // üstte durur (`harita_yandex.dart`) — altta "Oto Sırala", sağda kontroller var.
        // "Oto Sırala" ALT ORTADA. Yatay iç boşluk 64: sağdaki kontrol sütunu (12 + 40 çap)
        // ile çakışmasın — ortalanmış düğme dar telefonda o sütunun altına girerdi.
        if (widget.otoDugmesi != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: SipSpace.x4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 64),
              child: widget.otoDugmesi!,
            ),
          ),
      ],
    );
  }
}
