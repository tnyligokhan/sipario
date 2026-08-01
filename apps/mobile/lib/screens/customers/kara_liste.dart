// Kara liste kuralı ve METİNLERİ — tek doğruluk kaynağı.
//
// Kural üç ayrı ekranda uygulanıyor (müşteri detayındaki "Sipariş" kısayolu, sipariş formunda
// müşteri seçimi, çağrı kartından gelen hazır müşteri). Üç kopya zamanla ayrışır: biri damgayı
// kontrol etmeyi unutur ve engel SESSİZCE delinir. Bu yüzden hem yüklem hem cümle burada durur.
//
// Ekran metni SÖZLEŞMEDİR (testler bu sabitlere bağlanır, dizgeye değil).

import '../../data/app_database.dart';

/// Müşteri kara listede mi? Damga doluysa evet.
bool karaListede(Customer? musteri) => musteri?.blacklistedAt != null;

/// Sipariş engellenirken gösterilen cümle.
///
/// NEDEN AD GEÇİYOR: bayi listeden yanlış satıra basmış olabilir; hangi müşterinin engellendiğini
/// söylemeyen bir uyarı, kullanıcıyı aynı dokunuşu tekrar etmeye iter.
///
/// NEDEN "ÇIKARABİLİRSİNİZ" DEĞİL: engeli kaldırma yetkisi yalnız yöneticide. Kuryeye "detaydan
/// çıkarın" demek, yapamayacağı bir işe yönlendirmektir; cümle nötr kalır ve nereye bakılacağını
/// söyler.
String karaListeSiparisMesaji(String ad) =>
    '$ad kara listede — yeni sipariş oluşturulamaz.';

/// Liste satırındaki ve detaydaki rozet metni.
const String karaListeRozeti = 'KARA LİSTE';

/// Tehlikeli eylemler bölümünün başlığı ve eylem etiketleri.
const String karaListeyeEkleEtiketi = 'Kara Listeye Ekle';
const String karaListedenCikarEtiketi = 'Kara Listeden Çıkar';
const String musteriyiSilEtiketi = 'Müşteriyi Sil';
