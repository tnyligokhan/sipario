// GÜN SONU ekranı — tasarım s-gunsonu.jsx + Sipario.html `.gs-*`, `.segtab`, `.ys-alt`.
//
// Kapsam seçimi (Tümü / tek kurye) → kasa özeti · açık veresiye · arşiv.
// Alt çubuktan gün ya da kurye hesabı KAPATILIR; kapatma sayılan nakitle mutabakat ister ve
// kaydı arşive taşır (append-only, `day_closings` tablosu). Açık sipariş varken kapatma
// ENGELLENİR — kapanmış bir gün açık bir siparişi gizlerdi.
//
// Kasa/borç rakamları defterden TÜRETİLİR; ekran hiçbir bakiyeyi kendi hesaplamaz.
// Veri katmanı `isletme/gun_sonu_ozet.dart`, kartlar `isletme/gun_sonu_kartlari.dart` içinde
// (500 satır sınırı).
//
// ══ ROL KAPISI BURADADIR (K2) ══════════════════════════════════════════════════════════════
// Ayrı kasa devri ekranı kaldırılınca çekmecenin "Kasa Devri" satırı bu ekrana bağlandı, yani
// ekran artık KURYE trafiği de alıyor ve kabuk önünde rol kapısı TUTMUYOR. Kural:
//  • GÜN hesabını yalnız yönetici kapatır (`yetkiler().gunSonu`).
//  • Kurye YALNIZ kendi kurye hesabını kapatabilir — kendi kasasının kanıtı odur.
//  • Kurye başka kuryenin kapsamını SEÇEMEZ: segmentte yalnız "Tümü" + kendisi listelenir.
// Kurye "Tümü"yü okuyabilir (gün toplamları bilgi), ama oradan kapatma düğmesi çalışmaz.

import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../repo/day_closing_repository.dart';
import '../theme/components/atoms.dart';
import '../theme/components/overlays.dart';
import '../theme/components/states.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'isletme/gun_kapatma_sheet.dart';
import 'isletme/gun_sonu_kartlari.dart';
import 'isletme/gun_sonu_ozet.dart';
import 'isletme/isletme_atomlari.dart';
import 'team.dart';

// Veri katmanı bu ekranın genel yüzeyinin parçası olarak kalır: testler ve kabuk `bugunTr` /
// `gunSonuOzeti`yi buradan import ediyor, dosya bölünürken o imzalar kırılmasın.
export 'isletme/gun_sonu_ozet.dart'
    show bugunTr, gunSonuOzeti, GunSonuOzet, kapsamOzeti, KapsamOzeti, GunSonuGorunumu;

class DayEndScreen extends StatefulWidget {
  const DayEndScreen({
    super.key,
    required this.db,
    this.onMenu,
    this.rol,
    this.kullaniciId,
  });

  final AppDatabase db;

  /// Verilirse üst çubukta hamburger çizilir (sekme olarak açıldığında); yoksa geri oku.
  final VoidCallback? onMenu;

  /// Oturumdaki rol `patron|operator|kurye`. null → yetki verilmemiş sayılır (yönetici eylemi
  /// yok); tek başına açılan testlerde/önizlemede kapsam yine gezilebilir.
  final String? rol;

  /// Oturumdaki kullanıcı kimliği. İKİ İŞ yapar:
  ///  1. [rol] `kurye` ise ekran KENDİ KAPSAMINDA açılır (kurye çekmeceden "Kasa Devri" ile
  ///     buraya geliyor; "Tümü"de açılınca kendi devrini bulmak için segmenti elle çevirmesi
  ///     gerekiyordu).
  ///  2. Kapatma yetkisinin sahibi budur: kurye yalnız `kullaniciId == kapsam` iken kapatabilir.
  final String? kullaniciId;

  @override
  State<DayEndScreen> createState() => _DayEndScreenState();
}

class _DayEndScreenState extends State<DayEndScreen> {
  /// null = "Tümü"; aksi hâlde kuryenin kullanıcı kimliği.
  late String? _kuryeId = widget.rol == 'kurye' ? widget.kullaniciId : null;

  late DateTime _gun = bugunTr();

  // İlk yükleme de kapsamı taşır: ön seçim varken `kuryeId` geçilmezse ekran bir kare boyunca
  // gün toplamlarını kurye kapsamı etiketiyle gösteriyordu.
  late Future<GunSonuGorunumu> _gorunum =
      gunSonuGorunumu(widget.db, _gun, kuryeId: _kuryeId);

  void _tazele() {
    setState(() {
      _gun = bugunTr();
      _gorunum = gunSonuGorunumu(widget.db, _gun, kuryeId: _kuryeId);
    });
  }

  void _kapsamSec(String? kuryeId) {
    setState(() {
      _kuryeId = kuryeId;
      _gorunum = gunSonuGorunumu(widget.db, _gun, kuryeId: _kuryeId);
    });
  }

