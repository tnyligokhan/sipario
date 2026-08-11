// MÜŞTERİ KARTINDAKİ "FAVORİ ÜRÜNLER" — görüntüleme + düzenleme yüzeyi (kullanıcı isteği
// 2026-08-11: "müşterinin her zamanki ürünleri").
//
// VERİ KATMANI BU DOSYADA DEĞİL: id listesi müşteri satırının içinde JSON olarak durur ve
// çözümlemesi TEK yerdedir (`customer_repository.dart` — `favoriIdleriCoz`, `favorileriKaydet`,
// `watchFavoriUrunler`, `kFavoriUstSinir`). Burada yalnız ekran var.
//
// ÇÖZÜLEMEYEN ID SESSİZCE ATLANIR ama SİLİNMEZ: silinmiş/pasifleştirilmiş ürünün id'si listede
// kalır (repo okuma tarafında eler). Bu yüzden bu ekranın YAZDIĞI her liste HAM listeden türer —
// yalnız görünenleri geri yazmak, pasife alınmış bir ürünü favorilerden kalıcı olarak silerdi ve
// bayi bunu ancak ürünü geri açtığında fark ederdi.

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../repo/customer_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../orders/order_queries.dart' show katalogSuz, watchKatalogUrunleri;

/// Görünür sıradaki değişikliği HAM id listesine uygular.
///
/// [gorunurYeniSira] görünen (kataloğa çözülmüş) id'lerin YENİ sırasıdır; ham listedeki
/// çözülemeyen id'ler kendi konumlarında kalır. Yalnız görünenleri geri yazan bir sürükleme,
/// görünmeyen favorileri sessizce çöpe atardı.
List<String> favoriSirasiniUygula(List<String> ham, List<String> gorunurYeniSira) {
  final kume = gorunurYeniSira.toSet();
  var i = 0;
  return [
    for (final id in ham)
      if (kume.contains(id) && i < gorunurYeniSira.length) gorunurYeniSira[i++] else id,
  ];
}

/// Müşteri kartındaki favori bölümü. [yazabilir] salt-okunur/rol kapısıdır: `false` dönerse
/// çağıran taraf gerekçeyi zaten toast'la söylemiştir, burada ikinci bir mesaj basılmaz.
class MusteriFavorileri extends StatelessWidget {
  const MusteriFavorileri({
    super.key,
    required this.db,
    required this.customerId,
    required this.yazabilir,
  });

  final AppDatabase db;
  final String customerId;
  final bool Function() yazabilir;

  static const String bosDavet = 'Her zamanki ürünlerini ekleyin';
  static const String duzenleEtiketi = 'Düzenle';
  static const String limitMesaji = 'En fazla $kFavoriUstSinir favori ürün eklenebilir';

  Future<void> _duzenle(BuildContext context) async {
    if (!yazabilir()) return;
    final repo = CustomerRepository(db);
    final mevcut = await repo.favorileriOku(customerId);
    if (!context.mounted) return;
    final secim = await sipSheet<List<String>>(
      context,
      baslik: 'Favori Ürünler',
      govde: (ctx) => _FavoriSecici(db: db, baslangic: mevcut),
    );
    if (secim == null || !context.mounted) return;
    await repo.favorileriKaydet(customerId, secim);
    if (!context.mounted) return;
    SipToast.goster(context, 'Favori ürünler güncellendi');
  }

  /// Tek ürünü listeden çıkarır. HAM liste okunur — çözülemeyen id'ler korunur.
  Future<void> _cikar(BuildContext context, Product urun) async {
    if (!yazabilir()) return;
    final repo = CustomerRepository(db);
    final ham = await repo.favorileriOku(customerId);
    await repo.favorileriKaydet(customerId, [...ham]..remove(urun.id));
    if (!context.mounted) return;
    SipToast.goster(context, '${urun.name} favorilerden çıkarıldı');
  }

