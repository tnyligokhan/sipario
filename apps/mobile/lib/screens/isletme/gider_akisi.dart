// GİDER EKLEME AKIŞI — gider sheet'i + yazma, tek kapı (2026-11-05).
//
// Gider artık iki yerden girilir: Gün Özeti'ndeki "Gider Ekle" ve alt menüdeki + düğmesi. Yetki ve
// kapanış kuralları aynı olmak zorunda; ikisi ayrı yazılsaydı zamanla ayrışırdı (`TeslimAkisi` deseni).

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../repo/gider_repository.dart';
import '../../repo/tenant_settings_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import 'gider_sheet.dart';

enum GiderAkisiSonucu { vazgecildi, kaydedildi, engellendi }

class GiderAkisi {
  const GiderAkisi({
    required this.db,
    required this.kapsamAdi,
    this.harcayanId,
    this.mevcutNakit,
  });

  final AppDatabase db;

  /// Sheet'in üstünde parayı kimin kasasından çıktığını söyleyen ad.
  final String kapsamAdi;

  /// Verilmezse oturumdaki kullanıcıya yazılır.
  final String? harcayanId;

  /// Kapsamda görünen nakit; verilirse "kasadakinden fazla" uyarısı çizilir.
  final int? mevcutNakit;

  /// Sheet'i açar ve kaydeder. Kapanmış kapsam engeli repodan geldiği gibi gösterilir: sheet
  /// açıkken senkron başka bir cihazdan kapanış indirebilir.
  Future<GiderAkisiSonucu> calistir(BuildContext context) async {
    final kategoriler = await TenantSettingsRepository(db).giderKategorileri();
    if (!context.mounted) return GiderAkisiSonucu.vazgecildi;

    final sonuc = await giderSheet(
      context,
      kapsamAdi: kapsamAdi,
      mevcutNakit: mevcutNakit,
      kategoriler: kategoriler,
    );
    if (sonuc == null || !context.mounted) return GiderAkisiSonucu.vazgecildi;

    try {
      await GiderRepository(db).ekle(
        kurus: sonuc.kurus,
        aciklama: sonuc.aciklama,
        harcayanId: harcayanId,
      );
    } on StateError catch (e) {
      if (context.mounted) SipToast.goster(context, e.message);
      return GiderAkisiSonucu.engellendi;
    }
    if (context.mounted) SipToast.goster(context, '${sipTutar(sonuc.kurus)} gider kaydedildi');
    return GiderAkisiSonucu.kaydedildi;
  }
}
