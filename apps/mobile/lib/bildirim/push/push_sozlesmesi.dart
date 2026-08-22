// PUSH SÖZLEŞMESİ — sunucudan gelen dürtünün SAF çözümü.
//
// Bu dosya Firebase'i, ağı, veritabanını TANIMAZ. Gelen `data` haritasını okur ve bir
// [BildirimTaslagi] üretir; gerisi (izin, sessiz saatler, günlük bütçe, çizim) mevcut
// bildirim altyapısınındır — push YENİ BİR BİLDİRİM YOLU AÇMAZ, var olanı besler.
//
// ⚠️ SUNUCUYLA PAYLAŞILAN SÖZLEŞME: alan adları ve olay değerleri `app/Bildirim/PushOlayi.php`
// ile birebir aynıdır. Tek taraflı değiştirmek, sahadaki eski istemcinin dürtüyü tanımaması
// demektir (telefonlar offline-first çalışır ve günlerce eski sürümde kalır).
//
// YÜKTE KİŞİSEL VERİ YOKTUR (BRIEF kırmızı çizgi #4): Google'ın sunucularından yalnız olay
// türü ve bir UUID geçer. Bildirimin okunabilir metni BURADA, telefonun kendi verisinden
// üretilir — [pushTaslagi] müşteri adını PARAMETRE olarak alır, yükten değil.

import '../bildirim_sozlesmesi.dart';

/// Dürtüye YEREL veriden eklenen bilgi. Hepsi telefonun kendi veritabanından okunur —
/// FCM yükünde bu alanların hiçbiri taşınmaz (BRIEF kırmızı çizgi #4).
///
/// Alanların ikisi de `null` olabilir ve bu NORMALDİR: senkron o kaydı henüz getirmemiş
/// olabilir, sipariş müşterisiz girilmiş olabilir, müşterinin adresi kayıtlı olmayabilir.
/// Bildirim o zaman jenerik metinle çıkar — beklemek, push'un tek değerini (anında olmasını)
/// yok ederdi.
class PushEkBilgi {
  const PushEkBilgi({this.ad, this.adres});

  /// Müşteri adı — GÖVDEYE girer.
  final String? ad;

  /// Teslim adresi — yalnız GENİŞLETİLMİŞ metne girer. Gövdeye koymak, daraltılmış bildirimi
  /// okunmaz uzunlukta yapar ve Android onu zaten keser.
  final String? adres;
}

/// Sunucudan gelen dürtünün çözülmüş hâli.
class PushMesaji {
  const PushMesaji({required this.kategori, required this.varlikId, this.olay});

  /// Hangi olay — doğrudan bir bildirim kategorisidir (sunucu `kategori` alanında yollar).
  final BildirimKategori kategori;

  /// İlgili kaydın kimliği (sipariş / kasa devri). Bildirim METNİNE girmez; yerel veriden
  /// ayrıntı okumak ve aynı olayın ikinci dürtüsünü ÜZERİNE YAZMAK için kullanılır.
  final String varlikId;

  /// SUNUCUNUN OLAY ADI (`app/Bildirim/PushOlayi.php` → `value`) — yükte `olay` alanı.
  ///
  /// 2026-08-22'DE OKUNMAYA BAŞLANDI ve alan yükte İLK GÜNDEN BERİ VARDI. Gerekmesinin sebebi
  /// bir kategorinin İKİ YÖNÜ olabilmesi: `siparis_iptal_onayi` hem "kurye iptal istedi"
  /// (yöneticiye) hem "talebin reddedildi" (kuryeye) dürtüsünü taşır ve metinleri terstir.
  /// Kategoriyi ikiye bölmek ayarlar listesini uzatırdı; `olay`ı okumak bedavaydı.
  ///
  /// `null` OLABİLİR: eski sunucu ya da tanınmayan bir değer. O zaman kategori genel metnine
  /// düşülür — bilinmeyen bir yön, bildirimi hiç göstermemek için yeterli sebep değildir.
  final String? olay;

  @override
  bool operator ==(Object other) =>
      other is PushMesaji &&
      other.kategori == kategori &&
      other.varlikId == varlikId &&
      other.olay == olay;

  @override
  int get hashCode => Object.hash(kategori, varlikId, olay);

  @override
  String toString() => 'PushMesaji(${kategori.wire}, $varlikId, ${olay ?? '-'})';
}

/// Sunucunun `olay` değerleri — SÖZLEŞME (`app/Bildirim/PushOlayi.php` ile birebir).
abstract final class PushOlayAdi {
  static const String iptalTalebi = 'siparis_iptal_talebi';
  static const String iptalReddedildi = 'siparis_iptal_reddedildi';
}

