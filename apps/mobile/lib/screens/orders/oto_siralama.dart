// "OTO SIRALA (rota)" — ekrandan bağımsız akış.
//
// NEDEN AYRI DOSYA: eylem 2026-08-01'de sıralama sheet'inden HARİTAYA taşındı. Rota bir SIRA
// üretir ve o sıranın anlamlı olup olmadığı ancak yeryüzünde görülür; düğmenin yeri de orasıdır.
// Mantık ekranın içinde kalsaydı harita ekranı `RouteApi` + konum + repo + kontör yazımını
// yeniden kurmak zorunda kalırdı — yani aynı akışın İKİNCİ bir kopyası doğardı.
//
// BuildContext ALMAZ: eylem yalnız veritabanı ve ağla konuşur, kullanıcıya söylenecek cümleyi
// döndürür. Böylece `mounted` kontrolü çağıranın tek sorumluluğu olur ve akış saf async testle
// (widget kurmadan) sınanabilir.
//
// KVKK: koordinat HİÇBİR yere loglanmaz — yalnız istek gövdesine girer.

import 'package:drift/drift.dart' show Value;

import '../../auth/session.dart';
import '../../data/app_database.dart';
import '../../konum/cihaz_konumu.dart';
import '../../repo/order_repository.dart';
import '../../sync/route_api.dart';
import 'order_queries.dart';

/// Oto sıralamanın sonucu: kullanıcıya söylenecek TEK cümle + başarılı mı.
///
/// [basarili] yalnız sıra gerçekten yazıldıysa true'dur; çağıran ekranını buna bakarak rota
/// görünümüne alır. Arıza dallarında da bir [mesaj] vardır — sessiz başarısızlık yasak.
class OtoSiralamaSonucu {
  const OtoSiralamaSonucu({required this.basarili, required this.mesaj});

  final bool basarili;
  final String mesaj;
}

/// "Oto Sırala" neden kullanılamıyor? null = kullanılabilir.
///
/// Sıra tek yazma yüzeyinden (`sort_set` olayı) geçer → salt-okunur kipte yasak. Hak
/// bilinmiyorsa (ilk senkron gelmedi / oturum yok) tıklamak 409 ile dönerdi. Cümleler TEK
/// yerde durur: düğmenin altındaki gerekçe ile dokunulduğunda çıkan toast aynı olmalı, yoksa
/// kullanıcı iki farklı sebep duyar.
///
/// [durakSayisi] rotaya girecek küme büyüklüğüdür. En DÜŞÜK öncelik: hak yoksa ya da kip
/// salt-okunursa asıl engel odur.
String? otoKilitNedeni({
  required bool yazilabilir,
  required int? hak,
  required int durakSayisi,
}) {
  if (!yazilabilir) return 'Aboneliğiniz sona erdiği için sıra kaydedilemiyor.';
  if (hak == null) return 'Hak bilgisi henüz inmedi. İlk senkrondan sonra kullanabilirsiniz.';
  if (hak <= 0) return 'Oto sıralama hakkı kalmadı.';
  if (durakSayisi < 2) return kOtoKumeYetersiz;
  return null;
}

/// Küme yetersizken yazılan gerekçe. Metin SÖZLEŞMEDİR (testler bu cümleyi arar).
const String kOtoKumeYetersiz = 'Rota için en az iki açık sipariş gerekir.';