  /// Ürünü bir sıra yukarı taşır — sıra bayinin tercihidir (en çok sattığı başa gelsin).
  Future<void> _yukari(BuildContext context, List<Product> gorunur, int i) async {
    if (i <= 0 || !yazabilir()) return;
    final repo = CustomerRepository(db);
    final ham = await repo.favorileriOku(customerId);
    final yeni = [for (final u in gorunur) u.id];
    final tasinan = yeni.removeAt(i);
    yeni.insert(i - 1, tasinan);
    await repo.favorileriKaydet(customerId, favoriSirasiniUygula(ham, yeni));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return StreamBuilder<List<Product>>(
      stream: CustomerRepository(db).watchFavoriUrunler(customerId),
      initialData: const [],
      builder: (context, snap) {
        final urunler = snap.data ?? const <Product>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SipBolumBaslik(
              'Favori Ürünler',
              sag: SipDokun(
                onTap: () => _duzenle(context),
                radius: SipRadius.br1,
                padding: const EdgeInsets.symmetric(vertical: SipSpace.xs),
                child: Text(
                  duzenleEtiketi,
                  style: SipText.metin(12, w: 700).copyWith(color: t.accent),
                ),
              ),
            ),
            // BOŞ DURUM KUTUSU DEĞİL, DAVET: favorisi olmayan müşteri kuraldır (her müşteride
            // baştan boştur). Büyük bir "hiçbir şey yok" kutusu, kartın yarısını hiç kullanılmamış
            // bir özelliğe ayırır; tek satırlık davet aynı şeyi söyler ve dokunulabilir.
            if (urunler.isEmpty)
              SipDokun(
                onTap: () => _duzenle(context),
                zemin: t.surface,
                radius: SipRadius.br2,
                padding: const EdgeInsets.symmetric(
                    horizontal: SipSpace.x2, vertical: 13),
                child: Row(
                  children: [
                    SipIcon(SipIcons.plus, boyut: 16, kalinlik: 2.2, renk: t.accent),
                    const SizedBox(width: SipSpace.md),
                    Expanded(
                      child: Text(
                        bosDavet,
                        style: SipText.metin(13, w: 600).copyWith(color: t.ink2),
                      ),
                    ),
                  ],
                ),
              )
            else
              for (var i = 0; i < urunler.length; i++)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : SipSpace.sm),
                  child: _FavoriSatiri(
                    urun: urunler[i],
                    ilk: i == 0,
                    onYukari: () => _yukari(context, urunler, i),
                    onCikar: () => _cikar(context, urunler[i]),
                  ),
                ),
          ],
        );
      },
    );
  }
}

/// Favori satırı — ad + birim fiyat, sağda "yukarı taşı" ve "çıkar".
class _FavoriSatiri extends StatelessWidget {
  const _FavoriSatiri({
    required this.urun,
    required this.ilk,
    required this.onYukari,
    required this.onCikar,
  });

  final Product urun;

  /// Listenin başındaki satırda "yukarı" ÇİZİLMEZ (basılınca hiçbir şey olmayan bir düğme,
  /// kullanıcıya uygulamanın bozuk olduğunu söyler).
  final bool ilk;

  final VoidCallback onYukari;
  final VoidCallback onCikar;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      decoration: BoxDecoration(color: t.surface, borderRadius: SipRadius.br2),
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: 11),
      child: Row(
        children: [
          SipIcon(SipIcons.box, boyut: 16, kalinlik: 2.1, renk: t.accent),
          const SizedBox(width: SipSpace.md),
          Expanded(
            child: Text(
              urun.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SipText.metin(13, w: 600).copyWith(color: t.ink),
            ),
          ),
          const SizedBox(width: SipSpace.md),
          Text(
            sipTutar(urun.unitPriceKurus),
            style: SipText.tutar(13).copyWith(color: t.ink2),
          ),
          if (!ilk)
            SipIkonButon(
              ikon: SipIcons.up,
              ikonBoyut: 16,
              kalinlik: 2.2,
              etiket: '${urun.name} yukarı taşı',
              onTap: onYukari,
            ),
          SipIkonButon(
            ikon: SipIcons.x,
            ikonBoyut: 16,
            kalinlik: 2.2,
            renk: t.muted,
            etiket: '${urun.name} favorilerden çıkar',
            onTap: onCikar,
          ),
        ],
      ),
    );
  }
}

