// Gün sonu KAPATMA ve ARŞİV DETAYI alt sayfaları — tasarım s-gunsonu.jsx içindeki
// iki `Sheet` + Sipario.html `.kd-*` (kasa devri) ve `.gs-*` sınıfları.
//
// Kapatma sheet'i, gün/kurye hesabını sayılan nakitle mutabık kılıp arşive taşır. FARK ≠ 0
// KAPATMAYI ENGELLEMEZ (BRIEF: eksik para görünür kalmalı) — kanıt olarak arşive yazılır.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_database.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'isletme_atomlari.dart';

/// Kapatma sheet'inin sonucu: sayılan nakit (girilmediyse null) + not.
@immutable
class KapatmaSonucu {
  const KapatmaSonucu({required this.sayilan, required this.not});

  final int? sayilan;
  final String not;
}

/// Hesabı kapat · kasa devri. [beklenen] o kapsamın beklenen nakiti (kuruş).
Future<KapatmaSonucu?> gunKapatmaSheet(
  BuildContext context, {
  required String kapsamAdi,
  required bool gunHesabi,
  required int beklenen,
  required int teslimat,
}) {
  return sipSheet<KapatmaSonucu>(
    context,
    baslik: 'Hesabı Kapat · Kasa Devri',
    govde: (ctx) => _KapatmaGovdesi(
      kapsamAdi: kapsamAdi,
      gunHesabi: gunHesabi,
      beklenen: beklenen,
      teslimat: teslimat,
    ),
  );
}

class _KapatmaGovdesi extends StatefulWidget {
  const _KapatmaGovdesi({
    required this.kapsamAdi,
    required this.gunHesabi,
    required this.beklenen,
    required this.teslimat,
  });

  final String kapsamAdi;
  final bool gunHesabi;
  final int beklenen;
  final int teslimat;

  @override
  State<_KapatmaGovdesi> createState() => _KapatmaGovdesiState();
}

class _KapatmaGovdesiState extends State<_KapatmaGovdesi> {
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
    final fark = sayilan == null ? 0 : sayilan - widget.beklenen;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.teslimat == 0)
          const AlanNotu(
            'Bu hesapta bugün hiç teslimat yok — yine de kapatabilirsiniz.',
            tur: AlanNotuTuru.uyari,
          ),

        // CSS `.kd-row`
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  widget.gunHesabi
                      ? 'Beklenen nakit'
                      : 'Beklenen nakit (${widget.kapsamAdi})',
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

        const SipFormEtiket('SAYILAN NAKİT (₺)', ustBosluk: 2),
        // CSS `.kd-input` — 56 yüksek, 22 punto rakam.
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

        if (sayilan != null) FarkSeridi(fark: fark),
        if (sayilan != null && fark < 0)
          Padding(
            padding: const EdgeInsets.only(top: SipSpace.xl),
            child: SipNotKutusu(
              tur: SipNotTuru.hata,
              ikon: SipIcons.alert,
              metin: 'Eksik tutar kanıt olarak arşive geçer; kapatma engellenmez.',
            ),
          ),

        const SipFormEtiket('NOT (OPSİYONEL)'),
        SipInput(controller: _not, ipucu: 'Fark açıklaması, devreden…', satirlar: 2),

        const SizedBox(height: SipSpace.x3),
        SipButon(
          etiket: 'Kapat ve Arşivle',
          ikon: SipIcons.lock,
          onTap: sayilan == null
              ? null
              : () => Navigator.of(context).pop(
                    KapatmaSonucu(sayilan: sayilan, not: _not.text.trim()),
                  ),
        ),
      ],
    );
  }
}

/// CSS `.kd-fark` — tam / eksik / fazla şeridi. Kasa devri ekranı da aynısını kullanır.
class FarkSeridi extends StatelessWidget {
  const FarkSeridi({super.key, required this.fark});

