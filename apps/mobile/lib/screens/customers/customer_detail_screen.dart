// Müşteri detayı — kaynak s-musteriler.jsx `MusteriDetay`.
// Bloklar: koyu iletişim kartı (`.md-kart`) · bakiye kartı (`.md-bal`) · 4'lü hızlı eylem
// (`.md-akslar`) · not (`.md-not`) · defter hareketleri (`.defter`).
// Kartların görsel gövdesi customer_detail_cards.dart'ta, defter customer_ledger.dart'ta —
// bu dosya veriyi bağlar ve eylemleri (yetki/salt-okunur kapılarıyla) yürütür.

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../konum/cihaz_konumu.dart';
import '../../repo/customer_repository.dart';
import '../../sync/geocode_api.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../money.dart';
import '../orders/musteri_eylemleri.dart';
import '../orders/order_form_screen.dart';
import '../orders/order_queries.dart';
import '../team.dart';
import 'customer_detail_cards.dart';
import 'kara_liste.dart';
import 'customer_form_ops.dart';
import 'customer_form_screen.dart';
import 'customer_ledger.dart';
import 'customer_location_picker.dart';
import 'customer_sheets.dart';
import 'customer_widgets.dart';
import 'musteri_favorileri.dart';
import 'musteri_siparisleri.dart';

