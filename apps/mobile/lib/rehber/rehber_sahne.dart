// KATMAN B — EKRAN BAŞINA İLK GİRİŞ TURU: gerçek widget'ın üstünde spot + balon.
//
// NEDEN HAZIR PAKET DEĞİL (karar 2026-09-03): `showcaseview` / `tutorial_coach_mark` gibi
// paketler işin KOLAY kısmını verir — karartma, delik, balon. Vermedikleri şey bu üründe
// zor olan kısım: hangi adım kime, hangi rolde, hangi özellik açıkken gösterilir; ne
// "görüldü" sayılır; nasıl sıfırlanır; nasıl test edilir. Üstüne paket eklemenin sabit
// bedeli var (üç kapı: analyze + test + `build apk --release`) ve İngilizce varsayılanları
// bu deponun tasarım sistemiyle çakışıyor. Spot çizimi ~200 satır; orkestrasyon bizde kalıyor.
//
// ÜÇ KURAL:
//  1. HEDEFİ OLMAYAN ADIM ATLANIR. Kuryede çizilmeyen kutuyu anlatan adım kendiliğinden
//     düşer (bkz. `rehber_hedef.dart`). Turda ayrıca rol koşulu yazmak GEREKMEZ — iki ölçütü
//     birden canlı tutmak, birinin sessizce ayrışması demektir.
//  2. "ATLA" BÜTÜN TURLARI KAPATIR, tek ekranı değil. Rehberden kurtulmak isteyen bayiye
//     her ekranda aynı düğmeyi bastırmak, rehberi bir engele çevirirdi.
//  3. KAPANAN YALNIZ KENDİLİĞİNDEN AÇILMADIR. `?` düğmesi (`RehberYardimDugmesi`) ve
//     Ayarlar → Uygulama → "Rehberi baştan göster" her zaman çalışır. Turun atlanabilir
//     olmasının bedelini ödeyen şey budur: atlanan şey KAYBOLMUYOR.
//
// ⚠️ KAYDIRMA DESTEKLENMEZ ve bu bilinçli bir sınırdır: hedef görünür alanın dışındaysa adım
// atlanır, liste kaydırılıp hedef ortaya getirilmez. Kaydırıp hizalamak tembel listelerde
// `maxScrollExtent` tahminini oynatır ve bu depoda tam olarak öyle bir kilitlenme yaşandı
// (`scrollUntilVisible`). Adımlar, ekran açıldığında GÖRÜNEN kutulara bağlanır.

import 'package:flutter/material.dart';

import '../theme/components/atoms.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'rehber_deposu.dart';
import 'rehber_hedef.dart';
import 'rehber_modeli.dart';
import 'rehber_turlari.dart';

/// Ekran açıldıktan sonra tur başlamadan önce beklenen süre.
///
/// NEDEN VAR: hedeflerin çoğu bir drift AKIŞINDAN doluyor (bento kutuları, listeler) ve ilk
/// karede henüz ağaçta değil. Beklemeden filtreleseydik neredeyse her adım "hedefi yok"
/// sayılıp atlanırdı. Testler bunu [Duration.zero] yapar.
Duration rehberGecikmesi = const Duration(milliseconds: 600);

/// Oturumdaki rol kurye mi — rehberin ANLATI seçimi.
///
/// NEDEN GLOBAL (`tutamacSagdaTercihi` deseninin ikizi): `?` düğmesi sekiz ayrı ekranın üst
/// çubuğunda yaşıyor ve hiçbiri rolü bilmiyor. Rolü sekiz ekrana ayrı ayrı parametre olarak
/// geçirmek, sekiz yerde unutulabilecek bir bağ demekti — bu depoda tam olarak öyle bir
/// unutma patronun kendi kuryelerini yönetememesine yol açtı (`rol` geçilmeyen `KuryelerEkrani`).
///
/// TEK YAZAN VARDIR: kabuk (`home_shell_durum.dart`, `sync_meta.user_role` indiğinde). Okuyanlar
/// yalnız rehber katmanıdır ve bu bir YETKİ kapısı DEĞİLDİR — yanlış tarafın bedeli bir açık
/// değil, bir yanlış cümledir. Yetki kararları her zaman `RolYetkileri`nden geçmeye devam eder.
bool rehberKuryeKipi = false;

