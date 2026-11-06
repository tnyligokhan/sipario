// MÜŞTERİYE GİDEN BİLGİLENDİRME MESAJLARI (kullanıcı isteği 2026-11-06) —
// `tenant_settings.message_templates_json`.
//
// ══ HANGİ TÜRLER VAR, NEDEN BUNLAR ═════════════════════════════════════════════════════════
// Liste uydurulmadı, sistemin kendi olaylarından türetildi. Siparişin üç durumu vardır (`open`,
// `delivered`, `cancelled`) ve bayinin müşteriye bir şey söylemek zorunda kaldığı anlar bunların
// üzerinde oturur:
//
//   open       → Sipariş Alındı · Yola Çıktı (kurye ataması) · Gecikme Bilgisi (sipariş yaşı pili
//                zaten ölçüyor) · Adreste Ulaşılamadı (kurye kapıda)
//   delivered  → Teslim Edildi · Ödeme Alındı (defterdeki `payment` kaydı)
//   cancelled  → Sipariş İptali
//
// Borç Hatırlatma bu listede DEĞİLDİR: kendi kolonunda yaşar (`reminder_template`) çünkü web
// paneli de onu yazar ve mesajın kendi kurulum kuralları vardır (`borc_hatirlatma.dart`).
//
// Tür duruma bağlıdır: teslim edilmiş siparişte "Yola Çıktı" düğmesi durmaz. Yanlış anda yanlış
// mesajı göndermek, bayiyi kendi müşterisinin gözünde küçük düşürür.
//
// ══ VARSAYILAN METİN KOPYALANMAZ ═══════════════════════════════════════════════════════════
// `sistem` haritası yalnız bayinin DEĞİŞTİRDİĞİ metinleri tutar. Varsayılanı satıra yazmak, metni
// ileride iyileştirdiğimizde ona hiç dokunmamış bayide eski hâli dondururdu (`reminder_template`
// ile aynı gerekçe).
//
// Değişmez değer nesnesi. Sınırlar sunucudaki `MesajSablonlari` ile AYNI.

import 'dart:convert';

import '../theme/components/bicim.dart' show trKucuk;

/// Uygulamanın hazır sunduğu mesaj türü.
class MesajTuru {
  const MesajTuru({
    required this.anahtar,
    required this.baslik,
    required this.aciklama,
    required this.varsayilan,
    required this.durumlar,
  });

  /// Kayıtta ve senkronda kullanılan sabit ad. Başlık değişebilir, bu değişmez.
  final String anahtar;
  final String baslik;

  /// Mesajın nerede göründüğü — bayi düzenlediği metnin ne zaman çıktığını bilmeli.
  final String aciklama;
  final String varsayilan;

  /// Hangi sipariş durumlarında sunulur.
  final Set<String> durumlar;
}

const String _imza = 'Saygılarımızla,\n*isletmeadi*';

