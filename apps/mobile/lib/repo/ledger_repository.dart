import '../data/app_database.dart';
import '../data/ids.dart';
import 'ledger_ops.dart';

/// Defter yerel iş akışları (FAZ 3). Para İMZALI çift-satır modeli (DECISIONS): borç debit(+),
/// tahsilat payment(−, ödeme tipiyle), manuel alacak credit(−), düzeltme correction (ters kayıt).
/// Her metod TEK transaction: ledger_entries append + customers.balance_kurus recompute + outbox
/// (writeLedgerEntry içinde). Silme/UPDATE YOK — append-only; düzeltme yalnız ters kayıtla.
class LedgerRepository {
  LedgerRepository(this.db);
  final AppDatabase db;

  /// Tahsilat: müşteriden para girişi. amountKurus POZİTİF verilir, deftere payment(−) olarak düşer.
  /// paymentType: nakit|kart|havale (kasa gruplaması buna bağlı).
  Future<String> tahsilat(String customerId, int amountKurus, String paymentType) {
    return _write(customerId, entryType: 'payment', amountKurus: -amountKurus.abs(), paymentType: paymentType);
  }

  /// Manuel borç ekleme (veresiye satış dışı): debit(+). amountKurus POZİTİF.
  Future<String> borcEkle(String customerId, int amountKurus, {String? note}) {
    return _write(customerId, entryType: 'debit', amountKurus: amountKurus.abs(), note: note);
  }

  /// Manuel alacak/indirim: credit(−) borcu azaltır. amountKurus POZİTİF verilir.
  Future<String> alacak(String customerId, int amountKurus, {String? note}) {
    return _write(customerId, entryType: 'credit', amountKurus: -amountKurus.abs(), note: note);
  }

  /// Düzeltme (ters kayıt): bir defter kaydını correction ile düzeltir; amountKurus İMZALI verilir
  /// (düzeltilen kaydın etkisini sıfırlamak için ters işaret). Kaynak kayıt SİLİNMEZ (append-only).
  ///
  /// Ters çevrilen satırdan İKİ ŞEY DEVRALINIR — ikisi de aynı gerekçenin parçası: düzeltme,
  /// düzelttiği kaydın etkisini AYNI yerden geri almalıdır.
  ///
  ///  • `payment_type`: yanlış kayıt hangi kasa gözünden çıktıysa düzeltme de oradan düşer
  ///    (bakiye VE kasa birlikte düzelir). Ters çevrilen kayıt payment_type taşımıyorsa
  ///    (ör. veresiye debit) correction da taşımaz → yalnız bakiye düzelir, kasaya dokunmaz.
  ///  • `collected_by_user_id`: kasa katkısı KİMİN kasasından çıktıysa düzeltmesi de oraya
  ///    yazılır. Eskiden buraya DÜZELTMEYİ YAZAN kişi (`sync_meta.user_id`) geçiyordu ve o,
  ///    kuryenin parasını patronun kasasından düşüyordu: Emre 10.000 topladı, patron kendi
  ///    telefonundan 2.000'i ters çevirdi → gün kapsamında beklenen −2.000 (patron "FAZLA 2.000"
  ///    görür), Emre'nin kapsamında beklenen 10.000 kalır ama cebinde 8.000 vardır ve kapanışta
  ///    "EKSİK 2.000" arşive KALICI donardı. Bir kişinin hatası başkasının kasasında eksik
  ///    görünemez.
  ///
  /// Ters çevrilen satır BULUNAMAZSA atıf yazana düşer — o durumda payment_type da null kalır,
  /// yani kayıt kasaya zaten dokunmaz ve atfın para sonucu olmaz.
  Future<String> duzeltme(String reversesEntryId, int amountKurus, {String? customerId, String? note}) async {
    final reversed = await (db.select(db.ledgerEntries)
          ..where((t) => t.id.equals(reversesEntryId)))
        .getSingleOrNull();
    return _write(customerId, entryType: 'correction', amountKurus: amountKurus,
        tersCevrilen: reversed, reversesEntryId: reversesEntryId, note: note);
  }

  /// [tersCevrilen] verilirse `payment_type` ve nakit ATFI o satırdan devralınır (bkz. [duzeltme]).
  /// Tek parametrede taşınıyor çünkü ikisi TEK karardır: "bu kaydın etkisini aynı yerden geri al".
  /// Ayrı iki isteğe bağlı alan olsaydı biri geçilip diğeri unutulabilirdi — atfın null OLMASI da
  /// anlamlı bir devirdir (atıfsız tahsilatın düzeltmesi de atıfsızdır) ve `?? meta.userId`
  /// gibi bir varsayılan onu sessizce yazana kaydırırdı.
  Future<String> _write(
    String? customerId, {
    required String entryType,
    required int amountKurus,
    String? paymentType,
    LedgerEntry? tersCevrilen,
    String? reversesEntryId,
    String? note,
  }) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    late String id;
    await db.transaction(() async {
      id = await writeLedgerEntry(db,
          entryType: entryType,
          amountKurus: amountKurus,
          customerId: customerId,
          paymentType: tersCevrilen?.paymentType ?? paymentType,
          // FAZ 4: nakit atfı (kasa devri dayanağı). Düzeltmede atıf DEVRALINIR.
          collectedByUserId:
              tersCevrilen != null ? tersCevrilen.collectedByUserId : meta.userId,
          reversesEntryId: reversesEntryId,
          note: note,
          occurredAt: at,
          deviceId: meta.deviceId);
    });
    return id;
  }
}
