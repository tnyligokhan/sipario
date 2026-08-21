// BİLDİRİM KUTUSU — uygulamanın İÇİNDEKİ bildirim listesi (kullanıcı isteği 2026-08-21:
// "bildirimleri görebileceği bir alan eklemelisin ana sayfaya, orada okunmamış bildirimler
// gözükmeli").
//
// ══ NEDEN GEREKLİ ═══════════════════════════════════════════════════════════════════════════
// Bugüne kadar bildirim yalnız SİSTEM RAFINDA yaşıyordu. Bayi rafı süpürdüğü an bilgi yok
// oluyordu; üstelik iki hâlde bildirim zaten hiç görünmüyor:
//   • GÜNLÜK BÜTÇE doluysa (`GunlukSinir`) — kod bunu `atlananlar` listesine yazıyor ama o
//     liste yalnız bellekte, yalnız hata ayıklama için duruyordu,
//   • SESSİZ SAATTE doğduysa — sabaha ertelenir, arada bayi için hiçbir yerde yoktur.
// Kutu bu boşluğu kapatır: gösterilsin ya da gösterilmesin, ÜRETİLEN her bildirim buraya düşer.
//
// ══ KATEGORİSİ KAPALI OLAN YAZILMAZ ═════════════════════════════════════════════════════════
// Tek istisna budur ve bilinçlidir: bayi bir kategoriyi kapattıysa onu HİÇ görmek istemiyordur.
// Kutuya yazmak, kapattığı şeyi başka bir yerden geri getirmek olurdu.
//
// ══ ARKA PLAN PUSH KUTUYA GİRMEZ (bilinen sınır) ════════════════════════════════════════════
// Uygulama KAPALIYKEN gelen push ayrı bir isolate'te işlenir (`push_servisi.dart`) ve orada
// veritabanı AÇIK DEĞİLDİR. Aynı sqlite dosyasını ikinci bir isolate'ten açmak drift'in açıkça
// uyardığı bir yarıştır ve bir bildirim listesi için göze alınacak bir risk değildir. Sonuç:
// o bildirim sistem rafında görünür, kutuda görünmez. Bilgi kaybı DEĞİL — push'un anlattığı
// olay (atanan sipariş vb.) zaten senkronla iner ve kendi ekranında durur.

import 'package:drift/drift.dart';

import '../bildirim/bildirim_sozlesmesi.dart';
import '../data/app_database.dart';

/// Kutuda tutulacak EN FAZLA satır. Aşınca en eskiler silinir.
///
/// 200 gün değil SATIR sınırıdır: bildirim üretimi günlük bütçeyle zaten sınırlı, ama bir
/// telefon aylarca kullanılırsa liste sessizce büyür. Silinen satır bir para kaydı DEĞİLDİR
/// (kırmızı çizgi #2 buraya işlemez) — okunmuş bir hatırlatmanın altı ay sonra hiçbir değeri yok.
const int kBildirimKutusuSiniri = 200;

/// Cihaz-yerel bildirim kutusu. Senkronlanmaz (gerekçe `Bildirimler` tablosunda).
class BildirimKutusu {
  BildirimKutusu(this.db);
  final AppDatabase db;

  /// OKUNMAMIŞ sayısı — ana ekrandaki rozet. Akış: yeni bildirim düşünce rozet kendiliğinden
  /// artar, okununca azalır.
  Stream<int> watchOkunmamisSayisi() {
    final q = db.selectOnly(db.bildirimler)
      ..addColumns([db.bildirimler.id.count()])
      ..where(db.bildirimler.okunduAt.isNull());
    return q.map((r) => r.read(db.bildirimler.id.count()) ?? 0).watchSingle();
  }

  /// Tüm kutu, YENİDEN ESKİYE.
  Stream<List<BildirimlerData>> watchHepsi({int limit = 100}) => (db.select(db.bildirimler)
        ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
        ..limit(limit))
      .watch();

  /// Bir taslağı kutuya yazar.
  ///
  /// VAR OLAN SATIR TAZELENİR AMA "OKUNDU" VE "DOĞUŞ ANI" KORUNUR (gerekçe tabloda). Metin
  /// güncellenir çünkü rakam değişmiş olabilir ("3 gün kapatılmadı" → "4 gün kapatılmadı");
  /// kullanıcı onu okuduysa yine okunmuş kalır.
  Future<void> yaz(BildirimTaslagi t, {required String occurredAtIso}) async {
    final mevcut =
        await (db.select(db.bildirimler)..where((b) => b.id.equals(t.kimlik))).getSingleOrNull();

    if (mevcut == null) {
      await db.into(db.bildirimler).insert(BildirimlerCompanion.insert(
            id: t.kimlik,
            kategori: t.kategori.name,
            baslik: t.baslik,
            govde: t.govde,
            detay: Value(t.detay),
            yol: Value(t.yol),
            occurredAt: occurredAtIso,
          ));
      await _buda();
      return;
    }

    await (db.update(db.bildirimler)..where((b) => b.id.equals(t.kimlik))).write(
      BildirimlerCompanion(
        kategori: Value(t.kategori.name),
        baslik: Value(t.baslik),
        govde: Value(t.govde),
        detay: Value(t.detay),
        yol: Value(t.yol),
      ),
    );
  }

