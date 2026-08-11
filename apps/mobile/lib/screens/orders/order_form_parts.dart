// Yeni Sipariş formunun ADIM gövdeleri + favori ürün şeridi.
//
// `order_form_screen.dart` 500 satır sınırını aşmıştı (616) ve üç yeni özellik daha alıyordu.
// Ekranın kendisi artık yalnız DURUMU tutar (seçili müşteri, sepet, kurye, adım); adım 1 ve
// adım 3'ün ÇİZİMİ buraya taşındı. Adım 2 ekranda kaldı: sepet satırları durumun kendisiyle
// (adet, satır notu) iç içedir ve dışarı taşımak durumu iki dosyaya yayardı.

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../repo/customer_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'order_parts.dart';
import 'order_queries.dart';
import 'order_sheets.dart';

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Favori ürünler — CSS `.ys-ekle` dilinde hap şeridi
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Bölüm başlığı. Bayinin dili: "favori" bir uygulama terimidir, "her zamanki" ise müşterinin
/// düzenli aldığı şeydir — sipariş alan kişi telefonda zaten bu cümleyi kurar.
const String favoriBolumBasligi = 'Her Zamanki Ürünler';

/// Müşterinin favori ürünleri — TEK DOKUNUŞLA sepete.
///
/// Müşteri seçili değilken ya da favorisi yokken bölüm HİÇ ÇİZİLMEZ. Boş bir kutu göstermek
/// ("henüz favori yok") sipariş girişinin en sıcak anında ekranı bir açıklamayla uzatırdı;
/// favori tanımlama yeri burası değil, müşteri kaydıdır.
///
/// Çözülemeyen id (silinmiş ürün) sorgu katmanında elenir — burada ayrıca süzülmez, iki yerde
/// süzmek iki ayrı kural demektir.
class FavoriSeridi extends StatelessWidget {
  const FavoriSeridi({
    super.key,
    required this.db,
    required this.musteriId,
    required this.onEkle,
  });

  final AppDatabase db;

  /// null = müşteri henüz seçilmedi → bölüm çizilmez.
  final String? musteriId;

  /// Sepete ekleme. Adet DAİMA 1'dir: "hızlı seçim"in tanımı tek dokunuştur; adet gerekiyorsa
  /// sepetteki stepper zaten oradadır.
  final void Function(Product urun) onEkle;

  @override
  Widget build(BuildContext context) {
    final id = musteriId;
    if (id == null) return const SizedBox.shrink();

    return StreamBuilder<List<Product>>(
      stream: watchFavoriUrunler(db, id),
      initialData: const [],
      builder: (context, snap) {
        final liste = snap.data ?? const <Product>[];
        if (liste.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SdxSec(favoriBolumBasligi, ustBosluk: SipSpace.lg),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [for (final u in liste) _FavoriHapi(urun: u, onTap: () => onEkle(u))],
            ),
          ],
        );
      },
    );
  }
}

class _FavoriHapi extends StatelessWidget {
  const _FavoriHapi({required this.urun, required this.onTap});

