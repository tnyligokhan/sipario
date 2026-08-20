import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/courier_repository.dart';
import 'package:sipario/screens/team.dart';

/// KİŞİYE ÖZEL KURYE YETKİLERİ — devralma matrisi ve yazım sözleşmesi (kullanıcı kararı
/// 2026-08-10: "kurye yetkileri kuryeye özel atanmalı, direkt role değil").
///
/// `kurye_yetkileri_test.dart` bayi varsayılanının role nasıl uygulandığını sınar. Bu dosya
/// onun üstüne gelen katmanı sınar: **aynı bayide iki kuryenin farklı yetkisi olabilmesi.**
///
/// ÜÇ DURUM VE ÜÇÜ DE AYRI ŞEYDİR — bu dosyanın varlık sebebi budur:
///   • ezme `null`  → bayi varsayılanı devralınır
///   • ezme `true`  → varsayılan kapalı olsa bile bu kuryede AÇIK
///   • ezme `false` → varsayılan açık olsa bile bu kuryede KAPALI
///
/// `null` ile `false`u karıştıran bir katman, bayinin varsayılanını değiştirdiğinde kuryenin
/// yetkisinin neden oynamadığını (ya da oynadığını) açıklayamaz hâle getirir; bu projede
/// "eksik anahtar varsayılana çekiliyor" sınıfı hata iki kez yaşandı (DECISIONS 2026-08-05).
void main() {
  group('kuryeIzinleriCoz() — devralma matrisi', () {
    test('ezme yoksa varsayılan AYNEN geçerlidir (13 alanın hepsi)', () {
      const varsayilan = KuryeIzinleri();
      final coz = kuryeIzinleriCoz(varsayilan, KuryeIzinEzmeleri.bos);

      // Alan alan: "hiç ezme yoksa varsayılanı döndür" kısayolu doğru sonucu verir ama
      // yanlış sebeple — asıl garanti, her alanın BAĞIMSIZ devralınmasıdır.
      expect(coz.musteri, varsayilan.musteri);
      expect(coz.siparis, varsayilan.siparis);
      expect(coz.tahsilat, varsayilan.tahsilat);
      expect(coz.iskonto, varsayilan.iskonto);
      expect(coz.gunSonu, varsayilan.gunSonu);
      expect(coz.tumSiparisler, varsayilan.tumSiparisler);
      expect(coz.gecmisTeslimatlar, varsayilan.gecmisTeslimatlar);
      expect(coz.sahaGideri, varsayilan.sahaGideri);
      expect(coz.telefonMaskeleme, varsayilan.telefonMaskeleme);
      expect(coz.musteriGecmisDefteri, varsayilan.musteriGecmisDefteri);
      expect(coz.borcHatirlatma, varsayilan.borcHatirlatma);
      expect(coz.stokPasifleme, varsayilan.stokPasifleme);
      expect(coz.cagriGunlugu, varsayilan.cagriGunlugu);
    });

    test('ezme null ise (kullanıcı satırı hiç yok) varsayılan geçerlidir', () {
      const varsayilan = KuryeIzinleri(iskonto: true);
      expect(kuryeIzinleriCoz(varsayilan, null).iskonto, isTrue);
    });

    test('true ezmesi KAPALI varsayılanı açar — güvenilen kuryeye iskonto', () {
      // Bayi varsayılanı: iskonto kapalı (para kırma patron kararıdır).
      const varsayilan = KuryeIzinleri(iskonto: false);
      final coz = kuryeIzinleriCoz(varsayilan, const KuryeIzinEzmeleri(iskonto: true));
      expect(coz.iskonto, isTrue);
    });

    test('false ezmesi AÇIK varsayılanı kapatır — yeni kuryeye tahsilat yok', () {
      // Bayi varsayılanı: tahsilat açık. Yeni başlayan kuryede kasa sorumluluğu istenmiyor.
      const varsayilan = KuryeIzinleri(tahsilat: true);
      final coz = kuryeIzinleriCoz(varsayilan, const KuryeIzinEzmeleri(tahsilat: false));
      expect(coz.tahsilat, isFalse);
    });

    test('TEK alanın ezilmesi diğer 12 alanın devralmasını BOZMAZ', () {
      // Kısayol yazımının (ezme varsa hepsini ezmeden al) yakalanacağı yer burasıdır.
      const varsayilan = KuryeIzinleri(
        musteri: true,
        siparis: true,
        tahsilat: true,
        iskonto: false,
        stokPasifleme: true,
      );
      final coz = kuryeIzinleriCoz(varsayilan, const KuryeIzinEzmeleri(iskonto: true));

      expect(coz.iskonto, isTrue, reason: 'ezilen alan');
      expect(coz.musteri, isTrue, reason: 'devralınmalı');
      expect(coz.siparis, isTrue, reason: 'devralınmalı');
      expect(coz.tahsilat, isTrue, reason: 'devralınmalı');
      expect(coz.stokPasifleme, isTrue, reason: 'devralınmalı');
    });

    test('aynı bayide İKİ KURYE farklı yetkiye sahip olabilir — özelliğin varlık sebebi', () {
      const varsayilan = KuryeIzinleri(iskonto: false, tumSiparisler: false);

      // Kıdemli kurye: iskonto yapabilir, dükkanın tüm siparişlerini görür.
      final kidemli = kuryeIzinleriCoz(
        varsayilan,
        const KuryeIzinEzmeleri(iskonto: true, tumSiparisler: true),
      );
      // Yeni kurye: hiç ezmesi yok, varsayılanı devralır.
      final yeni = kuryeIzinleriCoz(varsayilan, KuryeIzinEzmeleri.bos);

      expect(kidemli.iskonto, isTrue);
      expect(yeni.iskonto, isFalse);
      expect(kidemli.tumSiparisler, isTrue);
      expect(yeni.tumSiparisler, isFalse);
    });
  });

  group('yetkiler() — kişisel ezme role kadar iner', () {
    test('kişisel ezme kuryenin ETKİN yetkisini değiştirir', () {
      const varsayilan = KuryeIzinleri(iskonto: false);
      final izin = kuryeIzinleriCoz(varsayilan, const KuryeIzinEzmeleri(iskonto: true));
      expect(yetkiler(rol: 'kurye', atamaHedefiVar: true, izin: izin).iskonto, isTrue);
    });

    test('YÖNETİCİ kişisel ezmeden ETKİLENMEZ — kapatılmış yetki patronu bağlamaz', () {
      // Kırmızı çizgi: patron/operatör kısıtlamasızdır. Bir "false" ezmesi yanlışlıkla
      // patron satırına yazılsa bile yöneticinin yetkisi düşmemelidir.
      final izin = kuryeIzinleriCoz(
        const KuryeIzinleri(tahsilat: true),
        const KuryeIzinEzmeleri(tahsilat: false, iskonto: false),
      );
      final patron = yetkiler(rol: 'patron', atamaHedefiVar: true, izin: izin);
      expect(patron.tahsilat, isTrue);
      expect(patron.iskonto, isTrue);
    });
  });

  group('kuryeEzmeleriOku() — users satırından okuma', () {
    test('kullanıcı yoksa hepsi devralınır', () {
      expect(kuryeEzmeleriOku(null).hepsiDevralindi, isTrue);
    });
  });

  group('hepsiDevralindi — "özel yetki" rozetinin kapısı', () {
    test('boş ezmede true', () {
      expect(KuryeIzinEzmeleri.bos.hepsiDevralindi, isTrue);
    });

    test('TEK BİR false ezmesi bile rozeti yakar', () {
      // `false`u "değer yok" sayan bir kontrol (ör. `?? false` ya da truthy denetimi)
      // burada kırmızı yanar: kapatılmış bir yetki de kişiselleştirmedir.
      expect(const KuryeIzinEzmeleri(tahsilat: false).hepsiDevralindi, isFalse);
    });

    test('tek bir true ezmesi de rozeti yakar', () {
      expect(const KuryeIzinEzmeleri(iskonto: true).hepsiDevralindi, isFalse);
    });
  });

  group('CourierRepository.kuryeIzinEzmeleriKaydet() — yazım sözleşmesi', () {
    /// Kuryenin yerel satırı + oturum damgası. `users` sunucudan iner, testte elle kurulur.
    Future<AppDatabase> kur() async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.into(db.users).insert(UsersCompanion.insert(
            id: 'k-1',
            name: 'Ahmet Yıldız',
            role: 'kurye',
            status: 'active',
          ));
      await db.into(db.syncMeta).insertOnConflictUpdate(const SyncMetaCompanion(
            id: Value(1),
            deviceId: Value('cihaz-A'),
            userId: Value('patron-1'),
          ));
      return db;
    }

    test('yerel satır ANINDA güncellenir (ekran senkronu beklemez)', () async {
      final db = await kur();
      addTearDown(db.close);

      await CourierRepository(db)
          .kuryeIzinEzmeleriKaydet('k-1', const KuryeIzinEzmeleri(iskonto: true));

      final u = await (db.select(db.users)..where((t) => t.id.equals('k-1'))).getSingle();
      expect(u.courierCanDiscount, isTrue);
    });

    test('"varsayılana dön" payload\'da AÇIKÇA null gider — anahtarı çıkarmak YETMEZ', () async {
      // Sözleşmenin can alıcı noktası: sunucu için EKSİK anahtar "dokunma" demektir. Ezmeyi
      // kaldırmak istiyorsak anahtar payload'da OLMALI ve değeri null OLMALI; aksi hâlde
      // kurye eski ezmesine sonsuza dek çakılı kalır ve varsayılanı asla devralamaz.
      final db = await kur();
      addTearDown(db.close);

      await CourierRepository(db).kuryeIzinEzmeleriKaydet('k-1', KuryeIzinEzmeleri.bos);

      final olay = await db.select(db.outbox).getSingle();
      final payload = jsonDecode(olay.payload) as Map<String, Object?>;

      expect(olay.entityType, 'user_profile');
      expect(payload['id'], 'k-1');
      for (final anahtar in const [
        'courier_can_customers',
        'courier_can_orders',
        'courier_can_collect',
        'courier_can_discount',
        'courier_can_day_end',
        'courier_can_see_all_orders',
        'courier_can_view_history',
        'courier_can_expense',
        'courier_phone_mask',
        'courier_can_customer_ledger',
        'courier_can_debt_reminder',
        'courier_can_toggle_stock',
        'courier_can_call_log',
      ]) {
        expect(payload.containsKey(anahtar), isTrue,
            reason: '$anahtar payload\'da BULUNMALI (yoksa sunucu "dokunma" anlar)');
        expect(payload[anahtar], isNull, reason: '$anahtar null olmalı = devral');
      }
    });

    test('AD/TELEFON/DURUM anahtarları payload\'a GİRMEZ — yetki ekranı onları bilmez', () async {
      // "Form dışı ayar" tuzağının bu varlıktaki karşılığı: bilmediği alanı gönderen bir
      // yüzey, sunucudaki güncel değeri eskimiş bir kopyayla ezer.
      final db = await kur();
      addTearDown(db.close);

      await CourierRepository(db)
          .kuryeIzinEzmeleriKaydet('k-1', const KuryeIzinEzmeleri(tahsilat: false));

      final payload =
          jsonDecode((await db.select(db.outbox).getSingle()).payload) as Map<String, Object?>;
      expect(payload.containsKey('name'), isFalse);
      expect(payload.containsKey('phone'), isFalse);
      expect(payload.containsKey('status'), isFalse);
      expect(payload['courier_can_collect'], isFalse);
    });

    test('damga ve device_id YAZILIR — cihazsız yazım LWW\'de sessizce bayat kalır', () async {
      final db = await kur();
      addTearDown(db.close);

      await CourierRepository(db)
          .kuryeIzinEzmeleriKaydet('k-1', const KuryeIzinEzmeleri(iskonto: true));

      final olay = await db.select(db.outbox).getSingle();
      expect(olay.deviceId, 'cihaz-A');
      expect(olay.occurredAt, isNotEmpty);
      expect(olay.status, 'pending');
    });
  });

  group('watchOturumKuryeIzinleri() — kabuğun etkin izin akışı', () {
    test('oturumun KENDİ satırındaki ezme çözülür, başkasınınki karışmaz', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      // Bayi varsayılanı: iskonto KAPALI.
      await db.into(db.tenantSettings).insertOnConflictUpdate(const TenantSettingsCompanion(
            id: Value(1),
            courierCanDiscount: Value(false),
          ));
      // İki kurye: biri iskonto yapabilir, diğeri devralır. Oturum ikincisinde.
      await db.into(db.users).insert(UsersCompanion.insert(
            id: 'k-kidemli',
            name: 'Kıdemli',
            role: 'kurye',
            status: 'active',
            courierCanDiscount: const Value(true),
          ));
      await db.into(db.users).insert(UsersCompanion.insert(
            id: 'k-yeni',
            name: 'Yeni',
            role: 'kurye',
            status: 'active',
          ));
      await db.into(db.syncMeta).insertOnConflictUpdate(const SyncMetaCompanion(
            id: Value(1),
            userId: Value('k-yeni'),
            userRole: Value('kurye'),
          ));

      expect((await watchOturumKuryeIzinleri(db).first).iskonto, isFalse,
          reason: 'k-yeni devralır → kapalı');

      // Oturum kıdemli kuryeye geçerse akış YENİDEN yayınlamalı (tek atış okuma burada bayat
      // kalırdı — ölçülmüş ders).
      await (db.update(db.syncMeta)..where((t) => t.id.equals(1)))
          .write(const SyncMetaCompanion(userId: Value('k-kidemli')));

      expect((await watchOturumKuryeIzinleri(db).first).iskonto, isTrue,
          reason: 'k-kidemli ezmesi → açık');
    });

    test('users satırı henüz inmediyse bayi varsayılanına düşer, yetki UYDURULMAZ', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await db.into(db.tenantSettings).insertOnConflictUpdate(const TenantSettingsCompanion(
            id: Value(1),
            courierCanCollect: Value(true),
            courierCanDiscount: Value(false),
          ));
      await db.into(db.syncMeta).insertOnConflictUpdate(const SyncMetaCompanion(
            id: Value(1),
            userId: Value('henuz-inmemis'),
            userRole: Value('kurye'),
          ));

      final izin = await watchOturumKuryeIzinleri(db).first;
      expect(izin.tahsilat, isTrue);
      expect(izin.iskonto, isFalse);
    });
  });
}
