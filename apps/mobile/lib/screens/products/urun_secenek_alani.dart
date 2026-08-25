// ÜRÜN FORMUNUN "İÇİNDEKİLER" ALANI — malzeme listesi düzenleyici (kullanıcı isteği 2026-08-18).
//
// NEDEN AYRI DOSYA: `product_form_sheet.dart` 475 satırdı (depo sınırı 500). Bölme çizgisi de
// doğal — form ürünün KİMLİĞİNİ (ad, fiyat, birim, barkod) düzenler; burası ürünün İÇERİĞİNİ.
//
// ══ ARAYÜZ KARARLARI ═══════════════════════════════════════════════════════════════════════
// 1. TEK LİSTE, İKİ DURUM. "İçindekiler" ve "ekstralar" ayrı iki liste olarak çizilebilirdi;
//    çizilmedi. Ayrı olsalardı aynı malzeme iki yere yazılabilir ve bayi "peynir hem içinde hem
//    ekstra" gibi kendi içinde çelişen bir menü kurabilirdi. Tek liste + satır başına bir anahtar
//    bu hâli imkânsız kılar.
// 2. HAZIR LİSTELER EN ÜSTTE. Boş bir listeye tek tek malzeme yazmak, özelliği ilk açan bayi için
//    en yorucu andır — kullanıcının istediği de buydu: "işletme türüne göre değişkenlik gösteren
//    ürün listesi". Şablon bir BAŞLANGIÇ noktasıdır; uygulandıktan sonra her satır düzenlenebilir.
// 3. FİYAT YALNIZ EKSTRADA GÖRÜNÜR. "Soğan"ın yanında bir fiyat kutusu, çıkarmanın da ücretli
//    olabileceğini ima ederdi; oysa çıkarma her zaman bedavadır (esnafın işleyişi böyle).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_database.dart';
import '../../data/urun_secenekleri.dart';
import '../../repo/tenant_settings_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../isletme/isletme_atomlari.dart';

/// Ürün formunun "İçindekiler" BÖLÜMÜ — kiracı kapısı + düzenleyici.
///
/// KAPI BURADA, FORMDA DEĞİL: ürün formu bir ürünü düzenler; "bu işletmede hazırlanan ürün var
/// mı?" sorusu onun konusu değildir. Kapıyı forma koymak, `tenant_settings`i bilen üçüncü bir
/// ekran daha demekti — ve o bilgiyi her yeni ürün yüzeyinde tekrar sormak gerekirdi.
///
/// AKIŞLA okunur, tek atış değil: ayar başka bir cihazdan açılabilir ve senkronla iner.
class UrunSecenekBolumu extends StatelessWidget {
  const UrunSecenekBolumu({
    super.key,
    required this.db,
    required this.secenekler,
    required this.onDegis,
  });

  final AppDatabase db;
  final List<UrunSecenegi> secenekler;
  final ValueChanged<List<UrunSecenegi>> onDegis;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: watchHazirlananUrun(db),
      initialData: false,
      builder: (context, snap) => (snap.data ?? false)
          ? UrunSecenekAlani(secenekler: secenekler, onDegis: onDegis)
          : const SizedBox.shrink(),
    );
  }
}

/// Ürünün seçenek listesini düzenleyen alan. Değişiklikleri [onDegis] ile dışarı bildirir;
/// kendi durumunu TUTMAZ — kaynak doğruluk formun `_secenekler` listesidir.
///
/// ══ İKİ KATMANLI GÖRÜNÜRLÜK (kullanıcı eleştirisi 2026-08-18) ══════════════════════════════
/// İlk sürümde bu alan HER ürün formunda koşulsuz çiziliyordu ve kullanıcı haklı olarak
/// itiraz etti: "su bayisinde içindekiler göstermek çok mantıklı değil". Görünürlük artık iki
/// ayrı soruya bağlı ve ikisi FARKLI şeyler sorar:
///
///  1. **İŞLETME**: burada hazırlanan ürün var mı? (`tenant_settings.prepared_products`)
///     Su/tüp bayisinde cevap HAYIR ve alan HİÇ çizilmez — çağıran ekranın kapısı.
///  2. **ÜRÜN**: bu ürünün içindekileri var mı? Kullanıcının örneği kesin: "küçük bir bakkal
///     olabilir ama aynı zamanda tost yapıyor olabilir". Yani karar ÜRÜN BAZINDA olmalı;
///     bakkalın 300 paketli ürününde bölüm açık durursa gürültü aynen geri gelir.
///
/// İkinci katman AYRI BİR KOLONLA DEĞİL, listenin kendisiyle çözülür: malzemesi olan ürün
/// düzenleyiciyi AÇIK gösterir, olmayan tek satırlık bir "İçindekiler ekle" bağlantısı. Ayrı
/// bir `hazirlanan` bayrağı, listeyle çelişebilen İKİNCİ bir doğruluk kaynağı olurdu (bayrak
/// açık ama liste boş / bayrak kapalı ama liste dolu) ve hiçbir yeni bilgi taşımazdı.
class UrunSecenekAlani extends StatefulWidget {
  const UrunSecenekAlani({super.key, required this.secenekler, required this.onDegis});

