// MÜŞTERİ LİSTESİ SORGULARI — ekranın okuduğu her şey.
//
// NEDEN AYRI DOSYA: `customer_list_screen.dart` 553 satıra çıkmıştı (depo sınırı 500). Ayrım
// KONUYA göre ve zaten dosyanın içindeki "Sorgular" banner'ıyla çizilmişti: yukarısı EKRAN
// (widget ağacı, dokunuşlar, kapılar), burası VERİ (sıra kuralı, arama normalizasyonu, kurye
// kapsamı). İkisi ayrı sorulardır ve sorgular ekrandan bağımsız, saf async testle sınanır.
//
// NEDEN `part` (ayrı kütüphane değil): `watchCustomerRows` · `watchCustomers` · `watchDebtCount`
// mevcut testlerin ve başka ekranların `customer_list_screen.dart`tan import ettiği ADLARDIR.
// Ayrı kütüphane yapmak ya her çağrı yerini değiştirmeyi ya da bir `export` köprüsü kurmayı
// gerektirirdi; `part` ile hiçbir çağrı yeri DEĞİŞMEZ. Aynı desen: `tables.dart` →
// `tables_isletme.dart`, `pos_catalog.dart` → `pos_karosu.dart`.

part of 'customer_list_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Sorgular
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Liste satırının verisi: müşteri + görüntü telefonu + birincil adres.
typedef CustomerRow = ({Customer customer, String? phone, CustomerAddressesData? adres});

/// LİSTENİN TEK SIRA KURALI: "en son kaydedilen en üstte" (kullanıcı isteği 2026-08-06).
///
/// ESKİDEN ADA GÖREYDİ ve kullanıcıya RASGELE görünüyordu: SQLite'ın varsayılan BINARY
/// collation'ı baytları karşılaştırır, Türkçe harfler (Ç Ğ İ Ö Ş Ü) çok baytlı UTF-8'dir ve
/// TÜM ASCII harflerden SONRA sıralanır — "Şükrü" listenin dibine, "Zeynep"in bile altına düşer.
/// Kullanıcı zaten alfabe aramıyor; az önce kaydettiğini arıyor.
///
/// Terimler:
///  1. `code IS NULL DESC` → kodu olmayan müşteri EN ÜSTTE. Kodu sunucu atar; kodsuz kayıt =
///     henüz senkronlanmamış = en yeni. (`NULLS FIRST` yerine bu ifade — sqlite sürümünden
///     bağımsız çalışır.)
///  2. `code DESC` → kod kiracı içinde artan sayaçtır (100, 101, …); büyük kod yeni müşteridir.
///  3. `rowid DESC` → kodsuz gruptaki ayırıcı: yerel INSERT sırası, yani tam olarak "kaydetme
///     sırası". Deterministiktir (aynı milisaniyede üretilen iki UUIDv7'nin sırası değildir).
///
/// `updated_occurred_at` BİLEREK KULLANILMADI: her düzenlemede (ad düzeltme, kara liste, adres)
/// tazeleniyor — tek başına "kayıt sırası" DEĞİLDİR; adı düzeltilen üç yıllık müşteri listenin
/// başına fırlardı. `rowid` UPDATE'te değişmez; senkron da satırları `insertOnConflictUpdate`
/// (yani `INSERT OR REPLACE` DEĞİL) ile yazdığından rowid korunur.
final List<OrderClauseGenerator<$CustomersTable>> _enYeniOnce = [
  (t) => OrderingTerm.desc(t.code.isNull()),
  (t) => OrderingTerm.desc(t.code),
  (t) => OrderingTerm.desc(t.rowId),
];

/// KURYE KAPSAMI (kullanıcı kararı 2026-08-22) — [kullaniciId] verilirse müşteri listesi
/// YALNIZ o kullanıcının işi olan müşterilerle sınırlanır.
///
/// "İŞİ OLAN" = o siparişe ATANMIŞ ya da onu TESLİM ETMİŞ olmak. İkisi birlikte sorulur ve bu
/// önemli: atama sonradan başkasına geçebilir (`unassigned` → yeniden `assigned`), ama malı
/// fiilen kapıya götüren kişinin o müşteriyi görmeye devam etmesi gerekir — dün teslim ettiği
/// adresi bugün bulamayan kurye, düzeltme yapamaz ve borcu konuşamaz.
///
/// İPTAL/SİLİNMİŞ SİPARİŞ DE SAYILIR: kurye iptal edilen bir siparişin müşterisine zaten
/// gitmiş olabilir. Kapsamı `status`a bağlamak, kuryenin ekranından o kaydı sipariş kapandığı
/// an kaçırırdı.
///
/// SORGUDA, EKRANDA DEĞİL (`watchOrders(assignedTo:)` ile aynı gerekçe): listeyi çekip Dart
/// tarafında elemek, arama sonucuyla birleştiğinde sessizce yanlış olurdu.
Expression<bool> _kuryeKapsami(AppDatabase db, String kullaniciId) {
  final iliski = db.selectOnly(db.orders)
    ..addColumns([db.orders.id])
    ..where(db.orders.customerId.equalsExp(db.customers.id) &
        (db.orders.assignedUserId.equals(kullaniciId) |
            db.orders.deliveredByUserId.equals(kullaniciId)));
  return existsQuery(iliski);
}