  final int fark;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final (etiket, renk, zemin) = switch (fark) {
      < 0 => ('EKSİK', t.danger, t.dangerSoft),
      > 0 => ('FAZLA', t.warn, t.warnSoft),
      _ => ('TAM', t.ok, t.okSoft),
    };
    return Padding(
      padding: const EdgeInsets.only(top: SipSpace.xl),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(color: zemin, borderRadius: SipRadius.br2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                etiket,
                style: SipText.metin(11.5, w: 700)
                    .copyWith(color: renk, letterSpacing: 0.69),
              ),
            ),
            Text(
              sipTutar(fark.abs()),
              style: SipText.tutar(19, w: 800).copyWith(color: renk),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Arşiv detayı
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Arşivlenmiş kapanışı kuruşu kuruşuna geri okur. [kapsamAdi] gün hesabında "Gün hesabı",
/// kurye kapanışında kuryenin adıdır (kayıtta yalnız `user_id` durur, ad `users` aynasından çözülür).
Future<void> arsivDetaySheet(
  BuildContext context,
  DayClosing k, {
  required String kapsamAdi,
}) {
  return sipSheet<void>(
    context,
    baslik: '$kapsamAdi · Arşiv',
    govde: (ctx) => _ArsivDetay(kapanis: k),
  );
}

class _ArsivDetay extends StatelessWidget {
  const _ArsivDetay({required this.kapanis});

  final DayClosing kapanis;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final k = kapanis;
    final fark = k.diffKurus;
    final farkRengi = fark < 0 ? t.danger : (fark > 0 ? t.warn : t.ok);
    final not = (k.note ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KapaliSerit(
          metin: '${gunSaatBicimi(k.occurredAt)} · kapatıldı · ${k.deliveryCount} teslimat',
          ikon: SipIcons.lock,
        ),
        const SizedBox(height: SipSpace.xl),
        DegerKarti(
          satirlar: [
            DegerSatiri(etiket: 'Nakit', deger: sipTutar(k.cashNakitKurus)),
            DegerSatiri(etiket: 'Kart', deger: sipTutar(k.cashKartKurus)),
            DegerSatiri(etiket: 'Havale', deger: sipTutar(k.cashHavaleKurus)),
            DegerSatiri(
              etiket: 'Toplam Tahsilat',
              deger: sipTutar(k.totalCollectedKurus),
              toplam: true,
            ),
          ],
        ),
        const SizedBox(height: SipSpace.lg),
        DegerKarti(
          satirlar: [
            DegerSatiri(etiket: 'Beklenen nakit', deger: sipTutar(k.expectedCashKurus)),
            DegerSatiri(
              etiket: 'Sayılan nakit',
              deger: k.countedCashKurus == null ? '—' : sipTutar(k.countedCashKurus!),
            ),
            DegerSatiri(
              etiket: 'Fark',
              deger: fark == 0 ? 'Tam' : sipTutar(fark),
              degerRengi: farkRengi,
            ),
          ],
        ),
        if (not.isNotEmpty) ...[
          const SizedBox(height: SipSpace.lg),
          SipNotKutusu(metin: not),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Paylaşılan küçük parçalar
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// CSS `.gs-kapali` — yeşil zeminli "kapatıldı" şeridi.
class KapaliSerit extends StatelessWidget {
  const KapaliSerit({super.key, required this.metin, this.ikon = SipIcons.check});

  final String metin;
  final String ikon;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: 11),
      decoration: BoxDecoration(color: t.okSoft, borderRadius: SipRadius.br2),
      child: Row(
        children: [
          SipIcon(ikon, boyut: 15, kalinlik: 2.2, renk: t.ok),
          const SizedBox(width: SipSpace.md),
          Expanded(
            child: Text(
              metin,
              style: SipText.metin(12.5, w: 700).copyWith(color: t.ok),
            ),
          ),
        ],
      ),
    );
  }
}

/// "45" → 4500 · "45,5" → 4550. Geçersizse null (para: sessiz yuvarlama YOK).
int? kurusaCevir(String metin) {
  final s = metin.trim().replaceAll('.', '');
  if (s.isEmpty) return null;
  final parcalar = s.split(',');
  if (parcalar.length > 2) return null;
  final lira = int.tryParse(parcalar[0].isEmpty ? '0' : parcalar[0]);
  if (lira == null) return null;
  if (parcalar.length == 1) return lira * 100;
  final kurusMetni = parcalar[1];
  if (kurusMetni.isEmpty) return lira * 100;
  if (kurusMetni.length > 2) return null;
  if (int.tryParse(kurusMetni) == null) return null;
  return lira * 100 + int.parse(kurusMetni.padRight(2, '0'));
}

/// ISO8601 → "Bugün 18:05" · "Dün 09:20" · "24.07 18:05" (tasarım `s-gunsonu.jsx:85` `{a.tarih}`).
///
/// Arşiv birden çok günün kapanışını taşır; yalnız saat basılınca (eski `saatBicimiKisa`)
/// satırlar birbirinden ayırt edilemiyordu. TR +03:00 sabit offset — gün sınırı kuralıyla aynı.
/// [simdi] yalnız test içindir.
String gunSaatBicimi(String iso, {DateTime? simdi}) {
  final t = DateTime.tryParse(iso);
  if (t == null) return iso;
  final tr = _trAn(t);
  final ref = _trAn(simdi ?? DateTime.now());
  final fark = DateTime(ref.year, ref.month, ref.day)
      .difference(DateTime(tr.year, tr.month, tr.day))
      .inDays;
  final saat = '${_iki(tr.hour)}:${_iki(tr.minute)}';
  // İleri tarihli kayıt (cihaz saati geri alınmış) gün.ay ile basılır — "-3 gün" saçmalığı yok.
  if (fark == 0) return 'Bugün $saat';
  if (fark == 1) return 'Dün $saat';
  return '${_iki(tr.day)}.${_iki(tr.month)} $saat';
}

/// Kapanış zamanları TR gününe göre okunur (gün sınırı kuralı: sabit +03:00).
DateTime _trAn(DateTime t) => t.toUtc().add(const Duration(hours: 3));

String _iki(int n) => n.toString().padLeft(2, '0');
