// Sipario paylaşılan KATMANLAR — alt sayfa (sheet), onay diyaloğu, toast.
// Kaynak: tasarım s-bilesenler.jsx (`Sheet`, `Onay`) + Sipario.html `.sheet-*`,
// `.dia-*`, `.toast`.
//
// Material'ın hazır `showModalBottomSheet`/`AlertDialog`/`SnackBar`ı KULLANILMIYOR: tasarımın
// köşe/perde/animasyon değerleri farklı ve SnackBar alt navigasyonu itiyor. Tasarımdaki toast
// alt navigasyonun ÜSTÜNDE yüzen bir haptır.

import 'package:flutter/material.dart';

import '../icons.dart';
import '../tokens.dart';
import '../typography.dart';
import 'atoms.dart';

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Sheet — CSS `.sheet-scrim` / `.sheet`
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Alttan açılan sayfa. [tam] true ise ekranın %92'sini kaplar (CSS `.sheet.tam`),
/// aksi hâlde içeriğe göre büyür ve %88'de durur.
///
/// Dönüş değeri [Navigator.pop] ile verilen değerdir — `await sipSheet<int>(...)`.
Future<T?> sipSheet<T>(
  BuildContext context, {
  String? baslik,
  required WidgetBuilder govde,
  bool tam = false,
  bool disariTiklaKapat = true,
}) {
  final t = context.sip;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: disariTiklaKapat,
    enableDrag: disariTiklaKapat,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: SipTokens.scrim,
    builder: (ctx) => Padding(
      // Klavye açıldığında sheet yukarı taşınır (tasarımdaki form sheet'leri metin alanı taşır).
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * (tam ? 0.92 : 0.88),
        ),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: SipRadius.sheetUst,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (baslik != null) _SheetUst(baslik: baslik),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    SipSpace.govde,
                    SipSpace.md,
                    SipSpace.govde,
                    SipSpace.x5 + MediaQuery.paddingOf(ctx).bottom,
                  ),
                  child: Builder(builder: govde),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// CSS `.sheet-ust` — tutamaç + başlık + kapat düğmesi.
class _SheetUst extends StatelessWidget {
  const _SheetUst({required this.baslik});

  final String baslik;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Padding(
      padding: const EdgeInsets.fromLTRB(SipSpace.govde, 9, SipSpace.govde, 4),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 9),
            decoration: BoxDecoration(
              color: t.line2,
              borderRadius: SipRadius.brHap,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  baslik,
                  style: SipText.sheetBaslik.copyWith(color: t.ink),
                ),
              ),
              SipIkonButon(
                ikon: SipIcons.x,
                cap: 34,
                ikonBoyut: 20,
                kalinlik: 2.2,
                zemin: t.surface2,
                renk: t.muted,
                etiket: 'Kapat',
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Onay diyaloğu — CSS `.dia-scrim` / `.dia`
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// İki düğmeli onay. `true` döndüyse kullanıcı onayladı.
/// [tehlike] true ise onay düğmesi danger olur (silme, iptal, çıkış).
Future<bool> sipOnay(
  BuildContext context, {
  required String baslik,
  String? mesaj,
  String onayEtiketi = 'Onayla',
  String vazgecEtiketi = 'Vazgeç',
  bool tehlike = false,
}) async {
  final t = context.sip;
  final sonuc = await showDialog<bool>(
    context: context,
    barrierColor: SipTokens.scrim,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 330),
          child: Material(
            color: t.surface,
            borderRadius: SipRadius.br3,
            child: Padding(
              padding: const EdgeInsets.all(SipSpace.x4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    baslik,
                    style: SipText.diyalogBaslik.copyWith(color: t.ink),
                  ),
                  if (mesaj != null) ...[
                    const SizedBox(height: 7),
                    Text(
                      mesaj,
                      style: SipText.diyalogMesaj.copyWith(color: t.ink2),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: SipButon(
                          etiket: vazgecEtiketi,
                          tur: SipButonTuru.ikincil,
                          onTap: () => Navigator.of(ctx).pop(false),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: SipButon(
                          etiket: onayEtiketi,
                          tur: tehlike
                              ? SipButonTuru.tehlike
                              : SipButonTuru.birincil,
                          onTap: () => Navigator.of(ctx).pop(true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return sonuc ?? false;
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Toast — CSS `.toast`
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Tasarımdaki `ping()` — alt navigasyonun üstünde 2,2 sn duran hap bildirim.
///
/// [OverlayEntry] ile çizilir; SnackBar KULLANILMAZ çünkü SnackBar alt navigasyonu iter ve
/// tasarımın hap biçimini/konumunu tutturamaz. Üst üste çağrılırsa öncekini düşürür.
class SipToast {
  SipToast._();

  static OverlayEntry? _acik;
  static int _sira = 0;

  static void goster(BuildContext context, String mesaj) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _acik?.remove();
    _acik = null;
    final benimSiram = ++_sira;

    final t = context.sip;
    final altBosluk = MediaQuery.paddingOf(context).bottom;
    final girdi = OverlayEntry(
      builder: (ctx) => Positioned(
        left: 16,
        right: 16,
        bottom: 96 + altBosluk,
        child: IgnorePointer(
          child: Center(
            child: _ToastGovde(mesaj: mesaj, zemin: t.toastFill, murekkep: t.toastInk),
          ),
        ),
      ),
    );
    _acik = girdi;
    overlay.insert(girdi);

    Future.delayed(const Duration(milliseconds: 2200), () {
      if (_sira != benimSiram) return; // araya yeni toast girdi
      girdi.remove();
      if (identical(_acik, girdi)) _acik = null;
    });
  }

  /// Ekran kapanırken açık toast varsa temizle (yetim OverlayEntry bırakma).
  static void temizle() {
    _acik?.remove();
    _acik = null;
    _sira++;
  }
}

class _ToastGovde extends StatefulWidget {
  const _ToastGovde({
    required this.mesaj,
    required this.zemin,
    required this.murekkep,
  });

  final String mesaj;
  final Color zemin;
  final Color murekkep;

  @override
  State<_ToastGovde> createState() => _ToastGovdeState();
}

class _ToastGovdeState extends State<_ToastGovde>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // CSS @keyframes tIn — 8px aşağıdan yukarı + solukluk.
    return FadeTransition(
      opacity: _c,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.35),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut)),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: SipSpace.x4, vertical: SipSpace.xl),
            decoration: BoxDecoration(
              color: widget.zemin,
              borderRadius: SipRadius.brHap,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x80000000),
                  blurRadius: 30,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Text(
              widget.mesaj,
              style: SipText.toast.copyWith(color: widget.murekkep),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