  final List<UrunSecenegi> secenekler;
  final ValueChanged<List<UrunSecenegi>> onDegis;

  @override
  State<UrunSecenekAlani> createState() => _UrunSecenekAlaniState();
}

class _UrunSecenekAlaniState extends State<UrunSecenekAlani> {
  final _yeni = TextEditingController();

  /// Düzenleyici AÇIK mı? Malzemesi olan üründe baştan açık; olmayanda kullanıcı isteyene kadar
  /// kapalı (yukarıdaki ikinci katman).
  late bool _acik = widget.secenekler.isNotEmpty;

  @override
  void dispose() {
    _yeni.dispose();
    super.dispose();
  }

  bool get _doldu => widget.secenekler.length >= kSecenekUstSinir;

  void _ekle() {
    final ad = _yeni.text.trim();
    if (ad.isEmpty || _doldu) return;
    // AYNI AD İKİ KEZ EKLENEMEZ — seçim `ad` üzerinden eşleşiyor (gerekçe `secenekleriCoz`).
    // Sessizce yutmak yerine söylenir: bayi yazdığı şeyin nereye gittiğini bilmeli.
    if (widget.secenekler.any((s) => s.ad.toLowerCase() == ad.toLowerCase())) {
      SipToast.goster(context, '"$ad" listede zaten var');
      return;
    }
    widget.onDegis([...widget.secenekler, UrunSecenegi(ad: ad)]);
    _yeni.clear();
  }

  void _degistir(int i, UrunSecenegi yeni) {
    final liste = [...widget.secenekler];
    liste[i] = yeni;
    widget.onDegis(liste);
  }

  void _sil(int i) {
    final liste = [...widget.secenekler]..removeAt(i);
    widget.onDegis(liste);
  }

