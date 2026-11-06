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
import '../../sync/konum_api.dart';
import '../../sync/route_api.dart';
import 'order_queries.dart';
import 'siparis_gruplari.dart';

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
  if (!yazilabilir) return 'Aboneliğiniz sona erdiği için sıra kaydedilemiyor';
  if (hak == null) return 'Kullanım hakkınız henüz görünmüyor. İnternete bağlanınca kullanabilirsiniz.';
  if (hak <= 0) return 'Oto sıralama hakkı kalmadı';
  if (durakSayisi < 2) return kOtoKumeYetersiz;
  return null;
}

/// Küme yetersizken yazılan gerekçe. Metin SÖZLEŞMEDİR (testler bu cümleyi arar).
const String kOtoKumeYetersiz = 'Rota için en az iki açık sipariş gerekir';

/// Sunucudan SIRA ÖNERİSİ ister, dönen sırayı normal yazma yolundan (`sort_set` olayı) kalıcılar.
/// Kontörü SUNUCU düşer; istemci yalnız onun bildirdiği kalanı önbelleğe yazar.
///
/// Bu, uygulamanın TEK çevrimİÇİ zorunlu eylemidir. Başarısızlıkta mevcut sıra AYNEN kalır;
/// yarım uygulanmış bir rota bırakmaz.
///
/// KİŞİ KİŞİ ROTA (kullanıcı kararı 2026-09-29): "patron oto sıralama yaptığında hem kendi
/// siparişlerini hem de kuryelerin konumlarına göre onların siparişlerini sıralayabilmeli."
///  • KURYE yalnız KENDİSİNE ATANMIŞ siparişleri, kendi konumundan sıralar.
///  • Diğer roller her kişinin grubunu AYRI rota olarak sıralar (`siparis_gruplari.dart`):
///    "Siz" grubu telefonun konumundan, her kurye grubu KURYENİN CANLI KONUMUNDAN başlar.
///    Kuryenin konumu taze değilse onun rotası ilk duraktan başlar ve bu söylenir.
///  • [grup] verilirse (haritadaki kişi şeridinde seçili olan) yalnız o grup sıralanır.
///  • HER ROTA BİR HAK: ürün kuralı "1 sıralama = 1 kontör" ve her rota ayrı bir sıralamadır
///    (sunucuda ayrı bir paralı çağrı). Hak ortada biterse kalan gruplar sıralanmaz ve
///    hangileri olduğu SÖYLENİR; sıralanmış olanlar geri alınmaz.
///
/// KÜME BURADA OKUNUR, çağırandan alınmaz: gruba AÇIK siparişlerin TAMAMI girer (konumsuzlar
/// dahil — sunucu onları sona atar). Gönderilmeyen bir açık siparişin `sort_index`i eski
/// değerinde kalır ve rota görünümünde yeni sıranın ORTASINA düşerdi.
///
/// SIRA NUMARALARI GRUP GRUP AYRILIR: her grubun `sort_index`i kendi bandında (grup sırası ×
/// [kGrupSiraBandi]) yazılır. Böylece patronun "Rota sırası" listesi kişi kişi okunur, kuryenin
/// kendi listesi ise yalnız kendi bandını görür ve sırası bozulmaz.
Future<OtoSiralamaSonucu> otoSiralaKos(AppDatabase db, {String? grup}) async {
  final meta = await db.syncState();
  final token = meta.authToken;
  if (token == null) {
    return const OtoSiralamaSonucu(
        basarili: false, mesaj: 'Oto sıralama için oturum gerekir');
  }

  final liste = await watchOrders(db, OrderFilter.acik).first;
  final users = await db.select(db.users).get();
  final tumGruplar = siparisleriGrupla<OrderListItem>(
    liste,
    atanan: (e) => e.order.assignedUserId,
    kendiId: meta.userId,
    adlar: {for (final u in users) u.id: u.name},
    kuryeKipi: meta.userRole == 'kurye',
  );
  final hedef = [
    for (var i = 0; i < tumGruplar.length; i++)
      if (grup == null || tumGruplar[i].anahtar == grup) (bant: i, grup: tumGruplar[i]),
  ];
  // Tek siparişli grubun sıralanacak bir şeyi yoktur; hak harcanmaz.
  final siralanacak = [for (final h in hedef) if (h.grup.ogeler.length >= 2) h];
  // EMNİYET AĞI: düğme küme yetersizken zaten pasif çizilir ([otoKilitNedeni]), ama ekran
  // açıkken senkron listeyi değiştirmiş olabilir. Cümle düğmenin altındakiyle AYNIDIR.
  if (siralanacak.isEmpty) {
    return const OtoSiralamaSonucu(basarili: false, mesaj: kOtoKumeYetersiz);
  }

  final baseUrl = Session.baseUrlOf(meta);
  final cihaz = await _cihazBaslangici();
  final kuryeKonumlari = siralanacak.any((h) => !h.grup.kendi)
      ? await _kuryeKonumlari(baseUrl, token)
      : const <String, ({double lat, double lng})>{};

  final api = rotaApiUret(baseUrl, token);
  final repo = OrderRepository(db);
  var sirali = 0;
  var konumsuz = 0;
  int? kalanHak;
  final konumsuzBaslayan = <String>[];
  final hakYetmeyen = <String>[];
  String? ariza;

  for (final h in siralanacak) {
    if (ariza != null || kalanHak == 0) {
      hakYetmeyen.add(h.grup.ad);
      continue;
    }
    final baslangic = h.grup.kendi ? cihaz : kuryeKonumlari[h.grup.kullaniciId];
    final AutoRouteResult sonuc;
    try {
      sonuc = await api.autoRoute(
        [for (final e in h.grup.ogeler) e.order.id],
        baslangic: baslangic,
      );
    } on RouteException catch (e) {
      // Sunucu güncel hakkı bildirdiyse ÖNBELLEĞİ düzelt: "34 hak" yazan düğmeye basıp
      // "hakkınız kalmadı" duymak, sonra hâlâ 34 görmek kullanıcıyı ikinci kez yanıltırdı.
      if (e.kalanHak != null) {
        kalanHak = e.kalanHak;
        await hakkiYaz(db, e.kalanHak!);
      }
      if (sirali == 0) return OtoSiralamaSonucu(basarili: false, mesaj: e.message);
      ariza = e.message;
      hakYetmeyen.add(h.grup.ad);
      continue;
    }

    // Dönen sırayı gruba eşle; sunucunun tanımadığı kimlik (silinmiş/kapanmış) sessizce düşer.
    final indeks = {for (final e in h.grup.ogeler) e.order.id: e};
    final yeniSira = [
      for (final id in sonuc.sira)
        if (indeks[id] != null) indeks[id]!,
    ];
    for (final girdi in elleSiraYazimi(yeniSira).entries) {
      await repo.setSortIndex(girdi.key, girdi.value + h.bant * kGrupSiraBandi);
    }
    await hakkiYaz(db, sonuc.kalanHak);
    kalanHak = sonuc.kalanHak;
    sirali++;
    konumsuz += sonuc.konumsuz;
    if (baslangic == null) konumsuzBaslayan.add(h.grup.kendi ? 'sizin' : h.grup.ad);
  }

  return OtoSiralamaSonucu(
    basarili: true,
    mesaj: otoSonucMetni(
      rotaSayisi: sirali,
      kalanHak: kalanHak ?? 0,
      konumsuzSiparis: konumsuz,
      konumsuzBaslayan: konumsuzBaslayan,
      yarimKalan: hakYetmeyen,
    ),
  );
}

