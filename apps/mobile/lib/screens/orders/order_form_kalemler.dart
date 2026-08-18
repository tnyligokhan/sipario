// Yeni Sipariş — ADIM 2'nin (kalemler) çizimi. CSS `.ys-secili`, `.ys-ekle`, `.ys-serbest`,
// `.ys-satir`. Kaynak: s-siparisler.jsx `YeniSiparis`.
//
// NEDEN AYRI DOSYA: `order_form_screen.dart` 568 satıra çıkmıştı (500 satır kuralı) ve adım 1 ile
// adım 3'ün çizimi zaten `order_form_parts.dart`taydı — inline kalan tek adım buydu. O dosya da
// 433 satırda, üçüncü adımı alacak yeri yok; bu yüzden kendi dosyası.
//
// DURUM TAŞINMADI (adım 2'nin ekranda tutulma gerekçesi buydu): sepet listesi, adetler ve satır
// notları hâlâ ekranın `State`inde yaşar. Buraya inen şey yalnız ÇİZİM ve dokunuşun geri
// bildirimi — adım 1/3 ile aynı sözleşme (kontrolcü + geri çağrı al, durum tutma).

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../data/urun_secenekleri.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'order_form_parts.dart';
import 'order_parts.dart';
import 'pos_catalog.dart';

/// EKRAN İKİ BÖLGEDİR: önce "nasıl eklerim", sonra "ne ekledim".
///
/// Eskiden üç ekleme yolu (favori hapları · katalog düğmesi · serbest satır bağlantısı) sepetin
/// ÜSTÜNE, ALTINA ve ARASINA dağılmıştı; sepet ikiye bölünmüş, ekran da altı ayrı yüzeye. Aynı
/// işi yapan üç düğme birbirinden uzağa serpildiğinde kullanıcı hangisine basacağını her
/// seferinde yeniden karar vermek zorunda kalır. Üçü artık hız sırasına dizili tek bir blok:
/// her zamanki ürünler (tek dokunuş) → katalog (arama/barkod) → serbest satır (istisna).
class KalemlerAdimi extends StatelessWidget {
  const KalemlerAdimi({
    super.key,
    required this.db,
    required this.musteri,
    required this.musteriKilitli,
    required this.satirlar,
    required this.onMusteriDegistir,
    required this.onUrunEkle,
    required this.onSerbestEkle,
    required this.onAdetDegis,
    required this.onSil,
    required this.onSatirNotu,
    required this.onBildir,
  });

  final AppDatabase db;

  /// Sipariş KİMİN için giriliyor. Müşteri dışarıdan kilitli geldiyse kayıt bir kare gecikmeyle
  /// iner ve null olur — o karede bekleme işareti çizilir.
  final Customer? musteri;

  /// Müşteri dışarıdan verildiyse (müşteri detayından "Sipariş oluştur") "Değiştir" çizilmez.
  final bool musteriKilitli;

  final List<LineDraft> satirlar;

  final VoidCallback onMusteriDegistir;
  /// Kataloğa/favorilere dokunulunca sepete ekler. Üçüncü argüman SEÇENEK SEÇİMİdir
  /// (2026-08-18) — favori şeridi boş seçimle çağırır: favori tek dokunuşla eklenir, malzeme
  /// sormaz. "Hız" onun bütün sebebidir; sormak isteyen katalogdan seçer.
  final void Function(Product urun, int adet, SecenekSecimi secim) onUrunEkle;
  final VoidCallback onSerbestEkle;

  /// Satırın adedini [delta] kadar değiştirir; 0'a düşünce satır silinir (kararı ekran verir).
  final void Function(int i, int delta) onAdetDegis;
  final void Function(int i) onSil;
  final void Function(int i) onSatirNotu;

  /// Toast — ekran gösterir (bu widget `ScaffoldMessenger`ı kendi başına aramaz).
  final void Function(String mesaj) onBildir;

