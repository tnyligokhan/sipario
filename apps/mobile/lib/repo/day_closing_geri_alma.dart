// KAPANIŞI GERİ ALMA — kapatılmış bir hesabın yeniden açılması (kullanıcı kararı 2026-08-18:
// "patron hata yapabilir, kasayı kapattığında yönetici şifresi ile geriye alabilir").
//
// NEDEN AYRI DOSYA: `day_closing_repository.dart` bu akışla 570 satıra çıkmıştı (depo sınırı
// 500). Ayrım KONUYA göre: ana dosya hesabı KAPATIR (önizleme · kimlik · arşiv satırı), burası
// kapatılmış olanı AÇAR. İkisi ters yönlü akışlardır ve tek ortak noktaları arşiv kaydıdır.
//
// NEDEN `part` (ayrı kütüphane değil): buradaki akış `_geriAlinmisIdler()` ve `_sameTrDay()`
// gibi PRIVATE yardımcıları kullanıyor ve onların public olması gerekmiyor — "geçerli kapanış"
// tanımının tek sahibi bu repodur. `part` aynı kütüphanede kalmayı, dolayısıyla `_` gizliliğini
// ve `DayClosingRepository.db`ye erişimi korur. Çağrı yerleri DEĞİŞMEZ.
//
// `cash_handover_ara_tahsilat.dart` ile birebir aynı gerekçe ve aynı desen.

part of 'day_closing_repository.dart';