/// Liste akışı. Telefon ve adres LEFT JOIN'dir — ikisi de olmayan müşteri de listede kalır.
/// Sorguda 3+ rakam varsa telefon araması (son-10 normalizasyonu — arayan tanımanın kuralı),
/// yoksa ad araması.
///
/// [kullaniciId] verilirse liste o kullanıcının kapsamına kısılır ([_kuryeKapsami]); null =
/// bayinin tamamı. Kararı ekran değil YETKİ verir (`yetkiler().tumMusterileriGorme`).
Stream<List<CustomerRow>> watchCustomerRows(AppDatabase db, String query,
    {String? kullaniciId}) {
  final q = query.trim();
  final kapsam =
      kullaniciId == null ? const Constant(true) : _kuryeKapsami(db, kullaniciId);

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
    sel.where(db.customers.deletedAt.isNull() & kapsam);
  } else {
    final digits = _numaraGovdesi(q);
    if (digits != null) {
      // EXISTS: herhangi bir telefonu eşleşen müşteri (görüntü telefonu yine birincil kalır).
      final match = db.selectOnly(db.customerPhones)
        ..addColumns([db.customerPhones.id])
        ..where(db.customerPhones.customerId.equalsExp(db.customers.id) &
            db.customerPhones.deletedAt.isNull() &
            db.customerPhones.phoneLast10.like('%$digits%'));
      // ⚠️ KAPSAM ARAMAYA DA UYGULANIR: yalnız boş sorguda süzmek, kuryenin numarayı yazarak
      // görmemesi gereken müşteriye ulaşması demekti — yetkiyi arama kutusuyla atlatmak.
      sel.where(db.customers.deletedAt.isNull() & existsQuery(match) & kapsam);
    } else {
      sel.where(db.customers.deletedAt.isNull() & db.customers.name.like('%$q%') & kapsam);
    }
  }

  // isPrimary terimleri SİLİNEMEZ ve sıra kuralının ARDINDA kalmak zorundadır: aşağıdaki
  // tekilleştirme "ilk gelen satır kazanır" der, yani müşterinin hangi telefon/adresinin
  // görüneceğini bu iki terim seçer. Önlerine geçselerdi yanlış telefon çizilirdi.
  sel.orderBy([
    ..._enYeniOnce.map((f) => f(db.customers)),
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
///
/// [kullaniciId] LİSTEYLE AYNI KAPSAMI alır ve bu şart: sayaç geniş, liste dar kalsaydı kurye
/// "12 borçlu müşteri" başlığının altında üç satır görür ve dokuzunun nereye gittiğini sorardı.
Stream<int> watchDebtCount(AppDatabase db, {String? kullaniciId}) {
  final count = db.customers.id.count();
  final kapsam =
      kullaniciId == null ? const Constant(true) : _kuryeKapsami(db, kullaniciId);
  final q = db.selectOnly(db.customers)
    ..addColumns([count])
    ..where(db.customers.deletedAt.isNull() &
        db.customers.balanceKurus.isBiggerThanValue(0) &
        kapsam);
  return q.watchSingle().map((r) => r.read(count) ?? 0);
}

/// Müşteri listesi sorgusu (arşivsizler, en son kaydedilen en üstte — bkz. [_enYeniOnce]).
/// Liste ekranı artık [watchCustomerRows]'u kullanır; bu fonksiyon KORUNDU çünkü
/// arama/normalizasyon sözleşmesi doğrudan onun üzerinden test ediliyor. Sıra kuralı ikisinde
/// AYNI olmalı — arama sonucu da aynı mantıkla dizilir.
Stream<List<Customer>> watchCustomers(AppDatabase db, String query) {
  final q = query.trim();
  if (q.isEmpty) {
    return (db.select(db.customers)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy(_enYeniOnce))
        .watch();
  }

  final digits = _numaraGovdesi(q);
  if (digits != null) {
    final join = db.select(db.customers).join([
      innerJoin(db.customerPhones, db.customerPhones.customerId.equalsExp(db.customers.id)),
    ])
      ..where(db.customers.deletedAt.isNull() & db.customerPhones.phoneLast10.like('%$digits%'))
      ..orderBy(_enYeniOnce.map((f) => f(db.customers)).toList());
    return join.watch().map((rows) =>
        {for (final r in rows) r.readTable(db.customers).id: r.readTable(db.customers)}
            .values
            .toList());
  }

  return (db.select(db.customers)
        ..where((t) => t.deletedAt.isNull() & t.name.like('%$q%'))
        ..orderBy(_enYeniOnce))
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
