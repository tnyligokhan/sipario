// BAYİNİN GİDER KATEGORİLERİ (kullanıcı isteği 2026-11-05) — `tenant_settings.expense_categories_json`.
//
// Değişmez değer nesnesi. Kategori bir ETİKETTİR: gider sheet'inde dokununca açıklama alanını doldurur,
// kilitlemez. Kayda metin olarak geçer, bu listeyle bağı yoktur; yani listeden silmek eski giderleri
// etkilemez ve bayi listede olmayan bir şeyi yazmaya devam edebilir. Bu kural 2026-08-25 kararının
// devamıdır: kapalı bir liste, listede olmayan gideri "Diğer"e sürerdi.
//
// HİÇ DÜZENLENMEMİŞ BAYİ (kolon null) [varsayilan] listeyi görür.

import 'dart:convert';

import '../theme/components/bicim.dart' show trKucuk;

class GiderKategorileri {
  const GiderKategorileri._(this.adlar);

  /// Sunucudaki `GiderKategorileri` sınırlarıyla AYNI.
  static const int azamiKategori = 40;
  static const int azamiHane = 40;

  static const GiderKategorileri varsayilan =
      GiderKategorileri._(['Yakıt', 'Tamir', 'Yemek', 'Nakliye', 'Personel avansı']);

  factory GiderKategorileri.coz(String? json) {
    if (json == null || json.trim().isEmpty) return varsayilan;
    final Object? cozulen;
    try {
      cozulen = jsonDecode(json);
    } catch (_) {
      return varsayilan;
    }
    if (cozulen is! List) return varsayilan;
    final adlar = [
      for (final e in cozulen)
        if (e is String && e.trim().isNotEmpty) e.trim(),
    ];
    return adlar.isEmpty ? varsayilan : GiderKategorileri._(adlar);
  }

  final List<String> adlar;

  /// Son kategori silinemez: boş liste sunucuda null'a iner ve varsayılan liste geri gelirdi.
  bool get silinebilir => adlar.length > 1;

  /// [ad] eklenemiyorsa kullanıcıya gösterilecek gerekçe, eklenebiliyorsa null.
  String? eklemeHatasi(String ad) {
    final temiz = ad.trim();
    if (temiz.isEmpty) return 'Kategori adı yazın';
    if (temiz.length > azamiHane) return 'Kategori adı en çok $azamiHane karakter olabilir';
    if (adlar.length >= azamiKategori) return 'En çok $azamiKategori kategori eklenebilir';
    final anahtar = trKucuk(temiz);
    if (adlar.any((a) => trKucuk(a) == anahtar)) return 'Bu kategori zaten var';
    return null;
  }

  GiderKategorileri ile(String ad) => GiderKategorileri._([...adlar, ad.trim()]);

  GiderKategorileri haric(String ad) =>
      GiderKategorileri._([for (final a in adlar) if (a != ad) a]);

  String yaz() => jsonEncode(adlar);
}