  final Product urun;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipDokun(
      onTap: onTap,
      zemin: t.accentSoft,
      basiliZemin: t.line2,
      radius: SipRadius.brHap,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SipIcon(SipIcons.plus, boyut: 14, kalinlik: 2.6, renk: t.accent),
          const SizedBox(width: 6),
          // Uzun ürün adı hapı ekran dışına taşımasın: test fontu ~1,8x geniştir.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Text(
              urun.name,
              style: SipText.metin(12.5, w: 700).copyWith(color: t.accent),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 7),
          Text(sipTutar(urun.unitPriceKurus),
              style: SipText.tutar(11.5).copyWith(color: t.ink2)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Adım 1 — müşteri seç
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// CSS `.ys-*` adım 1 gövdesi: arama + "Yeni müşteri ekle" + müşteri satırları.
class MusteriSecimAdimi extends StatelessWidget {
  const MusteriSecimAdimi({
    super.key,
    required this.db,
    required this.arama,
    required this.sorgu,
    required this.telefonlar,
    required this.adresler,
    required this.onSorgu,
    required this.onTemizle,
    required this.onSec,
    this.onYeniMusteri,
  });

  final AppDatabase db;
  final TextEditingController arama;
  final String sorgu;

  /// Satırdaki telefon ve adres TEK sorgudur, satır sayısıyla çoğalmaz — akışlar ekranda bir kez
  /// kurulur ve buraya verilir (arama yazılırken yeniden abone olup titremesinler).
  final Stream<Map<String, String>> telefonlar;
  final Stream<Map<String, AdresBilgi>> adresler;

  final ValueChanged<String> onSorgu;
  final VoidCallback onTemizle;
  final ValueChanged<Customer> onSec;

  /// null = salt-okunur kip (düğme pasif çizilir).
  final VoidCallback? onYeniMusteri;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding:
              const EdgeInsets.fromLTRB(SipSpace.govde, SipSpace.md, SipSpace.govde, SipSpace.xl),
          child: SipArama(
            controller: arama,
            ipucu: 'İsim ya da telefon ara…',
            onChanged: onSorgu,
            onTemizle: onTemizle,
          ),
        ),
        Expanded(
          child: StreamBuilder<Map<String, String>>(
            stream: telefonlar,
            initialData: const {},
            builder: (context, telSnap) => StreamBuilder<Map<String, AdresBilgi>>(
              stream: adresler,
              initialData: const {},
              builder: (context, adresSnap) => StreamBuilder<List<Customer>>(
                stream: watchMusteriArama(db, sorgu),
                builder: (context, snap) {
                  final liste = snap.data;
                  final tel = telSnap.data ?? const <String, String>{};
                  final adr = adresSnap.data ?? const <String, AdresBilgi>{};
                  return SipGovde(
                    altBosluk: SipSpace.x4,
                    children: [
                      // Tasarım `.ys-ekle` + `YeniMusteri` (s-siparisler.jsx:311). Buradaki
                      // "müşterisiz devam et (tezgâh satışı)" kapısı 2026-07-26'da kaldırıldı;
                      // müşterisiz siparişin GÖRÜNTÜLENMESİ duruyor (senkronla gelebilir),
                      // yalnız oluşturma yolu gitti.
                      YsEkleDugmesi(
                        etiket: 'Yeni müşteri ekle',
                        ikon: SipIcons.userPlus,
                        onTap: onYeniMusteri,
                      ),
                      const SizedBox(height: SipSpace.xl),
                      if (liste == null)
                        const SipIskelet(adet: 4)
                      else if (liste.isEmpty)
                        YsBosDurum(
                          ikon: SipIcons.users,
                          metin: sorgu.trim().isEmpty
                              ? 'Henüz müşteri yok — yukarıdan ekleyin'
                              : '"$sorgu" için müşteri yok',
                        )
                      else
                        for (final c in liste)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: MusteriSecimSatiri(
                              musteri: c,
                              telefon: tel[c.id],
                              adres: _mrowAdres(adr[c.id]),
                              onTap: () => onSec(c),
                            ),
                          ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  static MrowAdres? _mrowAdres(AdresBilgi? a) =>
      a == null ? null : MrowAdres(metin: a.tamMetin, konumVar: a.konumVar);
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Adım 3 — özet
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// CSS `.sdx-*` özet gövdesi: müşteri kartı, kalemler, sipariş notu, opsiyonel kurye.
class SiparisOzetiAdimi extends StatelessWidget {
  const SiparisOzetiAdimi({
    super.key,
    required this.musteri,
    required this.satirlar,
    required this.toplamKurus,
    required this.not,
    required this.telefonlar,
    required this.adresler,
    required this.onKalemleriDuzenle,
    required this.atamaYetkisi,
    required this.kuryeAdi,
    required this.kuryeSecili,
    required this.onKuryeSec,
  });

  final Customer? musteri;
  final List<LineDraft> satirlar;
  final int toplamKurus;
  final TextEditingController not;
  final Stream<Map<String, String>> telefonlar;
  final Stream<Map<String, AdresBilgi>> adresler;
  final VoidCallback onKalemleriDuzenle;

  /// Kurye satırı KİME görünür: atama yetkisi olana. Tek kişilik bayide satır hiç çizilmez.
  final bool atamaYetkisi;
  final String? kuryeAdi;
  final bool kuryeSecili;
  final VoidCallback onKuryeSec;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final m = musteri;
    return SipGovde(
      children: [
        const SdxSec('Müşteri', ustBosluk: SipSpace.lg),
        // CSS `.sdx-adres` — özette müşterinin TELEFONU ve ADRESİ yazar (s-siparisler.jsx:382-383).
        // Önce burada BAKİYE gösteriliyordu; siparişi teslim edecek kişinin son kontrolü
        // "doğru numara, doğru kapı" sorusudur — para teslimde konuşulur.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: SipSpace.xl),
          decoration: BoxDecoration(color: t.surface2, borderRadius: SipRadius.br2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: SipIcon(SipIcons.user, boyut: 15, kalinlik: 2.1, renk: t.accent),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m?.name ?? '',
                        style: SipText.metin(13, w: 600).copyWith(color: t.ink)),
                    if (m != null) ...[
                      const SizedBox(height: 3),
                      StreamBuilder<Map<String, String>>(
                        stream: telefonlar,
                        initialData: const {},
                        builder: (context, snap) {
                          final tel = (snap.data ?? const {})[m.id];
                          return Text(
                            (tel ?? '').isEmpty ? 'Telefon yok' : sipTelefon(tel!),
                            style: SipText.metin(11.5, w: 600).copyWith(color: t.muted),
                          );
                        },
                      ),
                      StreamBuilder<Map<String, AdresBilgi>>(
                        stream: adresler,
                        initialData: const {},
                        builder: (context, snap) {
                          final adres = (snap.data ?? const {})[m.id];
                          if (adres == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              adres.tamMetin,
                              style: SipText.metin(11.5, w: 600).copyWith(color: t.muted),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        SdxSec(
          'Kalemler',
          sag: SdxLink(etiket: 'Düzenle', onTap: onKalemleriDuzenle),
        ),
        SdKart(
          toplamKurus: toplamKurus,
          satirlar: [
            for (final l in satirlar)
              SdSatiri(
                ad: l.name,
                // Tasarım `{r.adet} {r.birim} × {fmtTL(r.fiyat)}` (s-siparisler.jsx:390).
                altMetin: l.serbest
                    ? 'tek seferlik'
                    : '${l.qty} ${l.birimEtiketi} × ${sipTutar(l.unitPriceKurus)}',
                tutarKurus: l.unitPriceKurus * l.qty,
                // Satır notu ÖZETTE de görünür: kaydetmeden önceki son kontrol, notun doğru
                // kaleme yazıldığının tek kanıtıdır.
                not: l.note,
              ),
          ],
        ),
        const SdxSec('Sipariş Notu'),
        SipInput(
          controller: not,
          ipucu: 'Kapı kodu, teslim saati, özel istek…',
          satirlar: 2,
        ),
        // ── Kurye (OPSİYONEL) ───────────────────────────────────────────────────────────
        // Saha isteği: siparişi girerken kimin götüreceği çoğu zaman zaten bellidir; onu
        // atamak için kaydedip listeye dönüp detayı açmak üç fazladan dokunuştu. Satır formun
        // SONUNDA durur — sipariş girişini uzatmaz, boş bırakılabilir ve atlanabilir.
        if (atamaYetkisi) ...[
          const SdxSec('Kurye'),
          SecimSatiri(
            etiket: kuryeAdi ?? 'Atama yok — sonra da atanabilir',
            ikon: SipIcons.truck,
            secili: kuryeSecili,
            onTap: onKuryeSec,
          ),
        ],
      ],
    );
  }
}
