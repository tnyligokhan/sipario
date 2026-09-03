// Müşteriler listesi — CSS `.mliste` / `.mrow*`, kaynak s-musteriler.jsx `MusterilerEkran`.
// Üstte başlık + borçlu sayısı, altında hap arama çubuğu, sonra kart satırları:
// avatar · ad · telefon · adres (konum varsa pin YEŞİL) · sağda bakiye çipi (0 ise çip YOK).
//
// Sorgu mantığı ekrandan bağımsız fonksiyonlardadır (watchCustomerRows/watchCustomers/
// watchDebtCount) — saf async testle sınanır; widget-test sahte zamanı drift akışlarında
// güvenilmez (Dilim 1 dersi).

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../rehber/rehber_modeli.dart';
import '../../rehber/rehber_sahne.dart';

import '../../rehber/rehber_hedef.dart';
import '../../data/app_database.dart';
import '../../sync/yenileme.dart';
import '../../data/outbox.dart' show phoneLast10;
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../orders/order_queries.dart' show musteriKodu;
import '../team.dart';
import 'customer_detail_screen.dart';
import 'customer_form_screen.dart';
import 'customer_widgets.dart';
import 'kara_liste.dart';

// Liste SORGULARI buradan ayrıldı — 500 satır sınırı. AYNI KÜTÜPHANEDİR (`part`), yani
// `watchCustomerRows` gibi adları import eden hiçbir yer değişmedi; gerekçe o dosyanın başlığında.
part 'customer_list_sorgulari.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({
    super.key,
    required this.db,
    required this.writable,
    required this.yetki,
    this.onMenu,
    this.userId,
  });

  final AppDatabase db;
  final bool writable;

  /// Rol bazlı yetki (K2); detaydaki tahsilat ve defter düzeltme kapıları buradan gelir.
  ///
  /// ⚠️ ZORUNLU (2026-08-13). Eskiden nullable'dı ve "null → tam yetki (giriş öncesi/test yolu)"
  /// diyordu. Bu ekran yetkiyi `CustomerDetailScreen`e AKTARIYOR, yani buradaki geçirgen
  /// varsayılan orada yönetici eylemlerine dönüşüyordu — kolaylık bir kapıda kalmıyor, zincir
  /// boyunca akıyor. Test/önizleme yolu kapanmadı: `yetkiler(rol: 'patron', atamaHedefiVar: true)`.
  final RolYetkileri yetki;

  /// Çekmeceyi açan geri çağrım (kabuk verir). null ise hamburger çizilmez.
  final VoidCallback? onMenu;

  /// Oturumdaki kullanıcı — `yetki.tumMusterileriGorme` KAPALIYSA liste bu kişinin kapsamına
  /// kilitlenir (kendi siparişlerinin müşterileri). `OrderListScreen.userId` deseninin ikizi.
  ///
  /// null verilirse kısıtlama UYGULANMAZ ve bu bilinçli: kimliği bilinmeyen bir oturumu boş
  /// listeye kilitlemek, yetkiyi uygulamak değil ekranı bozmaktır — o durumda kapı yönetici
  /// tarafında kalır (`OrderListScreen._kendiSiparisleriyleSinirli` ile aynı gerekçe).
  final String? userId;

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final _arama = TextEditingController();
  String _sorgu = '';

  /// Sorguya gidecek kapsam: kısıtlıysa oturum kullanıcısı, değilse null (bayinin tamamı).
  String? get _kapsamKullanicisi =>
      widget.yetki.tumMusterileriGorme ? null : widget.userId;

  // Başlıktaki borçlu sayısı — bir kez abone ol (tuş başına yeniden abonelik/titreme olmasın).
  late final Stream<int> _borcluSayisi =
      watchDebtCount(widget.db, kullaniciId: _kapsamKullanicisi);

  @override
  void dispose() {
    _arama.dispose();
    super.dispose();
  }

  Future<void> _yeniMusteri() async {
    if (!widget.writable) {
      SipToast.goster(context, 'Aboneliğiniz sona erdiği için yeni kayıt eklenemiyor');
      return;
    }
    // Kurye yetkisi (2026-08-04). Ekranın "Yeni" düğmesi burada GİZLENMEZ (listeye giriş
    // yetkiden bağımsız) ama eylem durur ve sebebini söyler — kabuğun FAB menüsünde satır
    // zaten hiç çizilmiyor, yani bu yol ikinci kapıdır.
    if (!(widget.yetki.musteriDuzenleme)) {
      SipToast.goster(context, 'Müşteri ekleme yetkiniz yok');
      return;
    }
    final eklendi = await musteriEkleSheet(context, db: widget.db);
    if (eklendi == true && mounted) SipToast.goster(context, 'Müşteri kaydedildi');
  }

  void _ac(Customer c) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CustomerDetailScreen(
        db: widget.db,
        customerId: c.id,
        writable: widget.writable,
        yetki: widget.yetki,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StreamBuilder<int>(
              stream: _borcluSayisi,
              builder: (context, snap) {
                final n = snap.data ?? 0;
                return SipUst(
                  baslik: 'Müşteriler',
                  // DARALTMA SESSİZ OLAMAZ (bu deponun yerleşik kuralı; sipariş listesinde de
                  // aynı çözüm var): kapsam kısıtlıysa üst şerit bunu SÖYLER. Söylemeseydi
                  // kurye eksik bir defter görüp "müşterim kaybolmuş" derdi.
                  alt: _kapsamKullanicisi != null
                      ? 'Yalnız sizin siparişlerinizin müşterileri'
                      : (n > 0 ? '$n borçlu müşteri' : 'Tüm hesaplar temiz'),
                  onMenu: widget.onMenu,
                  sag: [
                    SipMetinButon(
                      etiket: 'Yeni',
                      ikon: SipIcons.plus,
                      onTap: _yeniMusteri,
                    ),
                    const RehberYardimDugmesi(yuzey: RehberYuzey.musteriler),
                  ],
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(SipSpace.govde, SipSpace.xs, SipSpace.govde, SipSpace.xl),
              child: RehberHedef(
                id: 'musteri.arama',
                child: SipArama(
                  controller: _arama,
                  ipucu: 'Ad veya telefon ara',
                  onChanged: (v) => setState(() => _sorgu = v),
                  onTemizle: () {
                    _arama.clear();
                    setState(() => _sorgu = '');
                  },
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<CustomerRow>>(
                stream: watchCustomerRows(widget.db, _sorgu,
                    kullaniciId: _kapsamKullanicisi),
                builder: (context, snap) {
                  if (snap.hasError) return const SipHataEkran();
                  final rows = snap.data;
                  if (rows == null) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: SipSpace.govde),
                      child: SipIskelet(),
                    );
                  }
                  if (rows.isEmpty) return _bosDurum();
                  return RefreshIndicator(
                    onRefresh: yenile,
                    child: ListView.separated(
                      padding:
                          const EdgeInsets.fromLTRB(SipSpace.govde, 2, SipSpace.govde, 104),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 7),
                      itemBuilder: (context, i) => _MusteriSatiri(
                        satir: rows[i],
                        maskeli: widget.yetki.telefonMaskeleme,
                        onAc: () => _ac(rows[i].customer),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bosDurum() {
    final arama = _sorgu.trim();
    if (arama.isNotEmpty) {
      return SipBosDurum(
        ikon: SipIcons.search,
        baslik: 'Sonuç yok',
        aciklama: '"$arama" için müşteri bulunamadı',
      );
    }
    // BOŞ DURUM KAPSAMI BİLİR (çağrı günlüğündeki süzgeç dersinin aynısı): kısıtlı kuryeye
    // "henüz müşteri yok" demek, bayinin defterinin boş olduğunu söylerdi — oysa yalnız ONA
    // düşen bir iş yok.
    if (_kapsamKullanicisi != null) {
      return const SipBosDurum(
        ikon: SipIcons.users,
        baslik: 'Size düşen müşteri yok',
        aciklama: 'Size sipariş atandığında müşterisi burada görünür',
      );
    }
    return SipBosDurum(
      ikon: SipIcons.users,
      baslik: 'Henüz müşteri yok',
      aciklama: 'Gelen çağrıdan ya da alttaki ekle düğmesinden kaydedin',
      aksiyon: 'Yeni Müşteri',
      onAksiyon: _yeniMusteri,
    );
  }
}

/// CSS `.mrow` — (ad / telefon / adres) + bakiye çipi.
///
/// AVATAR YOK: tasarımın `MusteriSatir`ı (s-musteriler.jsx:7-19) avatar çizmiyor; `.mrow-av`
/// CSS'te kalmış ölü bir sınıf.
class _MusteriSatiri extends StatelessWidget {
  const _MusteriSatiri({required this.satir, required this.onAc, this.maskeli = false});

  final CustomerRow satir;
  final VoidCallback onAc;
  final bool maskeli;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final c = satir.customer;
    final adres = satir.adres;
    final konumVar = adres?.lat != null && adres?.lng != null;
    final adresMetni = adresGosterimi(adres?.addressText);

    return SipDokun(
      onTap: onAc,
      zemin: t.surface,
      radius: SipRadius.br2,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    if (c.code != null) ...[
                      Text(
                        musteriKodu(c.code)!,
                        style: SipText.satirAd.copyWith(color: t.muted),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SipText.satirAd.copyWith(color: t.ink),
                      ),
                    ),
                    if (karaListede(c)) ...[
                      const SizedBox(width: 6),
                      const _KaraListeRozeti(),
                    ],
                  ],
                ),
                if (satir.phone != null) ...[
                  const SizedBox(height: 3),
                  _AltSatir(
                    ikon: SipIcons.phone,
                    ikonRenk: t.muted,
                    kalinlik: 2,
                    metin: maskeli ? telefonMaskele(satir.phone!) : sipTelefon(satir.phone!),
                    stil: SipText.satirTel.copyWith(color: t.ink2),
                  ),
                ],
                if (adresMetni != null) ...[
                  const SizedBox(height: 3),
                  _AltSatir(
                    ikon: SipIcons.pin,
                    // Konumu kayıtlı adres YEŞİL pin — kurye için "bu kapı bulunur" işareti.
                    ikonRenk: konumVar ? t.ok : t.muted,
                    kalinlik: 2.2,
                    metin: adresMetni,
                    stil: SipText.satirAdres.copyWith(color: t.ink2),
                    satirlar: 2,
                  ),
                ],
              ],
            ),
          ),
          // Bakiye 0'da çip HİÇ çizilmez (tasarım); öndeki boşluk da o zaman hayalet kalmasın.
          if (c.balanceKurus != 0) ...[
            const SizedBox(width: SipSpace.xl), // CSS `.mrow { gap: 12px }`
            SipBakiyeCipi(kurus: c.balanceKurus),
          ],
        ],
      ),
    );
  }
}

