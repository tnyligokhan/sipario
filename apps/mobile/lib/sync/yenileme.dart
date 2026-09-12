// AŞAĞI ÇEKEREK YENİLE — uygulama genelinde tek davranış (kullanıcı isteği 2026-07-29).
//
// NEDEN GEREKLİ: veri yerelden okunuyor (Drift akışları) ve senkron 2 dakikada bir kendiliğinden
// koşuyor. Yani ekran "eski" görünse bile aslında yakında tazelenecek — ama bayi bunu BİLMİYOR
// ve bekleyecek bir gerekçesi yok. Aşağı çekmek, telefonda "şimdi bak" demenin evrensel jestidir;
// olmadığında kullanıcı uygulamayı kapatıp açıyor (saha davranışı: "kapatıp açınca senkronize
// ediyor" şikâyeti tam olarak bu boşluktan doğmuştu).
//
// NEDEN GEÇİLEN GERİ ÇAĞRIM DEĞİL DE MODÜL DÜZEYİNDE BAĞLAMA: yenileme beş ayrı ekranda
// (ana · sipariş · müşteri · gün sonu · borçlular) gerekiyor ve hepsi kabuk tarafından farklı
// yollardan kuruluyor — bazıları sekme, bazıları `Navigator.push`. Callback'i her ekranın
// imzasına eklemek, ekranların yarısını yalnız taşıma amacıyla değiştirmek demekti. Servisin
// kendisi zaten uygulama ömrü boyunca tek örnektir (`main.dart` kurar); `guncellemeServisi`
// tekilinin aynı deseni.
//
// SESSİZ BAŞARISIZLIK YOK ama GÜRÜLTÜ de yok: yenileme başarısızsa çağıran ekran kendi
// bandını/çipini zaten gösteriyor (çevrimdışı bandı, senkron çipi). Bu modül hata YUTMAZ,
// yalnız sonucu döndürür.

import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../guncelleme/guncelleme_servisi.dart';
import 'sync_service.dart';

SyncService? _servis;

/// Kabuk açılışta bağlar. Bağlanmadan çağrılırsa yenileme sessizce "yapılamadı" döner —
/// test ve önizleme ağaçlarında senkron servisi yoktur ve orada çökmek doğru davranış değildir.
void yenilemeyiBagla(SyncService servis) => _servis = servis;

/// Testlerin bıraktığı bağlamayı temizler (bir sonraki test başkasının servisini kullanmasın).
void yenilemeyiCoz() => _servis = null;

/// Bir senkron turu koşar ve biter. `syncNow()` eşzamanlı çağrıları BİRLEŞTİRİR (`_tur ??=`),
/// yani zamanlayıcının turu sürerken aşağı çekilirse ikinci bir tur açılmaz — kullanıcı yine de
/// gerçek turun bitmesini bekler ve göstergeyi doğru anda bırakır.
///
/// Dönen değer: senkron başarılı mı. Çağıran ekran bunu kullanmak ZORUNDA değil (durum çipi
/// ve çevrimdışı bandı zaten canlı akıştan besleniyor).
Future<bool> yenile() async {
  final s = _servis;
  if (s == null) return false;
  final sonuc = await s.syncNow();
  return sonuc.ok;
}

/// Ana ekranın yenilemesi: senkron + GÜNCELLEME kontrolü (kullanıcı isteği).
///
/// `zorla: true` 15 dakikalık aralığı atlar — kullanıcı açıkça "şimdi bak" dediyse onu
/// beklemeye zorlamak, jestin anlamını boşa çıkarırdı. Kontrol sonucunu ekran GÖSTERİR:
/// güncelleme varsa bant düşer, yoksa senkron çipinin yanında "Sürüm güncel" yazar.
Future<bool> anaEkranYenile() async {
  final ok = await yenile();
  await guncellemeServisi.sessizKontrol(zorla: true);
  return ok;
}

/// VERİYİ SUNUCUDAN BAŞTAN İNDİR — sıkışmış bir cihazın TEK kurtarma yolu (2026-09-12).
///
/// NEDEN GEREKLİ: senkron imleci ilerlediyse ve satırlar bir şekilde uygulanmadıysa, o satırlar
/// BİR DAHA GELMEZ — sunucu yalnız imleçten SONRASINI gönderir. Çıkış+giriş de çözmez, çünkü
/// `logout` imlece bilerek dokunmaz (offline-first). Sahada yaşandı: panelde 9.047 müşteri ve
/// 6 ürün, telefonda bir avuç; kullanıcının yapabileceği HİÇBİR ŞEY yoktu.
///
/// YALNIZ İMLECİ SIFIRLAR, YEREL VERİYİ SİLMEZ. Silmek, henüz gönderilmemiş giden-kutusu
/// kayıtlarını (kırmızı çizgi #3: hiçbir kayıt kaybolmaz) ve cihaz-yerel alanları (ürün görseli
/// gibi) yok ederdi. Sunucudan gelen satırlar `insertOnConflictUpdate` ile ÜSTÜNE yazılır.
///
/// TEK GERÇEKLEME BURADADIR; `SyncEngine.bastanIndir()` buna devreder. Ayarlar ekranının senkron
/// motoruna erişimi yok (yalnız `db` var) — kuralı iki yere kopyalamak yerine motor buraya bakar.
Future<void> senkronBastanIndir(AppDatabase db) async {
  await (db.update(db.syncMeta)..where((t) => t.id.equals(1))).write(
    const SyncMetaCompanion(lastPulledSeq: Value(0), snapshotDone: Value(false)),
  );
}
