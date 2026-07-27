// Native çağrı kuyruğunun Flutter ucu — `android/.../CallJournal.kt` ile eşleşir.
//
// NEDEN KUYRUK VAR: telefon çaldığında Flutter motoru BAŞLATILMAZ (1 sn bütçe, DECISIONS
// Faz 0). Çağrıyı o an `call_logs` tablosuna yazacak olan taraf native'dir; ama yazma yolu
// daima repo → outbox'tır (SÖZLEŞME). İkisini uzlaştırmak için native çağrıyı düz metin bir
// dosyaya ekler, uygulama açıldığında burası dosyayı boşaltıp `CallLogRepository.log()` ile
// normal yoldan yazar. Böylece outbox/LWW/kimlik sözleşmesi tek yerde kalır.
//
// Biçim: satır başına `<iso8601-utc>|<yon>|<haneler>`; yon ∈ incoming | missed | outgoing.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' show getDatabasesPath;

import '../../data/app_database.dart';
import '../../repo/call_log_repository.dart';

/// `CallJournal.DOSYA` aynası.
const String kCagriKuyrukDosyasi = 'sipario_cagri_kuyrugu.txt';

/// Boşaltma sırasında kullanılan geçici ad. Native dosyaya yazmaya devam edebilsin diye
/// önce yeniden adlandırılır; yarıda kalırsa sonraki açılışta bu dosya da işlenir.
const String kCagriKuyrukIsleniyor = 'sipario_cagri_kuyrugu.isleniyor';

/// Native kuyruğunu boşaltır. **Uygulama AÇILIŞINDA bir kez çağrılmalıdır** (kabuk / ana ekran
/// kurulurken), çünkü çağrı geçmişini okuyan tek yer çağrı geçmişi ekranı değildir: ana ekrandaki
/// "Son Arama" bento kutusu da DB'den okur. Boşaltma yalnız geçmiş ekranı açıldığında yapılsaydı,
/// bayi Ayarlar'a girene kadar bento kutusu bayat kalırdı.
///
/// `await` edilmesi gerekmez; yazılan satırlar akışları kendiliğinden tazeler.
Future<int> cagriKuyrugunuBosalt(AppDatabase db) =>
    CagriKuyrugu(CallLogRepository(db)).bosalt();

/// Native'in biriktirdiği çağrıları çağrı günlüğüne aktarır.
class CagriKuyrugu {
  CagriKuyrugu(this.repo, {Future<String> Function()? dizin})
      : _dizin = dizin ?? getDatabasesPath;

  /// Test kipi — disk yok, boşaltma her zaman 0 döner.
  CagriKuyrugu.bellek(this.repo) : _dizin = null;

  final CallLogRepository repo;
  final Future<String> Function()? _dizin;

  /// Kuyruğu okuyup her satırı çağrı günlüğüne yazar; yazılan satır sayısını döner.
  ///
  /// HATA YUTAR: kuyruk okunamazsa uygulama normal çalışmaya devam eder — çağrı günlüğü
  /// bir kolaylıktır, açılışı bloke etmesi kabul edilemez.
  Future<int> bosalt() async {
    final klasor = await _klasor();
    if (klasor == null) return 0;

    final satirlar = <String>[];
    // Önce yarım kalmış bir boşaltma varsa onu topla, sonra tazeyi devral.
    final artik = File(p.join(klasor, kCagriKuyrukIsleniyor));
    final taze = File(p.join(klasor, kCagriKuyrukDosyasi));
    try {
      if (await artik.exists()) satirlar.addAll(await artik.readAsLines());
      if (await taze.exists()) {
        // Rename atomiktir: native bu andan sonra yeni bir dosyaya yazmaya başlar,
        // elimizdeki kopya donar ve satır kaybı/çift kayıt olmaz.
        final tasinan = await taze.rename(artik.path);
        satirlar.addAll(await tasinan.readAsLines());
      }
    } on Object catch (e) {
      debugPrint('Çağrı kuyruğu okunamadı: $e');
      return 0;
    }

    var yazilan = 0;
    for (final satir in satirlar) {
      final kayit = _cozumle(satir);
      if (kayit == null) continue;
      try {
        await repo.log(
          phoneE164: kayit.numara,
          direction: kayit.yon,
          occurredAtIso: kayit.zaman,
        );
        yazilan++;
      } on Object catch (e) {
        // Tek bir bozuk satır bütün kuyruğu tıkamasın.
        debugPrint('Çağrı kaydı yazılamadı: $e');
      }
    }

    try {
      if (await artik.exists()) await artik.delete();
    } on Object catch (e) {
      debugPrint('Çağrı kuyruğu silinemedi: $e');
    }
    return yazilan;
  }

  Future<String?> _klasor() async {
    final dizin = _dizin;
    if (dizin == null) return null;
    try {
      return await dizin();
    } on Object {
      return null; // platform kanalı yok (test) ya da dizin çözülemedi
    }
  }

  static _KuyrukSatiri? _cozumle(String ham) {
    final parcalar = ham.trim().split('|');
    if (parcalar.length < 3) return null;
    final zaman = parcalar[0].trim();
    final haneler = parcalar[2].replaceAll(RegExp(r'\D'), '');
    if (zaman.isEmpty || haneler.isEmpty) return null;
    return _KuyrukSatiri(
      zaman: zaman,
      yon: CallDirection.parse(parcalar[1].trim()),
      numara: e164(haneler),
    );
  }

  /// Native yalnız haneleri yazar; depoya E.164 biçiminde girsin diye Türkiye önekini kurar.
  /// Tanımadığı uzunlukta numara (kısa servis numarası, yurt dışı) olduğu gibi saklanır —
  /// eşleşme zaten `phone_last10` üzerinden yapılır, biçim yalnız gösterim içindir.
  static String e164(String haneler) {
    if (haneler.length == 10) return '+90$haneler';
    if (haneler.length == 11 && haneler.startsWith('0')) {
      return '+90${haneler.substring(1)}';
    }
    if (haneler.length == 12 && haneler.startsWith('90')) return '+$haneler';
    return haneler;
  }
}

class _KuyrukSatiri {
  const _KuyrukSatiri({
    required this.zaman,
    required this.yon,
    required this.numara,
  });

  final String zaman;
  final CallDirection yon;
  final String numara;
}
