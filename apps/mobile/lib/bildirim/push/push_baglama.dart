// PUSH'UN UYGULAMAYA BAĞLANDIĞI TEK YER.
//
// `PushServisi` bağımlılıklarını KANCA olarak alır (senkron · jeton bildirimi · ayrıntı
// okuma) ve bu yüzden ne veritabanını ne HTTP'yi tanır. O kancaları gerçek nesnelere bağlamak
// bu dosyanın işidir — `main.dart`ta yapılsaydı kök widget üç ayrı katmanı birden tanımak
// zorunda kalırdı (bildirim kurallarının bağlanması için orada zaten ödenmiş bir bedel var,
// ikincisini eklemiyoruz).

import 'package:drift/drift.dart';

import '../../data/app_database.dart';
import '../../sync/cihaz_api.dart';
import '../../sync/sync_service.dart';
import '../bildirim_sozlesmesi.dart';
import 'push_servisi.dart';
import 'push_sozlesmesi.dart';

/// Oturum AÇIKKEN kurulan push servisi. Oturum yoksa `null` döner ve hiçbir şey kurulmaz:
/// jetonun yazılacağı cihaz kaydı bir bayiye aittir, oturumsuz cihazda gidecek adresi yoktur.
Future<PushServisi?> pushKur(AppDatabase db, SyncService sync) async {
  final meta = await db.syncState();
  final token = meta.authToken;
  final cihazId = meta.deviceId;
  final baseUrl = meta.apiBaseUrl;

  if (token == null || cihazId == null || baseUrl == null) return null;

  final api = CihazApi(baseUrl: baseUrl, token: token);

  final servis = PushServisi(
    // Dürtü geldiğinde tam bir senkron turu: bekleyenleri gönder + yenileri çek. Yalnız `pull`
    // demek yetmezdi — kuryenin telefonunda bekleyen teslim kaydı varken sunucudan veri
    // çekmek, aynı turda gidebilecek yazımı bir sonraki tura bırakırdı.
    senkronKos: () => sync.syncNow(),
    jetonBildir: (jeton) => api.jetonBildir(
      cihazId: cihazId,
      platform: 'android',
      jeton: jeton,
    ),
    ayrintiOku: (mesaj) => pushAyrintisi(db, mesaj),
  );

  await servis.kur();

  return servis;
}

/// Bildirim gövdesine eklenecek YEREL ayrıntı — müşteri adı.
///
/// KİŞİSEL VERİ BURADAN OKUNUR, YÜKTEN DEĞİL (BRIEF kırmızı çizgi #4): sunucudan gelen
/// dürtüde yalnız bir UUID vardır; ad telefonun kendi veritabanındadır ve oraya senkronla
/// inmiştir.
///
/// `null` DÖNMESİ NORMALDİR: senkron o siparişi henüz getirmemiş olabilir ya da sipariş
/// müşterisiz girilmiştir (bu üründe mümkün). Bildirim o zaman jenerik metinle çıkar —
/// beklemek, push'un tek değerini (anında olmasını) yok ederdi.
Future<String?> pushAyrintisi(AppDatabase db, PushMesaji mesaj) async {
  // Kasa devrinde ayrıntı OKUNMAZ: dürtüdeki kimlik bir kasa devri kaydınındır, sipariş
  // değildir — sipariş tablosunda aranırsa hiçbir zaman bulunmaz. "Kurye kasayı devretti"
  // cümlesi zaten yeterli.
  if (mesaj.kategori == BildirimKategori.kasaDevri) return null;

  final sorgu = db.select(db.orders).join([
    leftOuterJoin(db.customers, db.customers.id.equalsExp(db.orders.customerId)),
  ])
    ..where(db.orders.id.equals(mesaj.varlikId))
    ..limit(1);

  final satir = await sorgu.getSingleOrNull();
  final ad = satir?.readTableOrNull(db.customers)?.name.trim();

  return (ad == null || ad.isEmpty) ? null : ad;
}
