// Sipariş detayının ALT BÖLÜMLERİ — not, teslimat adresi, geçmiş siparişler.
// CSS: `.srow-not`, `.sdx-adres`, `.sdx-konum`, `.gec-*`. Kaynak: s-siparisler.jsx `SiparisDetay`.
//
// Detay ekranından ayrı durur: her biri KENDİ akışına abone bağımsız bir bölüm, detayın iskeleti
// ise yalnız sipariş + satır akışını birleştirir. Ayrıca detay dosyası 500 satır sınırını aşıyordu.

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../repo/order_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../team.dart';
import 'order_parts.dart';
import 'order_queries.dart';

/// "Sipariş Notu" bölümü — yerinde düzenleme (CSS `.s-textarea` + `.sdx-duzen-btns`).
class NotBolumu extends StatefulWidget {
  const NotBolumu({
    super.key,
    required this.db,
    required this.order,
    required this.duzenlenebilir,
  });

  final AppDatabase db;
  final Order order;
  final bool duzenlenebilir;

  @override
  State<NotBolumu> createState() => _NotBolumuState();
}

class _NotBolumuState extends State<NotBolumu> {
  final _taslak = TextEditingController();
  bool _duzenle = false;

  @override
  void dispose() {
    _taslak.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final not = widget.order.note ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SdxSec(
          'Sipariş Notu',
          sag: (!_duzenle && widget.duzenlenebilir)
              ? SdxLink(
                  etiket: not.isEmpty ? '+ Not Ekle' : 'Düzenle',
                  onTap: () => setState(() {
                    _taslak.text = not;
                    _duzenle = true;
                  }),
                )
              : null,
        ),
        if (_duzenle) ...[
          SipInput(
            controller: _taslak,
            ipucu: 'Kapı kodu, teslim saati, özel istek…',
            satirlar: 2,
            otomatikOdak: true,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: SipSpace.xl),
            child: Row(
              children: [
                Expanded(
                  child: SipButon(
                    etiket: 'Vazgeç',
                    tur: SipButonTuru.ikincil,
                    yukseklik: 44,
                    onTap: () => setState(() => _duzenle = false),
                  ),
                ),
                const SizedBox(width: SipSpace.md),
                Expanded(
                  child: SipButon(etiket: 'Notu Kaydet', yukseklik: 44, onTap: _kaydet),
                ),
              ],
            ),
          ),
        ] else if (not.isEmpty)
          const SdxBos('Not yok.')
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: SipSpace.md),
            decoration: BoxDecoration(color: t.warnSoft, borderRadius: SipRadius.br1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: SipIcon(SipIcons.edit, boyut: 14, kalinlik: 2.1, renk: t.warn),
                ),
                const SizedBox(width: 7),
                Expanded(child: Text(not, style: SipText.not.copyWith(color: t.ink2))),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _kaydet() async {
    final yeni = _taslak.text.trim();
    setState(() => _duzenle = false);
    await OrderRepository(widget.db).setNote(widget.order.id, yeni.isEmpty ? null : yeni);
    if (!mounted) return;
    SipToast.goster(context, yeni.isEmpty ? 'Not silindi' : 'Not kaydedildi');
  }
}

/// CSS `.sdx-adres` + `.sdx-konum` — adres metni ve konum durumu.
/// "Konum Al" düğmesi ÇİZİLMEZ: tasarımda bir coğrafi kodlama servisinin aday listesini açıyordu;
/// bizde böyle bir servis yok ve offline-first sözüyle çelişir. Konum müşteri detayından girilir.
class AdresBolumu extends StatelessWidget {
  const AdresBolumu({super.key, required this.db, required this.musteriId});