/// FCM `data` haritasını çözer. TANINMAYAN/BOZUK YÜK `null` DÖNER, İSTİSNA ATMAZ.
///
/// Gerekçe: bu kod arka planda, kullanıcının göremeyeceği bir bağlamda koşar. Sunucu bir gün
/// yeni bir olay türü göndermeye başlarsa (ve sahadaki telefon eski sürümdeyse) çökmek değil,
/// sessizce atlamak doğrudur — dürtüyü anlamayan istemci veriyi yine de senkronla alır.
PushMesaji? pushMesajiCoz(Map<String, dynamic>? veri) {
  if (veri == null) return null;

  final kategori = BildirimKategori.wiredan('${veri['kategori'] ?? ''}');
  final id = '${veri['id'] ?? ''}'.trim();

  if (kategori == null || id.isEmpty) return null;

  // SUNUCUDAN GELEBİLECEK KATEGORİLER SINIRLIDIR. Yerel kategoriler (gün sonu özeti, borç
  // eşiği …) telefonun kendi kurallarınındır; sunucudan öyle bir dürtü gelmesi ya bir hatadır
  // ya da kötü niyetli bir yüktür. İkisinde de doğru davranış yok saymaktır.
  if (!pushIleGelebilir(kategori)) return null;

  final olay = '${veri['olay'] ?? ''}'.trim();

  return PushMesaji(
    kategori: kategori,
    varlikId: id,
    olay: olay.isEmpty ? null : olay,
  );
}

/// Sunucudan itilebilecek kategoriler. Beyaz liste — kara liste değil: yeni bir yerel kategori
/// eklendiğinde onu buraya eklemeyi unutmak GÜVENLİ tarafa düşer (dürtü yok sayılır).
bool pushIleGelebilir(BildirimKategori k) => switch (k) {
      BildirimKategori.siparisAtandi ||
      BildirimKategori.siparisIptal ||
      BildirimKategori.siparisTeslim ||
      BildirimKategori.kasaDevri ||
      BildirimKategori.siparisIptalOnayi ||
      BildirimKategori.yeniCihaz =>
        true,
      _ => false,
    };

