/// FAZ 5a — abonelik erişim kararı (istemci tarafı, DECISIONS "Abonelik ve kilit").
///
/// Sunucu TEK doğru kaynaktır; istemci son bilinen durumu (sync_meta önbelleği) + İLERİ-SADECE saatle
/// karar verir. Grace SUNUCUDA YOK; 7 gün lütuf YALNIZ istemcide, sunucuya ulaşılamadığında ödeyen
/// bayiyi yanlış kilitlememek içindir:
///  - valid_until GELECEKTE → tam çalışma (cihaz haftalarca offline olsa da; fatura ödenmiş).
///  - valid_until GEÇMİŞ + 7 gün içinde → grace (yazılabilir; sunucuya ulaşınca kesinleşir).
///  - valid_until GEÇMİŞ + 7 gün sonrası → salt-okunur.
///  - Sunucu açıkça locked/suspended dediyse (ulaşıldığında) → salt-okunur (otorite sunucu).
///  - valid_until NULL → tam (süre/kısıt yok; sunucu "null = kilitsiz" ile simetrik).
///
/// evaluate() SAF fonksiyondur (estimatedServerNow enjekte edilir → test edilebilir). Gerçek
/// ileri-sadece saat (elapsedRealtime) platform kanalı ister; estimateServerNow() minimal bir
/// yaklaşımdır (sistem saati + sunucu offset, son görülen sunucu saatine tabanlanmış — geri alınamaz).
enum AccessLevel {
  full, // tam okuma+yazma
  grace, // süre doldu ama 7 gün lütuf (yazılabilir)
  readOnly, // kilitli — yalnız okuma + bekleyen outbox akışı
}

class SubscriptionState {
  static const graceDuration = Duration(days: 7);

  /// Erişim kararı. estimatedServerNow: ileri-sadece tahmini sunucu "şimdi"si (UTC).
  static AccessLevel evaluate({
    required DateTime estimatedServerNow,
    DateTime? validUntil,
    String? status,
  }) {
    // Sunucu açıkça kilit/askı dediyse otorite sunucudur → salt-okunur (grace'i atlar).
    if (status == 'locked' || status == 'suspended') return AccessLevel.readOnly;

    // Süre/kısıt yok → tam (sunucu "null valid_until = kilitsiz" ile simetrik).
    if (validUntil == null) return AccessLevel.full;

    // Fatura geleceğe kadar ödenmiş → tam (offline süresi önemsiz).
    if (validUntil.isAfter(estimatedServerNow)) return AccessLevel.full;

    // Süre dolmuş: 7 gün lütuf (sunucuya ulaşılamıyor varsayımı), sonra salt-okunur.
    final overdue = estimatedServerNow.difference(validUntil);
    return overdue <= graceDuration ? AccessLevel.grace : AccessLevel.readOnly;
  }

  /// Yazma izni var mı? (grace dahil; yalnız readOnly yazmayı durdurur — bekleyen outbox yine akar).
  static bool writable(AccessLevel level) => level != AccessLevel.readOnly;

  /// Minimal ileri-sadece "şimdi" tahmini: sistem saati + sunucu offset, son görülen sunucu saatine
  /// TABANLANMIŞ (kullanıcı sistem saatini geri alsa bile lastServerTime'ın altına inmez).
  /// NOT: gerçek monotonik elapsedRealtime çıpası (elapsedAnchorMs) platform kanalı ister — partner işi.
  static DateTime estimateServerNow({
    required int serverTimeOffsetMs,
    String? lastServerTimeIso,
    DateTime? wallClockNow,
  }) {
    final now = (wallClockNow ?? DateTime.now().toUtc()).add(Duration(milliseconds: serverTimeOffsetMs));
    final floor = lastServerTimeIso != null ? DateTime.tryParse(lastServerTimeIso) : null;
    if (floor != null && now.isBefore(floor)) return floor; // geri alma koruması (ileri-sadece)
    return now;
  }
}
