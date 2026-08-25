// Sipario paylaşılan DURUM ekranları — boş, iskelet, hata, çevrimdışı, üst başlık.
// Kaynak: tasarım s-bilesenler.jsx (`BosDurum`, `Iskelet`, `HataEkran`,
// `CevrimdisiBant`, `Ust`) + Sipario.html `.bos-*`, `.isk-*`, `.cbant`, `.ust-*`.

import 'package:flutter/material.dart';

import '../icons.dart';
import '../tokens.dart';
import '../typography.dart';
import 'atoms.dart';

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Üst başlık — CSS `.ust`
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// İç sayfaların başlık çubuğu. Material [AppBar] KULLANILMAZ: tasarımda gölge/yükseklik yok,
/// başlık sola dayalı ve iki satırlı (başlık + alt bilgi) olabiliyor.
///
/// [onGeri] verilirse sol ok, yoksa [onMenu] verilirse hamburger, ikisi de yoksa boşluk çizilir.
class SipUst extends StatelessWidget {
  const SipUst({
    super.key,
    required this.baslik,
    this.alt,
    this.onGeri,
    this.onMenu,
    this.sag = const [],
  });

  final String baslik;
  final String? alt;
  final VoidCallback? onGeri;
  final VoidCallback? onMenu;

  /// Sağdaki eylemler (CSS `.ust-sag`) — genelde [SipMetinButon] / [SipIkonButon].
  final List<Widget> sag;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.fromLTRB(SipSpace.govde, SipSpace.xl, SipSpace.govde, SipSpace.md),
      child: Row(
        children: [
          if (onGeri != null)
            SipIkonButon(
              ikon: SipIcons.left,
              ikonBoyut: 24,
              renk: t.ink,
              etiket: 'Geri',
              onTap: onGeri,
            )
          else if (onMenu != null)
            SipIkonButon(
              ikon: SipIcons.menu,
              ikonBoyut: 23,
              renk: t.ink,
              etiket: 'Menü',
              onTap: onMenu,
            )
          else
            const SizedBox(width: 10),
          const SizedBox(width: SipSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  baslik,
                  style: SipText.ustBaslik.copyWith(color: t.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (alt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      alt!,
                      style: SipText.ustAlt.copyWith(color: t.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          if (sag.isNotEmpty) ...[
            const SizedBox(width: SipSpace.lg),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < sag.length; i++) ...[
                  if (i > 0) const SizedBox(width: SipSpace.sm),
                  sag[i],
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Ekran gövdesi — CSS `.ekran-govde` (yatay 18, altta 20 iç boşluk, kaydırılabilir).
class SipGovde extends StatelessWidget {
  const SipGovde({
    super.key,
    required this.children,
    this.controller,
    this.altBosluk = SipSpace.x4,
    this.onYenile,
  });

  final List<Widget> children;
  final ScrollController? controller;
  final double altBosluk;

  /// Aşağı çekerek yenile (kullanıcı isteği 2026-07-29). Verilmezse jest HİÇ kurulmaz —
  /// yenilenecek bir şeyi olmayan bir ekranda dönen gösterge, iş yapıldığı yalanını söyler.
  final Future<void> Function()? onYenile;

  @override
  Widget build(BuildContext context) {
    final liste = ListView(
      controller: controller,
      // İçerik kısa olsa da jest çalışmalı: yenileme en çok BOŞ ekranda (yeni kurulum,
      // senkron gelmemiş cihaz) gerekiyor ve varsayılan fizik orada kaydırmayı kapatıyor.
      physics: onYenile == null ? null : const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(SipSpace.govde, 0, SipSpace.govde, altBosluk),
      children: children,
    );
    if (onYenile == null) return liste;
    return RefreshIndicator(onRefresh: onYenile!, child: liste);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Boş durum — CSS `.bos`
// ═══════════════════════════════════════════════════════════════════════════════════════════

class SipBosDurum extends StatelessWidget {
  const SipBosDurum({
    super.key,
    required this.baslik,
    this.aciklama,
    this.ikon = SipIcons.box,
    this.aksiyon,
    this.onAksiyon,
    this.hata = false,
  });

  final String baslik;
  final String? aciklama;

  /// [SipIcons] anahtarı.
  final String ikon;

  /// Düğme etiketi; null ise düğme çizilmez.
  final String? aksiyon;
  final VoidCallback? onAksiyon;

  /// CSS `.bos-ikon.hata` — daire danger-soft, ikon danger.
  final bool hata;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 46),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 66,
            height: 66,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hata ? t.dangerSoft : t.accentSoft,
              shape: BoxShape.circle,
            ),
            child: SipIcon(
              ikon,
              boyut: 40,
              kalinlik: hata ? 1.6 : 1.5,
              renk: hata ? t.danger : t.accent,
            ),
          ),
          const SizedBox(height: SipSpace.x3),
          Text(
            baslik,
            style: SipText.bosBaslik.copyWith(color: t.ink),
            textAlign: TextAlign.center,
          ),
          if (aciklama != null) ...[
            const SizedBox(height: SipSpace.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(
                aciklama!,
                style: SipText.bosAciklama.copyWith(color: t.muted),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          if (aksiyon != null) ...[
            const SizedBox(height: 18),
            SipButon(etiket: aksiyon!, onTap: onAksiyon, genisle: false),
          ],
        ],
      ),
    );
  }
}

/// CSS `HataEkran` — boş durumun danger varyantı, sabit metinlerle.
class SipHataEkran extends StatelessWidget {
  const SipHataEkran({super.key, this.onTekrar, this.aciklama});

  final VoidCallback? onTekrar;
  final String? aciklama;

  @override
  Widget build(BuildContext context) {
    return SipBosDurum(
      hata: true,
      ikon: SipIcons.alert,
      baslik: 'Liste yüklenemedi',
      aciklama: aciklama ??
          'Bağlantınızı kontrol edip tekrar deneyin',
      aksiyon: onTekrar == null ? null : 'Tekrar Dene',
      onAksiyon: onTekrar,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// İskelet — CSS `.isk-*` + `.sh` parıltı animasyonu
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Liste yüklenirken gösterilen iskelet satırlar. Tasarımda spinner YOK — liste ekranları
/// doğrudan iskelete düşer (algılanan hız için).
class SipIskelet extends StatelessWidget {
  const SipIskelet({super.key, this.adet = 5});

  final int adet;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Column(
      children: [
        for (var i = 0; i < adet; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 2 : 7),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: SipRadius.br2,
              ),
              child: const Row(
                children: [
                  SipParilti(genislik: 38, yukseklik: 38, radius: 12),
                  SizedBox(width: SipSpace.xl),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FractionallySizedBox(
                          widthFactor: 0.55,
                          child: SipParilti(yukseklik: 11, radius: 6),
                        ),
                        SizedBox(height: 7),
                        FractionallySizedBox(
                          widthFactor: 0.35,
                          child: SipParilti(yukseklik: 11, radius: 6),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: SipSpace.xl),
                  SipParilti(genislik: 62, yukseklik: 11, radius: 6),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// CSS `.sh` — soldan sağa akan parıltı (shimmer) dikdörtgeni.
class SipParilti extends StatefulWidget {
  const SipParilti({
    super.key,
    this.genislik,
    required this.yukseklik,
    this.radius = 6,
  });

  final double? genislik;
  final double yukseklik;
  final double radius;

  @override
  State<SipParilti> createState() => _SipPariltiState();
}

class _SipPariltiState extends State<SipParilti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        // CSS: background-size 400% + position 100%→0
        final kayma = (_c.value * 2) - 1;
        return Container(
          width: widget.genislik,
          height: widget.yukseklik,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(kayma - 1, 0),
              end: Alignment(kayma + 1, 0),
              colors: [t.surface2, t.line, t.surface2],
              stops: const [0.25, 0.5, 0.75],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Çevrimdışı bandı — CSS `.cbant`
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Ağ yokken ekranın en üstünde duran kırmızı bant. Offline-first sözü burada görünür kılınır:
/// "kaydedilip bağlanınca gönderilecek" — kullanıcı veri kaybetmediğini bilmeli.
/// Bandın anlattığı gerçek. Üçü AYRI durumdur ve tek metinle anlatılamaz (2026-07-27 saha
/// arızası): oturum ölmüşken "bağlanınca gönderilecek" demek bayiyi boşuna bekletir — hiçbir şey
/// gönderilmeyecektir, yeniden giriş yapması gerekir. Kullanıcıya ne yapacağını söylemeyen bir
/// uyarı, uyarı değildir.
enum SipBantTuru {
  /// SUNUCUYA HİÇ ULAŞILAMADI. Offline-first sözü geçerli: yazmaya devam et, sonra gidecek.
  cevrimdisi,

  /// Sunucuya ULAŞILDI ve oturum reddedildi (401/403) ya da yerelde token yok.
  oturum,

  /// Sunucuya ULAŞILDI ama o veremedi (5xx / 429). Geçici — kendi kendine düzelir.
  sunucu,

  /// Sunucu isteğimizi KALICI olarak geri çevirdi (4xx) ya da beklenmedik yanıt geldi.
  /// Ne ağ ne oturum. Kullanıcı çözemez, verisi güvende.
  hata,

  /// Bir ya da daha çok kayıt KARANTİNADA: sunucu kabul etmedi, kayıt cihazda DURUYOR ve
  /// sunucuya hiç ulaşmadı. Senkronun geri kalanı çalışıyor olabilir — bu bant o yüzden ayrıdır:
  /// "çevrimdışı" da "senkron durdu" da yanlış olurdu.
  karantina,

  /// Sunucu kayıtları BİLEREK ertelemiş: abonelik kilitli (`locked`) ya da sunucu bu istemcinin
  /// tanımadığı bir durum döndürmüş (sürüm çarpıklığı). Kayıtlar `pending` duruyor, deneme
  /// sayaçları artmıyor, engel kalkınca kendiliğinden akacaklar.
  ///
  /// NEDEN AYRI BİR BANT (2026-08-09 borcu): bu sayı hesaplanıyor ve taşınıyordu ama HİÇ
  /// okunmuyordu — tur "başarılı" sayıldığı için çip "güncel" derken kayıtlar cihazda
  /// birikiyordu. `karantina` demek yanlış olurdu (kayıt reddedilmedi, ertelendi), `hata` demek
  /// de yanlış olurdu ("destekle görüşün" — oysa çare abonelik ya da güncelleme).
  bekleyen,
}

class SipCevrimdisiBant extends StatelessWidget {
  const SipCevrimdisiBant({super.key, this.tur = SipBantTuru.cevrimdisi, this.adres});

  final SipBantTuru tur;

  /// Konuşulan SUNUCUNUN adı (adresin ana bilgisayar kısmı, gerekirse portuyla). Null ise satır
  /// hiç çizilmez.
  ///
  /// NEDEN BANTTA: saha gerçeği, sunucu adresinin her açılışta değişen bir tünel olabilmesi ve
  /// bayinin yanlış adresle kalabilmesidir. Bant hangi adrese ulaşmaya çalıştığını yazmadığı
  /// sürece bu arıza telefonu inceleyen birini gerektiriyordu; yazınca beş saniyede kendi kendini
  /// teşhis ediyor.
  final String? adres;

  /// Metin SÖZLEŞMEDİR (ui_temel_test.dart): `cevrimdisi` metni offline-first sözünü verir,
  /// DİĞERLERİ VERMEZ — verilemeyecek bir söz vermek bayiyi boşuna bekletir.
  String get metin => switch (tur) {
        SipBantTuru.cevrimdisi => 'İnternet yok. Kayıtlarınız bağlantı gelince gönderilecek.',
        SipBantTuru.oturum => 'Oturumunuz düştü. Çıkış yapıp yeniden girin.',
        SipBantTuru.sunucu => 'Sunucuya ulaşılamıyor. Kayıtlarınız telefonda, birazdan '
            'yeniden denenecek.',
        // "telefonda güvende" CÜMLEDEN ÇIKARILMADI: bandın işi yalnız arızayı söylemek değil,
        // veri kaybı korkusunu kesmek (BRIEF kırmızı çizgi #3). O ifade çıkarılınca bant
        // kısalıyor ama bayinin ilk sorusu ("kayıtlarım gitti mi?") cevapsız kalıyor.
        SipBantTuru.hata => 'Kayıtlarınız gönderilemiyor. Telefonda güvende, destekle görüşün.',
        SipBantTuru.karantina =>
          'Bazı kayıtlar gönderilemedi. Telefonda duruyor, destekle görüşün.',
        // "bağlanınca gönderilecek" DEMEZ: ağ zaten var, engel abonelik ya da sürüm. Verilemeyecek
        // bir söz vermemek bu bandın kuruluş ilkesidir (2026-07-27 dersi, dosya başlığı).
        SipBantTuru.bekleyen => 'Bazı kayıtlar sırada bekliyor. Telefonda güvende; aboneliğiniz '
            'ya da uygulama güncellenince gönderilecek.',
      };

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final adresi = adres;
    return Container(
      width: double.infinity,
      color: t.danger,
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: 7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SipIcon(
                SipIcons.sync,
                boyut: 15,
                kalinlik: 2.2,
                renk: t.durumInk,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  metin,
                  style: SipText.metin(11.5, w: 600)
                      .copyWith(color: t.durumInk),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          // Adres satırı: küçük ve soluk — asıl mesajı bastırmaz ama arıza anında tek bakışta
          // okunur. Tek satır + üç nokta: uzun tünel adresleri bandı büyütmemeli.
          if (adresi != null && adresi.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'sunucu: $adresi',
                style: SipText.metin(10, w: 500)
                    .copyWith(color: const Color(0xCCFFFFFF)),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
