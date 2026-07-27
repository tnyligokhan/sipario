// Müşteri detayı — kaynak s-musteriler.jsx `MusteriDetay`.
// Bloklar: koyu iletişim kartı (`.md-kart`) · bakiye kartı (`.md-bal`) · 4'lü hızlı eylem
// (`.md-akslar`) · not (`.md-not`) · defter hareketleri (`.defter`).
// Kartların görsel gövdesi customer_detail_cards.dart'ta, defter customer_ledger.dart'ta —
// bu dosya veriyi bağlar ve eylemleri (yetki/salt-okunur kapılarıyla) yürütür.

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../orders/order_form_screen.dart';
import '../team.dart';
import 'customer_detail_cards.dart';
import 'customer_form_ops.dart';
import 'customer_form_screen.dart';
import 'customer_ledger.dart';
import 'customer_location_picker.dart';
import 'customer_sheets.dart';
import 'customer_widgets.dart';

class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({
    super.key,
    required this.db,
    required this.customerId,
    required this.writable,
    this.yetki,
  });

  final AppDatabase db;
  final String customerId;
  final bool writable;

  /// Rol bazlı yetki (K2). null → tam yetki. Defter düzeltme yönetici işidir; kurye tahsilat
  /// alır ama defteri düzeltemez.
  final RolYetkileri? yetki;

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
    if (!_yazabilir(izin: widget.yetki?.tahsilat ?? true)) return;
    final ok = await tahsilatSheet(context,
        db: widget.db, customerId: c.id, bakiyeKurus: c.balanceKurus);
    if (ok == true && mounted) SipToast.goster(context, 'Tahsilat kaydedildi');
  }

  Future<void> _duzeltme(Customer c) async {
    if (!_yazabilir(izin: widget.yetki?.defterDuzeltme ?? true)) return;
    final ok = await duzeltmeSheet(context,
        db: widget.db, customerId: c.id, bakiyeKurus: c.balanceKurus);
    if (ok == true && mounted) SipToast.goster(context, 'Düzeltme deftere işlendi');
  }

  void _siparis(Customer c) {
    if (!_yazabilir()) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => OrderFormScreen(db: widget.db, initialCustomerId: c.id, writable: widget.writable),
    ));
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

  /// Adresten konum: servis aday döner, doğrusunu KULLANICI seçer (otomatik atama yok).
  Future<void> _konumAl(CustomerAddressesData? adres) async {
    if (adres == null) {
      SipToast.goster(context, 'Önce müşteriye adres ekleyin');
      return;
    }
    if (!_yazabilir()) return;
    final secim = await konumSecSheet(context, adresAdaylari(adres.addressText, adres.region));
    if (secim == null) return;
    await konumKaydet(widget.db, adres, secim.lat, secim.lng);
    if (mounted) SipToast.goster(context, 'Konum kaydedildi');
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

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SipUst(
              baslik: c.name,
              alt: tel.isEmpty ? null : tel,
              onGeri: () => Navigator.of(context).pop(),
              sag: [
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
                    adres: adresGosterimi(adres?.addressText, adres?.region),
                    // Telefonsuz müşteride tasarımın `.md-kart-tel`i BOŞ kalır (s-musteriler.jsx:106)
                    // — "Telefon yok" diye bir metin yazmaz.
                    telefon: tel,
                    koordinat: koordinat,
                    onKonumAl: () => _konumAl(adres),
                    // Arama/WhatsApp/harita cihaz uygulamalarını açacak (url_launcher henüz
                    // bağımlılıkta yok) — şimdilik tasarımdaki `ping` davranışı.
                    onAra: () => SipToast.goster(context, '${c.name} aranıyor…'),
                    onWhatsapp: () => SipToast.goster(context, 'WhatsApp açılıyor…'),
                    onKonum: () => SipToast.goster(
                      context,
                      konumVar
                          ? 'Konum haritada açılıyor ($koordinat)…'
                          : 'Konum kayıtlı değil — önce Adresten Konum Al',
                    ),
                  ),
                  MusteriBakiyeKarti(kurus: c.balanceKurus),
                  // Tasarımda ızgara İKİ eylemlidir (s-musteriler.jsx:118-121, inline
                  // `gridTemplateColumns: '1fr 1fr'`). Bakiye düzeltmesinin yeri defter
                  // başlığının sağındaki bağlantı.
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
                  CustomerLedgerSection(
                    db: widget.db,
                    customerId: widget.customerId,
                    // Bağlantı HER ZAMAN çizilir (tasarımda koşulsuz); salt-okunur ve yetki
                    // kapıları `_duzeltme` içinde durur ve kullanıcıya toast'la söylenir.
                    onDuzelt: () => _duzeltme(c),
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
