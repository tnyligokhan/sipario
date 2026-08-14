// PUSH SERVİSİ — Firebase Cloud Messaging'in tek dokunma noktası.
//
// SORUMLULUK SINIRI: bu dosya jetonu alır, dinleyicileri kurar ve gelen dürtüyü çözer.
// "Ne yazacak" kararı SAF katmandadır (`push_sozlesmesi.dart`), "nasıl çizilecek" kararı
// mevcut bildirim altyapısındadır (`bildirim_servisi.dart`). Push YENİ BİR BİLDİRİM YOLU
// AÇMAZ: sessiz saatler, günlük bütçe ve kategori kısma kuralları aynen geçerlidir.
//
// ── DÜRTÜ VERİ TAŞIMAZ, "GEL BAK" DER ────────────────────────────────────────────────────
// Gelen mesajda müşteri adı, adres, tutar YOKTUR (BRIEF kırmızı çizgi #4 — kişisel veri
// Google'ın sunucularından geçmez). Sıra şudur: dürtü gelir → SENKRON koşar → veri yerel
// veritabanına iner → bildirim YEREL veriden çizilir. Bunun ikinci bir faydası var ve
// mimari olarak asıl önemli olan o: dürtü kaybolsa bile (telefon kapalıydı, Play Services
// takıldı, cihazda Play Services yok) veri mevcut periyodik senkronla akmaya devam eder.
// Push bu üründe HIZLANDIRICIDIR, taşıyıcı değil — "push gelmezse ürün çalışmaz" durumu
// tasarım gereği doğamaz.
//
// ── BİLDİRİM KAPALI ≠ VERİ GELMESİN ──────────────────────────────────────────────────────
// Bayi bir kategoriyi kısmışsa BİLDİRİM çizilmez ama SENKRON YİNE KOŞAR. İkisini birbirine
// bağlamak, "bu bildirimi istemiyorum" diyen bayinin siparişlerinin de geç gelmesi demekti.
//
// ── ARKA PLAN SINIRI (bilerek, yazılı) ───────────────────────────────────────────────────
// Uygulama arka plandayken/kapalıyken dürtü AYRI BİR ISOLATE'te karşılanır. Orada yalnız
// bildirim çizilir; senkron KOŞULMAZ ve müşteri adı OKUNMAZ. Sebep: ikinci bir isolate'ten
// aynı SQLite dosyasına yazmak, bu ürünün en hassas yerinde (para ve defter kayıtları) bir
// yarış riski açar. Bildirim jenerik olur ("Size bir sipariş atandı"), uygulama açılınca
// senkron zaten koşar ve ayrıntı orada görünür. Kaybedilen: arka plan bildiriminde müşteri
// adı. Kazanılan: defterin bütünlüğü. Takas bilinçlidir.

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../bildirim_servisi.dart';
import '../bildirim_sozlesmesi.dart';
import 'push_sozlesmesi.dart';

/// Uygulama ARKA PLANDAYKEN/KAPALIYKEN gelen dürtü. Ayrı isolate'te koşar.
///
/// `@pragma('vm:entry-point')` ZORUNLU: release derlemesinde ağaç sarsma (tree shaking) bu
/// fonksiyonu "çağıranı yok" diye siler ve arka plan bildirimleri YALNIZ RELEASE'te kaybolur —
/// debug'da çalıştığı için fark edilmesi en zor arıza sınıfı.
@pragma('vm:entry-point')
Future<void> pushArkaPlanIsleyici(RemoteMessage mesaj) async {
  try {
    await Firebase.initializeApp();
    final coz = pushMesajiCoz(mesaj.data);
    if (coz == null) return;
    // Bu isolate'in KENDİ servisi: `bildirimServisi` global'i burada kurulu değildir.
    // Tercih dosyası (sessiz saatler, kısılan kategoriler) diskten okunur — iki isolate aynı
    // dosyayı okur, yalnız sayaç yazımında kısa bir yarış olabilir; sonucu en fazla bir
    // bildirimin bütçeden iki kez düşmesidir, veri değil.
    final servis = YerelBildirimServisi();
    await servis.kur();
    await servis.goster(pushTaslagi(coz));
  } on Object catch (e) {
    // Arka plan isolate'inde atılan istisna sessizce sürecin ölümüne gider; yutup loglamak
    // hem tanıyı korur hem de bir sonraki dürtünün gelmesini engellemez.
    debugPrint('Arka plan push işlenemedi: $e');
  }
}

/// Gelen dürtüde senkronu koşturacak kanca. `true` dönerse veri güncellendi sayılır.
typedef PushSenkronKancasi = Future<void> Function();

/// Dürtüde adı geçen kaydın YEREL veriden okunan tamamlayıcı bilgisi (müşteri adı, kurye adı).
/// `null` dönmesi normaldir — senkron o kaydı henüz getirmemiş olabilir.
typedef PushAyrintiKancasi = Future<String?> Function(PushMesaji mesaj);

/// Push jetonunu sunucuya bildiren kanca.
typedef PushJetonKancasi = Future<void> Function(String jeton);

