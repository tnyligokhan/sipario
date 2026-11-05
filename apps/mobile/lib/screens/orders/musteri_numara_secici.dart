// BİRDEN ÇOK NUMARASI OLAN MÜŞTERİDE HANGİ NUMARA? (saha, 2026-11-05)
//
// Saha: "Müşterinin iki numarası varsa ikinci numaradan arandığında arama kaydında birinci numara
// çıkıyor. WhatsApp'a da birinci numara üzerinden gidiyor."
//
// KÖK NEDEN: çağrı günlüğü satırı doğru numarayı taşıyordu (`call_logs.phone_e164` gerçekten arayan
// numaradır). Numara satıra dokununca kayboluyordu: müşteri kartı çağrının hangi numaradan geldiğini
// bilmeden açılıyor, başlığında ve Ara/WhatsApp düğmelerinde `telefonlar.first`i kullanıyordu. Sipariş
// satırı ile borçlu kartı da yalnız birincil numarayı biliyordu.
//
// KURAL (tek yerde, bütün eylem düğmeleri buradan geçer):
//   1. Kart bir çağrıdan açıldıysa ve o numara müşterinindir → doğrudan o numara.
//   2. Müşterinin tek numarası varsa → soru sorulmaz, o numara.
//   3. Birden çok numara varsa → seçim sheet'i. En son arayan numara başta ve işaretlidir.
//
// Sheet'teki numaralar yetkiye göre maskelenir: `telefonMaskeleme` açık kuryeye tam numara gösterilmez.
// Yetki eylem anında okunur (`TeslimAkisi` ile aynı gerekçe: sipariş satırı yetki taşımaz).

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../data/outbox.dart' show phoneLast10;
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../team.dart';
import 'musteri_eylemleri.dart';
import 'order_sheets.dart' show SecimSatiri;

class MusteriNumaraSecici {
  const MusteriNumaraSecici({
    required this.db,
    required this.customerId,
    this.arayanNumara,
    this.yedekNumara,
  });

  final AppDatabase db;
  final String customerId;

  /// Kart bir çağrıdan açıldıysa o çağrının numarası.
  final String? arayanNumara;

  /// Kayıtlı telefon satırı okunamazsa kullanılacak numara (ekranın elindeki birincil numara).
  final String? yedekNumara;

  /// Arama başarılıysa ya da kullanıcı vazgeçtiyse null, aksi hâlde Türkçe gerekçe.
  Future<String?> ara(BuildContext context) =>
      _uygula(context, baslik: 'Hangi numara aransın?', eylem: musteriyiAra);

  /// WhatsApp açıldıysa ya da kullanıcı vazgeçtiyse null, aksi hâlde Türkçe gerekçe.
  Future<String?> whatsapp(BuildContext context, {String? mesaj}) => _uygula(
        context,
        baslik: 'Hangi numaraya yazılsın?',
        eylem: (numara) => whatsappAc(numara, mesaj: mesaj),
      );

  Future<String?> _uygula(
    BuildContext context, {
    required String baslik,
    required Future<String?> Function(String? numara) eylem,
  }) async {
    final numaralar = await _numaralar();
    if (!context.mounted) return null;

    if (numaralar.length < 2) {
      return eylem(numaralar.isEmpty ? yedekNumara : numaralar.single.phoneE164);
    }

    final arayan = _arayanSatiri(numaralar);
    if (arayan != null) return eylem(arayan.phoneE164);

    final sonArayan = await _sonArayanAnahtar(numaralar);
    final maskeli = (await oturumYetkileri(db)).telefonMaskeleme;
    if (!context.mounted) return null;

    final secilen = await sipSheet<String>(
      context,
      baslik: baslik,
      govde: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final p in _sonArayanBasta(numaralar, sonArayan))
            SecimSatiri(
              etiket: _etiket(p, sonArayan: sonArayan, maskeli: maskeli),
              ikon: SipIcons.phone,
              secili: p.phoneLast10 == sonArayan,
              onTap: () => Navigator.of(ctx).pop(p.phoneE164),
            ),
        ],
      ),
    );
    if (secilen == null) return null;
    return eylem(secilen);
  }

  /// Müşterinin arşivlenmemiş numaraları; birincil başta. Sıra müşteri kartıyla AYNI.
  Future<List<CustomerPhone>> _numaralar() => (db.select(db.customerPhones)
        ..where((t) => t.customerId.equals(customerId) & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.isPrimary), (t) => OrderingTerm.asc(t.id)]))
      .get();

  CustomerPhone? _arayanSatiri(List<CustomerPhone> numaralar) =>
      musteriNumarasiBul(numaralar, arayanNumara);

  /// Bu müşterinin numaralarından en son arayanın eşleşme anahtarı; hiç arama yoksa null.
  Future<String?> _sonArayanAnahtar(List<CustomerPhone> numaralar) async {
    final anahtarlar = numaralar.map((p) => p.phoneLast10).toList();
    final son = await (db.select(db.callLogs)
          ..where((t) => t.phoneLast10.isIn(anahtarlar) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
          ..limit(1))
        .getSingleOrNull();
    return son?.phoneLast10;
  }

  static List<CustomerPhone> _sonArayanBasta(List<CustomerPhone> numaralar, String? sonArayan) => [
        ...numaralar.where((p) => p.phoneLast10 == sonArayan),
        ...numaralar.where((p) => p.phoneLast10 != sonArayan),
      ];

  static String _etiket(CustomerPhone p, {required String? sonArayan, required bool maskeli}) {
    final numara = maskeli ? telefonMaskele(p.phoneE164) : sipTelefon(p.phoneE164);
    return p.phoneLast10 == sonArayan ? '$numara (son arayan)' : numara;
  }
}

/// [numaralar] içinde [numara] ile aynı hattı (son 10 hane) bulur; yoksa null.
///
/// Müşteri kartının başlığı da buna bakar: başlıktaki numara ile düğmenin kullandığı numara
/// aynı kuraldan çıkmalı.
CustomerPhone? musteriNumarasiBul(List<CustomerPhone> numaralar, String? numara) {
  if (numara == null) return null;
  final anahtar = phoneLast10(numara);
  if (anahtar.length < 10) return null;
  for (final p in numaralar) {
    if (p.phoneLast10 == anahtar) return p;
  }
  return null;
}
