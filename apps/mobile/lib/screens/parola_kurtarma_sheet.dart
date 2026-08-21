// PAROLA KURTARMA — giriş ekranından açılan sheet (kullanıcı isteği 2026-08-13).
//
// ══ NEDEN VAR ═══════════════════════════════════════════════════════════════════════════════
// Mobilde parola kurtarma yolu HİÇ YOKTU: uygulamada "şifremi unuttum" geçen tek bir satır bile
// yoktu ve kullanıcı parolasını unuttuğunda yapabildiği tek şey birini aramaktı. Pilot bayilerde
// bu, birinci sıradaki destek çağrısıdır.
//
// ══ NEDEN İKİ GERÇEK BAŞTAN YAZILIYOR ══════════════════════════════════════════════════════
// Bu üründe her kullanıcının e-postası GERÇEK DEĞİLDİR:
//   • PATRON gerçek bir adresle kayıtlıdır → sıfırlama bağlantısı ona gider.
//   • KURYE/OPERATÖR adresi sentetiktir (`<kullanıcı>@<kod>.sipario.local`) → o adrese giden
//     posta hiçbir yere ulaşmaz; parolalarını bayi yöneticisi belirler.
//
// Sunucu bu ayrımı CEVABINDA SÖYLEYEMEZ: "bu hesap kurye" demek, geçerli firma kodu + kullanıcı
// adı çiftlerinin numaralandırılmasına kapı açardı (giriş ekranının nötr hata kuralının aynısı).
// Yanıt her koşulda aynıdır. Dolayısıyla ayrım EKRANDA, İSTEKTEN ÖNCE anlatılır — cevaptan
// öğrenilemeyecek bir şeyi baştan söylemek hem dürüst hem güvenlidir. Aksi hâlde kurye
// bağlantıyı bekler, hiç gelmez ve "uygulama bozuk" der.

import 'package:flutter/material.dart';

import '../auth/auth_api.dart';
import '../auth/session.dart';
import '../theme/components/atoms.dart';
import '../theme/components/overlays.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'isletme/isletme_atomlari.dart';

/// Giriş ekranındaki "Parolamı unuttum" akışını açar.
///
/// [firmaKodu] / [kullaniciAdi] giriş formundan ÖN DOLDURULUR: kullanıcı zaten yazmıştır ve
/// aynı iki alanı ikinci kez istemek, kurtarma yolunu gereksiz yere zorlaştırırdı.
Future<void> parolaKurtarmaAc(
  BuildContext context, {
  required Session session,
  String firmaKodu = '',
  String kullaniciAdi = '',
}) {
  return sipSheet<void>(
    context,
    baslik: 'Parolamı unuttum',
    govde: (ctx) => _Govde(
      session: session,
      firmaKodu: firmaKodu,
      kullaniciAdi: kullaniciAdi,
    ),
  );
}

class _Govde extends StatefulWidget {
  const _Govde({
    required this.session,
    required this.firmaKodu,
    required this.kullaniciAdi,
  });

  final Session session;
  final String firmaKodu;
  final String kullaniciAdi;

  @override
  State<_Govde> createState() => _GovdeState();
}

class _GovdeState extends State<_Govde> {
  late final _firma = TextEditingController(text: widget.firmaKodu);
  late final _kullanici = TextEditingController(text: widget.kullaniciAdi);

  bool _busy = false;
  String? _hata;

  /// Sunucunun döndüğü NÖTR metin; doluysa form yerine sonuç gösterilir.
  String? _sonuc;

  @override
  void dispose() {
    _firma.dispose();
    _kullanici.dispose();
    super.dispose();
  }