/// Ön plan dinleyicilerini ve jeton yaşam döngüsünü yöneten servis.
///
/// Bağımlılıklar KANCA olarak alınır (senkron, ayrıntı okuma, jeton bildirimi): böylece bu
/// sınıf ne `SyncEngine`i ne veritabanını ne de HTTP istemcisini tanır ve testte Firebase'e
/// hiç dokunmadan sınanabilir.
class PushServisi {
  PushServisi({
    required this.senkronKos,
    required this.jetonBildir,
    this.ayrintiOku,
    BildirimServisi? bildirim,
    FirebaseMessaging? mesajlasma,
  })  : _bildirim = bildirim,
        _mesajlasma = mesajlasma;

  final PushSenkronKancasi senkronKos;
  final PushJetonKancasi jetonBildir;
  final PushAyrintiKancasi? ayrintiOku;

  final BildirimServisi? _bildirim;
  final FirebaseMessaging? _mesajlasma;

  BildirimServisi get _b => _bildirim ?? bildirimServisi;

  StreamSubscription<RemoteMessage>? _mesajAboneligi;
  StreamSubscription<String>? _jetonAboneligi;

  /// Açılışta bir kez (oturum AÇILDIKTAN sonra) çağrılır.
  ///
  /// OTURUMDAN SONRA olması şart: jeton sunucudaki cihaz kaydına yazılır ve o kayıt bir
  /// bayiye aittir. Girişten önce alınan jetonun gidecek bir adresi yoktur.
  ///
  /// HATA YUTAR: Firebase kurulamazsa (Play Services yok — Huawei; ya da yapılandırma eksik)
  /// uygulama normal çalışmaya devam eder ve veri mevcut senkronla akar.
  Future<void> kur() async {
    try {
      await Firebase.initializeApp();
      final fm = _mesajlasma ?? FirebaseMessaging.instance;

      FirebaseMessaging.onBackgroundMessage(pushArkaPlanIsleyici);

      /*
       * İZİN İSTENMİYOR, DURUM OKUNUYOR. Bildirim izni bu üründe bayi ayarlardan
       * bildirimleri açtığında istenir (`YerelBildirimServisi.kur` yorumundaki karar:
       * "açılışta izin diyaloğu göstermek esnafı kaçırır"). Push'un kendi izin diyaloğunu
       * açması o kararı arkadan dolanmak olurdu.
       *
       * İZİN OLMASA DA JETON ALINIR ve dinleyiciler kurulur: dürtünün SENKRON tetikleme
       * işlevi bildirimden bağımsızdır ve izinsiz de değerlidir.
       */
      final jeton = await fm.getToken();
      if (jeton != null && jeton.isNotEmpty) await jetonBildir(jeton);

      // JETON YENİLENİR ve bu akış olmadan push bir gün sessizce ölür: veri temizleme, cihaz
      // geri yükleme ya da Google'ın kendi döndürmesi jetonu değiştirir.
      _jetonAboneligi = fm.onTokenRefresh.listen((yeni) {
        if (yeni.isNotEmpty) unawaited(jetonBildir(yeni));
      });

      _mesajAboneligi = FirebaseMessaging.onMessage.listen(
        (m) => unawaited(onPlandaMesaj(m.data)),
      );
    } on Object catch (e) {
      debugPrint('Push kurulamadı (Play Services/yapılandırma?): $e');
    }
  }

  /// Uygulama ÖN PLANDAYKEN gelen dürtü. Test bu metodu doğrudan çağırır — Firebase gerekmez.
  ///
  /// SIRA ÖNEMLİ: önce senkron, sonra bildirim. Tersi olsaydı bayi bildirime dokunduğunda
  /// henüz inmemiş bir siparişi arardı; "bildirim geldi ama ekranda yok" güveni en hızlı
  /// bitiren şeydir.
  Future<void> onPlandaMesaj(Map<String, dynamic> veri) async {
    final coz = pushMesajiCoz(veri);
    if (coz == null) return;

    // SENKRON KATEGORİ TERCİHİNDEN ÖNCE VE ONDAN BAĞIMSIZ: bayi bildirimi kısmış olabilir,
    // ama verinin gelmesini istememesi diye bir şey yok.
    try {
      await senkronKos();
    } on Object catch (e) {
      // Senkron patlarsa bildirim yine gösterilir — dürtünün haber verdiği olay GERÇEKTİR;
      // yalnız ayrıntısı eksik kalır.
      debugPrint('Push sonrası senkron koşamadı: $e');
    }

    if (!await _b.kategoriAcikMi(coz.kategori)) return;

    String? ayrinti;
    try {
      ayrinti = await ayrintiOku?.call(coz);
    } on Object catch (e) {
      debugPrint('Push ayrıntısı okunamadı: $e');
    }

    await _b.goster(pushTaslagi(coz, ayrinti: ayrinti));
  }

  /// Oturum kapanınca dinleyiciler bırakılır.
  Future<void> kapat() async {
    await _mesajAboneligi?.cancel();
    await _jetonAboneligi?.cancel();
    _mesajAboneligi = null;
    _jetonAboneligi = null;
  }
}