  final AppDatabase db;
  final String musteriId;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return StreamBuilder<Map<String, AdresBilgi>>(
      stream: watchBirincilAdresler(db),
      initialData: const {},
      builder: (context, snap) {
        final adres = (snap.data ?? const {})[musteriId];
        if (adres == null) {
          return const SdxBos('Adres kayıtlı değil — müşteri detayından ekleyin.');
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: SipSpace.xl),
          decoration: BoxDecoration(color: t.surface2, borderRadius: SipRadius.br2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: SipIcon(SipIcons.pin,
                    boyut: 15, kalinlik: 2.1, renk: adres.konumVar ? t.ok : t.muted),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(adres.tamMetin,
                        style: SipText.metin(13, w: 600, h: 1.45).copyWith(color: t.ink)),
                    const SizedBox(height: 3),
                    Text(
                      adres.konumVar
                          ? 'Konum kayıtlı · ${adres.konumMetni}'
                          : 'Konum alınmamış',
                      style: SipText.metin(11, w: 700)
                          .copyWith(color: adres.konumVar ? t.ok : t.warn),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// CSS `.gec-*` — aynı müşterinin geçmiş siparişleri (bu sipariş hariç, en yeni önce).
///
/// Satır KALEM DÖKÜMÜ ve KURYE gerektirdiği için iki yardımcı akışa daha abone olur; ikisi de
/// tek sorgu (sipariş başına gruplu satırlar + ekip listesi), satır sayısıyla çoğalmaz.
class GecmisBolumu extends StatelessWidget {
  const GecmisBolumu({
    super.key,
    required this.db,
    required this.musteriId,
    required this.orderId,
  });

  final AppDatabase db;
  final String musteriId;
  final String orderId;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return StreamBuilder<List<Order>>(
      stream: watchGecmisSiparisler(db, musteriId, orderId),
      initialData: const [],
      builder: (context, snap) {
        final gecmis = snap.data ?? const <Order>[];
        if (gecmis.isEmpty) return const SizedBox.shrink();
        return StreamBuilder<Map<String, List<OrderLine>>>(
          stream: watchOrderLinesByOrder(db),
          initialData: const {},
          builder: (context, satirSnap) => StreamBuilder<List<User>>(
            stream: watchTeam(db),
            initialData: const [],
            builder: (context, ekipSnap) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SdxSec(
                  'Geçmiş Siparişler',
                  // CSS `.sdx-adet` — bölüm başlığının sağındaki sayaç.
                  sag: Text('${gecmis.length}',
                      style: SipText.metin(11, w: 700).copyWith(color: t.muted)),
                ),
                for (final g in gecmis)
                  _GecmisSatiri(
                    order: g,
                    satirlar: (satirSnap.data ?? const {})[g.id] ?? const [],
                    kuryeAdi: kullaniciAdi(ekipSnap.data ?? const [], g.assignedUserId),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// CSS `.gec-row` — ÜST satır kalem dökümü (`.gec-t` = tasarımın `siparisOzet`i), ALT satır
/// `saat · ödeme · kurye` (`.gec-s`); sağda durum pili ve tutar (s-siparisler.jsx:525-526).
///
/// Önce tam tersi çiziliyordu (üstte saat·ödeme, altta sipariş notu) — kalem dökümü ve kurye
/// hiç görünmüyordu. Geçmişe bakan kişi "geçen sefer ne almıştı" sorusunu sorar; notu değil.
class _GecmisSatiri extends StatelessWidget {
  const _GecmisSatiri({required this.order, required this.satirlar, this.kuryeAdi});

  final Order order;
  final List<OrderLine> satirlar;
  final String? kuryeAdi;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final dokum = satirlar.isEmpty ? '—' : satirlar.map(satirOzeti).join(' · ');
    final alt = [
      saatBicimi(order.occurredAt),
      if (order.paymentType != null) odemeTipiEtiketi(order.paymentType!),
      // Kurye adı yoksa (tek kişilik bayi) alt satır saat·ödeme olarak kalır — BRIEF gereği
      // kurye kavramı olmayan bayide boş bir ayraç bile görünmez.
      ?kuryeAdi,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: SipSpace.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(color: t.surface2, borderRadius: SipRadius.br2),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dokum,
                      style: SipText.metin(12.5, w: 700).copyWith(color: t.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 1),
                  Text(alt,
                      style: SipText.metin(11, w: 600).copyWith(color: t.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 9),
            SipDurumPili(durum: order.status),
            const SizedBox(width: 9),
            Text(sipTutar(order.totalKurus), style: SipText.tutar(13).copyWith(color: t.ink)),
          ],
        ),
      ),
    );
  }
}