  Future<void> _gonder() async {
    if (_busy) return;
    final firma = _firma.text.trim();
    final kullanici = _kullanici.text.trim();
    if (firma.isEmpty || kullanici.isEmpty) {
      setState(() => _hata = 'Firma kodu ve kullanıcı adını girin');
      return;
    }

    setState(() {
      _busy = true;
      _hata = null;
    });
    try {
      final mesaj = await widget.session.parolaSifirlamaIste(
        tenantCode: firma,
        username: kullanici,
      );
      if (mounted) setState(() => _sonuc = mesaj);
    } on AuthException catch (e) {
      if (mounted) setState(() => _hata = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;

    if (_sonuc != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SipIkonKutu(
                ikon: SipIcons.check,
                cap: 34,
                ikonBoyut: 17,
                kalinlik: 2.4,
                zemin: t.okSoft,
                renk: t.ok,
              ),
              const SizedBox(width: SipSpace.lg),
              Expanded(
                child: Text(
                  'İsteğiniz alındı',
                  style: SipText.metin(15, w: 800).copyWith(color: t.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: SipSpace.lg),
          // SUNUCUNUN METNİ OLDUĞU GİBİ BASILIR: nötr kalması gereken cümleyi burada yeniden
          // yazmak, iki yerde ayrışabilen iki metin demekti.
          Text(
            _sonuc!,
            style: SipText.metin(12.5, w: 500, h: 1.5).copyWith(color: t.ink2),
          ),
          const SizedBox(height: SipSpace.x3),
          SipButon(
            etiket: 'Tamam',
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // İKİ GERÇEK, İSTEKTEN ÖNCE. Sunucu ayrımı söyleyemez (numaralandırma); söyleyecek
        // olan bu ekrandır.
        _Yol(
          ikon: SipIcons.user,
          renk: t.accent,
          baslik: 'İşletme sahibiyseniz',
          metin: 'Kayıtlı e-posta adresinize sıfırlama bağlantısı gönderilir',
        ),
        const SizedBox(height: SipSpace.md),
        _Yol(
          ikon: SipIcons.truck,
          renk: t.muted,
          baslik: 'Kurye ya da tezgâhta çalışıyorsanız',
          metin: 'Parolanızı işletme sahibi belirler, sıfırlama için ona başvurun',
        ),

        const SipFormEtiket('FİRMA KODU', ustBosluk: 18),
        SipInput(
          controller: _firma,
          ipucu: 'ozpinar',
          aktif: !_busy,
          buyukHarfKipi: TextCapitalization.none,
        ),
        const SipFormEtiket('KULLANICI ADI'),
        SipInput(
          controller: _kullanici,
          ipucu: 'patron',
          aktif: !_busy,
          buyukHarfKipi: TextCapitalization.none,
          onSubmitted: (_) => _gonder(),
        ),

        if (_hata != null)
          Padding(
            padding: const EdgeInsets.only(top: SipSpace.md),
            child: AlanNotu(_hata!, tur: AlanNotuTuru.uyari),
          ),

        const SizedBox(height: SipSpace.x3),
        SipButon(
          etiket: 'Sıfırlama Bağlantısı Gönder',
          yukleniyor: _busy,
          onTap: _gonder,
        ),
        // Düğme sheet'in en dibine YAPIŞMASIN: önizlemede alt kenara değiyordu ve jest çubuğu
        // olan cihazlarda parmağın altında kalırdı.
        const SizedBox(height: SipSpace.md),
      ],
    );
  }
}

/// "Yöneticiyseniz / Kuryeyseniz" satırı — renkli ikon + başlık + tek cümle.
class _Yol extends StatelessWidget {
  const _Yol({
    required this.ikon,
    required this.renk,
    required this.baslik,
    required this.metin,
  });

  final String ikon;
  final Color renk;
  final String baslik;
  final String metin;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.lg, vertical: SipSpace.lg),
      decoration: BoxDecoration(color: t.surface2, borderRadius: SipRadius.br2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: SipIcon(ikon, boyut: 16, kalinlik: 2.2, renk: renk),
          ),
          const SizedBox(width: SipSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(baslik, style: SipText.metin(12.5, w: 800).copyWith(color: t.ink)),
                const SizedBox(height: 2),
                Text(
                  metin,
                  style: SipText.metin(12, w: 500, h: 1.45).copyWith(color: t.ink2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
