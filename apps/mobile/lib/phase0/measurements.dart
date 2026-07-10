import 'dart:convert';

/// Native tarafın `LatencyLog`'una yazdığı tek bir tanıma denemesi.
/// KVKK gereği burada telefon numarası veya müşteri adı yoktur.
class Measurement {
  const Measurement({
    required this.ms,
    required this.matched,
    required this.simulated,
    required this.path,
    required this.locked,
    required this.direction,
    required this.at,
  });

  /// Çağrının servise düştüğü andan kartın ekrana çizildiği ana kadar geçen süre.
  /// -1 ise kart hiç gösterilemedi.
  final int ms;
  final bool matched;
  final bool simulated;

  /// 'overlay' (kilitsiz) | 'fullscreen' (kilit ekranı) | 'notification' | 'failed'
  final String path;

  /// Çağrı geldiğinde ekran kilitli miydi? Sahada çoğu zaman öyle.
  final bool locked;

  /// 'in' (gelen) | 'out' (giden). Giden aramada da kart gösterilir ama go/no-go
  /// sayımına girmez — hedef metin "20 gelen aramada kart" der.
  final String direction;
  final DateTime at;

  /// Kartın kullanıcı tarafından GERÇEKTEN görülebildiği durum.
  ///
  /// Kilitli ekranda `overlay` yolu çizim yapar ve `onDraw` tetiklenir ama pencere
  /// keyguard'ın altında kalır — kullanıcı hiçbir şey görmez. O yüzden kilitliyken
  /// yalnız `fullscreen` yolu gösterim sayılır. Bunu ayırmazsak metrik kendi
  /// başarısızlığını başarı olarak raporlar.
  bool get shown {
    if (ms < 0 || path == 'failed') return false;
    if (locked) return path == 'fullscreen';
    return path == 'overlay' || path == 'notification';
  }

  factory Measurement.fromJson(Map<String, dynamic> j) => Measurement(
        ms: j['ms'] as int,
        matched: j['matched'] as bool,
        simulated: j['simulated'] as bool,
        path: j['path'] as String,
        // Eski kayıtlarda bu alanlar yok; kilitsiz ve gelen varsayılır.
        locked: j['locked'] as bool? ?? false,
        direction: j['dir'] as String? ?? 'in',
        at: DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
      );

  static List<Measurement> parse(String raw) => (jsonDecode(raw) as List)
      .cast<Map<String, dynamic>>()
      .map(Measurement.fromJson)
      .toList();
}

/// Go/no-go kararının rakamları.
///
/// Hedef: gerçek çağrılarda 20/20 arama, ≤1000 ms, ve bunların bir kısmı ekran
/// kilitliyken. Simüle çağrılar (uygulama zaten açıkken tetiklenen) sayıma GİRMEZ —
/// sahadaki asıl zorluk, sürecin ölü olduğu yerden ayağa kalkmasıdır.
class Verdict {
  Verdict(List<Measurement> all)
      : real = all.where((m) => !m.simulated && m.direction == 'in').toList(),
        outgoing = all.where((m) => !m.simulated && m.direction == 'out').toList(),
        simulated = all.where((m) => m.simulated).toList();

  final List<Measurement> real;

  /// Giden aramalar: kart gösterilir, sayılır ama go/no-go'ya karışmaz.
  final List<Measurement> outgoing;
  final List<Measurement> simulated;

  static const targetMs = 1000;
  static const requiredCalls = 20;

  /// Kilit ekranı sahanın normal hali; en az bu kadarı kilitliyken sınanmalı.
  static const requiredLockedCalls = 5;

  int get total => real.length;
  int get shown => real.where((m) => m.shown).length;
  int get withinTarget => real.where((m) => m.shown && m.ms <= targetMs).length;
  int get missed => total - shown;

  List<Measurement> get lockedCalls => real.where((m) => m.locked).toList();
  int get lockedShown => lockedCalls.where((m) => m.shown).length;
  int get lockedMissed => lockedCalls.length - lockedShown;

  List<int> get _sorted => (real.where((m) => m.shown).map((m) => m.ms).toList())..sort();

  int? get median {
    final s = _sorted;
    if (s.isEmpty) return null;
    return s[s.length ~/ 2];
  }

  int? get worst => _sorted.isEmpty ? null : _sorted.last;

  int? get p95 {
    final s = _sorted;
    if (s.isEmpty) return null;
    final i = ((s.length - 1) * 0.95).round();
    return s[i];
  }

  int get viaOverlay => real.where((m) => m.path == 'overlay').length;
  int get viaFullScreen => real.where((m) => m.path == 'fullscreen').length;
  int get viaNotification => real.where((m) => m.path == 'notification').length;

  bool get enoughSamples => total >= requiredCalls;
  bool get enoughLocked => lockedCalls.length >= requiredLockedCalls;

  /// Tek bir kaçırılan çağrı veya tek bir geç kart bile "no-go" demektir:
  /// bayi telefonu açtığında ekranda müşteri yoksa ürünün vaadi çökmüştür.
  /// Kilit ekranı ayrıca sınanmadan GO verilemez — sahada telefon çoğu zaman kilitlidir.
  bool get pass =>
      enoughSamples && enoughLocked && missed == 0 && withinTarget == total;

  String get label {
    if (!enoughSamples) return 'Ölçüm sürüyor — $total/$requiredCalls arama';
    if (!enoughLocked) {
      return 'Kilit ekranı sınanmadı — ${lockedCalls.length}/$requiredLockedCalls';
    }
    return pass ? 'GO' : 'NO-GO';
  }
}