/// Şu an açık olan sahne; aynı anda iki tur oynamasın (ekran geçişinde üst üste binebilirdi).
OverlayEntry? _acikSahne;

/// Yalnız test: açık kalmış sahneyi düşürür.
///
/// NEDEN GEREKLİ: sahne bir [OverlayEntry]dir ve widget ağacına değil OVERLAY'e bağlıdır.
/// Test ağacı yıkıldığında giriş öksüz kalır, modül düzeyindeki kilit ise açık kalırdı —
/// sonraki test "tur zaten açık" sanıp hiçbir şey çizmez ve sebebi görünmeyen bir kırmızı
/// üretirdi (bu depoda öksüz süreç/zamanlayıcı kaynaklı sahte kırmızılar defterlidir).
@visibleForTesting
void rehberSahnesiniSifirla() {
  final g = _acikSahne;
  _acikSahne = null;
  if (g != null && g.mounted) g.remove();
}

/// Turu şimdi oynatır. [zorla] `true` ise "görüldü"/"atlandı" durumuna BAKILMAZ (`?` düğmesi).
///
/// Oynatacak adım kalmazsa hiçbir şey yapmaz ve yüzeyi "görüldü" İŞARETLEMEZ: adımlar
/// hedefleri henüz monte olmadığı için elenmiş olabilir; işaretlemek turu kalıcı olarak
/// yutardı.
Future<void> rehberiOynat(
  BuildContext context,
  RehberYuzey yuzey, {
  required bool kuryeMi,
  bool zorla = false,
}) async {
  if (_acikSahne != null) return;
  if (!zorla && !rehberDeposu.otomatikOynarMi(yuzey)) return;

  final adimlar = [
    for (final a in rehberTuru(yuzey))
      if (a.kitle.kapsar(kuryeMi: kuryeMi) && (a.bagsiz || RehberKayit.varMi(a.hedef))) a,
  ];
  if (adimlar.isEmpty) return;

  final katman = Overlay.maybeOf(context, rootOverlay: true);
  if (katman == null) return; // Overlay yok (yalıtık widget testi) — sessizce vazgeç

  late final OverlayEntry giris;
  void kapat() {
    if (_acikSahne != giris) return; // zaten düşürülmüş (test sıfırlaması, ağaç yıkımı)
    _acikSahne = null;
    if (giris.mounted) giris.remove();
  }

  giris = OverlayEntry(
    builder: (_) => _Sahne(
      adimlar: adimlar,
      onBitti: () {
        kapat();
        rehberDeposu.goruldu(yuzey);
      },
      onAtla: () {
        kapat();
        // ATLAMAK DA BİR KARARDIR ve yazılır — yazılmasaydı tur her açılışta geri gelirdi
        // (kurulum sihirbazının `setup_completed_at` damgasıyla aynı gerekçe).
        rehberDeposu.tumunuAtla();
      },
    ),
  );
  _acikSahne = giris;
  katman.insert(giris);
}

/// Bir ekranı sarar ve ilk açılışında turunu KENDİLİĞİNDEN oynatır.
///
/// [aktif] `false` iken hiç oynamaz — abonelik kilidi, kurulum sihirbazı ya da ekranın henüz
/// verisiz olduğu durumlar için. Kilitli ekranda tur anlatmak, kullanamayacağı bir şeyi
/// tarif etmek olurdu.
class RehberSahne extends StatefulWidget {
  const RehberSahne({
    super.key,
    required this.yuzey,
    required this.kuryeMi,
    required this.child,
    this.aktif = true,
  });

  final RehberYuzey yuzey;
  final bool kuryeMi;
  final bool aktif;
  final Widget child;

  @override
  State<RehberSahne> createState() => _RehberSahneState();
}

class _RehberSahneState extends State<RehberSahne> {
  bool _denendi = false;

  @override
  void initState() {
    super.initState();
    _belkiOynat();
  }

  @override
  void didUpdateWidget(RehberSahne eski) {
    super.didUpdateWidget(eski);
    // Kilit kalkınca (ya da rol geç çözülünce) bir kez daha denenir: `aktif` ilk karede
    // false olup sonra true'ya dönmek bu kabukta olağandır (yetki asenkron iner).
    if (!eski.aktif && widget.aktif) _belkiOynat();
  }