/// Favori seçme sheet'i — aktif katalog, dokunulan ürün eklenir/çıkarılır.
///
/// Seçim ANINDA YAZILMAZ, "Kaydet"te tek seferde yazılır: her dokunuş bir `customer` upsert
/// olayı üretseydi, beş ürün seçen bayi senkron kuyruğuna beş tam müşteri satırı yollardı.
class _FavoriSecici extends StatefulWidget {
  const _FavoriSecici({required this.db, required this.baslangic});

  final AppDatabase db;

  /// HAM id listesi (çözülemeyenler dâhil) — kaydederken onlar da geri yazılır.
  final List<String> baslangic;

  @override
  State<_FavoriSecici> createState() => _FavoriSeciciState();
}

class _FavoriSeciciState extends State<_FavoriSecici> {
  // `final` ama `late`: liste hiç YENİDEN ATANMAZ (yalnız add/remove ile değişir), buna karşılık
  // ilk değeri `widget`ten okunduğu için alan başlatıcısında `late` şart.
  late final List<String> _idler = [...widget.baslangic];
  final TextEditingController _ara = TextEditingController();

  @override
  void dispose() {
    _ara.dispose();
    super.dispose();
  }

  void _degistir(Product u) {
    if (_idler.contains(u.id)) {
      setState(() => _idler.remove(u.id));
      return;
    }
    if (_idler.length >= kFavoriUstSinir) {
      SipToast.goster(context, MusteriFavorileri.limitMesaji);
      return;
    }
    // SONA EKLENİR: sıra bayinin tercihidir ve yeni eklenen, elle taşınana kadar en sonda kalır.
    setState(() => _idler.add(u.id));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return StreamBuilder<List<Product>>(
      stream: watchKatalogUrunleri(widget.db),
      initialData: const [],
      builder: (context, snap) {
        final tumu = snap.data ?? const <Product>[];
        final liste = katalogSuz(tumu, _ara.text);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SipArama(
              controller: _ara,
              ipucu: 'Ürün ara',
              onChanged: (_) => setState(() {}),
              onTemizle: () => setState(() => _ara.clear()),
            ),
            const SizedBox(height: SipSpace.lg),
            if (tumu.isEmpty)
              const SipBosDurum(
                ikon: SipIcons.box,
                baslik: 'Katalog boş',
                aciklama: 'Önce Ürünler ekranından ürün ekleyin.',
              )
            else if (liste.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: SipSpace.x3),
                child: Text(
                  '“${_ara.text.trim()}” için sonuç yok',
                  textAlign: TextAlign.center,
                  style: SipText.metin(13, w: 600).copyWith(color: t.muted),
                ),
              )
            else
              for (final u in liste)
                Padding(
                  padding: const EdgeInsets.only(bottom: SipSpace.sm),
                  child: SipDokun(
                    onTap: () => _degistir(u),
                    zemin: _idler.contains(u.id) ? t.accentSoft : t.bg,
                    radius: SipRadius.br2,
                    padding: const EdgeInsets.symmetric(
                        horizontal: SipSpace.x2, vertical: 13),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            u.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SipText.metin(13.5,
                                    w: _idler.contains(u.id) ? 700 : 600)
                                .copyWith(
                                    color: _idler.contains(u.id) ? t.accent : t.ink2),
                          ),
                        ),
                        const SizedBox(width: SipSpace.md),
                        Text(
                          sipTutar(u.unitPriceKurus),
                          style: SipText.tutar(12.5).copyWith(color: t.muted),
                        ),
                        if (_idler.contains(u.id)) ...[
                          const SizedBox(width: SipSpace.md),
                          SipIcon(SipIcons.check,
                              boyut: 17, kalinlik: 2.4, renk: t.accent),
                        ],
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: SipSpace.x3),
            SipButon(
              etiket: 'Kaydet',
              onTap: () => Navigator.of(context).pop(_idler),
            ),
          ],
        );
      },
    );
  }
}
