// ARA TAHSİLAT alt sayfası (kullanıcı kararı 2026-08-06).
//
// NEDEN VAR: gün içinde kuryede çok para birikmesin diye patron kasayı KAPANIŞ BEKLEMEDEN alır.
// Gün AÇIK kalır — bu bir kapanış değildir; kurye çalışmaya devam eder ve akşam kalan nakdi
// devreder.
//
// NEDEN "FARK" ŞERİDİ YOK (kapatma sheet'inin aksine): kapanışta sayılan ile beklenen ARASINDAKİ
// fark bir mutabakat sonucudur — eksikse para kayıptır. Ara tahsilatta ise sayılan tutar SERBESTTİR:
// patron kuryede biraz para bırakabilir (para üstü için), ya da kurye o an yolda olduğu için
// kasanın yarısını verebilir. Buraya "EKSİK" damgası basmak, normal bir işi her seferinde arıza
// gibi göstermek olurdu. Onun yerine KURYEDE KALAN yazılır: bilgi aynı, suçlama yok.
//
// Kayıt yine de beklenen/fark alanlarını doldurur (`CashHandoverRepository.araTahsilat` bunu
// devir kaydıyla aynı satıra yazar) — kanıt kaybolmaz, yalnız ekran onu yargı gibi sunmaz.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'gun_kapatma_sheet.dart' show kurusaCevir;
import 'isletme_atomlari.dart';

/// Ara tahsilat sheet'inin sonucu: sayılan nakit + not. Sayım ZORUNLUDUR (null ile kapanmaz) —
/// sayılmamış bir para transferi kaydı, kimsenin doğrulayamayacağı bir rakam olurdu.
@immutable
class AraTahsilatSonucu {
  const AraTahsilatSonucu({required this.sayilan, required this.not});

  final int sayilan;
  final String not;
}

/// Kuryeden gün içi tahsilat. [beklenen] son devirden beri o kuryenin topladığı nakit (kuruş);
/// `CashHandoverRepository.onizle()` ile ÇAĞIRAN taraf hesaplar — sheet hiçbir para formülü yazmaz.
Future<AraTahsilatSonucu?> araTahsilatSheet(
  BuildContext context, {
  required String kuryeAdi,
  required int beklenen,
}) {
  return sipSheet<AraTahsilatSonucu>(
    context,
    baslik: 'Ara Tahsilat · $kuryeAdi',
    govde: (ctx) => _AraTahsilatGovdesi(kuryeAdi: kuryeAdi, beklenen: beklenen),
  );
}

class _AraTahsilatGovdesi extends StatefulWidget {
  const _AraTahsilatGovdesi({required this.kuryeAdi, required this.beklenen});

  final String kuryeAdi;
  final int beklenen;

  @override
  State<_AraTahsilatGovdesi> createState() => _AraTahsilatGovdesiState();
}

class _AraTahsilatGovdesiState extends State<_AraTahsilatGovdesi> {
  final _sayilan = TextEditingController();
  final _not = TextEditingController();

  @override
  void dispose() {
    _sayilan.dispose();
    _not.dispose();
    super.dispose();
  }

  int? get _sayilanKurus {
    final s = _sayilan.text.trim();
    if (s.isEmpty) return null;
    return kurusaCevir(s);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final sayilan = _sayilanKurus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.beklenen == 0)
          const AlanNotu(
            'Son devirden beri bu kuryede nakit görünmüyor — yine de tahsilat kaydedebilirsiniz.',
            tur: AlanNotuTuru.uyari,
          ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  'Son devirden beri beklenen',
                  style: SipText.gsSatirEtiket.copyWith(color: t.ink2),
                ),
              ),
              const SizedBox(width: SipSpace.lg),
              Text(
                sipTutar(widget.beklenen),
                style: SipText.tutar20.copyWith(color: t.ink),
              ),
            ],
          ),
        ),

        const SipFormEtiket('ALINAN NAKİT (₺)', ustBosluk: 2),
        SipInput(
          controller: _sayilan,
          ipucu: '0',
          klavye: const TextInputType.numberWithOptions(decimal: true),
          girdiFiltreleri: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,]'))],
          stil: SipText.tutar(22),
          yukseklik: 56,
          otomatikOdak: true,
          onChanged: (_) => setState(() {}),
        ),

        // KURYEDE KALAN — girilen tutarın anlık geri bildirimi. Bu çıkarma repo'da yapılamaz:
        // sağ taraf kullanıcının O AN yazdığı sayıdır, kalıcı bir rakam değil. Kaydedilen hiçbir
        // tutar buradan türemez (kayda giden yalnız [sayilan]), yani paralel hesap doğmaz.
        if (sayilan != null) _KalanSeridi(kalan: widget.beklenen - sayilan),

        const SipFormEtiket('NOT (OPSİYONEL)'),
        SipInput(controller: _not, ipucu: 'Para üstü bırakıldı, kalan akşam…', satirlar: 2),

        const SizedBox(height: SipSpace.x3),
        SipButon(
          etiket: 'Tahsilatı Al',
          ikon: SipIcons.hand,
          // Sıfır tutarlı bir tahsilat kaydı hiçbir şey anlatmaz; boş girdi gibi ele alınır.
          onTap: sayilan == null || sayilan == 0
              ? null
              : () => Navigator.of(context).pop(
                    AraTahsilatSonucu(sayilan: sayilan, not: _not.text.trim()),
                  ),
        ),
      ],
    );
  }
}

/// Tahsilattan sonra kuryede kalacak nakit. Negatifse patron beklenenden FAZLASINI almıştır
/// (kurye önceki dönemden para taşıyor olabilir) — bu da bilgidir, gizlenmez.
class _KalanSeridi extends StatelessWidget {
  const _KalanSeridi({required this.kalan});

  final int kalan;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final fazla = kalan < 0;
    return Padding(
      padding: const EdgeInsets.only(top: SipSpace.xl),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(color: t.surface2, borderRadius: SipRadius.br2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                fazla ? 'BEKLENENDEN FAZLA ALINDI' : 'KURYEDE KALAN',
                style: SipText.metin(11.5, w: 700)
                    .copyWith(color: t.ink2, letterSpacing: 0.69),
              ),
            ),
            Text(
              sipTutar(kalan.abs()),
              style: SipText.tutar(19, w: 800)
                  .copyWith(color: fazla ? t.warn : t.ink),
            ),
          ],
        ),
      ),
    );
  }
}
