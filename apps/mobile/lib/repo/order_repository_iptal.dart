// İPTAL ONAY AKIŞININ YAZMA YOLU — kurye TALEP açar, yönetici reddeder.
//
// NEDEN AYRI DOSYA: `order_repository.dart` 520 satıra çıkmıştı (depo sınırı 500). Ayrım
// KONUYA göre: depo dosyası siparişin YAŞAM DÖNGÜSÜNÜ yazar (oluştur · satır · teslim · ata ·
// iptal), burası o döngünün üstüne binen tek bir KARAR AKIŞINI. Onayın ayrı bir metodu
// YOKTUR ve olmamalı — onaylayan taraf `OrderRepository.cancel`ı çağırır, yani iptalin tek
// doğru kaydı korunur.
//
// NEDEN `extension` + `part`: `_statusEvent` PRIVATE ve öyle kalmalı (olay + önbellek + outbox
// tek transaction'da yazılır; dışarıya açılması ikinci bir yazma yolu davetidir). Gizlilik
// Dart'ta KÜTÜPHANE düzeyindedir, yani `part` olduğu sürece extension ona erişebilir ve çağrı
// yerleri hiç değişmez. Aynı desen: `home_shell.dart` → `home_shell_cagri.dart`.
//
// ⚠️ TASARIM KARARI — YENİ KOLON YOK, YENİ OLAY VAR. Talebin durumu `orders` üzerinde bir
// alanda DEĞİL, olay geçmişinde yaşar ve iki taraf da onu aynı kurallarla türetir
// (`iptalTalebiCoz`). Gerekçe: bu depoda sipariş durumu zaten olaylardan türetiliyor
// (`status`, `assigned_user_id`, `delivered_by_user_id`, `sort_index`); talep için ayrı bir
// kolon açmak, aynı sorunun İKİNCİ bir doğruluk kaynağını üretir ve iki cihaz çevrimdışıyken
// ayrışırdı. Ayrıca kolon eklemek şema göçü + sunucu migration'ı + ayrıştırıcı demekti;
// olay eklemek yalnız sözlüğe bir satırdır ve eski istemci onu SESSİZCE yok sayar.
//
// SİPARİŞİN DURUMU DEĞİŞMEZ: talep açıkken sipariş hâlâ `open`tır ve teslim edilebilir.
// Talebi "yarı iptal" bir duruma çevirmek, yönetici cevap verene kadar kuryeyi kilitlerdi —
// oysa müşteri kapıda fikir değiştirip "tamam alıyorum" diyebilir.

part of 'order_repository.dart';

extension SiparisIptalOnayi on OrderRepository {
  /// KURYE İPTAL İSTER — sipariş iptal EDİLMEZ, patronun onayına düşer.
  ///
  /// [gerekce] opsiyoneldir ve yükte taşınır: patron "neden" sorusunu sormadan karar
  /// verebilmeli. Metin KİŞİSEL VERİ TAŞIMAZ diye bir garanti YOKTUR (kurye serbest yazar) —
  /// bu yüzden yalnız senkron yüküne girer, push yüküne ASLA (kırmızı çizgi #4).
  Future<void> iptalTalepEt(String orderId, {String? gerekce}) async {
    final meta = await db.syncState();
    return _statusEvent(orderId, 'cancel_requested', {
      'order_id': orderId,
      // Talebi KİMİN açtığı yükte taşınır: reddi ona bildirmenin tek yolu budur ve olay
      // geçmişi zaten `device_id` dışında bir kimlik taşımıyor (bir cihazı kişiye eşlemek
      // "o gün o telefonu kim kullandı" varsayımıdır — bu depoda bir kez reddedildi).
      'requested_by_user_id': meta.userId,
      if (gerekce != null && gerekce.trim().isNotEmpty) 'reason': gerekce.trim(),
    });
  }

  /// PATRON REDDEDER — talep kapanır, sipariş açık kalır. Onaylamak [cancel]'dır.
  Future<void> iptalTalebiniReddet(String orderId) =>
      _statusEvent(orderId, 'cancel_rejected', {'order_id': orderId});
}