  void _belkiOynat() {
    if (_denendi || !widget.aktif) return;
    if (!rehberDeposu.otomatikOynarMi(widget.yuzey)) return;
    _denendi = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // SIFIR GECİKMEDE ZAMANLAYICI KURULMAZ ve bu yalnız bir kısayol değil: widget testinin
      // sahte saatinde `Future.delayed(Duration.zero)` düz `pump()` ile ateşlenmiyor, tur
      // hiç açılmıyordu — ürün sahada doğru çalışırken testler onu göremezdi.
      if (rehberGecikmesi > Duration.zero) {
        await Future<void>.delayed(rehberGecikmesi);
      }
      if (!mounted || !widget.aktif) return;
      await rehberiOynat(context, widget.yuzey, kuryeMi: widget.kuryeMi);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Üst çubuğa konan `?` — o ekranın turunu yeniden oynatır.
///
/// KALICI YARDIMIN YARISI BUDUR (diğer yarısı `nasil_yapilir_ekrani.dart`): tur bir kez
/// görülüp unutulduğunda geri çağrılacak bir yer olmalı, yoksa "atla" düğmesi bilgiyi
/// kalıcı olarak siler.
class RehberYardimDugmesi extends StatelessWidget {
  const RehberYardimDugmesi({super.key, required this.yuzey, this.kuryeMi});

  final RehberYuzey yuzey;

  /// Verilmezse [rehberKuryeKipi] okunur — ekranların rolü ayrıca taşımasına gerek kalmaz.
  final bool? kuryeMi;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipIkonButon(
      ikon: SipIcons.info,
      ikonBoyut: 21,
      renk: t.muted,
      etiket: 'Yardım',
      onTap: () => rehberiOynat(
        context,
        yuzey,
        kuryeMi: kuryeMi ?? rehberKuryeKipi,
        zorla: true,
      ),
    );
  }
}

// ── Sahne ────────────────────────────────────────────────────────────────────────────────

class _Sahne extends StatefulWidget {
  const _Sahne({required this.adimlar, required this.onBitti, required this.onAtla});

  final List<RehberAdim> adimlar;
  final VoidCallback onBitti;
  final VoidCallback onAtla;

  @override
  State<_Sahne> createState() => _SahneState();
}

class _SahneState extends State<_Sahne> {
  int _i = 0;
  bool _gorunur = false;

  @override
  void initState() {
    super.initState();
    // Sönümlenerek girsin: karartma bir karede sertçe düşünce ekran "hata verdi" gibi duruyor.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _gorunur = true);
    });
  }

  void _ileri() {
    if (_i >= widget.adimlar.length - 1) {
      widget.onBitti();
      return;
    }
    setState(() => _i++);
  }

  @override
  Widget build(BuildContext context) {
    final adim = widget.adimlar[_i];
    final ekran = MediaQuery.sizeOf(context);
    // Hedef tur BAŞLADIKTAN SONRA da kaybolabilir (liste kaydı, akış tazelemesi). O anda adım
    // bağsıza döner — spot kaybolur ama anlatı ekranda kalır.
    final kutu = adim.bagsiz ? null : RehberKayit.kutu(adim.hedef);
    final delik = (kutu != null && _gorunurAlanda(kutu, ekran))
        ? kutu.inflate(6)
        : null;

    return AnimatedOpacity(
      opacity: _gorunur ? 1 : 0,
      duration: const Duration(milliseconds: 140),
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            // Karartma TÜM ekranı kaplar ve dokunuşu yutar: turun altındaki ekrana yanlışlıkla
            // dokunulup sipariş açılması/kaydedilmesi engellenir. Dokunmak adımı ilerletir.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _ileri,
                child: CustomPaint(painter: _KarartmaBoyaci(delik: delik)),
              ),
            ),
            _balon(context, ekran, delik, adim),
          ],
        ),
      ),
    );
  }

  /// Balonu deliğin altına ya da üstüne yerleştirir; delik yoksa ekranın ortasına.
  ///
  /// YÜKSEKLİK ÖLÇÜLMEZ: `top` yerine `bottom` verilerek üstte konumlandırma yapılır, böylece
  /// kartın kaç piksel olduğunu önceden bilmek gerekmez (metin uzunluğuna göre değişir).
  Widget _balon(BuildContext context, Size ekran, Rect? delik, RehberAdim adim) {
    final kart = _Balon(
      adim: adim,
      sira: _i + 1,
      toplam: widget.adimlar.length,
      onIleri: _ileri,
      onAtla: widget.onAtla,
    );
    final genislik = ekran.width - 2 * SipSpace.govde;
    final en = genislik > 360 ? 360.0 : genislik;

    if (delik == null) {
      return Center(child: SizedBox(width: en, child: kart));
    }

    final sol = ((delik.center.dx - en / 2)
        .clamp(SipSpace.govde, (ekran.width - en - SipSpace.govde).clamp(SipSpace.govde, double.infinity)));
    // Delik ekranın üst yarısındaysa balon ALTINA, alt yarısındaysa ÜSTÜNE gelir — balonun
    // deliği örtmemesi tek koşul; ölçüsüz bir karar olduğu için oran yeterli.
    final alta = delik.bottom < ekran.height * 0.55;
    return Positioned(
      left: sol.toDouble(),
      width: en,
      top: alta ? delik.bottom + SipSpace.xl : null,
      bottom: alta ? null : ekran.height - delik.top + SipSpace.xl,
      child: kart,
    );
  }

  /// Hedef görünür alanın içinde mi (kaydırılıp ekrandan çıkmamış).
  static bool _gorunurAlanda(Rect r, Size ekran) =>
      r.bottom > 0 && r.top < ekran.height && r.right > 0 && r.left < ekran.width;
}