  Future<void> okunduIsaretle(String id, {required String okunduAtIso}) =>
      (db.update(db.bildirimler)
            ..where((b) => b.id.equals(id) & b.okunduAt.isNull()))
          .write(BildirimlerCompanion(okunduAt: Value(okunduAtIso)));

  /// "Tümünü okundu işaretle". Yalnız OKUNMAMIŞ satırlara yazar — okunmuş bir satırın damgası
  /// ileri kaydırılmamalı, o an gerçekten okunduğu andır.
  Future<void> hepsiniOkunduIsaretle({required String okunduAtIso}) =>
      (db.update(db.bildirimler)..where((b) => b.okunduAt.isNull()))
          .write(BildirimlerCompanion(okunduAt: Value(okunduAtIso)));

  /// Sınırı aşan EN ESKİ satırları siler.
  Future<void> _buda() async {
    final hepsi = await (db.select(db.bildirimler)
          ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]))
        .get();
    if (hepsi.length <= kBildirimKutusuSiniri) return;
    final silinecek = hepsi.skip(kBildirimKutusuSiniri).map((b) => b.id).toList();
    await (db.delete(db.bildirimler)..where((b) => b.id.isIn(silinecek))).go();
  }
}

/// Bildirim servisini SARMALAR: her taslağı önce kutuya yazar, sonra gerçek servise devreder.
///
/// ══ NEDEN SARMALAYICI, NEDEN SERVİSİN İÇİ DEĞİL ═════════════════════════════════════════════
/// `YerelBildirimServisi` platform katmanıdır (kanal, izin, zamanlama) ve veritabanını hiç
/// tanımaz. Kutuyu oraya koymak o sınıfı drift'e bağlar ve `SahteBildirimServisi` ile koşan
/// onlarca testi veritabanı kurmaya zorlardı. Sarmalayıcı ikisini de bağımsız bırakır ve
/// kendisi tek başına test edilebilir.
///
/// ══ KUTU ÖNCE YAZILIR ═══════════════════════════════════════════════════════════════════════
/// Sıra bilinçli: iç servis sessiz saat yüzünden ERTELEYEBİLİR, bütçe yüzünden ATLAYABİLİR ya da
/// izin yokluğunda hiç göstermeyebilir. Bunların hiçbiri "bu bildirim üretilmedi" demek değildir.
/// Kutu, üretilmiş olanı kaydeder.
class KutuluBildirimServisi implements BildirimServisi {
  KutuluBildirimServisi(this._ic, this._kutu, {DateTime Function()? simdi})
      : _simdi = simdi ?? DateTime.now;

  final BildirimServisi _ic;
  final BildirimKutusu _kutu;
  final DateTime Function() _simdi;

  Future<void> _kutuyaYaz(BildirimTaslagi t) async {
    // KAPALI KATEGORİ KUTUYA DA GİRMEZ (dosya başlığındaki tek istisna).
    if (!await _ic.kategoriAcikMi(t.kategori)) return;
    await _kutu.yaz(t, occurredAtIso: _simdi().toUtc().toIso8601String());
  }

  @override
  Future<void> goster(BildirimTaslagi t) async {
    await _kutuyaYaz(t);
    await _ic.goster(t);
  }

  @override
  Future<void> zamanla(BildirimTaslagi t, DateTime neZaman) async {
    // ZAMANLANAN BİLDİRİM DE HEMEN KUTUYA GİRER ve bu bir hata değil: taslak ŞU AN üretildi,
    // içeriği şu anki veriden hesaplandı (bkz. `gunKapatilmadiUretici`). Kutuya ateşlendiğinde
    // yazmak, ateşlenme anında bizim kodumuzun koşmadığı gerçeğine çarpar — sistem bildirimi
    // biz uyanmadan gösterir ve kutu sonsuza dek boş kalırdı.
    await _kutuyaYaz(t);
    await _ic.zamanla(t, neZaman);
  }

  @override
  Future<void> iptal(String kimlik) => _ic.iptal(kimlik);

  @override
  Future<bool> izinDurumu() => _ic.izinDurumu();

  @override
  Future<bool> izinIste() => _ic.izinIste();

  @override
  Future<bool> kategoriAcikMi(BildirimKategori k) => _ic.kategoriAcikMi(k);
}