  Future<void> _sablonSec() async {
    final secilen = await sipSheet<SecenekSablonu>(
      context,
      baslik: 'Hazır Malzeme Listesi',
      govde: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const AlanNotu(
            'Listeyi ekledikten sonra malzemeleri düzenleyebilir ya da silebilirsiniz',
          ),
          const SizedBox(height: SipSpace.md),
          for (final s in kSecenekSablonlari)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _SablonSatiri(
                sablon: s,
                onTap: () => Navigator.of(ctx).pop(s),
              ),
            ),
        ],
      ),
    );
    if (secilen == null || !mounted) return;

    // ŞABLON EKLER, EZMEZ: bayi iki şablonu birleştirebilmeli (dürüm + içecek) ve elle yazdığı
    // malzemeyi kaybetmemeli. Zaten var olan adlar atlanır.
    final mevcut = {for (final s in widget.secenekler) s.ad.toLowerCase()};
    final eklenecek = [
      for (final s in secilen.secenekler)
        if (!mevcut.contains(s.ad.toLowerCase())) s,
    ];
    if (eklenecek.isEmpty) {
      SipToast.goster(context, 'Bu listedeki malzemelerin hepsi zaten ekli');
      return;
    }
    widget.onDegis([...widget.secenekler, ...eklenecek].take(kSecenekUstSinir).toList());
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final liste = widget.secenekler;

    // KAPALI HÂL: TEK SATIR. Bakkalın paketli ürünlerinde ekranda görünen her şey budur —
    // bölüm başlığı bile çizilmez. Dokununca düzenleyici açılır ve bir daha kapanmaz (ürün
    // artık "hazırlanan" sayılır; kullanıcı malzemeleri tek tek silerek geri dönebilir).
    if (!_acik) {
      return Padding(
        padding: const EdgeInsets.only(top: SipSpace.md),
        child: SipDokun(
          onTap: () => setState(() => _acik = true),
          radius: SipRadius.br2,
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SipIcon(SipIcons.plus, boyut: 14, kalinlik: 2.4, renk: t.muted),
              const SizedBox(width: SipSpace.sm),
              // FLEXIBLE + ELLIPSIS: metin uzun ve dar telefonda satırı taşırıyordu (golden
              // ile yakalandı). Serbest satır bağlantısındaki (`.ys-serbest`) desenin aynısı —
              // orada da tek satırlık bir davet metni var.
              Flexible(
                child: Text(
                  'Hazırlanan ürüne içindekiler ekleyin',
                  style: SipText.metin(12.5, w: 600).copyWith(color: t.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SipFormEtiket('İçindekiler (isteğe bağlı)'),
        // BOŞ DURUM AÇIKLAYICI: düzenleyiciyi yeni açan bayi özelliğin ne işe yaradığını
        // burada öğrenir. Metin suçlayıcı değil bilgilendirici — malzemesiz ürün de meşrudur.
        if (liste.isEmpty)
          const AlanNotu(
            'Malzeme eklerseniz sipariş alırken "soğansız" gibi seçimler yapabilirsiniz',
          ),

        for (var i = 0; i < liste.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 && liste.isEmpty ? 0 : 6),
            child: _SecenekSatiri(
              secenek: liste[i],
              onDegis: (s) => _degistir(i, s),
              onSil: () => _sil(i),
            ),
          ),

        const SizedBox(height: SipSpace.md),
        Row(
          children: [
            Expanded(
              child: SipInput(
                controller: _yeni,
                ipucu: _doldu ? 'Liste dolu ($kSecenekUstSinir)' : 'Malzeme adı',
                aktif: !_doldu,
                onSubmitted: (_) => _ekle(),
              ),
            ),
            const SizedBox(width: SipSpace.md),
            SipDokun(
              onTap: _doldu ? null : _ekle,
              zemin: _doldu ? t.surface2 : t.accentSoft,
              basiliZemin: t.accentSoft,
              radius: const BorderRadius.all(Radius.circular(13)),
              olcekle: true,
              child: SizedBox.square(
                dimension: 44,
                child: Center(
                  child: SipIcon(SipIcons.plus,
                      boyut: 20, kalinlik: 2.4, renk: _doldu ? t.muted : t.accent),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: SipSpace.md),
        SipButon(
          etiket: 'Hazır liste ekle',
          tur: SipButonTuru.ikincil,
          onTap: _doldu ? null : _sablonSec,
        ),
      ],
    );
  }
}

/// Tek malzeme satırı: ad · "İçinde / Ekstra" anahtarı · ekstra ücreti · sil.
class _SecenekSatiri extends StatelessWidget {
  const _SecenekSatiri({
    required this.secenek,
    required this.onDegis,
    required this.onSil,
  });

  final UrunSecenegi secenek;
  final ValueChanged<UrunSecenegi> onDegis;
  final VoidCallback onSil;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.xl, vertical: SipSpace.lg),
      decoration: BoxDecoration(color: t.surface2, borderRadius: SipRadius.br2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  secenek.ad,
                  style: SipText.metin(13.5, w: 700).copyWith(color: t.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: SipSpace.md),
              // İKİ DURUMLU ANAHTAR, ÜÇ DEĞİL: bir malzeme ya vardır ya eklenir. "Yok" diye bir
              // üçüncü durum, listeden silmekle aynı şeydir ve ayrı bir düğmesi zaten var.
              _DurumAnahtari(
                icinde: secenek.varsayilan,
                onDegis: (v) => onDegis(secenek.kopya(varsayilan: v)),
              ),
              const SizedBox(width: SipSpace.sm),
              SipIkonButon(
                ikon: SipIcons.x,
                ikonBoyut: 16,
                renk: t.muted,
                etiket: '${secenek.ad} malzemesini sil',
                onTap: onSil,
              ),
            ],
          ),
          // FİYAT ALANI YALNIZ EKSTRADA: çıkarma bedavadır ve orada bir fiyat kutusu göstermek
          // tersini ima ederdi.
          if (!secenek.varsayilan) ...[
            const SizedBox(height: SipSpace.md),
            _EkUcret(
              kurus: secenek.ekKurus,
              onDegis: (k) => onDegis(secenek.kopya(ekKurus: k)),
            ),
          ],
        ],
      ),
    );
  }
}