extension KapanisGeriAlma on DayClosingRepository {
  /// Kapatılmış bir hesabı GERİ ALIR: gün/kurye yeniden açılır ve düzeltilip yeniden kapatılabilir.
  ///
  /// ══ NEDEN GEREKLİ ═══════════════════════════════════════════════════════════════════════
  /// Kapanış bugüne kadar TEK YÖNLÜYDÜ. Yanlış sayılmış bir nakit arşive KALICI donuyor, gün
  /// kilitleniyordu; patronun elindeki tek çare ertesi gün deftere ters kayıt yazmaktı — yani
  /// hatanın izi doğru yerde değil, bir gün ilerideydi. Kullanıcının tarifi: "patron hata
  /// yapabilir, kasayı kapattığında yönetici şifresi ile geriye alabilir".
  ///
  /// ══ SİLME YOK ═══════════════════════════════════════════════════════════════════════════
  /// Geri alma, tabloya yazılan TERS BİR SATIRdır ([DayClosings.reversesClosingId]). Orijinal
  /// kapanış kanıt olarak yerinde durur; arşiv "ne olduğunu" anlatmayı sürdürür.
  ///
  /// ══ BAĞLI KASA DEVRİ DE GERİ ALINIR — AYNI TRANSACTION'DA ══════════════════════════════
  /// ⚠️ Bunu atlamak, özelliğin en pahalı hatası olurdu. Kurye kapanışı `alsoHandover` ile bir
  /// `cash_handovers` satırı da yazar; kapanış geri alınıp gün yeniden kapatılırsa o devir
  /// YERİNDE KALIR ve İKİNCİ bir devir daha yazılır. `teslimEdilenNakit` ikisini birden sayar,
  /// gün kapsamında beklenen nakit teslim edilen paranın İKİ KATI kadar düşer ve patron
  /// kasasını sayınca açıklanamaz bir "FAZLA" görür — append-only olduğu için de kalıcı.
  ///
  /// `araTahsilatIptal` bu iş için KULLANILAMAZ: o fonksiyon kapanışa bağlı devirleri bilerek
  /// reddeder ("ara tahsilat değildir"). Kural doğruydu ve duruyor — orada yasaklanan şey
  /// devrin TEK BAŞINA geri alınmasıydı; burada kapanışıyla BİRLİKTE geri alınıyor.
  ///
  /// [StateError] atar: kayıt yok · satır zaten bir geri alma · zaten geri alınmış · gün hesabı
  /// kapalıyken kurye kapanışı geri alınmaya çalışılıyor.
  Future<String> geriAl({required String closingId, String? note}) async {
    final hedef = await (db.select(db.dayClosings)..where((t) => t.id.equals(closingId)))
        .getSingleOrNull();
    if (hedef == null) {
      throw StateError('Kapanış kaydı bulunamadı; ekranı yenileyip tekrar deneyin');
    }
    if (hedef.reversesClosingId != null) {
      throw StateError('Bu satır zaten bir geri alma kaydı; geri alınamaz');
    }
    if ((await _geriAlinmisIdler()).contains(hedef.id)) {
      throw StateError('Bu kapanış zaten geri alınmış');
    }

    // SIRA KURALI: gün hesabı kapalıyken bir KURYE kapanışını geri almak, kilitli bir günün
    // içindeki hesabı açmak olurdu — gün toplamı o kapanışı zaten yutmuş durumda. Önce gün
    // geri alınır, sonra kurye. (Tasarımdaki "gün kapandıysa tüm hesaplar kilitli" kuralının
    // ters yöndeki karşılığı.)
    if (hedef.scope == ClosingScope.courier.name) {
      final gun = trGunu(DateTime.parse(hedef.occurredAt).add(const Duration(hours: 3)));
      if (await kapaliMi(ClosingScope.day, localDate: gun)) {
        throw StateError('Önce gün hesabını geri alın; gün kapalıyken kurye hesabı açılamaz');
      }
    }

    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;

    // GERİ ALMANIN KİMLİĞİ HEDEFTEN TÜRER: bir kapanış EN FAZLA BİR KEZ geri alınabilir (sunucuda
    // kısmi unique indeks bunu zorluyor), yani "hangi kapanışı geri alıyorum" tek başına yeterli
    // bir çekirdektir. İki cihaz aynı anda geri alırsa AYNI satırı üretir ve ikinci push
    // 'duplicate' olur — para iki kez geri gelmez.
    final tenant = meta.tenantCode;
    final id = tenant == null
        ? newId()
        : kapanisOlayId(
            tenantCode: tenant,
            scope: hedef.scope,
            userId: hedef.userId,
            gunAnahtari: closingId,
            tag: 'geri-al',
          );

    await db.transaction(() async {
      await db.into(db.dayClosings).insert(DayClosingsCompanion.insert(
            id: id,
            scope: hedef.scope,
            userId: Value(hedef.userId),
            reversesClosingId: Value(hedef.id),
            // TUTARLAR SIFIR: bu satır bir mutabakat değil, bir GERİ ALMADIR. Hedefin
            // rakamlarını ters işaretle kopyalamak cazip ama YANLIŞ olurdu — `day_closings`
            // toplanan bir defter değil, ARŞİV SNAPSHOT'LARI listesidir; ters bir snapshot
            // "eksi 480 ₺ sayıldı" gibi okunamayan bir kayıt bırakırdı. Paranın geri dönüşü
            // bağlı devrin ters satırından gelir (aşağıda).
            occurredAt: at,
            deviceId: Value(device),
            note: Value(note),
          ));
      await enqueueOutbox(db,
          entityType: 'day_closing',
          op: 'closing',
          entityId: id,
          occurredAt: at,
          deviceId: device,
          payload: <String, Object?>{
            'id': id,
            'scope': hedef.scope,
            'user_id': hedef.userId,
            'reverses_closing_id': hedef.id,
            'note': note,
          });

      // BAĞLI KASA DEVRİ — kapanışla AYNI transaction'da ters satır (gerekçe doc'ta).
      final devirId = hedef.cashHandoverId;
      if (devirId != null) {
        final devir = await (db.select(db.cashHandovers)..where((t) => t.id.equals(devirId)))
            .getSingleOrNull();
        if (devir != null) {
          final tersId = tenant == null
              ? newId()
              : kapanisOlayId(
                  tenantCode: tenant,
                  scope: hedef.scope,
                  userId: hedef.userId,
                  gunAnahtari: closingId,
                  tag: 'geri-al-handover',
                );
          await db.into(db.cashHandovers).insert(CashHandoversCompanion.insert(
                id: tersId,
                fromUserId: devir.fromUserId,
                toUserId: Value(devir.toUserId),
                countedCashKurus: -devir.countedCashKurus,
                expectedCashKurus: 0,
                diffKurus: 0,
                reversesHandoverId: Value(devir.id),
                occurredAt: at,
                deviceId: Value(device),
                note: Value(note),
              ));
          await enqueueOutbox(db,
              entityType: 'cash_handover',
              op: 'handover',
              entityId: tersId,
              occurredAt: at,
              deviceId: device,
              payload: <String, Object?>{
                'id': tersId,
                'from_user_id': devir.fromUserId,
                'to_user_id': devir.toUserId,
                'counted_cash_kurus': -devir.countedCashKurus,
                'expected_cash_kurus': 0,
                'diff_kurus': 0,
                'reverses_handover_id': devir.id,
                'note': note,
              });
        }
      }
    });

    return id;
  }

}