/// Sunucudan SIRA ÖNERİSİ ister, dönen sırayı normal yazma yolundan (`sort_set` olayı) kalıcılar.
/// Kontörü SUNUCU düşer; istemci yalnız onun bildirdiği kalanı önbelleğe yazar.
///
/// Bu, uygulamanın TEK çevrimİÇİ zorunlu eylemidir. Başarısızlıkta mevcut sıra AYNEN kalır;
/// yarım uygulanmış bir rota bırakmaz.
///
/// KÜME BURADA OKUNUR, çağırandan alınmaz: rotaya AÇIK siparişlerin TAMAMI girer. Eskiden
/// listedeki görünen küme gönderiliyordu ve kurye süzgeci/sekme seçimi rotayı sessizce
/// daraltabiliyordu. Ayrıca gönderilmeyen bir açık siparişin `sort_index`i eski değerinde
/// kalır ve rota görünümünde yeni sıranın ORTASINA düşerdi — sıralamanın kendisi bozulurdu.
Future<OtoSiralamaSonucu> otoSiralaKos(AppDatabase db) async {
  final liste = await watchOrders(db, OrderFilter.acik).first;
  // EMNİYET AĞI: düğme küme yetersizken zaten pasif çizilir ([otoKilitNedeni]), ama ekran
  // açıkken senkron listeyi değiştirmiş olabilir. Cümle düğmenin altındakiyle AYNIDIR.
  if (liste.length < 2) {
    return const OtoSiralamaSonucu(basarili: false, mesaj: kOtoKumeYetersiz);
  }

  final meta = await db.syncState();
  final token = meta.authToken;
  if (token == null) {
    return const OtoSiralamaSonucu(
        basarili: false, mesaj: 'Oto sıralama için oturum gerekir');
  }

  // ROTA NEREDEN BAŞLAR: kuryenin BULUNDUĞU nokta. Konum alınamazsa (izin yok, GPS kapalı,
  // kapalı alan) ya da ölçüm güvenilmezse (`guvenilir` kuralı — ±100 m üstü bir başlangıç
  // noktası rotayı yanlış şehir köşesinden kurabilir) `start` HİÇ gönderilmez; sunucu eski
  // davranışıyla ilk duraktan sıralar. Fark kullanıcıya SÖYLENİR (aşağıdaki mesaj eki):
  // sessizce başka bir kipte sıralamak, kuryeye yanlış bir rotaya güvenmesini söylemek olurdu.
  ({double lat, double lng})? baslangic;
  try {
    final konum = await cihazKonumuOku();
    if (konum.guvenilir) baslangic = (lat: konum.lat, lng: konum.lng);
  } on Object {
    // Konum bir KOLAYLIKTIR, ön koşul değil: okunamadıysa sıralama yine yapılır.
  }

  final api = rotaApiUret(Session.baseUrlOf(meta), token);
  final AutoRouteResult sonuc;
  try {
    sonuc = await api.autoRoute(
      [for (final e in liste) e.order.id],
      baslangic: baslangic,
    );
  } on RouteException catch (e) {
    // Sunucu güncel hakkı bildirdiyse ÖNBELLEĞİ düzelt: "34 hak" yazan düğmeye basıp
    // "hakkınız kalmadı" duymak, sonra hâlâ 34 görmek kullanıcıyı ikinci kez yanıltırdı.
    // Yerel alana değil sync_meta'ya yazılır — çekmecedeki kart da aynı kaynağı okur.
    if (e.kalanHak != null) await hakkiYaz(db, e.kalanHak!);
    return OtoSiralamaSonucu(basarili: false, mesaj: e.message);
  }

  // Dönen sırayı okunan kümeye eşle; sunucunun tanımadığı kimlik varsa (silinmiş/kapanmış)
  // sessizce düşer, kalanlar sırayı korur.
  final indeks = {for (final e in liste) e.order.id: e};
  final yeniSira = [
    for (final id in sonuc.sira)
      if (indeks[id] != null) indeks[id]!,
  ];

  final repo = OrderRepository(db);
  for (final girdi in elleSiraYazimi(yeniSira).entries) {
    await repo.setSortIndex(girdi.key, girdi.value);
  }
  await hakkiYaz(db, sonuc.kalanHak);

  // Koordinatsız duraklar sona atıldı — bunu SÖYLEMEK zorundayız, yoksa "sıraladım" demek
  // yanıltıcı olur (kullanıcı o siparişlerin neden sonda olduğunu anlamaz).
  final ek = sonuc.konumsuz > 0
      ? ' ${sonuc.konumsuz} siparişin konumu olmadığı için sona alındı.'
      : '';
  // Hangi KİPTE sıralandığı da söylenir: kurye "benim konumumdan başladı" sanıp ilk durağa
  // gitmemeyi seçebilir. Sessiz bozulma yasak — konum alınamadıysa cümlenin sonunda yazar.
  final kip = baslangic == null ? ' Konumunuz alınamadığı için ilk duraktan başlandı.' : '';
  return OtoSiralamaSonucu(
    basarili: true,
    mesaj: 'Rota sıralandı, ${sonuc.kalanHak} hakkınız kaldı.$ek$kip',
  );
}

/// Sunucunun bildirdiği güncel kontörü ÖNBELLEĞE yazar. Tek doğru kaynak sunucudur; burada
/// yalnız onun söylediği sayı saklanır (istemci kendi kendine düşürmez). Harita ekranı akış
/// aboneliğiyle, `home_shell` de çekmeceyi aynı satırdan tazeler.
Future<void> hakkiYaz(AppDatabase db, int kalan) =>
    (db.update(db.syncMeta)..where((t) => t.id.equals(1)))
        .write(SyncMetaCompanion(routeCredits: Value(kalan)));
