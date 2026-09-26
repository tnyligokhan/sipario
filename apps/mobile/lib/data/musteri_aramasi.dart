// MÜŞTERİ ARAMASI — arama kutusuna yazılanın TEK çözümü (kullanıcı şikâyeti 2026-09-26).
//
// NEDEN VAR: iki ekran müşteri arıyor (Müşteriler listesi, yeni siparişin müşteri adımı) ve
// ikisi de "müşteri koduna göre arama çalışmıyor" diye şikâyet aldı. Kök aynıydı: sorguda 3+
// rakam varsa doğrudan TELEFON aramasına gidiliyordu, 3'ten azsa AD aramasına — `code` kolonu
// hiçbir dalda sorulmuyordu. Bayinin eski sisteminden taşınan numara (2–9852) aranamaz
// durumdaydı. Üstelik sipariş ekranı kuralı KENDİ kopyasıyla yazmıştı (Türkçe katlama da yoktu);
// iki kopya iki ayrı arıza demekti. Kural artık burada ve bir kez yazılı.
//
// SÖZLEŞME:
//  • Yalnız rakam (başta `#` olabilir) → KOD tam eşleşmesi. 3+ rakamsa telefon da aranır;
//    ikisi VEYA ile birleşir ("105" hem 105 numaralı müşteriyi hem numarasında 105 geçenleri
//    getirir). Kod eşleşmesi listede EN ÜSTE çıkar ([oncelik]).
//  • Karışık metinde 3+ rakam → telefon (son-10 normalizasyonu — arayan tanımanın kuralı).
//  • Aksi hâlde → ad (`name_folded` üzerinden, bkz. `ad_anahtari.dart`).

import 'package:drift/drift.dart';

import 'ad_anahtari.dart';
import 'app_database.dart';
import 'outbox.dart' show phoneLast10;

/// Çözülmüş bir müşteri arama sorgusu. Durumu (hangi alanlara bakılacağı) yazımdan bir kez
/// çıkarır; sorgu üreten davranışlar bu duruma göre işler.
class MusteriAramasi {
  MusteriAramasi(String yazim)
      : metin = yazim.trim(),
        kod = _kodCoz(yazim.trim()),
        telefonGovdesi = _numaraGovdesi(yazim.trim());

  /// Kırpılmış ham yazım.
  final String metin;

  /// Müşteri kodu olarak okunabiliyorsa değeri. Yalnız rakamdan (başta `#`) oluşan yazımda dolar.
  final int? kod;

  /// Telefonun son-10 biçimine indirilmiş gövdesi; 3'ten az rakam varsa null.
  final String? telefonGovdesi;

  bool get bos => metin.isEmpty;

  /// Müşteri satırı için WHERE ifadesi. Boş yazımda her müşteri eşleşir.
  ///
  /// Telefon EXISTS ile sorulur (JOIN değil): birden çok numarası olan müşteri satır
  /// çoğaltmaz ve silinmiş numara eşleşmez.
  Expression<bool> eslesme(AppDatabase db) {
    if (bos) return const Constant(true);

    final govde = telefonGovdesi;
    final telefon = govde == null ? null : _telefonEslesmesi(db, govde);
    final k = kod;
    if (k != null) {
      final kodEslesmesi = db.customers.code.equals(k);
      return telefon == null ? kodEslesmesi : (kodEslesmesi | telefon);
    }
    if (telefon != null) return telefon;
    return db.customers.nameFolded.like('%${adAnahtari(metin)}%');
  }

  /// Kod tam eşleşmesini listenin başına alan sıra terimi; kod aranmıyorsa null.
  ///
  /// "105" yazan bayi 105 numaralı müşteriyi arıyordur; numarasında 105 geçen onlarca kişinin
  /// altında kalmamalı.
  OrderingTerm? oncelik($CustomersTable t) {
    final k = kod;
    return k == null ? null : OrderingTerm.desc(t.code.equals(k));
  }

  static Expression<bool> _telefonEslesmesi(AppDatabase db, String govde) {
    final eslesen = db.selectOnly(db.customerPhones)
      ..addColumns([db.customerPhones.id])
      ..where(db.customerPhones.customerId.equalsExp(db.customers.id) &
          db.customerPhones.deletedAt.isNull() &
          db.customerPhones.phoneLast10.like('%$govde%'));
    return existsQuery(eslesen);
  }

  /// "105", "#105", "# 105" → 105. Harf ya da ayraç içeren yazım kod DEĞİLDİR. 9 haneden uzun
  /// yazım (telefon) kod sayılmaz — sunucudaki kod 32 bit tamsayıdır.
  static int? _kodCoz(String q) {
    final m = RegExp(r'^#?\s*(\d{1,9})$').firstMatch(q);
    return m == null ? null : int.parse(m.group(1)!);
  }

  /// Kullanıcı yazımını numara gövdesine indirir; 3'ten az rakam varsa null.
  /// DB'de phone_last10 '5321112233' biçimindedir; '+90'/'90' ve baştaki 0 atılmazsa eşleşme kaçar.
  static String? _numaraGovdesi(String q) {
    var rakam = q.replaceAll(RegExp(r'\D'), '');
    if (rakam.length < 3) return null;
    if (rakam.startsWith('90') && rakam.length > 10) rakam = rakam.substring(2);
    while (rakam.startsWith('0')) {
      rakam = rakam.substring(1);
    }
    // "000" sıfırları atılınca boş kalır; boş gövde `LIKE '%%'` olur ve HERKESİ eşlerdi.
    if (rakam.isEmpty) return null;
    return phoneLast10(rakam);
  }
}