  bool get _sepetBos => satirlar.isEmpty;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipGovde(
      children: [
        // .ys-secili — sipariş KİMİN için giriliyor; ekranın çapası, en üstte kalır.
        Container(
          margin: const EdgeInsets.only(top: SipSpace.lg),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(color: t.accentSoft, borderRadius: SipRadius.br2),
          child: Row(
            children: [
              SipIcon(SipIcons.user, boyut: 15, kalinlik: 2.1, renk: t.accent),
              const SizedBox(width: SipSpace.md),
              Expanded(
                child: Text(
                  musteri?.name ?? '…',
                  style: SipText.metin(13.5, w: 800).copyWith(color: t.accent),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!musteriKilitli)
                SdxLink(etiket: 'Değiştir', onTap: onMusteriDegistir),
            ],
          ),
        ),

        // ── Ekleme yolları — hız sırasına göre ────────────────────────────────────────────
        // Favori ürünler: müşterinin "her zamankileri", tek dokunuşla sepete. Sipariş girişinin
        // en sık hâli zaten budur; katalogu açmak istisnadır. Favorisi olmayan müşteride bölüm
        // hiç çizilmez.
        FavoriSeridi(
          db: db,
          musteriId: musteri?.id,
          onEkle: (u) {
            onUrunEkle(u, 1, const SecenekSecimi());
            onBildir('${u.name} sepete eklendi');
          },
        ),
        YsEkleDugmesi(
          etiket: 'Katalogdan ürün ekle',
          ikon: SipIcons.plus,
          onTap: () => posKatalogAc(
            context,
            db: db,
            onEkle: onUrunEkle,
            onBildir: onBildir,
            musteriId: musteri?.id,
            musteriAdi: musteri?.name,
          ),
        ),
        // .ys-serbest — katalog düğmesinin hemen ALTINDA. İkisi de "sepete bir şey koy" demek;
        // aralarına sepeti sokmak, ikinci yolu listenin dibinde kaybediyordu.
        SipDokun(
          onTap: onSerbestEkle,
          radius: SipRadius.br2,
          // CSS `.ys-serbest { padding: 13px 2px }` (_sayfa.html:522) — ölçü tasarımdan.
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 2),
          child: Text(
            '+ Serbest satır (katalogda olmayan iş)',
            textAlign: TextAlign.center,
            style: SipText.metin(12.5, w: 600).copyWith(color: t.muted),
          ),
        ),

        // ── Sepet ────────────────────────────────────────────────────────────────────────
        // Bölüm başlığı sepet BOŞKEN DE durur: ekleme yapıldığında düzen yerinden oynamaz,
        // kullanıcı eklediği kalemin nereye düşeceğini önceden görür. Sayaç yalnız dolu
        // sepette yazar — "0 kalem" bir bilgi değil, gürültüdür.
        SdxSec(
          // Adım rozeti "Kalemler" diyor, özet ekranı "Kalemler" diyor — sepet de aynı adı
          // taşır. Aynı şeyin akış boyunca tek adı olur.
          'Kalemler',
          sag: _sepetBos ? null : SdxAdet('${satirlar.length} kalem'),
        ),
        if (_sepetBos)
          // BOŞ DURUM METNİ DEĞİŞTİ (2026-08-12): eski hâli "Sepet boş — katalogdan ürün
          // ekleyin" diyerek tam üstündeki düğmenin sözünü tekrarlıyordu. Boş bölüm, ne
          // yapılacağını değil BURAYA NE GELECEĞİNİ söyler; eylem zaten iki parmak yukarıda ve
          // kendi adını taşıyor.
          const YsBosDurum(metin: 'Eklenen kalemler burada listelenir')
        else
          for (var i = 0; i < satirlar.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 7),
              child: YsSatiri(
                ad: satirlar[i].name,
                // CSS `.ys-birim` YALNIZ birimi yazar (s-siparisler.jsx:346) — birim
                // fiyat sağdaki satır toplamının yanında ikinci kez okunmaz.
                // SEÇİM ÖZETİ BİRİMİN YANINDA (2026-08-18): "adet · Soğansız". Ayrı bir satır
                // açmak sepeti kalem başına üç satıra çıkarırdı (not rozetiyle aynı gerekçe);
                // birim alanı zaten kalemin künyesidir ve seçim o künyenin parçasıdır.
                altMetin: satirlar[i].secimOzeti.isEmpty
                    ? satirlar[i].birimEtiketi
                    : '${satirlar[i].birimEtiketi} · ${satirlar[i].secimOzeti}',
                // Ekstralar birim fiyata dahildir (`birimFiyat`) — sepetin gösterdiği tutar,
                // kaydedilen tutarla AYNI formülden çıkmalı.
                tutarKurus: satirlar[i].birimFiyat * satirlar[i].qty,
                adet: satirlar[i].serbest ? null : satirlar[i].qty,
                onAzalt: () => onAdetDegis(i, -1),
                onArtir: () => onAdetDegis(i, 1),
                onSil: () => onSil(i),
                not: satirlar[i].note,
                onNot: () => onSatirNotu(i),
              ),
            ),
      ],
    );
  }
}
