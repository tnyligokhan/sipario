import 'package:drift/drift.dart';

import '../data/app_database.dart';

// Yetki matrisi (roller · kurye izinleri · devralma) buradan ayrıldı — 500 satır sınırı.
// AYNI KÜTÜPHANEDİR (`part`), yani `team.dart` import eden hiçbir yer değişmedi.
part 'team_yetkileri.dart';

/// FAZ 4b Dilim 4 — ekip (yerel `users` aynası) sorguları + rol bazlı yetki. Ekrandan bağımsız,
/// saf test edilebilir (money.dart deseni). `users` team bloğuyla toptan tazelenen önbellektir;
/// istemciden ASLA push edilmez. Yetki mantığı TEK saf fonksiyonda (K2) → regresyon testi kolay.

/// Tüm ekip (ada göre). status disabled DAHİL — atanan kuryenin adı eski atamalarda gösterilsin.
Stream<List<User>> watchTeam(AppDatabase db) =>
    (db.select(db.users)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

/// Yalnız AKTİF kuryeler (ada göre). Kurye ROLÜNE özgü yüzeyler için — kurye yetki ekranı,
/// kurye kotası gibi. ATAMA HEDEFİ İÇİN KULLANILMAZ: onun listesi [watchAtamaHedefleri]'dir.
Stream<List<User>> watchAktifKuryeler(AppDatabase db) => (db.select(db.users)
      ..where((t) => t.role.equals('kurye'))
      ..where((t) => t.status.equals('active'))
      ..orderBy([(t) => OrderingTerm.asc(t.name)]))
    .watch();

/// ATAMA HEDEFLERİ — siparişi kimin götüreceği seçilirken sunulan liste (kullanıcı isteği
/// 2026-08-20: "kurye seçiminde patron kendisini de görebilmeli, daha doğrusu siparişi
/// oluşturan kişi kendisini de görebilmeli").
///
/// ROL SÜZGECİ YOK ve bu, listenin bütün sebebidir. Eskiden yalnız `role='kurye'` dönüyordu;
/// sonucu şuydu: malı çoğu zaman patronun kendisi götürdüğü hâlde onu seçebileceği bir satır
/// YOKTU. Sipariş ya sahipsiz kalıyor ya da götürmeyecek bir kuryeye atanıyordu — ve gün özeti
/// o yanlış atamayı muhasebe kaydı olarak okuyordu (bkz. `repo/islem_sahibi.dart`).
///
/// PASİFLER YOK: pasif hesap iş yapamaz, atama hedefi olamaz. Sıra rolle başlar (patron ·
/// tezgâh · kurye), sonra ad — web Ekip ekranıyla AYNI sıra; kullanıcı aynı ekibi her yüzeyde
/// aynı düzende görmeli.
/// SIRALAMA DART TARAFINDA: ekip birkaç kişiliktir, SQL'de `CASE` kurmanın kazancı yok ama
/// bedeli var (sürüme bağlı ifade API'si). Ad karşılaştırması Türkçe harfleri de doğru sıralasın
/// diye `compareTo` yerine küçük harfe indirgenmiş karşılaştırma kullanılır.
Stream<List<User>> watchAtamaHedefleri(AppDatabase db) =>
    (db.select(db.users)..where((t) => t.status.equals('active'))).watch().map((liste) {
      final sirali = [...liste]..sort((a, b) {
          final r = _rolSirasi(a.role).compareTo(_rolSirasi(b.role));
          return r != 0 ? r : a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      return sirali;
    });

int _rolSirasi(String? rol) => switch (rol) {
      'patron' => 0,
      'operator' => 1,
      _ => 2,
    };

/// Rolün İNSAN OKUNUR adı — TEK yer. Ekranlar rol dizgesini kendileri çevirmez; `operator`
/// kelimesi kullanıcıya hiçbir yerde görünmemeli (bayi "tezgâh" der, "operatör" demez).
String rolEtiketi(String? rol) => switch (rol) {
      'patron' => 'Patron',
      'operator' => 'Tezgâh',
      'kurye' => 'Kurye',
      _ => 'Personel',
    };

/// Devralan seçici için: bayinin patron/operator kullanıcıları (aktif, ada göre).
Stream<List<User>> watchYoneticiler(AppDatabase db) => (db.select(db.users)
      ..where((t) => t.status.equals('active'))
      ..where((t) => t.role.equals('patron') | t.role.equals('operator'))
      ..orderBy([(t) => OrderingTerm.asc(t.name)]))
    .watch();

/// Kullanıcı adını id'den çöz (bulunamazsa null → UI 'Kurye' gibi bir yedeğe düşer). Pasif
/// kullanıcı da çözülür (adı team'de kalır).
String? kullaniciAdi(List<User> team, String? id) {
  if (id == null) return null;
  for (final u in team) {
    if (u.id == id) return u.name;
  }
  return null;
}
