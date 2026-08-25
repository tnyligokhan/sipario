// Sipariş detayının ALT BÖLÜMLERİ — not, teslimat adresi, geçmiş siparişler.
// CSS: `.srow-not`, `.sdx-adres`, `.sdx-konum`, `.gec-*`. Kaynak: s-siparisler.jsx `SiparisDetay`.
//
// Detay ekranından ayrı durur: her biri KENDİ akışına abone bağımsız bir bölüm, detayın iskeleti
// ise yalnız sipariş + satır akışını birleştirir. Ayrıca detay dosyası 500 satır sınırını aşıyordu.

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../konum/cihaz_konumu.dart';
import '../../repo/order_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../customers/customer_form_ops.dart' show konumKaydet;
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
                  etiket: not.isEmpty ? 'Not Ekle' : 'Düzenle',
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
            ipucu: 'Kapı kodu, teslim saati, özel istek',
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
          const SdxBos('Not yok')
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

/// CSS `.sdx-adres` + `.sdx-konum` — adres metni, konum durumu ve "Konum Güncelle".
///
/// "KONUM AL" (adresten kodlama) BURADA YOKTUR, "KONUM GÜNCELLE" (cihaz GPS'i) VARDIR — ikisi
/// ayrı işlerdir (2026-07-28 kararı): kodlama sokağı bulur ve bir ADAY listesi döndürür, doğrusunu
/// kullanıcı seçer; bu ekranda aday seçtirmek teslimatın ortasındaki kuryeyi bir karar ekranına
/// sokardı. Cihaz konumu ise ÖLÇÜMDÜR ve tam bu anda en doğrudur.
///
/// Kullanıcı isteği (2026-07-29): "aktif bir siparişe tıkladığımızda çıkan menüde teslimat
/// adresinin yakınında konum güncelle diye bir buton olmalı, anlık işlem yapan cihazın konumunu
/// oraya kaydetmeli." Sahadaki değeri şudur: kurye kapıyı İLK KEZ bulduğunda oradadır; o an tek
/// dokunuşla kaydedilen pin, bir daha hiçbir kuryenin aynı kapıyı aramamasını sağlar.
class AdresBolumu extends StatefulWidget {
  const AdresBolumu({
    super.key,
    required this.db,
    required this.musteriId,
    this.writable = true,
  });

  final AppDatabase db;
  final String musteriId;

  /// Salt-okunur kipte düğme çizilir ama yazmaz (sebebini söyler) — Dilim 3 kararı:
  /// ana eylemler gizlenmez, kilit sebebini söyler.
  final bool writable;

  @override
  State<AdresBolumu> createState() => _AdresBolumuState();
}

class _AdresBolumuState extends State<AdresBolumu> {
  bool _calisiyor = false;

  AppDatabase get db => widget.db;
  String get musteriId => widget.musteriId;