/// Grup başına ayrılan `sort_index` bandı. `elleSiraYazimi` 10'ar adımla yazar; 100.000'lik bant
/// 10.000 siparişe kadar komşu grupla çakışmaz.
const int kGrupSiraBandi = 100000;

/// Sonuç cümlesi — saf, doğrudan testlenir. Ne olduysa SÖYLENİR: kaç rota, kalan hak,
/// sona atılan konumsuz siparişler, kimin rotasının konumsuz başladığı, hangilerinin
/// yapılamadığı.
String otoSonucMetni({
  required int rotaSayisi,
  required int kalanHak,
  int konumsuzSiparis = 0,
  List<String> konumsuzBaslayan = const [],
  List<String> yarimKalan = const [],
}) {
  final parcalar = <String>[
    rotaSayisi == 1
        ? 'Rota sıralandı, $kalanHak hakkınız kaldı.'
        : '$rotaSayisi rota sıralandı, $kalanHak hakkınız kaldı.',
    if (konumsuzSiparis > 0) '$konumsuzSiparis siparişin konumu olmadığı için sona alındı.',
    if (konumsuzBaslayan.length == 1 && konumsuzBaslayan.single == 'sizin')
      'Konumunuz alınamadığı için ilk duraktan başlandı.'
    else if (konumsuzBaslayan.isNotEmpty)
      'Konumu bilinmediği için ilk duraktan başlanan rota: ${konumsuzBaslayan.join(', ')}.',
    if (yarimKalan.isNotEmpty) 'Sıralanamayan rota: ${yarimKalan.join(', ')}.',
  ];
  return parcalar.join(' ');
}

/// ROTA NEREDEN BAŞLAR: telefonun BULUNDUĞU nokta. Konum alınamazsa (izin yok, GPS kapalı,
/// kapalı alan) ya da ölçüm güvenilmezse (±100 m üstü) başlangıç HİÇ gönderilmez; sunucu ilk
/// duraktan sıralar ve bu kullanıcıya söylenir.
Future<({double lat, double lng})?> _cihazBaslangici() async {
  try {
    final konum = await cihazKonumuOku();
    if (konum.guvenilir) return (lat: konum.lat, lng: konum.lng);
  } on Object {
    // Konum bir KOLAYLIKTIR, ön koşul değil: okunamadıysa sıralama yine yapılır.
  }
  return null;
}

/// Kuryelerin TAZE canlı konumları (kimlik → nokta). Bayat konum rotanın başı olamaz: 40 dakika
/// önceki nokta kuryeyi şehrin öbür ucundan başlatırdı. Okunamazsa boş — rotalar ilk duraktan.
Future<Map<String, ({double lat, double lng})>> _kuryeKonumlari(
    String baseUrl, String token) async {
  try {
    final konumlar = await konumApiUret(baseUrl, token).canliKonumlar();
    return {
      for (final k in konumlar)
        if (k.taze) k.userId: (lat: k.lat, lng: k.lng),
    };
  } on Object {
    return const {};
  }
}

/// Sunucunun bildirdiği güncel kontörü ÖNBELLEĞE yazar. Tek doğru kaynak sunucudur; burada
/// yalnız onun söylediği sayı saklanır (istemci kendi kendine düşürmez). Harita ekranı akış
/// aboneliğiyle, `home_shell` de çekmeceyi aynı satırdan tazeler.
Future<void> hakkiYaz(AppDatabase db, int kalan) =>
    (db.update(db.syncMeta)..where((t) => t.id.equals(1)))
        .write(SyncMetaCompanion(routeCredits: Value(kalan)));
