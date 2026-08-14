// PUSH'UN UYGULAMAYA BAĞLANDIĞI TEK YER.
//
// `PushServisi` bağımlılıklarını KANCA olarak alır (senkron · jeton bildirimi · ayrıntı
// okuma) ve bu yüzden ne veritabanını ne HTTP'yi tanır. O kancaları gerçek nesnelere bağlamak
// bu dosyanın işidir — `main.dart`ta yapılsaydı kök widget üç ayrı katmanı birden tanımak
// zorunda kalırdı (bildirim kurallarının bağlanması için orada zaten ödenmiş bir bedel var,
// ikincisini eklemiyoruz).

import 'package:drift/drift.dart';

import '../../data/app_database.dart';
import '../../auth/session.dart';
import '../../sync/cihaz_api.dart';
import '../../sync/sync_service.dart';
import '../bildirim_ayarlari.dart';
import '../bildirim_sozlesmesi.dart';
import 'push_servisi.dart';
import 'push_sozlesmesi.dart';

/// Oturum AÇIKKEN kurulan push servisi. Oturum yoksa `null` döner ve hiçbir şey kurulmaz:
/// jetonun yazılacağı cihaz kaydı bir bayiye aittir, oturumsuz cihazda gidecek adresi yoktur.
Future<PushServisi?> pushKur(AppDatabase db, SyncService sync) async {
  final meta = await db.syncState();
  final token = meta.authToken;
  final cihazId = meta.deviceId;

  if (token == null || cihazId == null) {
    await bildirimAyarlari.pushDurumuYaz(PushDurumu.oturumYok);

    return null;
  }

  /*
   * ⚠️ TABAN ADRES `Session.baseUrlOf` İLE ÇÖZÜLÜR, HAM KOLON OKUNMAZ.
   *
   * İlk sürümde burada `meta.apiBaseUrl` doğrudan okunuyordu ve `null` ise push HİÇ
   * KURULMUYORDU. Oysa bu depoda `apiBaseUrl` NULL OLABİLİR ve olması normaldir — kolon
   * yalnız girişte yazılır, varsayılan adresle çalışan bir kurulumda boş kalabilir. Bu yüzden
   * oturum katmanının tamamı (`login`, `logout`, `parolaSifirlamaIste`) o alanı ASLA
   * doğrudan okumaz, hepsi `?? kDefaultApiBaseUrl`e düşer ve bunun için bir yardımcı vardır.
   *
   * Yardımcıyı kullanmamak sessiz bir arıza üretiyordu: push kurulmuyor, jeton alınmıyor,
   * sunucu gönderecek cihaz bulamıyor — ve hiçbir yerde hata görünmüyor.
   */
  final baseUrl = Session.baseUrlOf(meta);

  final api = CihazApi(baseUrl: baseUrl, token: token);

  final servis = PushServisi(
    // Dürtü geldiğinde tam bir senkron turu: bekleyenleri gönder + yenileri çek. Yalnız `pull`
    // demek yetmezdi — kuryenin telefonunda bekleyen teslim kaydı varken sunucudan veri
    // çekmek, aynı turda gidebilecek yazımı bir sonraki tura bırakırdı.
    senkronKos: () => sync.syncNow(),
    // Sonuç KAYDEDİLİR: "jeton alındı ama sunucuya gitmedi" ile "hiç alınmadı" ayrı
    // arızalardır ve ayrı çözümleri vardır (biri ağ, diğeri Play Services).
    jetonBildir: (jeton) async {
      final gitti = await api.jetonBildir(
        cihazId: cihazId,
        platform: 'android',
        jeton: jeton,
      );
      await bildirimAyarlari.pushDurumuYaz(
        gitti ? PushDurumu.hazir : PushDurumu.bildirilemedi,
      );
    },
    ayrintiOku: (mesaj) => pushAyrintisi(db, mesaj),
  );

  await servis.kur();

  return servis;
}

/// Bildirime eklenecek YEREL bilgi — müşteri adı ve teslim adresi.
///
/// KİŞİSEL VERİ BURADAN OKUNUR, YÜKTEN DEĞİL (BRIEF kırmızı çizgi #4): sunucudan gelen
/// dürtüde yalnız bir UUID vardır; ad ve adres telefonun kendi veritabanındadır ve oraya
/// senkronla inmiştir.
///
/// `null` DÖNMESİ NORMALDİR: senkron o siparişi henüz getirmemiş olabilir ya da sipariş
/// müşterisiz girilmiştir (bu üründe mümkün). Bildirim o zaman jenerik metinle çıkar —
/// beklemek, push'un tek değerini (anında olmasını) yok ederdi.
Future<PushEkBilgi?> pushAyrintisi(AppDatabase db, PushMesaji mesaj) async {
  // SİPARİŞ OLMAYAN OLAYLARDA OKUMA YAPILMAZ: kasa devrindeki kimlik bir devir kaydınındır,
  // yeni cihazdaki ise bir cihaz kaydının — ikisi de sipariş tablosunda hiçbir zaman
  // bulunmaz. Bu iki bildirimin metni zaten kendi kendine yeter.
  if (mesaj.kategori == BildirimKategori.kasaDevri ||
      mesaj.kategori == BildirimKategori.yeniCihaz) {
    return null;
  }

  final sorgu = db.select(db.orders).join([
    leftOuterJoin(db.customers, db.customers.id.equalsExp(db.orders.customerId)),
  ])
    ..where(db.orders.id.equals(mesaj.varlikId))
    ..limit(1);

  final satir = await sorgu.getSingleOrNull();
  final musteri = satir?.readTableOrNull(db.customers);
  if (musteri == null) return null;

  final ad = musteri.name.trim();

  /*
   * ADRES: müşterinin BİRİNCİL adresi. Sipariş satırı bir adrese bağlı DEĞİL (şemada
   * `orders.customer_address_id` yok) — bu üründe sipariş müşteriye girilir, teslim onun
   * bilinen adresine yapılır. Birincil yoksa ilk kayıtlı adres alınır: kuryeye "adres yok"
   * demektense bilinen bir adresi göstermek her zaman daha yararlıdır.
   */
  final adresler = await (db.select(db.customerAddresses)
        ..where((t) => t.customerId.equals(musteri.id) & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.isPrimary)])
        ..limit(1))
      .get();

  final adres = adresler.isEmpty ? null : adresler.first.addressText.trim();

  return PushEkBilgi(
    ad: ad.isEmpty ? null : ad,
    adres: (adres == null || adres.isEmpty) ? null : adres,
  );
}