class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({
    super.key,
    required this.db,
    required this.customerId,
    required this.writable,
    required this.yetki,
  });

  final AppDatabase db;
  final String customerId;
  final bool writable;

  /// Rol bazlı yetki (K2). Defter düzeltme yönetici işidir; kurye tahsilat alır ama defteri
  /// düzeltemez.
  ///
  /// ⚠️ ZORUNLU VE NULLABLE DEĞİL — 2026-08-13'te bu alan `RolYetkileri?` idi ve her okuma
  /// `widget.yetki?.alan ?? true` deseniyle yazılmıştı; doc'ta da "null → tam yetki" diye
  /// KURAL olarak duruyordu. Bedeli ölçüldü: bu ekranın altı girişinden beşi yetkiyi geçiyor,
  /// biri (Ayarlar → Çağrı Geçmişi → arama satırı) geçmiyordu. O tek yoldan giren, `cagriGunlugu`
  /// yetkisi açılmış bir KURYE müşteri silme · kara listeye alma · defter düzeltme · maskesiz
  /// telefon eylemlerinin hepsine erişiyordu — aynı ekrana diğer yollardan girdiğinde hiçbirine
  /// erişemezken.
  ///
  /// DÜZELTME NEDEN "VARSAYILANI REDDET" DEĞİL: `?? false` de aynı yolu kapatırdı ama hatanın
  /// SINIFINI kapatmazdı — parametreyi geçmeyi unutmak yine sessiz kalır, yalnız yönü değişirdi
  /// (yetkisiz kullanıcıya açmak yerine yetkiliye kapatmak). Zorunlu alan, unutmayı DERLEME
  /// HATASINA çevirir: bu ekrana yeni bir giriş noktası açan kişi yetkiyi düşünmek zorunda kalır.
  /// Tam yetkili görünüm isteyen çağıran `yetkiler(rol: 'patron', kuryeVar: true)` geçer.
  final RolYetkileri yetki;

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  static const String saltOkunurMesaji = 'Salt-okunur kip: yeni kayıt eklenemez.';
  static const String yetkisizMesaji = 'Bu işlem için yetkiniz yok.';

  late final Stream<Customer?> _musteri = (widget.db.select(widget.db.customers)
        ..where((t) => t.id.equals(widget.customerId)))
      .watchSingleOrNull();

  late final Stream<List<CustomerPhone>> _telefonlar = (widget.db.select(widget.db.customerPhones)
        ..where((t) => t.customerId.equals(widget.customerId) & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.isPrimary)]))
      .watch();

  late final Stream<List<CustomerAddressesData>> _adresler =
      (widget.db.select(widget.db.customerAddresses)
            ..where((t) => t.customerId.equals(widget.customerId) & t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.isPrimary)]))
          .watch();

  @override
  void dispose() {
    SipToast.temizle();
    super.dispose();
  }

  /// Yazma kapısı: salt-okunur kip ve rol yetkisi. İzin yoksa toast basar, `false` döner.
  bool _yazabilir({bool izin = true}) {
    if (!widget.writable) {
      SipToast.goster(context, saltOkunurMesaji);
      return false;
    }
    if (!izin) {
      SipToast.goster(context, yetkisizMesaji);
      return false;
    }
    return true;
  }

  Future<void> _tahsilat(Customer c) async {
    if (!_yazabilir(izin: widget.yetki.tahsilat)) return;
    final ok = await tahsilatSheet(context,
        db: widget.db, customerId: c.id, bakiyeKurus: c.balanceKurus);
    if (ok == true && mounted) SipToast.goster(context, 'Tahsilat kaydedildi');
  }

  Future<void> _duzeltme(Customer c) async {
    if (!_yazabilir(izin: widget.yetki.defterDuzeltme)) return;
    final ok = await duzeltmeSheet(context,
        db: widget.db, customerId: c.id, bakiyeKurus: c.balanceKurus);
    if (ok == true && mounted) SipToast.goster(context, 'Düzeltme deftere işlendi');
  }

  void _siparis(Customer c) {
    if (!_yazabilir()) return;
    // Kara liste kapısı: engel BURADA, forma girmeden durur. Kullanıcıyı ürün seçtirip son
    // adımda reddetmek, yapılmış emeği çöpe atmaktır.
    if (karaListede(c)) {
      SipToast.goster(context, karaListeSiparisMesaji(c.name));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => OrderFormScreen(db: widget.db, initialCustomerId: c.id, writable: widget.writable),
    ));
  }

  /// Kara listeye al / çıkar. ONAY İSTEMEZ: tek dokunuşla geri alınabilir ve rozet sonucu
  /// anında gösterir — geri alınabilir bir eylemi diyalogla yavaşlatmak bedelsiz değildir.
  Future<void> _karaListe(Customer c) async {
    if (!_yazabilir(izin: widget.yetki.musteriYonetimi)) return;
    final ekle = !karaListede(c);
    await CustomerRepository(widget.db).karaListe(c.id, ekle: ekle);
    if (!mounted) return;
    SipToast.goster(context, ekle ? 'Müşteri kara listeye alındı' : 'Müşteri kara listeden çıkarıldı');
  }

  /// Müşteriyi sil (tombstone). Onay ŞART — ürün olarak geri alınamaz.
  ///
  /// BORÇ UYARISI: bakiyesi sıfır olmayan müşteride tutar diyaloğun içinde yazar. Silmek borcu
  /// SİLMEZ (defter append-only'dir, gün sonu ve istatistikler değişmez) — ama müşteri listeden
  /// düşeceği için bayi o borcu bir daha kendiliğinden görmez. Kullanıcının bilmesi gereken şey
  /// budur: kaybolan para değil, TAKİP.
  Future<void> _sil(Customer c) async {
    if (!_yazabilir(izin: widget.yetki.musteriYonetimi)) return;

    final borc = c.balanceKurus;
    final onay = await sipOnay(
      context,
      baslik: '${c.name} silinsin mi?',
      mesaj: borc > 0
          ? 'Müşteri listeden kaldırılacak. ${formatKurus(borc)} borcu var — '
              'geçmiş kayıtlarda görünmeye devam eder ama listede takip edemezsiniz.'
          : 'Müşteri listeden kaldırılacak. Geçmiş siparişleri ve defter kayıtları silinmez.',
      onayEtiketi: 'Sil',
      tehlike: true,
    );
    if (!onay || !mounted) return;

    await CustomerRepository(widget.db).archive(c.id);
    if (!mounted) return;
    SipToast.goster(context, 'Müşteri silindi');
    // Detay ekranı silinen müşteriyi göstermeye devam edemez: listeye dön. `maybePop` —
    // sipariş iptalindeki desenin aynısı (yığında tek rota kalmışsa sessizce hiçbir şey yapmaz).
    Navigator.of(context).maybePop();
  }

  Future<void> _duzenle(
    Customer c,
    List<CustomerPhone> telefonlar,
    CustomerAddressesData? adres,
  ) async {
    if (!_yazabilir()) return;
    final ok = await musteriDuzenleSheet(context,
        db: widget.db, musteri: c, telefonlar: telefonlar, adres: adres);
    if (ok == true && mounted) SipToast.goster(context, 'Müşteri bilgileri güncellendi');
  }

  /// Adres araması ya da cihaz konumu okuması sürüyor (çip bu sırada dokunuş kabul etmez).
  bool _konumCalisiyor = false;

  /// Ara / WhatsApp / Konum eylemini çalıştırır. Yardımcılar BAŞARIDA `null`, aksi hâlde
  /// kullanıcıya gösterilecek Türkçe gerekçe döner — başarıda toast BASILMAZ: hedef uygulama
  /// zaten öne gelir, üstüne bildirim göstermek gürültüdür.
  ///
  /// `mounted` kontrolü şart: kullanıcı harici uygulamaya geçerken bu ekran kapanmış olabilir.
  Future<void> _eylem(Future<String?> Function() calistir) async {
    final gerekce = await calistir();
    if (gerekce == null || !mounted) return;
    SipToast.goster(context, gerekce);
  }

  /// Yerel adres satırını eylem yardımcılarının anladığı biçime çevirir. Tek dönüşüm noktası:
  /// `konumVar` kararı (lat VE lng dolu mu) burada değil `AdresBilgi`de yaşar, iki kopya olmasın.
  AdresBilgi? _adresBilgisi(CustomerAddressesData? adres) => adres == null
      ? null
      : AdresBilgi(metin: adres.addressText, lat: adres.lat, lng: adres.lng);

  /// Adresten konum: servis aday döner, doğrusunu KULLANICI seçer (otomatik atama yok).
  ///
  /// "Bulunamadı" ile "servis arızası" AYRI cümlelerdir: ilkinde kullanıcı adres metnini
  /// düzeltmeli, ikincisinde beklemeli. Tek bir "konum alınamadı" onu yanlış işi yapmaya iter.
  Future<void> _konumAl(CustomerAddressesData? adres) async {
    if (adres == null) {
      SipToast.goster(context, 'Önce müşteriye adres ekleyin');
      return;
    }
    if (!_yazabilir()) return;
    if (_konumCalisiyor) return;

    setState(() => _konumCalisiyor = true);
    final List<AdresAdayi> adaylar;
    try {
      adaylar = await adresAdaylariGetir(widget.db, adres.addressText);
    } on GeocodeException catch (e) {
      if (!mounted) return;
      setState(() => _konumCalisiyor = false);
      SipToast.goster(context, e.message);
      return;
    }
    if (!mounted) return;
    setState(() => _konumCalisiyor = false);

    if (adaylar.isEmpty) {
      SipToast.goster(context, konumBulunamadiMesaji);
      return;
    }

    final secim = await konumSecSheet(context, adaylar);
    if (secim == null) return;
    await konumKaydet(widget.db, adres, secim.lat, secim.lng);
    if (mounted) SipToast.goster(context, 'Konum kaydedildi');
  }

  /// Konumu CİHAZIN bulunduğu noktayla günceller. Adresten türetilen pin sokağı bulur, kapıyı
  /// bulmaz; kurye ilk teslimatta kapının önünde bu düğmeye basınca pin gerçeğe oturur.
  /// Adres metni, bölge ve etiket DEĞİŞMEZ — yalnız koordinat yazılır.
  Future<void> _konumGuncelle(CustomerAddressesData adres) async {
    if (!_yazabilir()) return;
    if (_konumCalisiyor) return;

    setState(() => _konumCalisiyor = true);
    final CihazKonumu konum;
    try {
      konum = await cihazKonumuOku();
    } on KonumHatasi catch (e) {
      if (!mounted) return;
      setState(() => _konumCalisiyor = false);
      SipToast.goster(context, e.mesaj);
      return;
    }
    if (!mounted) return;
    setState(() => _konumCalisiyor = false);

    await konumKaydet(widget.db, adres, konum.lat, konum.lng);
    if (!mounted) return;
    SipToast.goster(
      context,
      konum.guvenilir ? 'Konum güncellendi' : konumDogrulukUyarisi(konum.dogrulukM),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Customer?>(
      stream: _musteri,
      builder: (context, snap) {
        final c = snap.data;
        if (c == null) {
          return Scaffold(
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  SipUst(baslik: 'Müşteri', onGeri: () => Navigator.of(context).pop()),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: SipSpace.govde),
                    child: SipIskelet(adet: 3),
                  ),
                ],
              ),
            ),
          );
        }
        return StreamBuilder<List<CustomerPhone>>(
          stream: _telefonlar,
          builder: (context, telSnap) {
            final telefonlar = telSnap.data ?? const <CustomerPhone>[];
            return StreamBuilder<List<CustomerAddressesData>>(
              stream: _adresler,
              builder: (context, adrSnap) {
                final adresler = adrSnap.data ?? const <CustomerAddressesData>[];
                return _govde(c, telefonlar, adresler.isEmpty ? null : adresler.first);
              },
            );
          },
        );
      },
    );
  }

  Widget _govde(Customer c, List<CustomerPhone> telefonlar, CustomerAddressesData? adres) {
    final tel = telefonlar.isEmpty ? '' : sipTelefon(telefonlar.first.phoneE164);
    final konumVar = adres?.lat != null && adres?.lng != null;
    final koordinat = konumVar ? konumMetni(adres!.lat!, adres.lng!) : null;
    final not = c.note;

    final maskeli = widget.yetki.telefonMaskeleme;
    final telGoster = maskeli ? telefonMaskele(tel) : tel;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SipUst(
              baslik: c.name,
              alt: telGoster.isEmpty ? null : telGoster,
              onGeri: () => Navigator.of(context).pop(),
              sag: [
                if (widget.yetki.musteriDuzenleme)
                  SipIkonButon(
                    ikon: SipIcons.edit,
                    ikonBoyut: 17,
                    kalinlik: 2,
                    etiket: 'Müşteriyi düzenle',
                    onTap: () => _duzenle(c, telefonlar, adres),
                  ),
              ],
            ),
            Expanded(
              child: SipGovde(
                altBosluk: 104,
                children: [
                  MusteriHeroKart(
                    adres: adresGosterimi(adres?.addressText),
                    telefon: telGoster,
                    koordinat: koordinat,
                    onKonumAl: () => _konumAl(adres),
                    konumCalisiyor: _konumCalisiyor,
                    onAra: () => _eylem(() => musteriyiAra(telefonlar.firstOrNull?.phoneE164)),
                    onWhatsapp: () => _eylem(() async {
                      if (!(widget.yetki.borcHatirlatma)) {
                        return 'Borç hatırlatma yetkisi kapalıdır.';
                      }
                      return whatsappAc(telefonlar.firstOrNull?.phoneE164);
                    }),
                    onKonum: () => _eylem(
                      () => konumuHaritadaAc(_adresBilgisi(adres), etiket: c.name),
                    ),
                    onKonumGuncelle: adres == null ? null : () => _konumGuncelle(adres),
                  ),
                  if (karaListede(c))
                    SipDurumSeridi(
                      metin: karaListeRozeti,
                      ikon: SipIcons.ban,
                      renk: context.sip.danger,
                      zemin: context.sip.dangerSoft,
                    ),
                  MusteriBakiyeKarti(kurus: c.balanceKurus),
                  MusteriAksiyonlari(
                    eylemler: [
                      MusteriEylemi(
                          ikon: SipIcons.plus, etiket: 'Sipariş', onTap: () => _siparis(c)),
                      MusteriEylemi(
                          ikon: SipIcons.wallet, etiket: 'Tahsilat', onTap: () => _tahsilat(c)),
                    ],
                  ),
                  if (not != null && not.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: SipSpace.xl),
                      child: SipNotKutusu(metin: not),
                    ),
                  // FAVORİ ÜRÜNLER — düzenlemesi müşteri düzenleme yetkisine bağlı; GÖRÜNTÜLEMESİ
                  // herkese açık, çünkü listenin asıl işi kurye/bayi siparişi hızlı açsın diye
                  // "bu müşteri ne alır" sorusunu cevaplamaktır.
                  MusteriFavorileri(
                    db: widget.db,
                    customerId: widget.customerId,
                    yazabilir: () =>
                        _yazabilir(izin: widget.yetki.musteriDuzenleme),
                  ),
                  // SİPARİŞ GEÇMİŞİ — `gecmisTeslimatlariGorme` kapısının ARKASINDA. Bu ekran o
                  // kapıyı atlasaydı, geçmiş gün teslimatları kapalı olan kurye aynı bilgiyi
                  // müşteri kartından okurdu; yarısı kapalı bir kapı hiç kapı değildir.
                  if (widget.yetki.gecmisTeslimatlariGorme)
                    MusteriSiparisGecmisi(
                      db: widget.db,
                      customerId: widget.customerId,
                      musteriAdi: c.name,
                      musteriCode: c.code,
                      writable: widget.writable,
                    ),
                  if (widget.yetki.musteriGecmisDefteri)
                    CustomerLedgerSection(
                      db: widget.db,
                      customerId: widget.customerId,
                      onDuzelt: () => _duzeltme(c),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(top: SipSpace.xl),
                      child: SipNotKutusu(
                        metin: 'Müşteri geçmiş defteri kurye yetkisine kapalıdır.',
                        ikon: SipIcons.lock,
                      ),
                    ),
                  // Tehlikeli işlemler KURYEDE HİÇ ÇİZİLMEZ (diğer kapıların aksine).
                  // Gerekçe: tahsilat/düzeltme kuryenin işinin bir parçası, yalnız bu cihazda
                  // yetkisi yok — orada toast doğru cevaptır. Müşteriyi silmek ise kuryenin işi
                  // DEĞİLDİR; düğmeyi gösterip reddetmek ona olmayan bir rol teklif eder.
                  if (widget.yetki.musteriYonetimi)
                    MusteriTehlikeliEylemler(
                      karaListede: karaListede(c),
                      karaListeEtiketi:
                          karaListede(c) ? karaListedenCikarEtiketi : karaListeyeEkleEtiketi,
                      silEtiketi: musteriyiSilEtiketi,
                      onKaraListe: () => _karaListe(c),
                      onSil: () => _sil(c),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
