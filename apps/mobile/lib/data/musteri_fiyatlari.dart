// MÜŞTERİYE ÖZEL FİYAT LİSTESİ (kullanıcı isteği 2026-11-05) — `customers.product_prices_json`.
//
// Değişmez değer nesnesi: ürün kimliği → birim fiyat (kuruş). Sipariş kalemi eklenirken katalog
// fiyatının yerine geçer ve SATIRA kopyalanır; yani bu liste sonradan değişirse eski siparişler
// değişmez (`order_lines.unit_price_kurus`: siparişin çekildiği andaki gerçek).
//
// Ekstralar (`SecenekSecimi.ekTutarKurus`) bu fiyatın ÜSTÜNE biner; özel fiyat ürünün taban fiyatıdır.
//
// ÇÖZÜM ÇÖKMEZ: alan müşteri satırının içindedir ve müşteri satırı her yerde okunur. Bozuk metin boş
// listeye düşer (`favoriIdleriCoz` ile aynı gerekçe).

import 'dart:convert';

class MusteriFiyatlari {
  const MusteriFiyatlari._(this._fiyatlar);

  /// Sunucudaki `MusteriFiyatlari::AZAMI_URUN` ile AYNI.
  static const int azamiUrun = 300;

  static const MusteriFiyatlari bos = MusteriFiyatlari._({});

  factory MusteriFiyatlari.coz(String? json) {
    if (json == null || json.trim().isEmpty) return bos;
    final Object? cozulen;
    try {
      cozulen = jsonDecode(json);
    } catch (_) {
      return bos;
    }
    if (cozulen is! Map) return bos;
    return MusteriFiyatlari._({
      for (final e in cozulen.entries)
        if (e.key is String && e.value is int && (e.value as int) >= 0)
          e.key as String: e.value as int,
    });
  }

  final Map<String, int> _fiyatlar;

  bool get bosMu => _fiyatlar.isEmpty;

  /// Listedeki ürün kimlikleri.
  Iterable<String> get urunIdleri => _fiyatlar.keys;

  bool ozelMi(String? urunId) => urunId != null && _fiyatlar.containsKey(urunId);

  /// Bu müşteriye uygulanacak taban fiyat: varsa özel fiyat, yoksa [katalogKurus].
  int birimFiyat(String urunId, int katalogKurus) => _fiyatlar[urunId] ?? katalogKurus;

  MusteriFiyatlari ile(String urunId, int kurus) =>
      MusteriFiyatlari._({..._fiyatlar, urunId: kurus});

  MusteriFiyatlari haric(String urunId) =>
      MusteriFiyatlari._({..._fiyatlar}..remove(urunId));

  /// Yerel kolona yazılacak metin; boş liste null'dır.
  String? yaz() => bosMu ? null : jsonEncode(_fiyatlar);

  /// Senkron yüküne konacak nesne; boş liste null'dır (null = fiyatı yok, sunucu kolonu temizler).
  Map<String, int>? toJson() => bosMu ? null : Map.of(_fiyatlar);
}
