// BİR İŞİN SAHİBİ KİMDİR — atıf kuralının TEK yeri (kullanıcı kararı 2026-08-20).
//
// ══ KURAL ═══════════════════════════════════════════════════════════════════════════════════
// "Uygulamada yapılan her işlem, o işlemi YAPAN hesaba yazılır." Siparişin ATANDIĞI kişi
// (`orders.assigned_user_id`) bir NİYETTİR — rota planıdır, muhasebe kaydı değil. Kim teslim
// ettiyse (`orders.delivered_by_user_id`) teslimat da, o teslimden doğan veresiye de onundur.
//
// ══ NEDEN AYRI DOSYA ════════════════════════════════════════════════════════════════════════
// Aynı kural iki ayrı okuma modelinde lazım (`DayEndRepository.teslimatSayisi` ve
// `GunVeresiyeRepository.gununVeresiyeleri`) ve bu depoda "aynı parayı iki yerde ayrı hesaplamak"
// gün sonu tanımında ÜÇ KEZ tekrarlanmış bir hata sınıfıdır: bayi kartta bir rakam, listede
// başka bir rakam görürse ikisine de güvenmez. Kural tek yerde durur ve doğrudan testlenir.
//
// ══ GERİYE DÖNÜK DAVRANIŞ ═══════════════════════════════════════════════════════════════════
// `delivered_by_user_id` v25'te (2026-08-20) geldi; ondan ÖNCEKİ teslimlerde NULL'dur ve bu
// dürüst bir boşluktur — o teslimi kimin yaptığı hiçbir yerde kayıtlı DEĞİLDİR. Boşlukta atamaya
// düşülür: geçmiş günler yükseltmeden önceki gibi görünmeye devam eder, uydurulmuş bir atıf
// üretilmez. Yeni teslimlerin hepsi alanı taşır, yani boşluk büyümez.

import 'package:drift/drift.dart';

import '../data/app_database.dart';

/// Bir siparişin gün özetinde HANGİ hesaba yazılacağı. Teslim eden varsa o; yoksa (v25 öncesi
/// kayıt) atanan kişi.
String? siparisSahibi({String? deliveredByUserId, String? assignedUserId}) =>
    deliveredByUserId ?? assignedUserId;

/// [siparisSahibi]'nin SQL karşılığı — aynı kural, aynı sonuç. Drift `where` yükleminde kullanılır.
///
/// Dart tarafındaki `??` ile birebir aynı okunur: "teslim eden bu kişi" YA DA "teslim eden hiç
/// yazılmamış ve atanan bu kişi".
Expression<bool> siparisSahibiEsit($OrdersTable t, String userId) =>
    t.deliveredByUserId.equals(userId) |
    (t.deliveredByUserId.isNull() & t.assignedUserId.equals(userId));

// ══ KAPSAM SÜZGECİ (gün özeti, kullanıcı isteği 2026-08-20) ═══════════════════════════════
//
// Gün özeti üç soruyu ayrı ayrı cevaplamalı: "ben ne yaptım", "elemanlarım ne yaptı", "toplam
// ne oldu". Üçü tek bir süzgeç ailesiyle ifade edilir:
//
//   userId  verilirse → YALNIZ o kişi
//   haric   verilirse → o kişi HARİÇ herkes ("Elemanlar" — patronun kendi işlemlerini çıkarır)
//   ikisi de yoksa    → süzgeç yok (Tümü)
//
// ⚠️ İKİSİ BİRDEN VERİLMEZ. Verilirse `haric` kazanır; ama çağıranın böyle bir hâli üretmemesi
// gerekir — kapsam seçimi tek bir seçenektir, iki değil.
//
// SAHİBİ BİLİNMEYEN KAYIT "ELEMAN" SAYILMAZ: `haric` kipinde sahip alanı NULL olan satırlar
// dışarıda kalır. Alternatifi, atfı olmayan eski kayıtları toptan "elemanların işi" göstermekti —
// yani bilinmezliği bir iddiaya çevirmek.

/// Bir hareketin sahibi seçili kapsama düşüyor mu — Dart tarafı ([kapsamSuzgeci]'nin ikizi).
bool kapsamaDusuyor(String? sahip, {String? userId, String? haric}) {
  if (haric != null) return sahip != null && sahip != haric;
  if (userId != null) return sahip == userId;
  return true;
}

/// Defter satırları için kapsam yüklemi (`collected_by_user_id`). Süzgeç gerekmiyorsa null.
Expression<bool>? defterKapsamSuzgeci(
  $LedgerEntriesTable t, {
  String? userId,
  String? haric,
}) {
  if (haric != null) {
    return t.collectedByUserId.isNotNull() & t.collectedByUserId.isNotValue(haric);
  }
  if (userId != null) return t.collectedByUserId.equals(userId);
  return null;
}

/// Siparişler için kapsam yüklemi — sahibi [siparisSahibiEsit] kuralıyla çözülür.
/// Süzgeç gerekmiyorsa null.
Expression<bool>? siparisKapsamSuzgeci(
  $OrdersTable t, {
  String? userId,
  String? haric,
}) {
  if (haric != null) {
    final teslimEden = t.deliveredByUserId.isNotNull() & t.deliveredByUserId.isNotValue(haric);
    final atanan = t.deliveredByUserId.isNull() &
        t.assignedUserId.isNotNull() &
        t.assignedUserId.isNotValue(haric);
    return teslimEden | atanan;
  }
  if (userId != null) return siparisSahibiEsit(t, userId);
  return null;
}