/// Sipariş ayrıntısında sunulan hazır türler; ekrandaki sıra bu sıradır.
const List<MesajTuru> kMesajTurleri = [
  MesajTuru(
    anahtar: 'siparis_alindi',
    baslik: 'Sipariş Alındı',
    aciklama: 'Açık siparişte görünür',
    durumlar: {'open'},
    varsayilan: 'Sayın *musteriadi*,\n'
        '\n'
        'Siparişiniz tarafımıza ulaşmış ve işleme alınmıştır.\n'
        '\n'
        'Sipariş numarası: *siparisno*\n'
        'Sipariş içeriği:\n'
        '*siparisozeti*\n'
        'Toplam tutar: *siparistoplami*\n'
        'Teslimat adresi: *teslimatadresi*\n'
        '\n'
        'Bizi tercih ettiğiniz için teşekkür ederiz.\n'
        '\n'
        '$_imza',
  ),
  MesajTuru(
    anahtar: 'yola_cikti',
    baslik: 'Yola Çıktı',
    aciklama: 'Açık siparişte görünür',
    durumlar: {'open'},
    varsayilan: 'Sayın *musteriadi*,\n'
        '\n'
        'Siparişiniz teslimat için yola çıkmıştır.\n'
        '\n'
        'Sipariş numarası: *siparisno*\n'
        'Teslim edecek görevli: *kuryeadi*\n'
        'Teslimat adresi: *teslimatadresi*\n'
        'Toplam tutar: *siparistoplami*\n'
        '\n'
        '$_imza',
  ),
  MesajTuru(
    anahtar: 'gecikme',
    baslik: 'Gecikme Bilgisi',
    aciklama: 'Açık siparişte görünür',
    durumlar: {'open'},
    varsayilan: 'Sayın *musteriadi*,\n'
        '\n'
        'Siparişinizin tesliminde bir gecikme yaşanmaktadır. Bu durum için özür diler, '
        'anlayışınız için teşekkür ederiz.\n'
        '\n'
        'Sipariş numarası: *siparisno*\n'
        '\n'
        'Siparişiniz en kısa sürede adresinize ulaştırılacaktır.\n'
        'Bilgi almak için: *isletmetelefonu*\n'
        '\n'
        '$_imza',
  ),
  MesajTuru(
    anahtar: 'adreste_ulasilamadi',
    baslik: 'Adreste Ulaşılamadı',
    aciklama: 'Açık siparişte görünür',
    durumlar: {'open'},
    varsayilan: 'Sayın *musteriadi*,\n'
        '\n'
        'Siparişinizi teslim etmek üzere adresinize geldik, ancak size ulaşamadık.\n'
        '\n'
        'Sipariş numarası: *siparisno*\n'
        'Teslimat adresi: *teslimatadresi*\n'
        '\n'
        'Teslimatın tamamlanabilmesi için bu mesajı yanıtlamanızı rica ederiz.\n'
        'İletişim: *isletmetelefonu*\n'
        '\n'
        '$_imza',
  ),
  MesajTuru(
    anahtar: 'teslim_edildi',
    baslik: 'Teslim Edildi',
    aciklama: 'Teslim edilmiş siparişte görünür',
    durumlar: {'delivered'},
    varsayilan: 'Sayın *musteriadi*,\n'
        '\n'
        'Siparişiniz teslim edilmiştir.\n'
        '\n'
        'Sipariş numarası: *siparisno*\n'
        'Sipariş içeriği:\n'
        '*siparisozeti*\n'
        'Toplam tutar: *siparistoplami*\n'
        'Ödeme şekli: *odemetipi*\n'
        '\n'
        'Bizi tercih ettiğiniz için teşekkür eder, iyi günler dileriz.\n'
        '\n'
        '$_imza',
  ),
  MesajTuru(
    anahtar: 'odeme_alindi',
    baslik: 'Ödeme Alındı',
    aciklama: 'Teslim edilmiş siparişte görünür',
    durumlar: {'delivered'},
    varsayilan: 'Sayın *musteriadi*,\n'
        '\n'
        'Ödemeniz tarafımıza ulaşmıştır, teşekkür ederiz.\n'
        '\n'
        'Son ödemeniz: *sonodeme*\n'
        'Güncel bakiyeniz: *siparistutar*\n'
        '\n'
        'Hesabınızla ilgili sorularınız için: *isletmetelefonu*\n'
        '\n'
        '$_imza',
  ),
  MesajTuru(
    anahtar: 'siparis_iptal',
    baslik: 'Sipariş İptali',
    aciklama: 'İptal edilmiş siparişte görünür',
    durumlar: {'cancelled'},
    varsayilan: 'Sayın *musteriadi*,\n'
        '\n'
        'Siparişiniz iptal edilmiştir.\n'
        '\n'
        'Sipariş numarası: *siparisno*\n'
        'Toplam tutar: *siparistoplami*\n'
        '\n'
        'Sorularınız için: *isletmetelefonu*\n'
        '\n'
        'Anlayışınız için teşekkür ederiz.\n'
        '\n'
        '$_imza',
  ),
];

/// Bayinin kendi eklediği mesaj.
class OzelMesaj {
  const OzelMesaj({required this.id, required this.baslik, required this.metin});

  final String id;
  final String baslik;
  final String metin;

  Map<String, String> yaz() => {'id': id, 'baslik': baslik, 'metin': metin};
}

/// Sipariş ayrıntısında tek bir düğmenin karşılığı: ne yazar, hangi metni çözer.
class BilgilendirmeSecenegi {
  const BilgilendirmeSecenegi({
    required this.anahtar,
    required this.baslik,
    required this.sablon,
  });

  final String anahtar;
  final String baslik;
  final String sablon;
}

class MesajSablonlari {
  const MesajSablonlari._(this._sistem, this.ozel);

  static const MesajSablonlari bos = MesajSablonlari._({}, []);

  /// Sunucudaki `MesajSablonlari` sınırlarıyla AYNI. Metin sınırı `reminder_template` ile ortak.
  static const int azamiOzel = 20;
  static const int azamiAd = 40;
  static const int azamiMetin = 1000;