/// Liste satırındaki kara liste rozeti — küçük, kırmızı, metinli hap.
///
/// SALT İKON DEĞİL: yasak işareti tek başına "pasif", "kilitli" ya da "sessize alındı" diye de
/// okunabilir. Kelime belirsizliği kapatır ve ekran okuyucuya da aynı şeyi söyler.
class _KaraListeRozeti extends StatelessWidget {
  const _KaraListeRozeti();

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: t.dangerSoft, borderRadius: SipRadius.brHap),
      child: Text(
        karaListeRozeti,
        style: SipText.metin(9, w: 800).copyWith(color: t.danger, letterSpacing: .3),
      ),
    );
  }
}

/// `.mrow-tel` / `.mrow-adres` — küçük ikon + metin satırı.
class _AltSatir extends StatelessWidget {
  const _AltSatir({
    required this.ikon,
    required this.ikonRenk,
    required this.kalinlik,
    required this.metin,
    required this.stil,
    this.satirlar = 1,
  });

  final String ikon;
  final Color ikonRenk;
  final double kalinlik;
  final String metin;
  final TextStyle stil;
  final int satirlar;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: SipIcon(ikon, boyut: 13, kalinlik: kalinlik, renk: ikonRenk),
        ),
        const SizedBox(width: SipSpace.sm),
        Expanded(
          child: Text(metin, maxLines: satirlar, overflow: TextOverflow.ellipsis, style: stil),
        ),
      ],
    );
  }
}

