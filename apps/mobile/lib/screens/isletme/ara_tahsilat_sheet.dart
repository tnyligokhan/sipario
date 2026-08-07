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
import 'gun_sonu_ozet.dart' show SenkronTazeligi;
import 'isletme_atomlari.dart';
import 'senkron_seridi.dart';

/// Ara tahsilat sheet'inin sonucu: sayılan nakit + not. Sayım ZORUNLUDUR (null ile kapanmaz) —
/// sayılmamış bir para transferi kaydı, kimsenin doğrulayamayacağı bir rakam olurdu.
@immutable
class AraTahsilatSonucu {
  const AraTahsilatSonucu({required this.sayilan, required this.not});

  final int sayilan;
  final String not;
}

/// Kuryeden gün içi tahsilat. [beklenen] o kuryede olması beklenen nakittir (kuruş) ve ÇAĞIRAN
/// taraf `CashHandoverRepository.onizle()`den alır — sheet hiçbir para formülü yazmaz, tanımın
/// nasıl kurulduğunu da BİLMEZ (repo tanımı 2026-08-06'da kümülatife döndü, bu dosya değişmedi).
///
/// [cerceveNotu] da çağırandan gelir: buradaki beklenen tutar kuryenin PENCERE çerçevesindendir
/// (son hesap kapanışından beri), arkasındaki ekran ise GÜN konuşur. İkisi aynı parayı
/// kapsamadığında bayi yan yana iki farklı rakam görüyordu. Metin ÇERÇEVEYİ söyler, formül değil;
/// null ise (çoğu gün) hiç çizilmez.
Future<AraTahsilatSonucu?> araTahsilatSheet(
  BuildContext context, {
  required String kuryeAdi,
  required int beklenen,
  String? cerceveNotu,
  SenkronTazeligi? senkron,
}) {
  return sipSheet<AraTahsilatSonucu>(
    context,
    baslik: 'Ara Tahsilat · $kuryeAdi',
    govde: (ctx) => _AraTahsilatGovdesi(
      kuryeAdi: kuryeAdi,
      beklenen: beklenen,
      cerceveNotu: cerceveNotu,
      senkron: senkron,
    ),
  );
}

class _AraTahsilatGovdesi extends StatefulWidget {
  const _AraTahsilatGovdesi({
    required this.kuryeAdi,
    required this.beklenen,
    required this.cerceveNotu,
    required this.senkron,
  });

  final String kuryeAdi;
  final int beklenen;

  /// Sheet'in çerçevesi ekranınkiyle çakışmıyorsa bunu söyleyen kısa satır; null ise çizilmez.
  final String? cerceveNotu;

  /// null ise tazelik şeridi çizilmez.
  final SenkronTazeligi? senkron;

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
        // Tazelik EN ÜSTTE: beklenen tutar okunmadan önce görünmeli — bu sheet'te de rakam
        // yerel `cash_handovers`tan çıkıyor ve başka telefondan alınmış bir tahsilat inmemiş
        // olabilir (o zaman beklenen ŞİŞİK görünür).
        if (widget.senkron != null) SenkronTazeligiSeridi(tazelik: widget.senkron!),

        if (widget.beklenen == 0)
          const AlanNotu(
            'Bu kuryede şu an nakit görünmüyor — yine de tahsilat kaydedebilirsiniz.',
            tur: AlanNotuTuru.uyari,
          ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  // FORMÜL İDDİA ETMEZ. Eskiden "Son devirden beri beklenen" yazıyordu; beklenen
                  // nakdin tanımı repo'da değişebilir (2026-08-06: kümülatif tanıma geçildi) ve
                  // ekranda donmuş bir formül cümlesi, değiştiği gün SESSİZCE yalan söylerdi.
                  // Etiket rakamın NE OLDUĞUNU söyler, NASIL hesaplandığını değil.
                  'Kuryede beklenen nakit',
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

        // ÇERÇEVE NOTU RAKAMIN ALTINDA: üstteki tutarın hangi aralığı kapsadığını söyler.
        if (widget.cerceveNotu != null)
          AlanNotu(widget.cerceveNotu!, tur: AlanNotuTuru.bilgi),

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