  /// Bozuk ya da eksik kayıt boş sayılır: ayar yüzünden sipariş ekranı açılamaz hâle gelmemeli.
  ///
  /// `sistem` alanında `Map` beklenir ama boş PHP dizisi JSON'da `[]` olarak iner, o da boş sayılır.
  factory MesajSablonlari.coz(String? json) {
    if (json == null || json.trim().isEmpty) return bos;
    final Object? cozulen;
    try {
      cozulen = jsonDecode(json);
    } catch (_) {
      return bos;
    }
    if (cozulen is! Map) return bos;

    final hamSistem = cozulen['sistem'];
    final sistem = <String, String>{
      if (hamSistem is Map)
        for (final e in hamSistem.entries)
          if (e.key is String && e.value is String && (e.value as String).trim().isNotEmpty)
            e.key as String: e.value as String,
    };

    final hamOzel = cozulen['ozel'];
    final ozel = <OzelMesaj>[
      if (hamOzel is List)
        for (final e in hamOzel)
          if (e is Map && e['id'] is String && e['baslik'] is String && e['metin'] is String)
            OzelMesaj(
              id: e['id'] as String,
              baslik: e['baslik'] as String,
              metin: e['metin'] as String,
            ),
    ];
    return MesajSablonlari._(sistem, ozel);
  }

  final Map<String, String> _sistem;
  final List<OzelMesaj> ozel;

  bool get yeniEklenebilir => ozel.length < azamiOzel;

  /// Bayinin bu tür için yazdığı metin; varsayılan kullanılıyorsa null.
  String? ozelMetin(MesajTuru tur) => _sistem[tur.anahtar];

  /// Müşteriye gidecek şablon.
  String metin(MesajTuru tur) => _sistem[tur.anahtar] ?? tur.varsayilan;

  /// [durum]daki siparişte sunulacak mesajlar. Bayinin mesajları her durumda görünür: ne zaman
  /// gönderileceğini yazan bilir.
  List<BilgilendirmeSecenegi> siparisIcin(String durum) => [
        for (final t in kMesajTurleri)
          if (t.durumlar.contains(durum))
            BilgilendirmeSecenegi(anahtar: t.anahtar, baslik: t.baslik, sablon: metin(t)),
        for (final o in ozel)
          BilgilendirmeSecenegi(anahtar: o.id, baslik: o.baslik, sablon: o.metin),
      ];

  /// [metin] boşsa ya da varsayılanın aynısıysa kayıt silinir: bayi varsayılana dönmüş demektir.
  MesajSablonlari sistemIle(MesajTuru tur, String? metin) {
    final temiz = (metin ?? '').trim();
    final yeni = {..._sistem}..remove(tur.anahtar);
    if (temiz.isNotEmpty && temiz != tur.varsayilan) yeni[tur.anahtar] = temiz;
    return MesajSablonlari._(yeni, ozel);
  }

  /// Aynı kimlikli mesaj varsa yerinde güncellenir, yoksa sona eklenir.
  MesajSablonlari ozelIle(OzelMesaj mesaj) {
    final var_ = ozel.any((o) => o.id == mesaj.id);
    return MesajSablonlari._(
      _sistem,
      var_ ? [for (final o in ozel) o.id == mesaj.id ? mesaj : o] : [...ozel, mesaj],
    );
  }

  MesajSablonlari ozelHaric(String id) =>
      MesajSablonlari._(_sistem, [for (final o in ozel) if (o.id != id) o]);

  /// Mesaj adı kullanılamıyorsa gerekçe, kullanılabiliyorsa null. [id] düzenlenen mesajdır,
  /// kendi adıyla çakışmış sayılmaz.
  String? adHatasi(String ad, {String? id}) {
    final temiz = ad.trim();
    if (temiz.isEmpty) return 'Mesaj adı yazın';
    if (temiz.length > azamiAd) return 'Mesaj adı en çok $azamiAd karakter olabilir';
    final anahtar = trKucuk(temiz);
    final cakisan = [
      for (final t in kMesajTurleri) trKucuk(t.baslik),
      for (final o in ozel)
        if (o.id != id) trKucuk(o.baslik),
    ].contains(anahtar);
    return cakisan ? 'Bu adda bir mesaj zaten var' : null;
  }

  /// Hiç değişiklik yoksa null yazılır: bayi hiçbir şeye dokunmamıştır.
  String? yaz() {
    if (_sistem.isEmpty && ozel.isEmpty) return null;
    return jsonEncode({
      if (_sistem.isNotEmpty) 'sistem': _sistem,
      if (ozel.isNotEmpty) 'ozel': [for (final o in ozel) o.yaz()],
    });
  }
}
