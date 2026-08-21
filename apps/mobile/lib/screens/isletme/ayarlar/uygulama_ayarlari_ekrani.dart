// AYARLAR → UYGULAMA — cihaza ait tercihler ve arayan tanıma kurulumu.
//
// BURASI TERCİHLERİN KANONİK EVİDİR. Koyu tema ve arayan tanıma anahtarları ÇEKMECEDE DE var
// (kullanıcı isteği 2026-08-13: günde birçok kez çevrilen şeyler elin altında olmalı) — ama o
// bir KISAYOLDUR, ikinci bir kaynak değil: ikisi de aynı depoyu okuyup yazar
// (`tema_deposu.dart`, `arayan_tanima_ayari.dart`). Bir yüzeyde çevrilen, diğeri açıldığında
// yeni değeriyle görünür. "Aynı gerçeği iki yerde tutmak" yasağı DEĞERE ilişkindir, görünüme
// değil; tek doğru kaynak korunuyor.
//
// NEDEN ÇEKMECEDE VARKEN BURADA DA DURUYOR: bir bayi tercihini ararken önce Ayarlar'a bakar.
// Yalnız çekmecede bıraksaydık, orayı fark etmeyen kullanıcı "koyu tema kaldırılmış" derdi.
//
// MAĞAZA KURALI: abonelik / ödeme / satın alma / fiyat / üyelik bağlantısı OLAMAZ.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../theme/components/atoms.dart';
import '../../../theme/components/overlays.dart';
import '../../../theme/components/states.dart';
import '../../../theme/icons.dart';
import '../../../theme/tokens.dart';
import '../../cagri/arayan_tanima_ayari.dart';
import '../../orders/order_list_parts.dart' show tutamacSagdaTercihi;
import '../../orders/tutamac_deposu.dart';
import '../isletme_atomlari.dart';

class UygulamaAyarlariEkrani extends StatefulWidget {
  const UygulamaAyarlariEkrani({
    super.key,
    this.koyuTema,
    this.onTema,
    this.onSihirbaz,
    this.onOlcumler,
  });

  /// Geçerli tema — DEĞER değil DİNLENEBİLİR kaynak (sahibi kabuk). Düz `bool` geçmek yetmez:
  /// bu sayfa `Navigator.push` ile açılıyor, kabuk yeniden çizilse bile rota kendi anlık
  /// kopyasıyla kalır ve anahtar tema döndüğü hâlde eski konumunda takılı görünürdü.
  final ValueListenable<bool>? koyuTema;
  final ValueChanged<bool>? onTema;

  /// Kurulum sihirbazını yeniden çalıştırır.
  final VoidCallback? onSihirbaz;

  /// Faz 0 gecikme ölçüm ekranı — satır YALNIZ hata ayıklama derlemesinde çizilir.
  final VoidCallback? onOlcumler;

  @override
  State<UygulamaAyarlariEkrani> createState() => _UygulamaAyarlariEkraniState();
}

class _UygulamaAyarlariEkraniState extends State<UygulamaAyarlariEkrani> {
  /// Sürükleme tutamacının tarafı. Depodan okunur; `tutamacSagdaTercihi` ekranların okuduğu
  /// süreç-içi değerdir ve yazınca birlikte güncellenir.
  bool _tutamacSagda = tutamacSagdaTercihi;

  Future<void> _tutamacCevir() async {
    final yeni = !_tutamacSagda;
    setState(() => _tutamacSagda = yeni);
    tutamacSagdaTercihi = yeni;
    await tutamacDeposu.yaz(yeni);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SipUst(baslik: 'Uygulama', onGeri: () => Navigator.of(context).maybePop()),
            Expanded(
              child: SipGovde(children: [
                const SipBolumBaslik('Görünüm', ustBosluk: 18),
                AyarKarti(satirlar: [
                  AyarSatiri(
                    ikon: SipIcons.moon,
                    baslik: 'Koyu tema',
                    onTap: () => widget.onTema?.call(!(widget.koyuTema?.value ?? false)),
                    sag: ValueListenableBuilder<bool>(
                      valueListenable:
                          widget.koyuTema ?? const AlwaysStoppedAnimation<bool>(false),
                      builder: (context, koyu, child) => SipKnob(acik: koyu),
                    ),
                  ),
                  // SÜRÜKLEME TARAFI AYARLARA GELDİ (2026-08-13). Kalıcı bir CİHAZ tercihi
                  // olmasına rağmen tek yaşadığı yer sipariş listesi ekranının içindeki bir
                  // kontroldü — yani bayi onu ancak o ekranda, o an fark ederse bulabiliyordu.
                  // Liste ekranındaki kontrol KALDI (orada bağlam doğru: sürüklerken değiştir);
                  // burası tercihin adıyla anıldığı yer.
                  AyarSatiri(
                    ikon: SipIcons.grip,
                    // BAŞLIK ANAHTARIN AÇIK HÂLİNİ SÖYLER (2026-08-18). Eskiden başlık
                    // "Sürükleme tutamacı", alt başlık ise DURUMU yazıyordu — anahtarın yanında
                    // durum iki kez okunuyor ve "açık ne demek?" sorusu cevapsız kalıyordu.
                    // Anahtarlı satırda alt başlık NE İŞE YARADIĞINI anlatır, durumu değil.
                    baslik: 'Tutamaç sağda',
                    altBaslik: 'Siparişleri elle sıralarken',
                    onTap: _tutamacCevir,
                    sag: SipKnob(acik: _tutamacSagda),
                  ),
                ]),

                const SipBolumBaslik('Arayan Tanıma', ustBosluk: 18),
                AyarKarti(satirlar: [
                  // AÇ/KAPA anahtarı EN ÜSTTE: bölümün diğer satırları (kurulum, deneme)
                  // özelliğin parçalarıdır; özelliğin kendisinin düğmesi hepsinden önce gelir.
                  const ArayanTanimaSatiri(),
                  AyarSatiri(
                    ikon: SipIcons.phone,
                    baslik: 'Kurulum ve izinler',
                    altBaslik: 'Telefon izinlerini yeniden ayarlayın',
                    onTap: () {
                      final sihirbaz = widget.onSihirbaz;
                      if (sihirbaz == null) {
                        SipToast.goster(context, 'Kurulum sihirbazı şu an açılamıyor');
                      } else {
                        sihirbaz();
                      }
                    },
                  ),
                  // Faz 0 gecikme ölçüm ekranı. Tasarımda YOK ve esnafın menüsünde işi de yok —
                  // ama silinemez: çağrı kartının 1 SANİYELİK bütçesini (BRIEF kırmızı çizgisi)
                  // ölçen tek araç orası. Girişi kaldırınca ekran hiçbir yerden açılamaz hâle
                  // geldi (bu projede Ayarlar/Kuryeler/Muaf dalı aynen böyle ölmüştü), o yüzden
                  // `kDebugMode` ile duruyor: geliştirmede ölçülür, üretimde satır derlenmez.
                  if (kDebugMode && widget.onOlcumler != null)
                    AyarSatiri(
                      ikon: SipIcons.clock,
                      baslik: 'Gecikme ölçümleri',
                      altBaslik: 'Yalnız geliştirme derlemesinde görünür',
                      onTap: widget.onOlcumler,
                    ),
                ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
