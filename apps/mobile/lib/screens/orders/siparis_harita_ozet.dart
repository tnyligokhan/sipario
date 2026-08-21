// DURAK ÖZETİ — harita pinine dokununca açılan alt sayfa (kullanıcı isteği 2026-07-29).
//
// NEDEN ARADA BİR SAYFA VAR: pin doğrudan sipariş detayını açıyordu. Kurye haritaya "sıradaki
// durak ne, ne kadar tutuyor, nereye gidiyorum" diye bakar; tam detay sayfası bu üç soruyu
// vermek için fazla büyük ve geri dönmek bir dokunuş daha ister. Özet, kararı haritayı
// kaybetmeden verdirir; detay ve eylemler buradan bir dokunuş uzakta durur.
//
// SAYFA HİÇBİR KAYIT YAZMAZ: yalnız okur ve harici uygulama açar. Bu yüzden salt-okunur kipte de
// aynen çalışır — "Sipariş Detayı" düğmesinin açtığı sayfa kendi kapılarını zaten uyguluyor.
//
// EYLEMLER YENİDEN KULLANILIR (`musteri_eylemleri.dart`): `konumuHaritadaAc` ve `musteriyiAra`
// aynı `uriAcici` dikişinden geçer — testler gerçek bir uygulama açmaz, açılamayan hedefin
// gerekçesi Türkçe tek cümleyle söylenir.

import 'package:flutter/material.dart';

import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'gecen_sure_pili.dart';
import 'harita_sorgulari.dart';
import 'musteri_eylemleri.dart';
import 'order_queries.dart';

/// Özet sayfasından çıkan tek karar. Yol tarifi ve arama sayfayı KAPATMAZ (kurye harici
/// uygulamadan dönünce özeti yerinde bulur); detay ise sayfayı kapatıp yerine geçer.
enum DurakOzetSonucu { detay }

/// Pine dokununca açılan özet. `konumSecSheet` ile aynı aile (`sipSheet`).
Future<DurakOzetSonucu?> durakOzetSheetAc(
  BuildContext context, {
  required HaritaDuragi durak,
  required int sira,
}) =>
    sipSheet<DurakOzetSonucu>(
      context,
      // Başlık SÖZLEŞMEDİR: numara haritadaki pinin üstündeki rakamla aynıdır — kullanıcı
      // hangi pine dokunduğunu sayfada da görmeli (yanlış pine dokunmak sık ve sessiz bir hata).
      baslik: '$sira. durak: ${durak.baslik}',
      govde: (ctx) => DurakOzetGovde(durak: durak),
    );

/// Özet gövdesi — sheet'ten ayrı bir widget: tek başına (sahte durakla) test edilebilir.
class DurakOzetGovde extends StatelessWidget {
  const DurakOzetGovde({super.key, required this.durak});

  final HaritaDuragi durak;

  /// Eylemi çalıştırır, gerekçe dönerse duyurur (`MusteriEylemSeridi` ile aynı kural: başarıda
  /// susulur — hedef uygulama zaten öne gelir).
  Future<void> _calistir(BuildContext context, Future<String?> Function() eylem) async {
    final gerekce = await eylem();
    if (gerekce == null || !context.mounted) return;
    SipToast.goster(context, gerekce);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    // Telefonu ÇEVRİLEBİLİR olmayan müşteride düğme HİÇ çizilmez. Liste satırındaki şeritten
    // ayrılan tek nokta bu: orada üç düğme bir ŞERİT oluşturuyor ve biri kaybolunca hizalama
    // bozuluyordu, burada tek başına duran bir düğmeyi pasif göstermenin kimseye faydası yok.
    final telefon = telefonE164(durak.telefon);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Üst şerit: kod rozeti · bekleme süresi · saat ─────────────────────────────────
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 7,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (durak.kod != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: t.accentSoft,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(durak.kod!,
                          style: SipText.siparisKod.copyWith(color: t.accent)),
                    ),
                  // Haritadaki duraklar TANIM GEREĞİ açıktır — liste satırındaki gibi bekleme
                  // süresi gösterilir, "Açık" yazmaz (o bilgi zaten bu ekranın kendisi).
                  GecenSurePili(occurredAt: durak.occurredAt),
                ],
              ),
            ),
            const SizedBox(width: SipSpace.sm),
            SipIcon(SipIcons.clock, boyut: 12, kalinlik: 2, renk: t.muted),
            const SizedBox(width: SipSpace.xs),
            Text(saatBicimi(durak.occurredAt),
                style: SipText.saat.copyWith(color: t.muted)),
          ],
        ),
        const SizedBox(height: SipSpace.xl),

        // ── Tutar ─────────────────────────────────────────────────────────────────────────
        Text(
          sipTutar(durak.tutarKurus),
          style: SipText.satirTutarBuyuk.copyWith(color: t.ink, fontSize: 22),
        ),
        const SizedBox(height: SipSpace.xl),

        // ── Adres (liste satırındaki kutunun aynısı) ──────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            border: Border.all(color: t.line2, width: 1.5),
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: SipIcon(SipIcons.pin, boyut: 14, kalinlik: 2.2, renk: t.accent),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(durak.adres.tamMetin,
                    style: SipText.satirAdres.copyWith(color: t.ink)),
              ),
            ],
          ),
        ),

        // ── Sipariş notu — kurye kapıya varmadan ÖNCE okumalı ("zili çalma" gibi notlar) ───
        if ((durak.not ?? '').isNotEmpty) ...[
          const SizedBox(height: SipSpace.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: SipSpace.md),
            decoration: BoxDecoration(
              color: t.warnSoft,
              borderRadius: const BorderRadius.all(Radius.circular(10)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: SipIcon(SipIcons.edit, boyut: 14, kalinlik: 2.1, renk: t.warn),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: 'Sipariş Notu: ',
                        style: SipText.not.copyWith(
                            color: t.warn, fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                      TextSpan(text: durak.not!),
                    ]),
                    style: SipText.not.copyWith(color: t.ink2, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: SipSpace.x3),

        // ── Eylemler ──────────────────────────────────────────────────────────────────────
        // "Yol Tarifi" BİRİNCİL: haritadaki bir durakta kuryenin bir sonraki hareketi budur.
        Row(
          children: [
            Expanded(
              child: SipButon(
                etiket: 'Yol Tarifi',
                ikon: SipIcons.pin,
                onTap: () => _calistir(
                  context,
                  () => konumuHaritadaAc(durak.adres, etiket: durak.baslik),
                ),
              ),
            ),
            if (telefon != null) ...[
              const SizedBox(width: SipSpace.md),
              Expanded(
                child: SipButon(
                  etiket: 'Ara',
                  ikon: SipIcons.phone,
                  tur: SipButonTuru.ikincil,
                  onTap: () => _calistir(context, () => musteriyiAra(durak.telefon)),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: SipSpace.md),
        SipButon(
          etiket: 'Sipariş Detayı',
          ikon: SipIcons.receipt,
          tur: SipButonTuru.ikincil,
          // Detay özetin YERİNE geçer: iki sayfa üst üste durursa kapatmak iki dokunuş olur.
          onTap: () => Navigator.of(context).pop(DurakOzetSonucu.detay),
        ),
      ],
    );
  }
}