class _DurumAnahtari extends StatelessWidget {
  const _DurumAnahtari({required this.icinde, required this.onDegis});

  final bool icinde;
  final ValueChanged<bool> onDegis;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipDokun(
      onTap: () => onDegis(!icinde),
      zemin: icinde ? t.okSoft : t.accentSoft,
      radius: SipRadius.brHap,
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.xl, vertical: 6),
      child: Text(
        icinde ? 'İçinde' : 'Ekstra',
        style: SipText.metin(11.5, w: 700).copyWith(color: icinde ? t.ok : t.accent),
      ),
    );
  }
}

/// Ekstranın ücreti. Boş = ücretsiz ekstra (meşru ve sık: "pipet").
class _EkUcret extends StatefulWidget {
  const _EkUcret({required this.kurus, required this.onDegis});

  final int kurus;
  final ValueChanged<int> onDegis;

  @override
  State<_EkUcret> createState() => _EkUcretState();
}

class _EkUcretState extends State<_EkUcret> {
  late final TextEditingController _c =
      TextEditingController(text: widget.kurus == 0 ? '' : _metin(widget.kurus));

  static String _metin(int kurus) {
    final lira = kurus ~/ 100;
    final kr = kurus % 100;
    return kr == 0 ? '$lira' : '$lira,${kr.toString().padLeft(2, '0')}';
  }

  /// "10" → 1000 · "10,5" → 1050. Çözülemeyen metin 0'dır — para alanında sessiz kabul YOK,
  /// ama burada "0" güvenli tarafta: bayiye hiç sormadan ÜCRET EKLEMEK yerine ücretsiz kalır.
  static int _coz(String ham) {
    final s = ham.trim().replaceAll('.', '');
    if (s.isEmpty) return 0;
    final parcalar = s.split(',');
    if (parcalar.length > 2) return 0;
    final lira = int.tryParse(parcalar[0].isEmpty ? '0' : parcalar[0]) ?? 0;
    if (parcalar.length == 1) return lira * 100;
    final kr = parcalar[1].isEmpty ? 0 : int.tryParse(parcalar[1].padRight(2, '0')) ?? 0;
    return lira * 100 + kr;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Row(
      children: [
        Text(
          'Ek ücret',
          style: SipText.metin(12, w: 600).copyWith(color: t.muted),
        ),
        const SizedBox(width: SipSpace.md),
        Expanded(
          child: SipInput(
            controller: _c,
            ipucu: '0',
            klavye: const TextInputType.numberWithOptions(decimal: true),
            girdiFiltreleri: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,]'))],
            stil: SipText.tutar(14, w: 600),
            onChanged: (v) => widget.onDegis(_coz(v)),
          ),
        ),
        const SizedBox(width: SipSpace.md),
        Text('₺', style: SipText.metin(13, w: 700).copyWith(color: t.muted)),
      ],
    );
  }
}

class _SablonSatiri extends StatelessWidget {
  const _SablonSatiri({required this.sablon, required this.onTap});

  final SecenekSablonu sablon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipDokun(
      onTap: onTap,
      zemin: t.surface2,
      radius: SipRadius.br2,
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: SipSpace.xl),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sablon.ad,
                  style: SipText.metin(13.5, w: 700).copyWith(color: t.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  sablon.secenekler.map((s) => s.ad).join(', '),
                  style: SipText.yardimci.copyWith(color: t.muted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: SipSpace.md),
          SipIcon(SipIcons.chevR, boyut: 16, kalinlik: 2, renk: t.line2),
        ],
      ),
    );
  }
}
