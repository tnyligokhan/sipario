// MÜŞTERİ KARTININ "ÜRÜN TERCİHLERİ" BÖLÜMÜ (kullanıcı isteği 2026-08-18).
//
// ══ NEDEN GÖRÜNÜR OLMAK ZORUNDA ════════════════════════════════════════════════════════════
// Tercih, sipariş sheet'inde SESSİZCE uygulanan tek şeydir: bayi ürüne dokunuyor, malzemeler
// kendiliğinden seçili geliyor. Kaydedildikleri yer (adet sheet'indeki küçük bir anahtar) ile
// etkilerini gösterdikleri an (haftalar sonraki bir sipariş) arasında uzun bir mesafe var.
// Bu bölüm o mesafeyi kapatır: bayi hangi müşteride ne kayıtlı olduğunu TEK yerden görür ve
// yanlış kaydedilmiş bir tercihi silebilir.
//
// Görünür bir listesi olmayan bir hatırlama, bir süre sonra "uygulama neden hep soğansız
// yazıyor" sorusuna dönüşür — ve o soruyu soran kişinin bakacağı hiçbir yer olmazdı.
//
// ══ NEDEN SALT-OKUNUR + SİL (düzenleme yok) ════════════════════════════════════════════════
// Tercihi DÜZENLEMENİN doğru yeri sipariş anıdır: malzemeler orada ürünün güncel listesiyle,
// fiyatlarıyla ve müşterinin o anki isteğiyle birlikte durur. Burada ikinci bir düzenleyici
// açmak, aynı kararı iki ayrı bağlamda vermek olurdu. Silme ise bağlam istemez.

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../data/urun_secenekleri.dart';
import '../../repo/customer_repository.dart';
import '../../theme/components/atoms.dart';
import '../isletme/isletme_atomlari.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Müşterinin kayıtlı ürün tercihleri. Tercihi yoksa bölüm HİÇ çizilmez — boş bir "tercih yok"
/// kartı, özelliği hiç kullanmayan bayilerin (su bayii) her müşteri kartına gürültü eklerdi.
class MusteriUrunTercihleri extends StatefulWidget {
  const MusteriUrunTercihleri({
    super.key,
    required this.db,
    required this.customerId,
    required this.yazabilir,
  });

  final AppDatabase db;
  final String customerId;

  /// Silme yetkisi kapısı — çağrı ANINDA sorulur (`MusteriFavorileri` ile aynı sözleşme):
  /// abonelik salt-okunura düşmüş olabilir ve ekran o an bayat olabilir.
  final bool Function() yazabilir;

  @override
  State<MusteriUrunTercihleri> createState() => _MusteriUrunTercihleriState();
}

class _MusteriUrunTercihleriState extends State<MusteriUrunTercihleri> {
  @override
  Widget build(BuildContext context) {
    // AKIŞ, TEK ATIŞ DEĞİL: tercih sipariş sheet'inden yazılıyor ve kullanıcı sipariş verip
    // müşteri kartına döndüğünde listeyi GÜNCEL görmeli. İki tabloyu birlikte izler — tercih
    // `customers`ta, ürün adı `products`ta.
    return StreamBuilder<List<_TercihSatiri>>(
      stream: _akis(),
      builder: (context, snap) {
        final liste = snap.data ?? const <_TercihSatiri>[];
        if (liste.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SipBolumBaslik('Ürün Tercihleri', ustBosluk: 18),
            const AlanNotu(
              'Sipariş girerken bu seçimler hazır gelir',
            ),
            for (final s in liste)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _Satir(
                  satir: s,
                  onSil: () => _sil(s),
                ),
              ),
          ],
        );
      },
    );
  }

  Stream<List<_TercihSatiri>> _akis() => widget.db
      .customSelect('SELECT 1', readsFrom: {widget.db.customers, widget.db.products})
      .watch()
      .asyncMap((_) => _oku());

  Future<List<_TercihSatiri>> _oku() async {
    final tercihler = await CustomerRepository(widget.db).urunTercihleriniOku(widget.customerId);
    if (tercihler.isEmpty) return const [];

    final urunler = await (widget.db.select(widget.db.products)
          ..where((t) => t.id.isIn(tercihler.keys.toList())))
        .get();
    final indeks = {for (final u in urunler) u.id: u};

    // ÇÖZÜLEMEYEN ÜRÜN ELENİR (silinmiş ürün, henüz inmemiş katalog) — favori listesindeki
    // kuralın aynısı. "Bilinmeyen ürün" satırı çizmek, bayiye silinmiş bir ürünün tercihini
    // yönettirirdi.
    return [
      for (final e in tercihler.entries)
        if (indeks[e.key] case final urun?)
          _TercihSatiri(urunId: e.key, urunAdi: urun.name, secim: e.value),
    ];
  }

  Future<void> _sil(_TercihSatiri s) async {
    if (!widget.yazabilir()) return;
    final onay = await sipOnay(
      context,
      baslik: 'Tercih silinsin mi?',
      mesaj: '"${s.urunAdi}" için kayıtlı seçim kaldırılacak',
      onayEtiketi: 'Sil',
      tehlike: true,
    );
    if (!onay || !mounted) return;
    // BOŞ SEÇİM YAZMAK = SİLMEK (repo sözleşmesi): ayrı bir silme yolu yok, çünkü "hiçbir şey
    // değiştirme" zaten tercihin yokluğudur.
    await CustomerRepository(widget.db)
        .urunTercihiKaydet(widget.customerId, s.urunId, const SecenekSecimi());
    if (!mounted) return;
    SipToast.goster(context, 'Tercih kaldırıldı');
  }
}

class _TercihSatiri {
  const _TercihSatiri({required this.urunId, required this.urunAdi, required this.secim});
  final String urunId;
  final String urunAdi;
  final SecenekSecimi secim;
}

class _Satir extends StatelessWidget {
  const _Satir({required this.satir, required this.onSil});

  final _TercihSatiri satir;
  final VoidCallback onSil;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: SipSpace.xl),
      decoration: BoxDecoration(color: t.surface, borderRadius: SipRadius.br2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  satir.urunAdi,
                  style: SipText.metin(13.5, w: 700).copyWith(color: t.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  satir.secim.ozet(),
                  style: SipText.metin(11.5, w: 600).copyWith(color: t.muted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: SipSpace.md),
          SipIkonButon(
            ikon: SipIcons.trash,
            ikonBoyut: 16,
            renk: t.muted,
            etiket: '${satir.urunAdi} tercihini sil',
            onTap: onSil,
          ),
        ],
      ),
    );
  }
}