  /// Cihazın bulunduğu noktayı müşterinin BİRİNCİL adresine yazar.
  ///
  /// Adres metni/etiket DEĞİŞMEZ — bu akış yalnız koordinat ekler (`konumKaydet` sözleşmesi).
  /// Zayıf ölçüm sessizce kaydedilmez: kurye "konum kayıtlı" yazısına güveniyor.
  Future<void> _konumGuncelle() async {
    if (_calisiyor) return;
    if (!widget.writable) {
      SipToast.goster(context, 'Aboneliğiniz sona erdiği için konum kaydedilemiyor');
      return;
    }

    // İki ayrı `where` AND ile birleşir; `&` operatörü drift'in tam import'unu gerektirir ve
    // bu dosya yalnız `OrderingTerm` alıyor (ekran katmanı sözleşmesi).
    final sorgu = db.select(db.customerAddresses)
      ..where((t) => t.customerId.equals(musteriId))
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.isPrimary), (t) => OrderingTerm.asc(t.id)]);
    final adresler = await sorgu.get();
    if (!mounted) return;
    if (adresler.isEmpty) {
      SipToast.goster(context, 'Önce müşteriye adres ekleyin');
      return;
    }

    setState(() => _calisiyor = true);
    try {
      final konum = await cihazKonumuOku();
      await konumKaydet(db, adresler.first, konum.lat, konum.lng);
      if (!mounted) return;
      SipToast.goster(
        context,
        konum.guvenilir
            ? 'Konum güncellendi'
            : 'Konum güncellendi. ${konumDogrulukUyarisi(konum.dogrulukM)}',
      );
    } on KonumHatasi catch (e) {
      if (mounted) SipToast.goster(context, e.mesaj);
    } finally {
      if (mounted) setState(() => _calisiyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return StreamBuilder<Map<String, AdresBilgi>>(
      stream: watchBirincilAdresler(db),
      initialData: const {},
      builder: (context, snap) {
        final adres = (snap.data ?? const {})[musteriId];
        if (adres == null) {
          return const SdxBos('Adres kayıtlı değil. Müşteri detayından ekleyebilirsiniz.');
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
                          ? 'Konum kayıtlı (${adres.konumMetni})'
                          : 'Konum alınmamış',
                      style: SipText.metin(11, w: 700)
                          .copyWith(color: adres.konumVar ? t.ok : t.warn),
                    ),
                    const SizedBox(height: SipSpace.md),
                    // Düğme HER İKİ durumda da çizilir: konumu olan bir adres de yanlış olabilir
                    // (kodlamadan gelen "sokak" kesinliği) ve kurye kapının önündeyken onu
                    // düzeltebilmeli. Metin duruma göre değişir — "Güncelle" ile "Kaydet"
                    // farklı işler yapıyormuş gibi görünmesin diye tek eylem, tek ad.
                    _KonumGuncelleButonu(
                      calisiyor: _calisiyor,
                      ilk: !adres.konumVar,
                      onTap: _konumGuncelle,
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
    final dokum = satirlar.isEmpty ? '—' : satirlar.map(satirOzeti).join(', ');
    final alt = [
      saatBicimi(order.occurredAt),
      if (order.paymentType != null) odemeTipiEtiketi(order.paymentType!),
      // Kurye adı yoksa (tek kişilik bayi) alt satır saat ve ödeme olarak kalır — BRIEF gereği
      // kurye kavramı olmayan bayide boş bir ayraç bile görünmez.
      ?kuryeAdi,
    ].join(', ');

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

/// "Konum Güncelle" — cihazın bulunduğu noktayı teslimat adresine yazar.
///
/// Çalışırken metin DEĞİŞİR ve dokunuş kabul edilmez: GPS okuması saniyeler sürebilir ve
/// tepki vermeyen bir düğme sahada "bozuk" sayılıp üst üste dokunulur (her dokunuş yeni bir
/// konum isteği açardı).
class _KonumGuncelleButonu extends StatelessWidget {
  const _KonumGuncelleButonu({
    required this.calisiyor,
    required this.ilk,
    required this.onTap,
  });

  final bool calisiyor;

  /// Adreste henüz konum yok — metin "Konumu Kaydet" olur; "Güncelle" olmayan bir şeyi
  /// güncelliyormuş gibi okunurdu.
  final bool ilk;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Align(
      alignment: Alignment.centerLeft,
      child: SipDokun(
        onTap: calisiyor ? null : onTap,
        zemin: t.surface,
        basiliZemin: t.line,
        radius: SipRadius.brHap,
        padding: const EdgeInsets.symmetric(horizontal: SipSpace.lg, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SipIcon(calisiyor ? SipIcons.clock : SipIcons.pin,
                boyut: 13, kalinlik: 2.2, renk: calisiyor ? t.muted : t.accent),
            const SizedBox(width: 6),
            Text(
              calisiyor ? 'Konum alınıyor' : (ilk ? 'Konumu Kaydet' : 'Konum Güncelle'),
              style: SipText.metin(12, w: 800)
                  .copyWith(color: calisiyor ? t.muted : t.accent),
            ),
          ],
        ),
      ),
    );
  }
}