/// Çözülmüş dürtüden gösterilecek taslağı üretir.
///
/// [ayrinti] telefonun KENDİ veritabanından okunan tamamlayıcı bilgidir (müşteri adı gibi) ve
/// isteğe bağlıdır: senkron henüz o kaydı getirmemiş olabilir. Yokluğunda bildirim yine
/// anlamlıdır — "Size bir sipariş atandı" eksik ama doğrudur; beklemek ise dürtüyü
/// geciktirirdi ve push'un tek değeri ANINDA olmasıdır.
///
/// BAŞLIK NÖTR, AYRINTI GÖVDEDE: bildirim rafında bir bakışta okunan şey başlıktır ve telefon
/// birine uzatıldığında yanındaki onu görür (`BildirimTaslagi.govde` gerekçesinin aynısı).
/// [detaySatiri] GENİŞLETİLMİŞ bildirimde gövdenin altına eklenen ikinci satırdır (teslim
/// adresi gibi). Yalnız genişleyen kategorilerde anlamlıdır ve o da yerelden okunur.
BildirimTaslagi pushTaslagi(PushMesaji m, {String? ayrinti, String? detaySatiri}) {
  final ek = (ayrinti ?? '').trim();
  final ikinci = (detaySatiri ?? '').trim();

  final (baslik, govde, yol) = switch (m.kategori) {
    BildirimKategori.siparisAtandi => (
        'Yeni sipariş',
        ek.isEmpty ? 'Size bir sipariş atandı' : '$ek size atandı',
        'siparisler',
      ),
    // İPTALDE BAŞLIK DA AÇIK OLMALI. Diğerlerinde başlık nötr tutuluyor (kilit ekranı kuralı)
    // ama burada nötr bir başlık ("Sipario") kuryeye hiçbir şey söylemez ve o yola çıkar;
    // "iptal" sözcüğü müşteri adı taşımaz, yani kural da çiğnenmiş olmaz.
    BildirimKategori.siparisIptal => (
        'Sipariş iptal edildi',
        ek.isEmpty ? 'Size atanan sipariş iptal edildi' : '$ek iptal edildi',
        'siparisler',
      ),
    BildirimKategori.siparisTeslim => (
        'Teslim edildi',
        ek.isEmpty ? 'Bir sipariş teslim edildi' : '$ek teslim edildi',
        'siparisler',
      ),
    BildirimKategori.kasaDevri => (
        'Kasa devri',
        ek.isEmpty ? 'Kurye kasayı devretti' : '$ek kasayı devretti',
        'gunsonu',
      ),
    BildirimKategori.yeniCihaz => (
        'Yeni cihaz girişi',
        'Hesabınız yeni bir telefonda açıldı',
        'cihazlar',
      ),
    /*
     * İPTAL ONAYI — TEK KATEGORİ, İKİ YÖN. Ayrımı yükteki `olay` yapar (bkz. [PushMesaji.olay]).
     *
     * YOL KİMLİK TAŞIR (`siparis/<id>`): karar düğmesinin uygulayacağı kayıt odur ve talebi
     * gören patron listeye değil doğrudan o siparişe gitmeli — bekleyen talep bir liste
     * içinde aranacak şey değildir.
     *
     * `olay` TANINMAZSA TALEP VARSAYILIR: eski sunucu bu kategoriyi zaten hiç göndermez, yani
     * buraya yalnız yeni sunucudan gelinir; bilinmeyen bir değerde "bir iş bekliyor" demek,
     * "bir şey oldu" demekten yararlıdır.
     */
    BildirimKategori.siparisIptalOnayi =>
      m.olay == PushOlayAdi.iptalReddedildi
          ? (
              'İptal talebiniz reddedildi',
              ek.isEmpty ? 'Sipariş açık kalmaya devam ediyor' : '$ek siparişi açık kalıyor',
              'siparis/${m.varlikId}',
            )
          : (
              'İptal onayı bekliyor',
              ek.isEmpty ? 'Kurye bir siparişi iptal etmek istiyor' : '$ek siparişi için iptal istendi',
              'siparis/${m.varlikId}',
            ),
    // Beyaz liste dışı kategori buraya ULAŞAMAZ (`pushMesajiCoz` eler); yine de dilin
    // tümlük şartı için nötr bir karşılık — çökmek yerine anlamsız ama zararsız bildirim.
    _ => ('Sipario', 'Yeni bir işlem var', 'siparisler'),
  };

  return BildirimTaslagi(
    kategori: m.kategori,
    baslik: baslik,
    govde: govde,
    detay: _detay(m.kategori, govde, ikinci),
    // AYNI OLAYIN İKİNCİ DÜRTÜSÜ ÜZERİNE YAZAR: sunucu aynı siparişi iki kez atarsa (ya da
    // kurye ağ yüzünden aynı olayı yeniden gönderirse) bayi iki satır değil bir satır görür
    // ve günlük bütçeden ikinci kez düşülmez.
    kimlik: bildirimKimligi(m.kategori, m.varlikId),
    yol: yol,
    // KARAR DÜĞMELERİ YALNIZ TALEPTE: ret bir bilgidir, kuryenin verecek kararı yoktur.
    kararIster: m.kategori == BildirimKategori.siparisIptalOnayi &&
        m.olay != PushOlayAdi.iptalReddedildi,
  );
}

/// Genişletilmiş metin. `null` = bu bildirim genişlemez.
///
/// ÜÇ KATEGORİ GENİŞLER ve üçünde de sebep aynı: bayinin/kuryenin BİR KARAR vermesi gerekiyor.
/// "Teslim edildi" ve "kasa devri" olan biteni haber verir — orada açılacak bir şey yoktur ve
/// genişletilebilir göstermek boş bir hareket yaptırmaktır.
String? _detay(BildirimKategori k, String govde, String ikinciSatir) => switch (k) {
      // Kurye nereye gideceğini bildirimi açmadan görebilsin.
      BildirimKategori.siparisAtandi =>
        ikinciSatir.isEmpty ? null : '$govde\n$ikinciSatir',
      // İptalde adres yine değerli: kurye "hangi teslimat iptal oldu"yu tanımalı.
      BildirimKategori.siparisIptal => ikinciSatir.isEmpty
          ? 'Bu siparişe gitmeyin, sipariş listeden kaldırıldı.'
          : '$govde\n$ikinciSatir\n\nBu siparişe gitmeyin, sipariş listeden kaldırıldı.',
      // Güvenlik bildiriminde ne yapılacağı SÖYLENİR; uyarıp yalnız bırakmak işe yaramaz.
      BildirimKategori.yeniCihaz =>
        'Hesabınız yeni bir telefonda açıldı.\n\nBu siz değilseniz parolanızı değiştirin. '
            'Bağlı telefonları Hesap → Cihazlar sayfasından görebilirsiniz.',
      _ => null,
    };