  String _kapsamAdi(List<User> kuryeler) =>
      _kuryeId == null ? 'Gün hesabı' : (kullaniciAdi(kuryeler, _kuryeId) ?? 'Kurye');

  /// Segmentte listelenecek kuryeler. Kurye YALNIZ kendini görür: başka kuryenin kasasını
  /// okumak onun işi değil (K2), ve göremediği kapsamı kapatması da mümkün olmaz.
  List<User> _gorunurKuryeler(List<User> kuryeler) => widget.rol == 'kurye'
      ? kuryeler.where((k) => k.id == widget.kullaniciId).toList()
      : kuryeler;

  /// Seçili kapsamı KAPATMA yetkisi (K2). Yönetici her kapsamı kapatır; kurye yalnız kendi
  /// kurye hesabını — gün hesabı ve başkasının hesabı ona kapalı.
  bool get _kapatabilir {
    if (yetkiler(rol: widget.rol, kuryeVar: true).gunSonu) return true;
    return _kuryeId != null && _kuryeId == widget.kullaniciId;
  }

  Future<void> _kapat(List<User> kuryeler, GunSonuGorunumu g) async {
    if (!_kapatabilir) return; // düğme zaten kapalı; çift kapı (K2 pazarlıksız)
    final kapsamAdi = _kapsamAdi(kuryeler);
    final sonuc = await gunKapatmaSheet(
      context,
      kapsamAdi: kapsamAdi,
      gunHesabi: _kuryeId == null,
      beklenen: g.kapsam.kasa.nakit,
      teslimat: g.kapsam.teslimat,
    );
    if (sonuc == null || !mounted) return;

    // Kapanış rakamları burada YENİDEN hesaplanmaz: repo submit anında kendi önizlemesini
    // çağırır, böylece arşive donan tutar ekranın gösterdiğiyle aynı koddan çıkar.
    // Fark ≠ 0 kapatmayı ENGELLEMEZ (BRIEF: eksik para görünür kalmalı) — kanıt olarak yazılır.
    await DayClosingRepository(widget.db).kapat(
      scope: _kuryeId == null ? ClosingScope.day : ClosingScope.courier,
      userId: _kuryeId,
      countedCashKurus: sonuc.sayilan,
      note: sonuc.not.isEmpty ? null : sonuc.not,
      alsoHandover: _kuryeId != null,
      localDate: _gun,
    );
    if (!mounted) return;

    SipToast.goster(
      context,
      _kuryeId == null
          ? 'Gün kapatıldı ve arşivlendi'
          : '$kapsamAdi hesabı kapatıldı ve arşivlendi',
    );
    _tazele();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<User>>(
          stream: watchAktifKuryeler(widget.db),
          builder: (context, kuryeSnap) {
            final kuryeler = kuryeSnap.data ?? const <User>[];
            final gorunur = _gorunurKuryeler(kuryeler);
            final secenekler = ['Tümü', for (final k in gorunur) k.name];

            // Seçili kapsam segmentte YOKSA (team bloğu henüz inmemiş, kurye kendi aynasında
            // görünmüyor) seçenek olarak EKLENİR. Aksi hâlde şerit "Tümü"yü işaretlerken
            // gövde kurye kapsamını gösteriyor, yani iki bileşen farklı şey söylüyordu.
            var seciliDizin = 0;
            if (_kuryeId != null) {
              final i = gorunur.indexWhere((k) => k.id == _kuryeId);
              if (i >= 0) {
                seciliDizin = i + 1;
              } else {
                secenekler.add(_kapsamAdi(kuryeler));
                seciliDizin = secenekler.length - 1;
              }
            }

            return FutureBuilder<GunSonuGorunumu>(
              future: _gorunum,
              builder: (context, snap) {
                final g = snap.data;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SipUst(
                      baslik: 'Gün Sonu',
                      alt: 'Bugün',
                      onMenu: widget.onMenu,
                      onGeri: widget.onMenu == null
                          ? () => Navigator.of(context).maybePop()
                          : null,
                    ),
                    // Kapsam segmenti HER ZAMAN çizilir — tek kurye (ya da hiç kurye) varken de
                    // "Tümü" görünür (tasarım `s-gunsonu.jsx:37-41` şeridi koşulsuzdur). Segment
                    // gizlenince kurye kapsamının varlığı keşfedilemez oluyordu.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          SipSpace.govde, 0, SipSpace.govde, SipSpace.xl),
                      child: SipSegment(
                        secenekler: secenekler,
                        secili: seciliDizin,
                        // Son seçenek "çözülemeyen kapsam" olabilir (yukarıdaki dal): ona
                        // dokunmak kapsamı DEĞİŞTİRMEZ, zaten seçili olandır.
                        onSec: (i) => _kapsamSec(i == 0
                            ? null
                            : (i - 1 < gorunur.length ? gorunur[i - 1].id : _kuryeId)),
                      ),
                    ),
                    Expanded(
                      child: g == null
                          ? const SipGovde(children: [SipIskelet(adet: 3)])
                          : _Govde(
                              gorunum: g,
                              kapsamAdi: _kapsamAdi(kuryeler),
                              gunKapsami: _kuryeId == null,
                              ekip: kuryeler,
                            ),
                    ),
                    if (g != null)
                      _AltCubuk(
                        gorunum: g,
                        kuryeAdi: _kuryeId == null ? null : _kapsamAdi(kuryeler),
                        kapatabilir: _kapatabilir,
                        onKapat: () => _kapat(kuryeler, g),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _Govde extends StatelessWidget {
  const _Govde({
    required this.gorunum,
    required this.kapsamAdi,
    required this.gunKapsami,
    required this.ekip,
  });

  final GunSonuGorunumu gorunum;

  /// Seçili kapsamın adı ("Gün hesabı" ya da kurye adı).
  final String kapsamAdi;

  final bool gunKapsami;

  /// Arşiv satırlarındaki `user_id`leri ada çevirmek için (kayıtta yalnız kimlik durur).
  final List<User> ekip;

  String _arsivAdi(DayClosing k) =>
      k.userId == null ? 'Gün hesabı' : (kullaniciAdi(ekip, k.userId) ?? 'Kurye');

  @override
  Widget build(BuildContext context) {
    final g = gorunum;
    final kasa = g.kapsam.kasa;

    return SipGovde(
      children: [
        if (g.kapsamKapali)
          KapaliSerit(
            metin: g.gunKapali
                ? 'Günün hesabı kapatıldı — tüm hesaplar kilitli.'
                : '$kapsamAdi hesabı kapatıldı ve arşivlendi.',
          ),

        SipBolumBaslik(
          gunKapsami ? 'Kasa Özeti' : 'Kasa Özeti · $kapsamAdi',
          ustBosluk: 18,
        ),
        DegerKarti(
          satirlar: [
            DegerSatiri(etiket: 'Nakit', deger: sipTutar(kasa.nakit)),
            DegerSatiri(etiket: 'Kart', deger: sipTutar(kasa.kart)),
            DegerSatiri(etiket: 'Havale', deger: sipTutar(kasa.havale)),
            DegerSatiri(
              etiket: 'Toplam Tahsilat · ${g.kapsam.teslimat} teslimat',
              deger: sipTutar(kasa.toplam),
              toplam: true,
            ),
          ],
        ),

        if (gunKapsami) ...[
          const SipBolumBaslik('Açık Veresiye', ustBosluk: 18),
          VeresiyeKarti(borc: g.ozet.borc),
        ],

        if (g.arsiv.isNotEmpty) ...[
          const SipBolumBaslik('Arşiv', ustBosluk: 18),
          for (var i = 0; i < g.arsiv.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
              child: ArsivSatiri(
                kapanis: g.arsiv[i],
                kapsamAdi: _arsivAdi(g.arsiv[i]),
                onTap: () => arsivDetaySheet(
                  context,
                  g.arsiv[i],
                  kapsamAdi: _arsivAdi(g.arsiv[i]),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// CSS `.ys-alt` — kapatma engeli · toplam · kapat düğmesi (ya da `.gs-alt-kapali`).
class _AltCubuk extends StatelessWidget {
  const _AltCubuk({
    required this.gorunum,
    required this.kuryeAdi,
    required this.kapatabilir,
    required this.onKapat,
  });

  final GunSonuGorunumu gorunum;

  /// null ise gün hesabı kapsamı.
  final String? kuryeAdi;

  /// K2: kurye gün hesabını (ve başkasının hesabını) kapatamaz. false ise düğme kapalı çizilir
  /// ve NEDENİ yazılır — sessizce devre dışı bir düğme kullanıcıya hiçbir şey söylemiyordu.
  final bool kapatabilir;

  final VoidCallback onKapat;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final g = gorunum;

    if (g.kapsamKapali) {
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
                  g.gunKapali
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
    final engel = !kapatabilir || g.kapsam.acikSiparis > 0 || g.gunEngeli;
    return AltCubuk(children: [
      if (engel)
        SizedBox(
          width: double.infinity,
          child: KapatmaEngeli(
            rolEngeli: !kapatabilir,
            acikSiparis: kapatabilir ? g.kapsam.acikSiparis : 0,
            acikKuryeler:
                !kapatabilir || g.kapsam.acikSiparis > 0 ? const [] : g.acikKuryeAdlari,
          ),
        ),
      SizedBox(
        width: 150,
        child: AltCubukToplam(
          etiket: kuryeAdi == null ? 'Bugün tahsilat' : '$kuryeAdi · tahsilat',
          deger: sipTutar(g.kapsam.kasa.toplam),
        ),
      ),
      SipButon(
        etiket: kuryeAdi == null ? 'Günü Kapat' : 'Hesabı Kapat',
        ikon: SipIcons.lock,
        genisle: false,
        yatayPadding: SipSpace.x5,
        onTap: engel ? null : onKapat,
      ),
    ]);
  }
}
