// Müşteriler listesi — CSS `.mliste` / `.mrow*`, kaynak s-musteriler.jsx `MusterilerEkran`.
// Üstte başlık + borçlu sayısı, altında hap arama çubuğu, sonra kart satırları:
// avatar · ad · telefon · adres (konum varsa pin YEŞİL) · sağda bakiye çipi (0 ise çip YOK).
//
// Sorgu mantığı ekrandan bağımsız fonksiyonlardadır (watchCustomerRows/watchCustomers/
// watchDebtCount) — saf async testle sınanır; widget-test sahte zamanı drift akışlarında
// güvenilmez (Dilim 1 dersi).

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

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

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({
    super.key,
    required this.db,
    required this.writable,
    this.yetki,
    this.onMenu,
  });

  final AppDatabase db;
  final bool writable;

  /// Rol bazlı yetki (K2). null → tam yetki (giriş öncesi/test yolu); detaydaki tahsilat ve
  /// defter düzeltme kapıları buradan gelir.
  final RolYetkileri? yetki;

  /// Çekmeceyi açan geri çağrım (kabuk verir). null ise hamburger çizilmez.
  final VoidCallback? onMenu;

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final _arama = TextEditingController();
  String _sorgu = '';

  // Başlıktaki borçlu sayısı — bir kez abone ol (tuş başına yeniden abonelik/titreme olmasın).
  late final Stream<int> _borcluSayisi = watchDebtCount(widget.db);

  @override
  void dispose() {
    _arama.dispose();
    super.dispose();
  }

  Future<void> _yeniMusteri() async {
    if (!widget.writable) {
      SipToast.goster(context, 'Salt-okunur kip: yeni kayıt eklenemez.');
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
                  alt: n > 0 ? '$n borçlu müşteri' : 'Tüm hesaplar temiz',
                  onMenu: widget.onMenu,
                  sag: [
                    SipMetinButon(
                      etiket: 'Yeni',
                      ikon: SipIcons.plus,
                      onTap: _yeniMusteri,
                    ),
                  ],
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(SipSpace.govde, SipSpace.xs, SipSpace.govde, SipSpace.xl),
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
            Expanded(
              child: StreamBuilder<List<CustomerRow>>(
                stream: watchCustomerRows(widget.db, _sorgu),
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
        aciklama: '"$arama" için müşteri bulunamadı.',
      );
    }
    return SipBosDurum(
      ikon: SipIcons.users,
      baslik: 'Henüz müşteri yok',
      aciklama: 'Gelen çağrıdan ya da + Yeni ile ilk müşterini ekle.',
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
  const _MusteriSatiri({required this.satir, required this.onAc});

  final CustomerRow satir;
  final VoidCallback onAc;

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
        // CSS `.mrow-bal { align-self: center }` — çip satırın ortasında durur. Ad/telefon/adres
        // yığını her zaman çipten uzundur, dolayısıyla satırın yüksekliğini o belirler ve
        // `center` yalnız çipi etkiler (sabit `Padding(top: 7)` yerine).
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // KOD ADIN BAŞINDA (kullanıcı isteği 2026-07-29): bayi müşteriyi numarasıyla
                // anıyor ("102 arıyor"). Kod ile ad AYNI satırda ve kod DARALMAZ: uzun bir adda
                // kısalması gereken addır, kimliği taşıyan sayı değil.
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
                    // Rozet ADIN HEMEN YANINDA (satır sonunda değil): bakiye çipiyle aynı
                    // hizaya konsaydı uzun adlarda ondan uzaklaşır ve hangi müşteriye ait
                    // olduğu bulanıklaşırdı. Ad `Flexible` — kısalması gereken addır, rozet değil.
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
                    metin: sipTelefon(satir.phone!),
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

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Sorgular
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Liste satırının verisi: müşteri + görüntü telefonu + birincil adres.
typedef CustomerRow = ({Customer customer, String? phone, CustomerAddressesData? adres});

/// Liste akışı. Telefon ve adres LEFT JOIN'dir — ikisi de olmayan müşteri de listede kalır.
/// Sorguda 3+ rakam varsa telefon araması (son-10 normalizasyonu — arayan tanımanın kuralı),
/// yoksa ad araması.
Stream<List<CustomerRow>> watchCustomerRows(AppDatabase db, String query) {
  final q = query.trim();

  final sel = db.select(db.customers).join([
    leftOuterJoin(
      db.customerPhones,
      db.customerPhones.customerId.equalsExp(db.customers.id) &
          db.customerPhones.deletedAt.isNull(),
    ),
    leftOuterJoin(
      db.customerAddresses,
      db.customerAddresses.customerId.equalsExp(db.customers.id) &
          db.customerAddresses.deletedAt.isNull(),
    ),
  ]);

  if (q.isEmpty) {
    sel.where(db.customers.deletedAt.isNull());
  } else {
    final digits = _numaraGovdesi(q);
    if (digits != null) {
      // EXISTS: herhangi bir telefonu eşleşen müşteri (görüntü telefonu yine birincil kalır).
      final match = db.selectOnly(db.customerPhones)
        ..addColumns([db.customerPhones.id])
        ..where(db.customerPhones.customerId.equalsExp(db.customers.id) &
            db.customerPhones.deletedAt.isNull() &
            db.customerPhones.phoneLast10.like('%$digits%'));
      sel.where(db.customers.deletedAt.isNull() & existsQuery(match));
    } else {
      sel.where(db.customers.deletedAt.isNull() & db.customers.name.like('%$q%'));
    }
  }

  sel.orderBy([
    OrderingTerm.asc(db.customers.name),
    OrderingTerm.desc(db.customerPhones.isPrimary),
    OrderingTerm.desc(db.customerAddresses.isPrimary),
  ]);

  return sel.watch().map((rows) {
    // JOIN çarpımını müşteri başına tek satıra indir: ilk gelen (sıralama gereği birincil) kazanır.
    final byId = <String, CustomerRow>{};
    for (final r in rows) {
      final c = r.readTable(db.customers);
      final p = r.readTableOrNull(db.customerPhones);
      final a = r.readTableOrNull(db.customerAddresses);
      final mevcut = byId[c.id];
      byId[c.id] = (
        customer: c,
        phone: mevcut?.phone ?? p?.phoneE164,
        adres: mevcut?.adres ?? a,
      );
    }
    return byId.values.toList();
  });
}

/// Başlıktaki "N borçlu müşteri" için canlı sayım (bakiyesi + olan müşteriler).
Stream<int> watchDebtCount(AppDatabase db) {
  final count = db.customers.id.count();
  final q = db.selectOnly(db.customers)
    ..addColumns([count])
    ..where(db.customers.deletedAt.isNull() & db.customers.balanceKurus.isBiggerThanValue(0));
  return q.watchSingle().map((r) => r.read(count) ?? 0);
}

/// Müşteri listesi sorgusu (arşivsizler, ada göre sıralı). Liste ekranı artık
/// [watchCustomerRows]'u kullanır; bu fonksiyon KORUNDU çünkü arama/normalizasyon sözleşmesi
/// doğrudan onun üzerinden test ediliyor.
Stream<List<Customer>> watchCustomers(AppDatabase db, String query) {
  final q = query.trim();
  if (q.isEmpty) {
    return (db.select(db.customers)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  final digits = _numaraGovdesi(q);
  if (digits != null) {
    final join = db.select(db.customers).join([
      innerJoin(db.customerPhones, db.customerPhones.customerId.equalsExp(db.customers.id)),
    ])
      ..where(db.customers.deletedAt.isNull() & db.customerPhones.phoneLast10.like('%$digits%'))
      ..orderBy([OrderingTerm.asc(db.customers.name)]);
    return join.watch().map((rows) =>
        {for (final r in rows) r.readTable(db.customers).id: r.readTable(db.customers)}
            .values
            .toList());
  }

  return (db.select(db.customers)
        ..where((t) => t.deletedAt.isNull() & t.name.like('%$q%'))
        ..orderBy([(t) => OrderingTerm.asc(t.name)]))
      .watch();
}

/// Kullanıcı yazımını numara gövdesine indirir; 3'ten az rakam varsa null (= ad araması).
/// DB'de phone_last10 '5321112233' biçimindedir; '+90'/'90' ve baştaki 0 atılmazsa eşleşme kaçar.
String? _numaraGovdesi(String query) {
  var digits = query.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 3) return null;
  if (digits.startsWith('90') && digits.length > 10) digits = digits.substring(2);
  while (digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  return phoneLast10(digits);
}