/// Ekranı karartır, [delik] varsa oraya yuvarlatılmış bir pencere açar.
class _KarartmaBoyaci extends CustomPainter {
  const _KarartmaBoyaci({this.delik});

  final Rect? delik;

  @override
  void paint(Canvas canvas, Size size) {
    final boya = Paint()..color = SipTokens.scrim;
    final tam = Path()..addRect(Offset.zero & size);
    final d = delik;
    if (d == null) {
      canvas.drawPath(tam, boya);
      return;
    }
    final pencere = Path()
      ..addRRect(RRect.fromRectAndRadius(d, const Radius.circular(SipRadius.r2)));
    canvas.drawPath(Path.combine(PathOperation.difference, tam, pencere), boya);
    // İnce kenarlık: koyu temada delik ile karartma arasındaki sınır kayboluyordu.
    canvas.drawRRect(
      RRect.fromRectAndRadius(d, const Radius.circular(SipRadius.r2)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = SipTokens.onHeroStrong,
    );
  }

  @override
  bool shouldRepaint(_KarartmaBoyaci eski) => eski.delik != delik;
}

/// Anlatı kartı — sayaç · başlık · metin · [Atla] [Sonraki].
class _Balon extends StatelessWidget {
  const _Balon({
    required this.adim,
    required this.sira,
    required this.toplam,
    required this.onIleri,
    required this.onAtla,
  });

  final RehberAdim adim;
  final int sira;
  final int toplam;
  final VoidCallback onIleri;
  final VoidCallback onAtla;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final son = sira == toplam;
    // Karta dokunmak adımı İLERLETMEZ: karartmanın `onTap`i kartın altında kalıyor ve düğmeye
    // nişan alırken ıskalayan parmak turu bir adım atlatırdı.
    return GestureDetector(
      onTap: () {},
      child: SipKart(
        padding: const EdgeInsets.fromLTRB(SipSpace.x3, SipSpace.x3, SipSpace.x3, SipSpace.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Adım $sira/$toplam',
              style: SipText.metin(11, w: 700).copyWith(color: t.accent),
            ),
            const SizedBox(height: SipSpace.sm),
            Text(adim.baslik, style: SipText.metin(15.5, w: 700).copyWith(color: t.ink)),
            const SizedBox(height: SipSpace.sm),
            Text(
              adim.metin,
              style: SipText.metin(13, h: 1.45).copyWith(color: t.ink2),
            ),
            const SizedBox(height: SipSpace.x3),
            Row(
              children: [
                SipMetinButon(etiket: 'Rehberi kapat', onTap: onAtla),
                const Spacer(),
                SipButon(
                  etiket: son ? 'Bitti' : 'Sonraki',
                  genisle: false,
                  yukseklik: 40,
                  yatayPadding: 20,
                  onTap: onIleri,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
